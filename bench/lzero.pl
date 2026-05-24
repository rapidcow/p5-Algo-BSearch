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

> /usr/bin/time ./lzero.pl
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
               Rate L::MU::PP L::MU::XS LINEAR S::S(0) S::S[0] S::S(L) L::BS::PP S::S[L] L::S S::S(x) L::S{} L::BS::XS
L::MU::PP    3101/s        --      -25%   -82%    -94%    -95%    -95%      -95%    -95% -97%    -97%   -97%     -100%
L::MU::XS    4120/s       33%        --   -76%    -92%    -93%    -93%      -93%    -93% -96%    -96%   -97%     -100%
LINEAR      17512/s      465%      325%     --    -67%    -70%    -71%      -72%    -72% -83%    -84%   -85%      -98%
S::S(0)     53696/s     1632%     1203%   207%      --     -7%    -12%      -14%    -15% -48%    -52%   -55%      -95%
S::S[0]     57524/s     1755%     1296%   228%      7%      --     -5%       -8%     -9% -45%    -49%   -52%      -95%
S::S(L)     60811/s     1861%     1376%   247%     13%      6%      --       -2%     -4% -42%    -46%   -49%      -94%
L::BS::PP   62221/s     1906%     1410%   255%     16%      8%      2%        --     -2% -40%    -45%   -48%      -94%
S::S[L]     63219/s     1939%     1435%   261%     18%     10%      4%        2%      -- -39%    -44%   -47%      -94%
L::S       103982/s     3253%     2424%   494%     94%     81%     71%       67%     64%   --     -8%   -13%      -90%
S::S(x)    112553/s     3529%     2632%   543%    110%     96%     85%       81%     78%   8%      --    -6%      -89%
L::S{}     119810/s     3763%     2808%   584%    123%    108%     97%       93%     90%  15%      6%     --      -89%
L::BS::XS 1047291/s    33672%    25322%  5881%   1850%   1721%   1622%     1583%   1557% 907%    830%   774%        --
155.94user 0.06system 2:36.05elapsed 99%CPU (0avgtext+0avgdata 14208maxresident)k
0inputs+0outputs (0major+2411minor)pagefaults 0swaps

Note that (x) is entirely cheating with prior knowledge
that only one match exists.  I was just testing that it
works; but List::Search is still consistently faster due
to leaner design.  L::S{} is, in fact, not slower than
L::S than I had misread it to be; but it is true that
passing a CODE ref to an existing subroutine is faster
than creating an anonymous sub every time.  (I assume the
overhead comes nlist_search calling custom_list_search;
otherwise, both L::S and L::S{} still benefit from a stable
long-lived CODE ref as comparator, anonymous or not.)

I suspect List::BinarySearch::PP is slower due to
having localize $a $b.  But otherwise, it's pretty
fast too.

The test is not fair at all to List::MoreUtils, since
it takes not an array reference, but a flattened list
to search on.  In practice, it shouldn't too far
behind List::Search and List::BinarySearch.

And of course, nothing beats XS... makes any other
optimizations seem negligible.
