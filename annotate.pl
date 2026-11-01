#!/usr/bin/env perl

use strict;
use warnings;

while (<STDIN>){
	next unless /^REPLACE/;
	chomp;
	my ($REPLACE, $a, $WITH, $b, $evis) = split / /, $_, 5;
	my $evi = eval $evis;
	die $evi;
	system "git notes --ref evi ${evi}";
}
