# Changelog

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
