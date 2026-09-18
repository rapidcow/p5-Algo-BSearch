#!/usr/bin/env perl
use strict;
use warnings;

# For every push-event touching refs/heads/master recorded in
# refs/info/{rpi,rdk}-self, logs EVERY commit in the symmetric difference
# of the ref's before/after value (not just the event's two endpoints):
# a straight fast-forward logs its added commits; an amend/rewrite logs
# both the abandoned old-side commits and their new-side replacements.
# The same commit can legitimately get more than one row (once per event
# that touched it).
#
#   <date>  <info-ref event oid>  <commit oid>  <parent oid (all-zero if root)>
#   <revision oid (all-zero if not a forced-update replacement)>  <peer>
#
# Run `git name-rev <event oid>` to see which ref/offset an event came from.

my $HEAD = '134828d4d5f689c02e1a8f013187faad8f7f6ae4';

# ---- static table: rdk-self (the VPS) had rDNS logging disabled for a
# stretch (it hung on residential IPs), so these cs.wisc.edu lab-VM
# addresses show up bare even though real PTR records exist. ----
my %vm = (
    '128.105.37.132' => 'vm-instunix-00.cs.wisc.edu',
    '128.105.37.139' => 'vm-instunix-01.cs.wisc.edu',
    '128.105.37.133' => 'vm-instunix-02.cs.wisc.edu',
    '128.105.37.172' => 'vm-instunix-03.cs.wisc.edu',
    '128.105.37.140' => 'vm-instunix-04.cs.wisc.edu',
    '128.105.37.171' => 'vm-instunix-05.cs.wisc.edu',
    '128.105.37.134' => 'vm-instunix-06.cs.wisc.edu',
    '128.105.37.136' => 'vm-instunix-07.cs.wisc.edu',
    '128.105.37.138' => 'vm-instunix-08.cs.wisc.edu',
    '128.105.37.162' => 'vm-instunix-09.cs.wisc.edu',
    '128.105.37.185' => 'vm-instunix-10.cs.wisc.edu',
    '128.105.37.173' => 'vm-instunix-11.cs.wisc.edu',
    '128.105.37.176' => 'vm-instunix-12.cs.wisc.edu',
    '128.105.37.186' => 'vm-instunix-13.cs.wisc.edu',
    '128.105.37.177' => 'vm-instunix-14.cs.wisc.edu',
    '128.105.37.179' => 'vm-instunix-15.cs.wisc.edu',
    '128.105.37.184' => 'vm-instunix-16.cs.wisc.edu',
    '128.105.37.178' => 'vm-instunix-17.cs.wisc.edu',
    '128.105.37.175' => 'vm-instunix-18.cs.wisc.edu',
    '128.105.37.174' => 'vm-instunix-19.cs.wisc.edu',
);

sub augment_peer {
    my ($from, $mail) = @_;
    return $from if $from =~ /\(/;   # already has a parenthetical
    if ($mail =~ /@(.+\.(?:
            local        |# RFC 6762 (mDNS | Bonjour)
            arpa         |# RFC 3172, BCP 52 (e.g. home.arpa)
            # RFC 2606, BCP 32; RFC 6761. (reserved TLD)
            test|example|localhost|invalid
    ))$/x) {
        return "$from ($1)";
    }
    if ($from =~ /^(\d+\.\d+\.\d+\.\d+):\d+/ && exists $vm{$1}) {
        return "$from ($vm{$1})";
    }
    return $from;
}

my %subject_cache;
sub subject_of {
    my ($oid) = @_;
    return $subject_cache{$oid} //= do {
        my $s = qx(git log -1 --format=%s '$oid' 2>/dev/null);
        chomp $s;
        $s;
    };
}

my %resolved;
sub resolve {
    my ($abbrev) = @_;
    return undef if $abbrev =~ /^0+$/;
    return $resolved{$abbrev} if exists $resolved{$abbrev};
    my $full = qx(git rev-parse -q --verify '${abbrev}^{commit}' 2>/dev/null);
    chomp $full;
    $full = undef unless $full =~ /^[0-9a-f]{40}$/;
    return $resolved{$abbrev} = $full;
}

