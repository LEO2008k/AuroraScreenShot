// This program was developed by Levko Kravchuk with the help of Vibe Coding
import SwiftUI

struct DrawingShape {
    enum ShapeType { case freestyle, line, arrow, rect }
    var type: ShapeType
    var points: [CGPoint]       // used for freestyle
    var start: CGPoint          // used for line, arrow, rect
    var end: CGPoint            // used for line, arrow, rect
    var color: Color
    var lineWidth: CGFloat
}

struct OverlayView: View {
    let image: CGImage
    var isQuickOCR: Bool = false
    var onClose: () -> Void
    
    @ObservedObject var viewModel: OverlayViewModel
    
    @State private var startPoint: CGPoint?
    @State private var selectionRect: CGRect = .zero
    
    @State private var currentDrawing: DrawingShape?
    
    // Tools (Now in ViewModel)
    // Local aliases for easier refactoring, or just replace usage
    
    // Custom Tooltip State
    @State private var activeTooltip: String = ""
    
    enum ToolMode { case selection, draw, line, arrow, redact }
    enum ResizeHandle { case topLeft, topRight, bottomLeft, bottomRight, none }
    
    // Resize State
    @State private var currentResizeHandle: ResizeHandle = .none
    
    // Preferences
    @AppStorage("BlurBackground") private var blurBackground = false
    @AppStorage("BlurAmount") private var blurAmount = 5.0
    @AppStorage("ShowTimestamp") private var showTimestampButton = false
    @AppStorage("ShowWatermark") private var showWatermarkButton = false
    @AppStorage("EnableAurora") private var enableAurora = false
    
    // Local State for Manual Application
    @State private var isTimestampApplied = false
    @State private var isWatermarkApplied = false
    
    // Aurora Animation State
    @State private var auroraRotation: Double = 0
    @State private var auroraPhase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Background Layer (Blurred or Dimmed)
                Group {
                    if blurBackground {
                        Image(decorative: image, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .blur(radius: blurAmount)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .position(x: geometry.size.width/2, y: geometry.size.height/2)
                    } else {
                        Image(decorative: image, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .position(x: geometry.size.width/2, y: geometry.size.height/2)
                    }
                }
                
                // 2. Dimming
                if !blurBackground {
                    Path { path in
                        path.addRect(CGRect(origin: .zero, size: geometry.size))
                        if selectionRect != .zero {
                            path.addRect(selectionRect)
                        }
                    }
                    .fill(Color.black.opacity(0.15), style: FillStyle(eoFill: true))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
                
                // 3. Clean Image (Active Zone)
                if blurBackground && selectionRect != .zero {
                    Image(decorative: image, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .position(x: geometry.size.width/2, y: geometry.size.height/2)
                        .clipShape(Rectangle().path(in: selectionRect))
                }
                
                // 4. Drawings & Redactions (Clipped to selection)
                ZStack {
                    ForEach(viewModel.drawings.indices, id: \.self) { i in
                        drawShape(viewModel.drawings[i])
                    }
                    if let current = currentDrawing {
                        drawShape(current)
                    }
                }
                .clipShape(Rectangle().path(in: selectionRect != .zero ? selectionRect : CGRect(origin: .zero, size: geometry.size)))
                
                // 4. Selection Border
                if selectionRect != .zero {
                    if enableAurora {
                        auroraGlow()
                    }
                    selectionBorder()
                    selectionHandles()
                    timestampPreview()
                    watermarkPreview()
                }
                
                // 5. Interface/Toolbars
                if selectionRect != .zero && !isQuickOCR {
                    actionBar(geometry: geometry)
                    toolsBar(geometry: geometry)
                }
            }
            .background(Color.clear)
            .contentShape(Rectangle())
            .focusable(true)
            .onAppear {
                // Ensure window gets key events
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = value.location
                        
                        if viewModel.toolMode == .selection {
                            // 1. Check for Resize Handle on Start
                            if startPoint == nil {
                                startPoint = value.startLocation
                                
                                // Hit Test for Handles
                                currentResizeHandle = hitTestHandle(point: value.startLocation)
                                
                                if currentResizeHandle == .none {
                                    startPoint = value.startLocation
                                    selectionRect = CGRect(origin: value.startLocation, size: .zero)
                                }
                            }
                            
                            // 2. Handle Drag
                            if currentResizeHandle != .none {
                                resizeSelection(to: point)
                            } else {
                                updateSelection(to: point)
                            }
                            
                        } else if viewModel.toolMode == .draw {
                             if currentDrawing == nil {
                                 currentDrawing = DrawingShape(type: .freestyle, points: [point], start: .zero, end: .zero, color: viewModel.selectedColor, lineWidth: viewModel.strokeWidth)
                            } else {
                                currentDrawing?.points.append(point)
                            }
                        } else if viewModel.toolMode == .line || viewModel.toolMode == .arrow || viewModel.toolMode == .redact {
                            if startPoint == nil { startPoint = value.startLocation }
                            let start = startPoint!
                            let end = point
                            
                            let type: DrawingShape.ShapeType
                            switch viewModel.toolMode {
                            case .line: type = .line
                            case .arrow: type = .arrow
                            case .redact: type = .rect
                            default: type = .rect
                            }
                            
                            currentDrawing = DrawingShape(type: type, points: [], start: start, end: end, color: viewModel.selectedColor, lineWidth: viewModel.toolMode == .redact ? 0 : viewModel.strokeWidth)
                        }
                    }
                    .onEnded { _ in
                        if viewModel.toolMode == .selection {
                            startPoint = nil
                            currentResizeHandle = .none // Reset handle
                            
                            if isQuickOCR && selectionRect != .zero {
                                performOCR(geometry: geometry)
                            }
                        } else {
                            if let shape = currentDrawing { viewModel.drawings.append(shape) }
                            currentDrawing = nil
                            startPoint = nil 
                        }
                    }
            )
        }
    }
    
