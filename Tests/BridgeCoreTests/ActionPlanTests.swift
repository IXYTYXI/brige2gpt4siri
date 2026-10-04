import XCTest
@testable import BridgeCore

final class ActionPlanTests: XCTestCase {
    let now = ISO8601DateFormatter().date(from: "2026-10-04T12:00:00Z")!
    func reminder(at: String? = "2026-10-05T18:00:00-04:00") -> ActionPlan {
        ActionPlan(action: .createReminder, appID: nil, title: "买牛奶", at: at, replyZH: "准备创建提醒。")
    }
    func testReminderAndTimezone() throws {
        let plan = reminder()
        try plan.validate(now: now, supportsAlarm: true)
        XCTAssertEqual(plan.date, ISO8601DateFormatter().date(from: "2026-10-05T22:00:00Z"))
        XCTAssertTrue(plan.requiresConfirmation)
        try reminder(at: nil).validate(now: now, supportsAlarm: false)
    }
    func testBadDatesRejected() {
        for at in ["tomorrow", "2026-10-05T08:00:00", "2026-10-03T08:00:00Z", "2027-10-07T08:00:00Z", "2027-02-30T08:00:00Z", "2026-10-05T08:00:00+15:00"] {
            XCTAssertThrowsError(try reminder(at: at).validate(now: now, supportsAlarm: true), at)
        }
    }
    func testUnknownActionsAndAppsFailDecoding() {
        for value in [#"{"action":"send_message","reply_zh":"发送"}"#,
                      #"{"action":"open_app","app_id":"tel:123","reply_zh":"打开"}"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(ActionPlan.self, from: Data(value.utf8)))
        }
    }
    func testAlarmRequiresSupportedDeviceAndTime() {
        let alarm = ActionPlan(action: .setAlarm, appID: nil, title: "起床", at: reminder().at, replyZH: "准备设置。")
        XCTAssertThrowsError(try alarm.validate(now: now, supportsAlarm: false))
        XCTAssertNoThrow(try alarm.validate(now: now, supportsAlarm: true))
        XCTAssertThrowsError(try ActionPlan(action: .setAlarm, appID: nil, title: "起床", at: nil, replyZH: "准备设置。").validate(now: now, supportsAlarm: true))
    }
    func testPassiveResponsesCannotCarryActions() {
        let plan = ActionPlan(action: .reply, appID: .wechat, title: nil, at: nil, replyZH: "你好")
        XCTAssertThrowsError(try plan.validate(now: now, supportsAlarm: true))
    }
    func testConfirmationConsumedOnlyOnce() throws {
        var gate = ConfirmationGate(); gate.stage(reminder(), now: now)
        let id = try XCTUnwrap(gate.pending?.id)
        XCTAssertEqual(try gate.consume(id: id, now: now, supportsAlarm: true).plan, reminder())
        XCTAssertThrowsError(try gate.consume(id: id, now: now, supportsAlarm: true))
    }
    func testCancelPreventsExecution() throws {
        var gate = ConfirmationGate(); gate.stage(reminder(), now: now)
        let id = try XCTUnwrap(gate.pending?.id); gate.cancel()
        XCTAssertThrowsError(try gate.consume(id: id, now: now, supportsAlarm: true))
    }
    func testStaleConfirmationCannotExecuteReplacement() throws {
        var gate = ConfirmationGate(); gate.stage(reminder(), now: now)
        let old = try XCTUnwrap(gate.pending?.id); gate.stage(reminder(at: nil), now: now)
        XCTAssertThrowsError(try gate.consume(id: old, now: now, supportsAlarm: true))
        XCTAssertNotNil(gate.pending)
    }
    func testConfirmationExpiresAndCannotBeRetried() throws {
        var gate = ConfirmationGate(); gate.stage(reminder(), now: now)
        let id = try XCTUnwrap(gate.pending?.id)
        XCTAssertThrowsError(try gate.consume(id: id, now: now.addingTimeInterval(300), supportsAlarm: true))
        XCTAssertNil(gate.pending)
    }
    func testDueDateRecheckedAtExecution() throws {
        var gate = ConfirmationGate(); gate.stage(reminder(at: "2026-10-04T12:00:30Z"), now: now)
        let id = try XCTUnwrap(gate.pending?.id)
        XCTAssertThrowsError(try gate.consume(id: id, now: now.addingTimeInterval(31), supportsAlarm: true))
    }
}
