# Documentation Standards

## Language

- All documentation is written in **English**
- User-facing application strings are localized separately — see
  [localization-standards.md](localization-standards.md)

## Types of Documentation

| Type | Location | Audience |
|------|----------|----------|
| Product docs | `docs/` | Contributors, stakeholders |
| ADRs | `docs/decisions/` | Contributors, future self |
| Standards | `docs/standards/` | Contributors, AI agents |
| API docs (Dartdoc) | Inline `///` | Library consumers |
| README | Repository root | First-time visitors |
| Changelog | `CHANGELOG.md` | Users, release managers |

## Markdown Style

- ATX headings (`#`, `##`) — never Setext
- Sentence case for all headings except `README`
- One H1 per document, at the top
- Reference-style links when URLs are long or repeated
- Tables for comparative data; bullet lists otherwise
- Code fences must declare a language
- Line length: soft 100, hard 120
- No trailing whitespace

## Diagrams

Use **mermaid** as the project's default diagram syntax. Mermaid renders
natively inside the app, so authors get a live preview of their own
documentation by opening the file with the viewer.

Prefer mermaid for:

| Use case | Mermaid type |
|----------|-------------|
| System architecture, component layers | `flowchart` |
| Sequence interactions across modules | `sequenceDiagram` |
| State machines, lifecycles | `stateDiagram-v2` |
| Phased timelines and roadmaps | `gantt` |
| Class relationships in the domain | `classDiagram` |
| Entity relationships in storage | `erDiagram` |

Rules:

- Use mermaid wherever it explains structure, flow, or state more clearly
  than prose. **Prefer mermaid over ASCII art.**
- Keep each diagram **small and readable** — split large diagrams into
  focused sub-diagrams instead of cramming everything into one
- Place a one-sentence caption immediately above the diagram explaining
  what it shows
- Do not duplicate the same information in both prose and a diagram —
  let the diagram do the explaining and use prose for context only
- All mermaid blocks must use the ` ```mermaid ` fenced syntax so the
  app's renderer (and GitHub) detect them
- Validate every new diagram by opening the document in the app before
  merging

## Document Anatomy

Every `docs/` document must have:

1. Title (H1)
2. Short intro paragraph — one sentence stating purpose
3. Content
4. Optional: References / Related

## Dartdoc

- All public APIs in `core/` and exported barrel files require Dartdoc
- Start with a one-sentence summary ending in a period
- Use `{@template}` and `{@macro}` for shared descriptions

## ADR Format

ADRs follow a reduced MADR template — see
[../decisions/README.md](../decisions/README.md). Every ADR has:

- Title (H1): `ADR-NNNN: <decision>`
- Status: `Proposed | Accepted | Deprecated | Superseded`
- Date
- Context
- Decision
- Consequences (positive + negative)
- Alternatives considered

## When to Write an ADR

Write an ADR when the decision:

- Is hard to reverse
- Affects multiple features or layers
- Introduces a new dependency
- Diverges from a previously accepted decision

Do **not** write an ADR for:

- Naming disputes
- Bikeshed formatting choices
- Bug fixes

## Doc Reviews

Documentation changes go through code review like code. Reviewers check:

- Technical accuracy
- Consistency with other docs
- Markdown formatting
- Dead links

## Changelog

- Follow Keep a Changelog format
- Sections: Added, Changed, Deprecated, Removed, Fixed, Security
- Written in user-facing language, not developer jargon