    private func getFormattedDate() -> String {
        let format = SettingsManager.shared.timestampFormat
        let formatter = DateFormatter()
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
        if isTimestampApplied { // Use local state
            let dateString = getFormattedDate()
            
            Text(dateString)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(viewModel.selectedColor)
                .padding([.bottom, .trailing], 10)
                .frame(width: selectionRect.width, height: selectionRect.height, alignment: .bottomTrailing)
                .position(x: selectionRect.midX, y: selectionRect.midY)
                .allowsHitTesting(false)
        }
    }
    
    @ViewBuilder
    func watermarkPreview() -> some View {
        if isWatermarkApplied { // Use local state
            let text = SettingsManager.shared.watermarkText
            let size = SettingsManager.shared.watermarkSize
            if !text.isEmpty {
                Text(text)
                    .font(.system(size: size, weight: .bold))
                    .foregroundColor(viewModel.selectedColor.opacity(0.3))
                    .frame(width: selectionRect.width, height: selectionRect.height, alignment: .center)
                    .position(x: selectionRect.midX, y: selectionRect.midY)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    func selectionBorder() -> some View {
        // Marching ants selection border (black + white dashed for contrast)
        ZStack {
            // Black dashed layer
            Rectangle()
            .stroke(Color.black, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            .frame(width: selectionRect.width, height: selectionRect.height)
            .position(x: selectionRect.midX, y: selectionRect.midY)
            
            // White dashed layer (offset)
            Rectangle()
            .stroke(Color.white, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5], dashPhase: 5))
            .frame(width: selectionRect.width, height: selectionRect.height)
            .position(x: selectionRect.midX, y: selectionRect.midY)
        }
        .allowsHitTesting(false)
    }
    
    func actionBar(geometry: GeometryProxy) -> some View {
        let barWidth: CGFloat = 480 
        
        // Smart positioning logic
        let bottomSpace = geometry.size.height - selectionRect.maxY
        let topSpace = selectionRect.minY
        
        let actionBarY: CGFloat
        if bottomSpace > 60 {
            actionBarY = selectionRect.maxY + 30
        } else if topSpace > 60 {
            actionBarY = selectionRect.minY - 30
        } else {
            actionBarY = selectionRect.maxY - 30
        }
        
        let safeTop: CGFloat = 50
        let layoutY = max(safeTop, min(actionBarY, geometry.size.height - 30))
        let actionBarX = min(max(selectionRect.midX, barWidth/2 + 10), geometry.size.width - barWidth/2 - 10)
        
        return ZStack {
            // Tooltip Overlay (Above the bar)
            if !activeTooltip.isEmpty {
                Text(activeTooltip)
                    .font(.caption)
                    .padding(4)
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .offset(y: -40) // Position above the bar
                    .transition(.opacity)
            }
            
            HStack(spacing: 8) {
                ActionIconBtn(icon: "xmark", label: "Close", hoverText: "Close Overlay (ESC)", activeTooltip: $activeTooltip, action: onClose)
                
                Divider().frame(height: 20)
                
                ActionIconBtn(icon: "doc.on.doc", label: "Copy", hoverText: "Copy to Clipboard", activeTooltip: $activeTooltip, action: { copyImage(geometry: geometry) })
                ActionIconBtn(icon: "square.and.arrow.down", label: "Save", hoverText: "Save to File", activeTooltip: $activeTooltip, action: { saveImage(geometry: geometry) })
                ActionIconBtn(icon: "square.and.arrow.up", label: "Share", hoverText: "Share Image", activeTooltip: $activeTooltip, action: { shareSelection(geometry: geometry) })
                
                Divider().frame(height: 20)
                
                if showTimestampButton {
                    ActionIconBtn(icon: "clock", label: "Timestamp", isActive: isTimestampApplied, hoverText: "Toggle Timestamp", activeTooltip: $activeTooltip) { isTimestampApplied.toggle() }
                }
                if showWatermarkButton {
                    ActionIconBtn(icon: "crown", label: "Watermark", isActive: isWatermarkApplied, hoverText: "Toggle Watermark", activeTooltip: $activeTooltip) { isWatermarkApplied.toggle() }
                }
                if showTimestampButton || showWatermarkButton {
                    Divider().frame(height: 20)
                }
                
                ActionIconBtn(icon: "text.viewfinder", label: "OCR", hoverText: "Recognize Text", activeTooltip: $activeTooltip, action: { performOCR(geometry: geometry) })
                
                if SettingsManager.shared.enableOllama {
                    ActionIconBtn(icon: "eye", label: "Ollama", hoverText: "Analyze with AI", activeTooltip: $activeTooltip, action: { analyzeWithOllama(geometry: geometry) })
                }
                
                ActionIconBtn(icon: "magnifyingglass", label: "Search", hoverText: "Search in Google", activeTooltip: $activeTooltip, action: { searchImage(geometry: geometry) })
                ActionIconBtn(icon: "printer", label: "Print", hoverText: "Print Image", activeTooltip: $activeTooltip, action: { printImage(geometry: geometry) })
                
                Divider().frame(height: 20)
                
                ActionIconBtn(icon: "gearshape", label: "Settings", hoverText: "Settings", activeTooltip: $activeTooltip, action: openSettings)
            }
            .padding(8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
            .cornerRadius(6)
            .shadow(radius: 4)
        }
        .position(x: actionBarX, y: layoutY)
    }
    
    func toolsBar(geometry: GeometryProxy) -> some View {
        let rightSpace = geometry.size.width - selectionRect.maxX
        let leftSpace = selectionRect.minX
        
        let toolsBarX: CGFloat
        if rightSpace > 50 {
            toolsBarX = selectionRect.maxX + 30
        } else if leftSpace > 50 {
            toolsBarX = selectionRect.minX - 30
        } else {
            toolsBarX = selectionRect.maxX - 30
        }
        
        // Vertical center
        let toolsBarY = min(max(selectionRect.midY, 150), geometry.size.height - 150)
        
        return VStack(spacing: 8) {
            ActionIconBtn(icon: "pencil.tip", label: "Pen", isActive: viewModel.toolMode == .draw, hoverText: "Pen Tool", activeTooltip: $activeTooltip) {
                viewModel.toolMode = (viewModel.toolMode == .draw) ? .selection : .draw
            }
            ActionIconBtn(icon: "line.diagonal", label: "Line", isActive: viewModel.toolMode == .line, hoverText: "Line Tool", activeTooltip: $activeTooltip) {
                viewModel.toolMode = (viewModel.toolMode == .line) ? .selection : .line
            }
            ActionIconBtn(icon: "arrow.up.right", label: "Arrow", isActive: viewModel.toolMode == .arrow, hoverText: "Arrow Tool", activeTooltip: $activeTooltip) {
                viewModel.toolMode = (viewModel.toolMode == .arrow) ? .selection : .arrow
            }
            ActionIconBtn(icon: "square.dashed", label: "Redact", isActive: viewModel.toolMode == .redact, hoverText: "Redact Tool", activeTooltip: $activeTooltip) {
                viewModel.toolMode = (viewModel.toolMode == .redact) ? .selection : .redact
            }
            
            if [.draw, .line, .arrow, .redact].contains(viewModel.toolMode) {
                Divider().frame(width: 20)
                colorPalette()
                toolSettings()
            }
        }
        .padding(6)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
        .cornerRadius(6)
        .shadow(radius: 4)
        .position(x: toolsBarX, y: toolsBarY)
    }
    
    @ViewBuilder
    func colorPalette() -> some View {
        VStack(spacing: 4) {
            ForEach([Color.red, Color.blue, Color.green, Color.yellow, Color.black, Color.white], id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: viewModel.selectedColor == color ? 2 : 0)
                    )
                    .onTapGesture {
                        viewModel.selectedColor = color
                    }
            }
        }
        .padding(4)
        .background(Color.secondary.opacity(0.2))
        .cornerRadius(4)
    }
    
    @ViewBuilder
    func toolSettings() -> some View {
        HStack(spacing: 4) {
             Button(action: {
                 viewModel.strokeWidth = max(1, viewModel.strokeWidth - 1)
             }) {
                 Image(systemName: "minus.circle")
             }
             .buttonStyle(.plain)
             
             Text("\(Int(viewModel.strokeWidth))")
                 .font(.system(size: 12))
                 .frame(width: 20)
            
             Button(action: {
                 viewModel.strokeWidth = min(50, viewModel.strokeWidth + 1)
             }) {
                 Image(systemName: "plus.circle")
             }
             .buttonStyle(.plain)
        }
        .padding(4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
        
        Button(action: {
            if !viewModel.drawings.isEmpty { viewModel.drawings.removeLast() }
        }) {
            Image(systemName: "arrow.uturn.backward")
        }
        .buttonStyle(.plain)
        .help("Undo")
    }
    
    func drawShape(_ shape: DrawingShape) -> some View {
        Group {
            switch shape.type {
            case .freestyle:
                Path { path in
                    path.addLines(shape.points)
                }
                .stroke(shape.color, style: StrokeStyle(lineWidth: shape.lineWidth, lineCap: .round, lineJoin: .round))
            case .line:
                Path { path in
                    path.move(to: shape.start)
                    path.addLine(to: shape.end)
                }
                .stroke(shape.color, style: StrokeStyle(lineWidth: shape.lineWidth, lineCap: .round, lineJoin: .round))
            case .arrow:
                // Draw Line
                Path { path in
                    path.move(to: shape.start)
                    path.addLine(to: shape.end)
                }
                .stroke(shape.color, style: StrokeStyle(lineWidth: shape.lineWidth, lineCap: .round, lineJoin: .round))
                
                // Draw Head
                ArrowHeadShape(start: shape.start, end: shape.end, lineWidth: shape.lineWidth)
                    .fill(shape.color)
            case .rect:
                let rect = CGRect(x: min(shape.start.x, shape.end.x),
                                  y: min(shape.start.y, shape.end.y),
                                  width: abs(shape.start.x - shape.end.x),
                                  height: abs(shape.start.y - shape.end.y))
                Rectangle()
                    .fill(shape.color)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
    }
    
    struct ArrowHeadShape: Shape {
        var start: CGPoint
        var end: CGPoint
        var lineWidth: CGFloat
        
        func path(in rect: CGRect) -> Path {
            let angle = atan2(end.y - start.y, end.x - start.x)
            let arrowLength = max(lineWidth * 3.5, 20)
            let arrowAngle = CGFloat.pi / 6
            
            var path = Path()
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x - arrowLength * cos(angle - arrowAngle),
                                     y: end.y - arrowLength * sin(angle - arrowAngle)))
            path.addLine(to: CGPoint(x: end.x - arrowLength * cos(angle + arrowAngle),
                                     y: end.y - arrowLength * sin(angle + arrowAngle)))
            path.closeSubpath()
            return path
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
    
    /// Flattens the drawing lines and shapes onto the base image
    func getFlattenedImage(geometry: GeometryProxy) -> CGImage? {
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        
        // Create visual image for export
        let visualImage = NSImage(size: nsImage.size, flipped: false) { rect in
            nsImage.draw(in: rect)
            
            // Draw lines and shapes
            let scaleX = CGFloat(image.width) / geometry.size.width
            let scaleY = CGFloat(image.height) / geometry.size.height
            
            let ctx = NSGraphicsContext.current?.cgContext
            
            for shape in viewModel.drawings {
                ctx?.setFillColor(NSColor(shape.color).cgColor)
                ctx?.setStrokeColor(NSColor(shape.color).cgColor)
                ctx?.setLineCap(.round)
                ctx?.setLineJoin(.round)
                
                switch shape.type {
                case .freestyle:
                    ctx?.setLineWidth(shape.lineWidth * scaleX)
                    ctx?.beginPath()
                    var first = true
                    for point in shape.points {
                        let x = point.x * scaleX
                        let y = CGFloat(image.height) - (point.y * scaleY)
                        if first { ctx?.move(to: CGPoint(x: x, y: y)); first = false }
                        else { ctx?.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    ctx?.strokePath()
                    
                case .line:
                    ctx?.setLineWidth(shape.lineWidth * scaleX)
                    ctx?.beginPath()
                    let startX = shape.start.x * scaleX
                    let startY = CGFloat(image.height) - (shape.start.y * scaleY)
                    let endX = shape.end.x * scaleX
                    let endY = CGFloat(image.height) - (shape.end.y * scaleY)
                    ctx?.move(to: CGPoint(x: startX, y: startY))
                    ctx?.addLine(to: CGPoint(x: endX, y: endY))
                    ctx?.strokePath()
                    
                case .arrow:
                    // 1. Draw Line
                    ctx?.setLineWidth(shape.lineWidth * scaleX)
                    ctx?.beginPath()
                    let startX = shape.start.x * scaleX
                    let startY = CGFloat(image.height) - (shape.start.y * scaleY)
                    let endX = shape.end.x * scaleX
                    let endY = CGFloat(image.height) - (shape.end.y * scaleY)
                    ctx?.move(to: CGPoint(x: startX, y: startY))
                    ctx?.addLine(to: CGPoint(x: endX, y: endY))
                    ctx?.strokePath()
                    
                    // 2. Draw Arrow Head (Fill)
                    let angle = atan2(endY - startY, endX - startX)
                    let arrowLength = max(shape.lineWidth * 3.5 * scaleX, 20 * scaleX)
                    let arrowAngle = CGFloat.pi / 6
                    
                    // Note: Coordinates are flipped in ctx unless we flip transform
                    // But here we manually flip Y (image.height - y) so standard trig works?
                    // Let's verify angles.
                    // If start=(0,0), end=(100,0) -> Angle 0.
                    // Screen: Start(0,H), End(100,H) -> Angle 0. Correct.
                    // So standard Trig works.
                    
                    ctx?.beginPath()
                    ctx?.move(to: CGPoint(x: endX, y: endY))
                    ctx?.addLine(to: CGPoint(x: endX - arrowLength * cos(angle - arrowAngle),
                                             y: endY - arrowLength * sin(angle - arrowAngle)))
                    ctx?.addLine(to: CGPoint(x: endX - arrowLength * cos(angle + arrowAngle),
                                             y: endY - arrowLength * sin(angle + arrowAngle)))
                    ctx?.closePath()
                    ctx?.fillPath()
                    
                case .rect:
                    let rect = CGRect(x: min(shape.start.x, shape.end.x),
                                      y: min(shape.start.y, shape.end.y),
                                      width: abs(shape.start.x - shape.end.x),
                                      height: abs(shape.start.y - shape.end.y))
                    
                    let x = rect.minX * scaleX
                    let y = CGFloat(image.height) - (rect.maxY * scaleY)
                    let w = rect.width * scaleX
                    let h = rect.height * scaleY
                    
                    ctx?.fill(CGRect(x: x, y: y, width: w, height: h))
                }
            }
            
            // Draw Timestamp
            if isTimestampApplied { // Use local state
                let format = SettingsManager.shared.timestampFormat
                let formatter = DateFormatter()
                switch format {
                case "US": formatter.dateFormat = "MM/dd/yyyy HH:mm"
                case "EU": formatter.dateFormat = "dd/MM/yyyy HH:mm"
                case "US_SEC": formatter.dateFormat = "MM/dd/yyyy HH:mm:ss"
                case "EU_SEC": formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
                case "ISO": formatter.dateFormat = "yyyy-MM-dd HH:mm"
                case "ASIA": formatter.dateFormat = "yyyy/MM/dd HH:mm"
                default: formatter.dateFormat = "MM/dd/yyyy HH:mm"
                }
                
                let dateString = formatter.string(from: Date())
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 14 * scaleX, weight: .medium), // Scale font
                    .foregroundColor: NSColor(viewModel.selectedColor)
                ]
                let attrString = NSAttributedString(string: dateString, attributes: attributes)
                
                // Position: Bottom-Right of selection
                let margin: CGFloat = 10 * scaleX
                let textWidth = attrString.size().width
                
                // Ensure we use the current selection rect, normalized to image
                // selectionRect is in "geometry" coordinates (screen points)
                let rectMaxY = self.selectionRect.maxY
                let rectMaxX = self.selectionRect.maxX
                
                // Calc position in Image Coordinates (Bottom-Left origin)
                // X: Right edge - text width - margin
                let drawX = (rectMaxX * scaleX) - textWidth - margin
                
                // Y: Image Height - (Selection Bottom Y) + margin
                // (Since Selection Bottom Y is far down in Top-Left coords, subtracting it puts us near bottom of image)
                let drawY = CGFloat(image.height) - (rectMaxY * scaleY) + margin
                
                attrString.draw(at: CGPoint(x: drawX, y: drawY))
            }
            
            // Draw Watermark
            if isWatermarkApplied { // Use local state
                let text = SettingsManager.shared.watermarkText
                let size = CGFloat(SettingsManager.shared.watermarkSize)
                if !text.isEmpty {
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: size * scaleX, weight: .bold),
                        .foregroundColor: NSColor(viewModel.selectedColor).withAlphaComponent(0.3)
                    ]
                    let attrString = NSAttributedString(string: text, attributes: attributes)
                    
                    // Position: Center of selection
                    let textWidth = attrString.size().width
                    let textHeight = attrString.size().height
                    
                    let centerX = self.selectionRect.midX * scaleX
                    let centerY = self.selectionRect.midY * scaleY
                    
                    // Convert Y to Bottom-Left origin for drawing
                    let drawX = centerX - (textWidth / 2)
                    let drawY = CGFloat(image.height) - (centerY * scaleY) - (textHeight / 2)
                    
                    attrString.draw(at: CGPoint(x: drawX, y: drawY))
                }
            }
            
            return true
        }
        
        return visualImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
    
    func hitTestHandle(point: CGPoint) -> ResizeHandle {
        let handleSize: CGFloat = 20
        let rect = selectionRect
        
        let handles: [(ResizeHandle, CGPoint)] = [
            (.topLeft, CGPoint(x: rect.minX, y: rect.minY)),
            (.topRight, CGPoint(x: rect.maxX, y: rect.minY)),
            (.bottomLeft, CGPoint(x: rect.minX, y: rect.maxY)),
            (.bottomRight, CGPoint(x: rect.maxX, y: rect.maxY))
        ]
        
        for (handle, position) in handles {
            let distance = hypot(point.x - position.x, point.y - position.y)
            if distance <= handleSize {
                return handle
            }
        }
        return .none
    }
    
    func resizeSelection(to point: CGPoint) {
        var rect = selectionRect
        
        switch currentResizeHandle {
        case .topLeft:
            rect = CGRect(x: min(point.x, rect.maxX), y: min(point.y, rect.maxY), width: abs(point.x - rect.maxX), height: abs(point.y - rect.maxY))
        case .topRight:
            rect = CGRect(x: min(point.x, rect.minX), y: min(point.y, rect.maxY), width: abs(point.x - rect.minX), height: abs(point.y - rect.maxY))
        case .bottomLeft:
            rect = CGRect(x: min(point.x, rect.maxX), y: min(point.y, rect.minY), width: abs(point.x - rect.maxX), height: abs(point.y - rect.minY))
        case .bottomRight:
            rect = CGRect(x: min(point.x, rect.minX), y: min(point.y, rect.minY), width: abs(point.x - rect.minX), height: abs(point.y - rect.minY))
        case .none:
            break
        }
        
        selectionRect = rect
    }

    @ViewBuilder
    func selectionHandles() -> some View {
        if selectionRect != .zero {
            let handleSize: CGFloat = 12
            
            // Draw 4 handles
            ForEach([
                (ResizeHandle.topLeft, CGPoint(x: selectionRect.minX, y: selectionRect.minY)),
                (.topRight, CGPoint(x: selectionRect.maxX, y: selectionRect.minY)),
                (.bottomLeft, CGPoint(x: selectionRect.minX, y: selectionRect.maxY)),
                (.bottomRight, CGPoint(x: selectionRect.maxX, y: selectionRect.maxY))
            ], id: \.0) { handle, position in
                Circle()
                    .fill(Color.white)
                    .frame(width: handleSize, height: handleSize)
                    .overlay(Circle().stroke(Color.black, lineWidth: 1))
                    .position(position)
            }
        }
    }

    func getCroppedImage(geometry: GeometryProxy) -> CGImage? {
        // Use the flattened image (includes drawings)
        guard let flatImage = getFlattenedImage(geometry: geometry) else { return nil }
        
        let scaleX = CGFloat(flatImage.width) / geometry.size.width
        let scaleY = CGFloat(flatImage.height) / geometry.size.height
        
        let cropRect = CGRect(
            x: selectionRect.minX * scaleX,
            y: selectionRect.minY * scaleY,
            width: selectionRect.width * scaleX,
            height: selectionRect.height * scaleY
        )
        
        return flatImage.cropping(to: cropRect)
    }
    
    func copyImage(geometry: GeometryProxy) {
        print("Copy image called, selection: \(selectionRect)")
        guard let cropped = getCroppedImage(geometry: geometry) else {
            print("Failed to get cropped image")
            return
        }
        print("Cropped image size: \(cropped.width)x\(cropped.height)")
        let nsImage = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.writeObjects([nsImage])
        print("Pasteboard write success: \(success)")
        onClose()
    }
    
    func saveImage(geometry: GeometryProxy) {
        guard let cropped = getCroppedImage(geometry: geometry) else { return }
        
        var imageToSave = cropped
        let originalWidth = CGFloat(cropped.width)
        
        // Downscale Logic: If enabled and image is large (likely retina)
        if SettingsManager.shared.downscaleRetina && originalWidth > 100 { // Basic check
            let width = Int(cropped.width / 2)
            let height = Int(cropped.height / 2)
            
            if let context = CGContext(data: nil, width: width, height: height,
                                       bitsPerComponent: cropped.bitsPerComponent,
                                       bytesPerRow: 0,
                                       space: cropped.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
                                       bitmapInfo: cropped.bitmapInfo.rawValue) {
                context.interpolationQuality = .high
                context.draw(cropped, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
                if let downscaled = context.makeImage() {
                    imageToSave = downscaled
                }
            }
        }
        
        let nsImage = NSImage(cgImage: imageToSave, size: NSSize(width: imageToSave.width, height: imageToSave.height))
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "Screenshot_\(Int(Date().timeIntervalSince1970))"
        savePanel.directoryURL = SettingsManager.shared.saveDirectory
        
        onClose()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    if let tiff = nsImage.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiff),
                       let data = bitmap.representation(using: .png, properties: [:]) {
                        try? data.write(to: url)
                    }
                }
            }
        }
    }
    
