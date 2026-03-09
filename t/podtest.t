#!perl
#
# t/podtest.t - documentation examples
# (Inspired by Python "doctest" module)
#

use 5.006;
use strict;
use warnings;
use Test::More tests => 3;
use Sort::Search qw(
  blsrch0 blsrch1 blsrch2 blsrchx
  brsrch0         brsrch2
);

subtest ('Cookbook :: Exact match' => sub {
	plan(tests => 25);

	my @array = qw( 12 17a 17b 17c 21 );
	my $lsearch = sub {
	    my ($array, $want) = @_;
	    my ($idx, $cmp, $elt) = blsrch0
	            { no warnings 'numeric'; $_ <=> $want }
	            $array;
	    if (!defined $cmp) { "$want not found anywhere"; }
	    elsif ($cmp != 0)  { "$want not found; best "
	                             . "is $elt at [$idx]"; }
	    else               { "$want found at $elt [$idx] :)"; }
	};
	is $lsearch->( \@array, 11 ), "11 not found; best is 12 at [0]" => "lsearch impl 1";
	is $lsearch->( \@array, 12 ), "12 found at 12 [0] :)"   => "lsearch impl 2";
	is $lsearch->( \@array, 17 ), "17 found at 17a [1] :)"  => "lsearch impl 3";
	is $lsearch->( \@array, 21 ), "21 found at 21 [4] :)"   => "lsearch impl 4";
	is $lsearch->( \@array, 99 ), "99 not found anywhere"   => "lsearch impl 5";

	my @rsearch = (
	# Implementation 1
	sub {
	    my ($array, $want) = @_;
	    my ($idx, $cmp, $elt) = brsrch0
	            { no warnings 'numeric'; $want <=> $_ }
	            $array;
	    if (!defined $cmp) { "$want not found anywhere"; }
	    elsif ($cmp != 0)  { "$want not found; best "
	                             . "is $elt at [$idx]"; }
	    else               { "$want found at $elt [$idx] :)"; }
	},
	# Implementation 2
	sub {
	    my ($array, $want) = @_;
	    my $idx = blsrch1
	        { no warnings 'numeric'; $_ <=> $want }
	        $array;
	    --$idx;
	    if ($idx < 0) {
	        "$want not found anywhere";
	    } else {
	        my $elt = $array->[$idx];
	        my $cmp = $elt <=> $want;
	        $cmp == 0
	        ? "$want found at $elt [$idx] :)"
	        : "$want not found; best is $elt at [$idx]";
	    }
	});

foreach my $impl ($[..$#rsearch) {
	my $rsearch = $rsearch[$impl];
	my $n = $impl + 1 - $[;

	is $rsearch->( \@array => 11 ), "11 not found anywhere"   => "rsearch impl-$n 1";
	is $rsearch->( \@array => 12 ), "12 found at 12 [0] :)"   => "rsearch impl-$n 2";
	is $rsearch->( \@array => 17 ), "17 found at 17c [3] :)"  => "rsearch impl-$n 3";
	is $rsearch->( \@array => 21 ), "21 found at 21 [4] :)"   => "rsearch impl-$n 4";
	is $rsearch->( \@array => 99 ), "99 not found; best is 21 at [4]" => "rsearch impl-$n 5";
}

	my @srchall = (
	# Implementation 1
	sub {
	    my ($lo, $hi);
	    my ($array, $want) = @_;

	    ($lo, $hi) = blsrch2 { $_ <=> $want } $array;
	    map { "[$_]=$array->[$_]" } ($lo .. $hi-1);
	},
	# Implementation 2
	sub {
	    my ($lo, $hi);
	    my ($array, $want) = @_;

	    ($hi, $lo) = brsrch2 { $want <=> $_ } $array;
	    map { "[$_]=$array->[$_]" } ($lo+1 .. $hi);
	});

foreach my $impl ($[..$#srchall) {
	my $srchall = $srchall[$impl];
	my $n = $impl + 1 - $[;

	is_deeply [$srchall->( \@array => 11 )], []  => "srchall impl-$n 1";
	is_deeply [$srchall->( \@array => 12 )], [qw([0]=12)] => "srchall impl-$n 2";
	is_deeply [$srchall->( \@array => 17 )], [qw([1]=17a [2]=17b [3]=17c)] => "srchall impl-$n 3";
	is_deeply [$srchall->( \@array => 21 )], [qw([4]=21)] => "srchall impl-$n 4";
	is_deeply [$srchall->( \@array => 99 )], []  => "srchall impl-$n 5";
}
});  # 'Cookbook :: Exact match' subtest

subtest ('Conversion :: List::BinarySearch' => sub {
	plan(tests => 8);

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
	         scalar blsrch0 { $_ cmp $want }
	               \@num_array } (200, 400);

	is_deeply [$low_ix, $high_ix], [1, 3] => "binsearch_range 2";
});  # 'Conversion :: List::BinarySearch' subtest

subtest ('Conversion :: List::Search' => sub {
	plan(tests => 10);

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
