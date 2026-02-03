// This program was developed by Levko Kravchuk with the help of Vibe Coding
import SwiftUI
import Combine

class OverlayViewModel: ObservableObject {
    @Published var strokeWidth: CGFloat = 5.0
    @Published var selectedColor: Color = .red
    @Published var toolMode: OverlayView.ToolMode = .selection
    
    // Additional state that needs to be accessed/reset
    @Published var drawings: [DrawingShape] = []
    
    // Reset state for new capture
    func reset() {
        strokeWidth = 5.0
        selectedColor = .red
        toolMode = .selection
        drawings.removeAll()
    }
}