    func performOCR(geometry: GeometryProxy) {
        // For OCR, we probably want the CLEAN image (without highlighting/drawing?), 
        // OR the flattened one if they redacted stuff.
        // User request: "замалювати скажімо пароль" -> Confirms we should use flattened.
        
        guard let cropped = getCroppedImage(geometry: geometry) else { return }
        
        OCRService.recognizeText(from: cropped) { result in
            DispatchQueue.main.async {
                onClose() // Close overlay
                
                switch result {
                case .success(let text):
                    // Open Result Window
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.resultWindowController = OCRResultWindowController(text: text)
                        appDelegate.resultWindowController?.showWindow(nil)
                        appDelegate.resultWindowController?.window?.makeKeyAndOrderFront(nil)
                    }
                case .failure(let error):
                    print("OCR Failed: \(error)")
                }
            }
        }
    }
    
    func analyzeWithOllama(geometry: GeometryProxy) {
        guard let cropped = getCroppedImage(geometry: geometry) else { return }
        
        // Show loading state? For now, just close and show result window later or immediately show window with spinner
        onClose()
        
        // Open Result Window with "Analyzing..." placeholder
        if let appDelegate = NSApp.delegate as? AppDelegate {
            let controller = OCRResultWindowController(text: "Analyzing with Ollama...")
            appDelegate.resultWindowController = controller
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            
            AIHelper.shared.analyzeImageWithOllama(image: cropped) { result in
                DispatchQueue.main.async(execute: {
                    switch result {
                    case .success(let text):
                        // Update the window content
                         controller.updateText(text)
                    case .failure(let error):
                         controller.updateText("Ollama Error: \(error.localizedDescription)")
                    }
                })
            }
        }
    }

    func printImage(geometry: GeometryProxy) {
        guard let cropped = getCroppedImage(geometry: geometry) else { return }
        let nsImage = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
        
        onClose()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let printInfo = NSPrintInfo.shared
            printInfo.topMargin = 0
            printInfo.bottomMargin = 0
            printInfo.leftMargin = 0
            printInfo.rightMargin = 0
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .fit
            
            let imageView = NSImageView(frame: NSRect(origin: .zero, size: nsImage.size))
            imageView.image = nsImage
            
            let printOp = NSPrintOperation(view: imageView, printInfo: printInfo)
            printOp.run()
        }
    }

    func searchImage(geometry: GeometryProxy) {
        guard let cropped = getCroppedImage(geometry: geometry) else { return }
        
        // OCR Logic (Keep existing text search)
        OCRService.recognizeText(from: cropped) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let text):
                    let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !query.isEmpty, let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
                        NSWorkspace.shared.open(url)
                    } else {
                        // Fallback: Open Google Images
                        self.searchByImageRaw(image: cropped)
                    }
                case .failure:
                    self.searchByImageRaw(image: cropped)
                }
                onClose()
            }
        }
    }
    
    func searchByImageRaw(image: CGImage) {
        // Copy image to clipboard first
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
        
        // Open Google Images
        if let url = URL(string: "https://images.google.com") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func shareSelection(geometry: GeometryProxy) {
        guard let cropped = getCroppedImage(geometry: geometry) else { return }
        let nsImage = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
        
        // Close overlay first so picker shows properly
        onClose()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Use sharing service directly instead of picker
            if let service = NSSharingService(named: .sendViaAirDrop) {
                service.perform(withItems: [nsImage])
            } else {
                // Fallback: Copy to clipboard and show message
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([nsImage])
                
                // Show generic share picker in a new window
                let shareWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100), styleMask: [.titled, .closable], backing: .buffered, defer: false)
                shareWindow.title =  "Share"
                shareWindow.center()
                shareWindow.makeKeyAndOrderFront(nil)
                
                let picker = NSSharingServicePicker(items: [nsImage])
                if let contentView = shareWindow.contentView {
                    picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
                }
            }
        }
    }

    func openSettings() {
        onClose() // Close overlay
        // Small delay to ensure overlay is gone before showing settings
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.sendAction(Selector("openPreferences"), to: nil, from: nil)
        }
    }
}

