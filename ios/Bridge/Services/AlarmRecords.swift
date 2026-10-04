import Foundation

struct AlarmRecord: Codable, Identifiable {
    let id: UUID
    let title: String
    let date: Date
}
enum AlarmRecords {
    static var all: [AlarmRecord] {
        guard let data = UserDefaults.standard.data(forKey: "alarmRecords"),
              let records = try? JSONDecoder().decode([AlarmRecord].self, from: data) else { return [] }
        return records.sorted { $0.date < $1.date }
    }
    static func save(_ record: AlarmRecord) {
        let records = all.filter { $0.id != record.id } + [record]
        UserDefaults.standard.set(try? JSONEncoder().encode(records), forKey: "alarmRecords")
    }
    static func retain(ids: Set<UUID>) {
        UserDefaults.standard.set(try? JSONEncoder().encode(all.filter { ids.contains($0.id) }), forKey: "alarmRecords")
    }
}
