#!/usr/bin/env perl
use strict;
use warnings;

# Reads commit-provenance.tsv and draws the "revision" column (older
# revision -> newer revision, i.e. amendment/rewrite chains only -- not the
# git-parent DAG) as a Graphviz digraph, one dotted edge per pair, 8-hex-digit
# abbreviated node names.
#
#   perl commit-provenance-graph.pl < commit-provenance.tsv > revisions.dot
#   dot -Tsvg revisions.dot -o revisions.svg

my $ZERO = '0' x 40;
my %edges;   # "revision\tcommit" => 1 (deduped: the same amend can be logged
             # by both rpi-self and rdk-self)
while (my $line = <STDIN>) {
    chomp $line;
    next unless length $line;
    next if $line =~ /^;/;
    my (undef, undef, $commit, undef, $revision) = split /\t/, $line;
    next unless defined $revision && length($revision) && $revision ne $ZERO;
    $edges{"$revision\t$commit"} = 1;
}

print "digraph revisions {\n";
print qq{  rankdir=LR;\n};
print qq{  node [shape=box, fontname="monospace"];\n};
print qq{  edge [style=dotted];\n};
for my $key (sort keys %edges) {
    my ($rev, $commit) = split /\t/, $key;
    print qq{  "} . substr($rev, 0, 8) . qq{" -> "} . substr($commit, 0, 8) . qq{";\n};
}
print "}\n";
