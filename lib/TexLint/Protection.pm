package TexLint::Protection;
use strict;
use warnings;
use Exporter 'import';
our @EXPORT_OK = qw(protect_commands protect_item_prefixes);

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

# Run only on upstream's already-protected body. Include the separating space
# INSIDE the opaque prefix so wrapping can never strand \item on its own line.
# The first prose word and its sentence punctuation remain visible to upstream.
sub protect_item_prefixes {
    my ($text, $store, %options) = @_;
    my $output = '';
    for (my $i = 0; $i < length($text);) {
        pos($text) = $i;
        if ($text !~ /\G(\\(?:[a-zA-Z@]+\*?|[^\r\n]))/gc) {
            $output .= substr($text, $i++, 1);
            next;
        }
        my $command = $1;
        my $end = $i + length($command);
        if ($command ne '\\item') {
            $output .= $command;
            $i = $end;
            next;
        }
        my $label = '';
        pos($text) = $end;
        if ($text =~ /\G[ \t]*(?:\r?\n[ \t]*)?(?=\[)/gc) {
            my $start = pos($text);
            my $group_end = _group_end($text, $start);
            if (!defined $group_end) {
                $output .= $command;
                $i = $end;
                next;
            }
            $label = substr($text, $start, $group_end - $start);
            $end = $group_end;
        }
        pos($text) = $end;
        $text =~ /\G[ \t]*(?:\r?\n[ \t]*)?/gc;
        $end = pos($text);
        my $tail = substr($text, $end);
        my $barrier = $options{barrier};
        my $unsafe = !$tail || $tail =~ /\A\R|\A\\(?:begin|end|item|par)(?![a-zA-Z])/ || $label =~ /\R/;
        $unsafe ||= $tail =~ /\A(?:$barrier)/ || $label =~ /$barrier/ if defined $barrier;
        if ($unsafe) {
            $output .= substr($text, $i, $end - $i);
        } else {
            $output .= $store->($command . $label . ' ');
        }
        $i = $end;
    }
    return $output;
}

1;
