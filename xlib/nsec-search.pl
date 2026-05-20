#!/usr/bin/env perl

=head1 NAME

C<xlib/nsec-search.pl> -
Search for predecessor and succesor.
Inspired by DNSSEC NextSECure (NSEC) records.

Modified from C<blsrch2>.  The funny suffix
is short for "Previous" and "neXt".

For an example of extending the real C<Search.pm>
with this, see C<xt/nsec-search.t>.  I don't have
a good name for this, nor see a good use case for
it besides the (unrealistic) use case as a DNSSEC
name server in action, so it will live in the
C<xlib/> directory for now.

=cut

package Sort::Search;

=head1 SUBROUTINES

=over

=item B<bsrchpx { ORD } ARRAY>

Like C<blsrch2> (but reversed!), this return the
last (right) and first (left) match on "success",
OR the predecessor and the successor on "failure".

(I put "failure" in air quotes because that is
precisely the NSEC record that would be served
for when a domain name falls within such range. ;)

The index of each of the two matches, C<$hi>
and C<$lo>, is collocated among the matches to
distinguish the case of a "success" and the
case of "failure".  In the case of the former,
C<< $hi >= $lo >>; in the case of the latter,
C<< $hi < $lo >> (in fact, they differ by 1).

=cut

sub _bsrchpx
{
	my ($ord, $map, $min) = @_;
	my ($prv, $nxt);
	my ($mid, $res, $elp, $lo, $hi) = _blsrch(1, sub { $_[0] >= 0 }, @_);

	# Normally, our search functions operate on
	# asymmetric half-open intervals -- such as
	# [$lo, $hi) in this case of left search.
	#
	# Not today! :)  We're making it [$lo, $hi]
	# since we need to search backwards too...
	--$hi;

	if (defined $res && $res == 0) {
		# Search on a (possibly) long range on either ends
		# of the interior spans [$lo, $mid) and ($mid, $hi].
		# (We tell b?srch to ignore $mid, because we already
		# know what it is. ;)
#		print STDERR "You are long, [$lo, $mid) ($mid, $hi]!\n";
#		print STDERR "   LFT RNG $_\n" for map { sprintf "[%02d] %s", $_, ${$map->($_)} } $lo..$mid-1;
		($lo, undef, $nxt) = _blsrch(0, sub { $_[0] >= 0 }, $ord, $map, $lo, $mid);
#		print STDERR sprintf "     IDX %02d ELP %s\n", $lo, defined $nxt ? qq[\\"$$nxt"] : "???";
		# blsrch0 won't actually check $mid, so if $mid is
		# already on the far right end (which isn't at all
		# unlikely, and almost guaranteed if there are only
		# 2-3 matches (it is in fact guaranteed at 2), we'd
		# have to use prior knowledge of what lives at $mid...
		$nxt = $elp if $mid == $lo;
#		print STDERR sprintf "  ( fixup       %s )\n", qq[\\"$$elp"] if $mid == $lo;

#		print STDERR "   RGT RNG $_\n" for reverse
#		                                   map { sprintf "[%02d] %s", $_, ${$map->($_)} } $mid+1..$hi;
		($hi, undef, $prv) = _brsrch(0, sub { $_[0] <= 0 }, $ord, $map, $hi, $mid);
#		print STDERR sprintf "     IDX %02d ELP %s\n", $hi, defined $prv ? qq[\\"$$prv"] : "???";
		# The same fixup is necessary here because we don't
		# know if the extra matches intersect with the left
		# interior but not the right interior (what the
		# previous fixup addresses), or vise versa (what
		# this fixup will address).
		$prv = $elp if $mid == $hi;
#		print STDERR sprintf "  ( fixup       %s )\n", qq[\\"$$elp"] if $mid == $hi;
	} else {
		# No match found; now the left and right match cross
		# over one other to become successor and predecessor
		$nxt = $elp;
		unless ($hi < $min) {
			$prv = $map ? $map->($hi) : \$hi;
		}
	}
	($hi, defined $prv ? $$prv : undef,
	 $lo, defined $nxt ? $$nxt : undef);
}

sub bsrchpx (&$;$$) { _bsrchpx(_parse(LTR, @_)); }

push @EXPORT_OK, qw(bsrchpx);

=item B<cmp_zone A, B>

Implements canonical DNS name order.
Any IDN is assumed to have been encoded.

In addition, if B<A> is a subdomain of B<B>
or vice versa, return 1/-1.  This is similar
to the C<acomp> function in Plan9, except
reversed because domain names are written
right-to-left.
=cut

sub cmp_zone
{
	my $cmp;
	# Pointer indeX String Remaining
	my ($p0, $x0, $s0, $r0); $p0 = length($_[0]) - 1;
	my ($p1, $x1, $s1, $r1); $p1 = length($_[1]) - 1;
	# Skip the root zone dot
	$p0-- if $p0 >= 0 && substr($_[0], $p0, 1) eq '.';
	$p1-- if $p1 >= 0 && substr($_[1], $p1, 1) eq '.';
	do {
		$r0 = ($x0 = rindex($_[0], ".", $p0)) > 0;
		$r1 = ($x1 = rindex($_[1], ".", $p1)) > 0;
		# Compare labels
		$s0 = lc(substr($_[0], $x0 + 1, $p0 - $x0));
		$s1 = lc(substr($_[1], $x1 + 1, $p1 - $x1));
		if ($cmp = ($s0 cmp $s1)) {
			return 2*$cmp;
		}
		$x0-- if $r0;
		$x1-- if $r1;
		($p0, $p1) = ($x0, $x1);
	} while ($r0 && $r1);
	if ($cmp = ($r0 <=> $r1)) {
		return $cmp;
	}
	return 0;
}

push @EXPORT_OK, qw(cmp_zone);

=back

=head1 SEE ALSO

L<RFC 4034 "Resource Records for
the DNS Security Extensions,
Section 6.1 "Canonical DNS Name Order"
|https://datatracker.ietf.org/doc/html/rfc4034#section-6.1>

L<Plan 9, /sys/src/cmd/look.c, int acomp(Rune *s, Rune *t)
|https://github.com/plan9foundation/plan9/blob/main/sys/src/cmd/look.c>

=cut

1;
