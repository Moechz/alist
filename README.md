# alist-for-tos

> TerraMaster TOS 7 App Center — **deb package** for the
> [AList](https://github.com/AlistGo/alist) file manager (multi-storage aggregation + WebDAV).

## What this is

A TOS 7 `.deb` application package (`alist_<platform>.deb`) that installs AList on a
TerraMaster NAS and opens it in a new browser tab from the App Center route `/alist/`.

| | |
|---|---|
| Upstream | AList **v3.66.0**, AGPL-3.0, <https://github.com/AlistGo/alist> |
| Binary | built from the upstream source tag by **this repository's public CI** (`.github/workflows/build-upstream.yml`, static musl, no UPX); audit chain = source tag → workflow → Actions run → `build-v3.66.0` release |
| Open | `http://<NAS-IP>:8181/alist/` (TOS web server route; the backend itself listens on `127.0.0.1:15244` only) |
| Runs as | dedicated unprivileged system user `alist`, hardened systemd sandbox |
| Data | `/var/lib/alist` (database, config, search index, password file) |
| WebDAV | `http://<NAS-IP>:8181/alist/dav/` |
| Publisher / Maintainer | **Moechz** (`moechz@163.com`) — the same traceable party in `config.ini` and in `DEBIAN/control` |

## How it works

- **New-tab mode.** `config.ini` declares `open_path: true` and `path: "/alist/"`; TOS nginx
  loads `assets/nginx/alist.conf`, which keeps the `/alist/` prefix and proxies to the
  loopback backend. The privacy page has an exact-match location and `/alist` gets a 301.
- **Sub-path native.** AList itself runs under `/alist` (`ALIST_SITE_URL=/alist`), so SPA
  routes, API, WebDAV and direct links stay consistent behind the prefix.
- **Loopback only.** `ALIST_ADDR=127.0.0.1` is the active default in `alist.env` and is
  pre-seeded into `config.json` at install time; no port is exposed to the LAN.
- **First login.** `postinst` pre-creates the administrator with `alist admin set` and stores
  the generated password root-only in `/var/lib/alist/admin_password.txt` (0600); nothing is
  printed to the journal.
- **User-tunable.** Ports, database, HTTPS, FTP/SFTP/S3 listeners and MCP live in
  `/usr/local/alist/alist.env` (copied from `alist.env.example` on first install, never
  overwritten by upgrades); restart the service after editing.

## Design highlights

- **Source-auditable binary (V6).** No upstream prebuilt binary is redistributed: CI builds
  `linux/amd64` and `linux/arm64` statically against musl from the upstream tag, publishes
  `SHA256SUMS`, and `config.env` pins both tarball hashes.
- **Non-root + sandbox.** `User=alist` (no shell/home), `NoNewPrivileges`,
  `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`, kernel/control-group protections,
  `ReadWritePaths=/var/lib/alist`, `UMask=0027`; no `Restart=` (lifecycle belongs to the App
  Center).
- **Deterministic packaging.** `umask 022`, explicit modes (0644 public files, 0755 binary),
  LF/BOM normalisation, AppleDouble/xattr stripping, `webui.bz2` re-packed with uid/gid 0.
- **Self-check gates.** `./build.sh verify` asserts the layout, `config.ini` fields, the
  14-language file, the static ELF, the nginx and systemd rules, the `webui.bz2` owner, the
  package file modes, the publisher/maintainer identity and the uninstall-cleanup behaviour.

## Privacy

This application runs entirely on your NAS. **The developer does not collect, receive or have
access to any data it processes.** There is no telemetry, no analytics, no tracking, no crash
reporting and no automatic update check; the developer operates no server in this path.

| Topic | Detail |
|---|---|
| Data processed | Local user accounts (hashed passwords), the storage credentials you enter (OAuth tokens, access keys, WebDAV/S3/FTP passwords), the server configuration, the search index, temporary files and logs. |
| Where it is stored | `/var/lib/alist` (`data.db`, `config.json`, `admin_password.txt`, index, logs) and `/usr/local/alist/alist.env`. Nothing is uploaded to the developer. |
| Retention | No automatic expiry. **Uninstalling deletes `/var/lib/alist`** (the package specification requires no residual data) — back it up first if you want to keep your library. Upgrading keeps and migrates the data. |
| Your rights | Access/export: copy `/var/lib/alist` or use the UI/API/WebDAV. Correct: edit settings or `alist.env`. Delete: UI, uninstall, or `rm -rf /var/lib/alist`. Restrict: per-storage visibility, per-user permissions, guest disabled by default. |
| Deletion channel | App Center uninstall or `dpkg --remove alist` (complete), or e-mail **moechz@163.com** (subject “AList data request”, answered within 30 days). |
| Security measures | Dedicated non-root user, systemd sandbox, loopback-only listener, credential files 0640/0600, hashed passwords, revocable share tokens. |

**Full policy:** [PRIVACY.md](PRIVACY.md) — also shipped in the package at
`/usr/local/alist/privacy-policy.html`, served at `/alist/privacy-policy.html`, and mirrored on
<https://www.moechz.com/privacy.html> (section 6).

## Third-party services (API disclosure)

Requests are made **only for operations you initiate**. Every storage backend sends the
credentials you entered and the file operations you perform directly from your NAS to the
provider you chose; nothing is sent to the developer.

| Service | Endpoint (host examples) | Data sent | Destination |
|---|---|---|---|
| Aliyun Drive | `api.alipan.com`, `openapi.alipan.com` | OAuth token, file operations | Alibaba Cloud, mainland China |
| Baidu Netdisk | `pan.baidu.com`, `photo.baidu.com` | access token, file operations | Baidu, mainland China |
| 139 / 189 / 123Pan / 115 / Xunlei / Tencent drives | `mopan.sc.189.cn`, `api.cloud.189.cn`, `yun.123pan.com`, `proapi.115.com`, `api-pan.xunlei.com`, `api.vs.tencent.com` | credentials, file metadata/transfers | the respective provider, mainland China |
| OneDrive / SharePoint | `graph.microsoft.com`, `login.microsoftonline.com` | OAuth token, file operations | Microsoft, region of your tenant |
| Google Drive / Photos | `www.googleapis.com`, `photoslibrary.googleapis.com` | OAuth token, file operations | Google, global (US/EU) |
| Dropbox / pCloud / others | `api.dropboxapi.com`, `my.pcloud.com`, … | credentials, file operations | the provider (EU/US) |
| S3-compatible / Azure Blob | the endpoint you configure | access key/secret, object operations | the region/account you configure |
| WebDAV / FTP / SFTP you add | the address you enter | username/password, file operations | that server |
| Offline download / link preview / remote upload | the URL you submit | an HTTP request for that URL | the target you chose |
| Update check (admin, manual) | `api.github.com`, `github.com` (optional proxy: `gh-proxy.com`, `ghproxy.net`) | a version query, no personal data | GitHub, US (or your proxy) |
| ffmpeg thumbnails (optional) | no network access | — | your NAS |

Full detail: `PRIVACY.md` §7.

## Licence and attributions

| Component | Licence | Notes |
|---|---|---|
| AList | AGPL-3.0 | upstream application, used unmodified; the binary is built from the upstream source tag by this repository's public CI (corresponding source available upstream) |
| `ffmpeg` (recommended) | LGPL/GPL per build | installed from the distribution repositories by the package manager, not redistributed here |
| This packaging | MIT (see `LICENSE`) | TOS metadata, systemd unit, nginx route, lifecycle scripts, translations, icon |

“AList” is the name of the upstream project; “TerraMaster”, “TOS” and “App Center” are
trademarks of their respective owners. This is an independent community package by Moechz, not
affiliated with or endorsed by the upstream project or TerraMaster. Full details:
[NOTICE.md](NOTICE.md).

## Build

```bash
make                      # = ./build.sh all → out/alist_<platform>.deb + .sha256
./build.sh stage          # assemble build/pkgroot from assets/ + the pinned upstream tarball
./build.sh verify         # review-standards gates (see Design highlights)
./build.sh deb            # makedeb.sh → out/
TARGET_ARCH=arm64 make    # aarch64 build (needs the arm64 tarball pin)
```

`config.env` is the single source of truth: upstream version, packaging iteration,
`PUBLISHER` / `MAINTAINER` (must stay identical — review item P1), port, data paths and the
two tarball sha256 pins.

## Local verification

```bash
./TOSAppSelfTestingTool -c build/pkgroot/usr/local/alist/   # official field check
bash test/install-and-verify.sh                             # on-device E2E (root)
```

The on-device checks cover install (`dpkg -i`), service `active` + `enabled`, the loopback
ping, `/alist/` through the TOS web server (200), the privacy page (200), WebDAV (401 without
credentials), login with the generated password, an upgrade that keeps the data, and an
uninstall that leaves no residual files.

## Store submission checklist

1. Public GitHub repo with `README.md`, `PRIVACY.md`, `NOTICE.md`, `LICENSE`.
2. Release **tag `v3.66.0-2`** with `alist_x86_64.deb` / `.sha256` and
   `alist_aarch64.deb` / `.sha256` (plus the `build-v3.66.0` source-build release).
3. Developer platform → version `3.66.0-2`; the 2026-11-24 review only names **aarch64**
   (the x86_64 record for `3.66.0-1` is already published), so this round resubmits
   `aarch64` only. In the submission
   remarks link the privacy policy
   (<https://github.com/Moechz/alist/blob/main/PRIVACY.md>) and state the
   publisher/maintainer identity (Moechz).

## Limitations

- The web UI is served through the TOS web server; exposing the NAS to the internet still
  requires a TLS reverse proxy and a strong administrator password.
- Video thumbnails and some previews need `ffmpeg` (recommended, not bundled).
- The data folder `/var/lib/alist` is not visible in the TOS File Manager; back it up over
  SSH/SFTP or with a TOS backup task.
- Uninstalling deletes the database and the credentials in it — export a backup first.

## Support

- Issues and questions: <https://github.com/Moechz/alist/issues>
- E-mail: **moechz@163.com**
- Privacy: [PRIVACY.md](PRIVACY.md) · Licences: [NOTICE.md](NOTICE.md)
