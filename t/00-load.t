#!perl
use 5.006;
use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
	use_ok( 'Sort::Search' ) or BAIL_OUT;
}
diag( "Testing Sort::Search $Sort::Search::VERSION, Perl $], $^X" );
