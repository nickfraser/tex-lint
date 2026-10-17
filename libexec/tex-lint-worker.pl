#!/usr/bin/env perl
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(dirname(abs_path(__FILE__))) . '/lib';
use Getopt::Long qw(GetOptions);
use Encode qw(decode FB_CROAK);
use TexLint::LatexIndentAdapter;

my (%options, %overrides);
GetOptions(
    'backend=s' => \$options{backend}, 'input=s' => \$options{input},
    'output=s' => \$options{output}, 'scratch=s' => \$options{scratch},
    'settings=s' => \$options{settings},
    'semantic-wrap-soft-width=s' => \$overrides{soft_width},
    'semantic-wrap-hard-width=s' => \$overrides{hard_width},
    'semantic-wrap-preferred-markers=s' => \$overrides{preferred_markers},
    'semantic-wrap-continuation-indent=s' => \$overrides{continuation_indent},
) or die "Invalid internal worker arguments\n";
%overrides = map { $_ => $overrides{$_} } grep { defined $overrides{$_} } keys %overrides;
$overrides{preferred_markers} = decode('UTF-8', $overrides{preferred_markers}, FB_CROAK)
    if exists $overrides{preferred_markers};
$options{overrides} = \%overrides;
TexLint::LatexIndentAdapter->run(%options);
