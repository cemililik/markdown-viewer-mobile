# Math (LaTeX)

The viewer renders LaTeX math through `flutter_math_fork` — a pure
Dart engine compatible with the KaTeX subset. Inline math is
bracketed with single dollars; display (block) math with double
dollars on their own lines.

## Inline math

The quadratic formula is $x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$,
valid when $a \neq 0$.

Euler's identity, $e^{i\pi} + 1 = 0$, packs five fundamental
constants into a single expression. The natural log satisfies
$\ln(xy) = \ln x + \ln y$ for positive reals.

## Display math

A stand-alone equation gets its own vertical breathing room:

$$
\int_{-\infty}^{\infty} e^{-x^2} \, dx = \sqrt{\pi}
$$

Matrix arithmetic:

$$
\begin{pmatrix}
  a & b \\
  c & d
\end{pmatrix}
\begin{pmatrix}
  x \\
  y
\end{pmatrix}
=
\begin{pmatrix}
  ax + by \\
  cx + dy
\end{pmatrix}
$$

Summation with bounds:

$$
\sum_{k=1}^{n} k = \frac{n(n+1)}{2}
$$

## Common notations

| Concept          | Source                      | Renders as                 |
|------------------|-----------------------------|----------------------------|
| Greek letters    | `\alpha \beta \gamma`       | $\alpha \beta \gamma$      |
| Subscript        | `x_{i,j}`                   | $x_{i,j}$                  |
| Superscript      | `x^{2n+1}`                  | $x^{2n+1}$                 |
| Square root      | `\sqrt{x+1}`                | $\sqrt{x+1}$               |
| Fraction         | `\frac{a}{b}`               | $\frac{a}{b}$              |
| Limit            | `\lim_{x \to 0}`            | $\lim_{x \to 0}$           |
| Integral         | `\int_a^b f(x)\,dx`         | $\int_a^b f(x)\,dx$        |
| Summation        | `\sum_{i=1}^{n}`            | $\sum_{i=1}^{n}$           |
| Product          | `\prod_{i=1}^{n}`           | $\prod_{i=1}^{n}$          |
| Binomial         | `\binom{n}{k}`              | $\binom{n}{k}$             |

## Multi-line derivations

The `aligned` environment keeps each step aligned on the `=`:

$$
\begin{aligned}
  (a + b)^2 &= (a + b)(a + b) \\
            &= a^2 + ab + ba + b^2 \\
            &= a^2 + 2ab + b^2
\end{aligned}
$$

## Cases

A piecewise definition:

$$
f(x) = \begin{cases}
  x^2       & \text{if } x \ge 0 \\
  -x^2      & \text{if } x < 0
\end{cases}
$$

## Literal dollar signs

A lone `$` or a dollar sign outside a math span renders verbatim:
the price is \$9.99 and the total rounds to \$10.

## Malformed input

If the parser hits a `$` it cannot close, the rest of the line
falls back to plain text rather than consuming paragraphs further
down the document — an unclosed `$$` inside a paragraph will still
close when the next paragraph boundary (blank line, heading,
horizontal rule, fence) is reached.
