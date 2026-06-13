import SwiftUI

/// Shared styling for establishments with no hygiene score yet (never had a
/// valid Pass/Conditions/Fail inspection). Distinct from the green/amber/red
/// score bands and from the gray "out of business" status.
enum RatingStyle {
    /// Slate blue-gray for "no rating yet".
    static let noScore = Color(red: 0.45, green: 0.50, blue: 0.58)
}
