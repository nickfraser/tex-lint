use strict;
use warnings;
use TexLintTest;
use TexLintPDF qw(build_pdf inspect_pdf compare_pdf);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

if (!$ENV{TEX_LINT_COMPILE}) {
    skip('use --compile for latexmk compilation and Poppler PDF-equivalence tests');
} else {
    my %tools = map { $_ => find_program($_) } qw(latexmk pdflatex lualatex pdftotext pdfinfo pdftoppm bibtex);
    make_path("$TexLintTest::root/.ocs/integration");
    my $artifacts = tempdir('compile-XXXXXXXX', DIR => "$TexLintTest::root/.ocs/integration", CLEANUP => 0);
    print "# Compilation artifacts: $artifacts\n";
    # Keep font and TeX caches within the test's owned workspace as well.
    local $ENV{TEXMFVAR} = "$artifacts/texmf-var";
    local $ENV{TEXMFCONFIG} = "$artifacts/texmf-config";
    local $ENV{TEXMFCACHE} = "$artifacts/texmf-var";
    make_path($ENV{TEXMFVAR}, $ENV{TEXMFCONFIG});
    my $backend = $ENV{TEX_LINT_LATEXINDENT} // find_program('latexindent');
    my $settings = "$artifacts/settings.yaml";
    write_text($settings, "semantic_wrap:\n  soft_width: 40\n  hard_width: 55\ndefaultIndent: '    '\nverbatimEnvironments:\n  linewise: 1\n");
    my $inline_settings = "$artifacts/inline-items.yaml";
    write_text($inline_settings, read_text($settings)
        . "noAdditionalIndent:\n  item: 1\n  itemize: 1\n  enumerate: 1\n  description: 1\nnoAdditionalIndentGlobal:\n  items: 1\nmodifyLineBreaks:\n  items:\n    ItemFinishesWithLineBreak: -1\n");
    my %results;
    for my $engine (qw(pdflatex lualatex)) {
        for my $fixture (qw(protected prose structures references whitespace unicode items readme)) {
            next if ($fixture eq 'unicode' || $fixture eq 'readme') && $engine eq 'pdflatex';
            my $case = "$artifacts/$engine-$fixture";
            make_path("$case/original", "$case/formatted");
            my $source_path = $fixture eq 'readme' ? "$TexLintTest::root/examples/README.tex"
                : "$TexLintTest::root/tests/fixtures/$fixture.tex";
            my $source = read_text($source_path);
            my $case_settings = $fixture eq 'items' || $fixture eq 'readme' ? $inline_settings : $settings;
            my ($status, $formatted, $err) = run_cli($case, $source,
                '--latexindent', $backend, '--config', $case_settings, '-');
            die "Cannot format $fixture for compilation:\n$err" if $status;
            ok($formatted ne $source, "$engine/$fixture actually changes source wrapping");
            my ($again_status, $again, $again_err) = run_cli($case, $formatted,
                '--latexindent', $backend, '--config', $case_settings, '-');
            die "Cannot reformat $fixture:\n$again_err" if $again_status;
            is($again, $formatted, "$engine/$fixture is source-idempotent");
            for my $variant (qw(original formatted)) {
                my $dir = "$case/$variant";
                write_text("$dir/document.tex", $variant eq 'original' ? $source : $formatted);
                write_text("$dir/references.bib", read_text("$TexLintTest::root/tests/fixtures/references.bib"))
                    if $fixture eq 'references';
                build_pdf($dir, $engine, \%tools);
                ok(-s "$dir/document.pdf", "$engine/$fixture/$variant compiles with latexmk");
                my $log = read_text("$dir/document.log");
                ok($log !~ /(?:There were undefined references|(?:Reference|Citation) .+ undefined|Rerun to get cross-references right|Label\(s\) may have changed|Missing character:)/,
                    "$engine/$fixture/$variant has resolved references and no missing glyphs");
                ok(-s "$dir/document.bbl", "$engine/$fixture/$variant ran BibTeX") if $fixture eq 'references';
                $results{"$engine/$fixture/$variant"} = inspect_pdf($dir, \%tools);
            }
            my $comparison = compare_pdf($results{"$engine/$fixture/original"}, $results{"$engine/$fixture/formatted"});
            ok($comparison->{text}, "$engine/$fixture preserves extracted text and line layout");
            ok($comparison->{geometry}, "$engine/$fixture preserves page count and geometry");
            ok($comparison->{pixels}, "$engine/$fixture preserves every rendered page pixel at 96 dpi");
        }
    }
    # Negative controls ensure the comparator detects content changes and also
    # layout changes that would pass a whitespace-normalized text comparison.
    my $control_source = "\\documentclass{article}\n\\begin{document}\n\\noindent Original control sentence.\n\\end{document}\n";
    my %control;
    for my $variant (qw(original content layout)) {
        my $dir = "$artifacts/control-$variant";
        make_path($dir);
        my $source = $control_source;
        $source =~ s/Original/Changed/ if $variant eq 'content';
        $source =~ s/Original/\\hspace*{20pt}Original/ if $variant eq 'layout';
        write_text("$dir/document.tex", $source);
        build_pdf($dir, 'pdflatex', \%tools);
        $control{$variant} = inspect_pdf($dir, \%tools);
    }
    my $content = compare_pdf($control{original}, $control{content});
    ok(!$content->{text} && !$content->{pixels}, 'negative control detects changed PDF content');
    (my $original_words = $control{original}{text}) =~ s/\s+//g;
    (my $layout_words = $control{layout}{text}) =~ s/\s+//g;
    is($layout_words, $original_words, 'layout negative control has identical textual content');
    my $layout = compare_pdf($control{original}, $control{layout});
    ok(!$layout->{pixels}, 'negative control detects changed placement despite identical words');
}
1;
