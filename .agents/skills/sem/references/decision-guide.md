# Decision Guide

## What do you need?

- What changed structurally (entities)? -> `sem`
- What else could break (impact / dependencies)? -> `sem impact`, `sem graph`
- Who last changed an entity? -> `sem blame`
- What should I review first? -> `inspect`
- Will this merge cleanly / where are semantic conflicts? -> `weave preview`, `weave summary`
- Who is editing what (advisory coordination)? -> `weave status`, `weave claim`, `weave release`

## Workflow order

`sem -> inspect -> weave`
