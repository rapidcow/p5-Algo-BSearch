#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

use Data::Dumper;
use Fcntl qw(:seek);
use IPC::Open2;

use constant DEBUG => 0;

my %REPLACE;
my %futures;
my %parents;

$/ = "\012";
$Data::Dumper::Useqq = 1;

# Per original commit: { author => EMAIL, committer => EMAIL, evidence => TEXT }
# (see commit-provenance-evidence.pl)
my %PROVENANCE = %{
	do './commit-provenance-evidence.dump'
	// die "commit-provenance-evidence.dump: ", $@ || $!, "\n"
};

sub hash
{
	local ($., $!);
	my ($type, @content) = @_;
	my ($rdr, $wtr);
	if ($] < 5.006) {
		require Symbol;
		$rdr = Symbol::gensym();
		$wtr = Symbol::gensym();
	}
	my $pid = open2($rdr, $wtr, qw(git hash-object -t), $type, qw(-w --stdin));
	print { $wtr } @content or warn "hash-object: write pipe: $!\n";
	close $wtr or warn "hash-object: close pipe: $!\n";
	my $hash = <$rdr>;
	waitpid $pid, 0;
	$? == 0 or die "hash-object: died: wstat $? (code @{[$? >> 8]})\n";
	defined $hash or die "BUG: hash-object returned nothing";
	chomp $hash;
	return $hash,
}

foreach my $this (`git rev-list --all`) {
	chomp $this;
	my @parents;
	foreach (`git cat-file commit $this`) {
		next if /^ /;
		if (s/^parent //) {
			chomp;
			push @parents, $_;
		}
		last if /^$/;
	}
	foreach my $past (@parents) {
		push @{$futures{$past}}, $this;
		push @{$parents{$this}}, $past;
	}
}

my %refs = map { chomp; split } split /^/, <<MAP;
fb9d918012b08b9eddd4068f952b552729b60c82 refs/heads/master
MAP
# Abbreviated mentions slip past the full-hash substitution below, so
# these were found by hand: mentioning commit => { abbreviation as it
# appears in the message => full hash of the commit it means }.  The
# abbreviations are stale (pre-rewrite); the walk writes in whatever
# the meant commit has become by then, at the same length.
my %ABBREV = (
	'537fd4a600a15061d246de63b5410889bb0a2eb2' => { '003b40f' => '003b40fd0b7313c873aa1c64c9b35cca91e75fc9' },
	'2b63c6406f32b63b7845a359605ffa9ebcbce6c3' => { '8d9b2e9' => '8d9b2e93d18217c560e55f0d83a49d586a717ea6' },
	'8ad4e057b8677069f25486703e6a1f3f46213556' => { '7a9ae69' => '7a9ae69cbcc42841a45cfcb8a5bd8809d46788f9' },
	'2e1d2c211907d64b359f9ca69b60b6ba449239ae' => { 'e3247b2' => 'e3247b235409e243fc115cb1d60f45e8f67a80e7' },
);
# A commit that mentions another commit by its full hash has to be
# rewritten after it, or the mention would keep the old hash (this
# can happen across branches, where neither is the other's ancestor).
# Treat each mention as one more edge next to the parent edges.
my %deps = map { $_ => [ @{$parents{$_}} ] } keys %parents;
{
	local $/ = "\0";
	my %mentions;
	foreach (`git log --all --format=%H%n%B%x00`) {
		chomp;
		s/\A\s+//;
		next unless length;
		my ($sha, $body) = split /\n/, $_, 2;
		$mentions{$sha} = $body // '';
	}
	foreach my $sha (sort keys %mentions) {
		my %seen;
		foreach (lc($mentions{$sha}) =~ /\b([0-9a-f]{40})\b/g) {
			next if $_ eq $sha || $seen{$_}++ || !exists $mentions{$_};
			push @{$deps{$sha}}, $_;
		}
	}
}
push @{$deps{$_}}, values %{$ABBREV{$_}} foreach keys %ABBREV;
# Reverse topological sort
my @walk = reachable(\%deps, keys %refs);

