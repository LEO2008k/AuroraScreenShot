// This program was developed by Levko Kravchuk with the help of Vibe Coding
import SwiftUI

struct DrawingShape {
    enum ShapeType { case freestyle, line, arrow, rect, strokeRect, blurRect }
    var type: ShapeType
    var points: [CGPoint]       // used for freestyle
    var start: CGPoint          // used for line, arrow, rect
    var end: CGPoint            // used for line, arrow, rect
    var color: Color
    var lineWidth: CGFloat
}

struct OverlayView: View {
    let image: CGImage
    let isQuickOCR: Bool
    let isTranslationMode: Bool // New
    let onClose: () -> Void
    
    // Default Init
    init(image: CGImage, isQuickOCR: Bool = false, isTranslationMode: Bool = false, onClose: @escaping () -> Void, viewModel: OverlayViewModel) {
        self.image = image
        self.isQuickOCR = isQuickOCR
        self.isTranslationMode = isTranslationMode
        self.onClose = onClose
        self.viewModel = viewModel
    }
    
    @ObservedObject var viewModel: OverlayViewModel
    
    @State private var startPoint: CGPoint?
    @State private var selectionRect: CGRect = .zero
    
    @State private var currentDrawing: DrawingShape?
    
    // Custom Tooltip State
    @State private var activeTooltip: String = ""
    
    enum ToolMode { case selection, draw, line, arrow, redact, highlight, pipette, magnify, blur }
    enum ResizeHandle { case topLeft, topRight, bottomLeft, bottomRight, top, bottom, left, right, none }
    
    // Resize State
    @State private var currentResizeHandle: ResizeHandle = .none
    
    // Preferences
    @AppStorage("BlurBackground") private var blurBackground = false
    @AppStorage("BlurAmount") private var blurAmount = 5.0
    @AppStorage("UIScale") private var uiScale: Double = 1.0
    @AppStorage("ShowTimestamp") private var showTimestampButton = false
    @AppStorage("ShowWatermark") private var showWatermarkButton = false
    @AppStorage("EnableAurora") private var enableAurora = false
    
    // Local State for Manual Application
    @State private var isTimestampApplied = false
    @State private var isWatermarkApplied = false
    
    // Aurora Animation State
    @State private var auroraRotation: Double = 0
    @State private var auroraPhase: CGFloat = 0
    
    // AI Prompt State
    @State private var showAIPrompt: Bool = false
    @State private var aiQuery: String = ""
    @State private var aiResponse: String = ""
    @State private var isAIThinking: Bool = false
    @State private var aiPanelOffset: CGSize = .zero // For dragging
    @FocusState private var isInputFocused: Bool // For keyboard focus
    
    // Magnify Tool State - NEW: Rectangle-based magnification
    @State private var magnifyRect: CGRect = .zero // User-drawn magnification zone
    @State private var magnifyZoomFactor: CGFloat = SettingsManager.shared.magnifierZoomFactor // 1.5x, 2x, 4x
    
    // MEMORY: Event monitor reference for cleanup
    @State private var scrollMonitor: Any? = nil
    
