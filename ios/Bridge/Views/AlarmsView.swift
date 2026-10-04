import AlarmKit
import SwiftUI

@available(iOS 26.0, *)
struct AlarmsView: View {
    @State private var records: [AlarmRecord] = []
    @State private var deletion: AlarmRecord?
    @State private var error: String?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        List {
            if records.isEmpty { Text("暂时没有 Bridge 闹钟。") }
            ForEach(records) { record in
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.title).font(.headline)
                    Text(record.date.formatted(date: .complete, time: .shortened))
                    Button("取消闹钟", role: .destructive) { deletion = record }
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("我的闹钟")
        .onAppear { refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        .confirmationDialog("取消这个闹钟？", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })) {
            if let record = deletion {
                Button("取消「\(record.title)」", role: .destructive) {
                    do { try AlarmManager.shared.cancel(id: record.id); deletion = nil; refresh() }
                    catch { self.error = error.localizedDescription }
                }
            }
            Button("保留", role: .cancel) { deletion = nil }
        }
    }
    private func refresh() {
        do {
            let alarms = try AlarmManager.shared.alarms
            let ids = Set(alarms.map(\.id))
            AlarmRecords.retain(ids: ids)
            let saved = AlarmRecords.all
            records = saved
            // Even if local metadata was lost, an existing system alarm remains cancellable.
            for alarm in alarms where !saved.contains(where: { $0.id == alarm.id }) {
                let date: Date
                if let schedule = alarm.schedule, case .fixed(let scheduled) = schedule { date = scheduled }
                else { date = Date() }
                records.append(AlarmRecord(id: alarm.id, title: "Bridge 闹钟", date: date))
            }
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}
