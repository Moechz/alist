# Changelog

## 3.64.0-2 — 2026-09-19

### Fixed（针对首次提审驳回项 V6/F10/C3/S11）
- **V6（一票否决）**：deb 内二进制改为本仓库 GitHub Actions 从上游 v3.64.0 源码构建（静态 musl 双架构、无 UPX、完整 section header），审计链 = 上游源码 tag → 公开 workflow → Actions 日志 → build-v3.64.0 Release 资产；verify 新增静态链接/未加壳断言，fetch 改拉自建产物并双重 pin 校验
- **F10**：初始管理员密码改为安装期预置（postinst `admin set`），仅存 /var/lib/alist/admin_password.txt（root 0600）；安装期建号后首启无密码日志打印（“官方首启打日志”设计被 F10 驳回，回归打包层方案）
- **C3**：新增双语隐私政策（包内 /usr/local/alist/privacy-policy.html + nginx 路由 /alist/privacy-policy.html，静态可达）
- **S11**：webui.bz2 归档条目归一化为 root:root（python3 tarfile 跨平台重打，摆脱 macOS bsdtar 无 --owner 的限制），verify 新增 uid/gid=0 断言

## 3.64.0-1 — 2026-09-17

### Added
- 首个 TOS 7 应用中心封装：基于 AList v3.64.0 官方二进制（Go 静态编译、前端内嵌、零运行时依赖）
- 新标签页打开模式：经 TOS 路由 `/alist/` 访问，后端仅监听 `127.0.0.1:15244`，不对外开端口
- 子路径原生支持：nginx 前缀保留转发 + `site_url=/alist`（SPA/API/WebDAV/直链全部自洽）
- 首装自动初始化：预置安全 config.json；初始管理员密码采用上游官方设计（首启自动生成随机密码并打印到 journal，`journalctl -u alist | grep -i "initial password"` 获取）
- WebDAV 端点：`http://<NAS>:8181/alist/dav/`；上传不受 nginx 默认 1m 限制（client_max_body_size 0）
- 用户可调配置 `/usr/local/alist/alist.env`（端口/数据库/HTTPS/FTP/SFTP/S3/MCP，环境变量优先于 config.json）
- 14 语言描述文件、systemd 沙箱加固（NoNewPrivileges/ProtectSystem=strict 等）、双落盘注册（init.d+nginx 目录与 /etc 实体）
- 应用概览/重要提示（14 语言）写明初始登录方式：用户名 admin + 密码文件路径 + cat 命令（商店详情页第一屏可见）
- 修复图标资产：官方 logo 首次下载被截断（非法 XML → TOS 桌面渲染灰白占位块），重新拉取完整版并注入 viewBox；自检新增 SVG 合法性断言（XML 可解析 + viewBox + fill/path 完整性）防复发
- 开发者署名归上游：应用中心展示的 publisher/auth 改为 “AList Team”；deb Maintainer 保持打包者（dpkg 语义：包维护人），描述内注明上游作者与打包者分工
- 双架构产物：x86_64 / aarch64（md5+sha256 双重校验官方 tarball）

## 3.66.0-1 — 2026-11-19

### Changed（针对 3.64.0-4 审核报告的 11 项）
- **T1（CVE）**：上游 **3.64.0 → 3.66.0**（当前最新 release，2026-10-21）；二进制仍由本仓库
  公开 CI 从上游 tag 源码构建（静态 musl、无 UPX），`config.env` 的两个 sha256 pin 同步更新。
  审计链：上游 tag v3.66.0 → `.github/workflows/build-upstream.yml` → Actions run → Release `build-v3.66.0`。
- **P1（品牌一致性）**：`config.ini.publisher` 与 `DEBIAN/control.Maintainer` 统一为
  **Moechz**（原 publisher 为 "AList Team"，与 Maintainer 无共同标识）；`Maintainer` 邮箱改为
  可追溯的 `moechz@163.com`。上游作者仍以 lang `auth`="AList Team"、`control` Description 与
  `NOTICE.md` 署名体现。build.sh 新增构建期门禁：publisher 必须等于 Maintainer 且不是占位符。
- **F11（卸载残留）**：`postrm` 改为 `remove` 与 `purge` 都完整清理（数据库/配置/密码文件/日志/
  systemd 单元/nginx 路由/专用用户/维护日志），与官方 Package Specification 生命周期表
  "postrm → Clean up user, data, residual files" 一致；`upgrade|failed-upgrade|…` 路径仍严格保留数据。
  store 文案（14 语 `important`）与 control Description 同步写明「卸载会删除数据，先备份」。
- **S11（权限最小化）**：build.sh 固定 `umask 022` 并在 stage 阶段显式归一化权限
  （公开文件 0644、二进制 0755、目录 0755），新增「包内不得存在任意用户可写文件」门禁；
  运行期凭据仍为 config.json 0640 / admin_password.txt 0600。
- **C4（隐私政策不完整）**：包内 `privacy-policy.html` 重写为中英双语完整政策，显式覆盖
  保留期、用户权利、安全措施、第三方共享/API 披露与删除渠道；仓库 `PRIVACY.md` 同步重写
  （原先误写为 docker 变体的 `/Volume1/DockerAppData/alistdocker` 路径）。
- **C8（未披露第三方 API）**：政策 §7 给出逐项表格（服务商 / 端点主机示例 / 发送的数据 /
  目的地与区域），覆盖阿里云盘、百度网盘、139/189/123/115/迅雷/腾讯、OneDrive、Google Drive、
  Dropbox/pCloud、S3/Azure Blob、WebDAV/FTP/SFTP、离线下载/远程上传、手动更新检查（GitHub），
  并明确默认不主动外连、无遥测。
- **C2（知识产权/许可）**：新增 `LICENSE`（打包部分 MIT）；`NOTICE.md` 重写：AGPL-3.0 上游、
  源码构建链路与 corresponding source 说明、包内组件许可表、商标与图标声明、
  「publisher == Maintainer」责任主体段落。
- **F22（webui.bz2）**：包内已含 `webui.bz2`（占位入口页，uid/gid=0），verify 继续断言；
  本次同时把隐私页置为 0644，避免 TOS nginx 非 root worker 读取时 403。

### Verified
- 官方 `TOSAppSelfTestingTool -c`（stage 目录）通过；`./build.sh verify` 全绿（含新增 P1/S11/F11 门禁）。
- 真机（本机 TOS 7）：`dpkg -i` 安装/升级、`systemctl active+enabled`、非 root 进程、
  仅 127.0.0.1:15244 监听、`/alist/` 200、隐私页 200（含五要素关键词）、WebDAV 401、
  生成密码登录 200、升级保留数据、`dpkg --remove` 后零残留。
