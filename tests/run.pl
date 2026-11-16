#!/usr/bin/env perl
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(dirname(abs_path(__FILE__))) . '/lib';
use lib dirname(abs_path(__FILE__)) . '/lib';
use TexLintTest;
use Getopt::Long qw(GetOptions);
my ($integration, $compile);
GetOptions('integration' => \$integration, 'compile' => \$compile)
    or die "Usage: perl tests/run.pl [--integration | --compile]\n";
die "Unexpected test arguments: @ARGV\n" if @ARGV;
$compile ||= $ENV{TEX_LINT_COMPILE};
if ($integration || $compile) {
    $ENV{TEX_LINT_LATEXINDENT} = find_program($ENV{TEX_LINT_LATEXINDENT} // 'latexindent');
}
$ENV{TEX_LINT_COMPILE} = 1 if $compile;
binmode STDOUT, ':encoding(UTF-8)';
$TexLintTest::root = dirname(dirname(abs_path(__FILE__)));
for my $test (qw(config wrapping protection adapter cli doctor integration items compilation)) {
    my $result = do "$TexLintTest::root/tests/$test.t";
    die "Cannot run $test.t: " . ($@ || $!) unless defined $result;
}
exit finish();