    // MEMORY: Cached bitmap for pipette color picking (avoid re-creating per drag event)
    @State private var cachedBitmapRep: NSBitmapImageRep? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Optimized Background Layer with Blur
                ZStack {
                    // Base image with conditional blur
                    // OPTIMIZATION: Disable blur on Minimum quality to save memory
                        let shouldBlur = blurBackground && SettingsManager.shared.quality != .minimum
                        
                        Image(decorative: image, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .blur(radius: shouldBlur ? min(blurAmount, 15) : 0)
                        
                        // Dimming overlay (for when blur is disabled or Minimum quality)
                        if !shouldBlur {
                            Path { path in
                                path.addRect(CGRect(origin: .zero, size: geometry.size))
                                if selectionRect != .zero {
                                    path.addRect(selectionRect)
                                }
                            }
                            .fill(Color.black.opacity(0.3), style: FillStyle(eoFill: true))
                            .allowsHitTesting(false)
                        }
                        
                        // Clear selection area (only when blurring)
                        if shouldBlur && selectionRect != .zero {
                            Image(decorative: image, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipShape(Rectangle().path(in: selectionRect))
                        }
                    }
                .drawingGroup() // Composite into single layer for performance
                .position(x: geometry.size.width/2, y: geometry.size.height/2)
                
                // Drawings
                ZStack {
                    ForEach(viewModel.drawings.indices, id: \.self) { i in
                        drawShape(viewModel.drawings[i])
                    }
                    if let current = currentDrawing {
                        drawShape(current)
                    }
                    
                    // Quality Preview - Show blur on selection to preview saved quality
                    if selectionRect != .zero {
                        let quality = SettingsManager.shared.quality
                        let blurRadius: CGFloat = {
                            switch quality {
                            case .minimum: return 1.5 // More blur (JPEG 0.6 + downscale preview)
                            case .medium: return 0.5  // Slight blur (JPEG 0.85 preview)
                            case .maximum: return 0   // No blur (PNG lossless)
                            }
                        }()
                        
                        if blurRadius > 0 {
                            Rectangle()
                                .fill(Color.white.opacity(0.0001)) // Nearly invisible
                                .frame(width: selectionRect.width, height: selectionRect.height)
                                .position(x: selectionRect.midX, y: selectionRect.midY)
                                .blur(radius: blurRadius)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .clipShape(Rectangle().path(in: selectionRect != .zero ? selectionRect : CGRect(origin: .zero, size: geometry.size)))
                
                // INTERACTION LAYER (Gestures for drawing/selection)
                // We place this BEHIND the UI controls but ABOVE the image/drawings
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleDrag(value: value, geometry: geometry)
                            }
                            .onEnded { _ in
                                handleDragEnd(geometry: geometry)
                            }
                    )
                
                // Selection Border & Interface
                if selectionRect != .zero {
                    if enableAurora { auroraGlow() }
                    selectionBorder()
                    selectionHandles()
                    timestampPreview()
                    watermarkPreview()
                    if !isQuickOCR && !isTranslationMode {
                        // Action Bar and Tools (only for regular mode)
                        actionBar(geometry: geometry)
                        
                        if showAIPrompt {
                            aiPromptPanel(geometry: geometry)
                        } else {
                            toolsBar(geometry: geometry)
                        }
                        
                        // Magnify Tool - NEW: Show magnified rectangle
                        if viewModel.toolMode == .magnify && magnifyRect != .zero && selectionRect != .zero {
                            // Render magnified version of the specified region
                            Image(decorative: image, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .scaleEffect(magnifyZoomFactor, anchor: .topLeading)
                                .offset(
                                    x: -magnifyRect.minX * (magnifyZoomFactor - 1),
                                y: -magnifyRect.minY * (magnifyZoomFactor - 1)
                                )
                                .clipShape(Rectangle().path(in: CGRect(
                                    x: magnifyRect.minX,
                                    y: magnifyRect.minY,
                                    width: magnifyRect.width * magnifyZoomFactor,
                                    height: magnifyRect.height * magnifyZoomFactor
                                )))
                                .allowsHitTesting(false)
                            
                            // Draw border around magnify zone
                            Rectangle()
                                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                                .frame(width: magnifyRect.width, height: magnifyRect.height)
                                .position(x: magnifyRect.midX, y: magnifyRect.midY)
                                .allowsHitTesting(false)
                        }
                    }
                    // Quick OCR and Translation Mode: show only selection, no toolbars
                }
            }
            .background(Color.clear)
            .contentShape(Rectangle())
            .focusable(true)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
                
                // MEMORY FIX: Store monitor reference so we can remove it later
                scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [self] event in
                    // Only handle when Magnify tool is active and Option is pressed
                    if viewModel.toolMode == .magnify && event.modifierFlags.contains(.option) {
                        let delta = event.scrollingDeltaY
                        // Cycle zoom levels: 1.5x → 2.0x → 4.0x
                        if delta > 0 {
                            // Scroll up: increase zoom
                            if magnifyZoomFactor < 2.0 { magnifyZoomFactor = 2.0 }
                            else if magnifyZoomFactor < 4.0 { magnifyZoomFactor = 4.0 }
                        } else if delta < 0 {
                            // Scroll down: decrease zoom
                            if magnifyZoomFactor > 2.0 { magnifyZoomFactor = 2.0 }
                            else if magnifyZoomFactor > 1.5 { magnifyZoomFactor = 1.5 }
                        }
                        // Save to settings
                        SettingsManager.shared.magnifierZoomFactor = magnifyZoomFactor
                        return nil // Consume event
                    }
                    return event // Pass through
                }
            }
            .onDisappear {
                // MEMORY FIX: Remove scroll event monitor to break retain cycle
                if let monitor = scrollMonitor {
                    NSEvent.removeMonitor(monitor)
                    scrollMonitor = nil
                }
                
                // Explicit cleanup to help release memory
                viewModel.drawings.removeAll()
                cachedBitmapRep = nil
                magnifyRect = .zero
                selectionRect = .zero
                currentDrawing = nil
                aiResponse = ""
                aiQuery = ""
            }
            // IMPORTANT: Gesture removed from here and moved to 'Gesture Layer' inside ZStack
        }
    }
    
    // Drag Logic extracted
    func handleDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        let point = value.location
        
        if viewModel.toolMode == .pipette {
             // Pipette Logic
             pickColor(at: point, geometry: geometry)
             return
        }

        if viewModel.toolMode == .selection {
            if startPoint == nil {
                startPoint = value.startLocation
                currentResizeHandle = hitTestHandle(point: value.startLocation)
                if currentResizeHandle == .none {
                    startPoint = value.startLocation
                    selectionRect = CGRect(origin: value.startLocation, size: .zero)
                }
            }
            if currentResizeHandle != .none {
                resizeSelection(to: point)
            } else {
                updateSelection(to: point)
            }
        } else if viewModel.toolMode == .magnify {
            // Magnify Tool: Draw magnification rectangle
            if startPoint == nil {
                startPoint = value.startLocation
                magnifyRect = CGRect(origin: value.startLocation, size: .zero)
            } else {
                let origin = CGPoint(
                    x: min(startPoint!.x, point.x),
                    y: min(startPoint!.y, point.y)
                )
                let size = CGSize(
                    width: abs(point.x - startPoint!.x),
                    height: abs(point.y - startPoint!.y)
                )
                magnifyRect = CGRect(origin: origin, size: size)
            }
        } else if viewModel.toolMode == .draw {
             if currentDrawing == nil {
                 currentDrawing = DrawingShape(type: .freestyle, points: [point], start: .zero, end: .zero, color: viewModel.selectedColor, lineWidth: viewModel.strokeWidth)
            } else {
                currentDrawing?.points.append(point)
            }
        } else if [.line, .arrow, .redact, .highlight, .blur].contains(viewModel.toolMode) {
            if startPoint == nil { startPoint = value.startLocation }
            let start = startPoint!
            
            var type: DrawingShape.ShapeType
            switch viewModel.toolMode {
                case .line: type = .line
                case .arrow: type = .arrow
                case .redact: type = .rect
                case .highlight: type = .strokeRect
                case .blur: type = .blurRect // Blur tool uses special blur rectangle
                default: type = .freestyle
            }
            
            currentDrawing = DrawingShape(type: type, points: [], start: start, end: point, color: viewModel.selectedColor, lineWidth: (viewModel.toolMode == .redact || viewModel.toolMode == .highlight || viewModel.toolMode == .blur) ? viewModel.strokeWidth : viewModel.strokeWidth)
        }
    }
    
    func handleDragEnd(geometry: GeometryProxy) {
        if viewModel.toolMode == .selection {
            startPoint = nil
            currentResizeHandle = .none

            if isQuickOCR && selectionRect != .zero { performOCR(geometry: geometry) }
            else if isTranslationMode && selectionRect != .zero { performTranslation(geometry: geometry) } // New logic
        } else {
            if let shape = currentDrawing { viewModel.drawings.append(shape) }
            currentDrawing = nil
            startPoint = nil 
        }
    }

    private func getFormattedDate() -> String {
        let format = SettingsManager.shared.timestampFormat
        let formatter = DateFormatter()
        // ... format logic same as before ...
        formatter.dateFormat = "MM/dd/yyyy HH:mm" // simplified for brevity here, actual impl can use full switch
         switch format {
           case "US": formatter.dateFormat = "MM/dd/yyyy HH:mm"
           case "EU": formatter.dateFormat = "dd/MM/yyyy HH:mm"
           case "US_SEC": formatter.dateFormat = "MM/dd/yyyy HH:mm:ss"
           case "EU_SEC": formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
           case "ISO": formatter.dateFormat = "yyyy-MM-dd HH:mm"
           case "ASIA": formatter.dateFormat = "yyyy/MM/dd HH:mm"
           default: formatter.dateFormat = "MM/dd/yyyy HH:mm"
         }
        return formatter.string(from: Date())
    }

    @ViewBuilder
    func timestampPreview() -> some View {
        if isTimestampApplied {
            Text(getFormattedDate())
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(viewModel.selectedColor)
                .padding([.bottom, .trailing], 10)
                .frame(width: selectionRect.width, height: selectionRect.height, alignment: .bottomTrailing)
                .position(x: selectionRect.midX, y: selectionRect.midY)
        }
    }
    
    @ViewBuilder
    func watermarkPreview() -> some View {
        if isWatermarkApplied {
            Text(SettingsManager.shared.watermarkText)
                .font(.system(size: CGFloat(SettingsManager.shared.watermarkSize), weight: .bold))
                .foregroundColor(viewModel.selectedColor.opacity(0.3))
                .frame(width: selectionRect.width, height: selectionRect.height, alignment: .center)
                .position(x: selectionRect.midX, y: selectionRect.midY)
        }
    }

    @ViewBuilder
    func selectionBorder() -> some View {
        ZStack {
            Rectangle().stroke(Color.black, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            Rectangle().stroke(Color.white, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5], dashPhase: 5))
        }
        .frame(width: selectionRect.width, height: selectionRect.height)
        .position(x: selectionRect.midX, y: selectionRect.midY)
        .allowsHitTesting(false)
    }
    
    func actionBar(geometry: GeometryProxy) -> some View {
        let barWidth: CGFloat = 480 
        let bottomSpace = geometry.size.height - selectionRect.maxY
        let topSpace = selectionRect.minY
        
        let actionBarY: CGFloat
        if bottomSpace > 60 { actionBarY = selectionRect.maxY + 30 }
        else if topSpace > 60 { actionBarY = selectionRect.minY - 30 }
        else { actionBarY = selectionRect.maxY - 30 }
        
        let layoutY = max(50, min(actionBarY, geometry.size.height - 30))
        let actionBarX = min(max(selectionRect.midX, barWidth/2 + 10), geometry.size.width - barWidth/2 - 10)
        
        return ZStack {
            if !activeTooltip.isEmpty {
                Text(activeTooltip)
                    .font(.caption).padding(4).background(Color.black.opacity(0.8)).foregroundColor(.white).cornerRadius(4)
                    .offset(y: -40).transition(.opacity)
            }
            HStack(spacing: 8) {
                ActionIconBtn(icon: "xmark", label: "Close", hoverText: "Close Overlay (ESC)", activeTooltip: $activeTooltip, action: onClose)
                Divider().frame(height: 20)
                ActionIconBtn(icon: "doc.on.doc", label: "Copy", hoverText: "Copy to Clipboard", activeTooltip: $activeTooltip, action: { copyImage(geometry: geometry) })
                ActionIconBtn(icon: "square.and.arrow.down", label: "Save", hoverText: "Save to File", activeTooltip: $activeTooltip, action: { saveImage(geometry: geometry) })
                ActionIconBtn(icon: "square.and.arrow.up", label: "Share", hoverText: "Share Image", activeTooltip: $activeTooltip, action: { shareSelection(geometry: geometry) })
                Divider().frame(height: 20)
                if showTimestampButton { ActionIconBtn(icon: "clock", label: "Timestamp", isActive: isTimestampApplied, hoverText: "Timestamp", activeTooltip: $activeTooltip) { isTimestampApplied.toggle() } }
                if showWatermarkButton { ActionIconBtn(icon: "crown", label: "Watermark", isActive: isWatermarkApplied, hoverText: "Watermark", activeTooltip: $activeTooltip) { isWatermarkApplied.toggle() } }
                if showTimestampButton || showWatermarkButton { Divider().frame(height: 20) }
                
                if SettingsManager.shared.showTranslateButton {
                     ActionIconBtn(icon: "globe", label: "Translate", hoverText: "OCR & Translate", activeTooltip: $activeTooltip, action: { performTranslation(geometry: geometry) })
                }
                
                ActionIconBtn(icon: "text.viewfinder", label: "OCR", hoverText: "Recognize Text", activeTooltip: $activeTooltip, action: { performOCR(geometry: geometry) })
                if SettingsManager.shared.enableOllama {
                    ActionIconBtn(icon: "eye", label: "Ollama", isActive: showAIPrompt, hoverText: "Analyze with AI", activeTooltip: $activeTooltip, action: { 
                        showAIPrompt.toggle() 
                        aiResponse = ""
                        aiQuery = ""
                    })
                }
                ActionIconBtn(icon: "magnifyingglass", label: "Search", hoverText: "Search in Google", activeTooltip: $activeTooltip, action: { searchImage(geometry: geometry) })
                ActionIconBtn(icon: "printer", label: "Print", hoverText: "Print Image", activeTooltip: $activeTooltip, action: { printImage(geometry: geometry) })
                
                // Settings Divider
                Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 1, height: 24).padding(.horizontal, 4)
                
                ActionIconBtn(icon: "gearshape", label: "Settings", hoverText: "Settings", activeTooltip: $activeTooltip, action: openSettings)
            }
            .padding(8).background(Color(NSColor.windowBackgroundColor).opacity(0.95)).cornerRadius(6).shadow(radius: 4)
            .scaleEffect(uiScale) // Apply UI Scale
        }
        .position(x: actionBarX, y: layoutY)
    }
    
    // ... toolsBar, colorPalette, toolSettings, drawShape ... same logic
    func pickColor(at point: CGPoint, geometry: GeometryProxy) {
        let viewSize = geometry.size
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        
        let widthRatio = viewSize.width / imageWidth
        let heightRatio = viewSize.height / imageHeight
        let scale = min(widthRatio, heightRatio)
        
        let scaledWidth = imageWidth * scale
        let scaledHeight = imageHeight * scale
        
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2
        
        let imagePointX = (point.x - offsetX) / scale
        let imagePointY = (point.y - offsetY) / scale
        
        if imagePointX >= 0 && imagePointX < imageWidth && imagePointY >= 0 && imagePointY < imageHeight {
            // MEMORY FIX: Cache NSBitmapImageRep instead of creating a new one per drag event
            if cachedBitmapRep == nil {
                cachedBitmapRep = NSBitmapImageRep(cgImage: image)
            }
            if let color = cachedBitmapRep?.colorAt(x: Int(imagePointX), y: Int(imagePointY)) {
                viewModel.selectedColor = Color(color)
            }
        }
    }

    func toolsBar(geometry: GeometryProxy) -> some View {
         let rightSpace = geometry.size.width - selectionRect.maxX
         let leftSpace = selectionRect.minX
         let toolsBarX: CGFloat
         if rightSpace > 50 { toolsBarX = selectionRect.maxX + 30 }
         else if leftSpace > 50 { toolsBarX = selectionRect.minX - 30 }
         else { toolsBarX = selectionRect.maxX - 30 }
         let toolsBarY = min(max(selectionRect.midY, 150), geometry.size.height - 150)
         
         return VStack(spacing: 8) {
             ActionIconBtn(icon: "pencil.tip", label: "Pen", isActive: viewModel.toolMode == .draw, hoverText: "Pen", activeTooltip: $activeTooltip) { viewModel.toolMode = viewModel.toolMode == .draw ? .selection : .draw }
             ActionIconBtn(icon: "line.diagonal", label: "Line", isActive: viewModel.toolMode == .line, hoverText: "Line", activeTooltip: $activeTooltip) { viewModel.toolMode = viewModel.toolMode == .line ? .selection : .line }
             ActionIconBtn(icon: "arrow.up.right", label: "Arrow", isActive: viewModel.toolMode == .arrow, hoverText: "Arrow", activeTooltip: $activeTooltip) { viewModel.toolMode = viewModel.toolMode == .arrow ? .selection : .arrow }
             ActionIconBtn(icon: "square.dashed", label: "Redact", isActive: viewModel.toolMode == .redact, hoverText: "Redact (Fill)", activeTooltip: $activeTooltip) { viewModel.toolMode = viewModel.toolMode == .redact ? .selection : .redact }
             ActionIconBtn(icon: "rectangle", label: "Box", isActive: viewModel.toolMode == .highlight, hoverText: "Highlight Box", activeTooltip: $activeTooltip) { viewModel.toolMode = viewModel.toolMode == .highlight ? .selection : .highlight }
             
             // Pipette
             ActionIconBtn(icon: "eyedropper", label: "Pipette", isActive: viewModel.toolMode == .pipette, hoverText: "Pick Color", activeTooltip: $activeTooltip) { viewModel.toolMode = viewModel.toolMode == .pipette ? .selection : .pipette }
              
              // Magnifier Tool (macOS 14+ only - requires hover tracking)
              if SettingsManager.shared.showMagnifierTool {
                  if #available(macOS 14.0, *) {
                      ActionIconBtn(icon: "plus.magnifyingglass", label: "Magnify (Beta)", isActive: viewModel.toolMode == .magnify, hoverText: "Zoom In (Requires macOS 14+)", activeTooltip: $activeTooltip) { viewModel.toolMode = viewModel.toolMode == .magnify ? .selection : .magnify }
                  }
                  // On macOS < 14, button is hidden (feature not available)
              }
             
             // Blur Tool (conditional)
             if SettingsManager.shared.showPrivacyTool {
                 ActionIconBtn(icon: "drop.fill", label: "Blur", isActive: viewModel.toolMode == .blur, hoverText: "Blur/Pixelate Sensitive Info", activeTooltip: $activeTooltip) { viewModel.toolMode = viewModel.toolMode == .blur ? .selection : .blur }
             }
             
                          if [.draw, .line, .arrow, .redact, .highlight, .pipette, .magnify, .blur].contains(viewModel.toolMode) {
                 Divider().frame(width: 20)
                 
                 // Current Color Preview (Large)
                 Circle()
                     .fill(viewModel.selectedColor)
                     .frame(width: 24, height: 24)
                     .overlay(Circle().stroke(Color.white, lineWidth: 2))
                     .shadow(radius: 2)
                     .help("Current Color")
                 
                 colorPalette()
                 
                 if viewModel.toolMode != .pipette {
                    toolSettings()
                 }
                 
                 // Removed "Set OCR Bg" button as requested
             }
         }
         .padding(6).background(Color(NSColor.windowBackgroundColor).opacity(0.95)).cornerRadius(6).shadow(radius: 4)
         .scaleEffect(uiScale) // Apply UI Scale
         .position(x: toolsBarX, y: toolsBarY)
    }
    
    @ViewBuilder func colorPalette() -> some View {
         VStack(spacing: 4) {
             ForEach([Color.red, Color.blue, Color.green, Color.yellow, Color.black, Color.white], id: \.self) { color in
                 Circle().fill(color).frame(width: 16, height: 16)
                 .overlay(Circle().stroke(Color.white, lineWidth: viewModel.selectedColor == color ? 2 : 0))
                 .onTapGesture { viewModel.selectedColor = color }
             }
         }.padding(4).background(Color.secondary.opacity(0.2)).cornerRadius(4)
    }
    
    @ViewBuilder func toolSettings() -> some View {
        // Show different controls based on active tool
        if viewModel.toolMode == .magnify {
            // Magnifier Size Controls
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass.circle").font(.system(size: 16))
                Button(action: {
                    // Cycle down: 4x → 2x → 1.5x
                    if magnifyZoomFactor > 2.0 { magnifyZoomFactor = 2.0 }
                    else if magnifyZoomFactor > 1.5 { magnifyZoomFactor = 1.5 }
else { magnifyZoomFactor = 4.0 } // Wrap around
                    SettingsManager.shared.magnifierZoomFactor = magnifyZoomFactor
                }) { Image(systemName: "minus.circle") }.buttonStyle(.plain)
                Text(String(format: "%.1fx", magnifyZoomFactor)).font(.system(size: 12)).frame(width: 40)
                Button(action: {
                    // Cycle up: 1.5x → 2x → 4x
                    if magnifyZoomFactor < 2.0 { magnifyZoomFactor = 2.0 }
                    else if magnifyZoomFactor < 4.0 { magnifyZoomFactor = 4.0 }
                    else { magnifyZoomFactor = 1.5 } // Wrap around
                    SettingsManager.shared.magnifierZoomFactor = magnifyZoomFactor
                }) { Image(systemName: "plus.circle") }.buttonStyle(.plain)
            }.padding(4).background(Color.secondary.opacity(0.1)).cornerRadius(4)
        } else {
            // Standard stroke width controls
            HStack(spacing: 4) {
                Button(action: { viewModel.strokeWidth = max(1, viewModel.strokeWidth - 1) }) { Image(systemName: "minus.circle") }.buttonStyle(.plain)
                Text("\(Int(viewModel.strokeWidth))").font(.system(size: 12)).frame(width: 20)
                Button(action: { viewModel.strokeWidth = min(50, viewModel.strokeWidth + 1) }) { Image(systemName: "plus.circle") }.buttonStyle(.plain)
            }.padding(4).background(Color.secondary.opacity(0.1)).cornerRadius(4)
        }
        Button(action: { if !viewModel.drawings.isEmpty { viewModel.drawings.removeLast() } }) { Image(systemName: "arrow.uturn.backward") }.buttonStyle(.plain)
    }

     func drawShape(_ shape: DrawingShape) -> some View {
        Group {
             if shape.type == .freestyle {
                 Path { p in p.addLines(shape.points) }
                 .stroke(shape.color, style: StrokeStyle(lineWidth: shape.lineWidth, lineCap: .round, lineJoin: .round))
             } else if shape.type == .line {
                 Path { p in p.move(to: shape.start); p.addLine(to: shape.end) }
                 .stroke(shape.color, style: StrokeStyle(lineWidth: shape.lineWidth, lineCap: .round, lineJoin: .round))
             } else if shape.type == .arrow {
                 Path { p in p.move(to: shape.start); p.addLine(to: shape.end) }
                 .stroke(shape.color, style: StrokeStyle(lineWidth: shape.lineWidth, lineCap: .round, lineJoin: .round))
                 ArrowHeadShape(start: shape.start, end: shape.end, lineWidth: shape.lineWidth).fill(shape.color)
              } else if shape.type == .rect {
                  let r = CGRect(x: min(shape.start.x, shape.end.x), y: min(shape.start.y, shape.end.y), width: abs(shape.start.x-shape.end.x), height: abs(shape.start.y-shape.end.y))
                  Rectangle().fill(shape.color).frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
              } else if shape.type == .strokeRect {
                  let r = CGRect(x: min(shape.start.x, shape.end.x), y: min(shape.start.y, shape.end.y), width: abs(shape.start.x-shape.end.x), height: abs(shape.start.y-shape.end.y))
                  Rectangle().stroke(shape.color, lineWidth: shape.lineWidth).frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
              } else if shape.type == .blurRect {
                  // Real Blur Effect (Strong - 76% intensity ≈ radius 30)
                  let r = CGRect(x: min(shape.start.x, shape.end.x), y: min(shape.start.y, shape.end.y), width: abs(shape.start.x-shape.end.x), height: abs(shape.start.y-shape.end.y))
                  
                  // Blurred image section
                  Image(decorative: image, scale: 1.0)
                      .resizable()
                      .aspectRatio(contentMode: .fit)
                      .blur(radius: 30) // Strong blur (76% intensity)
                      .mask(
                          Rectangle()
                              .frame(width: r.width, height: r.height)
                              .position(x: r.midX, y: r.midY)
                      )
              }
        }
    }
    
    struct ArrowHeadShape: Shape {
        var start, end: CGPoint; var lineWidth: CGFloat
        func path(in r: CGRect) -> Path {
            let angle = atan2(end.y - start.y, end.x - start.x)
            let len = max(lineWidth * 3.5, 20)
            var p = Path(); p.move(to: end)
            p.addLine(to: CGPoint(x: end.x - len * cos(angle - .pi/6), y: end.y - len * sin(angle - .pi/6)))
            p.addLine(to: CGPoint(x: end.x - len * cos(angle + .pi/6), y: end.y - len * sin(angle + .pi/6)))
            p.closeSubpath()
            return p
        }
    }

    func hitTestHandle(point: CGPoint) -> ResizeHandle {
        let handles: [(ResizeHandle, CGPoint)] = [
            (.topLeft, CGPoint(x: selectionRect.minX, y: selectionRect.minY)),
            (.topRight, CGPoint(x: selectionRect.maxX, y: selectionRect.minY)),
            (.bottomLeft, CGPoint(x: selectionRect.minX, y: selectionRect.maxY)),
            (.bottomRight, CGPoint(x: selectionRect.maxX, y: selectionRect.maxY)),
            // Edges
            (.top, CGPoint(x: selectionRect.midX, y: selectionRect.minY)),
            (.bottom, CGPoint(x: selectionRect.midX, y: selectionRect.maxY)),
            (.left, CGPoint(x: selectionRect.minX, y: selectionRect.midY)),
            (.right, CGPoint(x: selectionRect.maxX, y: selectionRect.midY))
        ]
        for (h, p) in handles { if hypot(point.x-p.x, point.y-p.y) <= 20 { return h } }
        return .none
    }

    func resizeSelection(to point: CGPoint) {
        var r = selectionRect
        switch currentResizeHandle {
        case .topLeft: r = CGRect(x: min(point.x, r.maxX), y: min(point.y, r.maxY), width: abs(point.x-r.maxX), height: abs(point.y-r.maxY))
        case .topRight: r = CGRect(x: min(point.x, r.minX), y: min(point.y, r.maxY), width: abs(point.x-r.minX), height: abs(point.y-r.maxY))
        case .bottomLeft: r = CGRect(x: min(point.x, r.maxX), y: min(point.y, r.minY), width: abs(point.x-r.maxX), height: abs(point.y-r.minY))
        case .bottomRight: r = CGRect(x: min(point.x, r.minX), y: min(point.y, r.minY), width: abs(point.x-r.minX), height: abs(point.y-r.minY))
        case .top: r = CGRect(x: r.minX, y: min(point.y, r.maxY), width: r.width, height: abs(point.y - r.maxY))
        case .bottom: r = CGRect(x: r.minX, y: min(point.y, r.minY), width: r.width, height: abs(point.y - r.minY))
        case .left: r = CGRect(x: min(point.x, r.maxX), y: r.minY, width: abs(point.x - r.maxX), height: r.height)
        case .right: r = CGRect(x: min(point.x, r.minX), y: r.minY, width: abs(point.x - r.minX), height: r.height)
        default: break
        }
        selectionRect = r
    }
    
    func selectionHandles() -> some View {
        if selectionRect == .zero { return AnyView(EmptyView()) }
        let handleSize: CGFloat = 12
        return AnyView(ForEach(0..<8) { i in
            let positions = [
                CGPoint(x: selectionRect.minX, y: selectionRect.minY), CGPoint(x: selectionRect.maxX, y: selectionRect.minY),
                CGPoint(x: selectionRect.minX, y: selectionRect.maxY), CGPoint(x: selectionRect.maxX, y: selectionRect.maxY),
                CGPoint(x: selectionRect.midX, y: selectionRect.minY), CGPoint(x: selectionRect.midX, y: selectionRect.maxY),
                CGPoint(x: selectionRect.minX, y: selectionRect.midY), CGPoint(x: selectionRect.maxX, y: selectionRect.midY)
            ]
            Circle()
                .fill(Color.blue)
                .frame(width: handleSize, height: handleSize)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                .position(positions[i])
        })
    }
    
    // Flatten logic
    func getFlattenedImage(geometry: GeometryProxy) -> CGImage? {
        return autoreleasepool {
            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            let visualImage = NSImage(size: nsImage.size, flipped: false) { rect in
                nsImage.draw(in: rect)
                let scaleX = CGFloat(image.width) / geometry.size.width
                let scaleY = CGFloat(image.height) / geometry.size.height
                let ctx = NSGraphicsContext.current?.cgContext
                
                // Re-implement drawing loop for context (simplified)
                for shape in viewModel.drawings {
                    ctx?.setFillColor(NSColor(shape.color).cgColor)
                    ctx?.setStrokeColor(NSColor(shape.color).cgColor)
                    ctx?.setLineCap(.round)
                    ctx?.setLineJoin(.round)
                    
                    if shape.type == .freestyle {
                        ctx?.setLineWidth(shape.lineWidth * scaleX)
                        ctx?.beginPath(); var f=true
                        for p in shape.points {
                            let x = p.x * scaleX; let y = CGFloat(image.height) - (p.y * scaleY)
                            if f { ctx?.move(to: CGPoint(x:x,y:y)); f=false } else { ctx?.addLine(to: CGPoint(x:x,y:y)) }
                        }
                        ctx?.strokePath()
                    } else if shape.type == .line || shape.type == .arrow {
                        ctx?.setLineWidth(shape.lineWidth * scaleX)
                        let sX = shape.start.x*scaleX; let sY = CGFloat(image.height)-(shape.start.y*scaleY)
                        let eX = shape.end.x*scaleX; let eY = CGFloat(image.height)-(shape.end.y*scaleY)
                        ctx?.beginPath(); ctx?.move(to: CGPoint(x:sX,y:sY)); ctx?.addLine(to: CGPoint(x:eX,y:eY)); ctx?.strokePath()
                        if shape.type == .arrow {
                            // arrow head fill
                            let angle = atan2(eY-sY, eX-sX)
                            let len = max(shape.lineWidth*3.5*scaleX, 20*scaleX)
                            ctx?.beginPath(); ctx?.move(to: CGPoint(x:eX,y:eY))
                            ctx?.addLine(to: CGPoint(x: eX - len*cos(angle - .pi/6), y: eY - len*sin(angle - .pi/6)))
                            ctx?.addLine(to: CGPoint(x: eX - len*cos(angle + .pi/6), y: eY - len*sin(angle + .pi/6)))
                            ctx?.closePath(); ctx?.fillPath()
                        }
                    } else if shape.type == .rect {
                        let r = CGRect(x: min(shape.start.x, shape.end.x), y: min(shape.start.y, shape.end.y), width: abs(shape.start.x-shape.end.x), height: abs(shape.start.y-shape.end.y))
                        ctx?.fill(CGRect(x: r.minX*scaleX, y: CGFloat(image.height)-(r.maxY*scaleY), width: r.width*scaleX, height: r.height*scaleY))
                    } else if shape.type == .strokeRect {
                        let r = CGRect(x: min(shape.start.x, shape.end.x), y: min(shape.start.y, shape.end.y), width: abs(shape.start.x-shape.end.x), height: abs(shape.start.y-shape.end.y))
                         ctx?.setLineWidth(shape.lineWidth * scaleX)
                         ctx?.stroke(CGRect(x: r.minX*scaleX, y: CGFloat(image.height)-(r.maxY*scaleY), width: r.width*scaleX, height: r.height*scaleY))
                    } else if shape.type == .blurRect {
                        let r = CGRect(x: min(shape.start.x, shape.end.x), y: min(shape.start.y, shape.end.y), width: abs(shape.start.x-shape.end.x), height: abs(shape.start.y-shape.end.y))
                        
                        // Scale rect to final image coordinates
                        let scaledRect = CGRect(x: r.minX*scaleX, y: CGFloat(image.height)-(r.maxY*scaleY), width: r.width*scaleX, height: r.height*scaleY)
                        
                        // Crop region from current context, apply blur, and draw back
                        if let ctx = ctx,
                           let contextImage = ctx.makeImage(),
                           let region = contextImage.cropping(to: scaledRect) {
                            
                            // Create blurred version with CIFilter
                            let ciImage = CIImage(cgImage: region)
                            let filter = CIFilter(name: "CIGaussianBlur")
                            filter?.setValue(ciImage, forKey: kCIInputImageKey)
                            filter?.setValue(30.0, forKey: kCIInputRadiusKey) // Match overlay blur radius (line 582)
                            
                            if let output = filter?.outputImage {
                                let ciContext = CIContext(options: [.useSoftwareRenderer: false])
                                if let cgBlurred = ciContext.createCGImage(output, from: ciImage.extent) {
                                    ctx.draw(cgBlurred, in: scaledRect)
                                }
                            }
                        }
                    }
                }
                
                // Timestamps & Watermarks inside context ...
                if isTimestampApplied {
                    let d = getFormattedDate()
                    let attr: [NSAttributedString.Key:Any] = [.font: NSFont.systemFont(ofSize: 14*scaleX, weight: .medium), .foregroundColor: NSColor(viewModel.selectedColor)]
                    let str = NSAttributedString(string: d, attributes: attr)
                    let m: CGFloat = 10*scaleX
                    let dX = (selectionRect.maxX*scaleX) - str.size().width - m
                    let dY = CGFloat(image.height) - (selectionRect.maxY*scaleY) + m
                    str.draw(at: CGPoint(x:dX, y:dY))
                }
                if isWatermarkApplied {
                    let t = SettingsManager.shared.watermarkText
                    if !t.isEmpty {
                       let s = CGFloat(SettingsManager.shared.watermarkSize)
                       let attr: [NSAttributedString.Key:Any] = [.font: NSFont.systemFont(ofSize: s*scaleX, weight: .bold), .foregroundColor: NSColor(viewModel.selectedColor).withAlphaComponent(0.3)]
                       let str = NSAttributedString(string: t, attributes: attr)
                       let cX = selectionRect.midX*scaleX; let cY = selectionRect.midY*scaleY
                       let dX = cX - str.size().width/2
                       let dY = CGFloat(image.height) - (cY*scaleY) - str.size().height/2
                       str.draw(at: CGPoint(x:dX, y:dY))
                    }
                }
                
                return true
            }
            return visualImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
    }

    func getCroppedImage(geometry: GeometryProxy) -> CGImage? {
        return autoreleasepool {
            guard let flat = getFlattenedImage(geometry: geometry) else { return nil }
            let sX = CGFloat(flat.width) / geometry.size.width
            let sY = CGFloat(flat.height) / geometry.size.height
            let rect = CGRect(x: selectionRect.minX*sX, y: selectionRect.minY*sY, width: selectionRect.width*sX, height: selectionRect.height*sY)
            return flat.cropping(to: rect)
        }
    }
    
    // MARK: - Clipboard & Save Logic (Optimized)
    func copyImage(geometry: GeometryProxy) {
        // Check for high memory usage warning
        if SettingsManager.shared.quality == .maximum && !SettingsManager.shared.suppressMaxQualityWarning {
            showMaxQualityWarning {
                self.performCopyInternal(geometry: geometry)
            }
        } else {
            performCopyInternal(geometry: geometry)
        }
    }
    
    private func performCopyInternal(geometry: GeometryProxy) {
        autoreleasepool {
            guard let cropped = getCroppedImage(geometry: geometry) else { return }
            
            let bitmapRep = NSBitmapImageRep(cgImage: cropped)
            guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }
            
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(pngData, forType: .png)
            
            // MEMORY: Schedule auto-cleanup of clipboard after 5 minutes
            ClipboardManager.shared.scheduleClipboardCleanup()
        }
        onClose()
    }
    
    private func showMaxQualityWarning(onConfirm: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "High Memory Usage Warning"
        alert.informativeText = "You're copying a screenshot in Maximum Quality mode. This may use up to 2GB of memory on Retina displays.\n\nContinue?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Copy Anyway")
        alert.addButton(withTitle: "Cancel")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't show this again"
        
        let response = alert.runModal()
        
        if alert.suppressionButton?.state == .on {
            SettingsManager.shared.suppressMaxQualityWarning = true
        }
        
        if response == .alertFirstButtonReturn {
            onConfirm()
        }
    }
    
    func saveImage(geometry: GeometryProxy) {
        var imageToSave: CGImage?
        autoreleasepool {
            guard let cropped = getCroppedImage(geometry: geometry) else { return }
            imageToSave = cropped
            // Downscale logic
            if SettingsManager.shared.downscaleRetina && cropped.width > 200 {
                let w = cropped.width/2; let h = cropped.height/2
                if let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: cropped.bitsPerComponent, bytesPerRow: 0, space: cropped.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: cropped.bitmapInfo.rawValue) {
                    ctx.interpolationQuality = .high
                    ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
                    if let down = ctx.makeImage() { imageToSave = down }
                }
            }
        }
        guard let final = imageToSave else { return }
        
        let rep = NSBitmapImageRep(cgImage: final)
        
        // Quality-based compression
        let quality = SettingsManager.shared.quality
        let imageData: Data?
        let fileExtension: String
        
        switch quality {
        case .minimum:
            // JPEG with 0.6 compression for < 1MB files
            imageData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.6])
            fileExtension = "jpg"
        case .medium:
            // Balanced: JPEG with 0.85 compression
            imageData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
            fileExtension = "jpg"
        case .maximum:
            // Lossless PNG for best quality
            imageData = rep.representation(using: .png, properties: [:])
            fileExtension = "png"
        }
        
        guard let finalData = imageData else { return }
        
        let savePanel = NSSavePanel()
        // Only allow the correct file type for the current quality setting
        switch quality {
        case .minimum, .medium:
            savePanel.allowedContentTypes = [.jpeg]
        case .maximum:
            savePanel.allowedContentTypes = [.png]
        }
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "Screenshot_\(Int(Date().timeIntervalSince1970)).\(fileExtension)"
        savePanel.directoryURL = SettingsManager.shared.saveDirectory
        
        onClose()
        DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    try? finalData.write(to: url)
                }
            }
        }
    }
    
    func shareSelection(geometry: GeometryProxy) {
        guard let cropped = getCroppedImage(geometry: geometry) else { return }
        let nsImage = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
        let picker = NSSharingServicePicker(items: [nsImage])
        if let window = NSApp.keyWindow {
             picker.show(relativeTo: selectionRect, of: window.contentView!, preferredEdge: .minY)
        }
        onClose()
    }
    
    // MARK: - Features Actions
    func performOCR(geometry: GeometryProxy) {
        guard let cropped = getCroppedImage(geometry: geometry) else { return }
        let ocrText = AIHelper.shared.recognizeText(from: cropped) // Now works!
        
        if let windowController = (NSApp.delegate as? AppDelegate)?.resultWindowController {
            windowController.close()
            (NSApp.delegate as? AppDelegate)?.resultWindowController = nil
        }
        
        // Quick OCR: manual translation (autoTranslate: false)
        let resultVC = OCRResultWindowController(text: ocrText, autoTranslate: false)
        (NSApp.delegate as? AppDelegate)?.resultWindowController = resultVC
        resultVC.showWindow(nil)
        resultVC.window?.center()
        NSApp.activate(ignoringOtherApps: true)
        
        onClose()
    }
    
    func performTranslation(geometry: GeometryProxy) {
        guard let cropped = getCroppedImage(geometry: geometry) else { return }
        
        // 1. OCR (Fast)
        let ocrText = AIHelper.shared.recognizeText(from: cropped)
        if ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        
        onClose()
        
        // 2. Open Result Window with Placeholder
        if let windowController = (NSApp.delegate as? AppDelegate)?.resultWindowController {
            windowController.close()
            (NSApp.delegate as? AppDelegate)?.resultWindowController = nil
        }
        
        let resultVC = OCRResultWindowController(text: "Translating...\n\n(Original: \(ocrText.prefix(50))...)")
        (NSApp.delegate as? AppDelegate)?.resultWindowController = resultVC
        resultVC.showWindow(nil)
        resultVC.window?.center()
        
        // 3. Perform Translation
        AIHelper.shared.translateText(ocrText, to: SettingsManager.shared.targetLanguage) { result in
             DispatchQueue.main.async {
                 switch result {
                 case .success(let translated):
                     resultVC.updateText(translated)
                 case .failure(let error):
                     resultVC.updateText("Error: \(error.localizedDescription)\n\nOriginal Text:\n\(ocrText)")
                 }
             }
        }
    }
    
    func updateSelection(to point: CGPoint) {
        guard let start = startPoint else { return }
        let rect = CGRect(x: min(start.x, point.x),
                          y: min(start.y, point.y),
                          width: abs(start.x - point.x),
                          height: abs(start.y - point.y))
        selectionRect = rect
    }
    
    func submitAIQuery(geometry: GeometryProxy) {
        guard let cropped = getCroppedImage(geometry: geometry) else { return }
        
        isAIThinking = true
        aiResponse = "Analyzing..."
        
        // Use user query, or Custom Prompt from settings, or default fallback
        let settingsPrompt = SettingsManager.shared.aiPrompt
        let prompt = aiQuery.isEmpty ? (settingsPrompt.isEmpty ? "Describe this image." : settingsPrompt) : aiQuery
        
        AIHelper.shared.analyzeImageWithOllama(image: cropped, customPrompt: prompt) { result in
             DispatchQueue.main.async {
                 isAIThinking = false
                 switch result {
                 case .success(let text):
                     aiResponse = text
                 case .failure(let error):
                     aiResponse = "Error: \(error.localizedDescription)"
                 }
             }
        }
    }
    
    func aiPromptPanel(geometry: GeometryProxy) -> some View {
         let rightSpace = geometry.size.width - selectionRect.maxX
         let leftSpace = selectionRect.minX
         let panelX: CGFloat
         if rightSpace > 50 { panelX = selectionRect.maxX + 160 } // Shift right
         else if leftSpace > 50 { panelX = selectionRect.minX - 160 } // Shift left
         else { panelX = selectionRect.maxX - 160 }
         
         let panelY = min(max(selectionRect.midY, 150), geometry.size.height - 150)
         
         
         return VStack(spacing: 8) {
             // Header
             HStack {
                 Image(systemName: "sparkles").foregroundColor(.yellow)
                 Text("Ask AI").font(.headline).foregroundColor(.white)
                 Spacer()
                 
                 // Reset Button
                 if !aiResponse.isEmpty || !aiQuery.isEmpty {
                     Button(action: { 
                         aiResponse = ""
                         aiQuery = ""
                         isAIThinking = false 
                         isInputFocused = true
                     }) {
                         Image(systemName: "arrow.counterclockwise").foregroundColor(.white.opacity(0.8))
                     }.buttonStyle(.plain).help("New Chat / Reset")
                     Divider().frame(height: 12).padding(.horizontal, 4)
                 }
                 
                 Button(action: { showAIPrompt = false }) {
                     Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                 }.buttonStyle(.plain)
             }
             .padding(.bottom, 4)
             .contentShape(Rectangle()) // Make header draggable area
             .gesture(DragGesture().onChanged { v in
                 aiPanelOffset = CGSize(width: aiPanelOffset.width + v.translation.width, height: aiPanelOffset.height + v.translation.height)
             })
             
             // Input
             HStack {
                 TextField("Ask a question...", text: $aiQuery, onCommit: {
                     submitAIQuery(geometry: geometry)
                 })
                 .textFieldStyle(PlainTextFieldStyle())
                 .focused($isInputFocused)
                 .padding(6)
                 .background(Color.black.opacity(0.3))
                 .cornerRadius(4)
                 .frame(height: 30)
                 
                 Button(action: { submitAIQuery(geometry: geometry) }) {
                     Image(systemName: "arrow.up.circle.fill")
                         .font(.system(size: 20))
                         .foregroundColor(.blue)
                 }.buttonStyle(.plain)
             }
             
             Divider().background(Color.gray)
             
             // Response
             if isAIThinking {
                 HStack {
                     ProgressView().scaleEffect(0.5)
                     Text("Thinking...").font(.caption).foregroundColor(.secondary)
                 }
                 .frame(height: 100)
             } else if !aiResponse.isEmpty {
                 ScrollView {
                     Text(aiResponse)
                         .font(.system(size: 13))
                         .foregroundColor(.white)
                         .fixedSize(horizontal: false, vertical: true)
                         .multilineTextAlignment(.leading)
                         .padding(4)
                         .textSelection(.enabled) // Allow text selection
                 }
                 .frame(maxHeight: 200)
                 
                 HStack {
                     Spacer()
                     Button("Copy") {
                         let p = NSPasteboard.general
                         p.clearContents()
                         p.setString(aiResponse, forType: .string)
                     }.font(.caption).buttonStyle(.plain).foregroundColor(.blue)
                 }
             } else {
                 Text("AI can analyze this area. Type a prompt above.")
                     .font(.caption)
                     .foregroundColor(.secondary)
                     .frame(height: 50)
             }
         }
         .padding(12)
         .frame(width: 320)
         .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)) // Glass effect
         .cornerRadius(12)
         .shadow(radius: 10)
         .position(x: panelX + aiPanelOffset.width, y: panelY + aiPanelOffset.height)
         .onAppear {
             isInputFocused = true // Auto-focus when opened
         }
    }

    
    // Helper for Blur
    struct VisualEffectBlur: NSViewRepresentable {
        var material: NSVisualEffectView.Material
        var blendingMode: NSVisualEffectView.BlendingMode
        
        func makeNSView(context: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.material = material
            view.blendingMode = blendingMode
            view.state = .active
            return view
        }
        func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
            nsView.material = material
            nsView.blendingMode = blendingMode
        }
    }
    func searchImage(geometry: GeometryProxy) {
        guard let cropped = getCroppedImage(geometry: geometry) else { return }
        let text = AIHelper.shared.recognizeText(from: cropped)
        if !text.isEmpty {
           let query = text.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
           if let url = URL(string: "https://www.google.com/search?q=\(query)") {
               NSWorkspace.shared.open(url)
           }
        }
        onClose()
    }
    func printImage(geometry: GeometryProxy) {
        guard let cropped = getCroppedImage(geometry: geometry) else { return }
        
        // Prepare image data immediately
        let nsImage = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
        let contentW = CGFloat(cropped.width)
        let contentH = CGFloat(cropped.height)
        
        // Close overlay UI first so it doesn't block the print dialog
        onClose()
        
        // Run print operation after a brief delay to allow window to close
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let printInfo = NSPrintInfo.shared
            printInfo.horizontalPagination = .clip
            printInfo.verticalPagination = .clip
            printInfo.isHorizontallyCentered = true
            printInfo.isVerticallyCentered = true
            
            // Logic to fit to page
            let paperSize = printInfo.paperSize
            let printArea = printInfo.imageablePageBounds
            
            let pageW = printArea.width > 0 ? printArea.width : paperSize.width - 40
            let pageH = printArea.height > 0 ? printArea.height : paperSize.height - 40
            
            // Calculate scale needed to fit
            let scaleX = pageW / contentW
            let scaleY = pageH / contentH
            let scale = min(scaleX, scaleY)
            
            printInfo.scalingFactor = scale
            
            let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: contentW, height: contentH))
            imageView.image = nsImage
            imageView.imageScaling = .scaleProportionallyUpOrDown
            
            let op = NSPrintOperation(view: imageView, printInfo: printInfo)
            op.showsPrintPanel = true
            op.showsProgressPanel = true
            
            // Bring app to front to ensure dialog is visible
            NSApp.activate(ignoringOtherApps: true)
            
            op.run()
        }
    }
    func openSettings() {
        onClose()
        DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
             if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.openPreferences()
            }
        }
    }
    
    @ViewBuilder func auroraGlow() -> some View {
        let glowSize = CGFloat(SettingsManager.shared.auroraGlowSize)
        ZStack {
            // Inner Core
            RoundedRectangle(cornerRadius: 4).strokeBorder(
                AngularGradient(gradient: Gradient(colors: [.blue, .purple, .pink, .cyan, .blue]), center: .center, angle: .degrees(auroraRotation)), lineWidth: 6
            )
            .frame(width: selectionRect.width + glowSize, height: selectionRect.height + glowSize)
            .position(x: selectionRect.midX, y: selectionRect.midY)
            .blur(radius: glowSize * 0.4)
            .opacity(1.0)
            
            // Outer Glow
            RoundedRectangle(cornerRadius: 4).strokeBorder(
                AngularGradient(gradient: Gradient(colors: [.blue, .purple, .pink, .cyan, .blue]), center: .center, angle: .degrees(auroraRotation)), lineWidth: 10
            )
            .frame(width: selectionRect.width + glowSize, height: selectionRect.height + glowSize)
            .position(x: selectionRect.midX, y: selectionRect.midY)
            .blur(radius: glowSize)
            .opacity(0.6)
        }
        .onAppear { withAnimation(Animation.linear(duration: 3).repeatForever(autoreverses: false)) { auroraRotation = 360 } }
    }
}

// ActionIconBtn
struct ActionIconBtn: View {
    let icon: String; let label: String; var isActive: Bool = false; var hoverText: String = ""; @Binding var activeTooltip: String; var action: () -> Void
    @State private var isHovering = false
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) { Image(systemName: icon).font(.system(size: 16)); Text(label).font(.system(size: 10)) }
            .frame(width: 50, height: 45)
            .background(isActive ? Color.accentColor.opacity(0.3) : (isHovering ? Color.secondary.opacity(0.2) : Color.clear))
            .cornerRadius(6).foregroundColor(isActive ? .accentColor : .primary)
        }.buttonStyle(.plain).onHover { h in isHovering=h; activeTooltip=h ? hoverText : "" }
    }
}

