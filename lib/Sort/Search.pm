#
# Copyright (c) 2025, 2026, Ethan Meng <ethan@rapidcow.org>
#
# This module is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
# See LICENSE at the root directory of your distribution
# for a copy of Perl's licenses.
#
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
}

use constant LTR => 1;  # left-to-right
use constant RTL => 0;  # right-to-left

# Parse input arguments.
#    $ori:  search orientation (1 for left/LTR, 0 for right/RTL)
#    @args: arguments from caller
# Return:
#    ($fun, undef, $beg, $end)   for index form.
# and
#    ($fun, $map,  $beg, $end)   for ARRAY/CODE form;
# where $fun is a predicate or an ordering, and
# $map returns a ref to the image at the index.
# On parse failure, croak.
sub _parse
{
	my ($ori, @args) = @_;
	my $caller = (caller)[3];  # subroutine name
	# This should never happen if args are checked
	# with prototype.  It's still a good idea to
	# check though, as prototypes can be bypassed.
	if (@args < 2) {
		my $nargs = @args;
		Carp::croak($caller, ": ", <<EOM);
not enough arguments (expected at least 2, got $nargs)
EOM
	}
	my ($fun, $arg) = splice @args, 0, 2;
	my ($beg, $end);
	# If $arg is a normal ARRAY ref or a blessed
	# ARRAY ref, map its index to its elements.
	# <https://stackoverflow.com/a/64160/19411800>
	# (Tied ARRAY refs should be OK too.)
	if (UNIVERSAL::isa($arg, 'ARRAY')) {
		if (@args > 2) {
			my $nargs = @args + 2;
			Carp::croak($caller, ": ", <<EOM);
too many arguments for ARRAY form (expected at most 4, got $nargs)
EOM
		}
		if ($ori) {
			# Left search
			my ($lo, $hi) = @args;
			defined $lo or $lo = $[;
			defined $hi or $hi = 1 + $#$arg;
			($beg, $end) = ($lo, $hi);
		}
		else {
			# Right search
			my ($hi, $lo) = @args;
			defined $hi or $hi = $#$arg;
			defined $lo or $lo = $[ - 1;
			($beg, $end) = ($hi, $lo);
		}
		($fun, sub { \$arg->[$_[0]] }, $beg, $end);
	}
	elsif (UNIVERSAL::isa($arg, 'CODE')) {
		if (@args < 1) {
			my $nargs = @args + 2;
			Carp::croak($caller, ": ", <<EOM);
not enough arguments for CODE form (expected at least 3, got $nargs)
EOM
		}
		if (@args > 2) {
			my $nargs = @args + 2;
			Carp::croak($caller, ": ", <<EOM);
too many arguments for CODE form (expected at most 4, got $nargs)
EOM
		}
		if (@args == 2) {
			($beg, $end) = (@args);
		}
		else {
			# $hi = $arg, $lo inferred
			my $arg = shift @args;
			($beg, $end) = $ori ? (0, $arg) : ($arg, -1);
		}
		($fun, $arg, $beg, $end);
	}
	else {
		# Same way as how we handle the CODE form above,
		# except $arg is itself an index, so the argument
		# counts are all shifted down by 1...
		if (@args > 1) {
			my $nargs = @args + 2;
			Carp::croak($caller, ": ", <<EOM);
too many arguments for index form (expected at most 3, got $nargs)
EOM
		}
		if (@args == 1) {
			unshift @args, $arg;
			($beg, $end) = (@args);
		}
		else {
			# $hi = $arg, $lo inferred
			($beg, $end) = $ori ? (0, $arg) : ($arg, -1);
		}
		($fun, undef, $beg, $end);
	}
}

# Very silly workaround for finding the arithmetic
# mean with mixed IV/UV... this should not break it
# for bigint since we only do right shifts and only
# on positive integers.
#
# _lmean finds the floor of ($lo+$hi)/2 while _rmean
# finds the ceiling.  Caller ensures that $lo < $hi.
sub _lmean
{
	my ($lo, $hi) = @_;
	if ($lo < 0 && $hi > 0) {
		# $lo and $hi may be very far apart.
		# Compute the midpoint in a way that
		# doesn't overflow into a float (NV).
		my $sum = $lo + $hi;
		if ($sum < 0) {
			# >> on a positive integer...
			- ((1 - $sum) >> 1);
		} else {
			$sum >> 1;
		}
	} else {
		$lo + (($hi - $lo) >> 1);
	}
}

sub _rmean
{
	my ($lo, $hi) = @_;
	if ($lo < 0 && $hi > 0) {
		# Same overflow guard for here.
		my $sum = $lo + $hi;
		if ($sum < 0) {
			- ((-$sum) >> 1);
		} else {
			($sum + 1) >> 1;
		}
	} else {
		$lo + (($hi - $lo + 1) >> 1);
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
sub _bisectl
{
	my ($any, $ok, $map, $lo, $hi) = @_;
	# Fun fact!  The following are written in the order
	# of right-to-left notation of function composition.
	# ($cmp = $res is the image of ${$elp = $img} via $ok,
	# which in turn is the image of $mid, the index...)
	my ($cmp, $res, $elp, $img, $mid);

	# Assumption: If $ok->($x) true, $x <= $y => $ok->($y) true.
	# Invariant:  - $ok attains truth somewhere on [ $lo, $hi ].
	#             - If $x < $lo,  $ok->($x) is false if defined.
	while ($lo < $hi) {
		# Prefer floor of (L+H)/2, so that $mid < $hi,
		# and so either branch is guaranteed to converge.
		$mid = _lmean($lo, $hi);
		$img = $map ? $map->($mid) : \$mid;
		local *_ = $img;
		if ($res = $ok->($mid)) {
			$hi = $mid;      # include
			$cmp = $res;
			$elp = $img;
			last if $any;
		} else {
			$lo = $mid + 1;  # exclude
		}
	}
	wantarray ? ($hi, $cmp, $elp) : $hi;
}

sub bisectl (&$;$$) { _bisectl(0, _parse(LTR, @_)); }
sub bixectl (&$;$$) { _bisectl(1, _parse(LTR, @_)); }

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
# The exact return value is documented above _bisectl.
sub _bisectr
{
	my ($any, $ok, $map, $hi, $lo) = @_;
	my ($cmp, $res, $elp, $img, $mid);

	# Assumption: If $ok->($y) true, $x <= $y => $ok->($x) true.
	# Invariant:  - $ok attains truth somewhere on [ $lo, $hi ].
	#             - If $x > $hi,  $ok->($x) is false if defined.
	while ($lo < $hi) {
		# Prefer ceiling of (L+H)/2, so that $lo > $mid,
		# and so either branch is guaranteed to converge.
		$mid = _rmean($lo, $hi);
		$img = $map ? $map->($mid) : \$mid;
		local *_ = $img;
		if ($res = $ok->($mid)) {
			$lo = $mid;      # include
			$cmp = $res;
			$elp = $img;
			last if $any;
		} else {
			$hi = $mid - 1;  # exclude
		}
	}
	wantarray ? ($lo, $cmp, $elp) : $lo;
}

sub bisectr (&$;$$) { _bisectr(0, _parse(RTL, @_)); }
sub bixectr (&$;$$) { _bisectr(1, _parse(RTL, @_)); }

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
sub _blsrch
{
	my ($any, $ok, $ord, $map, $lo, $hi) = @_;
	my ($cmp, $res, $elp, $img, $mid);
	while ($lo < $hi) {
		# Pick floor( (L+H)/2 )
		$mid = _lmean($lo, $hi);
		$img = $map ? $map->($mid) : \$mid;
		local *_ = $img;
		if ($ok->($res = $ord->($mid))) {
			$hi = $mid;       # include
			$cmp = $res;
			$elp = $img;
			last if $any and $res == 0;
		} else {
			$lo = $mid + 1;   # exclude
		}
	}
	wantarray ? ($hi, $cmp, $elp) : $hi;
}

sub blsrch0 (&$;$$) { _blsrch(0, sub { $_[0] >= 0 }, _parse(LTR, @_)); }
sub blsrch1 (&$;$$) { _blsrch(0, sub { $_[0] >  0 }, _parse(LTR, @_)); }
sub blsrchx (&$;$$) { _blsrch(1, sub { $_[0] >= 0 }, _parse(LTR, @_)); }

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
# the indices bounded by ( $lo, $hi ] into three zones:
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
# The x (brsrchx) variant works in exactly the same
# way as 0 (brsrch0), except it returns on any zero.
# Same caveats apply (look above for `_blsrch'...)
sub _brsrch
{
	my ($any, $ok, $ord, $map, $hi, $lo) = @_;
	my ($cmp, $res, $elp, $img, $mid);
	while ($lo < $hi) {
		# Pick ceil( (L+H)/2 )
		$mid = _rmean($lo, $hi);
		$img = $map ? $map->($mid) : \$mid;
		local *_ = $img;
		if ($ok->($res = $ord->($mid))) {
			$lo = $mid;       # include
			$cmp = $res;
			$elp = $img;
			last if $any and $res == 0;
		} else {
			$hi = $mid - 1;   # exclude
		}
	}
	wantarray ? ($lo, $cmp, $elp) : $lo;
}

sub brsrch0 (&$;$$) { _brsrch(0, sub { $_[0] >= 0 }, _parse(RTL, @_)); }
sub brsrch1 (&$;$$) { _brsrch(0, sub { $_[0] >  0 }, _parse(RTL, @_)); }
sub brsrchx (&$;$$) { _brsrch(1, sub { $_[0] >= 0 }, _parse(RTL, @_)); }

# b?srch2 is a shorthand that returns b?srch0 and b?srch1.
# Effectively, this gives you a half-open interval for all
# the indices where the ordering returns zero.
# (it's like equal_range from C++ STL, if you know that!)
#
# Actually, this is just going to be based on C++ STL,
# namely GNU GCC's implementation of it in libstdc++-v3.
# Observe that we're effectively finding a range for
# the zeros.  If this range is empty, the boundaries of
# this range collapse and both searches converge to the
# same point; so either search will do the trick, so we
# will use the search for an inclusive bound (since the
# inequality &ord >= 0 has the equality we want).  Now
# here's the ingenious part: if the range is NOT empty,
# at some point we'd enter this range:
#
#    (&ord < 0)    (&ord == 0)            (&ord > 0)
#    ---------o[-->|<===o===>|<--------------]o-------->
#           $lo ------->^ found at $mid      $hi
#             ^<----------------------------- ^<---- ...
#                             [This is left-search, btw]
#
# Up to this point we're doing the same thing as b?srchx,
# $mid being what it would return.  BUT we continue to
# search for lower and upper equal matches, which (as
# you can tell from my meticulously constructed diagram*)
# falls between [$lo, $mid] and ($mid, $hi].  (Note that
# the "upper" match is actually one position above it, so
# the range would exclude $mid, an actual equal match.)
#
# * Note that the lower bound exists to the left of any zero
#   (including it) and the upper bound exists to the right of
#   any zero (excluding it). In other words, my meticulously
#   constructed diagram is accurate and you can trust it. :)
#   (Also note that, since $mid is the FIRST equality, the
#   equal range would actually fall fully inside our bounds.)
sub _blsrch2
{
	my ($ord, $map, $lo, $hi) = @_;
	my ($res, $img, $mid);
	while ($lo < $hi) {
		# Pick floor( (L+H)/2 )
		$mid = _lmean($lo, $hi);
		$img = $map ? $map->($mid) : \$mid;
		local *_ = $img;
		$res = $ord->($mid);
		if ($res == 0) {
			$lo = _bisectl(0, sub { &$ord >= 0 }, $map, $lo, $mid);
			$hi = _bisectl(0, sub { &$ord > 0 }, $map, $mid + 1, $hi);
			last;
		} elsif ($res > 0) {
			$hi = $mid;       # include
		} else {
			$lo = $mid + 1;   # exclude
		}
	}
	wantarray ? ($lo, $hi) : ($hi - $lo);
}

# It is worth noting that the lower bound is exclusive now
# (equivalent to brsrch1) and the upper bound is inclusive
# (equivalent to brsrch0).  For the first part we search as
# we do in brsrchx, and when a zero is found, [$hi, $mid)
# has the lower bound and [$mid, $hi] has the upper bound.
sub _brsrch2
{
	my ($ord, $map, $hi, $lo) = @_;
	my ($res, $img, $mid);
	while ($lo < $hi) {
		# Pick ceil( (L+H)/2 )
		$mid = _rmean($lo, $hi);
		$img = $map ? $map->($mid) : \$mid;
		local *_ = $img;
		$res = $ord->($mid);
		if ($res == 0) {
			$hi = _bisectr(0, sub { &$ord >= 0 }, $map, $hi, $mid);
			$lo = _bisectr(0, sub { &$ord > 0 }, $map, $mid - 1, $lo);
			last;
		} elsif ($res > 0) {
			$lo = $mid;       # include
		} else {
			$hi = $mid - 1;   # exclude
		}
	}
	wantarray ? ($hi, $lo) : ($hi - $lo);
}

sub blsrch2 (&$;$$) { _blsrch2(_parse(LTR, @_)); }
sub brsrch2 (&$;$$) { _brsrch2(_parse(RTL, @_)); }

1;
