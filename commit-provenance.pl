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
#   <info-ref event oid>  <commit oid>  <parent oid (all-zero if root)>  <peer>
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
    my ($raw) = @_;
    return $raw if $raw =~ /\(/;   # already has a parenthetical
    if ($raw =~ /^(\d+\.\d+\.\d+\.\d+):\d+/ && exists $vm{$1}) {
        return "$raw ($vm{$1})";
    }
    return $raw;
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
    my @lines = qx(git log --format='%x01COMMIT %H %ct%n%B' refs/info/$refname);
    my $text = join('', @lines);
    my @chunks = split /\x01COMMIT /, $text;
    shift @chunks while @chunks && $chunks[0] !~ /\S/;

    my @events;
    for my $chunk (@chunks) {
        next unless $chunk =~ /\S/;
        my ($header, $body) = split /\n/, $chunk, 2;
        $body //= '';
        my ($hash, $date) = $header =~ /^(\S+)\s+(\S+)/;
        next unless $hash;

        my ($from) = $body =~ /^From:\s*(.+)$/m;
        $from //= '';

        while ($body =~ /^\s*(refs\/\S+)\s+([0-9a-f]{4,40}|0{7,40})\.\.([0-9a-f]{4,40}|0{7,40})\s+\(([^)]*)\)/mg) {
            my ($ref, $old, $new, $delta) = ($1, $2, $3, $4);
            next unless $ref eq 'refs/heads/master';
            my ($added) = $delta =~ /\+(\d+)/;
            push @events, { meta => $hash, date => $date, old => $old, new => $new,
                            added => $added, from => $from };
        }
    }
    return @events;
}

my @events = (parse_ref('rpi-self'), parse_ref('rdk-self'));

my @rows;   # { meta, commit, parent, peer, date, connected }
for my $e (@events) {
    my $new_full = resolve($e->{new});
    next unless defined $new_full;   # nothing to walk from at all
    my $old_full = resolve($e->{old});
    my $peer = augment_peer($e->{from});

    my %seen_this_event;
    my @pairs;
    if (defined $old_full) {
        push @pairs, parents_in_range("${old_full}..${new_full}");   # added side
        push @pairs, parents_in_range("${new_full}..${old_full}");   # removed side (empty if old is an ancestor of new)
    } elsif ($e->{old} =~ /^0+$/) {
        push @pairs, parents_in_range($new_full);                    # brand new ref
    } elsif (defined $e->{added}) {
        push @pairs, parents_in_range("-n $e->{added} $new_full");
    }

    for my $pair (@pairs) {
        my ($c, $p) = @$pair;
        next if $seen_this_event{$c}++;
        push @rows, {
            meta => $e->{meta}, commit => $c,
            parent => (defined $p ? $p : $ZERO),
            peer => $peer, date => $e->{date},
            connected => ($all270{$c} ? 1 : 0),
        };
    }
}

# ---- sort: dangling commits first, connected (part of HEAD's 270) last;
# within each group, topological (parent before child) then event date ----
sub topo_sort_by_date {
    my (@nodes) = @_;
    my %indeg;
    my %succs;     # parent-commit => [ rows whose commit is that parent's child ]
    my %producers; # commit => [ rows that ARE this commit (could be >1, same commit multiple events) ]
    push @{ $producers{ $_->{commit} } }, $_ for @nodes;

    for my $n (@nodes) {
        $indeg{$n} = 0;
    }
    for my $n (@nodes) {
        next if $n->{parent} eq $ZERO;
        if (my $preds = $producers{ $n->{parent} }) {
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
    print join("\t", $r->{meta}, $r->{commit}, $r->{parent}, $r->{peer}), "\n";
}
