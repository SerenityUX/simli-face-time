//
//  face_time_simliApp.swift
//  face-time-simli
//
//  Created by Thomas Stubblefield on 12/7/24.
//

import SwiftUI
import HotKey

@main
struct face_time_simliApp: App {
    private let hotKey = HotKey(key: .y, modifiers: [.command, .shift])
    
    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        
        hotKey.keyDownHandler = {
            WindowManager.shared.toggleWindow()
        }
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
