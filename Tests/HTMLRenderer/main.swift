import Foundation

func render(_ source: String) -> String {
    MarkdownHTMLRenderer.renderMarkdownDocument(source)
}

for (destination, expected) in [
    ("//example.com/path", "https://example.com/path"),
    ("//example.com:8443/a%20b?q=1&lang=en#top", "https://example.com:8443/a%20b?q=1&amp;lang=en#top"),
    ("//document/path", "https://document/path"),
    ("https://example.com/path", "https://example.com/path"),
    ("http://example.com/path", "http://example.com/path"),
    ("images/photo.png", "images/photo.png"),
    ("../images/photo.png", "../images/photo.png"),
    ("/images/photo.png", "/images/photo.png"),
    ("#section", "#section")
] {
    precondition(render("[docs](\(destination))").contains("href=\"\(expected)\""), "Incorrect link: \(destination)")
    precondition(render("![image](\(destination))").contains("src=\"\(expected)\""), "Incorrect image: \(destination)")
}
for destination in ["javascript:document.title=42", "data:text/html,bad", "java\tscript:bad", "javascript&#58;bad"] {
    precondition(!render("[docs](\(destination))").contains("href="), "Unsafe link: \(destination)")
    precondition(!render("![image](\(destination))").contains("src="), "Unsafe image: \(destination)")
}
precondition(render("[mail](mailto:person@example.com)").contains("href=\"mailto:person@example.com\""))
precondition(render("> first\n> **second**").contains("first<br><strong>second</strong>"))
print("PASS: 28 HTML renderer assertions (network-path links/images, escaping, local paths, unsafe schemes, blockquotes)")
