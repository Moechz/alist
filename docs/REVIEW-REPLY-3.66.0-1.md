# Reply to the listing review — AList File Manager `3.66.0-1`

> Answers the report of **2026-11-18** for `alist 3.64.0-4` (x86_64, package SHA-256
> `7b9f29640b07afd7d8914d35efbf3bdc3e83e061728f0b2dcff243044e1eb5bb`), verdict
> **Approved**, 11 remediation items.
>
> Use as the submission remarks (“Rectified per review comments”) and as the reply to the
> review e-mail. `3.64.0-4` is already listed, so nothing was withdrawn; this version is
> submitted on top of the published listing for both architectures.

Dear TerraMaster App Review Team,

Thank you for the report. `3.66.0-1` answers all eleven items. The upstream application is
now **AList 3.66.0** (the current release, 2026-10-21), which is also the answer to T1, and
the packaging itself was changed where the findings were real.

Two notes on provenance, because the report mixes two artefacts:

- The package SHA-256 in the header (`7b9f2964…`) is the hash the platform recorded for
  **3.64.0-3**; the released `3.64.0-4` x86_64 asset hashes to
  `a468786db5092829716b8f65f700c3a4af9fd8f4a03f112399e024fb00780b42`. Version 3.64.0-4
  already carried `webui.bz2` and the privacy page, so items F22/C3 as worded did not match
  that build — we treated them as real requirements anyway and re-checked every one below.
- The report’s *Verification Summary* states “**Installed and started successfully**” while
  items F1/F2/F7 report installation, start-up and web-interface failures. Our own on-device
  run (below) agrees with the summary; if the functional failures are reproducible in your
  environment, the installer/journal log would let us find the difference.

## Compliance items

**P1 — publisher field inconsistent with the Maintainer.** Fixed at the source:
`config.ini` → `"publisher": "Moechz"` and `DEBIAN/control` → `Maintainer: Moechz
<moechz@163.com>` — the same traceable party, and the same identifier the other listings use.
The upstream author is still identified where it belongs: `alist.lang` → `auth = "AList Team"`,
the package description (“Upstream author: AList Team. Publisher and Maintainer of this
package: Moechz.”) and `NOTICE.md` §6. A **build-time gate** now fails the build if
`publisher != Maintainer` or if the publisher is a placeholder/vendor name.

**C4 — Privacy policy incomplete.** The in-package policy
(`/usr/local/alist/privacy-policy.html`, bilingual, also served at
`/alist/privacy-policy.html` and published as `PRIVACY.md`) now has explicit sections for
each required topic:

- **Retention period** — no automatic expiry; the data lives in `/var/lib/alist`; upgrading
  keeps and migrates it; **uninstalling deletes it** (with a back-up warning); logs are in the
  system journal; the maintenance log is removed on uninstall.
- **User rights** — access/export (data folder, UI, API/WebDAV), correction (UI or
  `alist.env`), deletion (UI, uninstall, `rm -rf`), restriction (per-storage visibility,
  per-user permissions, guest disabled by default).
- **Security measures** — dedicated non-root user, systemd sandbox (`NoNewPrivileges`,
  `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`, kernel/CG protections,
  `ReadWritePaths`, `UMask=0027`), loopback-only listener, credential files 0640/0600, hashed
  passwords, revocable share tokens.
- **Third-party sharing** — §7 table (below): nothing is shared by the developer.
- **Deletion channel** — self-service uninstall or `rm -rf /var/lib/alist`, plus
  **moechz@163.com** (subject “AList data request”, answered within 30 days) and the issue
  tracker.

**C8 — Third-party API usage not disclosed.** `PRIVACY.md` §7 and the in-package policy now
list every endpoint class, the data sent and the destination/region:

| Feature you enable | Endpoint (host examples) | Data sent | Destination / region |
|---|---|---|---|
| Aliyun Drive | `api.alipan.com`, `openapi.alipan.com` | OAuth token, file operations | Alibaba Cloud, mainland China |
| Baidu Netdisk | `pan.baidu.com`, `photo.baidu.com` | access token, file operations | Baidu, mainland China |
| 139 / 189 / 123Pan / 115 / Xunlei / Tencent drives | `mopan.sc.189.cn`, `api.cloud.189.cn`, `yun.123pan.com`, `proapi.115.com`, `api-pan.xunlei.com`, `api.vs.tencent.com` | credentials entered, file metadata/transfers | the respective provider, mainland China |
| OneDrive / SharePoint | `graph.microsoft.com`, `login.microsoftonline.com` | OAuth token, file operations | Microsoft, region of the tenant |
| Google Drive / Photos | `www.googleapis.com`, `photoslibrary.googleapis.com` | OAuth token, file operations | Google, global (US/EU) |
| Dropbox / pCloud / others | `api.dropboxapi.com`, `my.pcloud.com`, … | credentials, file operations | the provider (EU/US) |
| S3-compatible / Azure Blob | the endpoint the user configures | access key/secret, object operations | the configured region/account |
| WebDAV / FTP / SFTP added by the user | the address entered | username/password, file operations | that server |
| Offline download / link preview / remote upload | the URL submitted | one HTTP request for that URL | the target the user chose |
| Update check (administrator, manual) | `api.github.com`, `github.com` (optional proxy `gh-proxy.com` / `ghproxy.net`) | a version query, no personal data | GitHub, US (or the configured proxy) |
| ffmpeg thumbnails (optional) | no network access | — | the NAS itself |

There is no telemetry, no analytics, no automatic phone-home and no developer-operated
server; with default settings the app contacts nothing.

