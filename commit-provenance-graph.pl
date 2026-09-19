#!/usr/bin/env perl
use strict;
use warnings;

# Reads commit-provenance.tsv (on stdin) and draws a Graphviz digraph:
#   - solid edges  : parent -> commit   (the real git-parent DAG, "strong" links
#                    -- reachable from a tip -- are drawn thicker via penwidth)
#   - dotted edges : revision -> commit (amendment/rewrite chains only)
# plus refs/info/rpi-self, refs/info/rdk-self and refs/heads/master as
# special-shaped nodes pointing at whatever commit they currently resolve to.
# All commit nodes are named by their first 8 hex digits.
#
# Layout: every group of commits linked by revision edges (i.e. all the
# historical amendments of "the same" logical commit) is pinned to one
# Graphviz rank via `rank=same`, with rankdir=TB, so scanning DOWN the page
# moves through distinct commit positions and scanning ACROSS one row shows
# how many times that position got revised.
#
#   perl commit-provenance-graph.pl < commit-provenance.tsv > provenance.dot
#   dot -Tsvg provenance.dot -o provenance.svg

my $ZERO = '0' x 40;
my %parent_edges;     # "parent\tcommit" => 1
my %revision_edges;   # "revision\tcommit" => 1

while (my $line = <STDIN>) {
    chomp $line;
    next unless length $line;
    next if $line =~ /^;/;
    my (undef, undef, $commit, $parent, $revision) = split /\t/, $line;
    next unless defined $commit && length $commit;
    $parent_edges{"$parent\t$commit"} = 1 if defined $parent && length($parent) && $parent ne $ZERO;
    $revision_edges{"$revision\t$commit"} = 1 if defined $revision && length($revision) && $revision ne $ZERO;
}

sub short { substr($_[0], 0, 8) }

# Walk the parent DAG backward from each tip (no git calls -- everything
# needed is already in %parent_edges) to find every edge on some path up to
# a tip, i.e. the "strong" links, so they can be drawn thicker.
my %parents_of;   # commit => [ parent, parent, ... ]
for my $key (keys %parent_edges) {
    my ($parent, $commit) = split /\t/, $key;
    push @{ $parents_of{$commit} }, $parent;
}

my %strong_edge;      # "parent\tcommit" => 1
my %reachable_node;   # commit oid => 1 (on some path up to a tip, tip included)

sub mark_reachable {
    my ($start) = @_;
    my @stack = ($start);
    while (@stack) {
        my $node = pop @stack;
        next if $reachable_node{$node}++;
        for my $parent (@{ $parents_of{$node} // [] }) {
            $strong_edge{"$parent\t$node"} = 1;
            push @stack, $parent;
        }
    }
}

my %tip = (
	'refs/info/rpi-self' => '29a7737034c5afe164ea003f19a7095c7d48f35a',
	'refs/info/rdk-self' => '382fbf9e77a028c2463c82c02e45bc484c49c36b',
	'refs/heads/master' => '134828d4d5f689c02e1a8f013187faad8f7f6ae4',
);
mark_reachable($_) for values %tip;

# Connected components of the revision graph (treated as undirected): each
# one is every historical variant of a single logical commit "position".
my %adj;
for my $key (keys %revision_edges) {
    my ($rev, $commit) = split /\t/, $key;
    push @{ $adj{$rev} }, $commit;
    push @{ $adj{$commit} }, $rev;
}
my %component_seen;
my @revision_groups;
for my $node (keys %adj) {
    next if $component_seen{$node}++;
    my @component = ($node);
    my @stack = ($node);
    while (@stack) {
        my $n = pop @stack;
        for my $neighbor (@{ $adj{$n} // [] }) {
            next if $component_seen{$neighbor}++;
            push @component, $neighbor;
            push @stack, $neighbor;
        }
    }
    push @revision_groups, \@component if @component > 1;
}

my %all_commit;
for my $key (keys %parent_edges) {
    my ($parent, $commit) = split /\t/, $key;
    $all_commit{$parent} = 1;
    $all_commit{$commit} = 1;
}
for my $key (keys %revision_edges) {
    my ($rev, $commit) = split /\t/, $key;
    $all_commit{$rev} = 1;
    $all_commit{$commit} = 1;
}

print "digraph provenance {\n";
print qq{  rankdir=TB;\n};
print qq{  nodesep=1.2;\n};   # spaces same-rank (horizontal) nodes apart, so
                              # the flat revision/ref edges read as visibly
                              # long rather than collapsing to a stub
print qq{  node [shape=box, fontname="monospace"];\n};

# Explicit per-node attributes (unlike a later `node [...]` default
# statement) win regardless of where the node's name first appears in the
# file, so the tag-like ref look survives being mentioned earlier by the
# rank=same pairing below.
for my $refname (keys %tip) {
    print qq{  "$refname" [shape=cds, style=filled, fillcolor=lightyellow, fontname="monospace"];\n};
}

# Commits unreachable from every tip (dead/superseded history) get a dotted
# outline; live ones keep the default solid box.
for my $oid (sort keys %all_commit) {
    my $style = $reachable_node{$oid} ? 'solid' : 'dotted';
    print qq{  "} . short($oid) . qq{" [style=$style];\n};
}

for my $group (@revision_groups) {
    print "  { rank=same; " . join(' ', map { qq{"} . short($_) . qq{"} } @$group) . "; }\n";
}

# Pin each ref right next to the commit it points at, on the same rank,
# instead of leaving it wherever an unconstrained edge happens to land it.
for my $refname (keys %tip) {
    my $tip_oid = $tip{$refname};
    next unless defined $tip_oid;
    print "  { rank=same; \"$refname\" \"" . short($tip_oid) . "\"; }\n";
}

for my $key (sort keys %parent_edges) {
    my ($parent, $commit) = split /\t/, $key;
    my $penwidth = $strong_edge{$key} ? 4 : 1;
    print qq{  "} . short($parent) . qq{" -> "} . short($commit) . qq{" [penwidth=$penwidth];\n};
}

# constraint=false: these two nodes are already pinned to the same rank
# above, so the edge shouldn't also try to push the target a rank lower.
print qq{  edge [style=dotted, constraint=false];\n};
for my $key (sort keys %revision_edges) {
    my ($rev, $commit) = split /\t/, $key;
    print qq{  "} . short($rev) . qq{" -> "} . short($commit) . qq{";\n};
}

print qq{\n  edge [style=solid, penwidth=1, color=orange, constraint=false];\n};
for my $refname (keys %tip) {
    my $tip = $tip{$refname};
    next unless defined $tip;
    print qq{  "$refname" -> "} . short($tip) . qq{";\n};
}

print "}\n";
