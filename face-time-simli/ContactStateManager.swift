//
//  ContactStateManager.swift
//  face-time-simli
//
//  Created by Thomas Stubblefield on 12/7/24.
//

import Foundation
import SwiftUI

public struct Contact: Identifiable, Codable {
    public let id = UUID()
    public let name: String
    public let profilePictureURL: URL
    public let oneLiner: String
    public let faceID: String
    public let voiceID: String
    public var isSelected: Bool
    public let systemPrompt: String
}

class ContactStateManager: ObservableObject {
    static let shared = ContactStateManager()
    
    @Published var selectedIndex: Int = 0
    @Published var contacts: [Contact] = [
        Contact(
            name: "Kareem",
            profilePictureURL: URL(string: "https://kodan-videos.s3.us-east-2.amazonaws.com/2GPMNls.md.png")!,
            oneLiner: "CS Student @ SF State",
            faceID: "4ba60fbd-2dc3-4113-82b0-d712d3e1c1d4",
            voiceID: "7360f116-6306-4e9a-b487-1235f35a0f21",
            isSelected: true,
            systemPrompt: """
            You are Kareem, a Computer Science student at SF State University. You live in the Sunset district of San Francisco. 
            You're passionate about technology and have impressive problem-solving skills, being able to solve a Rubik's cube in under 20 seconds. 
            Your communication style is friendly and enthusiastic, especially when discussing technology and computer science.
            """
        ),
        Contact(
            name: "Thomas",
            profilePictureURL: URL(string: "https://kodan-videos.s3.us-east-2.amazonaws.com/Screenshot%202024-12-07%20at%201.40.37%E2%80%AFPM.png")!,
            oneLiner: "indie hacker",
            faceID: "53e4db75-e026-4602-9e7c-810e4bc6eb78",
            voiceID: "7360f116-6306-4e9a-b487-1235f35a0f21",
            isSelected: false,
            systemPrompt: """
            You are Thomas, an indie hacker in San Francisco building tools to help people. You're passionate about 
            startups, coding, and building useful products. You enjoy discussing technology, entrepreneurship, and 
            the challenges of building products independently.
            """
        ),
        Contact(
            name: "Lucas",
            profilePictureURL: URL(string: "https://kodan-videos.s3.us-east-2.amazonaws.com/Screenshot%202024-12-07%20at%201.19.46%E2%80%AFPM.png")!,
            oneLiner: "software engineer",
            faceID: "c9571fb7-afbc-4c2c-bcee-88f9143736cf",
            voiceID: "7360f116-6306-4e9a-b487-1235f35a0f21",
            isSelected: false,
            systemPrompt: """
            You are Lucas, a backend software engineer from Brazil now living in San Francisco's Outer Sunset. 
            You came to SF for a hackathon to enjoy and make friends. You're passionate about backend development 
            and love playing football. Your Brazilian background gives you a unique perspective on tech and culture. 
            You enjoy discussing both technical topics and sports, especially football.
            """
        ),
        Contact(
            name: "Nuné",
            profilePictureURL: URL(string: "https://kodan-videos.s3.us-east-2.amazonaws.com/Screenshot%202024-12-07%20at%201.19.31%E2%80%AFPM.png")!,
            oneLiner: "startup consultant",
            faceID: "156e758d-5823-4d45-bb76-337188e70880",
            voiceID: "4d2fd738-3b3d-4368-957a-bb4805275bd9",
            isSelected: false,
            systemPrompt: """
            You are Nuné, an independent consultant for startups based in San Francisco. You have extensive experience 
            helping startups grow and succeed. You're adventurous and spontaneous, having once traveled to Argentina 
            within a day. You enjoy sharing insights about startup strategy, growth, and business development.
            """
        ),
        Contact(
            name: "Nasif",
            profilePictureURL: URL(string: "https://kodan-videos.s3.us-east-2.amazonaws.com/Screenshot%202024-12-07%20at%201.20.00%E2%80%AFPM.png")!,
            oneLiner: "postdoc researcher",
            faceID: "127",
            voiceID: "7360f116-6306-4e9a-b487-1235f35a0f21",
            isSelected: false,
            systemPrompt: """
            You are Nasif, a postdoctoral researcher in San Francisco. You're deeply passionate about accessibility 
            and making technology more inclusive for everyone. Your research background gives you unique insights 
            into how technology can better serve diverse populations. You enjoy discussing accessibility, research, 
            and ways to make technology more inclusive.
            """
        )
    ]
    
    var selectedContact: Contact? {
        contacts.first(where: { $0.isSelected })
    }
}

