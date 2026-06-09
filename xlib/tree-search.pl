#!/usr/bin/env perl

=head1 NAME

xlib/tree-search.pl - prefix search on paths

=head1 SYNOPSIS

   # Command-line usage:
   xlib/tree-search.pl find [-x EXCL]* [ROOT] > TREE
   xlib/tree-search.pl leap [-K KIND] NODE < TREE
   xlib/tree-search.pl delv [-K KIND] NODE < TREE

   xlib/tree-search.pl find |
      xlib/tree-search.pl delv xt |
         xlib/tree-search.pl leap xt/old

   # Library usage
   use File::Find;  use File::Spec;
   require "./xlib/tree-search.pl";
   my @list;  find {
       no_chdir => 1,
       wanted => sub {
           push @list, File::Spec->abs2rel($_, ".");
       }
   } => ".";
   my $acomp = make_acomp( \&uri_strtok );
   @list = sort { $acomp->($a, $b) } @list;
   @list = BST_delv ($acomp, \@list, "xt");
   @list = BST_leap ($acomp, \@list, "xt/old");

=head1 DESCRIPTION

So... this is the real reason why I introduced plan9 C<acomp>.
Unlike B<xlib/nsec-search.pl>, which was just an excuse for
me to practice implementing the five zones correctly, here
we actually utilize the middle zones where one string is a
prefix of another.  This is perhaps best illustrated with an
example. :)

