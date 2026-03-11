// This program was developed by Levko Kravchuk with the help of Vibe Coding
import SwiftUI
import Combine

class OverlayViewModel: ObservableObject {
    @Published var strokeWidth: CGFloat = 5.0
    @Published var selectedColor: Color = .red
    @Published var toolMode: OverlayView.ToolMode = .selection
    
    // Additional state that needs to be accessed/reset
    @Published var drawings: [DrawingShape] = []
    
    // MEMORY FIX: Store CGImage in the ViewModel (a class) instead of in the View (a struct).
    // This prevents NSEvent monitor closures from copying the entire image when they capture [self].
    var capturedImage: CGImage?
    
    // Reset state for new capture
    func reset() {
        strokeWidth = 5.0
        selectedColor = .red
        toolMode = .selection
        drawings.removeAll()
        capturedImage = nil // MEMORY: Release the screenshot
    }
}
