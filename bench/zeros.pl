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
	);
	want qw( List::MoreUtils::PP 0.420_001 );
	want qw( List::MoreUtils::XS 0.420_001 );
	require Exporter;
	want qw( List::Search  0 ) => qw( custom_list_search );
	want qw( List::BinarySearch::PP );
	want qw( List::BinarySearch::XS );
}

print STDERR "Benchmark count: $count\n";

my @array = ( 0 .. (1 << 16) - 1 );
my @expect = ( 123 << 8, 124 << 8 );
my %bench;

{
	print STDERR "Registering Sort::Search (S::S) tests...\n";
	$bench{"S::S[2]"} = eval q{

sub { blsrch2 { ($_ >> 8) <=> 123 } \@array; }

	} or die "Compiler error: $@";

	$bench{"S::S[0+1]"} = eval q{

sub {
	my $lb = blsrch0 { ($_ >> 8) <=> 123 } \@array;
	my $ub = blsrch1 { ($_ >> 8) <=> 123 } \@array, $lb, @array;
	($lb, $ub);
}

	} or die "Compiler error: $@";

	$bench{"S::S(2)"} = eval q{

sub { blsrch2 { ($array[$_] >> 8) <=> 123 } @array; }

	} or die "Compiler error: $@" if 0;

	$bench{"S::S(0+1)"} = eval q{

sub {
	my $lb = blsrch0 { ($array[$_] >> 8) <=> 123 } @array;
	my $ub = blsrch1 { ($array[$_] >> 8) <=> 123 } $lb, @array;
	($lb, $ub);
}

	} or die "Compiler error: $@" if 0;
}

for my $IMPL (qw( PP XS )) {
	if (have "List::MoreUtils::${IMPL}" => '0.420_001') {
		print STDERR "Registering List::MoreUtils::${IMPL} (L::MU::${IMPL}) test...\n";
		$bench{"L::MU::${IMPL}(eq)"} = eval qq{

sub { List::MoreUtils::${IMPL}::equal_range { (\$_ >> 8) <=> 123 } \@array; }

		} or die "Compiler error: $@";

		$bench{"L::MU::${IMPL}(lb+ub)"} = eval qq{

sub { ( List::MoreUtils::${IMPL}::lower_bound { (\$_ >> 8) <=> 123 } \@array ),
      ( List::MoreUtils::${IMPL}::upper_bound { (\$_ >> 8) <=> 123 } \@array ); }

		} or die "Compiler error: $@";
	}
}

if (have qw( List::Search )) {
	print STDERR "Registering List::Search (L::S) test...\n";
	$bench{"L::S"} = eval q{

sub { custom_list_search ( sub { ($_[0] >> 8) <=> ($_[1] >> 8) }, (123 << 8), \@array ),
      custom_list_search ( sub { ($_[0] >> 8) <=> ($_[1] >> 8) }, (124 << 8), \@array ); }

	} or die "Compiler error: $@";
}

for my $IMPL (qw( PP XS )) {
	if (have "List::BinarySearch::${IMPL}") {
		print STDERR "Registering List::BinarySearch::${IMPL} (L::BS::${IMPL}) test...\n";
		$bench{"L::BS::${IMPL}"} = eval qq{

sub {
	( List::BinarySearch::${IMPL}::binsearch_pos { (\$a >> 8) <=> (\$b >> 8) } (123 << 8), \@array ),
	( List::BinarySearch::${IMPL}::binsearch_pos { (\$a >> 8) <=> (\$b >> 8) } (124 << 8), \@array );
}

		} or die "Compiler error: $@";
	}
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
