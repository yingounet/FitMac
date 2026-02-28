import SwiftUI

enum FitMacSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 32
}

enum FitMacAnimation {
    static let `default`: Animation = .easeInOut(duration: 0.25)
    static let progress: Animation = .easeInOut(duration: 0.3)
    static let spring: Animation = .spring(response: 0.3, dampingFraction: 0.7)
}

enum FitMacColor {
    enum Status {
        static func forUsage(_ percentage: Double) -> Color {
            if percentage < 60 { return .green }
            if percentage < 80 { return .orange }
            return .red
        }
        
        static func forDiskUsage(_ percentage: Double) -> Color {
            if percentage < 70 { return .green }
            if percentage < 90 { return .orange }
            return .red
        }
    }
    
    enum Category {
        static let cache = Color.orange
        static let trash = Color.red
        static let largeFiles = Color.purple
        static let duplicates = Color.purple
        static let uninstall = Color.secondary
        static let system = Color.blue
        static let homebrew = Color.brown
        static let mail = Color.blue
        static let itunes = Color.pink
        static let language = Color.cyan
        static let loginItems = Color.indigo
    }
}

struct FitMacFonts {
    static let title = Font.system(size: 48, weight: .bold, design: .rounded)
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let headline = Font.headline
    static let body = Font.body
    static let caption = Font.caption
    static let monospaced = Font.system(.body, design: .monospaced)
}
