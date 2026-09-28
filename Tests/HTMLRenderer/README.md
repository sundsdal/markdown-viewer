Run `Tests/HTMLRenderer/run.sh` on macOS with Xcode installed.

Compiles the actual renderer and checks protocol-relative links and images normalize to HTTPS, including the internal `document` hostname collision. It also covers query escaping, local paths, explicit HTTP(S), anchors, blocked schemes, mail links, and soft-wrapped paragraphs, list items, blockquotes, inline markup, and explicit hard breaks. No network access or package downloads are required.
