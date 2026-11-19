# Privacy Policy — AList File Manager for TerraMaster TOS (`alist`)

**Last updated:** 19 November 2026
**Version:** 3.66.0 · **Publisher / data controller:** Moechz — moechz@163.com

This policy covers the TOS 7 application package `alist` (the “app”), its packaging and the
AList instance it runs on your TerraMaster NAS. The same policy ships inside the package as
`/usr/local/alist/privacy-policy.html` and is served by the app at
`/alist/privacy-policy.html`.

## 1. Summary

- The app runs **entirely on your NAS**. The developer does not receive, collect or have
  access to any data it processes.
- **No telemetry, no analytics, no tracking, no advertising SDK, no crash reporting** and no
  update check that runs by itself. The developer operates no server in this path.
- The only network traffic is your browser through the TOS web server, and the requests the
  storage backends make **because you configured them** (§7).

## 2. What data is processed and where it is stored

| Data | Location | Purpose |
|---|---|---|
| User accounts (usernames, hashed passwords, preferences) | `/var/lib/alist/data.db` | Local login and per-user settings |
| Storage credentials you configure (OAuth/refresh tokens, access keys, WebDAV/S3/FTP passwords) | `/var/lib/alist/data.db` | Connect the storages you add; never uploaded to the publisher |
| Initial administrator password | `/var/lib/alist/admin_password.txt` (root-only, 0600) | One-time first-login credential; delete after changing |
| Server configuration | `/var/lib/alist/config.json` (0640), `/usr/local/alist/alist.env` | Listen address, port, database, optional FTP/SFTP/S3 |
| Search index, temporary files, logs | `/var/lib/alist/` | Local search, upload staging, troubleshooting |
| Share links served by the app | generated from `/var/lib/alist/data.db` | Files you deliberately publish from your own NAS |
| Your files | the storages you connect | The content you manage; not copied anywhere by the app |

Nothing is uploaded to the publisher or to an intermediary.

## 3. Retention period

- **No automatic expiry.** Database, configuration, search index and logs stay in
  `/var/lib/alist` until you delete them or uninstall the app.
- **Uninstalling deletes the data.** Uninstalling (App Center “Uninstall”, `apt remove`,
  `dpkg --remove`) removes `/var/lib/alist` completely, because the TOS package specification
  requires an uninstall to leave no residual configuration or data. **Back up
  `/var/lib/alist` first** if you want to keep your library.
- **Upgrading keeps the data.** A new version only stops and restarts the service; the
  database is preserved and migrated in place.
- **Initial password file** — kept until you delete it or uninstall; root-readable only (0600).
- **Logs** — service output goes to the system journal (its rotation is managed by the NAS).
  The maintenance log `/var/log/alist-maint.log` records install/uninstall steps and is
  removed on uninstall.
- **Website (moechz.com)** — unrelated to this app; see
  <https://www.moechz.com/privacy.html>.

## 4. Your rights

| Right | How |
|---|---|
| Access / export | Log in to the web UI, copy `/var/lib/alist` as the NAS administrator, or use AList's API/WebDAV paths |
| Correct | Change settings in the web UI, or edit `/usr/local/alist/alist.env` and restart the service |
| Delete | Delete accounts/storages/share links in the UI; uninstall (§5); or `rm -rf /var/lib/alist` |
| Restrict | Per-storage visibility and per-user permissions; the guest account is disabled by default; the backend listens on loopback only |

## 5. Deletion channel

- **Self-service (immediate)** — App Center “Uninstall” or `dpkg --remove alist` deletes the
  database, configuration, password file, logs, service registration, nginx route and the
  dedicated user. Removing `/var/lib/alist` deletes the data without uninstalling.
- **E-mail** — **moechz@163.com** (subject “AList data request”) for questions or requests
  about the package, the listing or the publishing records; a reply follows within 30 days.
  The developer holds no copy of your data, so deleting it on your NAS is complete by itself.
- **Issues** — <https://github.com/Moechz/alist/issues>.

## 6. Security measures

- Service runs as the dedicated unprivileged system user `alist` (no shell, no home
  directory), never as root.
- systemd sandbox: `NoNewPrivileges=true`, `ProtectSystem=strict`, `ProtectHome=true`,
  `PrivateTmp=true`, kernel tunables/modules/logs protection, `ProtectControlGroups`,
  `ProtectClock`, `ProtectHostname`, `ReadWritePaths=/var/lib/alist`, `UMask=0027`,
  `LimitNOFILE=65536`.
- The backend listens on **127.0.0.1 only** — no port is exposed to the LAN; access goes
  through the TOS web server route `/alist/`, which carries the platform's authentication and
  TLS.
- Credential files are minimal: `config.json` 0640, `admin_password.txt` 0600 root-only;
  package files are not world-writable.
- Passwords are stored as hashes; share links use random tokens and can be revoked.
- If you enable FTP/SFTP/S3 listeners in `alist.env`, their credentials, ports and firewall
  rules are your responsibility.

## 7. Third-party network access and API disclosure

Requests are made **only for operations you initiate**. Each storage backend sends the
credentials you entered and the file operations you perform directly from your NAS to the
provider you chose.

| Storage / feature you enable | Endpoint called (host examples) | Data sent | Destination / region |
|---|---|---|---|
| Aliyun Drive | `api.alipan.com`, `openapi.alipan.com` | OAuth token, file list/read/write | Alibaba Cloud, mainland China |
| Baidu Netdisk | `pan.baidu.com`, `photo.baidu.com` | access token, file operations | Baidu, mainland China |
| China Mobile Cloud (139), 189 Cloud, 123Pan, 115, Xunlei, Tencent Cloud disk | `mopan.sc.189.cn`, `api.cloud.189.cn`, `yun.123pan.com`, `proapi.115.com`, `api-pan.xunlei.com`, `api.vs.tencent.com` | credentials you enter, file metadata and transfers | the respective provider, mainland China |
| OneDrive / SharePoint | `graph.microsoft.com`, `login.microsoftonline.com` | OAuth token, file operations | Microsoft, region of your tenant |
| Google Drive / Photos | `www.googleapis.com`, `photoslibrary.googleapis.com` | OAuth token, file operations | Google, global (US/EU) |
| Dropbox / pCloud / other drives | `api.dropboxapi.com`, `my.pcloud.com`, … | credentials, file operations | the provider (EU/US, per its policy) |
| S3-compatible storage / Azure Blob | the endpoint you configure, e.g. `s3.amazonaws.com`, `<account>.blob.core.windows.net` | access key/secret, object operations | the region/account you configure |
| WebDAV / FTP / SFTP server you add | the address you enter (normally your LAN) | username/password, file operations | that server |
| Offline download, link preview, remote upload by URL | the URL you submit | an HTTP request for that URL; the target sees your NAS IP | the target you chose |
| Update check (administrator only, manual) | `api.github.com`, `github.com` (optionally a proxy you configure: `gh-proxy.com`, `ghproxy.net`) | a version query — no personal data | GitHub, US (or your proxy) |
| ffmpeg previews / thumbnails (optional, local) | no network access | — | your NAS |

Disable or remove a storage/integration in the web UI and it stops being called. Nothing else
in this package contacts the network on its own.

## 8. Accounts and children

The app has a purely local account system (administrator plus optional users; guest account
disabled by default). It is a self-hosted utility, not directed at children, and does not
knowingly process children's data.

## 9. Changes and contact

Material changes are published in this file and in the package copy, and are reflected in the
“Last updated” date. Contact: **moechz@163.com** · Publisher: Moechz · Upstream project:
<https://github.com/AlistGo/alist> (AGPL-3.0).
