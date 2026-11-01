#!/bin/sh
#
# t/lib/test-functions - TAP utils for POSIX sh
# (COPIED FROM SLC-3)
#
# USAGE:
#   make a plan, then run your tests!
#
# FOR:
#   Bourne shells (bash, ksh, ash... should be good.)
#   NOT for CShell, sorry :(
#
# NOTE:
#   Don't use set -e if you want to take advantage of $? :)
#   Namely, note() diag() ok() all thrive on $?.
#   They act as no-ops, so it is possible to write:
#
#      /path/to/danger blah blah >out
#
#      note "danger squeaked"
#      note <out
#
#      ok "danger was safe" || diag "danger died with $?"
#
# GLOBALS:
#   $a, $b          temp variables
#   $x, $y          even more variables
#   $c              test counter
#   $r              return value
#   $PLAN           # of planned tests
#

# Here is something for me.  Most functions here are inspired
# by Test::More, so it's only natural that I port die too :)
#
# Don't actually call this while testing... this is not xUnit,
# we want all the tests to actually run, not give up midway
# when anything non-critical fails.  Use `say no' for that.
#
die () {
	if [ $# -gt 0 ]; then
		printf '%s\n' "$*"
	else
		cat -
	fi >&2
	exit 1
}

tmp="$(mktemp -d)" || die "error: You're ancient; get a mktemp(1) please"
pwd="$(pwd)"
trap '
cd "$pwd";
rm -rf $tmp &&
trap - EXIT' EXIT INT TERM

#
# Make a plan!  This prints the number of tests you want to run.
# Usually a second argument is not needed, unless you need to
# skip this test case entirely (see below)...
#
# Example:
#     plan 10                             # run 10 tests
#     plan 0 "SKIP I feel sick today"     # skip all with reason
#
plan () {
	PLAN=$1
	shift
	if [ $# -gt 0 ]; then
		printf '1..%d # %s\n' "$PLAN" "$*"
	else
		printf '1..%d\n' "$PLAN"
	fi
}

#
# Skip all tests.  You can (and should) supply a reason.
#
skip_all () {
	if [ $# -gt 0 ]; then
		plan 0 "SKIP $*"
	else
		plan 0
	fi
	exit 0
}

#
# Print miscellaneous info to standard out.
# There is one-line use:
#
#     note "I am the mighty squid king"
#
# and multi-line use:
#
#     note <<'EOM'
#     I am the mighty squid king
#     Ha haha!
#     EOM
#
# Error code is preserved.
#
note () {
	r=$?
	if [ $# -gt 0 ]; then
		printf '%s\n' "$*" |
		sed 's/^/# /' | sed 's/ $//'
	else
		sed 's/^/# /' | sed 's/ $//'
	fi
	return $r
}

#
# Print miscellaneous info to standard error.
# You use it exactly the same way you use note().
# Error code is preserved here too.
#
# NOTE: Generally, TAP Harness expects the first
# line of diagnosis following "not ok ..." to be a
# short reason for test fail.  Detailed diagnosis
# should start on the line *after* that.
#
diag () {
	note "$@" >&2
	return $?
}

c=0

#
# A primitive form of assertion.  Generally this is
# not what you want to use.  Use ok() to test functions
# that set $? (e.g. test and [ ... ] constructs.)
#
say () {
	a="$1"
	shift
	c=$(( c+1 ))
	if [ "$a" = ok ]; then
		printf "ok %d" $c
	else
		printf "not ok %d" $c
	fi
	if [ $# -eq 0 ]; then
		echo
		return
	fi
	if printf '%s\n' "$*" | grep -iE 'SKIP|TODO' >/dev/null; then
		printf " # %s\n" "$*"
	else
		printf " - %s\n" "$*"
	fi
}

#
# Assert $? is 0, i.e. the previous function/program
# exited succesfully.  The only argument is the test name,
# which is optional but strongly recommended.
#
# Error code is preserved.
#
ok () {
	b=$?
	if [ $b -eq 0 ]; then
		say ok "$@"
	else
		say no "$@"
	fi
	return $b
}

#
# Assert two files are equal.  $1 and $2 are your file paths,
# and the remainder of your arguments is the test name, which
# is similarly optional.
#
is () {
	if [ $# -lt 2 ]; then
		die <<EOM
error: is() expects at least two arguments -- the files to compare
EOM
	fi
	x="$1"
	y="$2"
	shift
	shift
	if diff -q "$x" "$y" >/dev/null 2>&1; then
		say ok "$@"
		return 0
	fi
	say no "$@"
	if [ $# -gt 0 ]; then
		printf "Test '%s' failed!\n" "$*" | diag
	else
		diag "Test failed!"
	fi
	diag "Files '$x' and '$y' differ:"
	diff -u "$x" "$y" | diag
	return 1
}

#
# Skip a number of tests, with an optional but
# recommended reason.  $1 is the number and the
# rest is your reason.  The one-argument form is
# short for `skip 1 $1'.
#
skip () {
	if [ $# -lt 1 ]; then
		a=1
	else
		a=$1
		shift
	fi
	for b in $(seq 1 "$a"); do
		say ok SKIP "$@"
	done
}

#
# Disregard $? and peacefully exit.
#
conclude () {
	exit 0
}

return 0
