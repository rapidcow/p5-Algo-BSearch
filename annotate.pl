#!/usr/bin/env perl

use v5.36;
use open ':std', ':encoding(UTF-8)';
use autodie qw(:io :system);

$ENV{'GIT_AUTHOR_NAME'} = $0;

while (<STDIN>){
	next unless /^REPLACE/;
	chomp;
	my ($REPLACE, $a, $WITH, $b, $evis) = split / /, $_, 5;
	defined $evis or next;
	my $evi = eval $evis;
	open my $pipefh, '|-', "git notes --ref evi add -F - $b";

	print $pipefh $evi;
	if (length $evi) {
		print $pipefh <<TRAILER;

This commit was was originally $a.
See blob 5c47204c0877bc58e0a8b4c1bcb1443ee85c0fa9.
TRAILER
	}
	close $pipefh;
}
