---
name: nix-init
description: Generates Nix packages from repository URLs using nix-init — hash prefetching, dependency inference, and license detection included. Use this skill whenever the user wants to package a GitHub/GitLab/Gitea repo for Nix, add a tool or library that is missing from nixpkgs to their flake or home-manager config, prepare a pkgs/by-name contribution, or mentions nix-init directly. Also use it when asked to "package X for Nix", "create a derivation from this URL", "add this repo as a Nix package", or to fix/verify packages originally scaffolded with nix-init.
---

# Nix Init

[nix-init](https://github.com/nix-community/nix-init) scaffolds a complete Nix
package from a repository URL: it picks the fetcher, prefetches the source and
dependency hashes via nurl, infers the build system (Rust, Go, Python) and its
dependencies, and detects the license.

The generated file is a strong starting point, not a finished package — upstream
warns that tweaks are usually required. Always verify the result before handing
it back (see Verification).

## Running nix-init

Check if `nix-init` is on PATH first. If not, run it through nix:

```bash
nix run nixpkgs#nix-init -- <args>        # latest packaged release
```

## Non-interactive invocation

Agents cannot answer nix-init's fuzzy interactive prompts, so always pass
`--headless`. It requires `--url`; everything else gets inferred unless you
specify it explicitly.

```bash
nix run nixpkgs#nix-init -- --headless \
  -u 'https://github.com/owner/repo' \
  --overwrite=true \
  /path/to/package.nix
```

### Flags worth knowing

- `-u/--url` — **always pass full HTTPS URLs** (`https://github.com/owner/repo`,
  `https://gitlab.com/...`, `https://codeberg.org/...`). Short forms like
  `github:owner/repo` get mangled into an invalid `git+github:` fetcher and fail.
- `--rev` + `-V/--version` — pin a specific tag and its version. Pass both
  together or neither: `-V 1.2.3` without `--rev` leaves the source pinned to
  the *latest* tag while claiming version 1.2.3. With neither, nix-init tracks
  the latest release and usually emits dynamic tags like
  `tag = "v${finalAttrs.version}"`, which is ideal for updates.
- `--pname` — only needed when the derived name would be wrong (e.g. repo named
  `foo.rs` should be packaged as `foo`).
- `--builder` — forces a builder; otherwise inferred from repo contents (see
  below). Note `buildNpmPackage` is auto-detected but cannot be forced.
- `--cargo-vendor fetchCargoVendor|importCargoLock` — how cargo deps are vendored.
  Prefer the default (`fetchCargoVendor`) for new packages.
- `-S true` — fetch git submodules when the project needs them.
- `--overwrite=true` — long form only; `-y true` swallows `true` as a positional
  argument and breaks the command.
- Output position — pass an explicit **file** path. A directory makes nix-init
  write `default.nix` inside it, which is wrong for pkgs/by-name layout.

### Builder inference

| Repo contents            | Builder                     | Extra hashes          |
| ------------------------ | --------------------------- | --------------------- |
| `Cargo.toml`             | `buildRustPackage`          | `cargoHash`           |
| `go.mod`                 | `buildGoModule`             | `vendorHash`          |
| `pyproject.toml`/setup   | `buildPythonApplication`    | —                     |
| Python library           | `buildPythonPackage`        | —                     |
| `package.json`           | `buildNpmPackage`           | `npmDepsHash`         |
| anything else            | `stdenv.mkDerivation`       | —                     |

nix-init also fills in what it can detect: license(s), description, homepage,
changelog link, `mainProgram`, Go `ldflags`, Python `build-system`,
`dependencies`, `optional-dependencies`, and `pythonImportsCheck`.

## Verification

Treat the generated file as unverified until proven otherwise. Work through
these steps every time — they catch most real-world breakage:

1. **Read the whole file.** Sanity-check pname/version against the actual tag,
   and whether Application vs Package was chosen correctly for Python projects
   (libraries used as dependencies want `buildPythonPackage`).
2. **Build it.** For a quick check of a standalone file:
   ```bash
   nix-build -E 'with import <nixpkgs> {}; callPackage ./package.nix { }'
   ```
   In a nixpkgs checkout, build from the repo root with
   `nix-build -A <pname>` (or `nix build .#<pname>` in a flake).
3. **Fix hash mismatches.** If the build fails with a hash mismatch, set the
   offending attribute to `lib.fakeHash`, rebuild, and copy the `got:` value.
   The `nix-hash` skill covers conversions if needed.
4. **Smoke test.** Run `./result/bin/<mainProgram> --version` (or equivalent)
   so "it built" doesn't hide "it crashes on startup".
5. **Review meta.** Double-check `license` and `description` even when the
   build succeeds — detection can pick up the wrong LICENSE variant or copy a
   typo from the upstream repo.

### Common per-language fixes

- **Rust**: a failing `cargoHash` after fixing code changes means the lockfile
  inputs changed; re-prefetch rather than hand-editing. If the crate uses
  workspace features or git dependencies, consider `importCargoLock`.
- **Go**: `vendorHash` mismatches are routine; take the `got:` value. Projects
  with no module dependencies need `vendorHash = null`.
- **Python**: dependency names must exist under `python3Packages` — rename or
  add overrides where they don't. Missing native libraries show up as build
  failures; add them to `buildInputs`. If `pythonImportsCheck` fails, either
  fix missing runtime deps or drop the check if it tests optional extras.
- **stdenv**: everything meaningful (deps, install phase) still needs manual
  work; consult similar existing packages in nixpkgs.

## Where to put the result

### nixpkgs contributions (pkgs/by-name)

RFC 140 layout: `pkgs/by-name/<first-two-letters>/<name>/package.nix`
(e.g. `pkgs/by-name/vi/vivid/package.nix`). Pass that exact file path as the
output argument — remember a directory argument produces `default.nix`, which
by-name rejects. Keep the generated structure intact (finalAttrs, updateScript,
meta); reviewers expect it. nix-init's `-C true` can commit the change, but do
not commit without being asked.

### Local flakes and configs

Write the file somewhere durable (e.g. `pkgs/<name>.nix`) and wire it up with
callPackage semantics:

```nix
# flake.nix
outputs = { nixpkgs, ... }: {
  packages.x86_64-linux.vivid = nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/vivid.nix { };
};
```

For home-manager/NixOS, expose it through a `packages` overlay or reference the
derivation path in `home.packages` / `environment.systemPackages`. When adding
several generated packages, an overlay returning `callPackage` results keeps
things tidy.

## When generation falls short

- **Rate limits / private repos** — configure access tokens in
  `~/.config/nix-init/config.toml` (`[access-tokens]`), or ask the user for one.
- **Monorepos** — generate, then adjust `src` with the needed subpath handling;
  nurl supports extra args if you must stay automated.
- **Unsupported ecosystems** — the `stdenv.mkDerivation` scaffold is minimal;
  look for a comparable language builder in nixpkgs (e.g. `buildNpmPackage`,
  `buildMaven`, `composerRepository`) and model the file on an existing package.
