#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;

# For every commit on refs/heads/master with an author/committer address
# at rapidcow.org or cs.wisc.edu, decides what that address should really
# have been, and writes an evidence paragraph explaining where the commit
# was seen; rebase.pl loads both from commit-provenance-evidence.dump:
#
#   { <commit oid> => { author => <email>, committer => <email>,
#                       evidence => <paragraph> }, ... }
#
# The address comes from the push event that first carried a revision of
# the commit with a byte-identical author (resp. committer) line, i.e. the
# machine that line was actually written on:
#   - rapidcow.org: that meta-commit's own author email, verbatim
#     (rapidcow@RCs-T480s.local, rapidcow@NucBox-G3.local, ...)
#   - cs.wisc.edu: the meta author is just emeng@cs.wisc.edu, so the host
#     comes from the peer's rDNS instead (emeng@vm-instunix-NN.cs.wisc.edu)
#
# When the same oid shows up in both refs/info/rdk-self and rpi-self, the
# earlier event is the real one: the later is either a twin log of the
# same push or (e.g. the cs.wisc.edu commits: lab VM -> rdk, then T480s
# fetches and hops it on to rpi) a mere relay. So "first seen" is always
# "earliest date", whichever ref that lands in.
#
# Reads commit-provenance.tsv (run commit-provenance.pl first).

my $ZERO = '0' x 40;
my $DIFF_RANGE = "$ENV{HOME}/tree/utils/diff-range";
my $OUT = 'commit-provenance-evidence.dump';

my %rows_of;       # commit oid => [ { date, meta, revision, peer }, ... ]
my %revision_of;   # commit oid => the old commit it replaced
my %replaced_in;   # meta oid => { new commit oid => old commit oid }
open my $tsv, '<', 'commit-provenance.tsv' or die "open commit-provenance.tsv: $!\n";
while (<$tsv>) {
    chomp;
    my ($date, $meta, $commit, $parent, $revision, $peer) = split /\t/, $_, -1;
    next unless length $meta;   # predates refs/info/* logging: no event at all
    push @{ $rows_of{$commit} }, { date => $date, meta => $meta,
                                   revision => $revision, peer => $peer };
    if ($revision ne $ZERO) {
        $revision_of{$commit} = $revision;
        $replaced_in{$meta}{$commit} = $revision;
    }
}
close $tsv;

# The notes checkout is full of files named after commit oids, which makes
# every bare oid argument "both revision and filename" -- for us and for
# diff-range alike. Inside the git dir there's no worktree to collide with.
$OUT = do { require Cwd; Cwd::getcwd() } . "/$OUT";
chomp(my $git_dir = qx(git rev-parse --absolute-git-dir));
chdir $git_dir or die "chdir $git_dir: $!\n";

my %raw_cache;
sub raw_commit {
    my ($oid) = @_;
    return $raw_cache{$oid} //= do {
        my $raw = qx(git cat-file commit '$oid' 2>/dev/null);
        die "cat-file commit $oid failed\n" unless length $raw;
        $raw;
    };
}

sub header_line {
    my ($oid, $field) = @_;
    my ($header) = split /\n\n/, raw_commit($oid), 2;
    my ($line) = $header =~ /^\Q$field\E (.*)$/m;
    die "$oid: no $field line\n" unless defined $line;
    return $line;
}

sub email_of {
    my ($ident) = @_;
    my ($email) = $ident =~ /<([^>]*)>/;
    return $email;
}

# The earliest event carrying $commit. With $prev, only the forced updates
# that replaced $prev with $commit count (not later pushes that merely swept
# $commit along with revision=0).
sub first_event {
    my ($commit, $prev) = @_;
    my @rows = @{ $rows_of{$commit} // [] };
    @rows = grep { $_->{revision} eq $prev } @rows if defined $prev;
    my ($first) = sort { $a->{date} <=> $b->{date} || $a->{meta} cmp $b->{meta} } @rows;
    return $first;
}

my %master_of_cache;
sub master_in_snapshot {
    my ($meta) = @_;
    return $master_of_cache{$meta} //= do {
        my $blob = qx(git cat-file blob '$meta:info/refs' 2>/dev/null);
        my ($master) = $blob =~ /^([0-9a-f]{40})\trefs\/heads\/master$/m;
        $master // '';
    };
}

