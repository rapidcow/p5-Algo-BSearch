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
		plan skip_all => "failed to load \`./xlib/nsec-search.pl'";
	}

	plan tests => 1;
}

# https://blog.cloudflare.com/black-lies/
subtest "ietf.org" => sub {
	plan tests => 40;

	my $O = "ietf.org.";  # Zone $ORIGIN
	chomp (my @mock_zone = map {
		s/#.*$//;   # Strip comments
		s/ +/ /g;   # Squeeze spaces
		s/ $//;  # Trailing space...
		$_ } split /^/, <<RR);
$O       1  IN  SOA               # 0
$O       2  IN  A                 # 1
$O       3  IN  TXT               # 2
$O       4  IN  MX                # 3
$O       5  IN  NS                # 4
$O       6  IN  AAAA              # 5
ietf1._domainkey.$O  1  IN TXT    # 6
apps.$O  1  IN  A                 # 7
apps.$O  2  IN  MX                # 8
apps.$O  3  IN  AAAA              # 9
mail.apps.$O  1  IN  A            # 10
mail.apps.$O  2  IN  AAAA         # 11
www.apps.$O   1  IN  A            # 12
www.apps.$O   2  IN  AAAA         # 13
cloudflare-verify.$O   1  IN  TXT # 14
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
		{ $cmp_rr->($_, "bogus.$O") }
		\@mock_zone;
	cmp_ok ($hi, '<', $lo, "bogus.$O");
	cmp_ok ($hi, '==', 13);
	cmp_ok ($lo, '==', 14);
	is ($prv, "www.apps.$O 2 IN AAAA");
	is ($nxt, "cloudflare-verify.$O 1 IN TXT");

	# Similarly for the wildcard domain...
	($hi, $prv, $lo, $nxt) = bsrchpx
		{ $cmp_rr->($_, "*.$O") }
		\@mock_zone;
	cmp_ok ($hi, '<', $lo, "*.$O");
	cmp_ok ($hi, '==', 5);
	cmp_ok ($lo, '==', 6);
	is ($prv, "$O 6 IN AAAA");
	is ($nxt, "ietf1._domainkey.$O 1 IN TXT");

	# Domain that has a lot of records
	($hi, $prv, $lo, $nxt) = bsrchpx
		{ $cmp_rr->($_, "$O") }
		\@mock_zone;
	cmp_ok ($hi, '>=', $lo, "$O");
	cmp_ok ($hi, '==', 5);
	cmp_ok ($lo, '==', 0);
	is ($prv, "$O 6 IN AAAA");
	is ($nxt, "$O 1 IN SOA");

	# This is impossible in practice; nothing can
	# precede the apex in a zone file it manages.
	#
	# Doesn't stop me from testing that, though! :p
	($hi, $prv, $lo, $nxt) = bsrchpx
		{ $cmp_rr->($_, "example.com.") }
		\@mock_zone;
	cmp_ok ($hi, '<', $lo, "example.com.");
	cmp_ok ($hi, '==', -1);
	cmp_ok ($lo, '==', 0);
	is ($prv, undef);
	is ($nxt, "$O 1 IN SOA");

	# The case of wrap-around -- in NSEC, the successor
	# would make its way back to the root zone, making
	# it the weird (and only) case where the successor
	# is smaller than the predecessor. Also, I'm pretty
	# sure www.ietf.org. exists; don't take this the
	# wrong way... it's just a test since I can't think
	# of a commonplace non-infra-specific subdomain :P
	($hi, $prv, $lo, $nxt) = bsrchpx
		{ $cmp_rr->($_, "www.$O") }
		\@mock_zone;
	cmp_ok ($hi, '<', $lo, "www.$O");
	cmp_ok ($hi, '==', 14);
	cmp_ok ($lo, '==', 15);
	is ($prv, "cloudflare-verify.$O 1 IN TXT");
	is ($nxt, undef);

	# Edge case: 1
	($hi, $prv, $lo, $nxt) = bsrchpx
		{ $cmp_rr->($_, "ietf1._domainkey.$O") }
		\@mock_zone;
	cmp_ok ($hi, '==', $lo, "ietf1._domainkey.$O");
	cmp_ok ($hi, '==', 6);
	cmp_ok ($lo, '==', 6);
	is ($prv, "ietf1._domainkey.$O 1 IN TXT");
	is ($nxt, "ietf1._domainkey.$O 1 IN TXT");

	# Edge case: 2
	# The interior spans are [12, 13) (13, 14],
	# but $prv (last match) coincides with the
	# right exclusive bound of [12, 13).
	#
	# Something similar happens at "mail.apps"
	# where the spans are [8, 11) (11, 14] and
	# 11 coincides with (11, 14]; testing just
	# one case should be enough, though. :)
	($hi, $prv, $lo, $nxt) = bsrchpx
		{ $cmp_rr->($_, "www.apps.$O") }
		\@mock_zone;
	cmp_ok ($hi, '>=', $lo, "www.apps.$O");
	cmp_ok ($hi, '==', 13);
	cmp_ok ($lo, '==', 12);
	is ($prv, "www.apps.$O 2 IN AAAA");
	is ($nxt, "www.apps.$O 1 IN A");

	# Edge case: 3
	# The interior spans are [0, 7) (7, 14],
	# but $nxt (first match) coincides with
	# the left exclusive bound of (7, 14].
	($hi, $prv, $lo, $nxt) = bsrchpx
		{ $cmp_rr->($_, "apps.$O") }
		\@mock_zone;
	cmp_ok ($hi, '>=', $lo, "apps.$O");
	cmp_ok ($hi, '==', 9);
	cmp_ok ($lo, '==', 7);
	is ($prv, "apps.$O 3 IN AAAA");
	is ($nxt, "apps.$O 1 IN A");
};
