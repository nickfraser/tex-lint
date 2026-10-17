package TexLint::SentenceWrap;
use strict;
use warnings;
use utf8;
use Exporter 'import';
our @EXPORT_OK = qw(display_width restore wrap_sentence);

# Measure source display columns, not typeset TeX. Grapheme clusters keep
# combining accents and emoji sequences together; tabs use eight-column stops.
sub display_width {
    my ($text, $column) = @_;
    $column //= 0;
    my $start = $column;
    while ($text =~ /(\X)/g) {
        my $cluster = $1;
        if ($cluster eq "\t") { $column += 8 - $column % 8; next; }
        # Like the companion's wcwidth fallback, controls use character count.
        return length($text) if $cluster =~ /\p{Cc}/;
        next if $cluster =~ /\A[\p{Mark}\p{Default_Ignorable_Code_Point}]+\z/;
        $column += $cluster =~ /\p{East_Asian_Width=Wide}|\p{East_Asian_Width=Fullwidth}|\p{Emoji_Presentation}|\x{FE0F}/ ? 2 : 1;
    }
    return $column - $start;
}

sub restore {
    my ($text, $protected) = @_;
    return $text unless $protected && keys %$protected;
    my $pattern = join '|', map { quotemeta($_) } sort { length($b) <=> length($a) } keys %$protected;
    for (0 .. scalar(keys %$protected)) {
        my $changed = $text =~ s/($pattern)/$protected->{$1}/g;
        return $text unless $changed;
    }
    die "Cyclic protected-text replacements\n";
}

sub wrap_sentence {
    my ($sentence, $config, %options) = @_;
    my $protected = $options{protected} // {};
    my $indent = $options{indent} // '';
    my $continuation = $indent . (' ' x $config->{continuation_indent});
    # Only eligible prose newlines are joined. Opaque spans are never edited.
    $sentence =~ s/[ \t]*\r?\n[ \t]*/ /g;
    $sentence =~ s/\A[ \t]+|[ \t]+\z//g;
    my @lines;
    my $prefix = $indent;
    while (display_width($prefix . restore($sentence, $protected)) > $config->{soft_width}) {
        my @candidates;
        while ($sentence =~ /[ \t]+/g) {
            my ($start, $end) = ($-[0], $+[0]);
            next if !$start || $end == length($sentence);
            my $head = substr($sentence, 0, $start);
            # Never convert a TeX control space into a control newline.
            my ($slashes) = $head =~ /(\\*)\z/;
            next if length($slashes) % 2;
            my $width = display_width($prefix . restore($head, $protected));
            my $marker = substr($head, -1);
            my $preferred = index($config->{preferred_markers}, $marker) >= 0;
            if ($marker eq '-') {
                # Include TeX's conventional --/--- dash spellings, but never
                # prefer a hyphen at the end of a hyphenated word.
                $preferred &&= $head =~ /(?:\A|\s)-{1,3}\z/;
            } elsif ($marker =~ /[–—]/) {
                $preferred &&= length($head) == 1 || substr($head, -2, 1) =~ /\s/;
            }
            push @candidates, [$start, $end, $width, $preferred];
            last if $width > $config->{hard_width};
        }
        last unless @candidates;
        my @before = grep { $_->[2] <= $config->{soft_width} } @candidates;
        my @preferred_before = grep { $_->[3] } @before;
        my @preferred_after = grep {
            $_->[3] && $_->[2] > $config->{soft_width} && $_->[2] <= $config->{hard_width}
        } @candidates;
        my $chosen = @preferred_before ? $preferred_before[-1]
            : @preferred_after ? $preferred_after[0]
            : @before ? $before[-1] : $candidates[0];
        push @lines, $prefix . substr($sentence, 0, $chosen->[0]);
        $sentence = substr($sentence, $chosen->[1]);
        $prefix = $continuation;
    }
    push @lines, $prefix . $sentence;
    return join "\n", @lines;
}

1;
