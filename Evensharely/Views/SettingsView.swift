//
//  SettingsView.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/13/25.
//

import SwiftUI

struct SettingsView: View {
    func tempAction() {
        print("done")
    }
    
    
    var body: some View {
        NavigationStack{
            List {
                Section("System Settings") {
                    Button(action: tempAction) {
                        Label("Allow App Icon Counter", systemImage: "number.circle")
                    }
                    Button(action: tempAction) {
                        Label("Mark All As Read", systemImage: "flag.slash")
                    }
                    
                    
                }
            }
            .navigationTitle(Text("Settings"))
            
        }
    }
}

#Preview {
    SettingsView()
}
