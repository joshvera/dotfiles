---
name: skill-creator
description: Guide for creating or updating Claude Code skills. Use when users want to create a new skill, update an existing skill, or need guidance on skill structure and best practices.
---

# Skill Creator

Create effective Claude Code skills: modular extensions that provide specialized knowledge, workflows, and tool integrations.

## Skill Structure

```
skill-name/
├── SKILL.md          (required - frontmatter + instructions)
├── scripts/          (optional - executable code for deterministic tasks)
├── references/       (optional - docs loaded into context as needed)
└── assets/           (optional - templates, icons, boilerplate for output)
```

### Installation Locations

- **Global skills**: `~/.claude/skills/<skill-name>/SKILL.md`
- **Project skills**: `.claude/skills/<skill-name>/SKILL.md`

Global skills are available in all projects. Project skills are scoped to the repo.

### SKILL.md Format

```markdown
---
name: my-skill
description: What this skill does and when to use it. Be specific about triggers.
---

# Skill Title

Instructions for using the skill.
```

#### Frontmatter Fields

Required:
- `name`: Lowercase, hyphenated, under 64 chars. Verb-led preferred (e.g., `create-migration`, `review-pr`).
- `description`: Primary trigger mechanism. Include both what the skill does AND when to use it. All trigger context goes here, not in the body.

Optional:
- `context: fork` - Run in a forked context (subagent) instead of main conversation
- `model: <model>` - Override the model (e.g., `haiku` for delegation tasks)
- `allowed-tools` - Restrict which tools the skill can use (only with `context: fork`)

#### Body

Write in imperative form. Include only information Claude cannot infer. Challenge each paragraph: "Does this justify its token cost?"

Prefer concise examples over verbose explanations.

## Core Principles

### Conciseness

The context window is shared. Skills metadata is always loaded; body is loaded on trigger. Every token counts.

- Default assumption: Claude is already smart. Only add what it doesn't know.
- Keep SKILL.md under 500 lines.
- Move detailed reference material to `references/` files.

### Appropriate Specificity

Match guidance detail to task fragility:

- **High freedom** (text instructions): Multiple valid approaches, context-dependent decisions
- **Medium freedom** (pseudocode/parameterized scripts): Preferred pattern exists, some variation OK
- **Low freedom** (specific scripts): Fragile operations, consistency critical, exact sequence required

### Progressive Disclosure

Three-level loading keeps context lean:

1. **Metadata** (name + description) - Always in context (~100 words)
2. **SKILL.md body** - Loaded when skill triggers (<5k words)
3. **Bundled resources** - Loaded as needed by Claude (unlimited)

When a skill supports multiple variants or domains, keep core workflow in SKILL.md and move variant-specific details to reference files.

**Pattern: Domain-specific references**
```
cloud-deploy/
├── SKILL.md (workflow + provider selection logic)
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```
Claude loads only the relevant reference file.

**Pattern: Conditional details**
```markdown
## Creating documents
Use docx-js for new documents. See [references/docx-js.md](references/docx-js.md).

## Tracked changes
See [references/redlining.md](references/redlining.md) for tracked change support.
```

Keep references one level deep from SKILL.md. For files over 100 lines, include a table of contents.

### Bundled Resources

**Scripts** (`scripts/`): For deterministic, repeatedly-needed operations. Token efficient; can be executed without loading into context.

**References** (`references/`): Documentation loaded conditionally. Keeps SKILL.md lean. For large files (>10k words), include grep patterns in SKILL.md.

**Assets** (`assets/`): Templates, icons, boilerplate used in output. Not loaded into context.

Avoid duplication between SKILL.md and reference files.

## Creation Process

### 1. Understand Usage

Clarify concrete examples of how the skill will be used. Ask:
- What functionality should the skill support?
- What would a user say that should trigger it?
- Are there edge cases or variants?

### 2. Plan Resources

For each concrete example, identify:
- Code that gets rewritten repeatedly -> `scripts/`
- Documentation Claude needs while working -> `references/`
- Templates or files used in output -> `assets/`

### 3. Create the Skill

```bash
mkdir -p ~/.claude/skills/<skill-name>   # global
# or
mkdir -p .claude/skills/<skill-name>     # project-scoped
```

### 4. Write SKILL.md

1. Write frontmatter with clear `name` and comprehensive `description`
2. Write body instructions in imperative form
3. Create bundled resources as identified in step 2
4. Reference bundled resources from SKILL.md with clear "when to read" guidance

### 5. Validate

- Verify frontmatter has required `name` and `description` fields
- Confirm SKILL.md is under 500 lines
- Check all referenced files exist
- Test scripts by running them
- Verify the description would trigger correctly for intended use cases

### 6. Iterate

Use the skill on real tasks, notice struggles, update accordingly.

## What NOT to Include

- README.md, CHANGELOG.md, or auxiliary docs
- "When to use" sections in the body (put this in `description`)
- Information Claude can already infer
- Setup/testing/installation procedures

## Naming

- Lowercase letters, digits, hyphens only
- Under 64 characters
- Verb-led preferred: `rotate-pdf`, `create-migration`, `review-pr`
- Namespace by tool when helpful: `gh-address-comments`, `docker-compose-debug`
