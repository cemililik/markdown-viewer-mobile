# Math Rendering

## Inline math

Einstein's equation states that $E = mc^2$ relates mass to energy.
The Pythagorean theorem is $a^2 + b^2 = c^2$.

Multiple inline expressions in one paragraph: $\alpha$, $\beta$, and
$\gamma$ are the three base angles, while $\sin^2\theta + \cos^2\theta
= 1$ is the trigonometric identity.

## Display math

A single-line display equation:

$$E = mc^2$$

A multi-line display equation spanning several source lines:

$$
\frac{\partial^2 u}{\partial t^2}
= c^2 \nabla^2 u
$$

A display matrix:

$$
\begin{pmatrix}
1 & 2 \\
3 & 4
\end{pmatrix}
$$

## Malformed math

A broken expression that must not crash the viewer — it should render
as an inline error placeholder: $\frac{1}{$ and a broken display block
follows:

$$
\this-is-not-valid-tex
$$

The document keeps rendering after the broken blocks.

## Literal dollar signs

An escaped dollar sign like \$100 must stay literal and never trigger
the math syntax. Two unrelated single dollars on the same line, $5
and $10, should also be treated as prose — inline math requires the
body to be non-empty and to contain no other dollar.
