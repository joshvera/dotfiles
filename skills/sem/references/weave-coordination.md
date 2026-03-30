# weave Coordination + Merge Semantics

Git merges lines.

weave merges entities.

This matters in multi-agent workflows where two changes to different functions in the same file can produce a false conflict in Git.

weave provides two related capabilities:

1. Entity-level merge semantics (`weave preview`, merge driver when set up explicitly).
2. Advisory coordination via local state (claims are intent signals, not hard locks).

Treat claims like turn signals: they communicate intent. The merge driver remains the safety net.

Never run `weave setup` from a skill unless the user explicitly requests it.