# The push-log line in $meta records refs/heads/master's before/after as
# abbreviations; info/refs in $meta (after) and in its parent meta-commit
# (before) has the full oids.
sub event_tips {
    my ($meta) = @_;
    my $body = qx(git log -1 --format=%B '$meta');
    my ($old, $new) = $body =~ /^\s*refs\/heads\/master\s+([0-9a-f]{4,40})\.\.([0-9a-f]{4,40})\s+\(/m
        or die "$meta: no refs/heads/master OLD..NEW line\n";
    my $expand = sub {
        my ($abbrev, $snapshot) = @_;
        my $full = master_in_snapshot($snapshot);
        return $full if index($full, $abbrev) == 0;
        $full = qx(git rev-parse -q --verify '${abbrev}^{commit}' 2>/dev/null);
        chomp $full;
        die "$meta: can't expand $abbrev\n" unless $full =~ /^[0-9a-f]{40}$/;
        return $full;
    };
    return ($expand->($old, "$meta^"), $expand->($new, $meta));
}

my %first_parents_cache;
sub first_parents {
    my ($tip) = @_;
    return $first_parents_cache{$tip} //= [ split /\n/, qx(git rev-list --first-parent '$tip') ];
}

sub depth_in {
    my ($commit, $tip) = @_;
    my $list = first_parents($tip);
    for my $i (0 .. $#$list) {
        return $i if $list->[$i] eq $commit;
    }
    die "$commit is not on $tip\'s first-parent line\n";
}

sub nth {
    my ($tip, $n) = @_;
    return $n ? "$tip~$n" : $tip;
}

# Every diff-range BEFORE COUNT AFTER the forced update in $meta takes:
# runs of removed commits whose replacements sit at a constant offset, so
# diff-range's positional pairing (BEFORE~i against AFTER~i) matches each
# old revision with its new one. Usually that's one run covering the whole
# rewrite down to where both sides meet again (BEFORE~COUNT = AFTER~COUNT),
# with AFTER shifted down past any genuinely new commits pushed on top; a
# mid-series insertion splits it in two.
sub event_windows {
    my ($meta) = @_;
    my ($before, $after) = event_tips($meta);
    my @removed = split /\n/, qx(git rev-list --first-parent '$before' '^$after');
    my %replacement = reverse %{ $replaced_in{$meta} // {} };
    my @windows;
    for my $i (0 .. $#removed) {
        my $new = $replacement{ $removed[$i] } // next;
        my $e = depth_in($new, $after);
        my $w = $windows[-1];
        if ($w && $w->{i} + $w->{n} == $i && $w->{e} + $w->{n} == $e) {
            $w->{n}++;
        } else {
            push @windows, { i => $i, e => $e, n => 1 };
        }
    }
    return map { [ nth($before, $_->{i}), $_->{n}, nth($after, $_->{e}) ] } @windows;
}

sub pretty
{
	my ($src, @pookie) = @_;
	my @args = @$src;
	foreach my $i (@pookie) {
		$args[$i] =~ s/([[:xdigit:]]{7})[[:xdigit:]]{33}/$1/;
	}
	@args;
}
sub diff_range {
    my @args = @_;
    my @pretty_args = pretty(\@args, 0, 2);
    my $out = qx('$DIFF_RANGE' -- @pretty_args);
    die "diff-range @pretty_args: wstat $?\n" if $?;
    return "\$ ~/tree/utils/diff-range @pretty_args\n$out";
}

my %changes_cache;
sub changes_in {
    my ($meta) = @_;
    return $changes_cache{$meta} //= join "\n", map { diff_range(@$_) } event_windows($meta);
}

sub show_meta {
    my ($meta) = @_;
    my $out = qx(git show -s --format=fuller '$meta');
    die "git show $meta: wstat $?\n" if $?;
    return $out;
}

sub evidence {
    my (@chain) = @_;
    my $first = first_event($chain[0]);
    my @parts = ("This commit was first seen in:", show_meta($first->{meta}));
    for my $i (1 .. $#chain) {
        my $step = first_event($chain[$i], $chain[$i - 1])
            or die "$chain[$i]: no event replacing $chain[$i - 1]\n";
        push @parts, "then in:", show_meta($step->{meta}),
                     "with the following changes:",
                     changes_in($step->{meta});
    }
    chomp @parts;
    return join("\n\n", @parts) . "\n";
}

sub remap {
    my ($oid, $email, $event) = @_;
    die "$oid: no push event to tell where <$email> came from\n" unless $event;
    if ($email =~ /\@cs\.wisc\.edu$/) {
        my ($vm) = $event->{peer} =~ /\((vm-instunix-\d+\.cs\.wisc\.edu)\)$/
            or die "$oid: <$email> traced to $event->{meta}, pushed from $event->{peer}, not a lab VM\n";
        (my $new = $email) =~ s/\@.*/\@$vm/;
        return $new;
    }
    if ($email =~ /\@rapidcow\.org$/) {
        my $new = email_of(header_line($event->{meta}, 'author'));
        die "$oid: <$email> traced to $event->{meta}, whose author <$new> isn't me at a .local host\n"
            unless $new =~ /^(?:rapidcow|ethan)\@[^@]+\.local$/;
        return $new;
    }
    return $email;
}

my %result;
my %tally;
for my $oid (split /\n/, qx(git rev-list refs/heads/master)) {
    my %need = map { $_ => email_of(header_line($oid, $_)) } qw(author committer);
    next unless grep { /\@(?:rapidcow\.org|cs\.wisc\.edu)$/ } values %need;

    my @chain = ($oid);
    unshift @chain, $revision_of{ $chain[0] } while exists $revision_of{ $chain[0] };
    die "$oid: never seen in refs/info/{rdk,rpi}-self\n" unless $rows_of{ $chain[0] };

    my %entry = (evidence => evidence(@chain));
    for my $field (qw(author committer)) {
        my $line = header_line($oid, $field);
        my ($i) = grep { header_line($chain[$_], $field) eq $line } 0 .. $#chain;
        die "$oid: BUG: $field line not even on itself\n" unless defined $i;
        my $event = $i ? first_event($chain[$i], $chain[$i - 1]) : first_event($chain[0]);
        $entry{$field} = remap($oid, $need{$field}, $event);
        $tally{"$field\t<$need{$field}> -> <$entry{$field}>"}++;
    }
    $result{$oid} = \%entry;
}

open my $out, '>', $OUT or die "open $OUT: $!\n";
print { $out } Data::Dumper->new([\%result])->Useqq(1)->Sortkeys(1)->Indent(1)->Terse(1)->Dump;
close $out or die "write $OUT: $!\n";

printf "%5d  %s\n", $tally{$_}, $_ for sort keys %tally;
printf "%5d  commits written to %s\n", scalar(keys %result), $OUT;
