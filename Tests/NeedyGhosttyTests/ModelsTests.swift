import Foundation
import Testing

@testable import NeedyGhosttyCore

@Suite("Models")
struct ModelsTests {
    @Test func notificationEntryRoundTrip() throws {
        let entry = NotificationEntry(
            session_id: "abc-123", terminal_id: "term-1",
            working_dir: "/home/user", cwd: "/project",
            name: "zsh", message: "Needs permission",
            timestamp: "2025-01-01T00:00:00Z")

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(NotificationEntry.self, from: data)
        #expect(decoded == entry)
    }

    @Test func sessionEntryRoundTrip() throws {
        let entry = SessionEntry(
            terminal_id: "term-1", name: "zsh",
            working_dir: "/home/user", cwd: "/project",
            started_at: "2025-01-01T00:00:00Z")

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(SessionEntry.self, from: data)
        #expect(decoded == entry)
    }

    @Test func hookInputDecodesPartialFields() throws {
        let json = #"{"session_id":"s1","cwd":"/tmp"}"#
        let input = try JSONDecoder().decode(HookInput.self, from: Data(json.utf8))
        #expect(input.session_id == "s1")
        #expect(input.cwd == "/tmp")
        #expect(input.message == nil)
        #expect(input.hook_event_name == nil)
    }

    @Test func hookInputDecodesAllFields() throws {
        let json = #"{"session_id":"s1","cwd":"/tmp","message":"hello","hook_event_name":"Notification"}"#
        let input = try JSONDecoder().decode(HookInput.self, from: Data(json.utf8))
        #expect(input.session_id == "s1")
        #expect(input.message == "hello")
        #expect(input.hook_event_name == "Notification")
    }

    @Test func sessionMapRoundTrip() throws {
        let map: [String: SessionEntry] = [
            "s1": SessionEntry(terminal_id: "t1", name: "zsh", working_dir: "/dir", cwd: "/cwd", started_at: "2025-01-01T00:00:00Z"),
        ]
        let data = try JSONEncoder().encode(map)
        let decoded = try JSONDecoder().decode([String: SessionEntry].self, from: data)
        #expect(decoded == map)
    }
}
