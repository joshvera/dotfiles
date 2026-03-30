# Commands

This is a compact reference. Prefer the reasoning model in `../SKILL.md`.

## sem

```bash
sem diff --format json
sem diff --staged --format json
sem diff --from <base-ref> --to HEAD --format json

sem graph
sem impact <entity>
sem blame <file>
```

Examples for `<base-ref>`: `origin/main`, `origin/master`

## git

```bash
git -c diff.external=sem-diff-wrapper diff <base-ref>..HEAD
git -c diff.external=sem-diff-wrapper diff -- <path>
```

## inspect

```bash
inspect file <path> --format json
inspect diff <ref> --format json
inspect diff <ref> --format markdown

inspect pr <number> --format json   # requires gh
inspect grep --remote owner/repo --pattern <pattern> <PR_NUMBER>
```

## weave

```bash
weave preview <target>
weave status
weave claim <agent_id> <file_path> <entity_name>
weave release <agent_id> <file_path> <entity_name>
weave summary
```

Never run `weave setup` unless explicitly requested.
