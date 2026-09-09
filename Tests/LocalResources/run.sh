#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CHECK_DIR="$(mktemp -d)"
trap 'rm -rf "$CHECK_DIR"' EXIT
cd "$PROJECT_DIR"
swiftc -module-cache-path "$CHECK_DIR/modules" \
    Sources/MarkdownViewer/MarkdownTheme.swift \
    Sources/MarkdownViewer/MarkdownHTMLRenderer.swift \
    Sources/MarkdownViewer/Views/RendererScrollPosition.swift \
    Sources/MarkdownViewer/Views/MarkdownWebView.swift \
    Tests/LocalResources/main.swift -o "$CHECK_DIR/check-resources"
"$CHECK_DIR/check-resources"
