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
