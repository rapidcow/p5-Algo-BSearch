#!perl

use 5.006;
use strict;
use warnings;
use Test::More 'no_plan';

BEGIN {
	unless (eval {
		require './xlib/tree-search.pl';
		Sort::Search::Tree->import();
		1;
	}) {
		note "eval error: $@";
		plan skip_all => "SKIP: failed to load \`./xlib/tree-search.pl'";
	}
}

die "TODO";
