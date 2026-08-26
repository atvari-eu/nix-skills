# nix-skills

[Agent skills](https://skills.sh/) for Nix tasks: hashes, flakes, packaging, and skill discovery.

## Skills

| Skill | Description |
| --- | --- |
| [find-skills](skills/find-skills/SKILL.md) | Discover, install, and update agent skills from the open skills ecosystem — via the `skills` CLI or declaratively in home-manager/NixOS. |
| [nix-flake](skills/nix-flake/SKILL.md) | Set up a reproducible Nix development environment (`flake.nix` + devshell) for any Git repository. |
| [nix-hash](skills/nix-hash/SKILL.md) | Compute and convert SRI/hex/base32 Nix hashes; prefetching and fixed-output derivations. |
| [nix-init](skills/nix-init/SKILL.md) | Generate Nix packages from repository URLs with [nix-init](https://github.com/nix-community/nix-init). |

## Installation

Install individual skills via the `skills` CLI:

```console
$ skills add atvari-eu/nix-skills@nix-hash -g
```

Or via home-manager/NixOS:

```nix
programs.opencode.skills."nix-hash" = "${inputs.nix-skills}/skills/nix-hash";
```

## Layout

- `skills/<name>/SKILL.md` — one skill per directory
- `skills/<name>/evals/evals.json` — eval cases with fixtures in `evals/files/`

Skill directory paths are load-bearing — don't rename or restructure existing skill dirs without intent.

## License

[MIT](LICENSE)
