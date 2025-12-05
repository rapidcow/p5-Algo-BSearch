package Sort::Search;

our $VERSION = '0.01_00';
$VERSION = eval $VERSION;

=pod

=head1 NAME

Sort::Search - binary search on contiguous sorted ranges

=head1 VERSION

Version 0.01

=cut

use 5.006;
use strict;
use warnings;

use Carp ();

our (@ISA, @EXPORT_OK);
BEGIN {
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT_OK = qw(
		bisectl bisectr bixectl bixectr
		blsrch0 brsrch0 blsrch1 brsrch1
		blsrch2 brsrch2 blsrchx brsrchx
	);

	# We could avoid copying array elements if caller just
	# wants to inspect $cmp to see if the index was legit?
	# It's okay if this fails, 'wantarray and want(...)'
	# will reduce to just wantarray in that case...
	eval { require Want; Want->import('want') };
	if ($@) { *want = sub { 1 } }
}

# Orientation flags passed to parse_args
use constant ORI_L => 1;
use constant ORI_R => 0;

# Parse input arguments.
#    $ori:  search orientation (1 for left, 0 for right)
#    $args: arguments from caller
# Return:
#    ($fun, undef, $beg, $end)   for index form.
# and
#    ($fun, $map,  $beg, $end)   for ARRAY/CODE form;
# where $fun is a predicate or an ordering, and
# $map returns a ref to the image at the index.
# On parse failure, return nothing and set $@.
sub parse_args
{
	my ($ori, $args) = @_;
	# This should never happen if args are checked
	# with prototype.  It's still a good idea to
	# check though, as prototypes can be bypassed.
	if (@$args < 2) {
		my $nargs = @$args;
		$@ = <<EOM;
not enough arguments (expected at least 2, got $nargs)
EOM
		return;
	}
	my ($fun, $arg) = splice(@$args, 0, 2);
	my ($beg, $end);
	# If $arg is a normal ARRAY ref or a blessed
	# ARRAY ref, map its index to its elements.
	# <https://stackoverflow.com/a/64160/19411800>
	# (Tied ARRAY refs should be OK too.)
	if (UNIVERSAL::isa($arg, 'ARRAY')) {
		if (@$args > 2) {
			my $nargs = @$args + 2;
			$@ = <<EOM;
too many arguments for ARRAY form (expected at most 4, got $nargs)
EOM
			return;
		}
		if ($ori) {
			# Left search
			my ($lo, $hi) = @$args;
			defined $lo or $lo = $[;
			defined $hi or $hi = 1 + $#$arg;
			($beg, $end) = ($lo, $hi);
		}
		else {
			# Right search
			my ($hi, $lo) = @$args;
			defined $hi or $hi = $#$arg;
			defined $lo or $lo = $[ - 1;
			($beg, $end) = ($hi, $lo);
		}
		($fun, sub { \$arg->[$_[0]] }, $beg, $end);
	}
	elsif (UNIVERSAL::isa($arg, 'CODE')) {
		if (@$args < 1) {
			my $nargs = @$args + 2;
			$@ = <<EOM;
not enough arguments for CODE form (expected at least 3, got $nargs)
EOM
			return;
		}
		if (@$args > 2) {
			my $nargs = @$args + 2;
			$@ = <<EOM;
too many arguments for CODE form (expected at most 4, got $nargs)
EOM
			return;
		}
		if (@$args == 2) {
			($beg, $end) = (@$args);
		}
		else {
			# $hi = $arg, $lo inferred
			my $arg = shift @$args;
			($beg, $end) = $ori ? (0, $arg) : ($arg, -1);
		}
		($fun, $arg, $beg, $end);
	}
	else {
		# Same way as how we handle the CODE form above,
		# except $arg is itself an index, so the argument
		# counts are all shifted down by 1...
		if (@$args > 1) {
			my $nargs = @$args + 2;
			$@ = <<EOM;
too many arguments for index form (expected at most 3, got $nargs)
EOM
			return;
		}
		if (@$args == 1) {
			unshift @$args, $arg;
			($beg, $end) = (@$args);
		}
		else {
			# $hi = $arg, $lo inferred
			($beg, $end) = $ori ? (0, $arg) : ($arg, -1);
		}
		($fun, undef, $beg, $end);
	}
}

# This is the left bisection algorithm.  It finds the
# index of the leftmost TRUE on the range [ $lo, $hi ),
# though if the predicate is never TRUE, $hi is used.
#
# $hi is also used when said range is empty ($lo >= $hi).
#
# Remark: For a leftmost TRUE to be well-defined, there
# must exist at least one boundary that all TRUEs follow:
#
#                  valid              BAD
#
#          $i    0 1 2 3 4         0 1 2 3 4
#               -----------       -----------
#    $ok->($e)   . . . . .|        . . T . .
#                . . .|T T         . T . T T
#               |T T T T T         T T . . .
#
# It can be shown that whenever such a boundary exists,
# it is unique and identified by the indices immediately
# following it and preceding it.  This algorithm finds
# the one following it.  (To find the preceding index,
# subtract this index by 1, or negate the predicate and
# use the right bisection method.)
#
# In scalar context, the $index is returned.  In list
# context, the $index, the last TRUE comparison result,
# and the last TRUE element are returned.  The latter
# two should therefore be equivalent to $ok->($index)
# and ${$map->($index)} iff $index is a "real" index
# on said range [ $lo, $hi ).
sub bisectl_map
{
	my ($any, $ok, $map, $lo, $hi) = @_;
	# Fun fact!  The following are written in the order
	# of right-to-left notation of function composition.
	# ($cmp = $res is the image of $elt = $$img via $ok,
	# which in turn is the image of $mid, the index...)
	my ($cmp, $res, $elt, $img, $mid);
	my $want2 = wantarray and want(2);
	my $want3 = wantarray and want(3);

	# Assumption: If $ok->($x) true, $x <= $y => $ok->($y) true.
	# Invariant:  - $ok attains truth somewhere on [ $lo, $hi ].
	#             - If $x < $lo,  $ok->($x) is false if defined.
	while ($lo < $hi) {
		# Prefer floor of (L+H)/2, so that $mid < $hi,
		# and so either branch is guaranteed to converge.
		$mid = $lo + (($hi - $lo) >> 1);
		$img = $map ? $map->($mid) : \$mid;
		local *_ = $img;
		if ($res = $ok->($mid)) {
			$hi = $mid;      # include
			$cmp = $res;
			$elt = $img;     # (delay deref?)
			last if $any;
		} else {
			$lo = $mid + 1;  # exclude
		}
	}
	$elt = $$elt if $want3 && defined $elt;
	$want2 ? ($hi, $cmp, $elt) : $hi;
}

sub bisectl (&$;$$)
{
	local $@;
	my @args = parse_args(ORI_L, \@_) or Carp::croak("bisectl: $@");
	bisectl_map(0, @args);
}

sub bixectl (&$;$$)
{
	local $@;
	my @args = parse_args(ORI_L, \@_) or Carp::croak("bixectl: $@");
	bisectl_map(1, @args);
}

# This is the right bisection algorithm.  It finds the
# index of the rightmost TRUE on the range ( $lo, $hi ],
# though if the predicate is never TRUE, $hi is used.
#
# $lo is also used when said range is empty ($lo <= $hi).
#
# Remark: For a rightmost TRUE to be well-defined, there
# must exist at least one boundary that all TRUEs precede:
#
#                  valid              BAD
#
#          $i    0 1 2 3 4         0 1 2 3 4
#               -----------       -----------
#    $ok->($e)  |. . . . .         T T . T T
#                T T T|. .         T . T . .
#                T T T T T|        . . . T T
#
# It can be shown that whenever such a boundary exists,
# it is unique and identified by the indices immediately
# following it and preceding it.  This algorithm finds
# the one preceding it.  (To find the following index,
# add 1 to this index, or negate the predicate and use
# the left bisection method.)
#
# The exact return value is documented above bisectl_map.
sub bisectr_map
{
	my ($any, $ok, $map, $hi, $lo) = @_;
	my ($cmp, $res, $elt, $img, $mid);
	my $want2 = wantarray and want(2);
	my $want3 = wantarray and want(3);

	# Assumption: If $ok->($y) true, $x <= $y => $ok->($x) true.
	# Invariant:  - $ok attains truth somewhere on [ $lo, $hi ].
	#             - If $x > $hi,  $ok->($x) is false if defined.
	while ($lo < $hi) {
		# Prefer ceiling of (L+H)/2, so that $lo > $mid,
		# and so either branch is guaranteed to converge.
		$mid = $lo + (($hi - $lo + 1) >> 1);
		$img = $map ? $map->($mid) : \$mid;
		local *_ = $img;
		if ($res = $ok->($mid)) {
			$lo = $mid;      # include
			$cmp = $res;
			$elt = $img;
			last if $any;
		} else {
			$hi = $mid - 1;  # exclude
		}
	}
	$elt = $$elt if $want3 && defined $elt;
	$want2 ? ($lo, $cmp, $elt) : $lo;
}

sub bisectr (&$;$$)
{
	local $@;
	my @args = parse_args(ORI_R, \@_) or Carp::croak("bisectr: $@");
	bisectr_map(0, @args);
}

sub bixectr (&$;$$)
{
	local $@;
	my @args = parse_args(ORI_R, \@_) or Carp::croak("bixectr: $@");
	bisectr_map(1, @args);
}

# This is binary left search (blsrch[01]).  Different
# from before, we are passed an ordering that returns
# a trichotomous number: negative, zero, or positive.
# This ordering is assumed to be monotonic INCREASING:
# negatives before zeros, and zeros before positives.
#
# This "number" may be a blessed ref, but it should, at
# the very least, understand how it compares numerically
# with the scalar 0 (not having bool is probably fine.
# There should be details in 'perldoc overload' for what
# you want to implement...)
#
# (Typically, a concrete interpretation of this number
# corresponds to the result of a comparison between
# element in a sorted haystack and a needle, but _how_
# you compare them depends on how the haystack is sorted.
# So discussion of this is postponed until the POD...)
#
# The 0 (blsrch0) and 1 (blsrch1) variants of the binary
# left search find the leftmost indices where the ordering
# returns a non-negative and positive number, respectively.
# This is a direct application of the left bisection
# algorithm, with the pre-defined predicates &$ord >= 0
# and &$ord > 0.  It can be shown that these predicates
# satisfy the left-predicate assumption, and -- by proxy
# -- the results of both search variants are well-defined.
#
# Intuitively, blsrch0 and blsrch1 effectively trisect
# the indices bounded by [ $lo, $hi ) into three zones:
#
#                         "zeros"
#          "negatives"  &$ord == 0  "positives"
#           &$ord < 0    \       /   &$ord > 0
#    $lo ---------------->|<--->|<---------------- $hi
#  (incl)                 ^     ^                 (excl)
#                        /       \
#                blsrch0           blsrch1
#             (inclusive)         (exclusive)
#
# The x (blsrchx) variant works the same as 0 (blsrch0),
# except it returns on any zero.  It does NOT complain
# by returning something negative or undef if it cannot
# find a zero.  If you care about an _exact_ match, you
# should call in list context and check if $cmp is 0 or
# undef (or compare it again yourself!  TMTOWTDI... :)
sub blsrch_map
{
	my ($any, $ok, $ord, $map, $lo, $hi) = @_;
	my ($cmp, $res, $elt, $img, $mid);
	my $want2 = wantarray and want(2);
	my $want3 = wantarray and want(3);
	while ($lo < $hi) {
		# Pick floor( (L+H)/2 )
		$mid = $lo + (($hi - $lo) >> 1);
		$img = $map ? $map->($mid) : \$mid;
		local *_ = $img;
		if ($ok->($res = $ord->($mid))) {
			$hi = $mid;       # include
			$cmp = $res;
			$elt = $img;
			last if $any and $res == 0;
		} else {
			$lo = $mid + 1;   # exclude
		}
	}
	$elt = $$elt if $want3 && defined $elt;
	$want2 ? ($hi, $cmp, $elt) : $hi;
}

sub blsrch0 (&$;$$)
{
	local $@;
	my @args = parse_args(ORI_L, \@_) or Carp::croak("blsrch0: $@");
	blsrch_map(0, sub { $_[0] >= 0 }, @args);
}

sub blsrch1 (&$;$$)
{
	local $@;
	my @args = parse_args(ORI_L, \@_) or Carp::croak("blsrch1: $@");
	blsrch_map(0, sub { $_[0] > 0 }, @args);
}

sub blsrchx (&$;$$)
{
	local $@;
	my @args = parse_args(ORI_L, \@_) or Carp::croak("blsrchx: $@");
	blsrch_map(1, sub { $_[0] >= 0 }, @args);
}

# This is binary right search (brsrch[01]), similarly.
# This ordering is assumed to be monotonic DECREASING:
# positives before zeros, and zeros before negatives.
#
# The 0 (brsrch0) and 1 (brsrch1) variants of the binary
# left search find the rightmost indices where the ordering
# returns a non-negative and positive number, respectively.
# This is a direct application of the right bisection
# algorithm, with the pre-defined predicates &$ord >= 0
# and &$ord > 0.  It can be shown that these predicates
# satisfy the right-predicate assumption, and -- by proxy
# -- the results of both search variants are well-defined.
#
# Intuitively, brsrch0 and brsrch1 effectively trisect
# the indices bounded by [ $lo, $hi ) into three zones:
#
#                         "zeros"
#          "positives"  &$ord == 0  "negatives"
#           &$ord > 0    \       /   &$ord < 0
#    $lo ---------------->|<--->|<---------------- $hi
#  (excl)                 ^     ^                 (incl)
#                        /       \
#                brsrch1           brsrch0
#             (exclusive)         (inclusive)
#
# The x (brsrchx) variant works the same as 0 (brsrch0),
# except it returns on any zero.  Same caveats apply
# (look above for blsrch_map...)
sub brsrch_map
{
	my ($any, $ok, $ord, $map, $hi, $lo) = @_;
	my ($cmp, $res, $elt, $img, $mid);
	my $want2 = wantarray and want(2);
	my $want3 = wantarray and want(3);
	while ($lo < $hi) {
		# Pick ceil( (L+H)/2 )
		$mid = $lo + (($hi - $lo + 1) >> 1);
		$img = $map ? $map->($mid) : \$mid;
		local *_ = $img;
		if ($ok->($res = $ord->($mid))) {
			$lo = $mid;       # include
			$cmp = $res;
			$elt = $img;
			last if $any and $res == 0;
		} else {
			$hi = $mid - 1;   # exclude
		}
	}
	$elt = $$elt if $want3 && defined $elt;
	$want2 ? ($hi, $cmp, $elt) : $hi;
}

sub brsrch0 (&$;$$)
{
	local $@;
	my @args = parse_args(ORI_R, \@_) or Carp::croak("brsrch0: $@");
	brsrch_map(0, sub { $_[0] >= 0 }, @args);
}

sub brsrch1 (&$;$$)
{
	local $@;
	my @args = parse_args(ORI_R, \@_) or Carp::croak("brsrch1: $@");
	brsrch_map(0, sub { $_[0] > 0 }, @args);
}

sub brsrchx (&$;$$)
{
	local $@;
	my @args = parse_args(ORI_R, \@_) or Carp::croak("brsrchx: $@");
	brsrch_map(1, sub { $_[0] >= 0 }, @args);
}

# b?srch2 is a shorthand that returns b?srch0 and b?srch1.
# Effectively, this gives you a half-open interval for all
# the indices where the ordering returns zero.
# (it's like equal_range from C++ STL, if you know that!)
#
# In scalar context, the difference is returned.  You can
# use it as the # of exact matches in the sorted array,
# or as a boolean indicating that a match exists.
#
# We assume that the zeros won't be stretch for too long,
# and the exclusive bound falls inclusive bound.
#
# Because we don't really care about the intermediate values
# themselves (or be able to return them, for that matter),
# we can get away with using bisect instead of b?srch... :)
sub blsrch2_map
{
	my ($ord, $map, $lo, $hi) = @_;
	my $lower = bisectl_map(0, sub { &$ord >= 0 }, $map, $lo, $hi);
	# Find a sufficiently close candidate for upper bound,
	# assuming there aren't too many equal values around?
	my ($prev, $next) = ($lower, $lower);
	for (my $step = 1; $next < $hi; $step <<= 1) {
		# Do not step on $hi, $ord could be undefined there
		if ($hi - $next <= $step) {
			$next = $hi;
			last;
		}
		$next += $step;
		# Strictly speaking, we only have to check for != 0,
		# since if the ordering is well-behaved, it should be
		# nonnegative from this point and on... just saying :P
		local *_ = $map ? $map->($next) : \$next;
		last if $ord->($next) > 0;
		$prev = $next;
	}
	my $upper = bisectl_map(0, sub { &$ord > 0 }, $map, $prev, $next);
	wantarray ? ($lower, $upper) : $upper - $lower;
}

# And the mirror image...
sub brsrch2_map
{
	my ($ord, $map, $hi, $lo) = @_;
	my $lower = bisectr_map(0, sub { &$ord >= 0 }, $map, $hi, $lo);
	my ($prev, $next) = ($lower, $lower);
	for (my $step = 1; $next - $step > $lo; $step <<= 1) {
		# Do not step on $lo for the same reason
		if ($next - $lo <= $step) {
			$next = $lo;
			last;
		}
		$next -= $step;
		local *_ = $map ? $map->($next) : \$next;
		last if $ord->($next) > 0;
		$prev = $next;
	}
	my $upper = bisectr_map(0, sub { &$ord > 0 }, $map, $prev, $next);
	wantarray ? ($lower, $upper) : $lower - $upper;
}

sub blsrch2 (&$;$$)
{
	local $@;
	my @args = parse_args(ORI_L, \@_) or Carp::croak("blsrch2: $@");
	blsrch2_map(@args);
}

sub brsrch2 (&$;$$)
{
	local $@;
	my @args = parse_args(ORI_R, \@_) or Carp::croak("brsrch2: $@");
	brsrch2_map(@args);
}

1;

__END__

=pod

=head1 SYNOPSIS

  # TODO !

=head1 DESCRIPTION

  # TODO !

=head1 CAVEATS

  # TODO !

Please report any bugs or feature requests to C<bug-sort-search at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Sort-Search>.

=head1 SEE ALSO

  # TODO !

=head1 AUTHORS

Ethan Meng C<< <ethan at rapidcow.org> >>.

=head1 LICENSE

This module is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut
