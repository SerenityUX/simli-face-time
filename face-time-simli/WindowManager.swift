import SwiftUI
import AppKit

// Custom panel that can become key window
class CustomPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

class KeyHandlingView: NSView {
    var onEsc: () -> Void = {}
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            onEsc()
        } else {
            super.keyDown(with: event)
        }
    }
}

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    private var window: CustomPanel?
    
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
            let panel = CustomPanel(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 100),
                styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                backing: .buffered,
                defer: false
            )
            
            let keyHandlingView = KeyHandlingView()
            keyHandlingView.onEsc = { [weak panel] in
                panel?.close()
            }
            
            let hostingView = NSHostingView(rootView: 
                ContentView()
                    .padding(.vertical, 32)
            )
            
            hostingView.setFrameSize(hostingView.fittingSize)
            
            let containerView = NSView()
            containerView.wantsLayer = true
            containerView.layer?.cornerRadius = 16
            containerView.layer?.masksToBounds = true
            
            containerView.addSubview(keyHandlingView)
            containerView.addSubview(hostingView)
            
            keyHandlingView.frame = containerView.bounds
            keyHandlingView.autoresizingMask = [.width, .height]
            hostingView.frame = containerView.bounds
            hostingView.autoresizingMask = [.width, .height]
            
            panel.contentView = containerView
            panel.backgroundColor = NSColor.windowBackgroundColor
            panel.isMovableByWindowBackground = true
            panel.level = .floating
            panel.collectionBehavior = [.transient, .ignoresCycle]
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = true
            
            // Enable window corner radius
            panel.isOpaque = false
            panel.backgroundColor = .clear
            if let contentView = panel.contentView {
                contentView.wantsLayer = true
                contentView.layer?.cornerRadius = 16
                contentView.layer?.masksToBounds = true
                contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            }
            
            panel.setContentSize(hostingView.fittingSize)
            
            centerWindow(panel)
            panel.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            panel.makeFirstResponder(keyHandlingView)
            
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