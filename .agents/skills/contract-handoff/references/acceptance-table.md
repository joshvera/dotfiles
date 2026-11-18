# Acceptance table

Use this inside the existing execution ledger. Track only the relevant scenarios; one row may cover a coherent group. Link to test output or reports instead of copying logs. The contract revision belongs in the table's context, not a hand-maintained version number.

```markdown
Contract: <path and section> @ <exact commit or immutable snapshot hash>
Review batch: <scope and rationale, or parent verification>

| Scenario | Implementation | Verification evidence | Acceptance / remaining work |
| --- | --- | --- | --- |
| RS-01 | <commit> | <relevant test/result at revision> | Accepted by parent; <review reference if required> |
| RS-02 | <commit> | Happy path passes; failed-refresh case unverified | Open: prove retry performs only the read |
| RS-03 | Pending | None | Open: implement exact-command retention and verify recovery |
```

These rows illustrate status distinctions, not project facts. Replace them with actual IDs and evidence. Record unavailable checks as gaps, not passes. Use applicable repository verification rules, including pre-fix failure evidence for bug regressions.

Attach review findings to the affected rows with a finding reference, correction revision, and closure evidence. Accepted means the parent has checked the implementation and evidence and closed any required review. A coder's completion claim or a green suite total alone does not establish scenario acceptance.

When code or contract revisions change, reassess affected rows and retain acceptance for unaffected behavior. Preserve the prior revision in the existing history; do not reset the whole table or repeat completed reviews by default.
