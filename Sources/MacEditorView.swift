import SwiftUI
import Cocoa

struct MacEditorView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor
    var isEditable: Bool = true
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        
        let textView = NSTextView()
        textView.autoresizingMask = [.width]
        textView.drawsBackground = false // KEY: Make it transparent so underlying SwiftUI background shows
        textView.backgroundColor = .clear
        textView.isEditable = isEditable
        textView.isRichText = false
        textView.font = font
        textView.textColor = textColor
        textView.delegate = context.coordinator
        textView.allowsUndo = true
        
        // Enhance readability logic if needed, but transparency is the main goal
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if textView.string != text {
            // Only update if different to avoid cursor jumping
            textView.string = text
        }
        
        if textView.font != font {
            textView.font = font
        }
        
        if textView.textColor != textColor {
            textView.textColor = textColor
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacEditorView
        
        init(_ parent: MacEditorView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
    }
}
