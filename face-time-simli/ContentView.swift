//
//  ContentView.swift
//  face-time-simli
//
//  Created by Thomas Stubblefield on 12/7/24.
//

import SwiftUI
import Foundation

struct Contact: Identifiable {
    let id = UUID()
    let name: String
    let profilePictureURL: URL
    let oneLiner: String
    let faceID: String
    
    static let example = Contact(
        name: "Kareem",
        profilePictureURL: URL(string: "https://kodan-videos.s3.us-east-2.amazonaws.com/2GPMNls.md.png")!,
        oneLiner: "a CS student",
        faceID: "123"
    )
}

struct ContentView: View {
    var body: some View {
        VStack {
            HStack{
                AsyncImage(url: Contact.example.profilePictureURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                } placeholder: {
                    ProgressView()
                        .frame(width: 42, height: 42)
                }
                VStack(alignment: .leading) {
                    Text(Contact.example.name)
                        .bold()
                    Text(Contact.example.oneLiner)
                        .opacity(0.6)
                }
                Spacer()
            Image(systemName: "phone.fill")
                .foregroundColor(.black.opacity(0.6))
                .font(.title2)
                .padding(.trailing, 8)
            }
        }
        .frame(width: 300)
        .padding()
    }
}

#Preview {
    ContentView()
}
