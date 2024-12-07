//
//  ContentView.swift
//  face-time-simli
//
//  Created by Thomas Stubblefield on 12/7/24.
//

import SwiftUI
import Foundation

public struct Contact: Identifiable {
    public let id = UUID()
    public let name: String
    public let profilePictureURL: URL
    public let oneLiner: String
    public let faceID: String
    public var isSelected: Bool
}

public struct ContentView: View {
    @StateObject private var stateManager = ContactStateManager.shared
    
    public var body: some View {
        VStack(spacing: 8) {
            // All contacts except the last one, with dividers
            ForEach(stateManager.contacts.dropLast()) { contact in
                HStack {
                    AsyncImage(url: contact.profilePictureURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 42, height: 42)
                            .clipShape(Circle())
                    } placeholder: {
                        ProgressView()
                            .frame(width: 42, height: 42)
                    }
                    VStack(alignment: .leading) {
                        Text(contact.name)
                            .bold()
                        Text(contact.oneLiner)
                            .opacity(0.6)
                    }
                    Spacer()
                    Image(systemName: "phone.fill")
                        .font(.title2)
                        .padding(.trailing, 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .foregroundColor(contact.isSelected ? .white : .black)
                .background(
                    Group {
                        if contact.isSelected {
                            Color.blue
                                .cornerRadius(16)
                                .padding(.horizontal, 8)
                        }
                    }
                )
                
                Divider()
                    .padding(.horizontal, 16)
            }
            
            // Last contact without divider
            if let lastContact = stateManager.contacts.last {
                HStack {
                    AsyncImage(url: lastContact.profilePictureURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 42, height: 42)
                            .clipShape(Circle())
                    } placeholder: {
                        ProgressView()
                            .frame(width: 42, height: 42)
                    }
                    VStack(alignment: .leading) {
                        Text(lastContact.name)
                            .bold()
                        Text(lastContact.oneLiner)
                            .opacity(0.6)
                    }
                    Spacer()
                    Image(systemName: "phone.fill")
                        .font(.title2)
                        .padding(.trailing, 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .foregroundColor(lastContact.isSelected ? .white : .black)
                .background(
                    Group {
                        if lastContact.isSelected {
                            Color.blue
                                .cornerRadius(16)
                                .padding(.horizontal, 8)
                        }
                    }
                )
            }
            
            // Debug text to show current selection
            Text("made with <3")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(width: 450)
        .padding()
        .focusable(true)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            
            // Set up notification observer
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("MoveSelection"),
                object: nil,
                queue: .main
            ) { notification in
                if let moveUp = notification.object as? Bool {
                    var updatedContacts = self.stateManager.contacts
                    updatedContacts[stateManager.selectedIndex].isSelected = false
                    
                    if moveUp {
                        stateManager.selectedIndex = stateManager.selectedIndex > 0 ? stateManager.selectedIndex - 1 : stateManager.contacts.count - 1
                    } else {
                        stateManager.selectedIndex = stateManager.selectedIndex < stateManager.contacts.count - 1 ? stateManager.selectedIndex + 1 : 0
                    }
                    
                    updatedContacts[stateManager.selectedIndex].isSelected = true
                    self.stateManager.contacts = updatedContacts
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
