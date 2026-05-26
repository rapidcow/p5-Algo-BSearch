#!/usr/bin/env perl

package Sort::Search::Tree;

use strict;
use warnings;
use List::Util qw(min);
use Sort::Search qw(blsrch2);
use Exporter ();

our @EXPORT = qw(
	BST_leap BST_delv
	uri_strtok dns_strtok
	make_acomp
);
our @ISA = qw(Exporter);

sub BST_leap {
	my ($acomp, $list, $node) = @_;
	# Step 1: bound the whole subtree
	my ($lo, $hi) = blsrch2 { $acomp->($_, $node) - 1 } $list;

	# Step 2: iterate direct children, skipping subtrees
	my @children;
	while ($lo < $hi) {
		my $child = $list->[$lo];
		push @children, $child;
		# blsrch1 finds first element where acomp > 0 relative to $child,
		# i.e. first successor — skips $child's entire subtree
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
	split m{/}, $path, -1;
}

sub dns_strtok {
	my ($path) = @_;
	$path =~ s{\.$}{};
	split m{\.}, $path, -1;
}

sub make_acomp {
	my ($strtok, $strcmp) = @_;
	sub {
		my ($atok, $btok) = @_;
		my (@atok, @btok);

		@atok = $strtok->($_[0]);
		@btok = $strtok->($_[0]);

		acomp(\@atok, \@btok, $strcmp);
	};
}

sub acomp {
	my ($atok, $btok, $strcmp) = @_;

	my $res = 0;
	foreach (0 .. max($#$atok, $#$btok)) {
		$res = ($_ < @$atok) - ($_ < @$btok);
		return $res if $res;

		$res = $strcmp->($atok->[$_], $btok->[$_]);
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

my @excl;
GetOptions('x=s@' => \@excl) or die "usage: $0 [-x EXCL]* [ROOT]";

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
