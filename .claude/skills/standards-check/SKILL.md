---
name: standards-check
description: Cross-check a piece of output (code, doc, ADR, test, commit message) against all relevant project standards. Use as a last-mile verification before handing a deliverable back to the user.
---

# Standards Check Skill

Verify that a deliverable complies with the binding standards in
`docs/standards/`. Think of this as a final sanity pass.

## Applicability

| Deliverable | Standards to apply |
|-------------|--------------------|
| Dart code | coding, naming, architecture, error-handling, performance, security, accessibility |
| Widget code | + accessibility, localization |
| Tests | testing, naming |
| Docs | documentation |
| ADR | documentation (ADR section), decisions README |
| Commit / PR | git-workflow |
| Review comment | code-review |

## Process

1. Classify the deliverable
2. Open each applicable standard
3. Walk through each rule that applies to this deliverable type
4. Produce a pass/fail checklist with specific line references

## Output Format

```
## Deliverable
<one-line classification>

## Applicable Standards
- <list>

## Check
- [x] <rule> — pass
- [ ] <rule> — fail — <line> — <fix>

## Verdict
<pass / fail / fail-with-nits>
```

## Rules

- Do not rewrite the deliverable — report only
- Cite the specific standard and the specific rule
- If nothing applies, say so — do not invent rules
