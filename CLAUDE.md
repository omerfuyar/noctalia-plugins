# CLAUDE.md

Instructions for AI agents working in this repository. Read this file fully before doing anything.

This is the only file written for agents. Everything else is written for humans. This file does not repeat project information; it tells you where to find it.

## Where things are

| File                       | What it holds                                                                                  |
| -------------------------- | ---------------------------------------------------------------------------------------------- |
| [README.md](README.md)     | Short introduction and how to install the plugins.                                             |
| [OVERVIEW.md](OVERVIEW.md) | What the plugins are: principles, scope and what each plugin does.                             |
| [DESIGN.md](DESIGN.md)     | How the plugins are built: layout, conventions, the Noctalia plugin model, checks, publishing. |
| [TODO.md](TODO.md)         | Open questions and pending tasks.                                                              |

Before you propose or change anything, read the Contents of OVERVIEW.md and DESIGN.md, then every section the task touches. Read DESIGN.md section 1 before you write code.

| Path              | What it holds                                                                                                   |
| ----------------- | --------------------------------------------------------------------------------------------------------------- |
| `<plugin>/`       | One directory per plugin (DESIGN.md, section 2).                                                                |
| `catalog.toml`    | The plugin source's index. CI generates it on `main`; never edit it (DESIGN.md, section 14.1).                  |
| `.github/`        | Check scripts for agents and CI, and the workflows (DESIGN.md, section 13).                                     |
| `.claude/`        | Claude Code's settings: which commands run without asking, and which never run.                                 |
| `.luaurc`         | Luau's analysis mode for the language server.                                                                   |
| `noctalia.d.luau` | Noctalia's plugin API types for the language server. `check.sh` fetches it; it is not committed.                |
| `ignore/`         | Local output, not committed: screenshots from live tests and tools that `check.sh` fetches.                     |

## Current stage

No plugin is built yet. Build one plugin at a time, in small milestones, and keep DESIGN.md in step with the code.

## How to work with the owner

1. **Apply good solutions, then inform.** When research gives you a working, well-supported solution, write it into the documents as decided and tell the owner what you decided and why. Do not ask first.
2. **Ask when it is really unsure,** or when it is a matter of the owner's taste. Then explain the options and trade-offs, and recommend one. Ask all open questions together, in one batch at the end of your work; the owner answers them at once. Do not assume; the project must not be misunderstood.
3. **Research before proposing.** Check the facts in Noctalia's documentation, in the source of official and community plugins, or on the web. Show the evidence in your reply, not in the documents.
4. **Design first.** Focus on the design of the product, not on implementation, unless asked otherwise.
5. **Correct the owner** when an idea would cause problems, and say why. Do not follow any idea blindly, including the owner's.
6. **Do not be afraid** to delete things, to propose the opposite, or to change the design when it makes sense.
7. **Examples are ideas, not constraints.** Think widely and long term.
8. **Keep one source of truth.** When a decision is made, write it in the one place it belongs and remove it from TODO.md.
9. **Use what Noctalia gives first.** Before you add an external command, check whether Noctalia's runtime API or IPC already does it (DESIGN.md, section 10).

## Boundaries

**Always**

- Write text and code for a human reader: simple, short and easy to read. Do not bloat.
- Keep each plugin's `README.md`, `plugin.toml` and `translations/en.json` in step with its code.
- Check your work as [Checks](#checks) says.

**Ask first**

- Changing anything that is marked as decided.
- Adding an external command to a plugin's `dependencies`.
- Opening a pull request in any other repository, such as `noctalia-dev/community-plugins` (DESIGN.md, sections 14.2 and 14.3).

**Never**

- Push to `main`. Changes reach it only through pull requests.
- Edit `catalog.toml` or `noctalia.d.luau` by hand.
- Add AI features to a plugin (OVERVIEW.md, section 2).
- Run Noctalia commands that end the owner's session or turn off screens, such as `noctalia msg session` or `noctalia msg dpms-off`.

## Checks

- Before each commit, run `.github/scripts/check.sh`. It validates every plugin with the community repository's validator and checks the Luau files with luau-lsp when it is installed.
- Before a pull request, test each changed plugin live with `.github/scripts/live.sh <plugin>` and read the screenshot it prints. This needs the owner's machine: when `noctalia` is not installed where you run, say which plugins were not tested live.
- The scripts print only problems, except the screenshot path from `live.sh`.

## Git

- Commit each finished piece of work. Do not leave changes uncommitted.
- Start each branch from `main`; it reaches `main` through a pull request with a merge commit. There are no releases: what is on `main` is what users of this plugin source get.
- Merge your own pull requests into `main` once checks pass, every changed plugin passed a live test, and no review thread is open.
- Name the branch after the change: `feature/<feature>`, `fix/<bug>`, `refactor/<area>` or `docs/<area>`; never use a generated name.
- Publish the branch at the start of the work, then push each commit to it.
- Put small changes on the branch you work on; do not open a branch for each of them. Keep few branches at a time, each a whole piece of work, so they do not conflict.
- Commit messages have one line per change, starting with `-`. Details go on lines starting with `--`.

## Writing documents

- Markdown only.
- One source of truth: write each thing in one place only. Elsewhere, link to it instead of repeating it.
- Put each thing in its place: product decisions in OVERVIEW.md, technical decisions in DESIGN.md, open questions and pending work in TODO.md, introduction and installing in README.md, instructions for agents in this file. A plugin's own `README.md` is its page on noctalia.dev and follows DESIGN.md, section 14.2.
- OVERVIEW.md and DESIGN.md explain the design and nothing else: no history, sources, research evidence, comparisons with alternatives, status or open questions. Everything in them is decided.
- Explain terms only in the glossary of the document that uses them, never inline.
- Do not invent framings, categories or rules. Do not make vague claims.
- Keep section and list numbers in order, and update cross-references when they change.
- No roadmaps, phases or schedules.
- Use short sentences and plain words:
  - Good: "The widget hides when no monitor reports a brightness."
  - Bad: "It should be noted that, in cases where no monitor is able to report a brightness value, the widget will not be displayed."
