# tex-lint

Semantic source wrapping for LaTeX, using `latexindent.pl` for sentence detection
and protected regions. The CLI and wrapping policy follow the companion
[`../md-lint`](../md-lint) project.

Each detected sentence starts on its own source line. Short sentences stay
together; longer sentences prefer punctuation near a soft width, with a separate
hard width. Widths count source display columns, including LaTeX markup and
indentation, rather than typeset text.

## Requirements and current status

- Perl 5.32 or newer, including its standard modules and Unicode character data.
- The **Perl-script distribution** of `latexindent`, with its `LatexIndent/`
  modules and `defaultSettings.yaml`. TeX Live's script distribution is suitable.
- `latexindent`'s Perl dependencies, including `YAML::Tiny` and `File::HomeDir`,
  available to the Perl interpreter running `tex-lint`.

There is no project package-install or build step, and no Python environment is
needed. With the runtime requirements available, run `bin/tex-lint` directly,
or use `perl bin/tex-lint`.

**Validation status:** the independent wrapping, macro protection, adapter
callbacks, configuration validation, and CLI error tests run without TeX Live.
The full-document integration tests are implemented but have not yet been run
against a real `latexindent` installation. Compilation checks also remain to be
done once TeX Live is ready.

The adapter uses process-local overrides of latexindent's internal sentence
methods, based on its 3.5.1-and-later sentence-object architecture and upstream
4.0.3 source. It checks for the methods it needs. It does not modify the installed
tool. A standalone compiled `latexindent` binary without its Perl modules is not
a supported backend.

## Locate TeX Live

Once installation under `~/.local/texlive` is complete, add the installation's
actual platform-specific `bin` directory to `PATH`. Then check the backend:

```bash
latexindent --version
bin/tex-lint --help
```

Alternatively, select the script explicitly:

```bash
bin/tex-lint --latexindent /absolute/path/to/latexindent.pl document.tex
```

`LATEXINDENT=/absolute/path/to/latexindent.pl` provides the same selection without
repeating the option. The formatter resolves executable symlinks so the adjacent
upstream Perl modules and settings can be loaded. The backend runs under the
same Perl interpreter as the formatter; a successful standalone version check
under a different interpreter is not sufficient.

## Format and check

Like `md-lint`, file inputs are **formatted in place by default**:

```bash
bin/tex-lint document.tex
bin/tex-lint chapters/ appendix.tex
bin/tex-lint --check document.tex
```

Directories are searched recursively for `.tex` files in deterministic order.
Hidden directories, `venv`, `env`, and `node_modules` are skipped; directory
symlinks encountered during recursion are not followed. Explicit file inputs
are accepted regardless of extension. Duplicate resolved paths are processed
once. For an explicitly supplied directory symlink, its contents are searched.

Use a separate output file or stdout to preview:

```bash
bin/tex-lint --output document-formatted.tex document.tex
bin/tex-lint --output - document.tex
bin/tex-lint - < document.tex > document-formatted.tex
```

`-` must be the only input; `--output` requires a single resolved input file.
Input and output text use UTF-8. Formatting is completed for every input before
any source file is edited. Backend errors leave the inputs untouched. Existing
file permissions are preserved when writing in place.

Exit statuses:

| Status | Meaning |
| --- | --- |
| `0` | Formatting succeeded, or every input already passes `--check`. |
| `1` | `--check` found unformatted input. No files were changed. |
| `2` | Invalid arguments/configuration, unavailable backend, or another error. |

Check-mode reports go to stderr. `--check -` compares stdin without emitting
formatted text. `--check` and `--output` cannot be combined.

## Configuration

Put `.latexindent.yaml` in the LaTeX project. The formatter uses the nearest
ancestor configuration for each input, or the nearest configuration from the
working directory for stdin. `--config PATH` selects one file for every input.
Only that settings file and latexindent's defaults are loaded; ambient user
configuration is excluded. YAML `paths` includes are not supported.

```yaml
semantic_wrap:
  soft_width: 80
  hard_width: 100
  preferred_markers: ',;:-–—'
  continuation_indent: 0

defaultIndent: '    '
```

The checkout's configuration also contains the baseline `modifyLineBreaks`
settings from the [original design note](latexindent_sentence_wrapping.md).
Running ordinary `latexindent -m -l` uses the baseline width wrapping; the
conditional punctuation policy requires `tex-lint`.

CLI options override the corresponding `semantic_wrap` settings:

```bash
bin/tex-lint \
  --semantic-wrap-soft-width 72 \
  --semantic-wrap-hard-width 88 \
  --semantic-wrap-preferred-markers ',;:' \
  document.tex
```

Widths must be positive integers and `soft_width` must not exceed `hard_width`.
`continuation_indent` is a nonnegative number of extra spaces, also exposed as
`--semantic-wrap-continuation-indent`. It is additional to the surrounding
LaTeX indentation. With no project setting, surrounding indentation follows
latexindent's defaults, including tab indentation.

