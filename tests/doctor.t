use strict;
use warnings;
use File::Path qw(make_path);
use TexLintTest;

{
    my $dir = scratch();
    my $backend_dir = "$dir/script distribution";
    my $path_dir = "$dir/bin";
    my $deps = "$dir/deps";
    make_path("$backend_dir/LatexIndent", $path_dir, "$deps/YAML", "$deps/File");
    write_text("$deps/YAML/Tiny.pm", "package YAML::Tiny; 1;\n");
    write_text("$deps/File/HomeDir.pm", "package File::HomeDir; 1;\n");
    my $script = "$backend_dir/latexindent.pl";
    write_text($script, "die qq(doctor must not execute the backend CLI\\n);\n");
    chmod 0755, $script or die "chmod: $!";
    write_text("$backend_dir/defaultSettings.yaml", "---\n");
    my $document = <<'MODULE';
package LatexIndent::Document;
use YAML::Tiny;
use File::HomeDir;
sub yaml_read_settings {}
sub one_sentence_per_line {}
sub text_wrap {}
package LatexIndent::Verbatim;
sub create_unique_id {}
1;
MODULE
    write_text("$backend_dir/LatexIndent/Document.pm", $document);
    symlink $script, "$path_dir/latexindent" or die "symlink: $!";
    local $ENV{PATH} = $path_dir;
    local $ENV{PERL5LIB} = $deps;
    local $ENV{LATEXINDENT};
    delete $ENV{LATEXINDENT};
    my ($status, $out, $err) = run_cli($dir, '', '--doctor');
    is($status, 0, 'doctor succeeds with only runtime dependencies on PATH');
    like($out, qr/OK   Perl: .*\Q$^X\E/, 'doctor identifies the running Perl interpreter');
    like($out, qr/OK   latexindent: \Q$script\E/, 'doctor resolves backend symlinks and paths with spaces');
    like($out, qr/OK   YAML::Tiny/, 'doctor checks YAML dependency');
    like($out, qr/OK   File::HomeDir/, 'doctor checks home-directory dependency');
    like($out, qr/OK   latexindent installation and interface/, 'doctor checks the adapter interface');
    like($out, qr/Ready to format LaTeX/, 'doctor reports readiness');
    is($err, '', 'successful doctor has no stderr diagnostics');
    ok(!-e "$dir/.ocs", 'doctor creates no scratch files in the working directory');

    unlink "$path_dir/latexindent" or die "unlink: $!";
    ($status, $out, $err) = run_cli($dir, '', '--doctor');
    is($status, 2, 'doctor fails when backend is missing from PATH');
    like($out, qr/FAIL latexindent:.*unavailable/, 'doctor reports missing backend');
    like($out, qr/Add TeX Live's bin directory to PATH/, 'doctor provides PATH guidance');
    like($out, qr/OK   File::HomeDir/, 'doctor continues independent checks after failure');
    like($out, qr/Dependency checks failed/, 'doctor reports failure summary');

    symlink $script, "$path_dir/latexindent.pl" or die "symlink: $!";
    ($status, $out, $err) = run_cli($dir, '', '--doctor');
    is($status, 0, 'doctor falls back to latexindent.pl on PATH');
    $ENV{LATEXINDENT} = "$dir/missing";
    ($status, $out, $err) = run_cli($dir, '', '--doctor');
    is($status, 2, 'explicit environment override does not fall back to PATH');
    ($status, $out, $err) = run_cli($dir, '', '--doctor', '--latexindent', $script);
    is($status, 0, 'CLI backend override takes precedence over LATEXINDENT');
    $ENV{LATEXINDENT} = $script;
    $ENV{PATH} = '';
    chmod 0644, $script or die "chmod: $!";
    ($status, $out, $err) = run_cli($dir, '', '--doctor');
    is($status, 0, 'environment override accepts readable non-executable Perl script without PATH');
    ($status, $out, $err) = run_cli($dir, '', '--doctor', '--latexindent', "$dir/missing");
    is($status, 2, 'CLI backend override does not fall back to LATEXINDENT');

    unlink "$backend_dir/defaultSettings.yaml" or die "unlink: $!";
    ($status, $out, $err) = run_cli($dir, '', '--doctor');
    is($status, 2, 'doctor fails when default settings are missing');
    like($out, qr/FAIL latexindent installation and interface:.*defaultSettings.yaml/, 'missing settings identify the backend installation');
    write_text("$backend_dir/defaultSettings.yaml", "---\n");
    (my $unsupported = $document) =~ s/sub text_wrap \{\}//;
    write_text("$backend_dir/LatexIndent/Document.pm", $unsupported);
    ($status, $out, $err) = run_cli($dir, '', '--doctor');
    is($status, 2, 'doctor fails for unsupported backend interface');
    like($out, qr/Unsupported latexindent interface: missing text_wrap/, 'doctor identifies missing interface method');
    write_text("$backend_dir/LatexIndent/Document.pm", "require TexLintDoctorMissingDependency;\n$document");
    ($status, $out, $err) = run_cli($dir, '', '--doctor');
    is($status, 2, 'doctor fails for missing transitive backend dependency');
    like($out, qr/Can't locate TexLintDoctorMissingDependency.pm/, 'doctor preserves transitive dependency diagnostics');
    write_text("$backend_dir/LatexIndent/Document.pm", $document);
    write_text("$deps/YAML/Tiny.pm", "die qq(YAML dependency unavailable\\n);\n");
    ($status, $out, $err) = run_cli($dir, '', '--doctor');
    is($status, 2, 'doctor fails when an explicit Perl dependency cannot load');
    like($out, qr/FAIL YAML::Tiny: YAML dependency unavailable/, 'doctor identifies the failed Perl dependency');
    like($out, qr/OK   File::HomeDir/, 'other module checks continue after a module fails');

    for my $args (
        ['source.tex'], ['-'], ['--check'], ['--output', '-'],
        ['--config', 'missing.yaml'], ['--semantic-wrap-soft-width', '80'],
        ['--semantic-wrap-hard-width', '100'], ['--semantic-wrap-preferred-markers', ''],
        ['--semantic-wrap-continuation-indent', '0'],
    ) {
        ($status, $out, $err) = run_cli($dir, '', '--doctor', @$args);
        is($status, 2, 'doctor rejects inputs and formatting options');
        like($err, qr/--doctor accepts only --latexindent/, 'doctor explains incompatible arguments');
    }
}
1;
