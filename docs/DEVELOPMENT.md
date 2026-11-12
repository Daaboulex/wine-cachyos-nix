# Development

```bash
nix build .#wine-cachyos
nix flake check
```

## Channels

[`sources.nix`](../sources.nix) holds the rolling `version` plus a `pins` map
of frozen tags. The live truth is that file. Every channel hangs off the
package as passthru.

| Channel | Attribute | Tag |
|---|---|---|
| `latest` (also `packages.default`) | `pkgs.wine-cachyos` | newest `*-wine` tag |
| `v<major>` | `pkgs.wine-cachyos.v10` | that major's newest packaged tag |

`latest` rolls with every upstream `*-wine` tag. Each `v<major>` freezes one
major so a prefix built against it keeps working after upstream moves on.

The rolling version always owns its own major. When CachyOS cuts the first
`cachyos-11.0-<date>-wine` tag the updater picks it up as `latest` and `v11`.
Reading `majorPattern` in [`.github/update.json`](../.github/update.json), it
copies the last 10.x release into `pins` itself, so `v10` stays available with
no hand edit.

The rolling release and the pins sit between the `# std:rolling` and
`# std:pins` markers that copy reads.

## Staying in step with upstream

Nothing this flake mirrors from upstream is left to be noticed by hand. Two
checks run in `nix flake check`, so they gate every push, and also gate the
daily updater's verification build. A drift cannot be committed, and the
standard's workflow files the issue.

### runtime-pins

`runtime-pins` reads each channel's own source tree and asserts the Gecko and
Mono versions it ships are exactly the ones `dlls/appwiz.cpl/addons.c`
declares. Ship the wrong Mono and Wine silently asks the user to download it at
prefix creation while every build stays green. This check makes that
impossible.

It needs only the fetched source, so it fails in seconds rather than after a
full compile. It is checked per channel because different Wine majors want
different runtimes.

### upstream-recipe

`upstream-recipe` pins CachyOS's own `PKGBUILD` as a flake input, so the weekly
[`flake.lock`](../flake.lock) refresh re-reads it. It compares the Gecko, Mono
and Xalia versions and every `configure` flag against what this flake actually
passes, and names the file to edit when they diverge. The two flags it leaves
out are `--prefix` and `--libdir`.

The comparison only applies while upstream's `_srctag` matches the packaged
tag. When upstream moves first it says so and passes, because the daily updater
is what advances the tag.

## The other checks

- `wine-shape` tests every channel: `bin/wine` is executable, the
  `x86_64-windows` and `i386-windows` directories exist, the Gecko and Mono
  `.msi` files and `xalia.exe` are in place, and `wine --version` reports the
  channel's major.
- `font-aliases` builds the font alias file, which validates it against
  fontconfig's DTD.
- `module-eval-nixos` evaluates the module with `enable` and `binfmt.enable`
  on.

## Workflows

- [`update.yml`](../.github/workflows/update.yml) is the updater. Its cadence
  is daily unless the `UPDATE_CADENCE` repository variable says otherwise.
- [`maintenance.yml`](../.github/workflows/maintenance.yml) refreshes
  `flake.lock`. Its cadence is weekly unless `MAINTENANCE_CADENCE` says
  otherwise.
- [`ci.yml`](../.github/workflows/ci.yml) runs on every push to the default
  branch and on pull requests.

All three call the workflows of
[nix-packaging-standard](https://github.com/Daaboulex/nix-packaging-standard).
