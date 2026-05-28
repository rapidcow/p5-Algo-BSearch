#!perl

use 5.006;
use strict;
use warnings;

my $pipe;
if (!open($pipe, '|-', '/bin/sh', '-')) {
	print "1..0 # SKIP You don't have /bin/sh.\n";
	exit 0;
}

while (<DATA>) {
	print $pipe $_;
}
close $pipe;
my $child = $?;
print sprintf "[Child exited with code 0x%X]\n", $child;
exit $child >> 8;

__DATA__
#!/bin/sh

. xt/lib/test-functions.sh

if ! {
	[ -f xlib/tree-search.pl ] &&
	[ -x xlib/tree-search.pl ] &&
	dot=$(xlib/tree-search.pl find "$tmp" 2>/dev/null)
}
then
	skip_all "can't exec xlib/tree-search.pl"
fi

plan 6

[ "$dot" = . ]
ok "find <empty> is a dot"

# ---- create @xt_tree under $tmp/root ----
tmpROOT=$tmp/ROOT
mkdir -p "$tmpROOT"/lib/Sort/Search \
         "$tmpROOT"/xt/old &&
touch "$tmpROOT"/lib/Sort/Search/Cookbook.pod \
      "$tmpROOT"/lib/Sort/Search.pm \
      "$tmpROOT"/lib/Sort/Search.pod \
      "$tmpROOT"/xt/00-load.t \
      "$tmpROOT"/xt/changes.t \
      "$tmpROOT"/xt/essay.t \
      "$tmpROOT"/xt/manifest.t \
      "$tmpROOT"/xt/nsec-search.t \
      "$tmpROOT"/xt/overflow.t \
      "$tmpROOT"/xt/pod-coverage.t \
      "$tmpROOT"/xt/pod.t \
      "$tmpROOT"/xt/sib.t \
      "$tmpROOT"/xt/tree-search.t \
      "$tmpROOT"/xt/old/10-bisectl.t \
      "$tmpROOT"/xt/old/10-bisectr.t \
      "$tmpROOT"/xt/old/50-bisect120.t \
      "$tmpROOT"/xt/old/50-scope.t \
      "$tmpROOT"/xt/old/README \
      "$tmpROOT"/xt/old/doctest.t
ok "setup ROOT"

# ---- delv xt/old: all descendants ----
xlib/tree-search.pl find "$tmpROOT" |
	xlib/tree-search.pl delv xt/old \
	>"$tmp"/actual
ok "ls -r xt/old"
cat <<'EOF' >"$tmp"/expect
xt/old/10-bisectl.t
xt/old/10-bisectr.t
xt/old/50-bisect120.t
xt/old/50-scope.t
xt/old/README
xt/old/doctest.t
EOF
is "$tmp"/actual "$tmp"/expect "diff <(ls -r xt/old)"

# ---- leap xt: direct children (xt/old subtree skipped) ----
xlib/tree-search.pl find "$tmpROOT" |
    xlib/tree-search.pl leap xt \
    >"$tmp"/actual
ok "ls xt/old"
cat <<'EOF' >"$tmp"/expect
xt/00-load.t
xt/changes.t
xt/essay.t
xt/manifest.t
xt/nsec-search.t
xt/old
xt/overflow.t
xt/pod-coverage.t
xt/pod.t
xt/sib.t
xt/tree-search.t
EOF
is "$tmp"/actual "$tmp"/expect "diff <(ls xt)"

conclude
