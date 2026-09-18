# Design decisions

## 反代与打开方式

### D-001: 打开方式采用新标签页（External Open）
**Decision:** config.ini 用 `open_path: true` + `path: /alist/`，不含 `type` 字段。
**Consequences:**
- 全页运行零适配，规避 iframe 的 X-Frame-Options/高度/子路径三重坑
- `recommend` 提交商店前必须 `false`（过审后可改）
- 参考实现 beszel/navidrome（同一模式真机验证过）

### D-002: nginx 前缀保留转发（不剥离 /alist/ 前缀）
**Decision:** `location /alist/ { proxy_pass http://127.0.0.1:15244/alist/; }`，AList 以 `site_url=/alist` 原生运行在子路径。
**Consequences:**
- AList 服务端把全部路由挂在 `conf.URL.Path`（来自 site_url）下，前端经 `base_path` 注入自适应（源码 server/router.go `e.Group(conf.URL.Path)` + server/static/config.go；macOS 本地 darwin 二进制实测：`/alist/ping`→pong、`/`→302→`/alist`、index.html 注入 `base_path: '/alist'`）
- 排除方案：官方默认的尾斜杠剥离模式（`proxy_pass ...:15244/`）——AList 前端为绝对路径 SPA，剥离前缀后刷新即 404
- 同模式先例：navidrome（--baseurl）、metube
- 代价：用户改前缀需同时改 nginx conf 与 alist.env（ALIST_SITE_URL），文档已注明

### D-004: site_url 只写路径（"/alist"），不写 scheme://host
**Decision:** postinst 预置 config.json 时 `site_url` 仅含路径部分。
**Consequences:**
- initURL 对无 `://` 的值按路径处理（FixAndCleanPath），路由前缀与 base_path 正常工作
- 避免打包期写死 IP/端口导致的错误绝对 URL（坑 14 变体；AList 生成分享等绝对 URL 时按请求 Host 拼接，nginx 侧已传 `$http_host` 含端口）

## 监听与配置安全

### D-003: 监听安全采用「env 活动默认值 + config.json 预置」双保险
**Decision:** alist.env 随包携带**活动**（非注释）默认值 `ALIST_ADDR=127.0.0.1` / `ALIST_HTTP_PORT=15244` / `ALIST_SITE_URL=/alist`；postinst 首装同时预置含相同安全值的 config.json。
**Consequences:**
- AList 没有 CLI 层面的地址/端口参数（仅配置文件+环境变量），无法像 navidrome 那样写死在 ExecStart
- 优先级 环境变量 > config.json > 内置默认：用户改端口编辑 alist.env 即可；误删任一层，另一层仍保证回环监听，不会退化为 0.0.0.0:5244 外泄
- 剩余风险：两层同时被删才会外泄（用户显式行为），接受
- postinst 只在 config.json 不存在时预置（升级永不覆盖用户配置，坑 2 精神）

### D-005: 初始密码采用安装期预置 + root-0600 文件（F10 审核定案，含一次决策反转）
**Decision:** postinst 首装（data.db 与密码文件均不存在）时生成 16 位随机密码，`alist admin set --data` 一次性建库+建号+设密；密码仅写 `/var/lib/alist/admin_password.txt`（root 0600）。
**Consequences:**
- 安装期已建号 → 服务首启不触发上游 initial password 日志打印，journal 无密码明文（F10 要求；真机验证）
- **决策反转记录**：3.64.0-1 曾应“贴近官方设计”改为上游默认（首启打日志），首次提审被 F10 驳回（“日志不得含敏感数据”）；审核员指名修法即本方案。教训：**上游默认行为与平台规范冲突时，平台规范优先**
- 密码不进维护日志/dpkg 输出（0644 面）；忘记密码用 `runuser -u alist -- /usr/local/alist/bin/alist admin set --data /var/lib/alist '新密码'` 重置

## 打包与分发

