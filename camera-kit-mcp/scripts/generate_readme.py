#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate README.md and refresh manifest.json for the Camera Kit MCP corpus."""
import json
import re
from datetime import datetime, timezone
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
API_DIR = BASE_DIR / "api"
GUIDE_DIR = BASE_DIR / "guides"
README = BASE_DIR / "README.md"
MANIFEST = BASE_DIR / "manifest.json"


def extract_title(path):
    text = path.read_text(encoding="utf-8")
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("# "):
            return line[2:].strip()
    return path.stem


def collect(directory):
    rows = []
    for path in sorted(directory.glob("*.md")):
        title = extract_title(path)
        uri = None
        text = path.read_text(encoding="utf-8")
        m = re.search(r"^> 来源：(.+)$", text, re.MULTILINE)
        if m:
            uri = m.group(1).strip()
        rows.append((path.stem, title, uri, path.name))
    return rows


def markdown_table(rows, subdir):
    lines = ["| 文档 | 标题 | 来源 |", "| --- | --- | --- |"]
    for slug, title, uri, fname in rows:
        rel = f"{subdir}/{fname}"
        lines.append(f"| [{slug}]({rel}) | {title} | {uri or '-'} |")
    return "\n".join(lines)


def main():
    api_rows = collect(API_DIR)
    guide_rows = collect(GUIDE_DIR)

    api_table = markdown_table(api_rows, "api")
    guide_table = markdown_table(guide_rows, "guides")

    now = datetime.now(timezone.utc).isoformat(timespec="seconds")

    readme = f"""# Camera Kit 鸿蒙开发知识库（MCP）

本目录通过鸿蒙开发者知识 MCP 服务（`https://connect-api.cloud.huawei.com/api/developerknowledge/mcp`）抓取并整理了 **Camera Kit（相机服务）** 的 ArkTS 相关知识，便于本地检索、喂给 MCP 客户端或作为开发参考资料。

## 目录结构

```
camera-kit-mcp/
├── api/          # Camera Kit ArkTS API 模块文档（@ohos.multimedia.camera、@ohos.multimedia.cameraPicker 等）
├── guides/       # 开发相机应用必选能力(ArkTS)、开发相机应用基础能力(ArkTS) 各板块指南
├── scripts/      # 抓取与生成脚本（可重新拉取最新文档）
├── manifest.json # 已抓取文档清单
├── mcp.json      # 鸿蒙开发者知识 MCP 远程服务配置（供 MCP 客户端使用）
└── README.md
```

## 快速使用

- 直接阅读 `api/` 与 `guides/` 下的 Markdown 文件。
- 将本目录作为本地知识库接入支持文件/文件夹检索的 MCP 客户端或 RAG 工具。
- 如需重新同步官方最新内容，运行：

```bash
python scripts/fetch_camera_kit.py
python scripts/generate_readme.py
```

## 官方 MCP 服务配置

如需继续使用官方远程 MCP，可将 `mcp.json` 中的配置加入支持 MCP 的 AI 客户端（如 DevEco Studio）。

```json
{{
  "mcpServers": {{
    "harmonyos_developer_knowledge": {{
      "url": "https://connect-api.cloud.huawei.com/api/developerknowledge/mcp",
      "type": "http"
    }}
  }}
}}
```

## 统计

- ArkTS API 文档：{len(api_rows)} 篇
- ArkTS 开发指南：{len(guide_rows)} 篇
- 抓取时间：{now}

## ArkTS API 文档

{api_table}

## 开发相机应用基础能力(ArkTS) 及必选能力指南

{guide_table}
"""
    README.write_text(readme, encoding="utf-8")
    print(f"README written: {README}")

    # Refresh fetched_at in manifest.
    if MANIFEST.exists():
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        manifest["fetched_at"] = now
        MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"Manifest updated: {MANIFEST}")


if __name__ == "__main__":
    main()
