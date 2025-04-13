//
//  UserProfile.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/6/25.
//

import CloudKit
import Foundation
import PhotosUI
import UIKit

struct UserProfile: Identifiable {
    var id: CKRecord.ID
    var icloudID: String
    var username: String
    var fullName: String
    var joined: Date
    var image: UIImage?
    var friends: [String]

    init(id: CKRecord.ID, icloudID: String, username: String, fullName: String, joined: Date, image: UIImage? = nil, friends: [String] = []) {
        self.id = id
        self.icloudID = icloudID
        self.username = username
        self.fullName = fullName
        self.joined = joined
        self.image = image
        self.friends = friends
    }

    init(record: CKRecord) {
        self.id = record.recordID
        self.icloudID = record["icloudID"] as? String ?? ""
        self.username = record["username"] as? String ?? ""
        self.fullName = record["fullName"] as? String ?? ""
        self.joined = record["joined"] as? Date ?? Date()

        if let asset = record["avatar"] as? CKAsset,
           let fileURL = asset.fileURL,
           let data = try? Data(contentsOf: fileURL),
           let img = UIImage(data: data) {
            self.image = img
        } else {
            self.image = nil
        }
        self.friends = record["friends"] as? [String] ?? []
    }

    func toRecord(with image: UIImage?) -> CKRecord {
        let record = CKRecord(recordType: "UserProfile", recordID: id)
        record["icloudID"] = icloudID
        record["username"] = username
        record["fullName"] = fullName
        record["joined"] = joined

        if let image = image,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
            try? imageData.write(to: tempURL)
            record["avatar"] = CKAsset(fileURL: tempURL)
        }
        record["friends"] = friends


        return record
    }
}
