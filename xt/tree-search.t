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

# ------------------------------------------------------------------ tokenizers

subtest "uri_strtok" => sub {
	is_deeply [uri_strtok("a/b/c")],  [qw(a b c)], "relative path";
	is_deeply [uri_strtok("/a/b/c")], [qw(a b c)], "absolute path (leading slash stripped)";
	is_deeply [uri_strtok("a")],      [qw(a)],      "single component";
};

subtest "dns_strtok" => sub {
	is_deeply [dns_strtok("www.example.com")],  [qw(com example www)], "labels reversed";
	is_deeply [dns_strtok("www.example.com.")], [qw(com example www)], "trailing dot stripped";
	is_deeply [dns_strtok("example.com")],      [qw(com example)],     "parent zone";
};

# ------------------------------------------------------------------ acomp

subtest "acomp — all five relationships" => sub {
	my $cmp = sub { $_[0] cmp $_[1] };
	is Sort::Search::Tree::acomp([qw(a b)],   [qw(a b)],   $cmp),  0, "equal      →  0";
	is Sort::Search::Tree::acomp([qw(a b c)], [qw(a b)],   $cmp),  1, "suffix     → +1";
	is Sort::Search::Tree::acomp([qw(a b)],   [qw(a b c)], $cmp), -1, "prefix     → -1";
	is Sort::Search::Tree::acomp([qw(a c)],   [qw(a b)],   $cmp),  2, "successor  → +2";
	is Sort::Search::Tree::acomp([qw(a a)],   [qw(a b)],   $cmp), -2, "predecessor → -2";
};

# ------------------------------------------------------------------ path tree

my @PATHS = qw(
	a/b
	a/b/c
	a/b/d
	a/e
	f
	f/g
	f/g/h
	f/i
);

my $path_cmp = make_acomp(\&uri_strtok, sub { $_[0] cmp $_[1] });

subtest "BST_delv — all descendants (path)" => sub {
	is_deeply [BST_delv($path_cmp, \@PATHS, "a")],
		[qw(a/b a/b/c a/b/d a/e)], "all under a/";

	is_deeply [BST_delv($path_cmp, \@PATHS, "a/b")],
		[qw(a/b/c a/b/d)], "all under a/b/";

	is_deeply [BST_delv($path_cmp, \@PATHS, "f")],
		[qw(f/g f/g/h f/i)], "all under f/ (f itself excluded)";

	is_deeply [BST_delv($path_cmp, \@PATHS, "z")],
		[], "no match";
};

subtest "BST_leap — direct children only (path)" => sub {
	is_deeply [BST_leap($path_cmp, \@PATHS, "a")],
		[qw(a/b a/e)], "direct children of a/";

	is_deeply [BST_leap($path_cmp, \@PATHS, "a/b")],
		[qw(a/b/c a/b/d)], "direct children of a/b/";

	is_deeply [BST_leap($path_cmp, \@PATHS, "f")],
		[qw(f/g f/i)], "f/g/h skipped as grandchild";

	is_deeply [BST_leap($path_cmp, \@PATHS, "z")],
		[], "no match";
};

# ------------------------------------------------------------------ DNS tree
#
# Listing must be sorted by reversed-label order (as dns_strtok produces):
#   dns_strtok("example.com")          → (com, example)
#   dns_strtok("api.example.com")      → (com, example, api)
#   dns_strtok("staging.api.example.com") → (com, example, api, staging)
#   dns_strtok("mail.example.com")     → (com, example, mail)
#   dns_strtok("www.example.com")      → (com, example, www)

my @DNS = qw(
	example.com
	api.example.com
	staging.api.example.com
	mail.example.com
	www.example.com
);

my $dns_cmp = make_acomp(\&dns_strtok, sub { $_[0] cmp $_[1] });

subtest "BST_delv — all descendants (DNS)" => sub {
	is_deeply [BST_delv($dns_cmp, \@DNS, "example.com")],
		[qw(api.example.com staging.api.example.com mail.example.com www.example.com)],
		"all subdomains of example.com";

	is_deeply [BST_delv($dns_cmp, \@DNS, "api.example.com")],
		[qw(staging.api.example.com)],
		"all subdomains of api.example.com";
};

subtest "BST_leap — direct children only (DNS)" => sub {
	is_deeply [BST_leap($dns_cmp, \@DNS, "example.com")],
		[qw(api.example.com mail.example.com www.example.com)],
		"direct subdomains of example.com (staging skipped)";
};
