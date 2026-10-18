package TexLintPDF;
use strict;
use warnings;
use Exporter 'import';
use File::Path qw(make_path);
use TexLintTest;
our @EXPORT_OK = qw(build_pdf inspect_pdf compare_pdf);

sub _checked {
    my ($dir, $name, @command) = @_;
    my ($status, $out, $err) = run_command($dir, '', @command);
    write_text("$dir/$name.stdout", $out);
    write_text("$dir/$name.stderr", $err);
    die "Command failed (exit $status) in $dir: @command\n$out\n$err\n" if $status;
    return $out;
}

sub build_pdf {
    my ($dir, $engine, $tools) = @_;
    my $mode = $engine eq 'pdflatex' ? '-pdf' : '-lualatex';
    _checked($dir, 'latexmk', $tools->{latexmk}, '-norc', $mode,
        '-interaction=nonstopmode', '-halt-on-error', '-file-line-error',
        '-no-shell-escape', '-synctex=0', 'document.tex');
    die "No PDF produced in $dir\n" unless -s "$dir/document.pdf";
    return "$dir/document.pdf";
}

sub inspect_pdf {
    my ($dir, $tools) = @_;
    my $pdf = "$dir/document.pdf";
    _checked($dir, 'pdftotext', $tools->{pdftotext}, '-enc', 'UTF-8', '-layout', $pdf, "$dir/document.txt");
    my $info = _checked($dir, 'pdfinfo', $tools->{pdfinfo}, '-box', $pdf);
    my ($pages) = $info =~ /^Pages:\s+(\d+)/m;
    my ($size) = $info =~ /^Page size:\s+(.+)$/m;
    die "Cannot read PDF page geometry in $dir\n" unless $pages && $size;
    _checked($dir, 'pdftoppm', $tools->{pdftoppm}, '-r', '96', $pdf, "$dir/page");
    my @images = map { sprintf '%s/page-%0*d.ppm', $dir, length($pages), $_ } 1 .. $pages;
    die "Missing page raster in $dir\n" if grep { !-s $_ } @images;
    return {text => read_text("$dir/document.txt"), pages => $pages, size => $size, images => \@images};
}

sub compare_pdf {
    my ($before, $after) = @_;
    my $same_pixels = $before->{pages} == $after->{pages};
    if ($same_pixels) {
        for my $i (0 .. $#{$before->{images}}) {
            $same_pixels &&= read_bytes($before->{images}[$i]) eq read_bytes($after->{images}[$i]);
        }
    }
    return {
        text => $before->{text} eq $after->{text},
        geometry => $before->{pages} == $after->{pages} && $before->{size} eq $after->{size},
        pixels => $same_pixels ? 1 : 0,
    };
}
1;
