#!/usr/bin/env perl

use v5.36;
use open ':std', ':encoding(UTF-8)';
use autodie qw(:io :system);

$ENV{'GIT_AUTHOR_NAME'} = $0;

while (<STDIN>){
	next unless /^REPLACE/;
	chomp;
	my ($REPLACE, $a, $WITH, $b, $evis) = split / /, $_, 5;
	my $evi = eval $evis;
	open my $pipefh, '|-', "git notes --ref evi add -F - $b";

	print $pipefh $evi;
	if (length $evi) {
		print $pipefh <<TRAILER;

This commit was was originally $a.
See blob a09ff63e2c91c52f0d93dcc89c9d3b5552ea0b53
TRAILER
	}
	close $pipefh;
}
