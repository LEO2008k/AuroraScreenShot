import SwiftUI
import Cocoa

struct MacEditorView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor
    var backgroundColor: NSColor
    var isEditable: Bool = true
    
    func makeNSView(context: Context) -> NSView {
        // Create container view that will hold background
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = backgroundColor.cgColor
        
        // Create scroll view
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        
        // Create text view
        let textView = NSTextView()
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isEditable = isEditable
        textView.isRichText = false
        textView.font = font
        textView.textColor = textColor
        textView.delegate = context.coordinator
        textView.allowsUndo = true
        
        scrollView.documentView = textView
        
        // Add scrollView to container
        container.addSubview(scrollView)
        scrollView.frame = container.bounds
        
        return container
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update background color
        nsView.layer?.backgroundColor = backgroundColor.cgColor
        
        // Find the scrollView and textView
        guard let scrollView = nsView.subviews.first as? NSScrollView,
              let textView = scrollView.documentView as? NSTextView else { return }
        
        // Update scroll view frame
        scrollView.frame = nsView.bounds
        
        if textView.string != text {
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
