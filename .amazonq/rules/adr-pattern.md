# ADR Pattern — Decision Recording

**Version:** 1.0 | **Sources:** `docs/adr/`, `ops/receipts/adr/`

---

## When to Suggest an ADR

- Choosing between technologies/frameworks
- Defining/altering architectural patterns
- Changing cryptographic or federation approaches
- Modifying protocols or storage backends

---

## ADR Template

```markdown
# ADR-{number}: {Title}

## Status
{Proposed|Accepted|Rejected|Superseded}

## Context
Why this decision?

## Decision
What did we choose?

## Consequences
### Positive
### Neutral
### Negative

## Verification
How to verify this works?

## References
- Related docs
- External standards
```

---

## Command Helper

```bash
./ops/bin/remembrancer adr create "Use PostgreSQL for storage"
```

---

## Response Pattern

When user makes significant architectural choice:

1. Acknowledge the decision
2. Suggest creating an ADR
3. Provide template with pre-filled context
4. Include verification steps
5. Check against Four Covenants
