import SwiftUI

#if os(iOS)
import WebKit

struct KanbunWebView: UIViewRepresentable {
  let kanbunText: String

  // Internal Parser (Inlined to ensure build stability)
  struct LocalKanbunParser {
      static func parse(_ text: String) -> String {
          var processed = text
          // 1. Ruby (Furigana)
          processed = processed.replacingOccurrences(of: "(", with: "<rt>")
          processed = processed.replacingOccurrences(of: ")", with: "</rt>")
          // 2. Return Marks (Kaeriten)
          processed = processed.replacingOccurrences(of: "[", with: "<sup class=\"return\">")
          processed = processed.replacingOccurrences(of: "]", with: "</sup>")
          // 3. Okurigana
          processed = processed.replacingOccurrences(of: "{", with: "<span class=\"okurigana\">")
          processed = processed.replacingOccurrences(of: "}", with: "</span>")
          // 4. Sai-reading
          processed = processed.replacingOccurrences(of: "‹", with: "<rt class=\"sai-reading\">")
          processed = processed.replacingOccurrences(of: "›", with: "</rt>")
          // 5. Sai-okurigana
          processed = processed.replacingOccurrences(of: "«", with: "<span class=\"sai-okurigana\">")
          processed = processed.replacingOccurrences(of: "»", with: "</span>")
          // 6. Newlines
          processed = processed.replacingOccurrences(of: "\n", with: "<br>")
          return processed
      }
  }

  func makeUIView(context: Context) -> WKWebView {
    let webView = WKWebView()
    webView.isOpaque = false
    webView.backgroundColor = .clear
    webView.scrollView.isScrollEnabled = false
    return webView
  }

  func updateUIView(_ uiView: WKWebView, context: Context) {
    let cssContent = """
      .kanbun {
        writing-mode: vertical-rl;
        font-size: 1.75rem;
        line-height: 100%;
        font-weight: 375;
        height: 14em;
        padding: 1.2em 0.2em;
        -webkit-writing-mode: vertical-rl;
      }

      .kanbun,
      .kanbun:lang(ja),
      .kanbun :lang(ja) {
        font-family: "A-OTF Shuei Mincho Pr6N", YuMincho, "Yu Mincho",
          "Hiragino Mincho ProN", "MS Mincho", serif;
      }

      .kanbun rt,
      .kanbun sup,
      .kanbun sub,
      .kanbun .return {
        font-size: 60%;
        line-height: 100%;
        color: inherit;
      }
      
      .kanbun .return {
         vertical-align: sub; /* Kaeriten usually on the left/bottom in vertical text */
         font-size: 50%;
         margin-left: 2px;
      }
      
      .kanbun .okurigana {
         font-size: 80%;
         /* Okurigana is usually just inline text, maybe slightly smaller */
      }
      
      body {
          margin: 0;
          padding: 20px;
          background-color: transparent;
          height: 100vh;
          display: flex;
          justify-content: center;
          align-items: center;
      }
      
      @media (prefers-color-scheme: dark) {
          body { color: #eee; }
      }
      """

    let htmlContent = """
      <html>
      <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <style>
          @import url('https://fonts.googleapis.com/css2?family=Zen+Kurenaido&display=swap');
          \(cssContent)
          body { font-family: 'Zen Kurenaido', serif; }
      </style>
      </head>
      <body>
          <div class="kanbun">
              \(LocalKanbunParser.parse(kanbunText))
          </div>
      </body>
      </html>
      """

    uiView.loadHTMLString(htmlContent, baseURL: nil)
  }
}

#else
// macOS fallback - simple text display
struct KanbunWebView: View {
    let kanbunText: String
    
    var body: some View {
        Text(kanbunText)
            .font(.title3)
            .padding()
    }
}
#endif
