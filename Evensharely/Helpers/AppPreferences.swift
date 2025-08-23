//
//  AppPreferences.swift
//  Evensharely
//
//  Created by Marc Sebes on 5/16/25.
//
import Foundation

class AppPreferences: ObservableObject {
    static let shared = AppPreferences()
    
    @Published var useCondensedInbox: Bool {
        didSet {
            UserDefaults.standard.set(useCondensedInbox, forKey: "useCondensedInbox")
        }
    }
    
    init() {
        self.useCondensedInbox = UserDefaults.standard.bool(forKey: "useCondensedInbox")
    }
}
