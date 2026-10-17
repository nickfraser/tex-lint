use strict;
use warnings;
use utf8;
use TexLintTest;
use TexLint::Config;
my $defaults = TexLint::Config->new;
is($defaults->{soft_width}, 80, 'default soft width matches companion');
is($defaults->{hard_width}, 100, 'default hard width matches companion');
is($defaults->{preferred_markers}, ',;:-–—', 'default markers match companion');
is(TexLint::Config->new(preferred_markers => '')->{preferred_markers}, '', 'empty markers disable preference');
is(TexLint::Config->new(soft_width => 30, hard_width => 30)->{soft_width}, 30, 'equal widths accepted');
for my $key (qw(soft_width hard_width)) {
    for my $value (undef, 0, -1, 1.5, 'many', [], {}) {
        throws(sub { TexLint::Config->new($key => $value) }, qr/\Q$key\E/, "$key rejects invalid value");
    }
}
throws(sub { TexLint::Config->new(soft_width => 101) }, qr/must not exceed/, 'soft cannot exceed hard');
for my $value (undef, [], "a b", "\n", "\x00", "\x{00a0}", "\x{200b}") {
    throws(sub { TexLint::Config->new(preferred_markers => $value) }, qr/preferred_markers/, 'invalid marker string rejected');
}
throws(sub { TexLint::Config->new(continuation_indent => -1) }, qr/nonnegative/, 'negative continuation rejected');
throws(sub { TexLint::Config->new(soft_wdith => 72) }, qr/Unknown/, 'misspelled setting rejected');
1;
