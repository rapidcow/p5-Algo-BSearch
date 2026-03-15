#!perl

use Sort::Search;
use Test::More;

BEGIN {
	unless (eval {
		require './xlib/nsec-search.pl';
		Sort::Search->import(qw(bsrchpx cmp_zone));
		1;
	}) {
		note "eval error: $@";
		plan skip_all => "SKIP: failed to load \`./xlib/nsec-search.pl'";
	}

	plan tests => 1;
}

# https://blog.cloudflare.com/black-lies/
subtest "ietf.org" => sub {
	plan tests => 25;

	my $ORIGIN = "ietf.org.";
	chomp (my @mock_zone = map { s/ +/ /g; $_ } split /^/, <<RR);
$ORIGIN       1  IN  SOA
$ORIGIN       2  IN  A
$ORIGIN       3  IN  TXT
$ORIGIN       4  IN  MX
$ORIGIN       5  IN  NS
$ORIGIN       6  IN  AAAA
ietf1._domainkey.$ORIGIN  1  IN TXT
apps.$ORIGIN  1  IN  A
apps.$ORIGIN  2  IN  MX
apps.$ORIGIN  3  IN  AAAA
mail.apps.$ORIGIN  1  IN  A
mail.apps.$ORIGIN  2  IN  AAAA
www.apps.$ORIGIN   1  IN  A
www.apps.$ORIGIN   2  IN  AAAA
cloudflare-verify.$ORIGIN   1  IN  TXT
RR
	my $cmp_rr = sub {
		my ($owner0) = split / /, $_[0];
		my $owner1 = $_[1];
		cmp_zone($owner0, $owner1);
	};

	my ($hi, $prv, $lo, $nxt);

	# This example is given as the NSEC record
	# that denies the existence of "bogus.ietf.org."
	($hi, $prv, $lo, $nxt) = bsrchpx
		{ $cmp_rr->($_, "bogus.$ORIGIN") }
		\@mock_zone;
	cmp_ok ($hi, '<', $lo);
	cmp_ok ($hi, '==', 13);
	cmp_ok ($lo, '==', 14);
	is ($prv, "www.apps.$ORIGIN 2 IN AAAA");
	is ($nxt, "cloudflare-verify.$ORIGIN 1 IN TXT");

	# Similarly for the wildcard domain...
	($hi, $prv, $lo, $nxt) = bsrchpx
		{ $cmp_rr->($_, "*.$ORIGIN") }
		\@mock_zone;
	cmp_ok ($hi, '<', $lo);
	cmp_ok ($hi, '==', 5);
	cmp_ok ($lo, '==', 6);
	is ($prv, "$ORIGIN 6 IN AAAA");
	is ($nxt, "ietf1._domainkey.$ORIGIN 1 IN TXT");

	# Domain that has a lot of records
	($hi, $prv, $lo, $nxt) = bsrchpx
		{ $cmp_rr->($_, $ORIGIN) }
		\@mock_zone;
	cmp_ok ($hi, '>=', $lo);
	cmp_ok ($hi, '==', 5);
	cmp_ok ($lo, '==', 0);
	is ($prv, "$ORIGIN 6 IN AAAA");
	is ($nxt, "$ORIGIN 1 IN SOA");

	# This is impossible in practice; nothing can
	# precede the apex in a zone file manages.
	#
	# Doesn't stop me from testing that, though! :p
	($hi, $prv, $lo, $nxt) = bsrchpx
		{ $cmp_rr->($_, "example.com.") }
		\@mock_zone;
	cmp_ok ($hi, '<', $lo);
	cmp_ok ($hi, '==', -1);
	cmp_ok ($lo, '==', 0);
	is ($prv, undef);
	is ($nxt, "$ORIGIN 1 IN SOA");

	# The case of wrap-around -- in NSEC, the successor
	# would make its way back to the root zone, making
	# it the weird (and only) case where the successor
	# is smaller than the predecessor. Also, I'm pretty
	# sure www.ietf.org. exists; don't take this the
	# wrong way... it's just a test since I can't think
	# of a commonplace non-infra-specific subdomain :P
	($hi, $prv, $lo, $nxt) = bsrchpx
		{ $cmp_rr->($_, "www.$ORIGIN") }
		\@mock_zone;
	cmp_ok ($hi, '<', $lo);
	cmp_ok ($hi, '==', 14);
	cmp_ok ($lo, '==', 15);
	is ($prv, "cloudflare-verify.$ORIGIN 1 IN TXT");
	is ($nxt, undef);
};
