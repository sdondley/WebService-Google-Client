#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok('WebService::Google') || print "Bail out!\n";
}

diag("Testing WebService::Google $WebService::Google::VERSION, Perl $], $^X");
