---
name: adr-writing
description: Draft a new Architecture Decision Record in the project's reduced MADR format. Use when a decision is made that is hard to reverse, spans multiple layers, introduces a new dependency, or diverges from an accepted ADR.
---

# ADR Writing Skill

Draft an ADR following the format in `docs/decisions/README.md`.

## Before Drafting

1. Read `docs/decisions/README.md` (template and lifecycle)
2. Read existing ADRs so your tone, depth, and structure match
3. Read `docs/standards/documentation-standards.md` (ADR section)
4. Verify this decision is not already recorded

## Process

1. Pick the next available number (zero-padded, four digits)
2. Write the title as a short, affirmative decision statement
3. Draft sections: Context, Decision, Consequences (positive + negative),
   Alternatives Considered
4. Update `docs/decisions/README.md` index table with the new row

## Rules

- Write in English
- Affirmative voice in the Decision section ("We will use X", not
  "We might use X")
- At least two alternatives considered with explicit rejection reasons
- Consequences must be honest — list the downsides
- Never edit an accepted ADR's content. Supersede with a new ADR instead.
- Status starts as `Proposed`; only the user marks it `Accepted`

## Output Format

A complete new file at `docs/decisions/NNNN-short-slug.md` following the
template, plus the index update.

## When to Propose vs Accept

If you are not certain the decision has been made by the user, draft with
Status: `Proposed` and ask for confirmation. Do not mark `Accepted` on
your own.
