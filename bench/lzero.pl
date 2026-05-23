#!/usr/bin/env perl
# zero.pl - finding (left) exact match

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

	need qw( Sort::Search  0 ) => qw( bisectl blsrch0 blsrchx );
	want qw( List::MoreUtils::PP 0.420_001 );
	want qw( List::MoreUtils::XS 0.420_001 );
	require Exporter;
	want qw( List::Search  0 ) => qw( nlist_search custom_list_search );
	want qw( List::BinarySearch::PP );
	want qw( List::BinarySearch::XS );
}

print STDERR "Benchmark count: $count\n";

my @array = ( 0 .. (1 << 16) - 1 );
# 65536 -> 16384 -> 8192 -> 4096 -> 2048 -> 1024
# This early exit setup just for blsrchx... :)
my $expect = 1024;
my %bench = (
	"LINEAR" => sub {
		foreach (0 .. $#array) {
			return $_ if $array[$_] >= 1024;
		}
		return @array;
	}
);

{
	print STDERR "Registering Sort::Search (S::S) tests...\n";
	$bench{"S::S(L)"} = eval q{

sub { bisectl { $array[$_] >= 1024 } @array; }

	} or die "Compiler error: $@";

	$bench{"S::S[L]"} = eval q{

sub { bisectl { $array[$_] >= 1024 } \@array; }

	} or die "Compiler error: $@";

	$bench{"S::S(0)"} = eval q{

sub { blsrch0 { $array[$_] <=> 1024 } @array; }

	} or die "Compiler error: $@";

	$bench{"S::S[0]"} = eval q{

sub { blsrch0 { $array[$_] <=> 1024 } \@array; }

	} or die "Compiler error: $@";

	$bench{"S::S(x)"} = eval q{

sub { blsrchx { $array[$_] <=> 1024 } @array; }

	} or die "Compiler error: $@";
}

for my $IMPL (qw( PP XS )) {
	if (have "List::MoreUtils::${IMPL}" => '0.420_001') {
		print STDERR "Registering List::MoreUtils::${IMPL} (L::MU::${IMPL}) test...\n";
		$bench{"L::MU::${IMPL}"} = eval qq{

sub { List::MoreUtils::${IMPL}::lower_bound { \$_ <=> 1024 } \@array; }

		} or die "Compiler error: $@";
	}
}

if (have qw( List::Search )) {
	print STDERR "Registering List::Search (L::S) test...\n";
	$bench{"L::S"} = eval q{

sub { nlist_search ( 1024, \@array ); }

	} or die "Compiler error: $@";

	$bench{"L::S{}"} = eval q{
sub { custom_list_search ( sub { $_[0] <=> $_[1] }, 1024, \@array ); }

	} or die "Compiler error: $@";
}

for my $IMPL (qw( PP XS )) {
	if (have "List::BinarySearch::${IMPL}") {
		print STDERR "Registering List::BinarySearch::${IMPL} (L::BS::${IMPL}) test...\n";
		$bench{"L::BS::${IMPL}"} = eval qq{

sub {
	List::BinarySearch::${IMPL}::binsearch_pos { \$a <=> \$b } 1024, \@array,
}

		} or die "Compiler error: $@";
	}
}

foreach my $name (sort keys %bench) {
	my $result = $bench{$name}->();
	if ($result != $expect) {
		local $" = ",";
		die <<BADCODE;
E: $name function is misbehaving.
E: want: $expect
E:  got: $result
E: Cannot continue benchmark.
BADCODE
	}
}

Benchmark::cmpthese($count, \%bench);
