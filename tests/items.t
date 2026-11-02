use strict;
use warnings;
use utf8;
use TexLintTest;
use TexLint::SentenceWrap qw(display_width);

if (!$ENV{TEX_LINT_LATEXINDENT}) {
    skip('use --integration for native inline-item layout tests');
} else {
    my $dir = scratch();
    my $settings = "$dir/.latexindent.yaml";
    my $base = "semantic_wrap:\n  soft_width: 20\n  hard_width: 26\ndefaultIndent: '    '\nnoAdditionalIndentGlobal:\n  items: 1\nmodifyLineBreaks:\n  items:\n    ItemFinishesWithLineBreak: -1\n";
    my $no_hanging = "noAdditionalIndent:\n  item: 1\n";
    my $flush = $no_hanging . "  itemize: 1\n  enumerate: 1\n  description: 1\n";
    write_text($settings, $base . $flush);
    my @args = ('--latexindent', $ENV{TEX_LINT_LATEXINDENT}, '--config', $settings, '-');
    my @cases = (
        ["\\begin{itemize}\n\\item First. Another.\n\\end{itemize}\n",
            "\\begin{itemize}\n\\item First.\nAnother.\n\\end{itemize}\n", 'first sentence stays attached; later sentences split'],
        ["\\begin{itemize}\n\\item\nOne two three four five six seven.\n\\end{itemize}\n",
            "\\begin{itemize}\n\\item One two three\nfour five six seven.\n\\end{itemize}\n", 'existing item newline removed; marker counts toward width'],
        ["\\begin{description}\n\\item[Label] One two three four five six.\n\\end{description}\n",
            "\\begin{description}\n\\item[Label] One two\nthree four five six.\n\\end{description}\n", 'label counts toward first-line width only'],
    );
    for my $case (@cases) {
        my ($input, $expected, $name) = @$case;
        my ($status, $out, $err) = run_cli($dir, $input, @args);
        is($status, 0, "$name: formatter succeeds");
        is($out, $expected, $name);
        my ($again_status, $again) = run_cli($dir, $out, @args);
        is($again_status, 0, "$name: second pass succeeds");
        is($again, $out, "$name: idempotent");
    }
    my $nested = "\\begin{itemize}\n\\item First outer sentence.\n\\begin{enumerate}\n\\item Inner sentence. More words in another sentence.\n\\end{enumerate}\n\\item Last sentence.\n\\end{itemize}\n";
    my ($status, $out, $err) = run_cli($dir, $nested, @args);
    is($status, 0, 'nested inline lists format');
    ok($out !~ /^[ \t]+\S/m, 'nested lists are flush-left');
    ok($out !~ /\\item\h*\R/, 'nested item commands stay with their first word');
    ok(!(grep { display_width($_) > 26 } split /\n/, $out), 'nested item prose obeys the hard width');
    my (undef, $again) = run_cli($dir, $out, @args);
    is($again, $out, 'nested inline lists are idempotent');
    my $comments = "\\begin{itemize}\n\\item % Keep this comment.\nFirst sentence. Another sentence.\n\\item[Label] % Keep labelled comment.\nNext sentence.\n\\end{itemize}\n";
    ($status, $out, $err) = run_cli($dir, $comments, @args);
    is($status, 0, 'comments after items format');
    like($out, qr/\\item % Keep this comment\.\nFirst sentence\./, 'item comment remains a newline barrier');
    like($out, qr/\\item\[Label\] % Keep labelled comment\.\nNext sentence\./, 'labelled item comment remains a newline barrier');
    my $protected = "\\begin{itemize}\n\\item A \\textbf{long protected phrase, with punctuation} ends here.\n\\item[{Label with ] inside}] Another sentence.\n\\end{itemize}\n";
    ($status, $out, $err) = run_cli($dir, $protected, @args);
    is($status, 0, 'protected item content formats');
    like($out, qr/\\textbf\{long protected phrase, with punctuation\}/, 'protected macro remains atomic');
    like($out, qr/\\item\[\{Label with \] inside\}\] Another/, 'balanced label with inner closing bracket is preserved');
    (undef, $again) = run_cli($dir, $out, @args);
    is($again, $out, 'protected item content is idempotent');
    write_text($settings, $base . $no_hanging); # Retain normal environment indentation.
    ($status, $out, $err) = run_cli($dir, "\\begin{itemize}\n\\item One two three four five six.\n\\end{itemize}\n", @args);
    is($status, 0, 'inline style also supports indented list environments');
    like($out, qr/^    \\item One two\n    three four five\n    six\.$/m, 'environment indentation retained without hanging indentation');
    write_text($settings, "defaultIndent: '    '\nmodifyLineBreaks:\n  items:\n    ItemFinishesWithLineBreak: 0\n");
    ($status, $out, $err) = run_cli($dir, "\\begin{itemize}\n\\item First sentence.\n\\end{itemize}\n", @args);
    like($out, qr/\\item\h*\R/, 'native zero setting retains separate-item behavior');
    write_text($settings, $base . $flush);
    ($status, $out, $err) = run_cli($dir, "\\begin{itemize}\n\\itemFirst Not an item command.\n\\item First sentence.\n\\end{itemize}\n", @args);
    like($out, qr/\\itemFirst/, 'item-prefixed macro name is not rewritten');
}
1;
