use strict;
use warnings;
use TexLintTest;
use TexLint::LatexIndentAdapter;
use TexLint::Config;
my $settings = {
    semantic_wrap => {soft_width => 20, hard_width => 26},
    modifyLineBreaks => {
        oneSentencePerLine => {sentencesFollow => {other => 'CUSTOM'}},
        textWrapOptions => {comments => {wrap => 1}},
    },
    specialBeginEnd => [{name => 'inlineMath', begin => '\\$', end => '\\$', lookForThis => 1}],
};
my $config = TexLint::LatexIndentAdapter::_configure($settings, {hard_width => 30});
is($config->{soft_width}, 20, 'adapter retains project soft width');
is($config->{hard_width}, 30, 'adapter CLI overrides project hard width');
is($settings->{modifyLineBreaks}{textWrapOptions}{when}, 'after', 'adapter wraps after indentation');
is($settings->{modifyLineBreaks}{textWrapOptions}{comments}{wrap}, 0, 'adapter disables upstream comment reflow');
is($settings->{specialBeginEnd}[0]{lookForThis}, 'verbatim', 'adapter delegates math protection to upstream');
my $paren = $settings->{specialBeginEnd}[-1];
like('\\(x, y\\)', qr/$paren->{begin}/, 'paren math begin matches literal TeX delimiter');
like('\\(x, y\\)', qr/$paren->{end}/, 'paren math end matches literal TeX delimiter');
my $follow = $settings->{modifyLineBreaks}{oneSentencePerLine}{sentencesFollow}{other};
like('\\item[label] Text.', qr/$follow/, 'sentences can follow item labels');
like('CUSTOM', qr/$follow/, 'project sentence-follow pattern preserved');
my $object = {body => 'One two three four five six.', follows => '    '};
TexLint::LatexIndentAdapter::_wrap_object($object, TexLint::Config->new(soft_width => 20, hard_width => 26));
is($object->{body}, "One two three\n    four five six.", 'object callback includes continuation indentation');
TexLint::LatexIndentAdapter::_wrap_object($object, TexLint::Config->new(soft_width => 20, hard_width => 26));
is($object->{body}, "One two three\n    four five six.", 'early and late object callbacks do not duplicate indentation');
my $short = {body => 'Short sentence.', follows => '    '};
TexLint::LatexIndentAdapter::_wrap_object($short, TexLint::Config->new);
is('    ' . $short->{body}, '    Short sentence.', 'upstream replacement cannot double-indent a short sentence');
throws(sub { TexLint::LatexIndentAdapter::_configure({semantic_wrap => []}, {}) }, qr/mapping/, 'adapter rejects nonmapping semantic settings');
ok(!TexLint::LatexIndentAdapter::_inline_object({type => 'preamble'}, '\\documentclass{article}'), 'single-line preamble is still a barrier');
ok(!TexLint::LatexIndentAdapter::_inline_object({type => 'special', name => 'displayMath'}, '\\[x = y\\]'), 'single-line display math is still a barrier');
ok(TexLint::LatexIndentAdapter::_inline_object({type => 'special', name => 'inlineMath'}, '$x = y$'), 'inline math remains an atomic inline span');
ok(!TexLint::LatexIndentAdapter::_inline_object({type => 'special', name => 'texLintMacro'}, '\\newline'), 'explicit newline command is a barrier');
ok(!TexLint::LatexIndentAdapter::_inline_object({type => 'special', name => 'texLintMacro'}, "\\foo{line\nbreak}"), 'multiline macro is a barrier');
1;
