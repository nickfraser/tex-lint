package TexLint::Config;
use strict;
use warnings;
use utf8;

sub new {
    my ($class, %values) = @_;
    my %config = (
        soft_width => 80, hard_width => 100,
        preferred_markers => ',;:-–—', continuation_indent => 0,
    );
    for my $key (keys %values) {
        die "Unknown semantic_wrap setting: $key\n" unless exists $config{$key};
        $config{$key} = $values{$key};
    }
    for my $key (qw(soft_width hard_width continuation_indent)) {
        my $value = $config{$key};
        my $minimum = $key eq 'continuation_indent' ? 0 : 1;
        die "semantic_wrap.$key must be " . ($minimum ? 'a positive' : 'a nonnegative') . " integer\n"
            if !defined($value) || ref($value) || $value !~ /\A[0-9]+\z/ || $value < $minimum;
    }
    die "semantic_wrap.soft_width must not exceed hard_width\n"
        if $config{soft_width} > $config{hard_width};
    my $markers = $config{preferred_markers};
    die "semantic_wrap.preferred_markers must be a string of visible characters\n"
        if !defined($markers) || ref($markers) || $markers =~ /\p{C}|\p{White_Space}/;
    return bless \%config, $class;
}

1;
