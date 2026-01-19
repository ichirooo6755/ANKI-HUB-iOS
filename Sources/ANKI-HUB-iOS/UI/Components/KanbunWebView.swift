import SwiftUI

#if os(iOS)
import WebKit

struct KanbunWebView: UIViewRepresentable {
  let kanbunText: String
  let isCompact: Bool

  init(kanbunText: String, isCompact: Bool = false) {
      self.kanbunText = kanbunText
      self.isCompact = isCompact
  }

  class Coordinator {
      var lastSignature: String = ""
  }

  func makeCoordinator() -> Coordinator {
      Coordinator()
  }

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
    let signature = "\(kanbunText.hashValue)|\(isCompact)|\(uiView.traitCollection.userInterfaceStyle.rawValue)"
    if signature == context.coordinator.lastSignature {
      return
    }
    context.coordinator.lastSignature = signature

    let kanbunFontSize = isCompact ? "1.35rem" : "1.75rem"
    let kanbunHeight = isCompact ? "10.5em" : "14em"
    let kanbunPadding = isCompact ? "0.8em 0.2em" : "1.2em 0.2em"
    let bodyPadding = isCompact ? "8px" : "20px"
    let bodyAlignment = isCompact ? "flex-start" : "center"

    let cssContent = """
      .kanbun {
        writing-mode: vertical-rl;
        font-size: \(kanbunFontSize);
        line-height: 1.1;
        font-weight: 375;
        height: \(kanbunHeight);
        padding: \(kanbunPadding);
        -webkit-writing-mode: vertical-rl;
        display: inline-block;
      }

      .kanbun,
      .kanbun:lang(ja),
      .kanbun :lang(ja) {
        font-family: "A-OTF Shuei Mincho Pr6N", YuMincho, "Yu Mincho",
          "Hiragino Mincho ProN", "MS Mincho", serif;
      }

      .kanbun ruby {
        ruby-position: over;
      }

      .kanbun rt,
      .kanbun sup,
      .kanbun sub,
      .kanbun .return {
        font-size: 48%;
        line-height: 1;
        color: inherit;
      }
      
      .kanbun .return {
         vertical-align: super;
         margin-left: 0.15em;
         position: relative;
         top: 0.2em;
      }
      
      .kanbun .okurigana {
         font-size: 75%;
      }
      
      body {
          margin: 0;
          padding: \(bodyPadding);
          background-color: transparent;
          height: 100vh;
          display: flex;
          justify-content: center;
          align-items: \(bodyAlignment);
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
    let isCompact: Bool

    init(kanbunText: String, isCompact: Bool = false) {
        self.kanbunText = kanbunText
        self.isCompact = isCompact
    }
    
    var body: some View {
        Text(kanbunText)
            .font(.title3)
            .padding()
    }
}
#endif
