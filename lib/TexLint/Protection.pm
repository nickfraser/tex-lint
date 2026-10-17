package TexLint::Protection;
use strict;
use warnings;
use Exporter 'import';
our @EXPORT_OK = qw(protect_commands);

# This scanner runs AFTER latexindent has hidden comments, verbatim, math,
# and the preamble. It supplements that parser with balanced macro arguments;
# it is not a sentence detector or a whole-file regex formatter.
sub _group_end {
    my ($text, $start) = @_;
    my @ends = substr($text, $start, 1) eq '{' ? ('}') : (']');
    for (my $i = $start + 1; $i < length($text); $i++) {
        my $char = substr($text, $i, 1);
        if ($char eq '\\') { $i++; next; }
        if ($char eq '{') { push @ends, '}'; }
        elsif ($char eq '[' && $ends[-1] eq ']') { push @ends, ']'; }
        elsif ($char eq $ends[-1]) { pop @ends; return $i + 1 unless @ends; }
    }
    return; # Malformed groups are left to upstream rather than guessed.
}

sub protect_commands {
    my ($text, $store) = @_;
    my $output = '';
    for (my $i = 0; $i < length($text);) {
        pos($text) = $i;
        if ($text !~ /\G(\\(?:[a-zA-Z@]+\*?|[^\r\n]))/gc) {
            $output .= substr($text, $i++, 1);
            next;
        }
        my $command = $1;
        my $end = $i + length($command);
        # Structural commands must remain visible to latexindent.
        if ($command =~ /\A\\(?:begin|end|item|par)\z/ || $command eq '\\\\') {
            $output .= $command;
            $i = $end;
            next;
        }
        my $valid = 1;
        pos($text) = $end;
        while ($text =~ /\G([ \t]*(?:\r?\n[ \t]*)?)([\[{])/gc) {
            my $group_start = $end + length($1);
            my $next = _group_end($text, $group_start);
            if (!defined $next) { $valid = 0; last; }
            $end = $next;
            pos($text) = $end;
        }
        my $value = substr($text, $i, $end - $i);
        $output .= $valid ? $store->($value) : $value;
        $i = $end;
    }
    return $output;
}

1;
