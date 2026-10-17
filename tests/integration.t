use strict;
use warnings;
use utf8;
use TexLintTest;
use File::Path qw(make_path);
use TexLint::SentenceWrap qw(display_width);

my $backend = $ENV{TEX_LINT_LATEXINDENT};
if (!$backend) {
    skip('set TEX_LINT_LATEXINDENT to a working latexindent Perl script for real integration tests');
} else {
    my $dir = scratch();
    my $settings = "$dir/.latexindent.yaml";
    write_text($settings, "semantic_wrap:\n  soft_width: 20\n  hard_width: 26\n  preferred_markers: ',;:-–—'\ndefaultIndent: '    '\n");
    my @base = ('--latexindent', $backend);
    my $prose = "One, two three, four five six seven. Another sentence.\n";
    my $expected = "One, two three,\nfour five six seven.\nAnother sentence.\n";
    my ($status, $out, $err) = run_cli($dir, $prose, @base, '-');
    die "Real latexindent integration could not start:\n$err" if $status != 0;
    is($status, 0, 'real backend accepts stdin');
    is($out, $expected, 'real sentence pipeline uses soft-target core');
    write_text("$dir/document.tex", $prose);
    ($status, $out, $err) = run_cli($dir, '', @base, '--check', "$dir/document.tex");
    is($status, 1, 'check reports unformatted file');
    is(read_text("$dir/document.tex"), $prose, 'check does not edit');
    ($status, $out, $err) = run_cli($dir, '', @base, "$dir/document.tex");
    is($status, 0, 'file formatting succeeds');
    is(read_text("$dir/document.tex"), $expected, 'file formats in place');
    ($status, $out, $err) = run_cli($dir, '', @base, '--check', "$dir/document.tex");
    is($status, 0, 'formatted file passes check and is idempotent');
    ($status, $out, $err) = run_cli($dir, $prose, @base, '--semantic-wrap-soft-width', '80', '--semantic-wrap-hard-width', '100', '-');
    is($out, "One, two three, four five six seven.\nAnother sentence.\n", 'CLI widths override YAML settings');
    ($status, $out, $err) = run_cli($dir, 'One | two three four five six.', @base, '--semantic-wrap-preferred-markers', '|', '-');
    like($out, qr/\AOne \|\n/, 'CLI markers override YAML');
    ($status, $out, $err) = run_cli($dir, $prose, @base, '--semantic-wrap-preferred-markers', '', '-');
    like($out, qr/\AOne, two three, four\n/, 'empty CLI markers disable preference');
    make_path("$dir/nested", "$dir/.hidden");
    write_text("$dir/nested/child.tex", $prose);
    write_text("$dir/nested/leave.txt", $prose);
    write_text("$dir/.hidden/leave.tex", $prose);
    ($status, $out, $err) = run_cli($dir, '', @base, $dir, "$dir/nested/child.tex");
    is($status, 0, 'directories and duplicate file inputs accepted');
    is(read_text("$dir/nested/child.tex"), $expected, 'directory traversal formats tex files');
    is(read_text("$dir/nested/leave.txt"), $prose, 'directory traversal ignores other extensions');
    is(read_text("$dir/.hidden/leave.tex"), $prose, 'directory traversal skips hidden directories');
    ($status, $out, $err) = run_cli($dir, '', @base, '--output', "$dir/copy.tex", "$dir/.hidden/leave.tex");
    is($status, 0, 'separate output accepted');
    is(read_text("$dir/copy.tex"), $expected, 'separate output formatted');
    is(read_text("$dir/.hidden/leave.tex"), $prose, 'separate output preserves original');
    my $fixture = read_text("$TexLintTest::root/tests/fixtures/protected.tex");
    ($status, $out, $err) = run_cli($dir, $fixture, @base, '-');
    is($status, 0, 'protected document formats successfully');
    my $formatted = $out;
    for my $literal (
        '\\textbf{bold words, punctuation. And another phrase}',
        '\\href{https://example.test/a,b}{a link label}',
        '$a, b; c = 1.25$', '\\(x, y = 2.5\\)',
        "\\begin{verbatim}\n    A verbatim sentence. Another, sentence; stays: exactly as written.\n\\end{verbatim}",
        "Text before% keep this comment exactly\njoined text.",
        "An explicit line break\\\\\ncontinues here.",
        "\\begin{equation}\n  a, b = c + d \\quad \\text{Do not wrap. This is math.}\n\\end{equation}",
    ) {
        ok(index($formatted, $literal) >= 0, 'protected source retained literally');
    }
    ($status, $out, $err) = run_cli($dir, $formatted, @base, '-');
    is($status, 0, 'protected document formats twice');
    is($out, $formatted, 'protected document is idempotent');
    ($status, $out, $err) = run_cli($dir, "Unicode 中文 中文 and e\x{301} with more words, followed by a final sentence.\n", @base, '-');
    is($status, 0, 'Unicode source accepted by actual backend');
    like($out, qr/中文/, 'Unicode source survives upstream IO');
    ($status, $out, $err) = run_cli($dir, "\\begin{abstract}\nShort sentence. One two three four five six seven eight nine ten.\n\\end{abstract}\n", @base, '-');
    is($status, 0, 'nested prose formats successfully');
    like($out, qr/^    Short sentence\.$/m, 'short sentence receives exactly one surrounding indent');
    ok(!(grep { display_width($_) > 26 } split /\n/, $out), 'nested breakable prose includes indentation in hard width');
    my $nested = $out;
    ($status, $out, $err) = run_cli($dir, $nested, @base, '-');
    is($out, $nested, 'nested document indentation is idempotent');
    my $odd_config = "$dir/settings + comma, spaced.yaml";
    write_text($odd_config, "semantic_wrap:\n  soft_width: 20\n  hard_width: 26\n  preferred_markers: ''\n");
    ($status, $out, $err) = run_cli($dir, $prose, @base, '--config', $odd_config, '-');
    is($status, 0, 'explicit config paths preserve spaces and punctuation');
    like($out, qr/\AOne, two three, four\n/, 'explicit configuration is actually loaded');
    write_text($settings, "semantic_wrap:\n  soft_width: 50\n  hard_width: 20\n");
    ($status, $out, $err) = run_cli($dir, '', @base, "$dir/document.tex");
    is($status, 2, 'invalid merged config is an error');
    is(read_text("$dir/document.tex"), $expected, 'invalid config leaves source unchanged');
    write_text($settings, "semantic_wrap: [invalid: YAML\n");
    ($status, $out, $err) = run_cli($dir, '', @base, "$dir/document.tex");
    is($status, 2, 'invalid YAML fails rather than silently using defaults');
}
1;
