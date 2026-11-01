#!perl
# t/00-load.t - basic load
use 5.006;
use strict;
use warnings;
use Test::More tests => 25;  # 2*12+1

my @have_fun;
BEGIN {
	use_ok( 'Sort::Search', @have_fun = qw(
		bisectl bisectr bixectl bixectr
		blsrch0 brsrch0 blsrch1 brsrch1
		blsrch2 brsrch2 blsrchx brsrchx
	)) or BAIL_OUT;
}
diag ("Testing Sort::Search $Sort::Search::VERSION, Perl $], $^X");

my $PROTO = '&$;$$';
foreach (@have_fun) {
	no strict 'refs';
	ok (exists &{$_}, "&$_ is imported");
	is (prototype $_, $PROTO, "&$_ has prototype $PROTO");
}
