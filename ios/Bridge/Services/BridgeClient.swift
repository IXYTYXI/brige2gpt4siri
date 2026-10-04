import Foundation

// Do not forward the app's bearer token to redirects, including an HTTP downgrade.
final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

struct BridgeClient {
    private struct Request: Encodable { let text: String; let timezone: String; let supports_alarm: Bool }
    private struct Response: Decodable { let plan: ActionPlan }
    private struct Failure: Decodable { struct Detail: Decodable { let message: String }; let error: Detail }
    func plan(text: String, supportsAlarm: Bool) async throws -> ActionPlan {
        guard let base = SettingsStore.validURL(SettingsStore.endpoint), !SettingsStore.token().isEmpty else { throw BridgeFailure.configuration }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 35
        config.timeoutIntervalForResource = 40
        let session = URLSession(configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: base.appendingPathComponent("v1/plan"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + SettingsStore.token(), forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(Request(text: text, timezone: TimeZone.current.identifier, supports_alarm: supportsAlarm))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BridgeFailure.network("服务响应无效。") }
        guard http.statusCode == 200 else {
            let message = (try? JSONDecoder().decode(Failure.self, from: data).error.message) ?? "请求失败，请检查服务地址与网络。"
            throw BridgeFailure.network(message)
        }
        guard data.count < 32768 else { throw BridgeFailure.invalidPlan }
        let plan = try JSONDecoder().decode(Response.self, from: data).plan
        try plan.validate(supportsAlarm: supportsAlarm)
        return plan
    }
}
