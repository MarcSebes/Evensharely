//
//  Constants.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/6/25.
//

import Foundation
let appGroupID = "group.com.marcsebes.evensharely"

import CloudKit

enum CloudKitConfig {
    static let containerID = "iCloud.com.marcsebes.evensharely"
    static let container = CKContainer(identifier: containerID)
}
