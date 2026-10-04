import SwiftUI

@main
@MainActor
struct BridgeApp: App {
    @StateObject private var model = BridgeModel()
    var body: some Scene { WindowGroup { ContentView().environmentObject(model).environment(\.locale, Locale(identifier: "zh_CN")) } }
}
