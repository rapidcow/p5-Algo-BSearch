package Sort::Search;

our $VERSION = '0.01_00';
$VERSION = eval $VERSION;

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

=head1 NAME

Sort::Search - binary search on contiguous sorted ranges

=head1 SYNOPSIS

  use Sort::Search qw(
    bisectl bisectr bixectl bixectr
    blsrch0 brsrch0 blsrch1 brsrch1
    blsrch2 brsrch2 blsrchx brsrchx
  );

  bisectl { OK } ARRAY;   # leftmost True (F to T)
  bisectr { OK } ARRAY;   # rightmost True (T to F)
  bixectl { OK } ARRAY;   # any True  (F to T)
  bixectr { OK } ARRAY;   # any True  (T to F)

  blsrch0 { ORD } ARRAY;  # leftmost >= 0 (- to +)
  blsrch1 { ORD } ARRAY;  # leftmost > 0  (- to +)
  brsrch0 { ORD } ARRAY;  # rightmost >= 0 (+ to -)
  brsrch1 { ORD } ARRAY;  # rightmost > 0  (+ to -)

  blsrch2 { ORD } ARRAY;  # (blsrch0, blsrch1)
  brsrch2 { ORD } ARRAY;  # (brsrch0, brsrch1)
  blsrchx { ORD } ARRAY;  # any == 0  (- to +)
  brsrchx { ORD } ARRAY;  # any == 0  (+ to -)

=head1 DESCRIPTION

This module implements two classes of search algorithms,
which will named separately in this document as the
I<bisection method> and the (ordinary) I<binary search>
for distinction.  A brief definition follows.

=over

=item *

The I<bisection method> works with a monotonic predicate
(B<OK>) with a unique transition point from False to True, or
vice versa.

For example, the array C<[0, 1, 2, 3, 4]> with respect to the
predicate C<< $_ >= 2 >> transitions from False at C<1> into
True at C<2>, and the array C<[5, 4, 3, 2, 1]> with respect
to the predicate C<< $_ >= 3 >> transitions from True at C<3>
to False at C<2>.  We name the boundary between these two
elements the I<bisection point>.

=item *

The I<binary search> works with a C-like comparison function,
named the I<ordering> (B<ORD>), with two unique transition
points from negative to 0, then 0 to positive.  Such a
function is typically constructed with respect to a target
value to be located within the array (hence the name "search").

For example, suppose we want to locate C<$T = 3> in the array
C<[1, 2, 3, 3, 4]>.  We can consider the ordering C<< $_ <=>
$T >>, which returns negatives for C<[1, 2]>, zeros for C<[3, 3]>,
and positives for C<[4]>.  We name the boundary between the
negatives and the zeros the I<lower bisection point>, and that
between the zeros and the positives the I<upper bisection point>.

=back

In both cases, we call the return value of the
predicate/ordering the I<comparison result>, or
C<$cmp> for short.

For every function in the conventional direction (i.e.,
left-to-right, true-to-false, increasing), a dual variant
is provided.  The conventional and dual directions are
identified by the lowercase letter L and R.  To re-use
my examples, this:

  use Sort::Search qw(bisectl);
  my @A = ( 0, 1, 2, 3, 4 );
  print $A[ bisectl { $_ >= 2 } \@A ];

prints C<2> because the left-variants prefer to return
the leftmost index of the matching range C<[2, 3, 4]>.

  use Sort::Search qw(bisectr);
  my @B = ( 5, 4, 3, 2, 1 );
  print $B[ bisectr { $_ >= 3 } \@B ];

prints C<-3> because the right-variants prefer to return
the rightmost index of the matching range C<[5, 4, 3]>.

For every algorithm that searches for the precise bisection
point, a variant that returns an arbitrary match is provided.
They are identified by the letter X.  (Mnemonic: X stands
for eXists.)

=over

=item *

C<bixectl> is a modified version of C<bisectl> that
returns any index for which the predicate returns True.
In the case that the predicate attains True at exactly
one point or never attains True, they behave identically.

For C<bixectr>, it's the same against C<bisectr> except
it finds any index for which the predicate returns False.

=item *

C<blsrchx> is a modified version of C<blsrch0> that
returns any index for which the predicate returns 0.
In the case that the ordering attains 0 at exactly
one point or skips it entirely, they behave identically.

For C<brsrchx>, it's the same against C<brsrch0>.

=back

=begin VOID

The observant reader will quickly notice that the L-R
variants make each other redundant.

You are free to stick to one variant, then add 1 to or
subtract 1 from the index to derive the other. :)