my %all270 = map { chomp; $_ => 1 } qx(git rev-list $HEAD);
my $ZERO = '0' x 40;

# git rev-list --parents <range> => "commit [parent]" per line (root commits
# have no parent token). Returns a list of [commit, parent-or-undef].
sub parents_in_range {
    my ($range) = @_;
    my @out;
    for my $line (split /\n/, qx(git rev-list --parents $range 2>/dev/null)) {
        my ($c, $p) = split ' ', $line;   # only first parent: history is linear here
        push @out, [$c, $p];
    }
    return @out;
}

sub parse_ref {
    my ($refname) = @_;
    my @lines = qx(git log --format='%x01COMMIT %H %ct %ae%n%B' refs/info/$refname);
    my $text = join('', @lines);
    my @chunks = split /\x01COMMIT /, $text;
    shift @chunks while @chunks && $chunks[0] !~ /\S/;

    my @events;
    for my $chunk (@chunks) {
        next unless $chunk =~ /\S/;
        my ($header, $body) = split /\n/, $chunk, 2;
        $body //= '';
        my ($hash, $date, $mail) = $header =~ /^(\S+) (\S+) (.+)/;
        next unless $hash;

        my ($from) = $body =~ /^From:\s*(.+)$/m;
        $from //= '';

        while ($body =~ /^\s*(refs\/\S+)\s+([0-9a-f]{4,40}|0{7,40})\.\.([0-9a-f]{4,40}|0{7,40})\s+\(([^)]*)\)/mg) {
            my ($ref, $old, $new, $delta) = ($1, $2, $3, $4);
            next unless $ref eq 'refs/heads/master';
            my ($added) = $delta =~ /\+(\d+)/;
            push @events, { meta => $hash, date => $date, old => $old, new => $new,
                            added => $added, delta => $delta, from => $from, mail => $mail };
        }
    }
    return @events;
}

my @events = (parse_ref('rpi-self'), parse_ref('rdk-self'));

