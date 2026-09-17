#!/usr/bin/env python3
"""check_assets.py — 上架前的资产静态自检（Makefile check 调用）

按 TOS 7 应用中心规范校验：
  1. assets/config.ini.in 是合法 JSON（渲染 @@VERSION@@ 等占位符后）
  2. assets/alist.lang 含全部 14 个必需语言节，UTF-8 无 BOM，LF 行尾
  3. assets/ 下所有文本资产无 CRLF / BOM
  4. 图标 SVG 合法：XML 可解析、viewBox 存在、含实际填充色与路径数据
     （曾因下载截断出过灰白占位块图标，此检查防复发）
"""
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
fail = 0

REQUIRED_LANGS = ["zh-cn", "zh-hk", "en-us", "fr-fr", "de-de", "it-it", "es-es",
                  "hu-hu", "ja-jp", "ko-kr", "pl-pl", "ru-ru", "tr-tr", "pt-pt"]

# ---------- 1. config.ini.in ----------
raw = (ROOT / "assets/config.ini.in").read_text(encoding="utf-8")
rendered = (raw.replace("@@VERSION@@", "0.0.0")
              .replace("@@PUBLISHER@@", "x")
              .replace("@@PLATFORM@@", "x86_64"))
try:
    json.loads(rendered)
    print("config.ini.in: JSON 合法 ✓")
except Exception as e:  # noqa: BLE001
    print(f"config.ini.in: JSON 非法 ✗ ({e})")
    fail = 1

# ---------- 2. lang ----------
lang_path = ROOT / "assets/alist.lang"
data = lang_path.read_bytes()
if data.startswith(b"\xef\xbb\xbf"):
    print("lang: 含 BOM ✗")
    fail = 1
text = data.decode("utf-8")
found = re.findall(r"^\[([a-z]{2}-[a-z]{2})\]$", text, re.M)
missing = [t for t in REQUIRED_LANGS if t not in found]
if missing:
    print(f"lang: 缺少语言节 ✗ {missing}")
    fail = 1
else:
    print(f"lang: 14 语言齐全 ✓（共 {len(found)} 节）")

# ---------- 3. CRLF / BOM 扫描 ----------
for p in sorted((ROOT / "assets").rglob("*")):
    if not p.is_file() or p.suffix not in {".ini", ".in", ".lang", ".conf",
                                           ".service", ".env", ".sh", ".html",
                                           ".svg"}:
        continue
    b = p.read_bytes()
    rel = p.relative_to(ROOT)
    if b.startswith(b"\xef\xbb\xbf"):
        print(f"{rel}: 含 BOM ✗")
        fail = 1
    if b"\r\n" in b or b"\r" in b:
        print(f"{rel}: 含 CR ✗")
        fail = 1
print("CRLF/BOM 扫描: 完成 ✓" if fail == 0 else "CRLF/BOM 扫描: 有问题（见上）")

# ---------- 4. 图标 SVG 合法性 ----------
icon_path = ROOT / "assets/images/icons/alist.svg"
try:
    icon_text = icon_path.read_text(encoding="utf-8")
    root = ET.fromstring(icon_text)
    if "viewBox" not in root.attrib:
        print("icon: 根元素缺 viewBox ✗")
        fail = 1
    fills = re.findall(r'fill="#([0-9a-fA-F]{3,8})"', icon_text)
    paths = [p for p in root.iter() if p.tag.endswith("path")]
    if not fills:
        print("icon: 无任何 fill 填充色 ✗")
        fail = 1
    if any(len((p.get("d") or "")) < 100 for p in paths) or not paths:
        print("icon: path 数据缺失或过短（疑似截断）✗")
        fail = 1
    if fail == 0:
        print(f"icon: XML 合法 + viewBox + {len(paths)} path/{len(set(fills))} 色 ✓")
except ET.ParseError as e:
    print(f"icon: SVG 非法 XML（截断/损坏）✗ ({e})")
    fail = 1

sys.exit(fail)