#
# Non-recursive version of:
#
# L ← Empty list that will contain the sorted nodes
# while exists nodes without a permanent mark do
#     select an unmarked node n
#     visit(n)
#
# function visit(node n)
#     if n has a permanent mark then
#         return
#     if n has a temporary mark then
#         stop   (graph has at least one cycle)
#
#     mark n with a temporary mark
#
#     for each node m with an edge from n to m do
#         visit(m)
#
#     mark n with a permanent mark
#     add n to head of L
#
# /* from https://en.wikipedia.org/wiki/Topological_sorting#Depth-first_search */
sub reachable
{
	my ($graph, @node) = @_;
	my (%count, @list);
	my (@paths, @stop);
	# Stack trace
	@paths = ([]) x @node;
	# Bunch of sentinels
	@stop = (!!0) x @node;
	while (@node) {
		my $node = pop @node;
		my $path = pop @paths;
		my $stop = pop @stop;
		my $count = \$count{$node};

		# @@@ corresponds to bottom half of visit()
		if ($stop) {
			# We've visited all children; STOP and return.
			push @list, $node;
			$$count = 2;
			next;
		}
		# @@@ corresponds to top half of visit()
		$$count ||= 0;
		if ($$count == 2) {
			# Ok?  So $node has been emitted.  No biggie,
			# though it would be unwise to walk this again.
			next;
		}
		if ($$count == 1) {
			# Once of the children from $node led us all
			# the way back to it; there is a cycle in the
			# graph and it cannot be topologically sorted.
			my @path;
			foreach (reverse @$path) {
				push @path, $_;
				last if $_ eq $node;
			}
			die "Cyclic graph eats its own tail at ",
			join ' => ', reverse $node, @path;
		}
		# $count is nil; this is a fresh node
		{
			# Make sure whoever gets here GETS it.  It'd
			# take a while anyways; the children would have
			# all been emitted in the next part of the stack.
			push @node, $node;
			push @paths, $path;
			push @stop, !!1;

			my @path = (@$path, $node);
			foreach (@{$graph->{$node} // []}) {
				push @node, $_;
				push @paths, \@path;
				push @stop, !!0;
			}
		}
	}
	@list;
}

# Maintain nodes in the current graph and the rebased graph
my ($this, $that);
my ($past, $last);

my $i = 1; foreach (@walk) {
	$this = $_;
	$that = $REPLACE{$this} // $this;
	print STDERR "WALK $_ ($i of @{[0+@walk]})\r" if -t STDERR;

	open my $tempfh, '+>', \(my $mem = "") or die "<:memory: error: $!";
	print { $tempfh } `git cat-file commit $that`;

	foreach my $past (@{$parents{$this} // []}) {
		if (($last = $REPLACE{$past} // $past) ne $past) {
			replace_header($tempfh, \$mem, "parent $past", "parent $last");
		}
	}

	# Only the address changes; name, timestamp and zone stay byte-for-byte.
	if (my $prov = $PROVENANCE{$this}) {
		foreach my $field (qw(author committer)) {
			my $line = get_header($tempfh, $field);
			(my $newline = $line) =~ s/<[^>]*>/<$prov->{$field}>/;
			if ($newline ne $line) {
				replace_header($tempfh, \$mem, $field, $newline);
			}
		}
	}

	my $content = get_all_content($tempfh);
	my $newbody = $content;
	foreach my $abbr (sort keys %{$ABBREV{$this} // {}}) {
		my $full = $ABBREV{$this}{$abbr};
		my $now = substr($REPLACE{$full} // $full, 0, length $abbr);
		$newbody =~ s/\b\Q$abbr\E\b/$now/g
			or die "$this: no $abbr in message to replace\n";
	}
	# %REPLACE at the current instant should be just
	# right.  (If a commit was ever able to mention a
	# "future" commit, well.... let's just say, it
	# wouldn't be our job to panic over anyways. :x)
	while (my ($SK, $SV) = each %REPLACE) {
		$newbody =~ s/\Q$SK\E/$SV/ig;
	}
	# Most contents remain untouched, so probably
	# do the check first to avoid pipe overhead...
	unless ($newbody eq $content) {
		replace_content($tempfh, \$mem, $newbody);
	}

	seek $tempfh, 0, SEEK_SET;
	$that = hash commit => <$tempfh>;
	$REPLACE{$this} = $that;
} continue {
	$i += 1;
}
print STDERR "\n" if -t STDERR;

foreach (sort keys %REPLACE) {
	my ($this, $that) = ($_, $REPLACE{$_});
	if ($this ne $that) {
		print "REPLACE $this WITH $that";
		if (my $prov = $PROVENANCE{$this}) {
			print " ", Data::Dumper->new([$prov->{evidence}])
				->Useqq(1)->Indent(0)->Terse(1)->Dump;
		}
		print "\n";
	}
}
my @refs = sort {
	$a->[1] cmp $b->[1]
	|| $a->[0] cmp $b->[0]
} map [ $_ => $refs{$_} ], keys %refs;
foreach my $refv (@refs) {
	my ($sha, $ref) = @$refv;
	print $REPLACE{$sha}, " ", $ref, "\n";
}

sub replace_header
{
	local $.;
	my ($tempfh, $memptr, $spec, $line) = @_;
	chomp $line;
	seek $tempfh, 0, SEEK_SET;
	my @buffer;
	# Reset the input line counter.  Note that
	# simply unsetting $. is useless.
	$. = 0;
	while (<$tempfh>) {
		chomp (my $canon_line = $_);
		if (1 .. /^$/) {
			# If there is a space, consider it a full-line match.
			if ($spec =~ / /) {
				next unless $canon_line eq $spec;
			}
			else {
				# Must be a field name (and not any prefix!)
				next unless /\A\Q$spec\E ?/;
			}
			$_ = "$line$/";
		}
	}
	continue {
		push @buffer, $_;
	}
	$$memptr = '';
	seek $tempfh, 0, SEEK_SET;
	print { $tempfh } $_ for @buffer;
}

sub replace_content
{
	local $.;
	my ($tempfh, $memptr, @content) = @_;
	seek $tempfh, 0, SEEK_SET;
	my @buffer;
	$. = 0;
	while (<$tempfh>) {
		last unless 1 .. /^$/;
	}
	continue {
		push @buffer, $_;
	}
	push @buffer, @content;
	seek $tempfh, 0, SEEK_SET;
	$$memptr = '';
	print { $tempfh } $_ for @buffer;
}

sub get_all_content
{
	local $.;
	local $/ = $/;
	my ($tempfh) = @_;
	seek $tempfh, 0, SEEK_SET;
	$. = 0;
	my $content = '';
	while (<$tempfh>) {
		unless (1 .. /^$/) {
			$content .= $_;
			last;
		}
	}
	undef $/;
	my $morecontent = <$tempfh>;
	$content .= $morecontent if defined $morecontent;
	return $content;
}

sub get_header
{
	local $.;
	local $/ = $/;
	my ($tempfh, $field) = @_;
	seek $tempfh, 0, SEEK_SET;
	$. = 0;
	while (<$tempfh>) {
		last unless 1 .. /^$/;
		if (/\A\Q$field\E /) {
			chomp;
			return $_;
		}
	}
	die "no $field header???";
}

sub get_committer_date
{
	local $.;
	local $/ = $/;
	my ($tempfh) = @_;
	seek $tempfh, 0, SEEK_SET;
	$. = 0;
	while (<$tempfh>) {
		last unless 1 .. /^$/;
		if (/^committer .+ <.*> ([0-9]+)/) {
			return $1;
		}
	}
	die "no committer date???";
}
