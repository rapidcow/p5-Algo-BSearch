#!perl
#
# t/podtest.t - documentation examples
# (Inspired by Python "doctest" module)
#

use 5.006;
use strict;
use warnings;
use Test::More tests => 1;
use Sort::Search qw(
  blsrch0 blsrch1 blsrch2
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
