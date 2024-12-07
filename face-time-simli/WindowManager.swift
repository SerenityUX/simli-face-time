import SwiftUI
import AppKit
import AVFoundation
import AVKit
import WebRTC

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

class CallWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

class FocusableHostingView<Content: View>: NSHostingView<Content>, WebRTCClientDelegate {
    var onEsc: () -> Void = {}
    override var acceptsFirstResponder: Bool { true }
    private var detailWindow: NSWindow?
    private var audioPlayer: AVAudioPlayer?
    private var webRTCClient: WebRTCClient?
    private var videoTrack: RTCVideoTrack?
    private var videoView: AVPlayerView?
    private var player: AVPlayer?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    
    override func keyDown(with event: NSEvent) {
        print("Key received in FocusableHostingView: \(event.keyCode)")
        
        switch event.keyCode {
        case 36: // Enter key
            print("Enter key pressed")
            
            // Close existing detail window and stop audio if it exists
            detailWindow?.close()
            audioPlayer?.stop()
            
            // Set up audio player
            if let soundURL = Bundle.main.url(forResource: "calling_sound", withExtension: "mp3") {
                print("Found sound URL: \(soundURL)")
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                    audioPlayer?.numberOfLoops = -1  // -1 means infinite loop
                    audioPlayer?.volume = 1.0  // Ensure full volume
                    let didPlay = audioPlayer?.play() ?? false
                    print("Audio player started: \(didPlay)")
                } catch {
                    print("Failed to create audio player: \(error)")
                }
            } else {
                print("Could not find calling_sound.mp3 in bundle")
            }
            
            let stateManager = ContactStateManager.shared
            let selectedContact = stateManager.contacts[stateManager.selectedIndex]
            print("Got selected contact: \(selectedContact.name)")
            
            // Create basic window first
            let newWindow = CallWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            newWindow.isMovableByWindowBackground = true
            
            // Create simple content with more details
            let hostingView = NSHostingView(rootView: 
                ZStack {
                    // Blurred background
                    AsyncImage(url: selectedContact.profilePictureURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 500, height: 500)
                            .blur(radius: 30)
                    } placeholder: {
                        Color(NSColor.windowBackgroundColor)
                    }
                    
                    // Inner glow and border
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white.opacity(0.1))
                                .shadow(color: Color.white.opacity(0.5), radius: 15, x: 0, y: 0)
                        )
                    
                    // Content
                    VStack(spacing: 20) {
                        AsyncImage(url: selectedContact.profilePictureURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } placeholder: {
                            ProgressView()
                                .frame(width: 100, height: 100)
                        }
                        
                        Text(selectedContact.name)
                            .font(.title)
                            .foregroundColor(.white)
                        Text(selectedContact.oneLiner)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            )
            
            // Set content and show
            newWindow.contentView = hostingView
            newWindow.backgroundColor = .clear
            newWindow.isOpaque = false
            
            // Enable window corner radius
            if let contentView = newWindow.contentView {
                contentView.wantsLayer = true
                contentView.layer?.cornerRadius = 24
                contentView.layer?.masksToBounds = true
                contentView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
            }
            
