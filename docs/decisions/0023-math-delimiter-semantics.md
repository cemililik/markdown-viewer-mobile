# ADR-0023: Currency-safe markdown math delimiters

- **Status**: Accepted
- **Date**: 2026-07-30
- **Deciders**: Cemil Ilık
- **Owner**: Cemil Ilık
- **Revisit date**: 2027-01-30
- **Supersedes**:
  delimiter semantics in [ADR-0006](0006-math-rendering.md)

This ADR proposes exact, testable delimiter semantics for inline and
display math without changing the `flutter_math_fork` renderer.

## Context

ADR-0006 chooses the math renderer and names `$...$` and `$$...$$`, but
does not define lexical boundaries. Pairing any two dollar signs on a line
can merge a currency amount with a later math expression. Other ambiguous
cases include escaped dollars, soft line breaks, mid-paragraph display
markers, empty blocks, indentation, and unclosed delimiters.

The parser must favor literal document text when syntax is incomplete or
ambiguous. A malformed delimiter must not consume following prose or
delete user-authored dollar signs.

## Decision

### Escape rule

A dollar sign is escaped when immediately preceded by an odd-length run of
backslashes. Escaped dollar signs remain literal text and cannot open or
close math. An even-length run leaves the dollar sign available to the
delimiter scanner after normal backslash processing.

### Inline math

An inline opener is one unescaped `$` that:

- is not adjacent to another `$`;
- has a following character;
- is not followed by Unicode whitespace; and
- is not followed by a Unicode decimal digit.

The decimal-digit restriction makes currency-like `$5` literal. Authors
who need a numeric expression can write `$n = 5$`, `\(5\)` is not added as
an alternative syntax by this decision.

An inline closer is one unescaped `$` that:

- is not adjacent to another `$`;
- has a preceding non-whitespace character; and
- is followed by end of input, Unicode whitespace, or Unicode
  punctuation, but not a letter, decimal digit, underscore, or another
  dollar sign.

The body:

- is non-empty;
- contains no line break;
- preserves its source text for accessibility and copy actions; and
- is subject to the existing parser-cost length cap.

The scanner selects the first closer satisfying all rules. If no valid
closer exists, the opener and all following text remain literal.

### Display math

A display opener is a line containing:

- zero to three leading ASCII spaces;
- exactly `$$`; and
- optional trailing spaces or tabs, with no other content.

A display closer follows the same whole-line rule. The body lies between
the two lines and must contain at least one non-whitespace character.

Display rules are:

- opening or closing fences indented by four or more spaces belong to an
  indented code block;
- `$$` inside a prose line is literal and never opens display math;
- the body may contain line breaks and dollar signs that are not a valid
  whole-line closer;
- display content is emitted as one block and is never re-parsed as inline
  math; and
- an empty or unclosed display fence remains literal markdown. It never
  advances the parser past following prose.

### Required delimiter table

The parser test suite must include at least this table:

| Input | Expected |
|-------|----------|
| `$x$` | One inline expression `x` |
| `Cost: $5` | Literal text |
| `Cost: $5 and $x$` | Currency literal plus one expression `x` |
| `Total: $5$` | Literal text |
| `Price \$5` | Literal escaped dollar |
| `\$x$` | Literal escaped opener |
| `$x\$y$` | One expression whose body contains a literal dollar |
| `$ x$` | Literal text because whitespace follows the opener |
| `$x $` | Literal text because whitespace precedes the closer |
| `$x` | Literal unclosed opener |
| `$x` followed by a line break and `y$` | Literal text, no inline math |
| `Text $$ x $$` | Literal text, no display math |
| A `$$` line, `x + y`, then a `$$` line | One display expression |
| A three-space-indented `$$` block | One display expression |
| A four-space-indented `$$` block | Indented code, no math |
| Two adjacent `$$` lines | Literal empty display block |
| An unclosed `$$` line followed by prose | Literal source; prose remains |

The table is normative. Additional regression cases may tighten malformed
input handling but must not make a listed literal case render as math.

### Relationship to ADR-0006

ADR-0006 continues to govern `flutter_math_fork` as the renderer and the
supported TeX subset. When this proposal is accepted, it supersedes only
ADR-0006's unspecified `$...$` and `$$...$$` delimiter semantics.

## Consequences

### Positive

- Currency cannot capture a later mathematical expression.
- Escaped and malformed delimiters preserve exactly what the user typed.
- Display math cannot hijack indented code or following prose.
- Parser, viewer, accessibility labels, and PDF export share one syntax.
- A normative test table prevents regex changes from redefining the
  language accidentally.

### Negative

- Inline expressions beginning with a decimal digit, such as `$5^2$`, are
  intentionally treated as literal text.
- The delimiter scanner is more involved than one regular expression.
- Documents written for a more permissive dollar-math dialect may need
  small edits.
- `\(...\)` and `\[...\]` remain unsupported.

## Alternatives considered

### Pair any two dollar signs on a line

Rejected because currency can merge with unrelated later content and
produce a large, misleading math run.

### Apply whitespace boundaries only

Rejected because `$5` can still become an opener and capture a later
dollar sign.

### Allow inline math across soft line breaks

Rejected because it expands the capture range of malformed input and makes
unclosed delimiters consume prose unpredictably.

### Support TeX `\(...\)` and `\[...\]` now

Rejected because this ADR resolves the shipped markdown dialect. Adding
another public syntax requires separate compatibility and escaping tests.

### Make unclosed display fences parser errors

Rejected because markdown parsers should preserve readable literal source
for incomplete author input instead of making the document unloadable.

## Revisit criteria

Cemil Ilık will review this decision on **2027-01-30** using compatibility
reports from real documents and parser test results. An earlier review is
required if CommonMark, GitHub Markdown, or the selected markdown package
adopts a documented math-delimiter specification that conflicts with this
dialect.
