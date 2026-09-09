Run `Tests/HTMLRenderer/run.sh` on macOS with Xcode installed.

Compiles the actual renderer and checks protocol-relative links and images normalize to HTTPS, including the internal `document` hostname collision. Also covers query escaping, local paths, explicit HTTP(S), anchors, blocked schemes, mail links, and multiline blockquotes. No network access or package downloads are required.
