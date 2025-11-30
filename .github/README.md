<!--
  This document is written in GitHub Flavored Markdown
  <https://github.github.com/gfm/>, for display in a
  graphical web browser capable of rendering HTML.

  Here we assume the audience are accessing this file
  through a web frontend, and thus likely do not have
  a copy of the distribution with them.
-->

# Sort::Search - binary search on sorted ranges

Copyright (c) 2025 Ethan Meng &lt;ethan at rapidcow.org&gt;.


## Description

This is a pure-Perl module for searching for on sorted arrays.
It deals with:

    * Bisection point with respect to a predicate:
        bisectl   bixectl   |   bixectr   bisectr

    * Trisection point with respect to an ordering:
        blsrch0   blsrch1   |   brsrch1   blsrch0
        blsrchx   blsrch2   |   brsrch2   brsrchx


## Install

This module has not been fully developed or released yet,
so your best bet is to clone this Git repository with your
favorite Git client.  The clone URIs are:

    https://github.com/rapidcow/p5-Sort-Search.git
    git@github.com:rapidcow/p5-Sort-Search.git

for cloning over smart HTTP and SSH.  The former is an anonymous
read should not require authentication, while the latter requires
you to register your SSH key with your GitHub account.  (You may
find the same URIs by clicking the green "Code" dropdown button.)

If you have the **git**(1) command, run (without the `\`s):

    git clone -o upstream \
       https://github.com/rapidcow/p5-Sort-Search.git \
       Sort-Search

This clones the repository to a directory named "Sort-Search".

Once you have cloned this repository, change directory into
the work tree, then run

    perl Makefile.PL
    make
    make test
    make install

Or, using [cpanminus](https://metacpan.org/pod/App::cpanminus):

    cpanm .

After installing, you can find documentation for this module with the
perldoc command.  By some chance, you may also be able to use **man**(1):

    perldoc Sort::Search
    man 3 Sort::Search

You can also look for information at:

*   [RT, CPAN's request tracker](https://rt.cpan.org/NoAuth/Bugs.html?Dist=Sort-Search) (report bugs here)
*   [CPAN Ratings](https://cpanratings.perl.org/d/Sort-Search)
*   [Search CPAN](https://metacpan.org/release/Sort-Search)
*   [My project homepage](https://www.rapidcow.org/lib/perl5/Sort-Search/)
*   [Git repository](https://github.com/rapidcow/p5-Sort-Search) (web view)

Only the last two links work at the moment.


## License

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.
See [LICENSE][] for a copy of Perl's licenses.

<!--
  NOTE: This is a GitHub-specific relative link.  If you
  are mirroring on a different Gitweb, adjust accordingly.
-->

[LICENSE]: https://github.com/rapidcow/p5-Sort-Search/blob/master/LICENSE
