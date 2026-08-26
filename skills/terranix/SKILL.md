---
name: terranix
description: Write OpenTofu/Terraform infrastructure-as-code in Nix with terranix instead of hand-writing HCL — scaffold a terranix project (flake + config.nix), convert existing .tf HCL files to terranix, fix ${} interpolation clashes between Nix and Terraform ("undefined variable 'var'" / "variable not found" errors), wire up tofu workflows that consume generated config.tf.json, manage secrets via TF_VAR_ and sensitive variables, or verify a terranix setup with tofu init/validate. Use whenever the user mentions terranix, wants Terraform/OpenTofu configuration written in Nix ("infrastructure as nix code", "tf.json from nix", "opentofu in nix"), or works in a repo whose infra lives in config.nix + config.tf.json. Not for plain HCL authoring without Nix, packaging Terraform providers/plugins for nixpkgs, or deploy tools like nixops, colmena, or deploy-rs.
---

# Terranix

[terranix](https://terranix.org) generates [Terraform JSON](https://developer.hashicorp.com/terraform/language/syntax/json)
from Nix modules. You write `config.nix`; the `terranix` tool (or a flake build)
produces `config.tf.json`, which OpenTofu (`tofu`) applies exactly like HCL —
same providers, same state, same plan/apply workflow.

Prefer OpenTofu over Terraform when the user hasn't pinned a choice: it's in
nixpkgs as `pkgs.opentofu`, command `tofu`, reads the same `.tf.json` files, and
resolves providers from its own registry mirror.

Two rules that prevent most mistakes:

- **`config.tf.json` is a build artifact.** Never hand-edit it; regenerate it.
  Gitignore it along with state (see below).
- **Nix and Terraform share the `${}` syntax** (see
  [Interpolation escaping](#interpolation-escaping)) — this clash is the single
  biggest source of broken terranix configs.

Don't convert an existing working HCL project to terranix unasked; offer it if
the user is clearly Nix-first, but leave plain `.tf` repos alone otherwise.

## Two ways to run terranix

| | nixpkgs CLI (`pkgs.terranix`) | flake (`github:terranix/terranix`) |
| --- | --- | --- |
| Invocation | `terranix -q > config.tf.json` | `nix build -o config.tf.json` |
| Reads | `./config.nix` (or path argument) | `modules = [ ./config.nix ]` |
| Module args | `lib` is empty as of 2.8.0 | nixpkgs `lib` extended with `lib.tf.ref` / `lib.tfRef` |
| Best for | quick one-offs | anything real: pinning, modules, CI |

### Quick one-off with the CLI

```bash
nix run nixpkgs#terranix -- -q > config.tf.json   # evaluates ./config.nix
```

Useful flags: `-q/--quiet` prints only the JSON; by default null-valued
attributes are stripped (`-n` / `--with-nulls` keeps them); `--show-trace`
helps debug evaluation errors.

### The flake way (recommended)

```nix
# file: flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    terranix.url = "github:terranix/terranix";
    terranix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, terranix }: {
    packages.x86_64-linux.default =
      terranix.lib.terranixConfiguration {
        system = "x86_64-linux";
        modules = [ ./config.nix ];
      };
  };
}
```

`terranixConfiguration` returns a derivation whose output *is* the JSON, so
`${terraformConfiguration}` interpolates directly into wrapper scripts:

```bash
nix build -o config.tf.json && tofu init && tofu plan
```

If the repo has no flake yet, the `nix-flake` skill covers setting one up.
Upstream also ships a template:
`nix flake init --template github:terranix/terranix-examples`.

If resolving a branch ref like `nixos-unstable` fails with GitHub API errors
(timeouts, empty responses — it happens regularly), pin an explicit revision
instead: `github:nixos/nixpkgs/<rev>` fetches the tarball directly and skips
the API entirely.

## Writing config.nix

The attribute tree mirrors Terraform JSON top-level keys one-to-one:

```nix
{ lib, ... }:
let
  region = "nbg1";          # prefer plain Nix lets over Terraform `locals`
in
{
  terraform.required_providers.hcloud = {
    source = "hetznercloud/hcloud";
    version = "~> 1.45";
  };

  variable.hcloud_token = {
    type = "string";
    sensitive = true;
  };

  provider.hcloud.token = "\${var.hcloud_token}";

  resource.hcloud_server.web = {
    name = "web.example.org";
    image = "debian-13";
    server_type = "cx23";
    location = region;
    ssh_keys = [ "\${hcloud_ssh_key.admin.id}" ];
  };

  resource.hcloud_ssh_key.admin = {
    name = "admin";
    public_key = "\${file(\"~/.ssh/id_ed25519.pub\")}";
  };

  output.web_ip.value = "\${hcloud_server.web.ipv4_address}";
}
```

Mapping from HCL blocks:

| HCL | terranix |
| --- | --- |
| `resource "type" "name" { ... }` | `resource.type.name = { ... };` |
| `data "type" "name" { ... }` | `data.type.name = { ... };` |
| `provider "hcloud" { ... }` | `provider.hcloud = { ... };` |
| `variable "x" { ... }` | `variable.x = { ... };` |
| `output "x" { value = ... }` | `output.x.value = ...;` |
| `module "m" { source = ... }` | `module.m.source = ...;` |
| `locals { x = ... }` | use a Nix `let` binding instead |

Split large configs into modules with `imports = [ ./network.nix ];` — these are
NixOS-style modules, so they can declare their own options and take module args.
Community modules live in `terranix-*` GitHub repos and are added as flake
inputs. Use `terranix-doc-json` / `terranix-doc-man` to inspect what options a
module provides.

## Interpolation escaping

Everything meant for Terraform must survive Nix evaluation. In double-quoted
strings, escape `${` with a backslash; escape inner quotes too:

```nix
provider.hcloud.token = "\${var.hcloud_token}";
key = "\${file(\"~/.ssh/id_ed25519.pub\")}";
```

On the flake version of terranix (≥ 2.9), module args include helpers that do
the quoting for you — `lib.tf.ref "expr"` produces `"${expr}"`,
`lib.tfRef` is an alias. Note the **version divergence**: the nixpkgs CLI
package (2.8.0 at the time of writing) passes an empty `lib`, so those helpers
only exist in flake-based setups.

Pitfalls:

- Inside indented strings (`''...''`), escape as `''${`. But avoid indented
  strings for references entirely: the surrounding whitespace/newlines end up
  inside the JSON value and corrupt the expression. Prefer single-line
  double-quoted strings for anything containing `${`.
- Forgetting the backslash fails fast ("undefined variable 'var'") — good.
  Silently wrong is rarer but worse: check generated JSON when in doubt.
- Computed values that don't need Terraform interpolation (names, regions,
  sizes) should stay plain Nix strings — interpolate only actual cross-references
  between Terraform entities.

## Secrets

Never put API tokens in committed Nix files. Mark variables `sensitive = true`
and inject them through the environment at apply time — OpenTofu picks up
`TF_VAR_<name>` automatically:

```bash
TF_VAR_hcloud_token="$(cat ~/.secrets/hcloud)" tofu apply
```

For a durable entrypoint, wrap `tofu` in a script that loads secrets (e.g. from
a password store or `loadCredential`s) rather than baking them into the flake.

## Verification

Hand back only verified configurations:

1. **Parse**: `nix-instantiate --parse config.nix`
2. **Generate**: `terranix -q > config.tf.json` (or `nix build`) — evaluation
   errors surface here first
3. **Sanity-check the JSON**: it parses, and Terraform references appear
   literally (`grep -F '${var.' config.tf.json`)
4. **Validate**: `tofu init -input=false && tofu validate` — catches schema
   errors against the pinned provider without touching infrastructure
5. Leave `plan`/`apply` to the user unless asked: plans need credentials and
   change real infrastructure.

Gitignore the artifacts; commit only sources and the provider lock file:

```gitignore
/.terraform/
*.tfstate*
/config.tf.json
```

`.terraform.lock.hcl` should be committed (it pins provider hashes).

## Migrating existing HCL to terranix

Only on request. Because Terraform JSON and HCL are equivalent representations,
migration preserves resource addresses (`hcloud_server.web` stays
`hcloud_server.web`) and therefore state continuity — nothing gets recreated.
Convert block-by-block per the table above, keep `variable`/`output` names
identical, delete the old `.tf` files once `tofu plan` shows no changes, and
keep `.terraform.lock.hcl`.
