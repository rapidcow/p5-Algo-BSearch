package FastLook;
use 5.006;
use strict;
use warnings;

use Carp;
BEGIN {
	# We can avoid copying array elements if this is the case?
	# It's okay if we don't find Want, 'wantarray and want(...)'
	# will reduce to just wantarray in that case...
	eval { require Want; Want->import('want') }
	if ($@) { *want = sub { 1 } }
}

=head1 NAME

FastLook - binary search on contiguous monotonic ranges

=head1 VERSION

Version 0.00_00 (unimplemented)

=head1

=cut

our $VERSION = '0.00_00';

sub bisectl (&$;$$);
sub bisectr (&$;$$);
sub bixectl (&$;$$);
sub bixectr (&$;$$);

sub blsrch0 (&$;$$);
sub blsrch1 (&$;$$);
sub blsrch2 (&$;$$);
sub blsrchx (&$;$$);

sub brsrch0 (&$;$$);
sub brsrch1 (&$;$$);
sub brsrch2 (&$;$$);
sub brsrchx (&$;$$);

=head1 SYNOPSIS

   use FastLook qw(
       bisectl bisectr bixectl bixectr
       blsrch0 brsrch0 blsrch1 brsrch1
       blsrch2 brsrch2 blsrchx brsrchx
   );

   # Input forms (left bisection)
   bisectl { ok($idx = $_) } [\&sub,]$hi; # $lo //= 0
   bisectl { ok($idx = $_) } [\&sub,]$lo, $hi;
   bisectl { ok($elt = $_) } \@list;      # $lo //= $[
   bisectl { ok($elt = $_) } \@list, $lo; # $hi //= $[ + @$list
   bisectl { ok($elt = $_) } \@list, $lo, $hi;

   # Input forms (right bisection)
   bisectr { ok($idx = $_) } [\&sub,]$hi; # $lo //= -1
   bisectr { ok($idx = $_) } [\&sub,]$hi, $lo;
   bisectr { ok($elt = $_) } \@list;      # $hi //= $#$list
   bisectr { ok($elt = $_) } \@list, $hi; # $lo //= $[ - 1
   bisectr { ok($elt = $_) } \@list, $hi, $lo;

   # Output forms (as bi-/tri-section point)
   my $idx               = blsrch0 { ok } \@list;
   my ($idx, $cmp, $elt) = blsrch0 { ok } \@list;

   # Output forms (as dual trisection points)
   my $count       = blsrch2 { ok } \@list;
   my ($beg, $end) = blsrch2 { ok } \@list;

=head1 EXAMPLES

Who doesn't love examples!

You can compute the integer square root of C<$x> by
searching for the last integer C<$_> for which holds
C<$_ * $_ < $x> holds:

   sub isqrt {
       my ($x) = @_;
       bisectr { $_ * $_ <= $x } $x;
   }

   print isqrt(2025), "\n";  # 20+25 :O

=head1 DESCRIPTION

=head2 Algorithm

There are two classes of binary search algorithm: the left
bisection method and right bisection method.  Naively, they
deal with two classes of monotonic boolean-valued functions,
otherwise known as predicates.  Namely, call such a predicate
C<ok>.  Then:

=over 4

=item *

Left bisection assumes that the predicate is B<increasing>.
That is, if C<ok(x)> is true, then C<ok(y)> is true for all
C<< y >= x >>; and if C<ok(y)> is false, then C<ok(x)> is false
for all C<< x >= y >>.  Visually, the image of the predicate
looks like:

   F F F ... F T T T   ok(x)
   1 2 3     6 7 8 9      x

where there exists a unique point of true's I<first> occurrence.

=item *

Right bisection assumes that the predicate is B<decreasing>.
That is, if C<ok(x)> is false, then C<ok(y)> is false for all
C<< y >= x >>; and if C<ok(y)> is true, then C<ok(x)> is true
for all C<< x >= y >>.  Visually, the image of the predicate
looks like:

   T T T ... T F F F   ok(x)
   1 2 3     6 7 8 9      x

where there exists a unique point of true's I<last> occurrence.

=back

Given the predicate C<ok> and the bounds C<lo> and C<hi>, each
algorithm attempts to find that unique point respectively.

To ensure the return value is mathematically consistent at
all times, it is assumed that at least one point satisfies
the predicate.  Namely,

=over 4

=item *

Given C<[$lo, $hi]> as its input, the left bisection method
assumes that C<< $ok->($hi) >> to true, and searches on the
half-open interval C<[$lo, $hi)> (that is, C<< $ok->($hi) >>
is never actually checked).  When it cannot find any truth
there, it returns C<$hi> as a last resort.  The order passed
to the function is what you would expect:

   bisectl { ok } $lo, $hi

