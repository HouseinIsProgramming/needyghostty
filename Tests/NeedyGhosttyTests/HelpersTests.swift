import Foundation
import Testing

@testable import NeedyGhosttyCore

@Suite("Helpers")
struct HelpersTests {
    @Test func relativeTimeJustNow() {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        let now = f.string(from: Date())
        #expect(relativeTime(now) == "just now")
    }

    @Test func relativeTimeSeconds() {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        let past = f.string(from: Date().addingTimeInterval(-30))
        #expect(relativeTime(past) == "30s ago")
    }

    @Test func relativeTimeMinutes() {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        let past = f.string(from: Date().addingTimeInterval(-120))
        #expect(relativeTime(past) == "2m ago")
    }

    @Test func relativeTimeHours() {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        let past = f.string(from: Date().addingTimeInterval(-7200))
        #expect(relativeTime(past) == "2h ago")
    }

    @Test func relativeTimeDays() {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        let past = f.string(from: Date().addingTimeInterval(-172800))
        #expect(relativeTime(past) == "2d ago")
    }

    @Test func relativeTimeInvalidReturnsEmpty() {
        #expect(relativeTime("not-a-date") == "")
    }

    @Test func isoTimestampIsValid() {
        let ts = isoTimestamp()
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        #expect(f.date(from: ts) != nil)
    }

    @Test func notificationTypeAction() {
        #expect(NotificationType(message: "Needs permission to write") == .action)
        #expect(NotificationType(message: "Asking a question") == .action)
    }

    @Test func notificationTypeIdle() {
        #expect(NotificationType(message: "Waiting for input") == .idle)
        #expect(NotificationType(message: "Task complete") == .idle)
    }
}
