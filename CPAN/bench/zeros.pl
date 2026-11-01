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
my %bench = (
	"LINEAR" => sub {
		my ($lo, $hi) = (-1, scalar @array);
		foreach (0 .. $#array) {
			my $compar = ($array[$_] >> 8) <=> 123;
			if ($compar < 0) {
				$lo = $_;
			} elsif ($compar > 0) {
				$hi = $_;
				last;
			}
		}
		($lo + 1, $hi);
	}
);

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

__END__

Most recent run:

> w
 07:00:58 up 6 days,  4:36,  2 users,  load average: 0.00, 0.04, 0.06
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU  WHAT
emeng             52.119.103.130   Sat09    4:11m  0.00s  0.08s sshd: emeng [priv]
gdm      tty1     -                18May26  6days 21:36   0.10s /usr/bin/gjs -m /usr/share/gnome-shell/org.gnome.Scre

> uname -a
Linux vm-instunix-06.cs.wisc.edu 6.8.0-117-generic #117-Ubuntu SMP PREEMPT_DYNAMIC Tue May  5 19:26:24 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux

> perl -le 'print "Perl $] $^X"'
Perl 5.042000 /home/emeng/opt/x86_64/brew/Cellar/perl/5.42.0/bin/perl

> /usr/bin/time ./zeros.pl
Sort::Search 0.0043 found.
List::MoreUtils::PP 0.430 found.
List::MoreUtils::XS 0.430 found.
List::Search 0.31 found.
List::BinarySearch::PP 0.25 found.
List::BinarySearch::XS 0.09 found.
Benchmark count: -10
Registering Sort::Search (S::S) tests...
Registering List::MoreUtils::PP (L::MU::PP) test...
Registering List::MoreUtils::XS (L::MU::XS) test...
Registering List::Search (L::S) test...
Registering List::BinarySearch::PP (L::BS::PP) test...
Registering List::BinarySearch::XS (L::BS::XS) test...
                     Rate  LINEAR L::MU::PP(eq) L::MU::PP(lb+ub) L::MU::XS(lb+ub) L::MU::XS(eq) S::S[0+1] L::BS::PP S::S[2]  L::S L::BS::XS
LINEAR              226/s      --          -78%             -86%             -89%          -95%      -99%      -99%    -99% -100%     -100%
L::MU::PP(eq)      1032/s    356%            --             -34%             -50%          -76%      -96%      -97%    -97%  -98%     -100%
L::MU::PP(lb+ub)   1570/s    594%           52%               --             -24%          -63%      -94%      -95%    -95%  -97%     -100%
L::MU::XS(lb+ub)   2057/s    809%           99%              31%               --          -51%      -93%      -94%    -94%  -96%      -99%
L::MU::XS(eq)      4223/s   1766%          309%             169%             105%            --      -85%      -87%    -88%  -93%      -99%
S::S[0+1]         28151/s  12339%         2627%            1693%            1269%          567%        --      -13%    -17%  -52%      -91%
L::BS::PP         32401/s  14216%         3039%            1964%            1475%          667%       15%        --     -4%  -44%      -90%
S::S[2]           33910/s  14883%         3185%            2060%            1549%          703%       20%        5%      --  -42%      -90%
L::S              58355/s  25684%         5554%            3618%            2737%         1282%      107%       80%     72%    --      -82%
L::BS::XS        329780/s 145614%        31850%           20910%           15933%         7710%     1071%      918%    873%  465%        --
124.02user 0.05system 2:04.11elapsed 99%CPU (0avgtext+0avgdata 15232maxresident)k
0inputs+0outputs (0major+2671minor)pagefaults 0swaps

Yeah... it's slow.  A 20% improvement from
lower+upper to equal variants, compared to
105% in L::MU::XS.

The difference between XS(lb+ub) and XS(eq)
is quite telling though.