Commonly for arrays, you would set C<$hi> to the length,
which is one past the final index:

   bisectl { ok($list[$_]) } 0, @list

This checks array elements at index C<0> up to C<@list-1> only,
and returns C<@list> as a last resort.  You may also omit C<0>
here as it is the default C<$lo> for left-search functions.

=item *

Given C<[$lo, $hi]> as its input, the right bisection method
assumes that C<< $ok->($lo) >> to true, and searches on the
half-open interval C<($lo, $hi]>.  When it cannot find any
truth there, it returns C<$hi> as a last resort.  The order
passed to the function is reversed:

   bisectr { ok } $hi, $lo

This time, you might set C<$lo> to C<-1>, which is one less
than the initial index:

   bisectr { ok($list[$_]) } $#list, -1

This checks array elements at index C<$#list> down to C<0> only,
and returns C<-1> as a last resort.  You may also omit C<-1>
here as it is the default C<$lo> for right-search functions.

=back

=head2 Input forms

The first argument is always a callback, which can be passed
using any syntax permitted by the C<&> prototype.  Notably, the
callback may be given as a block, similar to
L<sort BLOCK|perlfunc/sort> and L<grep BLOCK|perlfunc/grep>.
The callback receives its argument from L<$_|perlvar/$_>,
the default variable.  Its exact value is dependent on the
input forms explained below.

Input can be divided into three forms: index, ARRAY, and CODE.

In the index form (demonstrated above), the function takes 2 to 3
arguments, including

=head2 Output forms

=cut

