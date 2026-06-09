#!perl
# t/podtest.t - documentation examples
# (Inspired by Python "doctest" module)
use 5.006;
use strict;
use warnings;
use Test::More tests => 6;

use Sort::Search qw(
	bisectl bisectr
	blsrch0 blsrch1 blsrch2 blsrchx
	brsrch0 brsrch1 brsrch2
);

subtest ('Description :: Orientation variants' => sub {
	plan tests => 4;

	#         F  F  T  T  T
	my @A = ( 0, 1, 2, 3, 4 );
	is +( bisectl { $_ >= 2 } \@A ), 2, "bisectl on increasing predicate";

	#         T   T   T   F   F
	my @B = ( 0, -1, -2, -3, -4 );
	is +( bisectr { $_ >= -2 } \@B ), 2, "bisectr on decreasing predicate";

	#         -  -  0  0  +
	my @p = ( 5, 6, 7, 7, 9 );
	is +( blsrch0 { $_ <=> 7 } \@p ), 2, "blsrch0 on increasing ordering";

	#           +  0  0  -  -
	my @q = qw( x  D  d  c  C );
	is +( brsrch0 { lc($_) cmp 'd' } \@q ), 2, "brsrch0 on decreasing ordering";
});

subtest ('Description :: Lower/upper variants' => sub {
	plan tests => 2;

	my (@a, $lb, $lx, $ub, $ux) = #sort { $a <=> $b }
	#( sprintf("%.13f", 4*atan2(1,1)) =~ /[0-9]/g )[0..12];
	# Floating-point math can be finicky, so
	# I'm just going to define them explicitly
	# here for the test....
		qw( 1 1 2 3 3 4 5 5 5 6 8 9 9 );

	my $x = 5;

	$lb = blsrch0 {$_<=>$x} \@a;  $ux = blsrch1 {$_<=>$x} \@a;  is "[$lb,$ux)", "[6,9)";
	#  (left lower bound)           (left upper bound)          =>  [6,  9  )
	#    first $_ >= $x  -.          ,-  first $_ > $x
	#                      \        /
	#    0  1  2  3  4  5 [6  7  8 [9  a  b  c   index of $_
	#    -  -  -  -  -  -  0  0  0  +  +  +  +   ord ($_ <=> $x)
	#    <<<<<<<<<<<<<<<<<<========------------
	#    1  1  2  3  3  4  5  5  5  6  8  9  9   value of $_
	#    -----------------========>>>>>>>>>>>>>
	#    +  +  +  +  +  +  0  0  0  -  -  -  -   ord ($x <=> $_)
	#    0  1  2  3  4  5] 6  7  8] 9  a  b  c   index of $_
	#                   /        \
	#   last $x > $_  -'          `-  last $x >= $_
	# (right lower bound)            (right upper bound)        =>  (  5,  8]
	$lx = brsrch1 {$x<=>$_} \@a;  $ub = brsrch0 {$x<=>$_} \@a;  is "($lx,$ub]", "(5,8]";
});  # 'Description :: Lower/upper variants' subtest