### D-011: 二进制源码可审计构建（V6 一票否决项的修复）
**Decision:** 不再分发上游官方预编译二进制；本仓库 `.github/workflows/build-upstream.yml` 从上游 tag 源码构建静态 musl 双架构产物（前端用 alist-web 官方 dist），发布于 Release `build-v<上游版本>`；本地 build.sh fetch 改拉自建产物，sha256 双重校验（CI SHA256SUMS + config.env pin）。
**Consequences:**
- 审计链公开闭环：上游源码 tag → workflow 文件 → Actions 运行日志 → Release 资产 + SHA256SUMS
- 全静态 musl（比官方 arm64 的 glibc 动态更稳）；不跑 UPX → 完整 section header，消除“加壳黑盒”观感（官方 amd64 被 UPX 压过，正是首次被拒的观感问题之一）
- verify 新增断言：静态链接 + 无 "no section header"（防回退到预编译二进制）
- 代价：CI 重建产物后必须同步 config.env 两个 pin（built_at 时间戳使哈希不可复现）；上游升级时 workflow 需手动触发
- 前端审计链弱一环（alist-web 官方 dist 为预构建）：接受，workflow 记录其 tag 与哈希

### D-012: 隐私政策双语 + 双落盘（C3 修复）
**Decision:** assets/privacy-policy.html（英文在前中文在后），打包至 /usr/local/alist/，nginx 精确 location 提供 /alist/privacy-policy.html（200 实测）。
**Consequences:**
- 提审表单可直接填公开仓库 URL；包内静态文件不依赖外网
- 精确匹配 location 优先于前缀反代，无冲突

### D-013: webui.bz2 归档归一化 root:root（S11 修复）
**Decision:** build.sh 用 python3 tarfile 重打 webui.bz2（uid/gid=0、uname=root、mtime=0），verify 断言全部条目属主为 0。
**Consequences:**
- macOS bsdtar 无 GNU tar 的 --owner 参数，嵌套归档会带打包机 uid 501；python3 方案跨平台
- deb 主归档由 makedeb.sh 的 root:root 参数保证，本修复覆盖唯一的漏洞（嵌套 webui.bz2）

### D-006: 版本 3.64.0-2；本地/上架双命名产物
**Decision:** 完整版本 = `上游版本-迭代号`；本地测试 deb `alist_3.64.0-1_amd64.deb`，上架资产 `alist_{x86_64,aarch64}.deb`（+ .sha256），Release tag `v3.64.0-1`。
**Consequences:**
- 迭代号永不零填充（dpkg 认为 -01 == -1）
- App Center 手动安装页的文件名禁 amd64/arm64 字样（hermes 实锤）；deb 内 Architecture 仍用 Debian 名
- 每次提交商店必须严格递增迭代号

### D-007: 上游资产 md5+sha256 双重校验（config.env pin sha256）
**Decision:** fetch 阶段 md5 对照官方 `md5.txt`，sha256 对照 config.env 中 pin 的值；升级上游版本必须同步更新 pin。
**Consequences:**
- AList 官方 Release 不发 sha256 文件（仅 md5.txt），md5 抗碰撞强度不足，故额外 pin sha256
- tarball 资产名不带版本号（`alist-linux-<arch>.tar.gz`，坑 7 同类怪癖），fetch 逻辑已适配
- 上游若同 tag 重发资产，构建会因 pin 不符而失败（预期行为，需人工确认后更新 pin）

### D-008: 语言文件采用真机 14 语言口径
**Decision:** alist.lang 覆盖 zh-cn/zh-hk/en-us/fr-fr/de-de/it-it/es-es/hu-hu/ja-jp/ko-kr/pl-pl/ru-ru/tr-tr/pt-pt 十四节。
**Consequences:**
- 真机口径含 hu-hu（官方英文文档口径不同，见指南 §二）；navidrome/beszel 同集合真机通过
- 未采用 23 语超集（hermes 方案）：当前阶段以本地/真机校验为准，送审前若被驳再补
- 显示名 "AList File Manager"（完整描述性名称，防与商店同名应用冲突，坑 12）

### D-009: 类目 Utilities；Recommends ffmpeg
**Decision:** config.ini `category: ["Utilities"]`；deb `Depends: systemd` + `Recommends: ffmpeg`。
**Consequences:**
- 文件管理工具归 Utilities（官方 10 类之一）；不选 Web_Services（偏自建 web 服务端语义）
- ffmpeg 非硬依赖：AList 核心功能不依赖（仅缩略图/预览增强），缺失不阻塞安装
- 描述中不出现 Docker 字样（指南坑 11 疑点存档）

### D-010: purge 补清 postinst 派生文件（真机发现的缺陷修复）
**Decision:** postrm purge 分支同时删除 `/usr/local/alist/index.html` 与 `/usr/local/alist/alist.env`。
**Consequences:**
- 真机首版验证发现 purge 后 `/usr/local/alist/alist.env` 残留（属主悬空为已删用户 uid）
- 修复后真机复验：install→purge 全路径零残留
