import Foundation
import SwiftUI
import UIKit

enum AppSettings {
    static let appName = "Greenhouse Helper"
    static let poweredBy = "Powered by bloomlogic"
    static let backendBaseURL = URL(string: "http://10.0.0.196:8000")!
}

enum AppPalette {
    static let darkGreen = Color(red: 0.10, green: 0.23, blue: 0.16)
    static let green = Color(red: 0.34, green: 0.49, blue: 0.33)
    static let lightGreen = Color(red: 0.67, green: 0.82, blue: 0.56)
    static let white = Color.white
    static let black = Color.black
    static let surface = Color(red: 0.97, green: 0.98, blue: 0.96)
    static let card = Color.white
    static let cardBorder = Color(red: 0.84, green: 0.88, blue: 0.84)
    static let mutedText = Color(red: 0.31, green: 0.40, blue: 0.34)
}

enum AppFont {
    static func title(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("Inter", size: size, relativeTo: .title).weight(weight)
    }

    static func body(size: CGFloat = 17, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size, relativeTo: .body).weight(weight)
    }

    static func caption(size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size, relativeTo: .caption).weight(weight)
    }

    static func headline(size: CGFloat = 17, weight: Font.Weight = .semibold) -> Font {
        .custom("Inter", size: size, relativeTo: .headline).weight(weight)
    }
}
