#!perl
# this is not a good name
use 5.006;
use strict;
use warnings;
use Test::More;

#List::Search qw(bisect1 bisect2 bisect0);
BEGIN {
	require Sort::Search;
	*bisect0 = sub (&$$) {
		my ($compar, $target, $array) = @_;
		my $caller = caller;
		scalar Sort::Search::blsrch0(sub {
			no strict 'refs';
			local ${"${caller}::a"} = $_;
			local ${"${caller}::b"} = $target;
			$compar->()
		}, $array)
	};
	*bisect1 = sub (&$$) {
		my ($compar, $target, $array) = @_;
		my $caller = caller;
		scalar Sort::Search::blsrch1(sub {
			no strict 'refs';
			local ${"${caller}::a"} = $_;
			local ${"${caller}::b"} = $target;
			$compar->()
		}, $array)
	};
	*bisect2 = sub (&$$) {
		my ($compar, $target, $array) = @_;
		my $caller = caller;
		Sort::Search::blsrch2(sub {
			no strict 'refs';
			local ${"${caller}::a"} = $_;
			local ${"${caller}::b"} = $target;
			$compar->()
		}, $array)
	};
}

plan tests => 56;

{
    my $dates = [20241217, 20250105, 20250105];
    is ((bisect0 { $a <=> $b } 20250101, $dates), 1,
        "bisect0 pod example, simple");
    is ((bisect1 { $a <=> $b } 20250201, $dates), 3,
        "bisect1 pod example, simple");
    my ($u, $v) = bisect2 { $a <=> $b } 20250105, $dates;
    is ($u, 1, "bisect2 pod example, simple[0]");
    is ($v, 3, "bisect2 pod example, simple[1]");
}

{
    my $strptime = sub {
        my ($totally_legit_date_format) = @_;
        # coerce to integer
        my $s = ~~$totally_legit_date_format;
        use integer;
        my $days = $s %   100; $s = ($s - $days) / 100;
        my $mons = $s %   100; $s = ($s - $mons) / 100;
        my $year = $s -  1900; return {
            st_year => $year,
            st_month => $mons,
            st_day => $days,
        };
    };
    my $cmptime = sub {
         $a->{st_year} <=> $b->{st_year}
                       ||
        $a->{st_month} <=> $b->{st_month}
                       ||
          $a->{st_day} <=> $b->{st_day}
    };
    # oh wait map is perfect for this!
    my $dates = [map { $strptime->($_) } 20241217, 20250105, 20250105];
    # shockingly, { $cmptime->() } (minus the comma and parens) works too...
    is (bisect0 (\&$cmptime, $strptime->(20250101), $dates),
        1, "bisect0 pod example, complex");
    is (bisect1 (\&$cmptime, $strptime->(20250201), $dates),
        3, "bisect1 pod example, complex");
    my ($u, $v) = bisect2 (\&$cmptime, $strptime->(20250105), $dates);
    is ($u, 1, "bisect2 pod example, complex[0]");
    is ($v, 3, "bisect2 pod example, complex[1]");
}

{
    # from the ginormous diagram in List/Search.pm:
    # 3 plus the first 12 decimal places of pi, sorted
    my $pie = [1, 1, 2, 3, 3, 4, 5, 5, 5, 6, 8, 9, 9];
    my $great_expectations = [
         0 => [ 0,  0],  1 => [ 0,  2],  2 => [ 2,  3],
         3 => [ 3,  5],  4 => [ 5,  6],  5 => [ 6,  9],
         6 => [ 9, 10],  7 => [10, 10],  8 => [10, 11],
         9 => [11, 13], 10 => [13, 13], 11 => [13, 13],
    ];
    # $cmp >= 0
    # $cmp >  0
    use integer;
    for (0..@$great_expectations/2 - 1) {
        my $valued = $great_expectations->[$_+$_];
        my $expectation = $great_expectations->[$_+$_+1];
        my ($lower, $upper) = @$expectation;
        is ((bisect0 { $a <=> $b } $valued, $pie),
            $lower, "bisect0 diagram[$valued]");
        is ((bisect1 { $a <=> $b } $valued, $pie),
            $upper, "bisect1 diagram[$valued]");
        my ($u, $v) = bisect2 { $a <=> $b } $valued, $pie;
        is ($u, $lower, "bisect2 diagram[$valued][0]");
        is ($v, $upper, "bisect2 diagram[$valued][1]");
    }
}
