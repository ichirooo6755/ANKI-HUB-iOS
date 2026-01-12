import SwiftUI

#if os(iOS)
import WebKit

struct SeikeiWebView: UIViewRepresentable {
    @ObservedObject private var theme = ThemeManager.shared

    let content: String
    let blankMap: [Int: String]
    @Binding var revealedId: Int?
    var isAllRevealed: Bool = false
    var onBlankTapped: (Int, String) -> Void

    private func applyInterfaceStyle(to webView: WKWebView) {
        if let preferred = theme.effectivePreferredColorScheme {
            webView.overrideUserInterfaceStyle = preferred == .dark ? .dark : .light
        } else {
            webView.overrideUserInterfaceStyle = .unspecified
        }
    }
    
    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: SeikeiWebView
        var lastSignature: String = ""
        
        init(_ parent: SeikeiWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "blankTapped", let dict = message.body as? [String: Any], let id = dict["id"] as? Int {
                if let answer = parent.blankMap[id] {
                    parent.onBlankTapped(id, answer)
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "blankTapped")
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        applyInterfaceStyle(to: webView)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        applyInterfaceStyle(to: uiView)

        let signature = makeSignature(content: content, blankMap: blankMap)

        // If content is already loaded and unchanged, do NOT reload. This preserves revealed blanks.
        if signature == context.coordinator.lastSignature {
            if isAllRevealed {
                uiView.evaluateJavaScript("revealAll()", completionHandler: nil)
            }

            if let rid = revealedId, let answer = blankMap[rid] {
                let js = "reveal(\(rid), '\(jsEscaped(answer))');"
                uiView.evaluateJavaScript(js, completionHandler: nil)
            }
            return
        }

        context.coordinator.lastSignature = signature

        var htmlBody = content
        
        for (id, _) in blankMap {
            let placeholder = "[\(id)]"
            // Use class for identification to support multiple blanks with same ID
            let buttonHtml = """
            <button class="blank blank-\(id)" onclick="window.webkit.messageHandlers.blankTapped.postMessage({id: \(id)})">
                \(placeholder)
            </button>
            """
            htmlBody = htmlBody.replacingOccurrences(of: placeholder, with: buttonHtml)
        }
        
        let isDarkTheme = theme.effectiveIsDark
        let bodyTextColor = isDarkTheme ? "#eee" : "#333"
        let blankBg = isDarkTheme ? "#444" : "#e0e0e0"
        let blankBorder = isDarkTheme ? "#555" : "#ccc"
        let blankText = isDarkTheme ? "#eee" : "#333"
        let revealedBg = isDarkTheme ? "#1b4b1b" : "#d4edda"
        let revealedText = isDarkTheme ? "#d4edda" : "#155724"
        let revealedBorder = isDarkTheme ? "#2b5b2b" : "#c3e6cb"

        let html = """
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
            @import url('https://fonts.googleapis.com/css2?family=Zen+Kurenaido&display=swap');
            body {
                font-family: 'Zen Kurenaido', sans-serif;
                font-size: 18px;
                line-height: 1.8;
                color: \(bodyTextColor);
                background-color: transparent;
                margin: 0;
                padding: 16px;
            }
            .blank {
                background: \(blankBg);
                border: 1px solid \(blankBorder);
                border-radius: 4px;
                padding: 2px 8px;
                margin: 0 4px;
                color: \(blankText);
                font-weight: bold;
                font-size: 16px;
                cursor: pointer;
            }
            .blank.revealed {
                background: \(revealedBg);
                color: \(revealedText);
                border-color: \(revealedBorder);
            }
        </style>
        <script>
            function reveal(id, answer) {
                // Find all blanks with this ID (Handle multiple occurrences)
                var btns = document.getElementsByClassName('blank-' + id);
                for (var i = 0; i < btns.length; i++) {
                    btns[i].innerText = answer;
                    btns[i].classList.add('revealed');
                }
            }
            function revealAll() {
                var blanks = document.getElementsByClassName('blank');
                for(var i=0; i<blanks.length; i++) {
                    var cls = blanks[i].className || '';
                    var match = cls.match(/\\bblank-(\\d+)\\b/);
                    if (!match) { continue; }
                    var id = match[1];
                    if (answers[id]) {
                       reveal(id, answers[id]);
                    }
                }
            }
        </script>
        </head>
        <body>
            <script>
                const answers = \(generateAnswersJson(blankMap));
            </script>
            <script>
                window.addEventListener('load', function() {
                    \(isAllRevealed ? "revealAll();" : "")
                    \((revealedId != nil && blankMap[revealedId ?? -1] != nil) ? "reveal(\(revealedId ?? -1), '\(jsEscaped(blankMap[revealedId ?? -1] ?? ""))');" : "")
                });
            </script>
            \(htmlBody)
        </body>
        </html>
        """
        
        uiView.loadHTMLString(html, baseURL: nil)
    }

    private func makeSignature(content: String, blankMap: [Int: String]) -> String {
        // Include theme in signature so that theme changes trigger re-render
        let ids = blankMap.keys.sorted().map(String.init).joined(separator: ",")
        let paletteKey = theme.selectedThemeId
        let schemeKey = String(theme.colorSchemeOverride)
        let wallpaperKey = "\(theme.wallpaperKind)|\(theme.wallpaperValue)"
        return "\(content.hashValue)|\(ids)|\(schemeKey)|\(paletteKey)|\(wallpaperKey)"
    }

    private func jsEscaped(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\\\\", with: "\\\\\\\\")
            .replacingOccurrences(of: "'", with: "\\\\'")
            .replacingOccurrences(of: "\n", with: "\\\\n")
            .replacingOccurrences(of: "\r", with: "")
    }
    
    private func generateAnswersJson(_ map: [Int: String]) -> String {
        do {
            let data = try JSONEncoder().encode(map)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
}

#else
// macOS fallback - simple text display
struct SeikeiWebView: View {
    let content: String
    let blankMap: [Int: String]
    @Binding var revealedId: Int?
    var isAllRevealed: Bool = false
    var onBlankTapped: (Int, String) -> Void
    
    var body: some View {
        Text(content)
            .font(.body)
            .padding()
    }
}
#endif
