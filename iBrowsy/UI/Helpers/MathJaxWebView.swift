import SwiftUI
import WebKit

#if os(macOS)
typealias PlatformAgnosticWebViewRepresentable = NSViewRepresentable
#else // iOS, etc.
typealias PlatformAgnosticWebViewRepresentable = UIViewRepresentable
#endif

struct MathJaxWebView: PlatformAgnosticWebViewRepresentable {
    let latexString: String
    @Binding var dynamicHeight: CGFloat

    private func htmlString(latex: String) -> String {
        let escapedLatex = latex
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script>
                MathJax = {
                    tex: {
                        inlineMath: [['$', '$']],
                        displayMath: [['$$', '$$']]
                    },
                    svg: {
                        fontCache: 'global'
                    },
                    startup: {
                        ready: () => {
                            MathJax.startup.defaultReady();
                            // After initial rendering, get the height and post it
                            window.webkit.messageHandlers.sizeNotification.postMessage(document.body.scrollHeight);
                        }
                    }
                };
            </script>
            <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js"></script>
            <style>
                body {
                    margin: 5px; 
                    padding: 0; 
                    font-size: 15px; /* Adjust base font size if needed */
                    color: #E0E0E0; /* Light text color for dark mode */
                    background-color: transparent; /* Transparent background */
                    overflow: hidden; /* Prevent scrollbars within the webview */
                }
                /* Ensure MathJax SVG elements inherit color */
                 mjx-container svg {
                     fill: currentcolor;
                     stroke: currentcolor;
                 }
            </style>
        </head>
        <body>
            \\(escapedLatex)
        </body>
        </html>
        """
    }

    // --- NSViewRepresentable specific implementation ---
    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.configuration.userContentController.add(context.coordinator, name: "sizeNotification")
        // Allow transparent background
        webView.setValue(false, forKey: "drawsBackground") 
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let html = htmlString(latex: latexString)
        nsView.loadHTMLString(html, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: MathJaxWebView

        init(_ parent: MathJaxWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
             if message.name == "sizeNotification", let contentHeight = message.body as? CGFloat {
                 DispatchQueue.main.async {
                     // Update the dynamic height binding
                     self.parent.dynamicHeight = contentHeight
                 }
             }
         }
    }
    #endif

    // --- UIViewRepresentable specific implementation ---
    #if os(iOS)
    func makeUIView(context: Context) -> WKWebView {
         let webView = WKWebView()
         webView.configuration.userContentController.add(context.coordinator, name: "sizeNotification")
         webView.isOpaque = false
         webView.backgroundColor = .clear
         webView.scrollView.backgroundColor = .clear
         webView.scrollView.isScrollEnabled = false // Disable scrolling within webview
         return webView
     }

     func updateUIView(_ uiView: WKWebView, context: Context) {
         let html = htmlString(latex: latexString)
         uiView.loadHTMLString(html, baseURL: nil)
     }
     
     func makeCoordinator() -> Coordinator {
         Coordinator(self)
     }

     class Coordinator: NSObject, WKScriptMessageHandler {
         var parent: MathJaxWebView

         init(_ parent: MathJaxWebView) {
             self.parent = parent
         }

         func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
              if message.name == "sizeNotification", let contentHeight = message.body as? CGFloat {
                  DispatchQueue.main.async {
                      // Update the dynamic height binding
                     self.parent.dynamicHeight = contentHeight
                  }
              }
          }
     }
     #endif
}

// Simple Preview
#if DEBUG
struct MathJaxWebView_Previews: PreviewProvider {
    static var previews: some View {
        // Example usage with state for dynamic height
        StatefulMathJaxPreview()
            .frame(height: 200) // Provide some initial frame
            .padding()
    }
    
    struct StatefulMathJaxPreview: View {
        @State private var webViewHeight: CGFloat = 50 // Initial height
        let latexExample = "$$ \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a} $$" // Updated example
        
        var body: some View {
             VStack {
                 Text("LaTeX Rendered Below:")
                 MathJaxWebView(latexString: latexExample, dynamicHeight: $webViewHeight)
                     .frame(height: webViewHeight) // Use dynamic height
                     .border(Color.red) // For visualizing the frame
                 Text("Reported Height: \\(webViewHeight, specifier: \"%.1f\")")
             }
        }
    }
}
#endif 