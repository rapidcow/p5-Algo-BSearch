#!perl

use 5.006;
use strict;
use warnings;

my $pipe;
if (!open($pipe, '|-', '/bin/sh', '-')) {
	print "1..0 # SKIP You don't have /bin/sh.\n";
	exit 0;
}

while (<DATA>) {
	print $pipe $_;
}
close $pipe;
my $child = $?;
print sprintf "[Child exited with code 0x%X]\n", $child;
exit $child >> 8;

__DATA__
#!/bin/sh

. xt/lib/test-functions.sh
skip_all TODO
