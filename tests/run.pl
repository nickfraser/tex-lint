#!/usr/bin/env perl
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(dirname(abs_path(__FILE__))) . '/lib';
use lib dirname(abs_path(__FILE__)) . '/lib';
use TexLintTest;
binmode STDOUT, ':encoding(UTF-8)';
$TexLintTest::root = dirname(dirname(abs_path(__FILE__)));
for my $test (qw(config wrapping protection adapter cli integration)) {
    my $result = do "$TexLintTest::root/tests/$test.t";
    die "Cannot run $test.t: " . ($@ || $!) unless defined $result;
}
exit finish();
