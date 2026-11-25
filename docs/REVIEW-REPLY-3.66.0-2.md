# Reply to the listing review — AList File Manager `3.66.0-2` (aarch64)

> Answers the on-hold report of **2026-11-24** for `alist 3.66.0-1` (aarch64, package
> SHA-256 `a31c01afac4c94aa7084d6249cfdc1df3b5cad562c9bb5dc3605ec4a3e7754ff`).
> Use as the submission remarks (“Rectified per review comments”) and as the reply to the
> review e-mail.
>
> The report names **aarch64**; `3.66.0-1` had been submitted for both architectures and the
> **x86_64** record was already **published**. That published x86_64 build ships the very same
> `postinst`, so it carries the same F1 install defect (bare `install` under App Center's
> minimal PATH). We therefore withdrew the aarch64 `3.66.0-1` and submitted **`3.66.0-2` for
> both architectures**: aarch64 (withdrawn first, as requested) and x86_64 (submitted as a new
> version on top of the published listing — the published `3.66.0-1` stays downloadable until
> `3.66.0-2` is approved).

Dear TerraMaster App Review Team,

Thank you for the report. It contained two CODE items (**C9**, **T1**) and, in the body, two
blocking findings that were not in the CODE list: the App Center online installation failing
because the post-install script stops early (**F1**), and non-minimised file permissions
(**S11**). All four are addressed in `3.66.0-2`. Both root causes were real and reproducible.

## C9 — Description inconsistent with the delivered functionality

The store parsed our description as:

```
"AList is a self-hosted file list program that aggregates many storage backends — local
folders, WebDAV, S3-compatible storage and dozens of cloud drives — behind one clean web UI.
… First login: username 'admin
```

It stopped mid-sentence and kept the opening quote. Root cause: `app.lang` used **ASCII
semicolons** (`;`) inside the quoted values. The App Center language parser treats `;` as the
start of an INI comment, so everything after it (including the closing quote and the login
instructions) was discarded. The same defect affected `release_note` and `important` in
14 languages; the Turkish `descript` started with `AList;` and was therefore cut to `AList`.

Fix: all ASCII semicolons were removed from every value of all 14 language sections (full-width
「；」 or full stops/commas where a separator is needed). The description was also rewritten to
match exactly what the package delivers:

- aggregates local folders, WebDAV, S3-compatible object storage and dozens of cloud drives in
  one web UI;
- browse, preview, upload, download, share links, offline-download tasks;
- built-in WebDAV server (`/alist/dav/`) so any client can mount every storage as one drive;
- opens in a new browser tab through the TOS route, backend on loopback only, dedicated
  non-root user in a systemd sandbox;
- **video thumbnails and some previews require the optional `ffmpeg` package** (declared as
  `Recommends`, not bundled) — stated explicitly so the description does not over-promise;
- first login `admin`, password generated at install time and stored root-readable in
  `/var/lib/alist/admin_password.txt`.

Verification: `grep -c ';'` over the packaged `alist.lang` returns **0** (build gate `C9` fails
the package if any ASCII semicolon comes back).

## F1 — App Center installation failed, the service was never registered

Confirmed and fixed. The package installed its files, but `postinst` aborted before step 8
(systemd registration). `postinst` began with `set -e` and then called the coreutils helper
`install` by bare name:

```
install -m 0640 -o alist -g alist "$APP_DIR/alist.env.example" "$APP_DIR/alist.env"
```

App Center invokes maintainer scripts with a minimal (sometimes empty) `PATH`, so `install`
was not found. With `set -e` the script exited at that line, `systemctl enable/start alist`
was never reached, and dpkg left the package unconfigured → “installation completes but the
application cannot start / stop failed”. Reproduced under `env -i PATH=`: the old script exits
**127** at `line 52: install: No such file or directory`.

Fix, as the report suggested, `install` is now called by absolute path and the environment is
made deterministic:

1. `export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin` at the top of
   `postinst`, `preinst`, `prerm` and `postrm`;
2. `/usr/bin/install` is resolved explicitly (`INSTALL_BIN`, falls back to `command -v install`)
   and used through the `copy_file` / `make_data_dir` helpers, which also work without
   `install` (plain `cp`/`chmod`);
3. every optional step (`useradd`, `chown`, webui extraction, env bootstrap, data dir, the
   `alist admin set` bootstrap) now ends in `|| warn` and can no longer abort the install;
4. the systemd unit copy + `daemon-reload` + `enable` + `start` runs after those guarded steps
   and is itself guarded, so the service is always registered;
