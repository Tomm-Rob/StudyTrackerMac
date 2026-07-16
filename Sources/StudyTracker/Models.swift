import Foundation
import SwiftUI
import AppKit

struct StudyData: Codable, Equatable {
    var classes: [StudyClass] = []
    var sessions: [StudySession] = []
    var chartSettings = ChartSettings()
}

struct StudyClass: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var colorHex: String
}

struct StudySession: Identifiable, Codable, Hashable {
    var id = UUID()
    var classID: UUID
    var date: Date
    var duration: TimeInterval
}

struct ChartSettings: Codable, Equatable {
    var dailyBarColorHex = "#2563EB"
}

struct DailyTotal: Identifiable {
    var id: Date { date }
    let date: Date
    let seconds: TimeInterval
}

struct ClassTotal: Identifiable {
    var id: UUID { studyClass.id }
    let studyClass: StudyClass
    let seconds: TimeInterval
}

enum SidebarSelection: Hashable {
    case dashboard
    case pomodoro
    case settings
    case studyClass(UUID)
}

extension TimeInterval {
    var hours: Double {
        self / 3600
    }

    var compactDuration: String {
        let totalSeconds = max(0, Int(self))
        if totalSeconds < 60 {
            return "\(totalSeconds)s"
        }

        let totalMinutes = totalSeconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        return "\(minutes)m"
    }

    var timerDuration: String {
        let totalSeconds = max(0, Int(self))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    var hhMMDuration: String {
        let totalMinutes = max(0, Int(self / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double

        switch cleaned.count {
        case 6:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        default:
            red = 0.2
            green = 0.2
            blue = 0.2
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    func hexString() -> String? {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else {
            return nil
        }

        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))

        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
