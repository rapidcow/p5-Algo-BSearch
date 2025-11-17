package FastLook;
use 5.006;
use strict;
use warnings;

use Carp;
BEGIN {
	# We can avoid copying array elements if this is the case?
	# It's okay if we don't find Want, 'wantarray and want(...)'
	# will reduce to just wantarray in that case...
	eval { require Want; Want->import('want') };
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

use Exporter ();
use vars qw(@ISA @EXPORT_OK);
BEGIN {
	@ISA = qw(Exporter);
	@EXPORT_OK = qw(
		bisectl bisectr bixectl bixectr
		blsrch0 brsrch0 blsrch1 brsrch1
		blsrch2 brsrch2 blsrchx brsrchx
	);
}

=head1 SYNOPSIS

   use FastLook qw(
       bisectl bisectr bixectl bixectr
       blsrch0 brsrch0 blsrch1 brsrch1
       blsrch2 brsrch2 blsrchx brsrchx
   );

   # Input forms (left bisection)
   bisectl { ok($idx = $_) } [\&fun,]$hi; # $lo //= 0
   bisectl { ok($idx = $_) } [\&fun,]$lo, $hi;
   bisectl { ok($elt = $_) } \@list;      # $lo //= $[
   bisectl { ok($elt = $_) } \@list, $lo; # $hi //= 1 + $#$list
   bisectl { ok($elt = $_) } \@list, $lo, $hi;

   # Input forms (right bisection)
   bisectr { ok($idx = $_) } [\&fun,]$hi; # $lo //= -1
   bisectr { ok($idx = $_) } [\&fun,]$hi, $lo;
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

The Guessing Game given in L<sort/search.go|https://go.dev/src/sort/search.go>
can be defined as follows:

   print STDERR "Pick an integer from 0 to 100.\n";
   my $answer = bisectl {
       print STDERR "Is your number <= $_? ";
       my $s = <STDIN>
       $s or return;
       chomp $s;
       $s eq 'y'
   } 0, 100;
   print STDERR "Your number is $answer.\n";

   __END__
   Pick an integer from 0 to 100.
   Is your number <= 50? y
   Is your number <= 25? n
   Is your number <= 38? n
   Is your number <= 44? n
   Is your number <= 47? y
   Is your number <= 46? y
   Is your number <= 45? y
   Your number is 45.

=head1 DESCRIPTION

=head2 Bisection algorithm

This section applies to the C<bisect*> and C<bixect*> subroutines:

   bisectl  bixectl
   bisectr  bixectr

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
the predicate.  This is the model employed by C<bisectl>
and C<bisectr>.  Namely,

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

This time, you might set C<$lo> to C<-1>, which is one below
the initial index:

   bisectr { ok($list[$_]) } $#list, -1

This checks array elements at index C<$#list> down to C<0> only,
and returns C<-1> as a last resort.  You may also omit C<-1>
here as it is the default C<$lo> for right-search functions.

=back

We will refer to the range of real, concrete index as the
I<search range>, which is C<[$lo, hi)> for left search and
C<($lo, $hi]> for right search.  While the possible return
values always lies on the closed interval C<[$lo, $hi]>,
the search range is a half-open interval, whose exclusive
endpoint depends on the search algorithm.  As a basic sanity
check you may check if the index lies in the search range to
see if the search actually found anything, but see
L</"Output forms"> for more robust forms of error checking.

For each function above a variant is also provided by
replacing the s with an x:

   bisectl -> bixectl
   bisectr -> bixectr

The constraint is relaxed in that the index returned
need not be the first nor the last true index: I<any>
truth found on the half-open interval will be immediately
returned.  (Mnemonic: the x stands for eXists.)

=head2 Search algorithm

This section applies to the C<blsrch*> and C<brsrch*> subroutines:

   blsrch0  brsrch0
   blsrch1  brsrch1
   blsrch2  brsrch2
   blsrchx  brsrchx

More commonly, binary search is employed not on booleans,
but on ordered collection of elements.  The search is then
done with respect to an ordering instead of a predicate.

The ordering is reflected by the trichotomous state of
a numeric indicator, identified by being C<< <0 >> (negative),
C<=0> (zero), C<< >0 >> (positive), similar to that returned
by the C<< <=> >> and C<cmp> operators.  A predicate is then
composed on this ordering to yield the familiar boolean
image from the previous section, where the same algorithm
is employed.  Let C<$_> denote this numerical ordering
indicator.  The predicate is chosen based on the suffix
of the search function:

=over 4

=item *

For the suffix 0, the predicate is C<< $_ >= 0 >>.

=item *

For the suffix 1, the predicate is C<< $_ > 0 >>.

=item *

For the suffix x, the search is performed as if the predicate
is C<< $_ >= 0 >>, however it is short-circuited to return at
the sight of any C<$_ == 0>.

=back

To see this more concretely, consider an increasing array of numbers:

   [1, 1, 2, 3, 3, 4, 5, 5, 5, 6, 8, 9, 9]   @list

We wish to know the first and last occurrence of the number 5.
One first approach is to define the ordering C<< $_ <=> 5 >>,
then apply the predicates C<< $_ >= 0 >> and C<< $_ > 0 >>:

   [1, 1, 2, 3, 3, 4, 5, 5, 5, 6, 8, 9, 9]   @list
                     |
		     | $_ <=> 5            ordering
                     v
   -1 -1 -1  ...  -1  0  0  0  1  1  ...
                     |
		     | $_ >= 0             predicate 0
		     | $_ >  0             predicate 1
                     v
    F  F  F  ...   F (T) T  T  T  T  ...
    F  F  F  ...   F  F  F  F (T) T  ...
    --------------------------------------
    0  1  2        5 [6  7  8 ]9  10 ...     index

Run left bisection on the final two boolean images gives
us the asymmetrical bounds 6 (inclusive) and 9 (exclusive).
That is, we know 6,7,8 are all indices at which the array
attains 5.  The corresponding code that could produce these
bounds is:

    my $lo = bisectl { $_ >= 5 } \@list;   # 6
    my $hi = bisectl { $_ >  5 } \@list;   # 9

Or, using the search algorithm:

    my $lo = blsrch0 { $_ <=> 5 } \@list;  # 6
    my $hi = blsrch1 { $_ <=> 5 } \@list;  # 9

which is equivalent to:

    my $lo = bisectl { ($_ <=> 5) >= 0 } \@list;
    my $hi = bisectl { ($_ <=> 5) >= 0 } \@list;

Another approach is to use the C<< 5 <=> $_ >> ordering,
apply the same predicates, but run right bisection instead:

   [1, 1, 2, 3, 3, 4, 5, 5, 5, 6, 8, 9, 9]   @list
                     |
		     | 5 <=> $_            ordering
                     v
    1  1  1  ...   1  0  0  0 -1 -1  ...
                     |
		     | $_ >= 0             predicate 0
		     | $_ >  0             predicate 1
                     v
    T  T  T  ...  (T) F  F  F  F  F  ...
    T  T  T  ...   T  T  T (T) F  F  ...
    --------------------------------------
    0  1  2        5[ 6  7  8] 9  10 ...     index

This gives us the asymmetrical bounds 5 (exclusive) and
8 (inclusive) for the indices at which the array attains 5.
The code that could produce these bounds is:

    my $lo = bisectr { 5 >= $_ } \@list;   # 5
    my $hi = bisectr { 5 >  $_ } \@list;   # 8

Or, using the search algorithm:

    my $lo = brsrch0 { 5 <=> $_ } \@list;  # 5
    my $hi = brsrch1 { 5 <=> $_ } \@list;  # 8

which is equivalent to:

    my $lo = bisectr { ($_ <=> 5) >= 0 } \@list;
    my $hi = bisectr { ($_ <=> 5) >  0 } \@list;

Notably, to acquire bounds that are inclusive on both
ends, you'd have to utilize search in both directions:

    my $lo = blsrch0 { $_ <=> 5 } \@list;  # 6
    my $hi = brsrch1 { 5 <=> $_ } \@list;  # 8

or offset the exclusive bound by 1 (only if you must avoid right search...)

    my $lo = blsrch0 { $_ <=> 5 } \@list;  # 6
    my $hi = blsrch1 { $_ <=> 5 } \@list;  # 9
    $hi--;     # now it is 8 and correct :)

Note that you would also have to reverse the ordering
if the array was decreasing instead.

The ordering to use can be summarized as follows:

                     SORT ORDERING?
    ORIEN-  | f(i) <= f(i+1)  f(i) >= f(i+1)
    TATION? |  (increasing)    (decreasing)
   ---------+--------------------------------
     left   |  $want <=> $_    $_ <=> $want
     right  |  $_ <=> $want    $want <=> $_

=head2 Input forms

The first argument is always a callback, which can be passed
using any syntax permitted by the C<&> prototype.  Notably, the
callback may be given as a block, similar to
L<sort BLOCK|perlfunc/sort> and L<grep BLOCK|perlfunc/grep>.

The callback receives its argument from L<$_|perlvar/$_>,
the default variable.  Its exact argument is dependent on the
input forms explained below: for index form, it is simply the
index itself.  For ARRAY and CODE form, it is the array element,
or function image, at the given index.  In either case, the
function shall receive the index as the sole argument of
L<@_|perlvar/@_>.  (This may be useful for identifying elements
in an array of otherwise indistinguishable elements.)

Regarding the return value, the callback should behave like
a I<predicate> that meets the assumption described in
L</"Bisection algorithm"> for C<bisect*> and C<bixect*>, or
an I<ordering> that meets the assumption described in
L</"Search algorithm"> for C<blsrch*> and C<brsrch*>.

Input from here can be divided into three forms:
index, ARRAY, and CODE.  The C<$> prototype is used; that is,
you can write C<0, @list> instead of C<0, scalar(@list)>
in the case of searching on an array.
Common across all forms,
a pair of bounds C<($lo, $hi)> will be determined for
the low-level bisection algorithms.
The exact order is dependent on the search algorithm
being employed: for left search, C<$lo> precedes C<$hi>.
For right search, C<$hi> precedes C<$lo>.

In the index form, the function takes 2 to 3 arguments
(including the callback).  When passed 2 arguments, C<$hi>
is set to the second argument, and C<$lo> is inferred
depending on the search algorithm being employed.  If it is
a left search, C<$lo = 0>, or else C<$lo = -1>.
This form is tried last if the second argument is neither
an ARRAY ref nor a CODE ref, but in principle you should
be only passing a scalar (number) for both the second and
the third argument.

In the ARRAY form, the function takes 2 to 4 arguments
(including the callback).  When passed 2 to 3 arguments,
both or one of C<$lo> and C<$hi> are inferred, depending
on the search algorithm being employed.

=over 4

=item *

If passed 2 arguments, then both bounds are implicit.
For left search, C<$lo> is set to the initial index of
an array (C<$[>), and C<$hi> to one past the final index
(C<$#list + 1>).  For right search, C<$hi> is set to the
final index (C<$#list>), and C<$lo> is set to one below
the initial index (C<-1>).

=item *

If passed 3 arguments, then the "end" bound is implicit.
For left search, C<$lo> is set to the second argument,
and C<$hi> is set according to the rules above.  For right
search, C<$hi> is set to the second argument, and C<$lo>
is set according to the rules above.

=back

Note that under Perl's default 0-based array indexing,
C<$[ == 0>, C<$#list + 1 == @$list>, and C<$[ - 1 = -1>.

In the CODE form, the function takes 3 to 4 arguments
(including the callback), and arguments 3--4 are processed
in the same way arguments 2--3 are processed in the
index form.  Note that the CODE should return a reference
to the image element for glob aliasing to work.  If the
element itself is an ARRAY/HASH ref, it should be a ref
to that ARRAY/HASH ref.

=cut

# Parse input arguments.
#    $ori:  search orientation (1 for left, 0 for right)
#    $args: arguments from caller
# Return:
#    ($fun, undef, $beg, $end)   for ARRAY/CODE form;
# and
#    ($fun, $map,  $beg, $end)   for index form.
# where $fun is a predicate or an ordering, $map
# On parse failure, return nothing and set $@.
sub parse_args
{
	my $ori = shift;
	my $args = shift;
	if (@$args < 2) {
		my $nargs = @$args;
		$@ = <<EOM;
not enough arguments (expected at least 2, got $nargs)
EOM
		return;
	}
	my ($fun, $arg) = splice(@$args, 0, 2);
	my ($beg, $end);
	# If it is a normal ARRAY ref or a blessed
	# ARRAY ref, map its index to its elements.
	# <https://stackoverflow.com/a/64160/19411800>
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
			defined $lo or $hi = $[;
			defined $lo or $hi = 1 + $#$arg;
			($beg, $end) = ($lo, $hi);
		}
		else {
			# Right search ($beg, $end) = ($hi, $lo)
			my ($hi, $lo) = @$args;
			defined $hi or $hi = $#$arg;
			defined $lo or $lo = $[ - 1;
			($beg, $end) = ($hi, $lo);
		}
		($fun, sub { \$arg->[$_] }, $beg, $end)
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
		if (@_ > 2) {
			($beg, $end) = (@$args);
		}
		else {
			my $arg = shift @$args;
			($beg, $end) = $ori ? (0, $arg) : ($arg, -1);
		}
		($fun, $arg, $beg, $end)
	}
	else {
		if (@$args > 1) {
			my $nargs = @$args + 2;
			$@ = <<EOM;
too many arguments for index form (expected at most 3, got $nargs)
EOM
			return;
		}
		if (@$args) {
			unshift @$args, $arg;
			($beg, $end) = (@$args);
		}
		else {
			($beg, $end) = $ori ? (0, $arg) : ($arg, -1);
		}
		($fun, undef, $beg, $end)
	}
}

=head2 Output forms

In scalar context all functions (excluding C<blsrch2> and
C<brsrch2>) return the index they found, possibly a last-resort
index lying beyond the search range.  This is, admittedly, not
the most helpful for searching when the match ought to be exact,
not just satisfying a monotonic predicate.  In list context,
therefore, these functions return parameters that may be
of more help.  One may use the mnemonic ICE for the order of
these parameters: index, comparison indicator, and element.

The comparison indicator is the return value of the predicate
or ordering function at this index, depending on whether this
is a bisection or a binary search algorithm.  If this index is
a last-resort index lying beyond the search range, this value
is C<undef>.  The element is the value passed to the previously
described predicate or ordering function at the same index,
or C<undef> too if the index is a last-resort index.

To find the first element I<equal> to a target value, not just
equal to or greater than it, you can therefore do this:

    sub search {
        my ($array, $want) = @_;
	my ($idx, $cmp, $elt) = blsrch0 { $_ <=> $want } $array;
        if (!defined $cmp) { print "$want not found anywhere\n"; }
        elsif ($cmp == 0)  { print "$want not found; the best "
                                 . "I got was $elt at [$idx]\n"; }
        else               { print "$want found at $idx :)"; }
    }

    my $list = [1, 1, 2, 3, 3, 4, 5, 5, 5, 6, 8, 9, 9];
    search $list => 5;
    search $list => 7;
    search $list => 10;

This should print:

    5 found at [6] :)
    7 not found; the best I got was 8 at [10]
    10 not found anywhere

If you are fine with finding any element equal to it, you can
substitute C<blsrch0> with C<blsrchx> or C<brsrchx>.  Note
that the same checks are still necessary to ensure that the
result is meaningful.

=cut

=head2 Subroutines

The following is a summary of all the subroutines provided
by this package.  All subroutines are exported on demand
only.

=over 4

=item B<bisectl>

=item B<bixectl>

Perform left bisection with respect to a predicate on the half-open
interval C<[$lo, $hi)>, where C<$lo> precedes C<$hi> in the argument
array.  The prototype is C<&$;$$>.

The predicate should be increasing over every pair of adjacent indices
it is defined on.  That is, true values always follow false values:

   F F F ... F T T T   ok(x)
   1 2 3     6 7 8 9      x

Set C<< $ok->($hi) = 1 >>.  The return value of C<bisectl> is the
unique index C<$x> on the closed interval C<[$lo, $hi]> such that:

=over 4

=item *

C<< $ok->($x) >> is true.

=item *

For all valid index C<< $y < $x >>, it follows that C<< $ok->($y) >> is false.

=back

The return value of C<bixectl> is any index satisfying the first constraint.
It is guaranteed to be consistent across invocations due to the nature of
binary search.

If the interval C<[$lo, $hi]> is empty, return C<$hi>.

=cut

# Assumption: If $ok->($x) true, $x <= $y => $ok->($y) true.
# Invariant:  - $ok attains truth somewhere on [ $lo, $hi ].
#             - If $x < $lo,  $ok->($x) is false if defined.
sub bisectl_map
{
	my ($any, $ok, $map, $lo, $hi) = @_;
	my ($cmp, $res, $elt, $img, $mid);
	my $want2 = wantarray and want(2);
	my $want3 = wantarray and want(3);
	while ($lo < $hi) {
		$mid = $lo + (($hi - $lo) >> 1);
		$img = $map ? $map->($mid) : \$mid;
		if (do { local *_ = $img; $res = $ok->($mid) }) {
			$hi = $mid;      # include
			$cmp = $res  if $want2;
			$elt = $$img if $want3;
			last if $any;
		} else {
			$lo = $mid + 1;  # exclude
		}
	} $want2 ? ($hi, $cmp, $elt) : $hi
}

sub bisectl (&$;$$)
{
	local $@;
	my @args = parse_args(1, \@_) or croak("bisectl: $@");
	bisectl_map(0, @args)
}

sub bixectl (&$;$$)
{
	local $@;
	my @args = parse_args(1, \@_) or croak("bixectl: $@");
	bisectl_map(1, @args)
}

=item B<bisectr>

=item B<bixectr>

Perform right bisection with respect to a predicate on the half-open
interval C<($lo, $hi]>, where C<$hi> precedes C<$lo> in the argument
array.  The prototype is C<&$;$$>.

The predicate should be decreasing over every pair of adjacent indices
it is defined on.  That is, true values always precede false values:

   T T T ... T F F F   ok(x)
   1 2 3     6 7 8 9      x

Set C<< $ok->($lo) = 1 >>.  The return value of C<bisectr> is the
unique index C<$x> on the closed interval C<[$lo, $hi]> such that:

=over 4

=item *

C<< $ok->($x) >> is true.

=item *

For all valid index C<< $y > $x >>, it follows that C<< $ok->($y) >> is false.

=back

The return value of C<bixectr> is any index satisfying the first constraint.
It is guaranteed to be consistent across invocations due to the nature of
binary search.

If the interval C<[$lo, $hi]> is empty, return C<$lo>.

=back

In general, a return value of C<$hi> (for left search) and
C<$lo> (for right search) is not meaningful as it is the only
index taken to be true for granted.  Caller should handle it
separately, or check if the comparison indicator and/or element
are defined by calling in list context.

=cut

# Assumption: If $ok->($y) true, $x <= $y => $ok->($x) true.
# Invariant:  - $ok attains truth somewhere on [ $lo, $hi ].
#             - If $x > $hi,  $ok->($x) is false if defined.
sub bisectr_map
{
	my ($any, $ok, $map, $hi, $lo) = @_;
	my ($cmp, $res, $elt, $img, $mid);
	my $want2 = wantarray and want(2);
	my $want3 = wantarray and want(3);
	while ($lo < $hi) {
		$mid = $lo + (($hi - $lo + 1) >> 1);
		$img = $map ? $map->($mid) : \$mid;
		if (do { local *_ = $img; $res = $ok->($mid) }) {
			$lo = $mid;      # include
			$cmp = $res  if $want2;
			$elt = $$img if $want3;
			last if $any;
		} else {
			$hi = $mid - 1;  # exclude
		}
	} $want2 ? ($lo, $cmp, $elt) : $lo
}

sub bisectr (&$;$$)
{
	local $@;
	my @args = parse_args(0, \@_) or croak("bisectr: $@");
	bisectr_map(0, @args)
}

sub bixectr (&$;$$)
{
	local $@;
	my @args = parse_args(0, \@_) or croak("bixectr: $@");
	bisectr_map(1, @args)
}

# Binary left search for a trisection point on a
# total ordering.  This time, the predicate $ok
# is pre-determined (>=0 or >0), but the ordering
# and mapping may vary.  We return the images of
# these two maps as they may be expensive to compute.
sub blsrch_map
{
	my ($any, $ok, $ord, $map, $lo, $hi) = @_;
	my ($cmp, $res, $elt, $img, $mid);
	my $want2 = wantarray and want(2);
	my $want3 = wantarray and want(3);
	while ($lo < $hi) {
		$mid = $lo + (($hi - $lo) >> 1);
		$img = $map ? $map->($mid) : \$mid;
		if (do { local *_ = $img; $ok->($res = $ord->($mid)) }) {
			$hi = $mid;       # include
			$cmp = $res   if $want2;
			$elt = $$img  if $want3;
			last if $any and $res == 0;
		} else {
			$lo = $mid + 1;   # exclude
		}
	} $want2 ? ($hi, $cmp, $elt) : $hi
}

sub blsrch0 (&$;$$)
{
	local $@;
	my @args = parse_args(1, \@_) or croak("blsrch0: $@");
	blsrch_map(0, sub { $_[0] >= 0 }, @args);
}

sub blsrch1 (&$;$$)
{
	local $@;
	my @args = parse_args(1, \@_) or croak("blsrch0: $@");
	blsrch_map(0, sub { $_[0] > 0 }, @args);
}

sub blsectx (&$;$$)
{
	local $@;
	my @args = parse_args(1, \@_) or croak("blsrctr: $@");
	blsrch_map(1, sub { $_[0] >= 0 }, @args);
}

# Binary right search, similarly...
sub brsrch_map
{
	my ($any, $ok, $ord, $map, $hi, $lo) = @_;
	my ($cmp, $res, $elt, $img, $mid);
	my $want2 = wantarray and want(2);
	my $want3 = wantarray and want(3);
	while ($lo < $hi) {
		$mid = $lo + (($hi - $lo + 1) >> 1);
		$img = $map ? $map->($mid) : \$mid;
		if (do { local *_ = $img; $ok->($res = $ord->($mid)) }) {
			$lo = $mid;       # include
			$cmp = $res   if $want2;
			$elt = $$img  if $want3;
			last if $any and $res == 0;
		} else {
			$hi = $mid - 1;   # exclude
		}
	} $want2 ? ($hi, $cmp, $elt) : $hi
}

sub brsrch0 (&$;$$)
{
	local $@;
	my @args = parse_args(1, \@_) or croak("blsrch0: $@");
	blsrch_map(0, sub { $_[0] >= 0 }, @args);
}

sub brsrch1 (&$;$$)
{
	local $@;
	my @args = parse_args(1, \@_) or croak("blsrch0: $@");
	blsrch_map(0, sub { $_[0] > 0 }, @args);
}

sub brsrchx (&$;$$)
{
	local $@;
	my @args = parse_args(1, \@_) or croak("brsrchx: $@");
	blsrch_map(1, sub { $_[0] >= 0 }, @args);
}

# Because we don't really care about the intermediate values
# themselves, (or be able to return them, for that matter),
# we can get away with using bisect instead of b*srch... :)
sub blsrch2_map
{
	my ($ord, $map, $lo, $hi) = @_;
	my $lower = bisectl_map(0, sub { &$ord >= 0 }, $map, $lo, $hi);
	# Find a sufficiently close candidate for upper bound,
	# assuming there aren't too many equal values around?
	my ($prev, $next) = ($lower, $lower);
	for (my $step = 1; $next + $step < $hi; $step += $step) {
		($prev, $next) = ($next, $next + $step);
		my $img = $map ? $map->($next) : \$next;
		# Strictly speaking, we only have to check for != 0,
		# since if the ordering is well-behaved, it should be
		# nonnegative from this point and on... just saying :P
		last if do { local *_ = $img; $ord->($next) } > 0;
	}
	my $upper = bisectl_map(0, sub { &$ord > 0 }, $map, $prev, $next);
	wantarray ? ($lower, $upper) : $upper - $lower
}

# And the mirror image...
sub brsrch2_map
{
	my ($ord, $map, $hi, $lo) = @_;
	my $lower = bisectr_map(0, sub { &$ord >= 0 }, $map, $hi, $lo);
	my ($prev, $next) = ($lower, $lower);
	for (my $step = 1; $next - $step > $lo; $step += $step) {
		($prev, $next) = ($next, $next - $step);
		my $img = $map ? $map->($next) : \$next;
		last if do { local *_ = $img; $ord->($next) } > 0;
	}
	my $upper = bisectr_map(0, sub { &$ord > 0 }, $map, $prev, $next);
	wantarray ? ($lower, $upper) : $lower - $upper
}

sub blsrch2 (&$;$$)
{
	local $@;
	my @args = parse_args(0, \@_) or croak("blsrch2: $@");
	blsrch2_map(@args);
}

sub brsrch2 (&$;$$)
{
	local $@;
	my @args = parse_args(1, \@_) or croak("brsrch2: $@");
	brsrch2_map(@args);
}

1;
