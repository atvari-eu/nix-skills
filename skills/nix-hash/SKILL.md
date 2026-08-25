---
name: nix-hash
description: Handles SRI (Subresource Integrity) hashes for Nix, including converting between hash formats (SRI, hex, base32), computing hashes of files and strings, using `nix hash` commands, and working with fixed-output derivations. Use this skill whenever the user mentions nix hashes, SRI hashes, hash conversion, hash prefetching, fixed-output derivations, fetchFromGitHub hashes, fetchurl hashes, or any task involving Nix hash manipulation.
---

# Nix Hash

## Hash Formats in Nix

Nix uses several hash encodings:

- **SRI** (`sha256-BASE64`) — The modern standard, used in `fetchFromGitHub`, `fetchurl`, etc. Format: `<algo>-<base64>`
- **Hex / base16** (`84a5d14c...`) — The encoding most upstream projects publish
- **Base32** (`020ay2q1...`) — Nix-specific legacy encoding; still printed by default by `nix-prefetch-url`

SRI is the preferred format. Always use SRI hashes in new derivations.

## Flat vs NAR Hashes

Which bytes get hashed depends on how the fetcher consumes the source:

- Raw file bytes ("flat") — matches plain `fetchurl` (no `unpack = true`). Compute with `nix hash file`.
- NAR serialisation of an unpacked tree — matches `fetchFromGitHub`, `fetchzip`, and any fetcher with `unpack = true`. Compute with `nix hash path`.

Prefetch accordingly: without unpacking for plain `fetchurl`, with unpacking when the fetcher extracts the archive. Getting this wrong is the most common cause of hash mismatches.

## Common Commands

### Converting Hashes

```bash
# Convert any hash to SRI (hex/base32 input auto-detected)
nix hash to-sri --type sha256 <hash>

# Convert SRI to hex
nix hash to-base16 --type sha256 <sri-hash>
```

On upstream Nix ≥ 2.19 these conversions also exist as `nix hash convert --to sri|base16|base32 --hash-algo sha256 <hash>`. Lix does not provide `nix hash convert`.

### Computing Hashes

```bash
# Raw bytes of a file (matches plain fetchurl); add --base16 for hex output
nix hash file --type sha256 --sri <file>

# NAR serialisation of a tree (matches fetchFromGitHub/fetchzip)
nix hash path --type sha256 --sri <dir>

# Hash a string
nix hash to-sri --type sha256 $(echo -n "my-string" | sha256sum | cut -d' ' -f1)
```

### Prefetching (for fetchFromGitHub, fetchurl, etc.)

```bash
# GitHub repo at tag/branch; JSON includes resolved rev and SRI hash
nix flake prefetch 'github:<owner>/<repo>?ref=<ref>'

# Raw file (plain fetchurl); JSON includes SRI hash
nix store prefetch-file --json <url>

# Unpacked archive (fetchzip / unpack = true); JSON includes SRI hash
nix store prefetch-file --json --unpack <url>

# Legacy alternative: prints base32 — convert with `nix hash to-sri`
nix-prefetch-url [--unpack] [--type sha256] <url>
```

`nix-prefetch-github` is a third-party tool and not always installed; prefer the built-in commands above.

## Using Hashes in Derivations

Fetchers take `hash` in SRI form; default to sha256 unless upstream only publishes another algorithm:

```nix
pkgs.fetchFromGitHub {
  owner = "owner";
  repo = "repo";
  rev = "v1.0.0";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
```

`pkgs.fetchurl` and `pkgs.fetchpatch` follow the same pattern (`url` + `hash`).

## When Hashes Don't Match

A `hash mismatch` means either the stored hash is wrong or the source changed unexpectedly. To get the correct hash, temporarily set `hash = lib.fakeHash;`, rebuild, and copy the `got:` value from the error:

```
error: hash mismatch in fixed-output derivation
  specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
  got:        sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=
```

When updating a package, verify that the changed hash is expected: check the upstream diff between the old and new rev instead of blindly accepting a new hash, since a surprise change can also mean a compromised or retargeted source.
