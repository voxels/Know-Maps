//
//  StoryRabbitSettingsView.swift
//  hopit
//
//  Created by Michael A Edgcumbe on 10/3/25.
//

import SwiftUI

struct StoryRabbitSettingsView: View {
    
    @State private var updateAvailable:Bool = false
    var body: some View {
        VStack(alignment: .center) {
            Image(systemName: "gear")
            Text("App Version 1.0.0")
                .font(.footnote)
                .foregroundColor(.secondary)
            if updateAvailable {
                Button("Update App Available") {
                    
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            List {
                Section {
                    Button("Notifications", systemImage: "bell") {
                        
                    }
                    Button("Send Feedback", systemImage: "exclamationmark.bubble") {
                        
                    }
                    Button("Privacy Policy", systemImage: "person.badge.key") {
                        
                    }
                    Button("Terms of Use", systemImage: "checkmark.shield") {
                        
                    }
                    Button("About StoryRabbit", systemImage:"info.circle") {
                        
                    }
                }
                Section {
                    Button("Delete Hopit Account", systemImage:"trash") {
                        
                    }
                    .tint(Color(.systemRed))
                    Button("Delete Hopit Data from iCloud", systemImage:"xmark.icloud") {
                        
                    }
                    .tint(Color(.systemRed))
                }
                Section {
                    Button("Log Out", systemImage: "rectangle.portrait.and.arrow.right") {
                        // handle log out
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .tint(.accent)
                }
            }
        }
    }
}

#Preview {
    StoryRabbitSettingsView()
}
