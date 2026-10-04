import Foundation

enum BridgeFailure: LocalizedError {
    case invalidPlan, expiredPlan, permission(String), configuration, network(String), busy
    var errorDescription: String? {
        switch self {
        case .invalidPlan: return "无法可靠理解这个操作，请重新表达。"
        case .expiredPlan: return "操作已过期，请重新提出请求。"
        case .permission(let message), .network(let message): return message
        case .configuration: return "请先在设置中保存 HTTPS 服务地址和服务令牌。"
        case .busy: return "请等待当前操作完成。"
        }
    }
}

enum ActionKind: String, Codable { case reply, clarify, unsupported, openApp = "open_app", createReminder = "create_reminder", setAlarm = "set_alarm" }
enum AllowedApp: String, Codable, CaseIterable {
    case maps, music, wechat
    var name: String { switch self { case .maps: return "地图"; case .music: return "音乐"; case .wechat: return "微信" } }
    var url: URL {
        switch self {
        case .maps: return URL(string: "maps://")!
        case .music: return URL(string: "music://")!
        case .wechat: return URL(string: "weixin://")!
        }
    }
}

struct ActionPlan: Codable, Equatable {
    let action: ActionKind
    let appID: AllowedApp?
    let title: String?
    let at: String?
    let replyZH: String
    enum CodingKeys: String, CodingKey { case action, appID = "app_id", title, at, replyZH = "reply_zh" }
    var requiresConfirmation: Bool { [.openApp, .createReminder, .setAlarm].contains(action) }
    var date: Date? {
        guard let at else { return nil }
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withInternetDateTime]
        return format.date(from: at)
    }
    func validate(now: Date = Date(), supportsAlarm: Bool) throws {
        guard !replyZH.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, replyZH.count <= 1000 else { throw BridgeFailure.invalidPlan }
        switch action {
        case .reply, .clarify, .unsupported:
            guard appID == nil, title == nil, at == nil else { throw BridgeFailure.invalidPlan }
        case .openApp:
            guard appID != nil, title == nil, at == nil else { throw BridgeFailure.invalidPlan }
        case .createReminder, .setAlarm:
            guard appID == nil, let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= 120 else { throw BridgeFailure.invalidPlan }
            if let at {
                // Round trip rejects invalid dates Foundation might normalize.
                let pattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})$"#
                guard at.range(of: pattern, options: .regularExpression) != nil, let date,
                      date > now, date.timeIntervalSince(now) <= 366 * 86400 else { throw BridgeFailure.invalidPlan }
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                if at.hasSuffix("Z") { formatter.timeZone = TimeZone(secondsFromGMT: 0) }
                else {
                    let suffix = String(at.suffix(6))
                    let parts = suffix.dropFirst().split(separator: ":")
                    guard let hours = Int(parts[0]), let minutes = Int(parts[1]), hours <= 14, minutes <= 59, hours != 14 || minutes == 0 else { throw BridgeFailure.invalidPlan }
                    formatter.timeZone = TimeZone(secondsFromGMT: (hours * 3600 + minutes * 60) * (suffix.first == "-" ? -1 : 1))
                }
                guard formatter.string(from: date).prefix(19) == at.prefix(19) else { throw BridgeFailure.invalidPlan }
            }
            if action == .setAlarm && (!supportsAlarm || date == nil) { throw BridgeFailure.invalidPlan }
        }
    }
    func summary() -> String {
        let when = date.map { "\n时间：" + $0.formatted(date: .complete, time: .shortened) } ?? ""
        switch action {
        case .openApp: return "打开\(appID?.name ?? "App")"
        case .createReminder: return "创建提醒：\(title ?? "")\(when)"
        case .setAlarm: return "设置一次性闹钟：\(title ?? "")\(when)"
        default: return replyZH
        }
    }
}

struct PendingAction: Identifiable {
    let id: UUID
    let plan: ActionPlan
    let createdAt: Date
    init(plan: ActionPlan, now: Date = Date()) { id = UUID(); self.plan = plan; createdAt = now }
    func validate(now: Date = Date(), supportsAlarm: Bool) throws {
        guard now.timeIntervalSince(createdAt) >= 0, now.timeIntervalSince(createdAt) < 300 else { throw BridgeFailure.expiredPlan }
        try plan.validate(now: now, supportsAlarm: supportsAlarm)
    }
}

// A plan can be consumed once, before execution starts, including after a failed operation.
struct ConfirmationGate {
    private(set) var pending: PendingAction?
    mutating func stage(_ plan: ActionPlan, now: Date = Date()) { pending = PendingAction(plan: plan, now: now) }
    mutating func cancel() { pending = nil }
    mutating func consume(id: UUID, now: Date = Date(), supportsAlarm: Bool) throws -> PendingAction {
        guard let item = pending, item.id == id else { throw BridgeFailure.expiredPlan }
        pending = nil
        try item.validate(now: now, supportsAlarm: supportsAlarm)
        guard item.plan.requiresConfirmation else { throw BridgeFailure.invalidPlan }
        return item
    }
}
