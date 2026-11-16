# V6 Exemption Application — Reply Draft (2026-09-20)

> 回复审核邮件用。对应重审结果：3.64.0-2 On Hold (Remediation Required)，仅剩 V6 一项。
> 决策背景见 `docs/TASK_STATE.md` §9 与 `docs/DESIGN_DECISIONS.md` D-014。
> 发送前替换署名；若官方要求附件，附 build-v3.64.0 的 SHA256SUMS 与 `file`/`go version -m` 输出。

---

Subject: Re: AList File Manager (alist 3.64.0-2) — V6 Exemption Application

Dear Review Team,

Thank you for reviewing AList File Manager 3.64.0-2 (SHA-256 f6d5b31349e4859842d504ab183a41efed045fcb3994369408d1ff9ec7c1270f). Regarding the single identified item — [V6] bundled binary executable — we would like to apply for an exemption under Option 1. The flagged ELF (`usr/local/alist/bin/alist`) is the application itself, and we believe the materials below demonstrate both why no reasonable non-binary distribution exists under the current TOS model and that the binary's origin is fully auditable.

## 1. Usage scenario and technical justification

- AList is a compiled Go application (multi-storage aggregation, file management, and a WebDAV server; upstream is open source under AGPL-3.0: https://github.com/AlistGo/alist). A native binary is the only form in which a compiled Go program can run; it cannot be shipped as readable script code the way a Python/JavaScript app can.
- No reasonable non-binary alternative exists on TOS 7:
  1. The TOS 7 base (Ubuntu 22.04) repositories contain no AList package, and upstream publishes no distro packages — only source tags and release binaries.
  2. The store's zero-online-installation rule (S8) prohibits downloading or compiling anything at install time, so "build from source during installation" is not an option.
  3. Bundling a Go toolchain to enable on-device compilation would add a far larger unaudited binary payload (compiler, linker, stdlib archives), which is strictly worse under V6 than a single application binary.
- Importantly, we do **not** distribute upstream prebuilt binaries. The flagged binary is built from the public upstream source tag v3.64.0 by a public GitHub Actions workflow, with every step auditable end-to-end (links in section 4). It is statically linked (musl), not packed (full section headers — verifiable with `file`/`readelf`), and carries upstream version metadata in its Go build info (`go version -m`).

## 2. Least-privilege plan (systemd unit settings)

- `User=alist` / `Group=alist` — dedicated non-privileged system account created at install time (no root, no login shell). **Shipped in 3.64.0-2.**
- `NoNewPrivileges=true`. **Shipped in 3.64.0-2.**
- `CapabilityBoundingSet=` (empty set) — the service requires zero capabilities: it binds only 127.0.0.1:15244 (unprivileged port > 1024) and writes only to /var/lib/alist. This setting is committed to our public repository and ships with the next package revision.
- Already shipped in 3.64.0-2, beyond the four required settings:
  - `ProtectSystem=strict` + `ReadWritePaths=/var/lib/alist` (read-only everywhere except the data directory)
  - `ProtectHome=true`, `PrivateTmp=true`, `UMask=0027`
  - `ProtectKernelTunables/ProtectKernelModules/ProtectKernelLogs/ProtectControlGroups/ProtectClock/ProtectHostname=true`
  - No `Restart=`/`RestartSec=` (service lifecycle is managed exclusively by the App Center, per TOS policy)

## 3. Security hardening measures

- **Audit logs**: all lifecycle scripts log to `/var/log/alist-maint.log` (root, 0600); service output goes to journald; application logs go to `/var/lib/alist/log/`. Credentials never appear in any log — the initial admin password is generated at install time (`alist admin set` with a random value) and stored only in `/var/lib/alist/admin_password.txt` (root:root, 0600). This was our F10 remediation from the first review, re-verified on a real TOS 7 machine (journal contains no password output).
- **Write-path allowlist**: with `ProtectSystem=strict` and `ReadWritePaths=/var/lib/alist`, the process can write only to /var/lib/alist (plus a private tmpfs /tmp). Its binary, unit, and nginx configuration directories are read-only to it.
- **Backup and rollback**: all persistent state (config.json, database, logs) is confined to the single directory `/var/lib/alist` — backing up and restoring that directory fully preserves the application. This was verified on a real TOS 7 machine: upgrade 3.64.0-1 → 3.64.0-2 preserved config/data/password; `apt remove` keeps data; `apt purge` removes everything with zero residue (re-verified).
- **User disable switch**: stopping or uninstalling the app from the TOS App Center stops and disables the service through the package lifecycle scripts (prerm/postrm follow the TOS specification: stop-only on upgrade, stop+disable+clean on removal). Additionally, the backend listens **only on 127.0.0.1:15244** — even while running, it exposes no port to the network. The only user-facing endpoint is the TOS-managed nginx route `/alist/` on port 8181. This loopback-only posture is enforced redundantly (environment defaults in `/usr/local/alist/alist.env` **and** a preseeded `/var/lib/alist/config.json`; removing either layer alone does not expose the port).

## 4. Supporting technical materials / self-assessment evidence

- Public packaging repository (build recipes, scripts, unit, nginx config): https://github.com/Moechz/alist
- Source-build workflow (checks out upstream tag v3.64.0 + official frontend dist, static musl build for amd64 & arm64, no UPX): https://github.com/Moechz/alist/blob/main/.github/workflows/build-upstream.yml
- Public Actions run that produced the shipped binary: https://github.com/Moechz/alist/actions/runs/35313888330
- Binary provenance release with SHA256SUMS: https://github.com/Moechz/alist/releases/tag/build-v3.64.0
- Submitted package release (deb assets + .sha256): https://github.com/Moechz/alist/releases/tag/v3.64.0-2
- Upstream source tag: https://github.com/AlistGo/alist/tree/v3.64.0
- **Identity check**: the package SHA-256 cited in your email (f6d5b31349e4859842d504ab183a41efed045fcb3994369408d1ff9ec7c1270f) matches our published `alist_x86_64.deb`, and the ELF inside it is byte-identical to the `build-v3.64.0` release asset — double-verified at package build time via the release SHA256SUMS plus an independent SHA-256 pin in `config.env`.
- Planned for the next revision (not required for this submission): an in-package provenance file (`/usr/local/alist/PROVENANCE.md` plus machine-readable `BUILD-INFO`) so the full audit chain also travels inside the package.

We are glad to provide any additional material your security specialist may need, or to adjust the unit settings if specific changes are required as a condition of approval.

Best regards,
Moechz