### Wrapping policy

While the remaining sentence exceeds the available soft width, choose:

1. The rightmost preferred punctuation boundary at or before soft.
2. Otherwise, the first preferred boundary after soft but at or before hard.
3. Otherwise, the rightmost safe whitespace boundary at or before soft.
4. If the first indivisible word or protected span exceeds soft, the first safe
   whitespace after that span.

For example, with soft `20` and hard `26`:

```text
One, two three, four five six seven.
```

becomes:

```text
One, two three,
four five six seven.
```

Markers have equal priority; their order has no effect. A marker is a candidate
only when followed by breakable whitespace. Hyphens, en dashes, and em dashes
also need preceding whitespace, preserving hyphenated words. When `-` is
enabled, TeX's standalone `--` and `---` spellings are also preferred boundaries.
An empty marker string disables punctuation preference:

```bash
bin/tex-lint --semantic-wrap-preferred-markers '' document.tex
```

Only ordinary spaces and tabs are breakable; nonbreaking spaces are not.
Widths account for wide characters, combining accents, and emoji grapheme
clusters. Tabs use eight-column stops. Individual words, URLs, and protected
macros may overflow the hard width rather than being split.

### LaTeX-specific behavior

- Sentence recognition, including its abbreviation heuristics, comes from
  latexindent. Customize its `oneSentencePerLine` detection settings for the
  project. Markdown's `--slw-*` language options have no direct LaTeX equivalent.
  Prose upstream does not recognize as a sentence, such as text without a
  sentence-ending marker, receives normal indentation rather than reflow.
- Existing eligible prose line breaks are rejoined before wrapping.
- Verbatim environments and commands use upstream's protection routines.
- Inline math (`$...$`, `\(...\)`), display math, common equation environments,
  common table environments, and `tikzpicture` are protected from reflow.
- Macro invocations with balanced optional/mandatory arguments stay atomic,
  including URLs and citations. Their original source width is measured.
  Sentences inside a macro argument are not split independently.
- Comments, paragraph boundaries, explicit `\\` breaks, and multiline protected
  objects are barriers. Sentences crossing a barrier are conservatively left
  out of reflow. Comment text is not wrapped or moved by the sentence pass.
- Document structure, item indentation, and other normal indentation remain
  latexindent's responsibility. Custom verbatim environments and `%\begin{noindent}`
  blocks can be specified through its usual YAML settings.

The adapter enforces sentence manipulation, wrapping after indentation, and
overflow preservation, and disables the upstream comment-wrapping pass.
`sentenceIndent` is managed through `continuation_indent` instead. YAML switches
that enable replacement passes, upstream check mode, or stdout logging are
rejected because they conflict with the formatter's CLI protocol.

## Tests

The dependency-free TAP harness runs with the existing Perl installation:

```bash
perl tests/run.pl
```

Tests cover companion-compatible punctuation selection, Unicode widths,
configuration validation, protected spans, indentation callbacks, idempotence,
and CLI errors. Without a real backend, the full-document integration group is
explicitly skipped.

Enable the real-backend suite after TeX Live is ready:

```bash
TEX_LINT_LATEXINDENT=/absolute/path/to/latexindent.pl perl tests/run.pl
```

That group exercises actual sentence detection, YAML/CLI precedence, file/check/
stdin/output modes, recursive input discovery, protected TeX fixtures, and
whole-document idempotence. A backend or dependency failure fails the tests.

The compilation fixture is `tests/fixtures/protected.tex`. Compile the original
and a separately formatted copy after the integration tests pass, and compare
their typeset output before adopting the formatter across a document collection.
Compilation is not part of the dependency-free test run.

Runtime scratch input copies, output copies, and upstream logs are confined to
`$PWD/.ocs/tex-lint/run-*` and removed after each invocation. Tests use disposable
directories under `.ocs/tests/`. No persistent test reports or caches are needed.

## Pre-commit

The repository includes a local system-language hook:

```yaml
repos:
  - repo: local
    hooks:
      - id: tex-lint
        name: Semantic LaTeX wrapping
        entry: bin/tex-lint
        language: system
        files: '\.tex$'
```

It uses the checkout and the current `PATH`/`LATEXINDENT`, formatting matching
files in place. When using the hook in another repository, set `entry` to this
checkout's absolute `bin/tex-lint` path.

## Source layout

- `bin/tex-lint`: input discovery, CLI, check/write/output workflow.
- `lib/TexLint/Config.pm`: shared setting validation.
- `lib/TexLint/SentenceWrap.pm`: independent display-column wrapping core.
- `lib/TexLint/Protection.pm`: balanced macro-argument protection.
- `lib/TexLint/LatexIndentAdapter.pm`: isolated upstream sentence integration.
- `libexec/tex-lint-worker.pl`: one fresh upstream process per input file.
- `tests/`: dependency-free tests and gated real-backend fixtures.