            // Center window on the main screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let windowFrame = newWindow.frame
                let newOriginX = (screenFrame.width - windowFrame.width) / 2
                let newOriginY = (screenFrame.height - windowFrame.height) / 2
                newWindow.setFrameOrigin(NSPoint(x: newOriginX, y: newOriginY))
            }
            
            print("About to show window")
            newWindow.makeKeyAndOrderFront(nil)
            newWindow.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            print("Window should be visible")
            
            // Store reference and close old window
            detailWindow = newWindow
            if let window = self.window {
                window.close()
            }
            
            webRTCClient = WebRTCClient()
            webRTCClient?.delegate = self
            webRTCClient?.startCall(with: "156e758d-5823-4d45-bb76-337188e70880")
            
        case 126: // Up arrow
            NotificationCenter.default.post(name: NSNotification.Name("MoveSelection"), object: true)
        case 125: // Down arrow
            NotificationCenter.default.post(name: NSNotification.Name("MoveSelection"), object: false)
        default:
            super.keyDown(with: event)
        }
    }
    
    deinit {
        detailWindow?.close()
        audioPlayer?.stop()  // Make sure to stop audio when view is destroyed
    }
    
    // Add WebRTCClientDelegate methods
    func webRTCClient(_ client: WebRTCClient, didReceiveHLSURL urlString: String) {
        print("\nDEBUG: WindowManager received HLS URL")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let url = URL(string: urlString) else {
                print("ERROR: Invalid HLS URL, trying MP4 fallback")
                return
            }
            
            print("DEBUG: Created valid URL object: \(url)")
            self.setupVideoPlayback(with: url)
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveMP4URL urlString: String) {
        print("\nDEBUG: WindowManager received MP4 URL: \(urlString)")
        
        DispatchQueue.main.async {
            guard let url = URL(string: urlString) else { 
                print("ERROR: Invalid MP4 URL")
                return 
            }
            
            print("DEBUG: Creating URL request")
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("video/mp4", forHTTPHeaderField: "Accept")
            
            print("DEBUG: Starting video download")
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                if let error = error {
                    print("ERROR: Download failed: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("ERROR: No data received")
                    return
                }
                
                print("DEBUG: Downloaded \(data.count) bytes")
                
                // Save to temporary file
                let tempDir = FileManager.default.temporaryDirectory
                let tempFile = tempDir.appendingPathComponent("temp_video.mp4")
                
                do {
                    try data.write(to: tempFile)
                    print("DEBUG: Saved video to: \(tempFile.path)")
                    
                    DispatchQueue.main.async {
                        print("DEBUG: Creating AVAsset")
                        let asset = AVAsset(url: tempFile)
                        
                        Task {
                            do {
                                print("DEBUG: Checking asset properties")
                                let duration = try await asset.load(.duration)
                                let tracks = try await asset.loadTracks(withMediaType: .video)
                                print("DEBUG: Video duration: \(duration.seconds)s")
                                print("DEBUG: Video tracks: \(tracks.count)")
                                
                                let playerItem = AVPlayerItem(asset: asset)
                                playerItem.addObserver(self!, forKeyPath: "status", options: [.new], context: nil)
                                
                                let player = AVPlayer(playerItem: playerItem)
                                player.actionAtItemEnd = .pause
                                
                                let videoView = AVPlayerView()
                                videoView.player = player
                                videoView.controlsStyle = .inline // Changed to show controls for debugging
                                videoView.showsFullScreenToggleButton = true
                                
                                if let window = self?.detailWindow {
                                    print("DEBUG: Setting up video in window")
                                    window.contentView?.subviews.forEach { $0.removeFromSuperview() }
                                    
                                    let containerView = NSView(frame: window.contentView?.bounds ?? .zero)
                                    containerView.wantsLayer = true
                                    containerView.layer?.cornerRadius = 24
                                    containerView.layer?.masksToBounds = true
                                    containerView.layer?.backgroundColor = NSColor.black.cgColor // Added black background
                                    
                                    videoView.frame = containerView.bounds
                                    videoView.autoresizingMask = [.width, .height]
                                    containerView.addSubview(videoView)
                                    
                                    window.contentView = containerView
                                    window.backgroundColor = .black // Added window background color
                                    
                                    // Monitor playback
                                    player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { time in
                                        let item = player.currentItem
                                        print("DEBUG: Playback status:")
                                        print("  - Time: \(time.seconds)s")
                                        print("  - Rate: \(player.rate)")
                                        print("  - Duration: \(item?.duration.seconds ?? 0)s")
                                        print("  - Status: \(item?.status.rawValue ?? -1)")
                                        print("  - Error: \(item?.error?.localizedDescription ?? "none")")
                                    }
                                    
                                    print("DEBUG: Starting playback from local file")
                                    self?.audioPlayer?.stop()
                                    player.play()
                                    self?.player = player
                                }
                            } catch {
                                print("ERROR: Failed to load asset: \(error)")
                            }
                        }
                    }
                } catch {
                    print("ERROR: Failed to save video: \(error.localizedDescription)")
                }
            }.resume()
        }
    }
    
    private func setupVideoPlayback(with url: URL) {
        print("DEBUG: Setting up video playback for URL: \(url)")
        
        // Stop the calling sound
        self.audioPlayer?.stop()
        print("DEBUG: Stopped calling sound")
        
        // Create video view
        let videoView = AVPlayerView(frame: .zero)
        videoView.controlsStyle = .none
        videoView.wantsLayer = true
        self.videoView = videoView
        
        // Try to load and play the video
        let asset = AVURLAsset(url: url)
        print("DEBUG: Created asset, attempting to load")
        
        Task {
            do {
                let status = try await asset.load(.isPlayable)
                print("DEBUG: Asset load status: \(status)")
                
                guard status else {
                    print("ERROR: Asset is not playable")
                    return
                }
                
                let playerItem = AVPlayerItem(asset: asset)
                print("DEBUG: Created player item")
                
                let player = AVPlayer(playerItem: playerItem)
                player.automaticallyWaitsToMinimizeStalling = true
                self.player = player
                videoView.player = player
                
                print("DEBUG: Player setup complete, updating window")
                
                if let window = self.detailWindow {
                    // Create container view
                    let containerView = NSView(frame: window.contentView?.bounds ?? .zero)
                    containerView.wantsLayer = true
                    containerView.layer?.cornerRadius = 24
                    containerView.layer?.masksToBounds = true
                    
                    // Set up video view
                    videoView.frame = containerView.bounds
                    videoView.autoresizingMask = [.width, .height]
                    containerView.addSubview(videoView)
                    
                    // Clear existing content and set new
                    window.contentView?.subviews.forEach { $0.removeFromSuperview() }
                    window.contentView = containerView
                    
                    print("DEBUG: Window content updated, starting playback")
                    player.play()
                    
                    // Monitor playback
                    player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 2), queue: .main) { [weak self] time in
                        let item = player.currentItem
                        print("DEBUG: Playback status: \(item?.status.rawValue ?? 0)")
                    }
                } else {
                    print("ERROR: No window available")
                }
            } catch {
                print("ERROR: Failed to load asset: \(error.localizedDescription)")
            }
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveRemoteVideoTrack track: RTCVideoTrack?) {
        // This method is still required by the protocol but we're not using it
        print("Received remote video track - ignoring in favor of HLS stream")
    }
    
    func webRTCClient(_ client: WebRTCClient, didRemoveRemoteVideoTrack track: RTCVideoTrack?) {
        // This method is still required by the protocol but we're not using it
        print("Remote video track removed - ignoring in favor of HLS stream")
    }
    
    func webRTCClient(_ client: WebRTCClient, didStopStream: Bool) {
        DispatchQueue.main.async {
            print("Stream stopped")
            self.player?.pause()
            self.player = nil
            
            // Optionally restore original view here
            if let window = self.detailWindow,
               let hostingView = window.contentView?.subviews.last {
                window.contentView = hostingView
            }
        }
    }
    
    // Add KVO observation
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status",
           let playerItem = object as? AVPlayerItem {
            switch playerItem.status {
            case .readyToPlay:
                print("DEBUG: Player item is ready to play")
            case .failed:
                print("ERROR: Player item failed: \(playerItem.error?.localizedDescription ?? "unknown error")")
                if let error = playerItem.error as NSError? {
                    print("ERROR details:")
                    print("  - Domain: \(error.domain)")
                    print("  - Code: \(error.code)")
                    print("  - User Info: \(error.userInfo)")
                }
            case .unknown:
                print("DEBUG: Player item status is unknown")
            @unknown default:
                print("DEBUG: Player item has unexpected status")
            }
        }
    }
    

}

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    private var window: CustomPanel?
    private let sharedContentView = ContentView()
    
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
            
            // Immediate focus
            if let hostingView = existingWindow.contentView?.subviews.first(where: { $0 is FocusableHostingView<ContentView> }) {
                existingWindow.makeFirstResponder(hostingView)
            }
        } else {
            let initialHeight = CGFloat(5 * 74) + 16
            let panel = CustomPanel(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: initialHeight),
                styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                backing: .buffered,
                defer: false
            )
            
            let keyHandlingView = KeyHandlingView()
            keyHandlingView.onEsc = { [weak panel] in
                panel?.close()
            }
            
            let hostingView = FocusableHostingView(rootView: sharedContentView)
            
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
            panel.hidesOnDeactivate = false
            
            centerWindow(panel)
            panel.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            
            // Immediate focus
            panel.makeFirstResponder(hostingView)
            
            // Enable window corner radius
            panel.isOpaque = false
            panel.backgroundColor = .clear
            if let contentView = panel.contentView {
                contentView.wantsLayer = true
                contentView.layer?.cornerRadius = 24
                contentView.layer?.masksToBounds = true
                contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            }
            
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
