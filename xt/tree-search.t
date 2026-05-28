#!perl

use 5.006;
use strict;
use warnings;
use Test::More;

BEGIN {
	unless (eval {
		require './xlib/tree-search.pl';
		Sort::Search::Tree->import();
		1;
	}) {
		note "eval error: $@";
		plan skip_all => "SKIP: failed to load \`./xlib/tree-search.pl'";
	}
	plan tests => 8;
}

# ------------------------------------------------------------------ tokenizers

subtest "uri_strtok" => sub {
	plan tests => 5;
	is_deeply [uri_strtok("a/b/c")],  [qw(a b c)], "relative path";
	is_deeply [uri_strtok("/a/b/c")], [qw(a b c)], "absolute path (leading slash stripped)";
	is_deeply [uri_strtok("a")],      [qw(a)],     "single component";
	is_deeply [uri_strtok("/")],      [],          "root directory";
	is_deeply [uri_strtok(".")],      [],          "current directory";
};

subtest "dns_strtok" => sub {
	plan tests => 4;
	is_deeply [dns_strtok("www.example.com")],  [qw(com example www)], "labels reversed";
	is_deeply [dns_strtok("www.example.com.")], [qw(com example www)], "trailing dot stripped";
	is_deeply [dns_strtok("example.com")],      [qw(com example)],     "parent zone";
	is_deeply [dns_strtok(".")],                [],                    "root zone";
};

# ------------------------------------------------------------------ acomp

subtest "acomp 5 states" => sub {
	plan tests => 5;
	my $cmp = sub { $_[0] cmp $_[1] };
	is Sort::Search::Tree::acomp([qw(a b)],   [qw(a b)],   $cmp),  0, "   equal    =>  0";
	is Sort::Search::Tree::acomp([qw(a b c)], [qw(a b)],   $cmp),  1, "   suffix   => +1";
	is Sort::Search::Tree::acomp([qw(a b)],   [qw(a b c)], $cmp), -1, "   prefix   => -1";
	is Sort::Search::Tree::acomp([qw(a c)],   [qw(a b)],   $cmp),  2, " successor  => +2";
	is Sort::Search::Tree::acomp([qw(a a)],   [qw(a b)],   $cmp), -2, "predecessor => -2";
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

subtest "BST_delv -- all descendants (path)" => sub {
	plan tests => 4;
	is_deeply [BST_delv($path_cmp, \@PATHS, "a")],
		[qw(a/b a/b/c a/b/d a/e)], "all under a/";

	is_deeply [BST_delv($path_cmp, \@PATHS, "a/b")],
		[qw(a/b/c a/b/d)], "all under a/b/";

	is_deeply [BST_delv($path_cmp, \@PATHS, "f")],
		[qw(f/g f/g/h f/i)], "all under f/ (f itself excluded)";

	is_deeply [BST_delv($path_cmp, \@PATHS, "z")],
		[], "no match";
};

subtest "BST_leap -- direct children only (path)" => sub {
	plan tests => 4;
	is_deeply [BST_leap($path_cmp, \@PATHS, "a")],
		[qw(a/b a/e)], "direct children of a/";

	is_deeply [BST_leap($path_cmp, \@PATHS, "a/b")],
		[qw(a/b/c a/b/d)], "direct children of a/b/";

	is_deeply [BST_leap($path_cmp, \@PATHS, "f")],
		[qw(f/g f/i)], "f/g/h skipped as grandchild";

	is_deeply [BST_leap($path_cmp, \@PATHS, "z")],
		[], "no match";
};

# Should work on us right???
#
# $ tree xt
# xt
# ├── 00-load.t
# ├── changes.t
# ├── essay.t
# ├── manifest.t
# ├── nsec-search.t
# ├── old
# │   ├── 10-bisectl.t
# │   ├── 10-bisectr.t
# │   ├── 50-bisect120.t
# │   ├── 50-scope.t
# │   ├── README
# │   └── doctest.t
# ├── overflow.t
# ├── pod-coverage.t
# ├── pod.t
# ├── sib.t
# └── tree-search.t
#
# 2 directories, 16 files

my @xt_tree = qw(
.
lib/Sort
lib/Sort/Search
lib/Sort/Search/Cookbook.pod
lib/Sort/Search.pm
lib/Sort/Search.pod
xt
xt/00-load.t
xt/changes.t
xt/essay.t
xt/manifest.t
xt/nsec-search.t
xt/old
xt/old/10-bisectl.t
xt/old/10-bisectr.t
xt/old/50-bisect120.t
xt/old/50-scope.t
xt/old/README
xt/old/doctest.t
xt/overflow.t
xt/pod-coverage.t
xt/pod.t
xt/sib.t
xt/tree-search.t
);

subtest "SANITY CHECK" => sub {
	plan tests => 6;
	my $uri_cmp = make_acomp(\&uri_strtok);
	is_deeply (\@xt_tree, [ sort { $uri_cmp->($a, $b) } @xt_tree ], "uri sort is OK");
	is_deeply ([ BST_delv ($uri_cmp, \@xt_tree, "xt") ], [ grep { m!^xt/! } @xt_tree ], "ls -r xt");
	is_deeply ([ BST_leap ($uri_cmp, \@xt_tree, "xt") ], [ grep { m!^xt/! && !m!^xt/.*/! } @xt_tree ], "ls xt");
	is_deeply ([ BST_delv ($uri_cmp, \@xt_tree, "xt/old") ], [ grep { m!^xt/old/! } @xt_tree ], "ls -r xt/old");
	is_deeply ([ BST_leap ($uri_cmp, \@xt_tree, "xt/old") ], [ grep { m!^xt/old/! } @xt_tree ], "ls xt/old");
	is_deeply ([ BST_leap ($uri_cmp, \@xt_tree, "lib/Sort") ], [ qw( lib/Sort/Search lib/Sort/Search.pm lib/Sort/Search.pod ) ], "ls lib/Sort");
};

# ------------------------------------------------------------------ DNS tree
#
# Listing must be sorted by reversed-label order (as dns_strtok produces):
#   dns_strtok("example.com")          => (com, example)
#   dns_strtok("api.example.com")      => (com, example, api)
#   dns_strtok("staging.api.example.com") => (com, example, api, staging)
#   dns_strtok("mail.example.com")     => (com, example, mail)
#   dns_strtok("www.example.com")      => (com, example, www)

my @DNS = qw(
	example.com
	api.example.com
	staging.api.example.com
	mail.example.com
	www.example.com
);

my $dns_cmp = make_acomp(\&dns_strtok, sub { $_[0] cmp $_[1] });

subtest "BST_delv -- all descendants (DNS)" => sub {
	plan tests => 2;
	is_deeply [BST_delv($dns_cmp, \@DNS, "example.com")],
		[qw(api.example.com staging.api.example.com mail.example.com www.example.com)],
		"all subdomains of example.com";

	is_deeply [BST_delv($dns_cmp, \@DNS, "api.example.com")],
		[qw(staging.api.example.com)],
		"all subdomains of api.example.com";
};

subtest "BST_leap -- direct children only (DNS)" => sub {
	plan tests => 1;
	is_deeply [BST_leap($dns_cmp, \@DNS, "example.com")],
		[qw(api.example.com mail.example.com www.example.com)],
		"direct subdomains of example.com (staging skipped)";
};