5. if `config.json` cannot be written, the script still registers the service but **does not
   start it**, so a broken environment can never expose AList’s upstream default `0.0.0.0:5244`;
6. the script ends with `exit 0` once configuration is done, so App Center sees a configured
   package even when a non-fatal warning was logged (the warning text is in
   `/var/log/alist-maint.log` and on the dpkg output).

Verification in this release (no root shell on the build host, so the script logic was exercised
with its paths rewritten into a sandbox and `PATH` emptied):

| Run | Result |
|---|---|
| old `postinst`, `env -i PATH=` | exits 127 at the bare `install` call (reproduces F1) |
| new `postinst`, `env -i PATH=` | resolves `/usr/bin/install`, every non-fatal step warns, reaches step 8, prints the install summary, **exit 0** |
| new `postinst` sandbox run, resulting modes | data dir `0750`, `config.json` `0640`, `alist.env` `0640`, unit `0644`, maintenance log `0600` |
| maintenance log after the run | contains no password material (`grep -ci password` → 0) |

## S11 — File permissions not minimised

- All four maintainer scripts now set `umask 027`.
- The maintenance log `/var/log/alist-maint.log` is explicitly `chmod 0600` **after** it is
  created. The previous version ran `chmod` before the first write, so the file was actually
  created `0644` and was readable by any local user — that was the real finding.
- Runtime credentials are minimised in `postinst`: `/var/lib/alist` `0750`,
  `config.json` `0640`, `admin_password.txt` `root:root 0600`; the upgrade path re-applies the
  same modes and never widens them.
- The service still runs as the dedicated non-root user `alist` under the systemd sandbox
  (`NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`, `UMask=0027`, …), never as root.
- The package itself keeps public files `0644`, `bin/alist` `0755`, directories `0755`, and the
  build gate still fails on any world-writable file.

## T1 — High or critical CVE

The requested check was done: **AList v3.66.0 (2026-10-21) is still the latest upstream
release** — `AlistGo/alist` has no newer release or tag as of 2026-11-25, so there is no newer
upstream to upgrade to in this round. The shipped binary is not a prebuilt download: this
repository’s public CI (`.github/workflows/build-upstream.yml`) builds it from the upstream
`v3.66.0` source tag with Go 1.25 (`check-latest: true`, static musl, no UPX), so the Go
toolchain, standard library, embedded front-end assets and musl base are all rebuilt at build
time. The exact build is attached to the `build-v3.66.0` release with `SHA256SUMS`.

Follow-up plan (also recorded in `docs/CHANGELOG.md`):

- upgrade within 7 days of any new upstream AList release;
- after every Go security release, re-run the workflow and update the two tarball `sha256`
  pins in `config.env` (the build fails if the pin and CI output differ);
- the vulnerability scan report was mentioned as attached but was not part of the e-mail body
  we received. Please send the affected component/CVE identifiers and we will evaluate them
  explicitly and rebuild immediately if any component is ours to upgrade.

## Package details (`3.66.0-2`, both architectures)

- aarch64: `alist_aarch64.deb`, SHA-256
  `0fdb95c2e1f32c758ab44cdd34c0f992274059c32339fdbc97e65af2f49cf0b7`
  (version uuid `a69b7adf-7b39-42df-990d-d612a0b80bad`)
- x86_64: `alist_x86_64.deb`, SHA-256
  `bdc52c8f46aadef9d37b940dac4d3cbc929e2d55e7f92397b52c6c9c0fee12a7`
  (version uuid `97d4ef3f-609e-4d2a-ba3f-f9536e92c632`) — same F1/S11/C9/T1 fixes
- Upstream: AList **v3.66.0** (AGPL-3.0), static binary built from that source tag by this
  repository’s public CI; publisher / Maintainer: **Moechz**
- Route `/alist/` (new tab), backend `127.0.0.1:15244` only, no exposed port
- Data: `/var/lib/alist` (kept and migrated on upgrade, removed on uninstall — back up first)
- Privacy policy: in-package `/usr/local/alist/privacy-policy.html`, served at
  `/alist/privacy-policy.html`, and <https://github.com/Moechz/alist/blob/main/PRIVACY.md>
- Gates: `make check` (syntax + asset self-check, new C9/F1 gates), `./build.sh verify`
  (C9/F1/S11/F11/P1 gates), official `TOSAppSelfTestingTool -c` → `check passed` on both
  `alist_x86_64.deb` and `alist_aarch64.deb`

Kind regards,
Moechz