For reference, the following relations should hold:

  bisectl { OK } ARRAY[,LO[,HI+1]]   ==  1 + bisectr { !OK } ARRAY[,HI[,LO-1]];
  bixectl { OK } ARRAY[,LO[,HI+1]]   ==  1 + bixectr { !OK } ARRAY[,HI[,LO-1]];
  blsrch0 { ORD } ARRAY[,LO[,HI+1]]   ==  1 + brsrch1 { -ORD } ARRAY[,HI[,LO-1]];
  blsrch1 { ORD } ARRAY[,LO[,HI+1]]   ==  1 + brsrch0 { -ORD } ARRAY[,HI[,LO-1]];
  blsrch2 { ORD } ARRAY[,LO[,HI+1]]    ==   brsrch2 { -ORD } ARRAY[,HI[,LO-1]];
                                     (in scalar context)

=end VOID

=head1 SUBROUTINES

All subroutines are exported on-demand.  All subroutines
the same interface for input and output described in
L</COMMON INTERFACE>.

=over

=item B<bisectl>

=item B<bixectl>

Perform left bisection with respect to a predicate on the half-open
interval C<[$lo, $hi)>, where C<$lo> precedes C<$hi> in the argument
list.  The prototype is C<&$;$$>.

The predicate should be increasing over every pair of adjacent indices
it is defined on.  That is, true values always follow false values:

   F F F ... F T T T   ok(x)
   0 1 2     6 7 8 9      x

Let C<$ok> denote the predicate, and set C<< $ok->($hi) = 1 >>.
The return value of C<bisectl> is the unique index C<$x> on the
closed interval C<[$lo, $hi]> such that:

=over

=item *

C<< $ok->($x) >> is true.

=item *

For all valid index C<< $y < $x >>, it follows that C<< $ok->($y) >> is false.

=back

The return value of C<bixectl> is any index satisfying the first constraint.

If the interval C<[$lo, $hi]> is empty, return C<$hi>.

=item B<bisectr>

=item B<bixectr>

Perform right bisection with respect to a predicate on the half-open
interval C<($lo, $hi]>, where C<$hi> precedes C<$lo> in the argument
list.  The prototype is C<&$;$$>.

The predicate should be decreasing over every pair of adjacent indices
it is defined on.  That is, true values always precede false values:

   T T T ... T F F F   ok(x)
   0 1 2     6 7 8 9      x

Let C<$ok> denote the predicate, and set C<< $ok->($lo) = 1 >>.
The return value of C<bisectr> is the unique index C<$x> on the
closed interval C<[$lo, $hi]> such that:

=over

=item *

C<< $ok->($x) >> is true.

=item *

For all valid index C<< $y > $x >>, it follows that C<< $ok->($y) >> is false.

=back

The return value of C<bixectr> is any index satisfying the first constraint.

If the interval C<[$lo, $hi]> is empty, return C<$lo>.

=back

In general, a return value of C<$hi> (for left bisection) and
C<$lo> (for right bisection) is not meaningful as it is the only
index taken to be true for granted.  Caller should handle it
separately, or check if the comparison result and/or element
are defined by calling in list context.

=over

=item B<blsrch0>

=item B<blsrchx>

=item B<blsrch1>

=item B<blsrch2>

Perform binary left search with respect to an ordering on the
half-open interval C<[$lo, $hi)>, where C<$lo> precedes C<$hi>
in the argument list.  The prototype is C<&$;$$>.

The sign of the ordering should be increasing over every pair of
adjacent indices it is defined on.  That is, C<< <0 >> (negative)
precedes C<< =0 >> (zero), which precedes C<< >0 >> (positive).

More concretely, the ordering defines the comparison of every value in
an ordered list, C<$_>, to a target value, C<$target>: C<< $cmp < 0 >>
represents C<< $_ < $target >>; C<$cmp == 0> represents C<$_ == $target>;
and C<< $_ > $target >> when C<< $cmp > 0 >>.  When the list is sorted
in increasing order, C<< $_ <=> $target >> is a valid ordering:

   [1, 1, 2, 3, 3, 4, 5, 5, 5, 6, 8, 9, 9]       x
   -1 -1 -1  ...  -1  0  0  0  1  1  ...     ord(x) := (x <=> 5)

When the list is sorted in decreasing order, C<< $target <=> $_ >>
is a valid ordering:

   [9, 9, 8, 6, 5, 5, 5, 4, 3, 3, 2, 1, 1]       x
    ...  -1 -1  0  0  0  1  ...   1  1  1    ord(x) := (5 <=> x)

The same applies to sorted lists of strings by replacing
C<< <=> >> with C<cmp>.

Let C<$ord> denote the ordering and set C<< $ord->($hi) = +Infinity >>.
The return value of C<blsect0> is the unique index C<$lower> on
the closed interval C<[$lo, $hi]> such that:

=over

=item *

C<< $ord->($lower) >= 0 >>.

=item *

