# Handoff block

Insert this into the existing brief. Replace placeholders, omit empty fields, and reference facts already present rather than repeating them. This complements the workflow's dispatch and callback protocol.

```text
Capability: <name>
Repository/worktree: <recipient's workspace>
Implementation baseline: <exact commit>
Contract: <path and section> @ <exact commit>
Plan / acceptance ledger: <existing paths>
Owned scope: <files or boundary>

Outstanding:
- <scenario ID>: <observable outcome>; needs <missing evidence>

Review boundary: <coherent batch and risk; or parent verification>
Return: <implementation revision, evidence/results, remaining IDs, blockers>
```

List additional contract references only for shared behavior this scope consumes. For an immutable uncommitted snapshot, replace the contract commit with its accessible path and content hash and state why the fallback is needed.

Example outstanding work:

```text
- RS-02: After save acceptance and refresh failure, retry only the read.
  Implementation exists; failed-refresh regression evidence is missing.
- RS-03: Unknown outcomes retain the exact submitted command.
  Implementation and recovery evidence are missing.
```

Keep accepted RS-01 in the linked ledger. The recipient should not need to reconstruct previous conversations to tell what remains. A baseline commit does not establish that another worktree's uncommitted contract edits were agreed.
