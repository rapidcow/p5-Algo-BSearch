#!/usr/bin/env perl

package Sort::Search::Tree;

use strict;
use warnings;
use List::Util qw(max);
use Sort::Search qw(blsrch1 blsrch2);

use Exporter ();
our (@ISA, @EXPORT);
BEGIN {
	@ISA = qw(Exporter);
	@EXPORT = qw(
		BST_leap BST_delv
		uri_strtok dns_strtok
		make_acomp
	);
}

sub BST_leap {
	my ($acomp, $list, $node) = @_;
	# Step 1: bound the whole subtree
	my ($lo, $hi) = blsrch2 { $acomp->($_, $node) - 1 } $list;

	# Step 2: iterate direct children, skipping subtrees
	my @children;
	while ($lo < $hi) {
		my $child = $list->[$lo];
		push @children, $child;
		# blsrch1 finds first element where acomp > 1 relative to $child,
		# i.e. first successor -- skips $child's entire subtree
		$lo = blsrch1 { $acomp->($_, $child) - 1 } $list, $lo + 1, $hi;
	}
	@children;
}

sub BST_delv {
	my ($acomp, $list, $node) = @_;
	# Just bound the whole subtree
	my ($lo, $hi) = blsrch2 { $acomp->($_, $node) - 1 } $list;
	@{$list}[$lo .. $hi-1];
}

sub uri_strtok {
	my ($path) = @_;
	$path =~ s{^/}{};
	grep { $_ ne '.' } split m{/}, $path, -1;
}

sub dns_strtok {
	my ($path) = @_;
	$path =~ s{\.$}{};
	reverse split m{\.}, $path, -1;
}

sub make_acomp {
	my ($strtok, $strcmp) = @_;
	sub {
		my ($atok, $btok) = @_;
		my (@atok, @btok);

		@atok = $strtok->($_[0]);
		@btok = $strtok->($_[1]);

		acomp(\@atok, \@btok, $strcmp);
	};
}

sub acomp {
	my ($atok, $btok, $strcmp) = @_;

	my $res = 0;
	foreach (0 .. max($#$atok, $#$btok)) {
		$res = ($_ < @$atok) - ($_ < @$btok);
		return $res if $res;

		$res = $strcmp
			? $strcmp->($atok->[$_], $btok->[$_])
			: $atok->[$_] cmp $btok->[$_];
		return $res < 0 ? -2 : 2 if $res;
	}
	return $res;
}

return 1 if caller;

package main;

use strict;
use warnings;
use Getopt::Long;
use File::Find;
use File::Spec;
no locale;

BEGIN { Sort::Search::Tree->import(); }

sub usage {
<<USE;
usage: $0 find [-x EXCL]* [ROOT] > TREE
       $0 leap [-K KIND] NODE < TREE
       $0 delv [-K KIND] NODE < TREE
USE
}

my $cmd = $ARGV[0];

if (defined $cmd && grep { $cmd eq $_ } qw(find leap delv)) {
	shift;
} else {
	$cmd = 'find';
}

if ($cmd eq 'find') {
	my @excl;
	GetOptions('x=s@' => \@excl) or die usage();

	my $root = shift;
	$root ||= ".";

	find({
		preprocess => sub { sort @_ },
		wanted => sub {
			my $filename = File::Spec->abs2rel($File::Find::name, $root);

			for my $excl (@excl) {
				if ($filename eq $excl) {
					$File::Find::prune = 1;
					return;
				}
			}

			print "$filename$/";
		}
	}, $root);
} else {
	my $kind = 'uri';
	GetOptions('K=s' => \$kind) and my $node = shift or die usage();

	chomp (my @list = <STDIN>);
	my $acomp = make_acomp(do { no strict 'refs'; \&{"${kind}_strtok"} });
	my @children = do { no strict 'refs'; \&{"BST_${cmd}"} }->($acomp, \@list, $node);
	print "$_$/" foreach @children;
}