// Helper View for buttons to keep code clean
// Helper View for buttons to keep code clean
struct ActionIconBtn: View {
    var icon: String
    var label: String // For accessibility or fallback
    var isActive: Bool = false
    var hoverText: String
    @Binding var activeTooltip: String
    var action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isActive ? .accentColor : .primary)
            }
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                activeTooltip = hoverText
            } else {
                if activeTooltip == hoverText {
                    activeTooltip = ""
                }
            }
        }
    }
}

// Helper to access NSWindow for Key handling
struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()
        DispatchQueue.main.async {
            if let window = nsView.window {
                callback(window)
            }
        }
        return nsView
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension OverlayView {
    @ViewBuilder
    func auroraGlow() -> some View {
        // Aurora Borealis Effect
        // We want a glow STARTING from the selection border and going OUTWARD.
        // Glow size is configurable via Settings.
        
        // Convert user-facing "glow size" (5-50px visible) to internal stroke width
        // Multiplier: 2.4x to get nice visible glow (e.g., 15 -> 36, 50 -> 120)
        let glowSizeSetting = CGFloat(SettingsManager.shared.auroraGlowSize)
        let strokeWidth: CGFloat = glowSizeSetting * 2.4
        let pathWidth = selectionRect.width + strokeWidth
        let pathHeight = selectionRect.height + strokeWidth
        
        ZStack {
            // Layer 1: Base Gradient
            RoundedRectangle(cornerRadius: 1) // Tiny corner radius to avoid sharp artifact
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.green, .blue, .purple, .green]),
                        center: .center,
                        angle: .degrees(auroraRotation)
                    ),
                    lineWidth: strokeWidth
                )
                .blur(radius: strokeWidth * 0.15)
                .opacity(0.8)
            
            // Layer 2: Counter-rotating overlay for "shimmer"
            RoundedRectangle(cornerRadius: 1)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.clear, .cyan.opacity(0.5), .purple.opacity(0.5), .clear]),
                        center: .center,
                        angle: .degrees(-auroraRotation * 1.5)
                    ),
                    lineWidth: strokeWidth * 0.8 // Slightly narrower for variation
                )
                .blur(radius: strokeWidth * 0.25)
                .opacity(0.6)
        }
        .frame(width: pathWidth, height: pathHeight)
        .position(x: selectionRect.midX, y: selectionRect.midY)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                auroraRotation = 360
            }
        }
    }
}
