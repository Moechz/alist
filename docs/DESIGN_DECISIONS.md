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

### D-005: 管理员初始化采用上游官方设计（首启随机密码打印到服务日志）【替代首版自创机制】
**Decision:** postinst 不做任何账号/密码干预。首次启动时 AList 自动生成随机初始密码并打印到 stdout（实测不落 log.log），systemd 收入 journal；用户用 `journalctl -u alist | grep -i "initial password"` 获取，登录后修改。
**Consequences:**
- 与上游/Docker 官方体验完全一致（熟悉 AList 的用户零学习成本；官方文档就是这么教的）
- 首版曾用自创机制（postinst 生成 16 位密码 + `alist admin set` 落库 + 写 admin_password.txt 0600）——用户决策"采用原始设计"后废弃，postinst 删掉密码块、14 语言指引改 journalctl 方式、真机 purge 重装复验登录 200
- 遗留风险：journal 轮转后找不到密码（登录后立即修改即可规避；旧密码文件机制无此风险，已接受）
- 忘记密码重置：`runuser -u alist -- /usr/local/alist/bin/alist admin set --data /var/lib/alist '新密码'`

## 打包与分发

### D-006: 版本 3.64.0-1；本地/上架双命名产物
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
