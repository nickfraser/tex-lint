use strict;
use warnings;
use utf8;
use TexLintTest;
use TexLint::Config;
use TexLint::SentenceWrap qw(wrap_sentence display_width restore);
my $config = TexLint::Config->new(soft_width => 20, hard_width => 26);
my @cases = (
    ['Short, sentence.', 'Short, sentence.', 'short sentence intact'],
    ['Exactly twenty chars', 'Exactly twenty chars', 'exact soft width intact'],
    ['One, two three, four five six seven.', "One, two three,\nfour five six seven.", 'rightmost punctuation before soft'],
    ['One two three four five, six seven eight.', "One two three four five,\nsix seven eight.", 'first punctuation between soft and hard'],
    ['One two three four five six seven.', "One two three four\nfive six seven.", 'whitespace fallback targets soft'],
    ['One,two,three,four,five,six.', 'One,two,three,four,five,six.', 'no break without whitespace'],
    [('x' x 40) . ' and more text.', ('x' x 40) . "\nand more text.", 'unbreakable word overflows'],
    ["One two\n three four five six seven.", "One two three four\nfive six seven.", 'existing prose wrapping rejoined'],
);
for my $case (@cases) {
    my ($input, $expected, $name) = @$case;
    my $result = wrap_sentence($input, $config);
    is($result, $expected, $name);
    is(wrap_sentence($result, $config), $result, "$name is idempotent");
}
is(wrap_sentence('One, two three, four five six seven.', TexLint::Config->new(soft_width => 20, hard_width => 26, preferred_markers => '')),
    "One, two three, four\nfive six seven.", 'empty markers use whitespace');
for my $marker (',', ';', ':', '|', '/', '§') {
    my $custom = TexLint::Config->new(soft_width => 20, hard_width => 26, preferred_markers => $marker);
    like(wrap_sentence("One$marker two three four five six.", $custom), qr/\AOne\Q$marker\E\n/, "custom marker $marker");
}
for my $dash ('-', '--', '---', '–', '—') {
    like(wrap_sentence("One $dash two three four five six seven.", $config), qr/\AOne \Q$dash\E\n/, "standalone $dash preferred");
}
my $hyphenated = 'A well-known-word- and more words to wrap.';
is(wrap_sentence($hyphenated, $config), wrap_sentence($hyphenated,
    TexLint::Config->new(soft_width => 20, hard_width => 26, preferred_markers => '')), 'hyphenated word not preferred');
is(wrap_sentence('One, two; three four five six seven.', TexLint::Config->new(soft_width => 20, hard_width => 26, preferred_markers => ',;')),
    wrap_sentence('One, two; three four five six seven.', TexLint::Config->new(soft_width => 20, hard_width => 26, preferred_markers => ';,')), 'marker order does not establish priority');
is(wrap_sentence('One two three four five six.', $config, indent => '    '),
    "    One two three\n    four five six.", 'indentation counts against widths');
is(wrap_sentence('One two three four five six.', TexLint::Config->new(soft_width => 20, hard_width => 26, continuation_indent => 4)),
    "One two three four\n    five six.", 'continuation indentation configurable');
is(display_width('中文'), 4, 'wide characters measured in columns');
is(display_width("e\x{301}"), 1, 'combining accent measured in columns');
is(display_width('🙂'), 2, 'emoji measured in columns');
is(display_width("👩‍💻"), 2, 'ZWJ emoji measured as one cluster');
is(display_width("a\tb"), 9, 'tabs use display tab stops');
is(wrap_sentence('中文 中文 中文 中文', TexLint::Config->new(soft_width => 9, hard_width => 12)), "中文 中文\n中文 中文", 'wide prose wraps by display columns');
like(wrap_sentence("one\x{a0}two\x{a0}three and four five", TexLint::Config->new(soft_width => 8, hard_width => 12)), qr/\Aone\x{a0}two\x{a0}three\n/, 'nonbreaking spaces never split');
my %protected = (TOKEN => '\\url{a long protected URL}');
my $wrapped = wrap_sentence('One TOKEN and more words.', TexLint::Config->new(soft_width => 12, hard_width => 18), protected => \%protected);
is(restore($wrapped, \%protected), "One\n\\url{a long protected URL}\nand more\nwords.", 'opaque spans measured at restored width');
is(restore('OUTER', {OUTER => 'INNER', INNER => 'restored'}), 'restored', 'nested protected text restored');
throws(sub { restore('A', {A => 'B', B => 'A'}) }, qr/Cyclic/, 'cyclic protection rejected');
# Deterministic sweeps check preservation and repeat-format stability across
# many widths, instead of just reproducing individual branches of the code.
for my $soft (8, 16, 32, 80) {
    for my $extra (0, 8, 20) {
        my $c = TexLint::Config->new(soft_width => $soft, hard_width => $soft + $extra);
        my $text = 'Alpha beta, gamma delta epsilon; zeta eta theta iota kappa lambda mu nu xi omicron.';
        my $out = wrap_sentence($text, $c);
        (my $joined = $out) =~ s/\n/ /g;
        is($joined, $text, "prose preserved at widths $soft/" . ($soft + $extra));
        is(wrap_sentence($out, $c), $out, "stable at widths $soft/" . ($soft + $extra));
        ok(!(grep { display_width($_) > $c->{hard_width} } split /\n/, $out), 'breakable lines fit hard width');
    }
}
1;