my @rows;   # { meta, commit, parent, revision, peer, date, connected }
for my $e (@events) {
    my $new_full = resolve($e->{new});
    next unless defined $new_full;   # nothing to walk from at all
    my $old_full = resolve($e->{old});
    my $peer = augment_peer($e->{from}, $e->{mail});

    my (@added_pairs, @removed_pairs);
    if (defined $old_full) {
        @added_pairs   = parents_in_range("${old_full}..${new_full}");
        @removed_pairs = parents_in_range("${new_full}..${old_full}");   # empty if old is an ancestor of new
    } elsif ($e->{old} =~ /^0+$/) {
        @added_pairs = parents_in_range($new_full);                     # brand new ref
    } elsif (defined $e->{added}) {
        @added_pairs = parents_in_range("-n $e->{added} $new_full");
    }

    # A forced update ("-N+M") is only a clean 1:1 revision (each new commit
    # replacing exactly one old commit, aligned from the tip backward like
    # git range-diff) when N == M. Anything else -- commits genuinely added
    # or dropped alongside the rewrite -- doesn't have a well-defined
    # per-commit correspondence, so just warn and leave it unpaired.
    my %revision_of;   # added-side commit oid => its old-side counterpart oid
    if (@added_pairs && @removed_pairs) {
        if (@added_pairs == @removed_pairs) {
            for my $i (0 .. $#added_pairs) {
                $revision_of{ $added_pairs[$i][0] } = $removed_pairs[$i][0];
            }
        } elsif (@added_pairs > @removed_pairs) {
            # Dumb heuristic for "-N+M" with M > N: line up both sides
            # oldest-first (git rev-list returns newest-first, so reverse),
            # walk the first N positions from there, and call two commits
            # the same "revision" when they share a commit SUBJECT (not the
            # tree -- deliberately loose). The M-N commits left over at the
            # *newest* end are just a normal new push, not a replacement --
            # verified against a real case where the genuinely-new commit
            # was the tip and the true replacement sat one position deeper.
            # This still won't recover a mid-series insertion (confirmed
            # against another real range-diff in refs/notes/amends), but
            # that's the "dumb" tradeoff.
            my @added_oldest_first   = reverse @added_pairs;
            my @removed_oldest_first = reverse @removed_pairs;
            my $n = scalar(@removed_oldest_first);
            for my $i (0 .. $n - 1) {
                my ($a, $r) = ($added_oldest_first[$i][0], $removed_oldest_first[$i][0]);
                $revision_of{$a} = $r if subject_of($a) eq subject_of($r);
            }
        } else {
            warn sprintf("asymmetric forced update in %s (delta %s): "
                       . "%d added vs %d removed commits -- not pairing\n",
                       $e->{meta}, $e->{delta}, scalar(@added_pairs), scalar(@removed_pairs));
        }
    }

    my %seen_this_event;
    for my $pair (@added_pairs, @removed_pairs) {
        my ($c, $p) = @$pair;
        next if $seen_this_event{$c}++;
        push @rows, {
            meta => $e->{meta}, commit => $c,
            parent => (defined $p ? $p : $ZERO),
            revision => ($revision_of{$c} // $ZERO),
            peer => $peer, date => $e->{date},
            connected => ($all270{$c} ? 1 : 0),
        };
    }
}

# Some commits (e.g. ones predating refs/info/* logging entirely) never show
# up in either log at all, so the loop above never emits a row for them.
# Still list them -- with no event/peer to report -- so every one of HEAD's
# commits is guaranteed at least one row, using the commit's own parent and
# its own committer date (there's no push event to borrow a date from).
my %have_row = map { $_->{commit} => 1 } @rows;
for my $oid (keys %all270) {
    next if $have_row{$oid};
    my $parent = qx(git rev-parse -q --verify '${oid}^' 2>/dev/null);
    chomp $parent;
    $parent = $ZERO unless $parent =~ /^[0-9a-f]{40}$/;
    my $date = qx(git log -1 --format=%ct '$oid');
    chomp $date;
    push @rows, {
        meta => '', commit => $oid, parent => $parent,
        revision => $ZERO,
        peer => '', date => $date, connected => 1,
    };
}

# ---- sort: dangling commits first, connected (part of HEAD's 270) last;
# within each group, topological (old revision before its replacement) then
# event date. Ordered by the revision column, not the git-parent column:
# most rows have no revision predecessor at all (only forced-update rewrites
# do), so this only constrains amend chains to read old-then-new and leaves
# everything else to sort by date.
sub topo_sort_by_date {
    my (@nodes) = @_;
    my %indeg;
    my %succs;     # old-revision commit => [ rows whose revision is that commit ]
    my %producers; # commit => [ rows that ARE this commit (could be >1, same commit multiple events) ]
    push @{ $producers{ $_->{commit} } }, $_ for @nodes;

    for my $n (@nodes) {
        $indeg{$n} = 0;
    }
    for my $n (@nodes) {
        next if $n->{revision} eq $ZERO;
        if (my $preds = $producers{ $n->{revision} }) {
            $indeg{$n} += scalar(@$preds);
            push @{ $succs{$_} }, $n for @$preds;
        }
    }

    my @ready = grep { $indeg{$_} == 0 } @nodes;
    my @out;
    my %done;
    while (@ready) {
        @ready = sort { $a->{date} <=> $b->{date} } @ready;
        my $n = shift @ready;
        next if $done{$n}++;
        push @out, $n;
        for my $s (@{ $succs{$n} // [] }) {
            next if $done{$s};
            $indeg{$s}--;
            push @ready, $s if $indeg{$s} <= 0;
        }
    }
    push @out, sort { $a->{date} <=> $b->{date} } grep { !$done{$_} } @nodes;
    return @out;
}

my @dangling  = grep { !$_->{connected} } @rows;
my @connected = grep {  $_->{connected} } @rows;

for my $r (topo_sort_by_date(@dangling), topo_sort_by_date(@connected)) {
    print join("\t", $r->{date}, $r->{meta}, $r->{commit}, $r->{parent}, $r->{revision}, $r->{peer}), "\n";
}
