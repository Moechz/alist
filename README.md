# AList for TOS 7（TerraMaster 应用中心封装）

[AList](https://github.com/AlistGo/alist) 是一款多网盘聚合 / 文件列表程序（Go + 内嵌前端，AGPL-3.0）：
把本地目录、WebDAV、S3 兼容存储与数十种网盘聚合到一个网页界面，支持预览、上传下载、
分享链接、离线下载，并内置 WebDAV 服务。本项目把它封装成 TerraMaster TOS 7 应用中心
规范的 deb 包。

## 架构

| 项 | 值 |
|---|---|
| 打开方式 | 新标签页（External Open），TOS 路由 `/alist/` |
| 后端监听 | `127.0.0.1:15244`（仅回环，无对外端口） |
| 反代 | TOS nginx 前缀保留转发（AList 以 `site_url=/alist` 原生跑子路径） |
| 运行身份 | 专用非特权用户 `alist`，systemd 沙箱加固 |
| 数据目录 | `/var/lib/alist`（数据库/配置/索引/日志；remove 保留、purge 删除） |
| 初始密码 | 安装时自动生成，仅存 `/var/lib/alist/admin_password.txt`（root 0600；审核 F10 要求，不进日志） |
| WebDAV | `http://<NAS>:8181/alist/dav/` |
| 依赖 | 零运行时依赖（Go 静态二进制；`Recommends: ffmpeg` 增强） |

## 构建与产物

```bash
make check          # 语法 + 资产静态自检
./build.sh          # x86_64（amd64）全流程构建
make arm64          # aarch64 构建
```

产物（`out/`）：

- `alist_<版本>_<arch>.deb` — 本地 apt 安装/测试
- `alist_{x86_64,aarch64}.deb` + `.sha256` — 应用中心上架资产（Release tag = `v<完整版本>`）

上游 Release 资产做 md5 + sha256 双重校验（md5 对照官方 `md5.txt`，sha256 对照 `config.env` 内 pin 值）。

## 首次使用

1. TOS 桌面 → AList 图标（新标签页打开 `http://<NAS>:8181/alist/`）
2. 读取初始管理员密码（NAS 管理员 SSH）：`cat /var/lib/alist/admin_password.txt`
3. 登录（用户名 `admin`），立即在后台修改密码
4. 后台「存储」添加网盘/本地路径；本地存储可直接填 TOS 共享文件夹路径

常用运维：

```bash
systemctl restart alist                 # 改配置后重启
vi /usr/local/alist/alist.env           # 端口/数据库/FTP 等覆盖项（环境变量 > config.json）
journalctl -u alist -n 50 --no-pager    # 排障
tail -50 /var/lib/alist/log/log.log
```

## 文档

- `docs/DESIGN_DECISIONS.md` — 设计决策台账
- `docs/CHANGELOG.md` — 版本历史

## 许可

上游 AList 采用 AGPL-3.0（随包附于 `/usr/share/doc/alist/copyright`）。
本项目封装脚本与资产无额外授权要求。
