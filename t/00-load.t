#!perl
use 5.006;
use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
	use_ok( 'FastLook' ) or BAIL_OUT;
}
diag( "Testing FastLook $FastLook::VERSION, Perl $], $^X" );
