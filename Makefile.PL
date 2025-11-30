# Generated with Module::Starter
use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
	NAME             => 'Sort::Search',
	AUTHOR           => q{Ethan Meng <ethan@rapidcow.org>},
	VERSION_FROM     => 'lib/Sort/Search.pm',
	ABSTRACT_FROM    => 'lib/Sort/Search.pm',
	# perl_5 is the same license as (Artistic 1 & GPL 1 or later)
	# https://metacpan.org/pod/CPAN::Meta::Spec#license
	LICENSE          => 'perl_5',
	MIN_PERL_VERSION => '5.006',
	CONFIGURE_REQUIRES => {
		'ExtUtils::MakeMaker' => '0',
	},
	TEST_REQUIRES => {
		'Test::More' => '0',
	},
	PREREQ_PM => {
		'Carp'     => '0',
		'Exporter' => '0',
		'Scalar::Util' => '0',
		#'Want'    => '0',  # Optional, to save copying
		# Pragmatic modules
		'constant' => '0',
		'strict'   => '0',
		'warnings' => '0',
	},
	dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
	clean => { FILES => 'Sort-Search-*' },
	META_MERGE => {
		# Hyperlinks in the MetaCPAN side bar (Spec 2.x)
		# https://metacpan.org/pod/CPAN::Meta::Spec#resources
		resources => {
			homepage => 'https://www.rapidcow.org/lib/perl5/Sort-Search/',
			bugtracker => {
				web    => 'https://rt.cpan.org/Public/Dist/Display.html?Name=Sort-Search',
				mailto => 'bug-sort-search@rt.cpan.org',
			},
			repository => {
				type => 'git',
				url  => 'https://github.com/rapidcow/p5-Sort-Search.git',
				web  => 'https://github.com/rapidcow/p5-Sort-Search',
			},
		}
	},
);

# Compatibility with old versions of ExtUtils::MakeMaker
unless (eval { ExtUtils::MakeMaker->VERSION('6.64'); 1 }) {
    my $test_requires = delete $WriteMakefileArgs{TEST_REQUIRES} || {};
    @{$WriteMakefileArgs{PREREQ_PM}}{keys %$test_requires} = values %$test_requires;
}

unless (eval { ExtUtils::MakeMaker->VERSION('6.55_03'); 1 }) {
    my $build_requires = delete $WriteMakefileArgs{BUILD_REQUIRES} || {};
    @{$WriteMakefileArgs{PREREQ_PM}}{keys %$build_requires} = values %$build_requires;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
    unless eval { ExtUtils::MakeMaker->VERSION('6.52'); 1 };
delete $WriteMakefileArgs{MIN_PERL_VERSION}
    unless eval { ExtUtils::MakeMaker->VERSION('6.48'); 1 };
delete @WriteMakefileArgs{qw(META_ADD META_MERGE)}
    unless eval { ExtUtils::MakeMaker->VERSION('6.46'); 1 };
delete $WriteMakefileArgs{LICENSE}
    unless eval { ExtUtils::MakeMaker->VERSION('6.31'); 1 };

WriteMakefile(%WriteMakefileArgs);
