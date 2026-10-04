import AlarmKit
import EventKit
import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct BridgeAlarmMetadata: AlarmMetadata { var title: String }

@MainActor
final class ActionExecutor {
    private let eventStore = EKEventStore()
    static var supportsAlarm: Bool { if #available(iOS 26.0, *) { return true }; return false }

    // Only called with a consumed confirmation. No model output is executable code or an arbitrary URL.
    func execute(_ item: PendingAction) async throws -> String {
        try item.validate(supportsAlarm: Self.supportsAlarm)
        let plan = item.plan
        switch plan.action {
        case .openApp:
            guard let app = plan.appID, UIApplication.shared.canOpenURL(app.url) else {
                throw BridgeFailure.permission("没有找到这个 App，请先安装或启用它。")
            }
            let opened = await UIApplication.shared.open(app.url)
            guard opened else { throw BridgeFailure.permission("系统未能打开这个 App。") }
            return "已请求系统打开\(app.name)。"
        case .createReminder:
            guard try await eventStore.requestFullAccessToReminders() else { throw BridgeFailure.permission("未获得提醒事项权限，没有创建提醒。") }
            try item.validate(supportsAlarm: Self.supportsAlarm)
            guard let calendar = eventStore.defaultCalendarForNewReminders() else {
                throw BridgeFailure.permission("请先在系统提醒事项 App 中创建一个列表。")
            }
            let reminder = EKReminder(eventStore: eventStore)
            reminder.calendar = calendar
            reminder.title = plan.title
            if let date = plan.date {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = .current
                reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .timeZone], from: date)
                reminder.addAlarm(EKAlarm(absoluteDate: date))
            }
            try eventStore.save(reminder, commit: true)
            return "已创建提醒：\(plan.title ?? "")。"
        case .setAlarm:
            if #available(iOS 26.0, *) {
                guard try await AlarmManager.shared.requestAuthorization() == .authorized else {
                    throw BridgeFailure.permission("未获得闹钟权限，没有设置闹钟。")
                }
                try item.validate(supportsAlarm: true)
                guard let date = plan.date, let title = plan.title else { throw BridgeFailure.invalidPlan }
                let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title),
                    stopButton: AlarmButton(text: "停止", textColor: .white, systemImageName: "stop.circle"))
                let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert),
                    metadata: BridgeAlarmMetadata(title: title), tintColor: Color.indigo)
                let configuration = AlarmManager.AlarmConfiguration.alarm(schedule: .fixed(date), attributes: attributes)
                _ = try await AlarmManager.shared.schedule(id: item.id, configuration: configuration)
                AlarmRecords.save(AlarmRecord(id: item.id, title: title, date: date))
                return "已设置闹钟：\(title)，\(date.formatted(date: .complete, time: .shortened))。"
            }
            throw BridgeFailure.permission("设置闹钟需要 iOS 26 或更新版本。")
        default: throw BridgeFailure.invalidPlan
        }
    }
}
