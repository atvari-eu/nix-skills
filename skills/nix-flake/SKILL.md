---
name: nix-flake
description: Set up a reproducible Nix development environment for any Git repository — create a flake.nix with a devshell so `nix develop` provides the project's toolchain (cargo/clippy, go/gopls, python/pytest/black, node, ...) without global installs, fix a missing or broken flake.nix, port a legacy shell.nix/default.nix to a flake, diagnose `nix develop` errors such as "does not contain a flake.nix", enforce a policy that every repo must have a flake.nix, or migrate an existing flake away from flake-utils. Use this skill whenever the user wants a project's environment reproducible with Nix, asks for a devshell/dev shell setup, mentions flake.nix or nix develop while working on a project, or asks to get set up hacking on a freshly cloned repo — and proactively check whether the Git repo you are working in has a flake.nix, offering to add one when missing. Writes flakes using the official default template pattern (builtins.mapAttrs over nixpkgs.legacyPackages, never flake-utils) and verifies them by evaluation and build. Not for packaging upstream repos for nixpkgs, converting or prefetching hashes, home-manager/NixOS configuration, or Docker-based environments.
---

# Nix Flake

Every repository an agent works in should have a `flake.nix`. It gives you —
and any human or agent that comes after you — a one-command, reproducible
toolchain: `nix develop` drops into a shell with the project's compiler,
package manager, and linters, independent of whatever happens to be installed
on the host.