Suppose we have a directory listing on the C<xt> directory,
and we compare with respect to the C<xt/old> key:

   $_                 acomp($_, $K)
   -------           ---------------
   xt                      -1
   xt/00-load.t            -2
   xt/changes.t            -2     prev   (-2 and -1)
   xt/essay.t              -2
   xt/manifest.t           -2
   xt/nsec-search.t        -2
   xt/old                   0  =- root   (0 == xt/old)
   xt/old/10-bisectl.t      1  \
   xt/old/10-bisectr.t      1  |
   xt/old/50-bisect120.t    1  }- child  (1 =~ xt/old/*)
   xt/old/50-scope.t        1  |
   xt/old/README            1  |
   xt/old/doctest.t         1  /
   xt/overflow.t            2
   xt/pod-coverage.t        2
   xt/pod.t                 2     succ   (+2)
   xt/sib.t                 2
   xt/tree-search.t         2

Normally, range searches like B<blsrch2> would find zeros:
in this case, the exact match against the key C<xt/old>,
the root directory itself.  However, we can use it to find
ones -- the children prefixed with the key -- by shifting
the 1 onto 0, while keeping everything monotonic (negatives
before zeros, zeros before positives.)

I find the mapping C<acomp - 1> to be the simplest for this.

The core of this proof of concept was written by Claude,
based on my L<mtree(5)>-like directory integrity utility
(you can audit the extent of that from git blame), which
implemented this premature idea of leaping over subtrees,
but written with primitives like C<bisectl> when my binary
search library lacked support for searching on sub-arrays.

=head2 PLAN9 ACOMP

The B<acomp> function, as found in C</sys/src/cmd/look.c>
from Plan 9, is an extended comparison function that returns
one of the five following states:  (We assume C<a> and C<b>
are the operands, in that order.)

=over 4

=item B<-2>

C<a> precedes C<b>; but excluding the case of B<-1>.

=item B<-1>

C<a> is a prefix of C<b>.

=item B<0>

C<a> equals C<b>.

=item B<1>

C<b> is a prefix of C<a>.

=item B<2>

C<a> follows C<b>; but excluding the case of B<1>.

=back

The B<acomp> function has a few interesting properties:

=over 4

=item *

It is anticommutative, like the average comparison function:
C<acomp(a, b) + acomp(b, a) == 0>.

=item *

It I<looks> like a regular comparison function to sorting
algorithms that are only aware of negative, zero, and
positive.  This lets us use it directly in L<sort|perlfunc/sort>,
as seen in the L</SYNOPSIS>.

=item *

When C<b> is fixed, the negatives precede 0s, the 0s precede
the 1s, and the 1s precede the 2s.  (There is, however, no
monotonicity among the negatives: -2s are easily interwoven
with the -1s, as already evident from the example above.)

=back

This last property is the most interesting because it means that
we can extend our notion of equality to consider the root node
I<and> any child node (map 0 and 1 both to 0), or just the child
nodes alone (map 1 to 0, 0 to negatives).

=cut

use strict;
use warnings;
use List::Util qw(max);
use Sort::Search qw(blsrch1 blsrch2);

=head1 SUBROUTINES

=over

=item B<BST_leap> I<ACOMP>, I<LIST>, I<NODE>

Find the immediate children of B<NODE> from B<LIST>,
with respect to the acomp function B<ACOMP>.

=cut

sub BST_leap {
	my ($acomp, $list, $node) = @_;
	# Step 1: bound the whole subtree
	my ($lo, $hi) = blsrch2 { $acomp->($_, $node) - 1 } $list;

	# Step 2: iterate direct children, skipping subtrees
	my @children;
	while ($lo < $hi) {
		my $child = $list->[$lo];
		push @children, $child if !$acomp->( [ $child, $node ], $child );
		# blsrch1 finds first element where acomp > 1 relative to $child,
		# i.e. first successor -- skips $child's entire subtree
		$lo = blsrch1 { $acomp->( [ $_, $node ], $child ) - 1 } $list, $lo + 1, $hi;
	}
	@children;
}

=item B<BST_delv> I<ACOMP>, I<LIST>, I<NODE>

Find all descendants of B<NODE> from B<LIST>, with
respect to the acomp function B<ACOMP>.

=cut

sub BST_delv {
	my ($acomp, $list, $node) = @_;
	# Just bound the whole subtree
	my ($lo, $hi) = blsrch2 { $acomp->($_, $node) - 1 } $list;
	@{$list}[$lo .. $hi-1];
}

=item B<uri_strtok> I<PATH>

=item B<dns_strtok> I<PATH>

Split string path into tokens for hierarchical, lexicographical comparison.
The former splits on a Unix path/URI path, while the latter splits on an
Internet domain name.  The absolute leading slash/trailing dot is discarded.
In addition, single dots in a Unix path split are a no-op and are discarded.

=cut

sub uri_strtok {
	my ($path) = @_;
	$path =~ s{^/}{};
	grep { $_ ne '.' } split m{/}, $path, -1;
}

sub dns_strtok {
	my ($path) = @_;
	$path =~ s{\.$}{};
	reverse split m{\.}, $path, -1;
}

=item B<make_acomp> I<STRTOK>[, I<STRCMP>]

Create an I<acomp> function from a tokenizer and (optionally) a
per-token comparison function.  String comparison is used if a
comparison function is not explicitly given.

=cut

sub make_acomp {
	my ($strtok, $strcmp) = @_;
	sub {
		my ($atok, $btok) = @_;
		my (@atok, @btok);
		my (@aref, @bref);

		if (UNIVERSAL::isa($atok, "ARRAY")) {
			@atok = $strtok->($atok->[0]);
			@aref = $strtok->($atok->[1]);
			@atok = splice @atok, 0, @aref + 1;
		} else {
			@atok = $strtok->($atok);
		}

		if (UNIVERSAL::isa($btok, "ARRAY")) {
			@btok = $strtok->($btok->[0]);
			@bref = $strtok->($btok->[1]);
			@btok = splice @btok, 0, @bref + 1;
		} else {
			@btok = $strtok->($btok);
		}

		acomp(\@atok, \@btok, $strcmp);
	};
}

sub acomp {
	my ($atok, $btok, $strcmp) = @_;

	my $res = 0;
	foreach (0 .. max($#$atok, $#$btok)) {
		$res = ($_ < @$atok) - ($_ < @$btok);
		return $res if $res;

		$res = $strcmp
			? $strcmp->($atok->[$_], $btok->[$_])
			: $atok->[$_] cmp $btok->[$_];
		return $res < 0 ? -2 : 2 if $res;
	}
	return $res;
}

=back

=cut

return 1 if caller;

use strict;
use warnings;
use Getopt::Long;
use File::Spec;
no locale;

sub usage {
<<USE;
usage: $0 find [-x EXCL]* [ROOT] > TREE
       $0 leap [-K KIND] NODE < TREE
       $0 delv [-K KIND] NODE < TREE
USE
}

my $cmd = $ARGV[0];

if (defined $cmd && grep { $cmd eq $_ } qw(find leap delv)) {
	shift;
} else {
	$cmd = 'find';
}

=head1 SUBCOMMANDS

All the sub-commands assume that we are dealing with paths.
Newline-delimited paths, more specifically.

=over

=item B<find> [-x I<EXCL>] [I<ROOT>]

Basically B<find>(1) but sorted per-component.  The
B<-x> flag is a primitive exclude rule that can be used
to, say, skip over the ".git" directory: C<-x .git>.
It basically acts like C<-path EXCL -prune -o ...> and
can be specified multiple times.  The root is optional
and defaults to the current directory.  There is at most
one root, though only because I forgot forests existed.

=cut

if ($cmd eq 'find') {
	my @excl;
	GetOptions('x=s@' => \@excl) or die usage();

	my $root = shift;
	$root ||= ".";

	# File::Find sorts directories separately from files...
	# We have to roll our own traversal, sadly. :(
	my @stack = ($root);
	while (@stack) {
		my $path = pop @stack;
		my $rel = File::Spec->abs2rel($path, $root);
		# Mimic our "wanted" function from before
		# that prunes files and directories alike.
		next if grep { $rel eq $_ } @excl;
		print "$rel$/";
		if (-d $path && !-l $path) {
			my ($dh, @kids);
			unless (opendir $dh, $path) {
				warn "opendir $path: $!\n";
				next;
			}
			@kids = sort { $b cmp $a } File::Spec->no_upwards(readdir $dh);
			closedir $dh;
			push @stack, map { "$path/$_" } @kids;
		}
	}
}

=item B<delv> [-K I<KIND>] I<NODE>

=item B<leap> [-K I<KIND>] I<NODE>

Calls B<BST_delv> and B<BST_leap>.  Input is read from STDIN.

I<KIND> is one of C<uri> and C<dns> and defaults to C<uri>.

=cut

else {
	my $kind = 'uri';
	GetOptions('K=s' => \$kind) and defined (my $node = shift) or die usage();

	chomp (my @list = <STDIN>);
	my $acomp = make_acomp(do { no strict 'refs'; \&{"${kind}_strtok"} });
	my @children = do { no strict 'refs'; \&{"BST_${cmd}"} }->($acomp, \@list, $node);
	print "$_$/" foreach @children;
}

=back

=cut
