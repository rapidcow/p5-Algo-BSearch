#!perl
use 5.006;
use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
	use_ok( 'RdKw::Algo::BSearch' ) or BAIL_OUT;
}
diag( "Testing RdKw::Algo::BSearch $RdKw::Algo::BSearch::VERSION, Perl $], $^X" );
