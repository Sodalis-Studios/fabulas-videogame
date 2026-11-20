# Workflow

Write everything in English: branch names, commits, PR titles and descriptions, and code comments.

## Branches

- `main` must always run. `dev` is where changes are integrated and tested; it is merged into `main` only once the game runs correctly.
- Never commit directly to `main` or `dev`.
- Create a branch from `dev` for each change and open the PR against `dev`.
- Name branches `<type>/<short-description>` in kebab-case, using the Conventional Commits types: `feat/ledge-hop`, `fix/checkpoint-respawn`, `docs/sound-manager`.

## Conventional Commits

Commits follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(<optional scope>): <description>

[optional body]

[optional footer(s)]
```

## Pull Requests

The PR title follows Conventional Commits, like a commit message.

The PR description uses this structure:

```markdown
## Description
General description of what was done.

## Main Changes

* Change 1
* Change 2
```

When opening a PR:

- Assign it to the person running the session (`gh api user -q .login`).
- Add the label that matches the PR type:

| PR type | Label |
|---|---|
| `feat` adding a new entity (enemy, platform, key...) | `entity` |
| `feat` adding a new component or system | `component` |
| `feat` adding a new level | `level` |
| any other `feat` | `enhancement` |
| `fix` | `fix` |
| `refactor` | `refactor` |
| `docs` | `documentation` |
| `chore`, `build`, `ci` (tooling, config, maintenance) | `chore` |

Reviewers are requested automatically through CODEOWNERS.

## Merging

- PRs into `dev`: **Create a merge commit**.
- `dev` into `main`: **Squash and merge**, so `main` keeps one clean commit per release.
- After squashing `dev` into `main`, merge `main` back into `dev`. Otherwise the next `dev` → `main` PR shows already-released commits again and may conflict.
- Agents don't merge PRs unless explicitly asked.
