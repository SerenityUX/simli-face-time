import SwiftUI
import AppKit

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    private var window: NSPanel?
    
    func toggleWindow() {
        if let window = window, window.isVisible {
            window.close()
        } else {
            showWindow()
        }
    }
    
    private func showWindow() {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            centerWindow(existingWindow)
        } else {
            // Create new panel window
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                styleMask: [.nonactivatingPanel, .fullSizeContentView, .titled],
                backing: .buffered,
                defer: false
            )
            
            panel.title = ""
            panel.contentView = NSHostingView(rootView: ContentView())
            panel.backgroundColor = NSColor.windowBackgroundColor
            panel.isMovableByWindowBackground = true
            panel.level = .floating
            panel.collectionBehavior = [.transient, .ignoresCycle]
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = true
            panel.standardWindowButton(.closeButton)?.isHidden = true
            
            centerWindow(panel)
            panel.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            
            self.window = panel
        }
    }
    
    private func centerWindow(_ window: NSWindow) {
        if let screenFrame = NSScreen.main?.visibleFrame {
            let newOriginX = (screenFrame.width - window.frame.width) / 2
            let newOriginY = (screenFrame.height - window.frame.height) / 2 + screenFrame.minY
            window.setFrameOrigin(NSPoint(x: newOriginX, y: newOriginY))
        }
    }
}