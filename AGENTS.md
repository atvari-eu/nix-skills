# AGENTS.md

Agent skills for Nix tasks, published to the skills ecosystem (skills.sh). Content-only repo: Markdown + JSON, no build system, linters, or CI.

## Layout

- `skills/<name>/SKILL.md` — one skill per directory. YAML frontmatter needs `name` (must match the directory name) and `description`; the description drives skill triggering, so it must enumerate the concrete tasks/phrasings the skill covers (and exclusions). Keep the body actionable and verified against current Nix behavior.
- `skills/<name>/evals/evals.json` — eval cases: `{skill_name, evals: [{id, prompt, expected_output, files, assertions}]}`. Fixtures referenced by `files` live in `evals/files/` (paths relative to the skill dir).

Skill directory paths are load-bearing: consumers install via home-manager/NixOS options like `programs.opencode.skills."name" = "${src}/skills/<name>"`, pointing directly at them. Don't rename or restructure existing skill dirs without intent.

## Conventions

- Commits touching a skill: `<skill-name>: lowercase imperative summary` (e.g. `nix-hash: document flat vs NAR hashes`). Repo-level changes use conventional prefixes instead (e.g. `docs: add README`).
- Skills cross-reference each other by name (e.g. find-skills defers hash work to nix-hash) — keep such references consistent.

## Verifying changes

No automated checks exist, so verify manually before finishing:
- Validate edited JSON parses (`python3 -m json.tool` / `jq .` / editor check; if neither tool is installed, `nix-instantiate --eval --strict --json --expr 'builtins.fromJSON (builtins.readFile <file>)' > /dev/null` works too).
- Check Nix snippets parse: `nix-instantiate --parse <file.nix>`; flakes additionally `nix flake show` and `nix develop --command true`.
- Confirm shell command examples still behave as documented — upstream Nix and Lix differ (e.g. Lix lacks `nix hash convert`); note divergences where relevant.
