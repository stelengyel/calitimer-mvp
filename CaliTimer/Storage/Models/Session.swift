import SwiftData
import Foundation

@Model
final class Session {
    var startedAt: Date
    var skill: String           // "Handstand" in Phase 2; multi-skill in Phase 9
    var targetDuration: TimeInterval?  // nil = no target set; positive = seconds

    init(skill: String, targetDuration: TimeInterval?) {
        self.startedAt = Date()
        self.skill = skill
        self.targetDuration = targetDuration
    }
}
