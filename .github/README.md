<!--
  This document is written in GitHub Flavored Markdown
  <https://github.github.com/gfm/>, for display in a
  graphical web browser capable of rendering HTML.

  Here we assume the audience are accessing this file
  through a web frontend, and thus likely do not have
  a copy of the distribution with them.
-->

# Sort::Search - binary search on sorted ranges

## Description

This is a pure-Perl module for searching for on sorted arrays.
It deals with:

    * Bisection point with respect to a predicate:
        bisectl   bixectl   |   bixectr   bisectr

    * Upper/lower bisection point with respect to an ordering:
        blsrch0   blsrch1   |   brsrch1   blsrch0
        blsrchx   blsrch2   |   brsrch2   brsrchx

See Sort/Search/Cookbook.pod for examples, and Sort/Search.pod
for the nitty gritty details.  (Read src/*.txt for a paper-ish
slow-paced introduction to it all. ;)


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
*   [My project homepage](https://pub.rapidcow.org/CPAN/Sort-Search/)
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


## Acknowledgement

Many thanks to the following libraries/resources:

*   Go "[sort](https://go.dev/src/sort/search.go)" package
*   Python "[bisect](https://github.com/python/cpython/blob/main/Lib/bisect.py)" module
*   "[Algorithms/Sorting/Binary Search][]" module from GNU libstdc++
    (`lower_bound`, `upper_bound`, `equal_range` namely)
*   [List::MoreUtils::PP][] for a large portion of the syntax! :^)
*   Ruby "[bsearch][]" method (the "x" variants inspired by Find-any mode)
*   RTL binary search (bisectr et al.) from [USACO Guide][] "last_true"

[Algorithms/Sorting/Binary Search]: https://gcc.gnu.org/onlinedocs/libstdc++/latest-doxygen/a01630.html
[List::MoreUtils::PP]: https://metacpan.org/dist/List-MoreUtils/source/lib/List/MoreUtils/PP.pm
[bsearch]: https://docs.ruby-lang.org/en/master/language/bsearch_rdoc.html
[USACO Guide]: https://usaco.guide/silver/binary-search#finding-the-maximum-x-such-that-fx--true
