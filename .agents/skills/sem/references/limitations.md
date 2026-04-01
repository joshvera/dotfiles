# Limitations

## sem

- Some formats/languages may fall back to chunk-based output when entity parsing is unavailable.

## inspect

- `inspect pr` depends on `gh` to resolve PR refs.

## weave

- Fallback to line-level merge semantics can occur for unsupported file types, very large files, or binaries.
- `weave setup` mutates repo merge-driver configuration; do not run unless explicitly requested.
