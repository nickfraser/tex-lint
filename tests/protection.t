use strict;
use warnings;
use TexLintTest;
use TexLint::Protection qw(protect_commands);
use TexLint::SentenceWrap qw(restore wrap_sentence);
use TexLint::Config;
my @cases = (
    'A \\textbf{nested {text}, with punctuation.} sentence.',
    'A \\href[option={x]y}]{https://example.test/a,b}{link text} sentence.',
    'A \\foo{escaped \\{ braces \\} inside} sentence.',
    'A \\% escaped percent and \\ space.',
    "A \\foo\n {multiline argument} sentence.",
);
for my $text (@cases) {
    my %stored;
    my $n = 0;
    my $hidden = protect_commands($text, sub { my $id = 'TOKEN' . ++$n; $stored{$id} = $_[0]; return $id; });
    ok($n > 0, 'macro scanner finds opaque spans');
    is(restore($hidden, \%stored), $text, 'macro protection is lossless');
}
my @stored;
my $structural = '\\begin{itemize} \\item Text. \\par More. \\end{itemize}';
is(protect_commands($structural, sub { push @stored, $_[0]; return 'TOKEN'; }), $structural, 'structural commands remain visible');
is(scalar @stored, 0, 'structural commands not stored');
my $malformed = 'A \\foo{unclosed argument.';
is(protect_commands($malformed, sub { 'TOKEN' }), $malformed, 'unclosed group not guessed');
my %stored;
my $hidden = protect_commands('One \\url{long url, with spaces} and more words.', sub { $stored{TOKEN} = $_[0]; return 'TOKEN'; });
my $wrapped = wrap_sentence($hidden, TexLint::Config->new(soft_width => 12, hard_width => 18), protected => \%stored);
like(restore($wrapped, \%stored), qr/\\url\{long url, with spaces\}/, 'macro internal spaces and punctuation never wrap');
1;