For all valid index C<< $x < $lower >>, it follows that C<< $ord->($x) < 0 >>.
As a result, C<< $lower >> is the first instance where C<< $ord >= 0 >>,
while C<< $lower - 1 >> is the last instance where C<< $ord < 0 >>.
(Compare this to C<brsect1>.)

=back

The return value of C<blsectx> is any index C<$x> satisfying
C<< $ord->($x) == 0 >>, but if one could not be found,
it returns the same result as C<blsect0>.

The return value of C<blsect1> is the unique index C<$upper_x>
on the closed interval C<[$lo, $hi]> such that:

=over

=item *

C<< $ord->($upper_x) > 0 >>.

=item *

For all valid index C<< $x < $upper_x >>, it follows that C<< $ord->($x) <= 0 >>.
As a result, C<< $upper_x >> is the first instance where C<< $ord > 0 >>,
while C<< $upper_x - 1 >> is the last instance where C<< $ord <= 0 >>.
(Compare this to C<brsect0>.)

=back

In list context, C<blsect2> returns both C<$lower> and C<$upper>,
in that order.  In scalar context, it returns the nonnegative
difference C<$upper_x - $lower>, which equals the number of elements
for which C<$ord == 0>.

=item B<brsrch0>

=item B<brsrchx>

=item B<brsrch1>

=item B<brsrch2>

Perform binary right search with respect to an ordering on the
half-open interval C<($lo, $hi]>, where C<$hi> precedes C<$lo>
in the argument list.  The prototype is C<&$;$$>.

The sign of the ordering should be decreasing over every pair of
adjacent indices it is defined on.  That is, C<< >0 >> (positive)
precedes C<< =0 >> (zero), which precedes C<< <0 >> (negative).

More concretely, the ordering defines the comparison of every value in
an ordered list, C<$_>, to a target value, C<$target>: C<< $cmp < 0 >>
represents C<< $_ < $target >>; C<$cmp == 0> represents C<$_ == $target>;
and C<< $_ > $target >> when C<< $cmp > 0 >>.  When the list is sorted
in increasing order, C<< $target <=> $_ >> is a valid ordering:

   [1, 1, 2, 3, 3, 4, 5, 5, 5, 6, 8, 9, 9]       x
    1  1  1  ...   1  0  0  0 -1 -1  ...     ord(x) := (5 <=> x)

When the list is sorted in decreasing order, C<< $_ <=> $target >>
is a valid ordering:

   [9, 9, 8, 6, 5, 5, 5, 4, 3, 3, 2, 1, 1]       x
    ...   1  1  0  0  0 -1  ...  -1 -1 -1    ord(x) := (x <=> 5)

The same applies to sorted lists of strings by replacing
C<< <=> >> with C<cmp>.

Let C<$ord> denote the ordering and set C<< $ord->($lo) = +Infinity >>.
The return value of C<brsect0> is the unique index C<$upper> on
the closed interval C<[$lo, $hi]> such that:

=over

=item *

C<< $ord->($upper) >= 0 >>.

=item *

For all valid index C<< $x > $upper >>, it follows that C<< $ord->($x) < 0 >>.
As a result, C<< $upper >> is the last instance where C<< -$ord <= 0 >> and
C<< $upper + 1 >> is the first instance where C<< -$ord > 0 >>.
(Compare this to C<blsect1>.)

=back

The return value of C<brsectx> is any index C<$x> satisfying
C<< $ord->($x) == 0 >>, but if one could not be found,
it returns the same result as C<brsect0>.

The return value of C<brsect1> is the unique index C<$lower> on
the closed interval C<[$lo, $hi]> such that:

=over

=item *

C<< $ord->($lower_x) > 0 >>.

=item *

For all valid index C<< $x > $lower_x >>, it follows that C<< $ord->($x) <= 0 >>.
As a result, C<< $lower_x >> is the last instance where C<< -$ord < 0 >> and
C<< $lower_x + 1 >> is the first instance where C<< -$ord >= 0 >>.
(Compare this to C<blsect0>.)

=back

In list context, C<brsect2> returns both C<$upper> and C<$lower_x>,
in that order.  In scalar context, it returns the nonnegative
difference C<$upper - $lower_x>, which equals the number of elements
for which C<$ord == 0>.

=back

=head1 COMMON INTERFACE

  # TODO !

=head1 CAVEATS

  # TODO !

Please report any bugs or feature requests to C<bug-sort-search at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Sort-Search>.

=head1 SEE ALSO

L<List::MoreUtils>, L<List::Search>, L<List::BinarySearch>,
L<List::BinarySearch::XS>.

=head1 AUTHORS

Ethan Meng C<< <ethan at rapidcow.org> >>.

=head1 LICENSE

This module is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut
