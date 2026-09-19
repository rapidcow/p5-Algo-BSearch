#!/usr/bin/env perl
use strict;
use warnings;
use File::Temp qw(tempfile);

# Materializes "what did refs/heads/master look like, as observed in this
# info-ref's own info/refs snapshot, over time" (the same data
# commit-provenance.pl's companion file and the pink/blue graph edges come
# from) as REAL git commits -- one link-commit per transition -- written to:
#   refs/link/info/rpi-self/for/refs/heads/master
#   refs/link/info/rdk-self/for/refs/heads/master
#
# Format (see ~/ics/uwisc/cslab/reslog.pl for a similar reflog-as-commits
# idea; simpler here since it's derived from fixed historical data rather
# than an append-only mutable reflog file, so there's no pooling/reuse step):
#   - the first transition is a single-parent link-commit: parent = the
#     newly observed master oid
#   - every later transition is a two-parent link-commit: parent 1 = the
#     previous link-commit (continuing the log chain), parent 2 = the newly
#     observed master oid
#   - tree = the tree of the currently-observed master oid
#   - author/committer copied byte-for-byte from the meta-commit whose
#     info/refs snapshot first showed this transition (built from the raw
#     header text, not re-derived via git's own date formatting -- that can
#     silently normalize "-0000" to "+0000" and change what's reproduced)
#   - subject "[LOG] <meta-commit's own subject>", always with the space:
#     bare "[LOG]" with no trailing space is reslog.pl's reserved marker for
#     an absent reflog entry, which doesn't apply here (our subjects are
#     never absent)
#
# 100% deterministic: every value written comes from already-committed git
# history in a fixed order, so identical inputs always produce identical
# commit oids -- re-running this is a no-op if nothing upstream changed.

my $ZERO = '0' x 40;

sub raw_commit {
    my ($oid) = @_;
    my $raw = qx(git cat-file -p '$oid' 2>/dev/null);
    die "cat-file -p $oid failed\n" unless length $raw;
    return $raw;
}

sub header_and_body {
    my ($oid) = @_;
    my ($header, $body) = split /\n\n/, raw_commit($oid), 2;
    die "$oid: couldn't split header/body\n" unless defined $body;
    return ($header, $body);
}

sub tree_of {
    my ($oid) = @_;
    my ($header) = header_and_body($oid);
    my ($tree) = $header =~ /^tree ([0-9a-f]{40})$/m;
    die "$oid: no tree line\n" unless defined $tree;
    return $tree;
}

sub hash_commit {
    my ($content) = @_;
    my ($fh, $filename) = tempfile();
    print $fh $content;
    close $fh;
    my $oid = qx(git hash-object -t commit -w '$filename');
    chomp $oid;
    unlink $filename;
    die "hash-object failed on:\n$content\n" unless $oid =~ /^[0-9a-f]{40}$/;
    return $oid;
}

sub process_ref {
    my ($refname) = @_;

    my @meta_chain = split /\n/, qx(git log --format=%H --reverse refs/info/$refname);

    my @transitions;   # [ meta_oid, master_oid ]
    my $prev_master = $ZERO;
    for my $meta (@meta_chain) {
        my $blob = qx(git cat-file blob '$meta:info/refs' 2>/dev/null);
        my ($master) = $blob =~ /^([0-9a-f]{40})\trefs\/heads\/master$/m;
        next unless defined $master;
        next if $master eq $prev_master;
        push @transitions, [$meta, $master];
        $prev_master = $master;
    }

    my $prev_link;
    for my $i (0 .. $#transitions) {
        my ($meta, $master) = @{ $transitions[$i] };
        my ($header) = header_and_body($meta);
        my ($author_line)    = $header =~ /^author (.*)$/m;
        my ($committer_line) = $header =~ /^committer (.*)$/m;
        die "$meta: no author line\n"    unless defined $author_line;
        die "$meta: no committer line\n" unless defined $committer_line;
        my (undef, $meta_body) = header_and_body($meta);
        my ($subject) = split /\n/, $meta_body, 2;

        my $tree = tree_of($master);
        my @parents = $i == 0 ? ($master) : ($prev_link, $master);

        my $content = join('', map { "$_\n" } (
            "tree $tree",
            (map { "parent $_" } @parents),
            "author $author_line",
            "committer $committer_line",
            "",
            "[LOG] $subject",
        ));
        $prev_link = hash_commit($content);
    }

    if (defined $prev_link) {
        my $target = "refs/link/info/$refname/for/refs/heads/master";
        system('git', 'update-ref', $target, $prev_link) == 0
            or die "update-ref $target failed\n";
        print "$target -> $prev_link (", scalar(@transitions), " transitions)\n";
    }
}

process_ref($_) for qw(rpi-self rdk-self);
