---
name: nix-hash
description: Handles SRI (Subresource Integrity) hashes for Nix, including converting between hash formats (SRI, hex, base32), computing hashes of files and strings, using `nix hash` commands, and working with fixed-output derivations. Use this skill whenever the user mentions nix hashes, SRI hashes, hash conversion, hash prefetching, fixed-output derivations, fetchFromGitHub hashes, fetchurl hashes, or any task involving Nix hash manipulation.
---

# Nix Hash

This skill covers working with SRI (Subresource Integrity) hashes in Nix, including conversion, computation, and usage in derivations.

## Hash Formats in Nix

Nix uses several hash formats:

- **SRI** (`sha256-BASE64`) — The modern standard, used in `fetchFromGitHub`, `fetchurl`, etc. Format: `<algo>-<base64>`
- **Hex** (`sha256:HEX`) — Used by `nix-prefetch-url --type sha256`
- **Base32** (Nix-specific) — Legacy format used by older Nix versions

SRI is the preferred format. Always use SRI hashes in new derivations.

## Common Commands

### Converting Hashes

```bash
# Convert hex to SRI
nix hash to-sri --type sha256 <hex-hash>

# Convert SRI to hex
nix hash convert --to-hex --hash-algo sha256 <sri-hash>

# Convert base32 to SRI
nix hash to-sri --type sha256 --base32 <base32-hash>
```

### Computing Hashes

```bash
# Hash a file (flat, for fetchurl)
nix hash file --type sha256 --base16 <file>

# Hash a file in SRI format
nix hash file --type sha256 --sri <file>

# Hash a string
nix hash to-sri --type sha256 $(echo -n "my-string" | sha256sum | cut -d' ' -f1)
```

### Prefetching (for fetchFromGitHub, fetchurl, etc.)

```bash
# Prefetch a GitHub repo (outputs SRI hash + src derivation)
nix-prefetch-github <owner> <repo> --rev <rev>

# Prefetch a URL (outputs SRI hash)
nix-prefetch-url --unpack --type sha256 <url>
```

## Using Hashes in Derivations

### fetchFromGitHub

```nix
pkgs.fetchFromGitHub {
  owner = "owner";
  repo = "repo";
  rev = "v1.0.0";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
```

### fetchurl

```nix
pkgs.fetchurl {
  url = "https://example.com/file.tar.gz";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
```

### fetchPatch

```nix
pkgs.fetchpatch {
  url = "https://example.com/fix.patch";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
```

## When Hashes Don't Match

If you see `hash mismatch` errors:

1. The hash in the derivation is wrong, or
2. The upstream source changed (reproducibility issue)

To get the correct hash, use the suggested hash from the error message:

```
error: hash mismatch in fixed-output derivation
  specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
  got:        sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=
```

Replace the old hash with the `got:` value.

## Hash Algorithms

- **sha256** — Default, most common
- **sha512** — Use when the package provides a sha512 hash
- **sha1** — Legacy, avoid unless required by upstream

## Tips

- Always use `--unpack` with `nix-prefetch-url` for tarballs/archives
- Use `nix hash to-sri` for quick conversions
- Keep hashes in SRI format for readability and Nix compatibility
- When updating a package, re-prefetch to get the correct hash
