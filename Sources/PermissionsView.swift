// This program was developed by Levko Kravchuk with the help of Vibe Coding
import SwiftUI

struct PermissionsView: View {
    @ObservedObject var manager = PermissionsManager.shared
    var onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
                .padding(.top, 20)
            
            Text("Permissions Required")
                .font(.title)
                .bold()
            
            Text("Aurora Screenshot needs access to Screen Recording and Accessibility to function correctly.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 15) {
                // Screen Recording
                HStack {
                    ZStack {
                        Circle()
                            .fill(manager.hasScreenRecording ? Color.green : Color.red)
                            .frame(width: 24, height: 24)
                        Image(systemName: manager.hasScreenRecording ? "checkmark" : "xmark")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .bold))
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Screen Recording")
                            .font(.headline)
                        Text("Required to capture screenshots.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !manager.hasScreenRecording {
                        Button("Grant") {
                            manager.requestScreenRecording()
                            manager.openSystemSettings(for: "screen")
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                // Accessibility
                HStack {
                    ZStack {
                        Circle()
                            .fill(manager.hasAccessibility ? Color.green : Color.red)
                            .frame(width: 24, height: 24)
                        Image(systemName: manager.hasAccessibility ? "checkmark" : "xmark")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .bold))
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Accessibility")
                            .font(.headline)
                        Text("Required for global keyboard shortcuts.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !manager.hasAccessibility {
                        Button("Grant") {
                            manager.requestAccessibility()
                            manager.openSystemSettings(for: "accessibility")
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding()
            
            HStack {
                Button("Check Again") {
                    manager.check()
                }
                
                Spacer()
                
                Button("Continue") {
                    onContinue()
                }
                .disabled(!manager.hasScreenRecording || !manager.hasAccessibility)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 450, height: 500)
    }
}