# Parse input arguments.
#    $ori:  search orientation (1 for left, 0 for right)
#    $args: arguments from caller
# Return:
#    (1, $fun, $map, $lo, $hi)   for ARRAY/CODE form;
# and
#    (0, $fun,       $lo, $hi)   for index form.
# where $fun is a predicate or an ordering, $map
# On parse failure, return nothing and set $@.
sub parse_args
{
	my $ori = shift;
	my $args = shift;
	if (@$args < 2) {
		my $nargs = @$args;
		$@ = <<EOM
not enough arguments (expected at least 2, got $nargs)
EOM
		return;
	}
	my ($fun, $arg) = splice(@$args, 0, 2)
	my ($lo, $hi);
	# If it is a normal ARRAY ref or a blessed
	# ARRAY ref, map its index to its elements.
	# <https://stackoverflow.com/a/64160/19411800>
	if (UNIVERSAL::isa($arg, 'ARRAY')) {
		if (@$args > 2) {
			my $nargs = @$args + 2;
			$@ = <<EOM
too many arguments for ARRAY form (expected at most 4, got $nargs)
EOM
			return;
		}
		($lo, $hi) = @_;
		if ($ori) {
			# Left search
			defined $lo or $lo = $[;
			defined $hi or $hi = $[ + @$arg;
		}
		else {
			# Right search
			defined $lo or $lo = $#$arg;
			defined $hi or $hi = $[ - 1;
		}
		(1, $fun, sub { \$arg->[$_] }, $lo, $hi)
	}
	elsif (UNIVERSAL::isa($arg, 'CODE')) {
		if (@$args < 1) {
			my $nargs = @$args + 2;
			$@ = <<EOM
not enough arguments for CODE form (expected at least 3, got $nargs)
EOM
			return;
		}
		if (@$args > 2) {
			my $nargs = @$args + 2;
			$@ = <<EOM
too many arguments for CODE form (expected at most 4, got $nargs)
EOM
			return;
		}
		if (@_ > 2) {
			($lo, $hi) = (@$args);
		}
		else {
			my $arg = shift @$args;
			($lo, $hi) = $ori ? (0, $arg) : ($arg, -1);
		}
		(1, $fun, $arg, $lo, $hi)
	}
	else {
		if (@$args > 1) {
			my $nargs = @$args + 2;
			$@ = <<EOM
too many arguments for index form (expected at most 3, got $nargs)
EOM
			return;
		}
		if (@_) {
			($lo, $hi) = ($arg, @$args);
		}
		else {
			($lo, $hi) = $ori ? (0, $arg) : ($arg, -1);
		}
		(0, $fun, $lo, $hi)
	}
}

# Assumption: If $ok->($x) true, $x <= $y => $ok->($y) true.
# Invariant:  - $ok attains truth somewhere on [ $lo, $hi ].
#             - If $x < $lo,  $ok->($x) is false if defined.
sub __bisectl
{
	my ($ok, $lo, $hi) = @_;
	my ($cmp, $res, $elt, $mid);
	my $want2 = wantarray and want(2);
	my $want3 = wantarray and want(3);
	while ($lo < $hi) {
		$mid = $lo + (($hi - $lo) >> 1);
		if (do { local *_ = \$mid; $res = $ok->() }) {
			$hi = $mid;      # include
			$cmp = $res  if $want2;
			$elt = $mid  if $want3;
		} else {
			$lo = $mid + 1;  # exclude
		}
	} $want2 ? ($hi, $cmp, $elt) : $hi
}

# Assumption: If $ok->($y) true, $x <= $y => $ok->($x) true.
# Invariant:  - $ok attains truth somewhere on [ $lo, $hi ].
#             - If $x > $hi,  $ok->($x) is false if defined.
sub __bisectr
{
	my ($ok, $hi, $lo) = @_;
	my ($cmp, $res, $elt, $mid);
	my $want2 = wantarray and want(2);
	my $want3 = wantarray and want(3);
	while ($lo < $hi) {
		$mid = $lo + (($hi - $lo + 1) >> 1);
		if (do { local *_ = \$mid; $res = $ok->() }) {
			$lo = $mid;      # include
			$cmp = $res  if $want2;
			$elt = $mid  if $want3;
		} else {
			$hi = $mid - 1;  # exclude
		}
	} $want2 ? ($lo, $cmp, $elt) : $lo
}

# Similar guys, except there is an MAP in the middle...
# Predicate is still the basis of comparison, but element
# is mapped from the index instead of just the index.
sub __bisectl_map
{
	my ($ok, $map, $lo, $hi) = @_;
	my ($cmp, $res, $elt, $img, $mid);
	my $want2 = wantarray and want(2);
	my $want3 = wantarray and want(3);
	while ($lo < $hi) {
		$mid = $lo + (($hi - $lo) >> 1);
		$img = $map->($mid);
		if (do { local *_ = $img; $res = $ok->() }) {
			$hi = $mid;      # include
			$cmp = $res  if $want2;
			$elt = $$img if $want3;
		} else {
			$lo = $mid + 1;  # exclude
		}
	} $want2 ? ($hi, $cmp, $elt) : $hi
}

sub __bisectr_map
{
	my ($ok, $map, $hi, $lo) = @_;
	my ($cmp, $res, $elt, $img, $mid);
	my $want2 = wantarray and want(2);
	my $want3 = wantarray and want(3);
	while ($lo < $hi) {
		$mid = $lo + (($hi - $lo + 1) >> 1);
		$img = $map->($mid);
		if (do { local *_ = $img; $res = $ok->() }) {
			$lo = $mid;      # include
			$cmp = $res  if $want2;
			$elt = $$img if $want3;
		} else {
			$hi = $mid - 1;  # exclude
		}
	} $want2 ? ($lo, $cmp, $elt) = $lo
}

# Binary left search for a trisection point on a
# total ordering.  This time, the predicate $ok
# is pre-determined (>=0 or >0), but the ordering
# and mapping may vary.  We return the images of
# these two maps as they may be expensive to compute.
sub __blsrch_map
{
	my ($ok, $ord, $map, $lo, $hi) = @_;
	my ($cmp, $res, $elt, $img, $mid);
	my $want2 = wantarray and want(2);
	my $want3 = wantarray and want(3);
	while ($lo < $hi) {
		$mid = $lo + (($hi - $lo) >> 1);
		$img = $map->($mid);
		if (do { local *_ = $img; $ok->($res = $ord->()) }) {
			$hi = $mid;       # include
			$cmp = $res   if $want2;
			$elt = $$img  if $want3;
		} else {
			$lo = $mid + 1;   # exclude
		}
	} $want2 ? ($hi, $cmp, $elt) : $hi
}

# Binary right search, similarly...
sub __brsrch_map
{
	my ($ok, $ord, $map, $hi, $lo) = @_;
	my ($cmp, $res, $elt, $img, $mid);
	my $want2 = wantarray and want(2);
	my $want3 = wantarray and want(3);
	while ($lo < $hi) {
		$mid = $lo + (($hi - $lo + 1) >> 1);
		$img = $map->($mid);
		if (do { local *_ = $img; $ok->($res = $ord->()) }) {
			$lo = $mid;       # include
			$cmp = $res   if $want2;
			$elt = $$img  if $want3;
		} else {
			$hi = $mid - 1;   # exclude
		}
	} $want2 ? ($hi, $cmp, $elt) : $hi
}

sub __blsrch
{
	my ($ok, $ord, $lo, $hi) = @_;
	__blsrch_map($ok, $ord, sub { $_ }, $lo, $hi);
}

sub __brsrch
{
	my ($ok, $ord, $hi, $lo) = @_;
	__brsrch_map($ok, $ord, sub { $_ }, $hi, $lo);
}

=head1 DESCRIPTION

Given a monotonic predicate.

=head2 bisectl

Return.

=cut

sub bisectl (&$;$$)
{
	local $@;
	my ($vari, @args) = parse_args(1, \@_) or croak("bisectl: $@");
	$vari ? __bisectl_map(@args) : __bisectl(@args)
}

1;
