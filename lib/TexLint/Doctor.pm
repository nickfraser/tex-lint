package TexLint::Doctor;
use strict;
use warnings;
use File::Basename qw(dirname);
use TexLint::Backend;

sub _report {
    my ($label, $check) = @_;
    my $detail = eval { $check->() };
    if ($@) {
        my $error = $@;
        $error =~ s/\s+\z//;
        $error =~ s/\n/\n      /g;
        print "FAIL $label: $error\n";
        return 0;
    }
    print "OK   $label", (defined($detail) && length($detail) ? ": $detail" : ''), "\n";
    return 1;
}

sub _checks {
    my ($requested) = @_;
    my $ready = _report('Perl', sub {
        die "Perl 5.32 or newer is required; running $^V ($^X).\n" if $] < 5.032;
        return "$^V ($^X)";
    });
    my $backend;
    $ready = _report('latexindent', sub {
        $backend = TexLint::Backend->resolve($requested);
        return $backend;
    }) && $ready;
    # Match the adapter's module search path, including the selected backend.
    local @INC = (defined($backend) ? (dirname($backend)) : (), @INC);
    for my $module (qw(YAML::Tiny File::HomeDir TexLint::LatexIndentAdapter)) {
        $ready = _report($module, sub {
            (my $file = "$module.pm") =~ s{::}{/}g;
            require $file;
            return;
        }) && $ready;
    }
    if (defined $backend) {
        $ready = _report('latexindent installation and interface', sub {
            TexLint::Backend->load($backend);
            return 'Perl modules, defaultSettings.yaml, and adapter methods available';
        }) && $ready;
    }
    print $ready ? "Ready to format LaTeX.\n" : "Dependency checks failed.\n";
    return $ready ? 0 : 2;
}

sub run {
    my ($class, $requested) = @_;
    # Upstream packages and FindBin state must not leak into the CLI process.
    my $pid = fork();
    die "Cannot start dependency checks: $!\n" unless defined $pid;
    if (!$pid) {
        my $status = eval { _checks($requested) };
        if ($@) { print STDERR "tex-lint: $@"; exit 2; }
        exit $status;
    }
    waitpid($pid, 0);
    return $? == 0 ? 0 : 2;
}

1;
