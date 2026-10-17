use strict;
use warnings;
use TexLintTest;
my $dir = scratch();
my ($status, $out, $err) = run_cli($dir, '', '--help');
is($status, 0, 'help works without latexindent');
like($out, qr/--semantic-wrap-preferred-markers/, 'help exposes companion argument names');
($status, $out, $err) = run_cli($dir, '', '--version');
is($status, 0, 'version works without latexindent');
like($out, qr/tex-lint \d/, 'version identifies formatter');
($status, $out, $err) = run_cli($dir, '');
is($status, 2, 'missing inputs are usage error');
for my $args (
    ['--semantic-wrap-soft-width', '0', '-'],
    ['--semantic-wrap-hard-width', 'ten', '-'],
    ['--semantic-wrap-preferred-markers', 'a b', '-'],
    ['--semantic-wrap-continuation-indent', '-1', '-'],
    ['--semantic-wrap-soft-width', '100', '--semantic-wrap-hard-width', '80', '-'],
    ['--check', '--output', '-', '-'],
    ['-', 'another.tex'],
    ['--unknown-option', '-'],
) {
    ($status, $out, $err) = run_cli($dir, '', @$args);
    is($status, 2, 'invalid CLI combination rejected');
}
write_text("$dir/source.tex", 'First sentence. Second sentence.');
($status, $out, $err) = run_cli($dir, '', '--latexindent', "$dir/nonexistent", "$dir/source.tex");
is($status, 2, 'missing backend is error');
like($err, qr/--latexindent \/path\/to\/latexindent.pl/, 'missing backend gives explicit path guidance');
is(read_text("$dir/source.tex"), 'First sentence. Second sentence.', 'backend failure leaves source untouched');
is($out, '', 'errors do not leak formatted text to stdout');
write_text("$dir/broken-backend.pl", "die qq(broken backend\\n);\n");
($status, $out, $err) = run_cli($dir, '', '--latexindent', "$dir/broken-backend.pl", "$dir/source.tex");
is($status, 2, 'worker dependency or interface failure is an error');
like($err, qr/(?:FindBin|LatexIndent|latexindent)/, 'worker failure explains the unavailable dependency or interface');
is(read_text("$dir/source.tex"), 'First sentence. Second sentence.', 'worker failure leaves source untouched');
is($out, '', 'worker failure does not pollute stdout');
($status, $out, $err) = run_cli($dir, '', '--config', "$dir/missing.yaml", "$dir/source.tex");
is($status, 2, 'missing explicit configuration rejected');
1;
