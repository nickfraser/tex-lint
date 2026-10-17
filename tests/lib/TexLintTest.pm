package TexLintTest;
use strict;
use warnings;
use Exporter 'import';
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use Encode qw(encode decode);
our @EXPORT = qw(ok is like throws skip scratch write_text read_text run_cli finish);
our ($count, $failed) = (0, 0);
our $root;

sub ok {
    my ($value, $name) = @_;
    $count++;
    print($value ? "ok $count - $name\n" : "not ok $count - $name\n");
    $failed++ unless $value;
    return $value;
}
sub is {
    my ($got, $expected, $name) = @_;
    my $pass = defined($got) && defined($expected) && $got eq $expected;
    ok($pass, $name);
    unless ($pass) {
        for ($got, $expected) { $_ = '<undef>' unless defined; s/\n/\\n/g; }
        print "# got: $got\n# expected: $expected\n";
    }
}
sub like { my ($got, $pattern, $name) = @_; ok($got =~ $pattern, $name); }
sub throws {
    my ($code, $pattern, $name) = @_;
    my $success = eval { $code->(); 1 };
    ok(!$success && $@ =~ $pattern, $name);
}
sub skip { my ($reason) = @_; $count++; print "ok $count # SKIP $reason\n"; }
sub scratch {
    make_path("$root/.ocs/tests");
    return tempdir('case-XXXXXXXX', DIR => "$root/.ocs/tests", CLEANUP => 1);
}
sub write_text {
    my ($path, $text) = @_;
    open my $fh, '>:raw', $path or die "$path: $!";
    print {$fh} encode('UTF-8', $text);
    close $fh or die "$path: $!";
}
sub read_text {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "$path: $!";
    local $/;
    return decode('UTF-8', <$fh> // '');
}
sub run_cli {
    my ($cwd, $stdin, @args) = @_;
    my $dir = scratch();
    write_text("$dir/stdin", $stdin // '');
    my $pid = fork();
    die "fork: $!" unless defined $pid;
    if (!$pid) {
        chdir $cwd or die "chdir $cwd: $!";
        open STDIN, '<:raw', "$dir/stdin" or die $!;
        open STDOUT, '>:raw', "$dir/stdout" or die $!;
        open STDERR, '>:raw', "$dir/stderr" or die $!;
        @args = map { utf8::is_utf8($_) ? encode('UTF-8', $_) : $_ } @args;
        exec {$^X} $^X, "$root/bin/tex-lint", @args;
        die "exec: $!";
    }
    waitpid($pid, 0);
    my $status = $?;
    return ($status & 127 ? 128 + ($status & 127) : $status >> 8,
        read_text("$dir/stdout"), read_text("$dir/stderr"));
}
sub finish { print "1..$count\n"; return $failed ? 1 : 0; }
1;
