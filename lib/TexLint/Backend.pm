package TexLint::Backend;
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;

sub resolve {
    my ($class, $requested) = @_;
    my @names = defined($requested) ? ($requested) : ('latexindent', 'latexindent.pl');
    for my $name (@names) {
        my @paths = $name =~ m{/} ? ($name) : map { File::Spec->catfile($_, $name) } File::Spec->path;
        for my $path (@paths) {
            next unless -f $path && -r $path && (-x $path || defined $requested);
            return abs_path($path);
        }
    }
    die "latexindent is unavailable. Add TeX Live's bin directory to PATH, or pass\n"
        . "--latexindent /path/to/latexindent.pl (LATEXINDENT is also supported).\n";
}

# Load and check exactly the interface used by the adapter, without executing
# latexindent's CLI or reading ambient configuration. Call in a fresh process.
sub load {
    my ($class, $backend) = @_;
    require FindBin;
    my $dir = dirname($backend);
    local $FindBin::RealBin = $dir;
    local $FindBin::Bin = $dir;
    local $FindBin::Script = 'latexindent.pl';
    local @INC = ($dir, @INC);
    for my $relative ('LatexIndent/Document.pm', 'defaultSettings.yaml') {
        my $path = File::Spec->catfile($dir, $relative);
        die "Missing or unreadable $path. Use latexindent's Perl-script distribution.\n"
            unless -f $path && -r $path;
    }
    eval { require LatexIndent::Document; 1 }
        or die "Cannot load latexindent's Perl modules: $@";
    for my $method (qw(yaml_read_settings one_sentence_per_line text_wrap)) {
        die "Unsupported latexindent interface: missing $method\n"
            unless LatexIndent::Document->can($method);
    }
    die "Unsupported latexindent interface: verbatim objects unavailable\n"
        unless LatexIndent::Verbatim->can('create_unique_id');
}

1;
