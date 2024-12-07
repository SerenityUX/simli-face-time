//
//  WebRTCClient.swift
//  face-time-simli
//
//  Created by Thomas Stubblefield on 12/7/24.
//

import Foundation
import WebRTC
import AVFoundation
import CoreAudio

protocol WebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCClient, didReceiveHLSURL url: String)
    func webRTCClient(_ client: WebRTCClient, didStopStream: Bool)
    func webRTCClient(_ client: WebRTCClient, didReceiveRemoteVideoTrack track: RTCVideoTrack?)
    func webRTCClient(_ client: WebRTCClient, didRemoveRemoteVideoTrack track: RTCVideoTrack?)
    func webRTCClient(_ client: WebRTCClient, didReceiveMP4URL url: String)
}

class WebRTCClient: NSObject {
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()
    
    private let peerConnection: RTCPeerConnection
    private let audioQueue = DispatchQueue(label: "audio")
    private var localAudioTrack: RTCAudioTrack?
    
    weak var delegate: WebRTCClientDelegate?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false
    
    private static let API_KEY = "iozki0y5sujs44kraqcmf"
    
    override init() {
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        
        guard let peerConnection = WebRTCClient.factory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: nil
        ) else {
            fatalError("Failed to create peer connection")
        }
        
        self.peerConnection = peerConnection
        
        super.init()
        self.peerConnection.delegate = self
        self.configureAudioSession()
        self.createMediaSenders()
    }
    
    func startCall(with faceId: String) {
        self.createOffer { [weak self] sdp in
            self?.sendOfferToSignalingServer(sdp: sdp, faceId: faceId)
        }
    }
    
    private func configureAudioSession() {
        // For macOS, we'll use CoreAudio instead of AVAudioSession
        let audioID = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceID = AudioDeviceID()
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectGetPropertyData(
            audioID,
            &address,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        if status == noErr {
            // Successfully got the default input device
            print("Audio input device configured")
        } else {
            print("Failed to configure audio input device")
        }
    }
    
    private func createMediaSenders() {
        let audioTrack = createAudioTrack()
        self.peerConnection.add(audioTrack, streamIds: ["stream0"])
        self.localAudioTrack = audioTrack
    }
    
    private func createAudioTrack() -> RTCAudioTrack {
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = WebRTCClient.factory.audioSource(with: audioConstrains)
        let audioTrack = WebRTCClient.factory.audioTrack(with: audioSource, trackId: "audio0")
        return audioTrack
    }
    
    private func createOffer(completion: @escaping (RTCSessionDescription) -> Void) {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "true"
            ],
            optionalConstraints: nil
        )
        
        self.peerConnection.offer(for: constraints) { sdp, error in
            guard let sdp = sdp else { return }
            self.peerConnection.setLocalDescription(sdp) { error in
                completion(sdp)
            }
        }
    }
    
    private func sendOfferToSignalingServer(sdp: RTCSessionDescription, faceId: String) {
        // First establish WebRTC connection
        guard let url = URL(string: "wss://api.simli.ai/StartWebRTCSession") else { 
            print("Failed to create URL")
            return 
        }
        
        // Create URLRequest for the WebSocket connection
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create URLSession WebSocket task
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        
        // Start the WebSocket connection
        webSocketTask?.resume()
        print("WebSocket connection started")
        
        // Prepare and send the WebRTC offer
        let offerDict: [String: Any] = [
            "sdp": sdp.sdp,
            "type": sdp.type.rawValue
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: offerDict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Failed to serialize offer")
            return 
        }
        
        // Send the offer through WebSocket
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                print("WebSocket sending error: \(error)")
                self?.isConnected = false
            } else {
                print("Successfully sent offer to server")
                self?.isConnected = true
                // After successful WebSocket connection, prepare audio stream
                self?.setupAudioStream(faceId: faceId)
            }
        }
        
        // Add message handler for WebRTC signaling
        func receiveMessage() {
            webSocketTask?.receive { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        print("Received WebSocket message: \(text)")
                        if let data = text.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let type = json["type"] as? String,
                               type == "answer",
                               let sdp = json["sdp"] as? String {
                                print("Received SDP answer from server")
                                let answer = RTCSessionDescription(type: .answer, sdp: sdp)
                                self.peerConnection.setRemoteDescription(answer) { error in
                                    if let error = error {
                                        print("Failed to set remote description: \(error)")
                                    } else {
                                        print("Successfully set remote description")
                                    }
                                }
                            }
                        }
                    case .data(let data):
                        print("Received binary message: \(data.count) bytes")
                    @unknown default:
                        print("Unknown message type received")
                    }
                    
                    if self.isConnected {
                        receiveMessage()
                    }
                    
                case .failure(let error):
                    print("WebSocket receive error: \(error)")
                    self.isConnected = false
                }
            }
        }
        
        receiveMessage()
        print("Message receiver set up")
    }
    
    private func setupAudioStream(faceId: String) {
        guard let url = URL(string: "https://api.simli.ai/audioToVideoStream") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let audioStreamParams: [String: Any] = [
            "simliAPIKey": WebRTCClient.API_KEY,
            "faceId": faceId,
            "audioFormat": "pcm16",
            "audioSampleRate": 16000,
            "audioChannelCount": 1,
            "videoStartingFrame": 0,
            "audioBase64": "" // Empty for now as we're just starting the stream
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: audioStreamParams) else {
            print("Failed to serialize audio stream parameters")
            return
        }
        
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Audio stream setup failed: \(error)")
                return
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Audio stream setup response: \(json)")
                
                if let mp4Url = json["mp4_url"] as? String {
                    print("EUREKA! Got MP4 URL: \(mp4Url)")
                    DispatchQueue.main.async {
                        self?.delegate?.webRTCClient(self!, didReceiveMP4URL: mp4Url)
                    }
                }
            }
        }.resume()
    }
    
    // Add cleanup method
    func cleanup() {
        isConnected = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
    
    func handleAudioStreamResponse(_ json: [String: Any]) {
        print("\nDEBUG: Handling audio stream response")
        if let mp4Url = json["mp4_url"] as? String {
            print("EUREKA! Got MP4 URL: \(mp4Url)")
            DispatchQueue.main.async {
                self.delegate?.webRTCClient(self, didReceiveMP4URL: mp4Url)
            }
        }
    }
}

// MARK: - RTCPeerConnectionDelegate
extension WebRTCClient: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("peerConnection state changed: \(dataChannel)")
    }
    
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("peerConnection state changed: \(stateChanged)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("peerConnection did add stream")
        delegate?.webRTCClient(self, didReceiveRemoteVideoTrack: stream.videoTracks.first)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("peerConnection did remove stream")
        delegate?.webRTCClient(self, didRemoveRemoteVideoTrack: stream.videoTracks.first)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        print("peerConnection did add rtpReceiver")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("peerConnection should negotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("peerConnection ICE connection state changed: \(newState)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("peerConnection ICE gathering state changed: \(newState)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("peerConnection did generate candidate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("peerConnection did remove candidates")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove rtpReceiver: RTCRtpReceiver) {
        print("peerConnection did remove rtpReceiver")
    }
}
