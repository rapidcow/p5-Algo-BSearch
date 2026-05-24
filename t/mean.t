#!perl
# t/mean.t - midpoints over potentially big IV/UV
use 5.006;
use strict;
use warnings;

use Test::More tests => 42;
use Sort::Search qw(bixectl bixectr);

use constant uvmin => ( +0 );  # (is actually an IV...)
use constant uvmax => ( ~0 );
use constant ivmax => ( uvmax() >> 1 );
use constant ivmin => ( -ivmax() - 1 );

BEGIN {
	no strict 'refs';
	foreach my $name (qw( uvmin uvmax ivmin ivmax )) {
		foreach (&{"::$name"}) {
			note "DBG: $name " . sprintf "%s%#x",
			$_ < 0 ? ('-', -$_) : ('+', +$_);
		}
	}
}

sub lmean { scalar bixectl { 1 } $_[0], $_[1] }
sub rmean { scalar bixectr { 1 } $_[1], $_[0] }

sub lmean_ok {
	local $Test::Builder::Level = $Test::Builder::Level + 1;
	my $mesg = sprintf "lmean(%s%#x, %s%#x) = %s%#x",
		map { $_ < 0 ? ('-', -$_) : ('+', +$_) } @_;
	cmp_ok (lmean( $_[0], $_[1] ), '==', ( $_[2] ), $mesg);
}

lmean_ok +( 0, 1 ) => ( 0 );
lmean_ok +( -10, 42 ) => ( 16 );
lmean_ok +( 0, 69 ) => ( 34 );
lmean_ok +( -1, 0 ) => ( -1 );
lmean_ok +( -42, 10 ) => ( -16 );
lmean_ok +( -69, 0 ) => ( -35 );
lmean_ok +( 0,     ivmax ) => ( ivmax >> 1 );
lmean_ok +( 0,  -2+uvmax ) => ( ivmax ) - 1;
lmean_ok +( 0,  -1+uvmax ) => ( ivmax );
lmean_ok +( 0,     uvmax ) => ( ivmax );
lmean_ok +( ivmin, ivmax ) => ( -1 );
lmean_ok +( ivmin, uvmax ) => ( ivmax >> 1 );

lmean_ok +( ivmin, ivmin+1 ) => ( ivmin );
lmean_ok +( ivmin, ivmin+2 ) => ( ivmin + 1 );
lmean_ok +( ivmin, ivmin+3 ) => ( ivmin + 1 );
lmean_ok +( ivmax-1, ivmax ) => ( ivmax - 1 );
lmean_ok +( ivmax-2, ivmax ) => ( ivmax - 1 );
lmean_ok +( ivmax-3, ivmax ) => ( ivmax - 2 );
lmean_ok +( uvmax-1, uvmax ) => ( uvmax - 1 );
lmean_ok +( uvmax-2, uvmax ) => ( uvmax - 1 );
lmean_ok +( uvmax-3, uvmax ) => ( uvmax - 2 );

sub rmean_ok {
	local $Test::Builder::Level = $Test::Builder::Level + 1;
	my $mesg = sprintf "rmean(%s%#x, %s%#x) = %s%#x", map {
		$_ < 0 ? ('-', -$_) : ('+', +$_),
	} @_;
	cmp_ok (rmean( $_[0], $_[1] ), '==', ( $_[2] ), $mesg);
}

rmean_ok +( 0, 1 ) => ( 1 );
rmean_ok +( -10, 42 ) => ( 16 );
rmean_ok +( 0, 69 ) => ( 35 );
rmean_ok +( -1, 0 ) => ( 0 );
rmean_ok +( -42, 10 ) => ( -16 );
rmean_ok +( -69, 0 ) => ( -34 );
rmean_ok +( 0,     ivmax ) => ( ivmax >> 1 ) + 1;
rmean_ok +( 0,  -2+uvmax ) => ( ivmax );
rmean_ok +( 0,  -1+uvmax ) => ( ivmax );
rmean_ok +( 0,     uvmax ) => ( ivmax ) + 1;
rmean_ok +( ivmin, ivmax ) => ( 0 );
rmean_ok +( ivmin, uvmax ) => ( ivmax >> 1 ) + 1;

rmean_ok +( ivmin, ivmin+1 ) => ( ivmin + 1 );
rmean_ok +( ivmin, ivmin+2 ) => ( ivmin + 1 );
rmean_ok +( ivmin, ivmin+3 ) => ( ivmin + 2 );
rmean_ok +( ivmax-1, ivmax ) => ( ivmax );
rmean_ok +( ivmax-2, ivmax ) => ( ivmax - 1 );
rmean_ok +( ivmax-3, ivmax ) => ( ivmax - 1 );
rmean_ok +( uvmax-1, uvmax ) => ( uvmax );
rmean_ok +( uvmax-2, uvmax ) => ( uvmax - 1 );
rmean_ok +( uvmax-3, uvmax ) => ( uvmax - 1 );
