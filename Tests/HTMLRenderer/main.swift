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
precondition(render("first\nsecond") == "<p>first second</p>")
precondition(render("first  \nsecond") == "<p>first<br>second</p>")
precondition(render("first\\\nsecond") == "<p>first<br>second</p>")
precondition(render("- first\n  **second**") == "<ul>\n<li>first <strong>second</strong></li>\n</ul>")
precondition(render("1. first\n   **second**") == "<ol>\n<li>first <strong>second</strong></li>\n</ol>")
precondition(render("- first\nsecond") == "<ul>\n<li>first second</li>\n</ul>")
precondition(render("> first\n> **second**").contains("first <strong>second</strong>"))
precondition(render("> first\n>\n> second").contains("first<br><br>second"))
precondition(render("first **bold\nsecond**") == "<p>first <strong>bold second</strong></p>")
precondition(render("first\n\nsecond") == "<p>first</p>\n<p>second</p>")
precondition(render("first\n# second") == "<p>first</p>\n<h1>second</h1>")
precondition(render("first\n- second") == "<p>first</p>\n<ul>\n<li>second</li>\n</ul>")
precondition(render("first\n---") == "<p>first</p>\n<hr>")
precondition(render("first\n```\nsecond\n```").hasPrefix("<p>first</p>\n<pre"))
precondition(render("first\n| a |\n|---|\n| b |").contains("</p>\n<table"))
precondition(render("first\r\nsecond") == "<p>first second</p>")
precondition(render("first\\\\\nsecond") == "<p>first\\\\ second</p>")
precondition(render("first\\") == "<p>first\\</p>")
precondition(render("\u{E000}") == "<p>\u{E000}</p>")
print("PASS: 46 HTML renderer assertions (network-path links/images, escaping, local paths, unsafe schemes, and soft-wrapped blocks)")
