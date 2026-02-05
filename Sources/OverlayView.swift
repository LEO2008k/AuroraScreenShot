// This program was developed by Levko Kravchuk with the help of Vibe Coding
import SwiftUI

struct DrawingShape {
    enum ShapeType { case freestyle, line, arrow, rect, strokeRect }
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
    
    // Custom Tooltip State
    @State private var activeTooltip: String = ""
    
    enum ToolMode { case selection, draw, line, arrow, redact, highlight, pipette }
    enum ResizeHandle { case topLeft, topRight, bottomLeft, bottomRight, top, bottom, left, right, none }
    
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
    
    // AI Prompt State
    @State private var showAIPrompt: Bool = false
    @State private var aiQuery: String = ""
    @State private var aiResponse: String = ""
    @State private var isAIThinking: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Layer (Blurred/Clean)
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
                
                // Dimming
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
                
                // Active Zone
                if blurBackground && selectionRect != .zero {
                    Image(decorative: image, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .position(x: geometry.size.width/2, y: geometry.size.height/2)
                        .clipShape(Rectangle().path(in: selectionRect))
                }
                
                // Drawings
                ZStack {
                    ForEach(viewModel.drawings.indices, id: \.self) { i in
                        drawShape(viewModel.drawings[i])
                    }
                    if let current = currentDrawing {
                        drawShape(current)
                    }
                }
                .clipShape(Rectangle().path(in: selectionRect != .zero ? selectionRect : CGRect(origin: .zero, size: geometry.size)))
                
                // Selection Border & Interface
                if selectionRect != .zero {
                    if enableAurora { auroraGlow() }
                    selectionBorder()
                    selectionHandles()
                    timestampPreview()
                    watermarkPreview()
                    if !isQuickOCR {
                        actionBar(geometry: geometry)
                        
                        if showAIPrompt {
                            aiPromptPanel(geometry: geometry)
                        } else {
                            toolsBar(geometry: geometry)
                        }
                    }
                }
            }
            .background(Color.clear)
            .contentShape(Rectangle())
            .focusable(true)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDrag(value: value, geometry: geometry)
                    }
                    .onEnded { _ in
                        handleDragEnd(geometry: geometry)
                    }
            )
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
        } else if viewModel.toolMode == .draw {
             if currentDrawing == nil {
                 currentDrawing = DrawingShape(type: .freestyle, points: [point], start: .zero, end: .zero, color: viewModel.selectedColor, lineWidth: viewModel.strokeWidth)
            } else {
                currentDrawing?.points.append(point)
            }
        } else if [.line, .arrow, .redact, .highlight].contains(viewModel.toolMode) {
            if startPoint == nil { startPoint = value.startLocation }
            let start = startPoint!
            
            var type: DrawingShape.ShapeType
            switch viewModel.toolMode {
                case .line: type = .line
                case .arrow: type = .arrow
                case .redact: type = .rect
                case .highlight: type = .strokeRect
                default: type = .freestyle
            }
            
            currentDrawing = DrawingShape(type: type, points: [], start: start, end: point, color: viewModel.selectedColor, lineWidth: (viewModel.toolMode == .redact || viewModel.toolMode == .highlight) ? viewModel.strokeWidth : viewModel.strokeWidth)
        }
    }
    
    func handleDragEnd(geometry: GeometryProxy) {
        if viewModel.toolMode == .selection {
            startPoint = nil
            currentResizeHandle = .none
            if isQuickOCR && selectionRect != .zero { performOCR(geometry: geometry) }
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
                if showTimestampButton { ActionIconBtn(icon: "clock", label: "Timestamp", isActive: isTimestampApplied, hoverText: "Toggle", activeTooltip: $activeTooltip) { isTimestampApplied.toggle() } }
                if showWatermarkButton { ActionIconBtn(icon: "crown", label: "Watermark", isActive: isWatermarkApplied, hoverText: "Toggle", activeTooltip: $activeTooltip) { isWatermarkApplied.toggle() } }
                if showTimestampButton || showWatermarkButton { Divider().frame(height: 20) }
                
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
                Divider().frame(height: 20)
                ActionIconBtn(icon: "gearshape", label: "Settings", hoverText: "Settings", activeTooltip: $activeTooltip, action: openSettings)
            }
            .padding(8).background(Color(NSColor.windowBackgroundColor).opacity(0.95)).cornerRadius(6).shadow(radius: 4)
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
            let bitmap = NSBitmapImageRep(cgImage: image)
            if let color = bitmap.colorAt(x: Int(imagePointX), y: Int(imagePointY)) {
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
                          if [.draw, .line, .arrow, .redact, .highlight, .pipette].contains(viewModel.toolMode) {
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
         HStack(spacing: 4) {
              Button(action: { viewModel.strokeWidth = max(1, viewModel.strokeWidth - 1) }) { Image(systemName: "minus.circle") }.buttonStyle(.plain)
              Text("\(Int(viewModel.strokeWidth))").font(.system(size: 12)).frame(width: 20)
              Button(action: { viewModel.strokeWidth = min(50, viewModel.strokeWidth + 1) }) { Image(systemName: "plus.circle") }.buttonStyle(.plain)
         }.padding(4).background(Color.secondary.opacity(0.1)).cornerRadius(4)
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
        return AnyView(ForEach([
            CGPoint(x: selectionRect.minX, y: selectionRect.minY), CGPoint(x: selectionRect.maxX, y: selectionRect.minY),
            CGPoint(x: selectionRect.minX, y: selectionRect.maxY), CGPoint(x: selectionRect.maxX, y: selectionRect.maxY),
            CGPoint(x: selectionRect.midX, y: selectionRect.minY), CGPoint(x: selectionRect.midX, y: selectionRect.maxY),
            CGPoint(x: selectionRect.minX, y: selectionRect.midY), CGPoint(x: selectionRect.maxX, y: selectionRect.midY)
        ], id: \.x) { p in
            Circle().fill(Color.white).frame(width: 8, height: 8).overlay(Circle().stroke(Color.black, lineWidth: 1)).shadow(radius: 2).position(p)
        })
    }
    
    // Flatten logic
    func getFlattenedImage(geometry: GeometryProxy) -> CGImage? {
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

    func getCroppedImage(geometry: GeometryProxy) -> CGImage? {
        guard let flat = getFlattenedImage(geometry: geometry) else { return nil }
        let sX = CGFloat(flat.width) / geometry.size.width
        let sY = CGFloat(flat.height) / geometry.size.height
        let rect = CGRect(x: selectionRect.minX*sX, y: selectionRect.minY*sY, width: selectionRect.width*sX, height: selectionRect.height*sY)
        return flat.cropping(to: rect)
    }
    
    // MARK: - Clipboard & Save Logic (Optimized)
    func copyImage(geometry: GeometryProxy) {
        autoreleasepool {
            guard let cropped = getCroppedImage(geometry: geometry) else { return }
            
            let bitmapRep = NSBitmapImageRep(cgImage: cropped)
            guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }
            
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(pngData, forType: .png)
        }
        onClose()
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
        guard let pngData = rep.representation(using: .png, properties: [:]) else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "Screenshot_\(Int(Date().timeIntervalSince1970))"
        savePanel.directoryURL = SettingsManager.shared.saveDirectory
        
        onClose()
        DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    try? pngData.write(to: url)
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
        
        if let windowController = (NSApp.delegate as? AppDelegate)?.resultWindowController { windowController.close() }
        
        // FIXED INIT: No image arg
        let resultVC = OCRResultWindowController(text: ocrText)
        (NSApp.delegate as? AppDelegate)?.resultWindowController = resultVC
        resultVC.showWindow(nil)
        resultVC.window?.center()
        NSApp.activate(ignoringOtherApps: true)
        
        onClose()
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
        
        // Use user query or default if empty
        let prompt = aiQuery.isEmpty ? "Describe this image." : aiQuery
        
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
    
    @ViewBuilder func aiPromptPanel(geometry: GeometryProxy) -> some View {
         let rightSpace = geometry.size.width - selectionRect.maxX
         let leftSpace = selectionRect.minX
         let panelX: CGFloat
         if rightSpace > 50 { panelX = selectionRect.maxX + 160 } // Shift right
         else if leftSpace > 50 { panelX = selectionRect.minX - 160 } // Shift left
         else { panelX = selectionRect.maxX - 160 }
         
         let panelY = min(max(selectionRect.midY, 150), geometry.size.height - 150)
         
         VStack(spacing: 8) {
             // Header
             HStack {
                 Image(systemName: "sparkles").foregroundColor(.yellow)
                 Text("Ask AI").font(.headline).foregroundColor(.white)
                 Spacer()
                 Button(action: { showAIPrompt = false }) {
                     Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                 }.buttonStyle(.plain)
             }
             
             // Input
             HStack {
                 TextField("Ask a question about this area...", text: $aiQuery, onCommit: {
                     submitAIQuery(geometry: geometry)
                 })
                 .textFieldStyle(PlainTextFieldStyle())
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
                 Text("Enter a prompt to analyze the selected area.")
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
         .position(x: selectionRect.midX, y: selectionRect.maxY + 140) // Position BELOW selection
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
        RoundedRectangle(cornerRadius: 4).strokeBorder(
                AngularGradient(gradient: Gradient(colors: [.blue, .purple, .pink, .cyan, .blue]), center: .center, angle: .degrees(auroraRotation)), lineWidth: 4
            ).frame(width: selectionRect.width + glowSize, height: selectionRect.height + glowSize).position(x: selectionRect.midX, y: selectionRect.midY)
            .blur(radius: glowSize * 0.6).opacity(0.8)
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
