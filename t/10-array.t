#!perl
# t/10-array.t - ARRAY input form
use 5.006;
use strict;
use warnings;
use Test::More tests => 6;

use Sort::Search qw(bisectl bisectr);

sub probe_check
{
	local $Test::Builder::Level = $Test::Builder::Level + 1;
	my ($probe, $array, $acopy, $index, $mutfn) = @_;
	my $ok = 1;
	ok( !grep( $probe->{$_} ne $acopy->[$_], keys %$probe ),
		"\$_ is array element, not index" ) or $ok = 0;
	ok( !grep( $array->[$_] ne $mutfn->($acopy->[$_]), keys %$probe ),
		"\$_ is an alias of array element" ) or $ok = 0;
	# This is equivalent to checking $index < @$array.
	ok( exists $probe->{$index}, "search success" ) or $ok = 0;
	$ok or diag "BAD probe! at $index " . join(" ",
		map { "[$_]=$probe->{$_}" } keys %$probe)
		. " array @$array";
	$ok;
}

my @NUMBERS = (5, 7, 12, 17, 29);

subtest "bisectl on unblessed ARRAY" => sub {
	plan tests => 4;
	my @array = (5, 7, 12, 17, 29);
	my @acopy = @array;
	my (%probe, $index);
	$index = bisectl { $probe{$_[0]} = $_; ($_ .= "E0") >= 12 } \@array;

	probe_check(\%probe, \@array, \@acopy, $index, sub { "$_[0]E0" });
	is ($array[$index], "12E0", "sanity check");
};

subtest "bisectr on unblessed ARRAY" => sub {
	plan tests => 4;
	my @array = @NUMBERS;
	my @acopy = @array;
	my (%probe, $index);
	$index = bisectr { $probe{$_[0]} = $_; ($_ .= "E0") <= 17 } \@array;

	probe_check(\%probe, \@array, \@acopy, $index, sub { "$_[0]E0" });
	is ($array[$index], "17E0", "sanity check");
};

my @STRINGS = qw(
	auto       break      case        char
	const      continue   default     do
	double     else       enum        extern
	float      for        goto        if
	int        long       register    return
	short      signed     sizeof      static
	struct     switch     typedef     union
	unsigned   void       volatile    while
);

subtest "bisectl on blessed ARRAY" => sub {
	plan tests => 4;
	my @array = @STRINGS;
	my $array = bless \@array, 'C89::Keywords';
	my @acopy = @array;
	my (%probe, $index);
	$index = bisectl { $probe{$_[0]} = $_; ($_ = uc($_)) ge "GOTO" } $array;

	probe_check(\%probe, \@array, \@acopy, $index, sub { uc($_[0]) });
	is ($array[$index], "GOTO", "sanity check");
};

subtest "bisectr on blessed ARRAY" => sub {
	plan tests => 4;
	my @array = @STRINGS;
	my $array = bless \@array, 'C89::Keywords';
	my @acopy = @array;
	my (%probe, $index);
	$index = bisectr { $probe{$_[0]} = $_; ($_ = uc($_)) le "VOID" } $array;

	probe_check(\%probe, \@array, \@acopy, $index, sub { uc($_[0]) });
	is ($array[$index], "VOID", "sanity check");
};

my $STRLIST = "AHjp";

subtest "bisectl on tied ARRAY" => sub {
	plan tests => 4;
	my $array = $STRLIST;
	tie my @array, 'Tie::StrArray', $array;
	my @acopy = @array;
	my (%probe, $index);
	$index = bisectl { $probe{$_[0]} = $_; ($_ = lc($_)) ge 'a' } \@array;

	probe_check(\%probe, \@array, \@acopy, $index, sub { lc($_[0]) });
	is ($array[$index], "a", "sanity check");
};

subtest "bisectr on tied ARRAY" => sub {
	plan tests => 4;
	my $array = $STRLIST;
	tie my @array, 'Tie::StrArray', $array;
	my @acopy = @array;
	my (%probe, $index);
	$index = bisectr { $probe{$_[0]} = $_; ($_ = uc($_)) le 'P' } \@array;

	probe_check(\%probe, \@array, \@acopy, $index, sub { uc($_[0]) });
	is ($array[$index], "P", "sanity check");
};

package Tie::StrArray;

sub TIEARRAY {
	bless \$_[1], $_[0];
}
sub FETCH {
	0 <= $_[1] && $_[1] < length( ${$_[0]} ) ?
	substr( ${$_[0]}, $_[1], 1 ) : undef;
}
sub STORE {
	${$_[0]} .= "\0" x ($_[1] - length( ${$_[0]} ) + 1)
		if $_[1] >= length( ${$_[0]} );
	substr( ${$_[0]}, $_[1], 1, $_[2] );
}
sub FETCHSIZE {
	length( ${$_[0]} );
}
sub STORESIZE {
	if ($_[1] < length( ${$_[0]} )) {
		${$_[0]} = substr( ${$_[0]}, 0, $_[1] );
	} else {
		${$_[0]} .= "\0" x ($_[1] - length( ${$_[0]} ));
	}
}
