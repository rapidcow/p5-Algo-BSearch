#!/usr/bin/env perl
use strict;
use warnings;

# Reads commit-provenance.tsv (on stdin) and draws a Graphviz digraph:
#   - solid edges  : parent -> commit   (the real git-parent DAG, "strong" links)
#   - dotted edges : revision -> commit (amendment/rewrite chains only)
# plus refs/info/rpi-self, refs/info/rdk-self and refs/heads/master as
# special-shaped nodes pointing at whatever commit they currently resolve to.
# All commit nodes are named by their first 8 hex digits.
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

my %tip = (
	'refs/info/rpi-self' => '29a7737034c5afe164ea003f19a7095c7d48f35a',
	'refs/info/rdk-self' => '382fbf9e77a028c2463c82c02e45bc484c49c36b',
	'refs/heads/master' => '134828d4d5f689c02e1a8f013187faad8f7f6ae4',
);

print "digraph provenance {\n";
print qq{  rankdir=LR;\n};
print qq{  node [shape=box, fontname="monospace"];\n};

print qq{  edge [style=solid];\n};
for my $key (sort keys %parent_edges) {
    my ($parent, $commit) = split /\t/, $key;
    print qq{  "} . short($parent) . qq{" -> "} . short($commit) . qq{";\n};
}

print qq{  edge [style=dotted];\n};
for my $key (sort keys %revision_edges) {
    my ($rev, $commit) = split /\t/, $key;
    print qq{  "} . short($rev) . qq{" -> "} . short($commit) . qq{";\n};
}

print qq{\n  node [shape=cds, style=filled, fillcolor=lightyellow];\n};
print qq{  edge [style=bold, color=orange];\n};
for my $refname (keys %tip) {
    my $tip = $tip{$refname};
    next unless defined $tip;
    print qq{  "$refname" -> "} . short($tip) . qq{";\n};
}

print "}\n";
