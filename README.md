# tex-lint

Semantic source wrapping for LaTeX, using `latexindent.pl` for sentence detection
and protected regions. The CLI and wrapping policy follow the companion
[`mdformat-semantic-wrap`](https://github.com/nickfraser/mdformat-semantic-wrap) project.

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

**Verified integration:** `latexindent` **3.24.7**, `latexmk` **4.87**, TeX Live
**2025** (pdfLaTeX and LuaLaTeX), and Poppler **25.07.0**. The full suite passes
**376 assertions**, including 14 original/formatted document pairs with identical
extracted text, page geometry, and page rasters at 96 dpi. Tests also verify
source idempotence and resolved bibliography/cross-references.

The adapter uses process-local overrides of latexindent's internal sentence
methods. The tested 3.x path handles the older settings hash and document-level
sentence-wrapping callback. A separate 4.x path follows upstream 4.0.3's internal
interface; it has callback unit tests but has not been verified against a real
4.x installation. The adapter checks the methods it needs and does not modify
the installed tool. A standalone compiled `latexindent` binary without its Perl
modules is not a supported backend.

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

Like `mdformat-semantic-wrap`, file inputs are **formatted in place by default**:

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

## LaTeX README demonstration

[`examples/README.tex`](examples/README.tex) is a maintained LaTeX edition of this
guide and a substantial formatting demonstration. Its source uses the project's
default 80/100 widths, with protected code examples, hyperlinks, lists, and a
table. Lists use the project's flush-left, inline-item settings described below.
Run these commands from the repository root to check it and build a PDF
with LuaLaTeX:

```bash
bin/tex-lint --check examples/README.tex
latexmk -norc -r examples/latexmkrc -lualatex examples/README.tex
```

The PDF is written to `.ocs/examples/README.pdf`. The example's `latexmkrc` also
keeps auxiliary files and TeX/font caches under `.ocs/examples/`. After building,
preview formatting on a separate copy with:

```bash
bin/tex-lint --output .ocs/examples/README-formatted.tex examples/README.tex
```

The compilation suite additionally reformats the example at 40/55 widths and
checks that its PDF text, geometry, and rendered pixels are unchanged.

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

### List source layout

This project's configuration keeps the first sentence on the same line as
`\item`, and makes ordinary and nested lists flush-left without a hanging indent:

```latex
\begin{itemize}
\item First sentence.
Another sentence in the same item.
\item A longer sentence, with a preferred break,
and a continuation without extra indentation.
\end{itemize}
```

Select that style through native latexindent settings:

```yaml
noAdditionalIndent:
  item: 1
  itemize: 1
  enumerate: 1
  description: 1

noAdditionalIndentGlobal:
  items: 1

modifyLineBreaks:
  items:
    ItemFinishesWithLineBreak: -1
```

The explicit `noAdditionalIndent.item: 1` is important: upstream's per-name
six-space item indent takes precedence over `noAdditionalIndentGlobal.items`.
The environment entries remove the additional indentation inside those lists;
omit those entries to retain surrounding list indentation with inline items.
Any indentation inherited from a containing non-list environment still applies.
`continuation_indent` remains available if extra continuation spaces are desired.

The adapter honors `ItemFinishesWithLineBreak: -1` for standard `\item` commands,
including balanced optional labels such as `\item[Label]`. The item command and
label count toward the first line's width only; the first word stays attached to
the marker. Later sentences still start on new source lines. Comments, blank
paragraphs, and protected block content remain barriers rather than being joined
onto an item line. A long indivisible marker/label plus its first word may overflow.

Without the `-1` setting, existing separate-item behavior is retained.

Set `ItemFinishesWithLineBreak: 1` to explicitly request a newline after `\item`.

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

Run the real-backend suite using `latexindent` from `PATH`:

```bash
perl tests/run.pl --integration
```

To select a particular backend instead:

```bash
TEX_LINT_LATEXINDENT=/absolute/path/to/latexindent.pl perl tests/run.pl
```

That group exercises actual sentence detection, YAML/CLI precedence, file/check/
stdin/output modes, recursive input discovery, protected TeX fixtures, and
whole-document idempotence. A backend or dependency failure fails the tests.

### Compilation and PDF equivalence

Run the complete suite, including real-backend integration and compilation:

```bash
perl tests/run.pl --compile
```

This requires `latexindent`, `latexmk`, `pdflatex`, `lualatex`, `bibtex`,
`pdftotext`, `pdfinfo`, and `pdftoppm` on `PATH`. On Fedora, the PDF utilities
come from `poppler-utils`. Explicit integration/compilation requests fail if a
required tool is unavailable; the default unit-test command skips those groups.
`TEX_LINT_LATEXINDENT` still overrides backend selection with `--compile`.

Seven fixtures in `tests/fixtures/` cover ordinary prose, abbreviation heuristics,
macro arguments, nested lists, tables, math, comments, explicit line breaks,
verbatim/custom newline-sensitive environments, Unicode, footnotes, URLs,
BibTeX citations, multipass cross-references, and inline/flush-left items.
Six fixtures run with both pdfLaTeX and LuaLaTeX;
the `fontspec` Unicode fixture and the LaTeX README example
run with LuaLaTeX.

For each fixture/engine combination, the suite:

1. Confirms that formatting actually changes source and is idempotent.
2. Builds original and formatted documents using `latexmk -norc`, allowing
   bibliography and reference passes to converge.
3. Checks the final logs for unresolved references and missing glyphs.
4. Compares exact `pdftotext -layout` output and page count/geometry.
5. Compares every rendered page byte-for-byte at 96 dpi using `pdftoppm`.

Separate negative controls deliberately change content and shift text placement
to verify that the comparisons catch both kinds of difference. PDF files
themselves are not compared byte-for-byte because metadata and source-dependent
objects can differ without changing typesetting.

Runtime scratch input copies, output copies, and upstream logs are confined to
`$PWD/.ocs/tex-lint/run-*` and removed after each invocation. Tests use disposable
directories under `.ocs/tests/`. Compilation runs retain source copies, PDFs,
extracted text, page rasters, build logs, and local TeX/font caches under
`.ocs/integration/compile-*`; the test output prints the exact directory. These
artifacts are ignored by Git and can be inspected after a failure or success.

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
        exclude: ^tests/fixtures/
```

It uses the checkout and the current `PATH`/`LATEXINDENT`, formatting matching
files in place. When using the hook in another repository, set `entry` to this
checkout's absolute `bin/tex-lint` path.
This checkout excludes its deliberately unformatted regression fixtures from
the hook so their source layout remains part of the test input.

## Source layout

- `bin/tex-lint`: input discovery, CLI, check/write/output workflow.
- `lib/TexLint/Config.pm`: shared setting validation.
- `lib/TexLint/SentenceWrap.pm`: independent display-column wrapping core.
- `lib/TexLint/Protection.pm`: balanced macro-argument protection.
- `lib/TexLint/LatexIndentAdapter.pm`: isolated upstream sentence integration.
- `libexec/tex-lint-worker.pl`: one fresh upstream process per input file.
- `tests/`: dependency-free tests and gated real-backend fixtures.
- `examples/README.tex`: maintained LaTeX user guide and formatting demonstration.
