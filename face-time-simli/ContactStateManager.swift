//
//  ContactStateManager.swift
//  face-time-simli
//
//  Created by Thomas Stubblefield on 12/7/24.
//

import Foundation
import SwiftUI

class ContactStateManager: ObservableObject {
    static let shared = ContactStateManager()
    
    @Published var selectedIndex: Int = 0
    @Published var contacts: [Contact] = [
        Contact(
            name: "Kareem",
            profilePictureURL: URL(string: "https://kodan-videos.s3.us-east-2.amazonaws.com/2GPMNls.md.png")!,
            oneLiner: "backend engineer",
            faceID: "123",
            isSelected: true
        ),
        Contact(
            name: "Thomas",
            profilePictureURL: URL(string: "https://kodan-videos.s3.us-east-2.amazonaws.com/Screenshot%202024-12-07%20at%201.40.37%E2%80%AFPM.png")!,
            oneLiner: "indie hacker",
            faceID: "124",
            isSelected: false
        ),
        Contact(
            name: "Lucas",
            profilePictureURL: URL(string: "https://kodan-videos.s3.us-east-2.amazonaws.com/Screenshot%202024-12-07%20at%201.19.46%E2%80%AFPM.png")!,
            oneLiner: "a CS student",
            faceID: "125",
            isSelected: false
        ),
        Contact(
            name: "Nuné",
            profilePictureURL: URL(string: "https://kodan-videos.s3.us-east-2.amazonaws.com/Screenshot%202024-12-07%20at%201.19.31%E2%80%AFPM.png")!,
            oneLiner: "startup consultant",
            faceID: "156e758d-5823-4d45-bb76-337188e70880",
            isSelected: false
        ),
        Contact(
            name: "Nasif",
            profilePictureURL: URL(string: "https://kodan-videos.s3.us-east-2.amazonaws.com/Screenshot%202024-12-07%20at%201.20.00%E2%80%AFPM.png")!,
            oneLiner: "postdoc",
            faceID: "127",
            isSelected: false
        )
    ]
    
    var selectedContact: Contact? {
        contacts.first(where: { $0.isSelected })
    }
}
