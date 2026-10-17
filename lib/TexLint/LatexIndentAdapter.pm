package TexLint::LatexIndentAdapter;
use strict;
use warnings;
no warnings 'once'; # Upstream package variables are deliberately fully qualified.
use TexLint::Config;
use TexLint::Protection qw(protect_commands);
use TexLint::SentenceWrap qw(wrap_sentence restore);

sub _configure {
    my ($settings, $overrides) = @_;
    my $custom = $settings->{semantic_wrap} // {};
    die "semantic_wrap must be a mapping\n" unless ref($custom) eq 'HASH';
    my $config = TexLint::Config->new(%$custom, %{$overrides // {}});
    my $sentence = $settings->{modifyLineBreaks}{oneSentencePerLine};
    @$sentence{qw(manipulateSentences removeSentenceLineBreaks textWrapSentences sentenceIndent)} = (1, 1, 1, '');
    my $wrap = $settings->{modifyLineBreaks}{textWrapOptions};
    @$wrap{qw(columns when huge)} = ($config->{hard_width}, 'after', 'overflow');
    $wrap->{comments}{wrap} = 0;
    # Use upstream's protection routines before sentence detection starts.
    for my $special (@{$settings->{specialBeginEnd}}) {
        $special->{lookForThis} = 'verbatim'
            if ($special->{name} // '') =~ /\A(?:inlineMath|displayMath|displayMathTeX)\z/;
    }
    push @{$settings->{specialBeginEnd}}, {
        name => 'texLintParenMath', begin => '(?<!\\\\)\\\\\\(', end => '\\\\\\)', lookForThis => 'verbatim',
    };
    for my $env (qw(equation equation* align align* alignat alignat* gather gather* multline multline* displaymath math tabular tabular* tabularx longtable array tikzpicture)) {
        $settings->{verbatimEnvironments}{$env} = 1;
    }
    my $follow = $sentence->{sentencesFollow}{other};
    $sentence->{sentencesFollow}{other} = '\\\\item(?:\\h*\\[[^]\\r\\n]*\\])?\\h*'
        . ($follow ? "|(?:$follow)" : '');
    for my $key (keys %{$settings->{switchesViaYaml} // {}}) {
        die "switchesViaYaml.$key is incompatible with tex-lint\n"
            if $settings->{switchesViaYaml}{$key} && $key =~ /\A(?:k|kv|r|rr|rv|sl)Switch\z/;
    }
    return $config;
}

sub _protected_text {
    my %protected;
    while (my ($id, $obj) = each %LatexIndent::Verbatim::verbatimStorage) {
        $protected{$id} = ($obj->{begin} // '') . ($obj->{body} // '') . ($obj->{end} // '');
    }
    return \%protected;
}

sub _inline_object {
    my ($object, $value) = @_;
    return 0 if $value =~ /\R|\\(?:newline|linebreak)(?![a-zA-Z])/;
    return 1 if ($object->{type} // '') eq 'command';
    return ($object->{type} // '') eq 'special'
        && ($object->{name} // '') =~ /\A(?:inlineMath|texLintParenMath|texLintMacro)\z/;
}

sub _wrap_object {
    my ($self, $config) = @_;
    my ($indent) = ($self->{follows} // '') =~ /(?:\A|\n)([ \t]*)\z/;
    $self->{body} = wrap_sentence($self->{body}, $config,
        indent => $indent // '', protected => _protected_text());
    # Upstream retains the surrounding indentation when replacing the sentence
    # ID. Only continuation lines need a prefix in the object's own body.
    substr($self->{body}, 0, length($indent), '') if defined($indent) && length($indent);
}

# latexindent has no public sentence callback. Keep the process-local private
# interface in this one module. Never change files in the TeX Live installation.
sub run {
    my ($class, %options) = @_;
    require File::Basename;
    require FindBin;
    my $backend_dir = File::Basename::dirname($options{backend});
    local $FindBin::RealBin = $backend_dir;
    local $FindBin::Bin = $backend_dir;
    local $FindBin::Script = 'latexindent.pl';
    local @INC = ($backend_dir, @INC);
    eval { require LatexIndent::Document; 1 }
        or die "Cannot load latexindent's Perl modules: $@";
    # -d would also suppress -l. Instead use an isolated indentconfig containing
    # only the chosen project file, preventing implicit home-directory settings.
    if ($options{settings}) {
        my $yaml = YAML::Tiny->read($options{settings});
        die "Cannot parse settings $options{settings}: " . YAML::Tiny->errstr . "\n" unless $yaml;
        die "Settings must contain exactly one YAML mapping\n"
            unless @$yaml == 1 && ref($yaml->[0]) eq 'HASH';
        die "Use --config rather than YAML paths to select project settings\n" if exists $yaml->[0]{paths};
    }
    my $isolated = "$options{scratch}/indentconfig.yaml";
    YAML::Tiny->new({paths => $options{settings} ? [$options{settings}] : []})->write($isolated)
        or die "Cannot write isolated latexindent settings: " . YAML::Tiny->errstr . "\n";
    local $ENV{LATEXINDENT_CONFIG} = $isolated;
    for my $method (qw(yaml_read_settings one_sentence_per_line text_wrap)) {
        die "Unsupported latexindent interface: missing $method\n"
            unless LatexIndent::Document->can($method);
    }
    die "Unsupported latexindent interface: sentence objects unavailable\n"
        unless LatexIndent::Sentence->can('mlb_one_sentence_per_line_indent')
            && LatexIndent::Verbatim->can('create_unique_id');

    my $read_settings = LatexIndent::Document->can('yaml_read_settings');
    my $sentences = LatexIndent::Document->can('one_sentence_per_line');
    my $config;
    no warnings 'redefine';
    no strict 'refs';
    local *{'LatexIndent::Document::yaml_read_settings'} = sub {
        my ($self) = @_;
        $read_settings->(@_);
        my $settings = \%LatexIndent::GetYamlSettings::mainSetting;
        $config = _configure($settings, $options{overrides});
    };
    local *{'LatexIndent::Document::one_sentence_per_line'} = sub {
        my ($self) = @_;
        my $storage = \%LatexIndent::Verbatim::verbatimStorage;
        $self->{body} = protect_commands($self->{body}, sub {
            my ($value) = @_;
            my $object = bless { begin => '', body => $value, end => '', type => 'command', name => 'texLintMacro' }, 'LatexIndent::Verbatim';
            $object->create_unique_id;
            # Restore before comments: macro arguments can contain comment IDs.
            $object->{type} = 'special';
            $storage->{$object->{id}} = $object;
            return $object->{id};
        });
        my $settings = \%LatexIndent::GetYamlSettings::mainSetting;
        my $sentence = $settings->{modifyLineBreaks}{oneSentencePerLine};
        my $tokens = \%LatexIndent::Tokens::tokens;
        my @barriers = map { quotemeta($_) } @$tokens{qw(blanklines doubleBackSlash)};
        push @barriers, '\\\\par(?![a-zA-Z])';
        push @barriers, $LatexIndent::TrailingComments::trailingCommentRegExp;
        my @inline;
        my $protected = _protected_text();
        for my $id (keys %$storage) {
            my $obj = $storage->{$id};
            my $value = restore($protected->{$id}, $protected);
            if (!_inline_object($obj, $value)) {
                push @barriers, quotemeta($id);
            } else {
                push @inline, quotemeta($id);
            }
        }
        my $old = $sentence->{sentencesDoNOTcontain}{other};
        push @barriers, "(?:$old)" if $old;
        local $sentence->{sentencesDoNOTcontain}{other} = join '|', @barriers;
        my $old_start = $sentence->{sentencesBeginWith}{other};
        push @inline, "(?:$old_start)" if $old_start;
        local $sentence->{sentencesBeginWith}{other} = @inline ? join('|', @inline) : 0;
        return $sentences->(@_);
    };
    local *{'LatexIndent::Sentence::text_wrap'} = sub {
        my ($self) = @_;
        _wrap_object($self, $config);
    };
    local @ARGV = ('-m', '-s', "-c=$options{scratch}", "-o=$options{output}");
    push @ARGV, $options{input};
    # do preserves upstream's argument handling, logger setup and UTF-8 IO.
    my $result = do $options{backend};
    die "Failed to execute latexindent: " . ($@ || $! || 'unknown error') . "\n"
        unless defined $result;
}

1;
