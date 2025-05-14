//
//  Functions.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/9/25.
//

import Foundation
import UIKit

func formattedDate(_ date: Date) -> String {
    let calendar = Calendar.current
    let now = Date()
    
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "h:mm a"
    let timeString = timeFormatter.string(from: date)
    
    if calendar.isDateInToday(date) {
        return "Today @ \(timeString)"
    } else if calendar.isDateInYesterday(date) {
        return "Yesterday @ \(timeString)"
    } else if let daysAgo = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day,
              daysAgo < 7, daysAgo > 1 {
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        let weekday = weekdayFormatter.string(from: date)
        return "\(weekday) @ \(timeString)"
    } else {
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "E, MMM d @ h:mm a"
        return fallbackFormatter.string(from: date)
    }
}

func triggerHapticFeedback() {
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.prepare()
    generator.impactOccurred()
}

func logThis(text: String, target: String = "APP", type: String = "") {

   
    let target = target.uppercased()
    let type = type.uppercased()
    if type != "" {
        NSLog("[\(target)] [\(type)]: \(text)")
    } else {
        NSLog("[\(target)]: \(text)")
    }
}

func printAllUserDefaults() {
    let allValues = UserDefaults.standard.dictionaryRepresentation()

    for (key, value) in allValues {
        print("\(key) = \(value)")
    }
}