subtest ('Examples :: Exact match' => sub {
	plan tests => 28;

	my @array = qw( 12 17a 17b 17c 21 );
	my $lsearch = sub {
	    my ($array, $want) = @_;
	    my ($idx, $cmp, $elp) = blsrch0 {
	        ($_ =~ /([0-9]+)/g)[0] <=>
	        ($want =~ /([0-9]+)/g)[0]
	        } $array;
	    if (!defined $cmp) { "$want not found anywhere"; }
	    elsif ($cmp != 0)  { "$want not found; best "
	                             . "is $$elp at [$idx]"; }
	    else               { "$want found at $$elp [$idx] :)"; }
	};
	is $lsearch->( \@array, 11 ), "11 not found; best is 12 at [0]" => "lsearch impl 1";
	is $lsearch->( \@array, 12 ), "12 found at 12 [0] :)"   => "lsearch impl 2";
	is $lsearch->( \@array, 17 ), "17 found at 17a [1] :)"  => "lsearch impl 3";
	is $lsearch->( \@array, 18 ), "18 not found; best is 21 at [4]" => "lsearch impl 4 (new)";
	is $lsearch->( \@array, 21 ), "21 found at 21 [4] :)"   => "lsearch impl 4 (old)";
	is $lsearch->( \@array, 99 ), "99 not found anywhere"   => "lsearch impl 5";

	my @rsearch = (
	# Implementation 1
	sub {
	    my ($array, $want) = @_;
	    my ($idx, $cmp, $elp) = brsrch0 {
	        ($want =~ /([0-9]+)/)[0]
	        <=> ($_ =~ /([0-9]+)/)[0]
	        } $array;
	    if (!defined $cmp) { "$want not found anywhere"; }
	    elsif ($cmp != 0)  { "$want not found; best "
	                             . "is $$elp at [$idx]"; }
	    else               { "$want found at $$elp [$idx] :)"; }
	},
	# Implementation 2
	sub {
	    my ($array, $want) = @_;
	    my $idx = blsrch1 {
	        ($_ =~ /([0-9]+)/)[0] <=>
	        ($want =~ /([0-9]+)/)[0] }
	        $array;
	    --$idx;
	    if ($idx < 0) {
	        "$want not found anywhere";
	    } else {
	        my $elt = $array->[$idx];
	        my $cmp = ($elt =~ /([0-9]+)/)[0]
	            <=> ($want =~ /([0-9]+)/)[0];
	        $cmp == 0
	        ? "$want found at $elt [$idx] :)"
	        : "$want not found; best is $elt at [$idx]";
	    }
	});

foreach my $impl (0 .. $#rsearch) {
	my $rsearch = $rsearch[$impl];
	my $n = $impl + 1 - $[;

	is $rsearch->( \@array => 11 ), "11 not found anywhere"   => "rsearch impl-$n 1";
	is $rsearch->( \@array => 12 ), "12 found at 12 [0] :)"   => "rsearch impl-$n 2";
	is $rsearch->( \@array => 17 ), "17 found at 17c [3] :)"  => "rsearch impl-$n 3";
	is $rsearch->( \@array => 18 ), "18 not found; best is 17c at [3]" => "rsearch impl-$n 4 (new)";
	is $rsearch->( \@array => 21 ), "21 found at 21 [4] :)"   => "rsearch impl-$n 4 (old)";
	is $rsearch->( \@array => 99 ), "99 not found; best is 21 at [4]" => "rsearch impl-$n 5";
}

	my @srchall = (
	# Implementation 1
	sub {
	    my ($lo, $hi);
	    my ($array, $want) = @_;

	    ($lo, $hi) = blsrch2 {
	        ($_ =~ /([0-9]+)/)[0] <=>
	        ($want =~ /([0-9]+)/)[0]
	        } $array;
	    map { "[$_]=$array->[$_]" } ($lo .. $hi-1);
	},
	# Implementation 2
	sub {
	    my ($lo, $hi);
	    my ($array, $want) = @_;

	    ($hi, $lo) = brsrch2 {
	        ($want =~ /([0-9]+)/)[0]
	        <=> ($_ =~ /([0-9]+)/)[0]
	        } $array;
	    map { "[$_]=$array->[$_]" } ($lo+1 .. $hi);
	});

foreach my $impl (0 .. $#srchall) {
	my $srchall = $srchall[$impl];
	my $n = $impl + 1 - $[;

	is_deeply [$srchall->( \@array => 11 )], []  => "srchall impl-$n 1";
	is_deeply [$srchall->( \@array => 12 )], [qw([0]=12)] => "srchall impl-$n 2";
	is_deeply [$srchall->( \@array => 17 )], [qw([1]=17a [2]=17b [3]=17c)] => "srchall impl-$n 3";
	is_deeply [$srchall->( \@array => 21 )], [qw([4]=21)] => "srchall impl-$n 4";
	is_deeply [$srchall->( \@array => 99 )], []  => "srchall impl-$n 5";
}
});  # 'Examples :: Exact match' subtest

subtest ('Conversion :: List::MoreUtils' => sub {
	plan tests => 6;

	my (@ids, $lb, $ub);
	@ids = (1, 1, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4,
	        4, 4, 5, 5, 6, 7, 7, 7, 8, 8, 9, 9,
	        9, 9, 9, 11, 13, 13, 13, 17);

	is +( blsrch0 { $_ <=> 2 } \@ids ), 2  ,=> "lower_bound 1";
	is +( blsrch0 { $_ <=> 4 } \@ids ), 10 ,=> "lower_bound 2";

	is +( blsrch1 { $_ <=> 2 } \@ids ), 4  ,=> "upper_bound 1";
	is +( blsrch1 { $_ <=> 4 } \@ids ), 14 ,=> "upper_bound 2";

	is_deeply [blsrch2 { $_ <=> 2 } \@ids], [2,4]   => "equal_range 1";
	is_deeply [blsrch2 { $_ <=> 4 } \@ids], [10,14] => "equal_range 2";
});  # 'Conversion :: List::MoreUtils' subtest

subtest ('Conversion :: List::BinarySearch' => sub {
	plan tests => 8;

	my ($low_ix, $high_ix);
	my @num_array = (100, 200, 300, 400, 500);
	my @str_array = qw(Bach Beethoven Brahms Mozart Schubert);
	my $exactly;

	$exactly = sub {
	    my ($idx, $cmp) = @_;
	    defined $cmp && $cmp == 0 ? $idx : undef;
	};

	is $exactly->( blsrch0 { $_ <=> 300 } \@num_array ),      2 ,=> "binsearch 1";
	is $exactly->( blsrch0 { $_ cmp 'Mozart' } \@str_array ), 3 ,=> "binsearch 2";
	is $exactly->( blsrch0 { $_ <=> 42 } \@num_array ),   undef ,=> "binsearch 3";

	is +( blsrch0 { $_ cmp 'Chopin' } \@str_array ), 3 ,=> "binsearch_pos 1";
	is +( blsrch0 { $_ <=> 600 } \@num_array ),      5 ,=> "binsearch_pos 2";
	is +( blsrch0 { $_ <=> 200 } \@num_array ),      1 ,=> "binsearch_pos 3";

	($low_ix, $high_ix)
	    = ( # ... in either scalar context:
	        scalar ( blsrch0 { $_ cmp 'Beethoven' } \@str_array ),
	        # ... or get just the index in list context:
	        ( blsrch0 { $_ cmp 'Mozart' } \@str_array )[0],
	      );

	is_deeply [$low_ix, $high_ix], [1, 3] => "binsearch_range 1";

	($low_ix, $high_ix)
	    = map { my $want = $_;
	         scalar blsrch0 { $_ <=> $want }
	               \@num_array } (200, 400);

	is_deeply [$low_ix, $high_ix], [1, 3] => "binsearch_range 2";
});  # 'Conversion :: List::BinarySearch' subtest

subtest ('Conversion :: List::Search' => sub {
	plan tests => 10;

	my @list = sort qw( bravo charlie delta );
	my @numbers = sort { $a <=> $b } ( 10, 20, 100, 200, );
	my $cmp_code = sub { lc( $_[0] ) cmp lc( $_[1] ) };
	my @custom_list = sort { $cmp_code->( $a, $b ) } qw( FOO bar BAZ bundy );
	my ($index, $found);

	my $actually = sub {
	    my ($idx, $cmp) = @_;
	    defined $cmp ? $idx : -1;
	};

	is $actually->( blsrch0 { $_ cmp 'alpha'   } \@list ), 0  ,=> "list_search 1";
	is $actually->( blsrch0 { $_ cmp 'charlie' } \@list ), 1  ,=> "list_search 2";
	is $actually->( blsrch0 { $_ cmp 'zebra'   } \@list ), -1 ,=> "list_search 3";
	is $actually->( blsrch0 { $_ <=> 20 } \@numbers ), 1      ,=> "nlist_search 1";
	is $actually->( blsrch0
		{ $cmp_code->($_, 'foo') } \@custom_list ), 3    ,=> "custom_list_search 1";

	my $validate = sub {
	    my ($idx, $cmp) = @_;
	    defined $cmp && $cmp == 0;
	};

	ok! $validate->( blsrchx { $_ cmp 'alpha'   } \@list )  => "list_contains 1";
	ok $validate->( blsrchx { $_ cmp 'charlie' } \@list )  => "list_contains 2";
	ok! $validate->( blsrchx { $_ cmp 'zebra'   } \@list )  => "list_contains 3";
	ok $validate->( blsrchx { $_ <=> 20 } \@numbers )      => "nlist_contains 1";
	ok $validate->( blsrchx
		{ $cmp_code->($_, 'foo') } \@custom_list )    => "custom_list_contains 1";
});  # 'Conversion :: List::Search' subtest
