#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fetch Camera Kit ArkTS API and ArkTS guide docs from Huawei Developer Knowledge MCP.

The script reads the official Camera Kit index documents through the MCP,
collects all linked ArkTS API and ArkTS guide document IDs, then downloads the
full Markdown content and saves it under ../api and ../guides.
"""
import json
import os
import re
import sys
import urllib.request
import ssl
from pathlib import Path

MCP_URL = "https://connect-api.cloud.huawei.com/api/developerknowledge/mcp"
ctx = ssl.create_default_context()

BASE_DIR = Path(__file__).resolve().parent.parent
API_DIR = BASE_DIR / "api"
GUIDE_DIR = BASE_DIR / "guides"
SCRIPT_DIR = BASE_DIR / "scripts"

INDEX_DOCS = [
    # API indexes
    "document/cn/harmonyos-references/camera-arkts",
    "document/cn/harmonyos-references/camera-api",
    "document/cn/harmonyos-references/js-apis-camera",
    # Guide indexes
    "document/cn/harmonyos-guides/camera-dev-arkts",
    "document/cn/harmonyos-guides/camera-dev-arkts-mandatory",
    "document/cn/harmonyos-guides/camera-kit",
]

# Docs that are explicitly part of the ArkTS API set but may not be linked by js-apis-camera.
EXTRA_API_DOCS = [
    "document/cn/harmonyos-references/js-apis-camerapicker",
    "document/cn/harmonyos-references/camera-arkts-errcode",
]

# Additional Camera Kit guide pages that are reachable from FAQ/index pages.
EXTRA_GUIDE_DOCS = [
    "document/cn/harmonyos-guides/camera-api-faq",
    "document/cn/harmonyos-guides/camera-previewoutput-faq",
    "document/cn/harmonyos-guides/camera-sessionconfig-faq",
    "document/cn/harmonyos-guides/camera-dev-faq-start",
    "document/cn/harmonyos-guides/camera-rotation-angle-adaptation",
    "document/cn/harmonyos-guides/camera-rotation-term",
    "document/cn/harmonyos-guides/camera-rotation-faq",
    "document/cn/harmonyos-guides/camera-whitebalance-faq",
]

# Native / C API docs to exclude because this corpus is ArkTS focused.
EXCLUDE_API_PREFIXES = [
    "document/cn/harmonyos-references/camera-c",
    "document/cn/harmonyos-references/capi-",
]

# Native / non-ArkTS guide docs to exclude.
EXCLUDE_GUIDE_PREFIXES = [
    "document/cn/harmonyos-guides/camera-dev-native",
    "document/cn/harmonyos-guides/camera-dev-native-mandatory",
    "document/cn/harmonyos-guides/camera-rotation-term-native",
    "document/cn/harmonyos-guides/camera-rotation-angle-adaptation-native",
]


def rpc(method, params=None, _id=1):
    payload = {"jsonrpc": "2.0", "id": _id, "method": method, "params": params or {}}
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        MCP_URL,
        data=data,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180, context=ctx) as resp:
        raw = resp.read().decode("utf-8", "replace")
    return json.loads(raw)


def get_documents(names):
    """Call getDocumentsById in batches of 10 and return name->doc."""
    docs = {}
    for i in range(0, len(names), 10):
        batch = names[i:i + 10]
        resp = rpc("tools/call", {
            "name": "getDocumentsById",
            "arguments": {"GetDocumentsByIdRequest": {"names": batch}},
        })
        result = resp.get("result", {})
        if isinstance(result, dict) and "structuredContent" in result:
            items = result["structuredContent"].get("resultList") or []
        elif isinstance(result, dict) and "content" in result:
            items = []
            for c in result["content"]:
                try:
                    obj = json.loads(c.get("text", "{}"))
                except Exception:
                    obj = {}
                items.extend(obj.get("resultList", []))
        else:
            items = []
        for d in items:
            name = d.get("name")
            if name:
                docs[name] = d
        print(f"Fetched batch {i // 10 + 1}/{(len(names) + 9) // 10}: {len(items)} docs", flush=True)
    return docs


def extract_doc_links(content):
    """Extract developer.huawei.com document paths from Markdown content."""
    pattern = re.compile(
        r"https://developer\.huawei\.com/consumer/cn/doc/([a-zA-Z0-9\-_]+)/([a-zA-Z0-9\-_]+)"
    )
    links = set()
    for m in pattern.finditer(content or ""):
        links.add(f"document/cn/{m.group(1)}/{m.group(2)}")
    return links


def is_api(name):
    return name.startswith("document/cn/harmonyos-references/")


def is_guide(name):
    return name.startswith("document/cn/harmonyos-guides/")


def should_include_api(name):
    if not is_api(name):
        return False
    if any(name.startswith(p) for p in EXCLUDE_API_PREFIXES):
        return False
    # Keep only camera-related reference docs.
    return "camera" in name.lower() or "camerapicker" in name.lower()


def should_include_guide(name):
    if not is_guide(name):
        return False
    if any(name.startswith(p) for p in EXCLUDE_GUIDE_PREFIXES):
        return False
    return "camera" in name.lower()


def save_doc(doc, subdir):
    name = doc.get("name", "")
    slug = name.rstrip("/").split("/")[-1]
    title = doc.get("title", "")
    uri = doc.get("uri", "")
    content = doc.get("content", "")
    if not content:
        return None
    file_path = subdir / f"{slug}.md"
    header = []
    if title:
        header.append(f"> 标题：{title}")
    if uri:
        header.append(f"> 来源：{uri}")
    header.append(f"> 文档ID：{name}")
    header.append("")
    text = "\n".join(header) + "\n" + content.strip() + "\n"
    file_path.write_text(text, encoding="utf-8")
    return file_path


def main():
    print("Fetching index documents...", flush=True)
    index_docs = get_documents(INDEX_DOCS)
    if not index_docs:
        print("ERROR: no index docs returned", flush=True)
        sys.exit(1)

    api_names = set(EXTRA_API_DOCS)
    guide_names = set()

    for doc in index_docs.values():
        content = doc.get("content", "")
        for link in extract_doc_links(content):
            if should_include_api(link):
                api_names.add(link)
            elif should_include_guide(link):
                guide_names.add(link)

    # Always include the index docs themselves where relevant.
    for name in INDEX_DOCS:
        if should_include_api(name):
            api_names.add(name)
        elif should_include_guide(name):
            guide_names.add(name)

    # Add camera-overview, camera-preparation, FAQ and index sub-pages explicitly;
    # they are useful context and appear in the Camera Kit top-level guide index.
    for extra in [
        "document/cn/harmonyos-guides/camera-overview",
        "document/cn/harmonyos-guides/camera-preparation",
        "document/cn/harmonyos-guides/camera-dev-faq",
    ] + EXTRA_GUIDE_DOCS:
        if should_include_guide(extra):
            guide_names.add(extra)

    API_DIR.mkdir(parents=True, exist_ok=True)
    GUIDE_DIR.mkdir(parents=True, exist_ok=True)

    # First pass: fetch all known Camera Kit docs.
    initial_names = sorted(api_names | guide_names)
    print(f"First pass docs to fetch: {len(initial_names)}", flush=True)
    all_docs = get_documents(initial_names)

    # Second pass: some Camera Kit docs are index pages (e.g. camera-rotation,
    # camera-dev-faq, camera-arkts-errcode) that link to additional Camera Kit docs.
    # Follow those links once so the local corpus contains the actual section pages too.
    new_api = set()
    new_guide = set()
    for doc in all_docs.values():
        content = doc.get("content", "")
        for link in extract_doc_links(content):
            if should_include_api(link) and link not in all_docs:
                new_api.add(link)
            elif should_include_guide(link) and link not in all_docs:
                new_guide.add(link)

    if new_api or new_guide:
        extra_names = sorted(new_api | new_guide)
        print(f"Second pass extra docs to fetch: {len(extra_names)}", flush=True)
        extra_docs = get_documents(extra_names)
        all_docs.update(extra_docs)
        api_names |= new_api
        guide_names |= new_guide

    missing = [n for n in api_names | guide_names if n not in all_docs]
    if missing:
        print("WARNING: missing docs:", missing, flush=True)

    saved = []
    for name in sorted(api_names):
        if name in all_docs:
            p = save_doc(all_docs[name], API_DIR)
            if p:
                saved.append(("api", name, p))
    for name in sorted(guide_names):
        if name in all_docs:
            p = save_doc(all_docs[name], GUIDE_DIR)
            if p:
                saved.append(("guide", name, p))

    print(f"Saved {len(saved)} documents.", flush=True)
    # Print manifest JSON for later use.
    manifest_path = BASE_DIR / "manifest.json"
    manifest = {
        "source_mcp": MCP_URL,
        "fetched_at": None,  # could be filled by caller
        "api": [name for kind, name, _ in saved if kind == "api"],
        "guides": [name for kind, name, _ in saved if kind == "guide"],
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Manifest written to {manifest_path}", flush=True)

if __name__ == "__main__":
    main()
