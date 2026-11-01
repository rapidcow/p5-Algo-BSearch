package RdKw::Algo::BSearch;

our $VERSION = '0.00_00';
$VERSION = eval $VERSION;

=pod

=head1 NAME

Algo::BSearch - binary search on contiguous monotonic ranges

=cut

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

=head1 SYNOPSIS

   use RdKw::Algo::BSearch qw(
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
    my $hi = bisectl { ($_ <=> 5) >  0 } \@list;

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

    my $lo = bisectr { (5 <=> $_) >= 0 } \@list;
    my $hi = bisectr { (5 <=> $_) >  0 } \@list;

Notably, to acquire bounds that are inclusive on both
ends, you'd have to utilize search in both directions:

    my $lo = blsrch0 { $_ <=> 5 } \@list;  # 6
    my $hi = brsrch0 { 5 <=> $_ } \@list;  # 8

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
       elsif ($cmp != 0)  { print "$want not found; the best "
                                . "I got was $elt at [$idx]\n"; }
       else               { print "$want found at [$idx] :)\n"; }
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

Let C<$ok> denote the predicate, and set C<< $ok->($hi) = 1 >>.
The return value of C<bisectl> is the unique index C<$x> on the
closed interval C<[$lo, $hi]> such that:

=over 4

=item *

C<< $ok->($x) >> is true.

=item *

For all valid index C<< $y < $x >>, it follows that C<< $ok->($y) >> is false.

=back

The return value of C<bixectl> is any index satisfying the first constraint.

If the interval C<[$lo, $hi]> is empty, return C<$hi>.

=cut

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

=item B<bisectr>

=item B<bixectr>

Perform right bisection with respect to a predicate on the half-open
interval C<($lo, $hi]>, where C<$hi> precedes C<$lo> in the argument
array.  The prototype is C<&$;$$>.

The predicate should be decreasing over every pair of adjacent indices
it is defined on.  That is, true values always precede false values:

   T T T ... T F F F   ok(x)
   1 2 3     6 7 8 9      x

Let C<$ok> denote the predicate, and set C<< $ok->($lo) = 1 >>.
The return value of C<bisectr> is the unique index C<$x> on the
closed interval C<[$lo, $hi]> such that:

=over 4

=item *

C<< $ok->($x) >> is true.

=item *

For all valid index C<< $y > $x >>, it follows that C<< $ok->($y) >> is false.

=back

The return value of C<bixectr> is any index satisfying the first constraint.

If the interval C<[$lo, $hi]> is empty, return C<$lo>.

=back

In general, a return value of C<$hi> (for left search) and
C<$lo> (for right search) is not meaningful as it is the only
index taken to be true for granted.  Caller should handle it
separately, or check if the comparison indicator and/or element
are defined by calling in list context.

=cut

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

=over 4

=item B<blsrch0>

=item B<blsrchx>

=item B<blsrch1>

=item B<blsrch2>

Perform binary left search with respect to an ordering on the
half-open interval C<[$lo, $hi)>, where C<$lo> precedes C<$hi>
in the argument array.  The prototype is C<&$;$$>.

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

=over 4

=item *

C<< $ord->($lower) >= 0 >>.

=item *

For all valid index C<< $x < $lower >>, it follows that C<< $ord->($x) < 0 >>.
As a result, C<< $lower >> is the first instance where C<< $ord >= 0 >>,
while C<< $lower - 1 >> is the last instance where C<< $ord < 0 >>.
(Compare this to C<brsect1>.)

=back

The return value of C<blsectx> is any index satisfying
C<< $ord == 0 >>, but if one could not be found,
it returns the same result as C<blsect0>.

The return value of C<blsect1> is the unique index C<$upper_x>
on the closed interval C<[$lo, $hi]> such that:

=over 4

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

=cut

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

=item B<brsrch0>

=item B<brsrchx>

=item B<brsrch1>

=item B<brsrch2>

Perform binary right search with respect to an ordering on the
half-open interval C<($lo, $hi]>, where C<$hi> precedes C<$lo>
in the argument array.  The prototype is C<&$;$$>.

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

=over 4

=item *

C<< $ord->($upper) >= 0 >>.

=item *

For all valid index C<< $x > $upper >>, it follows that C<< $ord->($x) < 0 >>.
As a result, C<< $upper >> is the last instance where C<< -$ord <= 0 >> and
C<< $upper + 1 >> is the first instance where C<< -$ord > 0 >>.
(Compare this to C<blsect1>.)

=back

The return value of C<brsectx> is any index satisfying
C<< $ord == 0 >>, but if one could not be found,
it returns the same result as C<brsect0>.

The return value of C<brsect1> is the unique index C<$lower> on
the closed interval C<[$lo, $hi]> such that:

=over 4

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

=cut

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

=back

One may speculate that the bounds satisfy the mathematical
relationship:

    $upper == $upper_x - 1
    $lower_x + 1 == $lower

provided that the search ranges in both cases cover the same
indices.  But this is mostly an empirical observation; at
the moment I am unable to prove that it is the case.... ;)

=cut

1;
