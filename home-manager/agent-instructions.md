# Response style
- Concise and token-efficient. No pleasantries, filler, or restating the question.
- Clear and honest. Correct wrong premises briefly.
- When teaching something new: enough context to understand, not a lecture.
- When I clearly already know the domain: terse answers only.
- Prefer minimal diffs. Don't expand scope, add docs, or refactor unasked.

# Workflow
- Prefer specialized tools over shell for file ops.
- Don't commit, push, or open PRs unless asked.
- Don't create files/docs unless needed for the task.
- For NixOS: edit the flake, then I rebuild myself unless I ask you to.

# Research
Applies whenever you need a fact from outside the repo — a rate, a threshold, a
statutory rule, an API's real behaviour, why a library does what it does. Do it
without being asked; do not ask permission to look something up.

- **Work down this ladder, stop at the first rung that answers it.** Each rung
  costs more than the one above.
  1. The repo — code, tests, `docs/`, commit history.
  2. `WebSearch` — free, unmetered. **US-biased**: for South African sources pass
     `allowed_domains` (`sars.gov.za`, `gov.za`, `treasury.gov.za`, `saflii.org`).
  3. `WebFetch` — free. Reads HTML. **Cannot read a PDF** — it returns
     unparseable binary.
  4. `curl` + `pdftotext -layout` — free, and the only thing here that reads a
     PDF. Most SA legislation is PDF, so this is usually the rung that works.
     `pdftoppm -png` then Read the images if there is no text layer.
  5. Tavily MCP — 1,000 free credits/month, shared across every project. Spend it
     only on what the free rungs cannot do: a site that blocks WebFetch, or a
     search where the US bias is burying the source.
- **Legislation, rates and thresholds**: use the `legislation-audit` skill. Quote
  the Act, cite the section, record the effective date. A law-firm summary tells
  you which section to read; it is never the citation.
- **Say which rung you reached.** A conclusion from search snippets and one from
  the Act's own words are different things, and I need to be able to tell them
  apart without asking.

# Local tools — Obsidian
- Vault root: `~/Documents/Obsidian Sync Vault`
- Templates live under `Resources/Templates/` (not top-level `Templates/`).
- **Never run `obsidian` for CLI work** — that is the Electron GUI and will open a window.
- Use **`obsidian-cli`** only. It remote-controls a *already-running* Obsidian app via a socket; it will not open the GUI itself, but fails if the app is not running.
- Prefer plain filesystem read/write on vault `.md` files when the app is closed or when GUI must not be involved. The vault is plain markdown on disk.
