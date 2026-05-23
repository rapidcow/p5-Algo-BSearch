#!/usr/bin/env perl
# zeros.pl - finding zeros (equal range)

use strict;
use warnings;
BEGIN { require "./bench.pl"; }

my $count;

BEGIN {
	if (@ARGV == 1) { ($count) = @ARGV; }
	elsif (!@ARGV)  {  $count  = -10;   }
	else {
		die "E: usage: $0 [count]\n";
	}

	need qw( Sort::Search  0 ) => qw(
		blsrch0 blsrch1 blsrch2
		brsrch2 brsrch1 brsrch0
	);
	want qw( List::MoreUtils 0.420_001 )  => qw(
		equal_range lower_bound upper_bound
	);
	require Exporter;
	want qw( List::Search  0 ) => qw( custom_list_search );
	want qw( List::BinarySearch 0 ) => qw( binsearch_pos );
}

print STDERR "Benchmark count: $count\n";

my @array = ( 0 .. (1 << 16) - 1 );
my @expect = ( 123 << 8, 124 << 8 );
my %bench;

{
	print STDERR "Registering Sort::Search (S::S) tests...\n";
	$bench{"S::S LTR 2"} = eval q{

sub { blsrch2 { ($_ >> 8) <=> 123 } \@array; }

	} or die "Compiler error: $@";

	$bench{"S::S RTL 2"} = eval q{

sub { reverse map { $_ + 1 } brsrch2 { 123 <=> ($_ >> 8) } \@array; }

	} or die "Compiler error: $@";

	$bench{"S::S LTR 0+1"} = eval q{

sub {
	my $lb = blsrch0 { ($_ >> 8) <=> 123 } \@array;
	my $ub = blsrch1 { ($_ >> 8) <=> 123 } \@array, $lb, @array;
	($lb, $ub);
}

	} or die "Compiler error: $@";

	$bench{"S::S RTL 0+1"} = eval q{

sub {
	my $ub = brsrch0 { 123 <=> ($_ >> 8) } \@array;
	my $lb = brsrch1 { 123 <=> ($_ >> 8) } \@array, $ub, -1;
	$lb++;  $ub++;  ($lb, $ub);
}

	} or die "Compiler error: $@";
}

if (have qw( List::MoreUtils 0.420_001 )) {
	print STDERR "Registering List::MoreUtils (L::MU) test...\n";
	$bench{"L::MU eq"} = eval q{

sub { equal_range { ($_ >> 8) <=> 123 } @array; }

	} or die "Compiler error: $@";

	$bench{"L::MU lb+ub"} = eval q{

sub { ( lower_bound { ($_ >> 8) <=> 123 } @array ),
      ( upper_bound { ($_ >> 8) <=> 123 } @array ); }

	} or die "Compiler error: $@";
}

if (have qw( List::Search )) {
	print STDERR "Registering List::Search (L::S) test...\n";
	$bench{"L::S"} = eval q{

sub {
	my $lb = custom_list_search sub { ($_[0] >> 8) <=> ($_[1] >> 8) }, (123 << 8), \@array;
	my $ub = custom_list_search sub { ($_[0] >> 8) <=> ($_[1] >> 8) }, (124 << 8), \@array;
	($lb, $ub);
}

	} or die "Compiler error: $@";
}

if (have qw( List::BinarySearch )) {
	print STDERR "Registering List::BinarySearch (L::BS) test...\n";
	$bench{"L::BS"} = eval q{

sub {
	my $lb = binsearch_pos { ($a >> 8) <=> ($b >> 8) } (123 << 8), @array;
	my $ub = binsearch_pos { ($a >> 8) <=> ($b >> 8) } (124 << 8), @array;
	($lb, $ub);
}

	} or die "Compiler error: $@";
}

foreach my $name (sort keys %bench) {
	my @result = $bench{$name}->();
	if (@result != @expect or grep {
		$result[$_] != $expect[$_]
	} 0..$#result) {
		local $" = ",";
		die <<BADCODE;
E: $name function is misbehaving.
E: want: [@expect]
E:  got: [@result]
E: Cannot continue benchmark.
BADCODE
	}
}

Benchmark::cmpthese($count, \%bench);