This skill covers two things: noticing when a repo is missing its `flake.nix`,
and writing a good one. The template below is the official default since
August 2026 ([NixOS/templates#103](https://github.com/NixOS/templates/pull/103)),
explained in depth by
[Nixcademy](https://nixcademy.com/posts/new-default-nix-flake-template/).

## Checking for a flake

When you start working in a Git repository, check whether a `flake.nix`
already exists at the repo root:

```bash
test -f "$(git rev-parse --show-toplevel)/flake.nix"
```

- **If it exists**, carry on with the user's task. Nothing to do here.
  (Exception: if it uses `flake-utils`, you may offer a migration — see
  [Migrating away from flake-utils](#migrating-away-from-flake-utils).)
- **If it is missing**, offer to add one as part of your work: a single
  sentence like *"This repo has no flake.nix — want me to add one with a dev
  shell for <detected stack>?"* Then continue with what the user actually
  asked. Do not silently create files in someone else's project, but do not
  nag either: if they decline, drop it and move on.
- Ask which toolchain belongs in the dev shell only if the project type is
  genuinely ambiguous. Usually marker files tell you everything (see below).

Skip the offer entirely for checkouts that aren't the user's own work (e.g.
vendored dependencies) or repos where Nix clearly isn't wanted.

## The template

Write the `flake.nix` directly from this skeleton instead of running
`nix flake init`: standard Nix now produces exactly this shape, but other
distributions (e.g. Determinate) ship different templates, and you would have
to rewrite the result anyway.

```nix
# file: flake.nix
{
  description = "<project> development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = inputs: {
    # Enter with `nix develop`
    devShells = builtins.mapAttrs (system: pkgs: {

      default = pkgs.mkShell {
        packages = [
          pkgs.git
          # ... toolchain picked from the table below
        ];
      };

    }) inputs.nixpkgs.legacyPackages;
  };
}
```

Buildable packages follow the same pattern:

```nix
    # Build with `nix build`
    packages = builtins.mapAttrs (system: pkgs: {

      my-tool = pkgs.callPackage ./my-tool.nix { };
      default = inputs.self.packages.${system}.my-tool;

    }) inputs.nixpkgs.legacyPackages;
```

### Why this pattern and not flake-utils

Do not use `flake-utils`, `eachDefaultSystem`, or hand-written system lists:

- `builtins.mapAttrs` over `inputs.nixpkgs.legacyPackages` walks every
  platform nixpkgs supports, so the flake automatically gains or loses
  platforms together with nixpkgs — no hardcoded list to go stale.
- Every extra input inflates the `flake.lock` of *your* flake and of every
  flake that depends on it. Projects commonly end up pinning dozens of
  redundant copies of flake-utils; zero inputs beyond nixpkgs avoids that
  entirely.
- `legacyPackages` reuses the `pkgs` instance the nixpkgs flake already
  built, so evaluation stays fast even in larger dependency trees. The name
  only means "not subject to the flat flake output schema" — the packages
  are current.

## direnv integration

If the repo has no `.envrc`, add one next to the flake so direnv users get
the dev shell automatically on `cd`:

```bash
# file: .envrc
use flake
dotenv
```

Leave an existing `.envrc` alone (offer switching legacy `use nix` lines to
`use flake` while you're at it).

## Tailoring the dev shell

Pick the toolchain from marker files at the repo root, then read the README
if nothing matches:

| Marker                          | Packages                                                                  |
| ------------------------------- | ------------------------------------------------------------------------- |
| `Cargo.toml`                    | `rustc` `cargo` `clippy` `rustfmt` `rust-analyzer`                         |
| `go.mod`                        | `go` `gotools` `gopls`                                                     |
| `package.json`                  | `nodejs`, plus `pnpm`/`yarn`/`bun` matching the lockfile                   |
| `pyproject.toml`/`requirements.txt` | `python3` `uv`                                                          |
| `*.csproj`/`*.sln`              | `dotnet-sdk`                                                               |
| `mix.exs`                       | `elixir`                                                                   |
| `composer.json`                 | `php` `composer`                                                           |
| `Gemfile`                       | `ruby`                                                                     |

Always include `git` — the repo is a Git checkout. Add linters/formatters the
project configures (e.g. `ruff`, `prettier`, `golangci-lint`) and native
libraries that build scripts expect.

Language-specific notes:

- **Rust**: nixpkgs' `rustc`/`cargo` are fine to start. If the repo pins an
  exact toolchain via `rust-toolchain.toml` and builds fail over version
  mismatch, reach for the community `rust-overlay` input rather than fighting
  nixpkgs — that's a real need, unlike platform enumeration.
- **Python**: pip cannot install into nixpkgs' Python directly. Prefer `uv`
  in the shell (`uv venv && uv sync`) so dependency management stays with the
  project's lockfile. For a Python package from nixpkgs to be importable,
  wire it via `python3.withPackages` instead of listing it side-by-side.
- If a `shell.nix` or `default.nix` already exists, port its packages and
  envvars into the flake's dev shell instead of inventing a parallel set, and
  leave the old file in place unless the user asks to remove it.

If `nixos-unstable` currently breaks one of the toolchains you need (this
happens regularly on staging transitions), pinning to the latest stable
release branch (`nixos-25.05`) is the right call — say so in a brief comment
in the flake so readers know why.

## Adding packages

For projects that should also expose a buildable package, put the derivation
in its own file and wire it up with `callPackage` inside the `mapAttrs`
block, as shown above. If your package must be visible *inside* `pkgs`
(because it overrides an existing package or other packages depend on it),
extend `pkgs` with an overlay instead:

```nix
packages = builtins.mapAttrs (
  system: pkgs':
  let
    pkgs = pkgs'.extend (final: prev: {
      my-tool = final.callPackage ./my-tool.nix { };
    });
  in
  {
    inherit (pkgs) my-tool;
    default = pkgs.my-tool;
  }
) inputs.nixpkgs.legacyPackages;
```

A side effect of the overlay route: the package also becomes available
through variants like `pkgs.pkgsStatic` and `pkgs.pkgsCross`.

## Custom nixpkgs configuration

`legacyPackages` uses nixpkgs' default configuration. When you need
`allowUnfree`, CUDA support, or baked-in overlays, instantiate nixpkgs per
selected system yourself with this 5-line helper — still no extra inputs:

```nix
outputs =
  inputs:
  let
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

    eachSystem =
      systems: f:
      builtins.foldl' (
        a: s: a // builtins.mapAttrs (k: v: (a.${k} or { }) // { ${s} = v; }) (f s)
      ) { } systems;
  in
  eachSystem systems (
    system:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      packages.default = pkgs.hello;
      devShells.default = pkgs.mkShell {
        inputsFrom = [ inputs.self.packages.${system}.default ];
      };
    }
  );
```

Decision guide:

1. Default case → `mapAttrs` over `legacyPackages`.
2. Package must live inside `pkgs` → `pkgs.extend` overlay.
3. Custom nixpkgs config needed → `eachSystem` helper above.
4. Reach for `flake-parts` only if you actually use its features, never just
   for platform enumeration.

## Verification

Never hand back an unverified flake:

1. **Parse**: `nix-instantiate --parse flake.nix`
2. **Evaluate**: `nix flake show` (lists all outputs across systems)
3. **Enter**: `nix develop --command true`, or better, run the project's own
   build/test command through it: `nix develop --command cargo build`
4. Show the user what was added (`git status`); do not commit unless asked.
   If the repo's README documents setup steps, a one-line pointer to
   `nix develop` is usually appreciated — ask or mention it, don't silently
   rewrite docs.

## Migrating away from flake-utils

If an existing flake uses `flake-utils.lib.eachDefaultSystem` or similar:

1. Replace the helper with `builtins.mapAttrs ... inputs.nixpkgs.legacyPackages`,
   keeping the body of the callback unchanged.
2. Delete the `flake-utils` input from `inputs`.
3. Run `nix flake lock` and confirm `flake-utils` no longer appears in
   `flake.lock`.
4. Re-verify per the checklist above — output paths stay identical
   (`.#packages.<system>.<name>`), so nothing downstream breaks.
