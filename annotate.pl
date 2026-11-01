#!/usr/bin/env perl

use v5.36;
use open ':std', ':encoding(UTF-8)';
use autodie qw(:io :system);

$ENV{'GIT_AUTHOR_NAME'} = $0;

my $C = 0;

while (<STDIN>){
	next unless /^REPLACE/;
	chomp;
	my ($REPLACE, $a, $WITH, $b, $evis) = split / /, $_, 5;
	print(STDERR "Annotating... (@{[++$C]})\r");
	defined $evis or next;
	my $evi = eval $evis;
	open my $pipefh, '|-', "git notes --ref evi add -F - $b";

	print $pipefh <<HEADER;
Originally identified by:

HEADER
	print $pipefh `git show -s --pretty=fuller $a --`;

	if (length $evi) {
		print $pipefh "\n";
	}
	print $pipefh $evi;
	close $pipefh;
}

print(STDERR "Annotating... ($C)\n");
print(STDERR "Done!\n");
