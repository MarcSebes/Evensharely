//
//  UserProfile.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/6/25.
//  Updated to include SignIn with Apple support
//

import CloudKit
import Foundation
import PhotosUI
import UIKit

struct UserProfile: Identifiable, Codable {
    var id: CKRecord.ID
    var icloudID: String
    var username: String
    var fullName: String
    var joined: Date
    var image: UIImage?
    var friends: [String]
    var appleUserID: String
    var email: String?

    enum CodingKeys: String, CodingKey {
        case recordName
        case icloudID
        case username
        case fullName
        case joined
        case friends
        case appleUserID
        case email
    }

    // MARK: - Initializers

    init(id: CKRecord.ID,
         icloudID: String,
         username: String,
         fullName: String,
         joined: Date,
         image: UIImage? = nil,
         friends: [String] = [],
         appleUserID: String = "",
         email: String? = nil) {
        self.id = id
        self.icloudID = icloudID
        self.username = username
        self.fullName = fullName
        self.joined = joined
        self.image = image
        self.friends = friends
        self.appleUserID = appleUserID
        self.email = email
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
        self.appleUserID = record["appleUserID"] as? String ?? ""
        self.email = record["email"] as? String
    }

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let recordName = try container.decode(String.self, forKey: .recordName)
        self.id = CKRecord.ID(recordName: recordName)
        self.icloudID = try container.decode(String.self, forKey: .icloudID)
        self.username = try container.decode(String.self, forKey: .username)
        self.fullName = try container.decode(String.self, forKey: .fullName)
        self.joined = try container.decode(Date.self, forKey: .joined)
        self.friends = try container.decode([String].self, forKey: .friends)
        self.appleUserID = try container.decode(String.self, forKey: .appleUserID)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.image = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.recordName, forKey: .recordName)
        try container.encode(icloudID, forKey: .icloudID)
        try container.encode(username, forKey: .username)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(joined, forKey: .joined)
        try container.encode(friends, forKey: .friends)
        try container.encode(appleUserID, forKey: .appleUserID)
        try container.encodeIfPresent(email, forKey: .email)
    }

    // MARK: - CloudKit Conversion

    func toRecord(with image: UIImage?) -> CKRecord {
        let record = CKRecord(recordType: "UserProfile", recordID: id)
        record["icloudID"] = icloudID as CKRecordValue
        record["username"] = username as CKRecordValue
        record["fullName"] = fullName as CKRecordValue
        record["joined"] = joined as CKRecordValue

        if let image = image,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString).jpg")
            try? imageData.write(to: tempURL)
            record["avatar"] = CKAsset(fileURL: tempURL)
        }

        record["friends"] = friends as CKRecordValue
        record["appleUserID"] = appleUserID as CKRecordValue
        if let e = email {
            record["email"] = e as CKRecordValue
        }

        return record
    }
}
