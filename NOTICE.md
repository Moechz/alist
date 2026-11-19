# NOTICE — third-party components and attributions

This package (`alist`, TOS 7 deb application) is an independent packaging by **Moechz** of the
upstream **AList** project. It is not affiliated with, sponsored or endorsed by the AList
authors or by TerraMaster.

## 1. Upstream application — AList

- Project: <https://github.com/AlistGo/alist>
- Licence: **AGPL-3.0**
- Relationship: the upstream application is used **unmodified**. The binary shipped in the
  package is built from the upstream source tag `v3.66.0` by the public CI workflow in this
  repository (`.github/workflows/build-upstream.yml`, output attached to the `build-v3.66.0`
  release), so the **corresponding source** is available at that upstream tag and the build is
  auditable end to end. No prebuilt third-party binaries are redistributed.
- Attribution: Copyright © the AList authors.

## 2. Components bundled in the package

| Component | Licence | Notes |
|---|---|---|
| `usr/local/alist/bin/alist` | AGPL-3.0 (upstream) | statically linked Go build from the upstream source tag |
| AList web UI assets | AGPL-3.0 (upstream) | embedded into the binary by the upstream build |
| systemd unit, nginx route, lifecycle scripts, translations, icon | MIT (this packaging) | authored for this package |
| `webui.bz2` placeholder page | MIT (this packaging) | TOS App Center requirement for `path`-declared apps |

`ffmpeg` is a **recommended** dependency (video thumbnails/previews); it is installed from the
distribution repositories by the user's package manager, not redistributed here.

## 3. This packaging

The files authored for this package — TOS metadata (`config.ini`, `alist.lang`), systemd unit,
nginx route, lifecycle scripts (`preinst`/`postinst`/`prerm`/`postrm`), translations, icon,
build scripts and this documentation — are released under the **MIT** licence (see `LICENSE`).
The upstream application stays under AGPL-3.0.

## 4. Trademarks

“AList” is the name of the upstream project. “TerraMaster”, “TOS” and “App Center” are
trademarks or registered trademarks of their respective owners. Their use here is descriptive
only (to identify the software being packaged and the platform it runs on). No TerraMaster
artwork or logo is reproduced in this package.

## 5. Icon

The icon in `assets/images/icons/alist.svg` is the upstream AList project logo, used only to
identify the project this package installs, scaled to the TOS icon safe area. It is not a
TerraMaster or App Center asset.

## 6. Responsible party

- Publisher shown in the App Center (`config.ini` → `publisher`): **Moechz**
- Package maintainer (`DEBIAN/control` → `Maintainer`): **Moechz <moechz@163.com>**
- Upstream author recorded in `alist.lang` (`auth`) and in the package description: **AList Team**

The publisher and the maintainer are the same traceable party, by design (review item P1).

## 7. Contact

Moechz — **moechz@163.com** — <https://github.com/Moechz/alist/issues>
Privacy policy: [PRIVACY.md](PRIVACY.md) (also shipped as
`/usr/local/alist/privacy-policy.html`)