**C2 — Intellectual property (from the earlier round, kept in scope).** `NOTICE.md` was
rewritten and a `LICENSE` file added: upstream **AGPL-3.0** (used unmodified, binary built
from the upstream source tag by this repository’s public CI, so the corresponding source is
available upstream), the bundled component table, this packaging under **MIT**, trademark
statement and an icon statement (“upstream AList logo, used only to identify the project”).

## Functional and package items

**F11 — Residual configuration or data after uninstall.** Fixed: `postrm` now performs the
full cleanup on **both `remove` and `purge`** — `/var/lib/alist`, the systemd unit, the nginx
route, the dedicated user, postinst-derived files and the maintenance log — matching the
official lifecycle table (`postrm → Clean up user, data, residual files`). The upgrade paths
(`upgrade`, `failed-upgrade`, `abort-*`) explicitly keep the data, so an upgrade never loses
the database. Verified on hardware: after `dpkg --remove alist` nothing listed above remains
and `nginx -t` still passes; a reinstall afterwards works. The store text (all 14 languages)
and the package description now warn that uninstalling deletes the data.

**F22 — `webui.bz2` missing although `path` is declared.** The package ships
`/usr/local/alist/webui.bz2` (a tar.bz2 whose entry is an openable `index.html` that opens
`/alist/`), entries owned by uid/gid 0, no AppleDouble files. The build fails if the archive
lacks an `.html` entry or contains non-root owners. If the checker still reports it missing,
the exact path it looked for would help us align — the file is present in both architecture
packages of this release.

**S11 — File permissions not minimised.** The build now sets `umask 022` and normalises modes
explicitly (public files 0644, `bin/alist` 0755, directories 0755), with a gate that fails on
any world-writable file; runtime credential files stay minimal (`config.json` 0640,
`admin_password.txt` 0600 root-only). The service runs as the dedicated non-root user `alist`
(`User=`/`Group=` in the unit, created idempotently in `preinst`), never as root. This also
fixes a real access issue: the previous 0640 mode on the privacy page could make the TOS web
server (non-root worker) return 403.

**F1 / F2 / F7 — Installation, start-up, web interface.** Not reproducible. On a TOS 7 device:

| Check | Result |
|---|---|
| `dpkg -i` (fresh install and upgrade over an existing install) | succeeds, `ii  alist 3.66.0-1` |
| `systemctl is-active` / `is-enabled` | `active` / `enabled` |
| Process identity | uid of the `alist` system user (non-root), `MainThread` alive |
| Listener | `127.0.0.1:15244` only — no public listener |
| Platform route `/alist/` (through the TOS web server) | **200** |
| `/alist/privacy-policy.html` | **200**, contains the policy text |
| WebDAV `/alist/dav/` without credentials | **401** (authentication required, as designed) |
| Login with the generated password (`admin`) | **200** |
| Restart / upgrade | service comes back, data and password file preserved |
| Uninstall | zero residual files (see F11) |

Note that the TOS web port `8181` answers **301** to the TLS port; the checks above follow the
redirect (`https://<nas>:5443/alist/`). If a browser test only used `http://<nas>:8181/alist/`
without following the redirect, that alone explains an “interface does not work” observation.

**F5 — Declared functionality not fully usable.** The described features (aggregate storages,
browse/preview/upload/download, share links, offline downloads, WebDAV, per-user permissions)
are all exercised by the app; the one dependency worth stating is that **video thumbnails and
some previews need `ffmpeg`**, which is declared as `Recommends:` (installed from the
distribution repositories, not bundled). The package description, README and policy now say
this explicitly. If a specific described feature failed, please name it and we will either fix
it or remove it from the description.

**T1 — High or critical CVE.** Upgraded upstream **3.64.0 → 3.66.0** (current
release), so the Go toolchain, standard library, embedded web assets and the static musl base
are all rebuilt from the newer source; the two tarball sha256 pins were updated to the new CI
output. Remediation note: the binary is built from the upstream tag by the public workflow
`.github/workflows/build-upstream.yml` (run attached to the `build-v3.66.0` release), shipped
statically linked and not packed. The report notes the scanner was unavailable, so no CVE list
is attached; if you can share the affected components we will evaluate them explicitly.

## Verification summary of this submission

- `./build.sh verify` (layout, config.ini, 14 languages, static ELF, systemd/nginx rules,
  `webui.bz2` ownership, file modes, **P1 identity gate**, **F11 cleanup gate**) — all green.
- Official `TOSAppSelfTestingTool -c` on the staged tree — passed.
- On-device E2E (`test/install-and-verify.sh`) — install, service identity, loopback listener,
  platform route, privacy page, WebDAV, login, P1 identity, upgrade-keeps-data, uninstall
  leaves nothing, reinstall — all green.
- Both architectures built: `alist_x86_64.deb` / `alist_aarch64.deb` with their `.sha256`.

## Package details (`3.66.0-1`)

- Assets: `alist_x86_64.deb` / `.sha256`, `alist_aarch64.deb` / `.sha256`
- Upstream: AList **v3.66.0** (AGPL-3.0), binary built from source by the public CI flow
- Publisher / Maintainer: **Moechz** (consistent, P1)
- Route: `/alist/` (new tab); backend on `127.0.0.1:15244` only
- Data: `/var/lib/alist` (deleted on uninstall; preserved on upgrade)
- Privacy policy: in-package `/usr/local/alist/privacy-policy.html`, served at
  `/alist/privacy-policy.html`, and <https://github.com/Moechz/alist/blob/main/PRIVACY.md>
- Repository: <https://github.com/Moechz/alist>

Kind regards,
Moechz
