import SwiftUI

/// Pushes every saved floor plan, as JSON, to the small Python receiver in
/// `tools/lexdar_receiver.py` running on a computer on the same network.
struct LANSyncView: View {
    @EnvironmentObject private var store: ScanStore
    @AppStorage("lanSyncURL") private var serverURL = ""
    @AppStorage("lanSyncToken") private var sharedToken = ""
    @State private var status = ""
    @State private var isSending = false

    var body: some View {
        Form {
            Section("Desktop receiver") {
                TextField("http://192.168.1.20:8765", text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField("Shared token", text: $sharedToken)
            }
            Section {
                Button {
                    Task { await send() }
                } label: {
                    Label("Send all floor plans", systemImage: "arrow.up.circle")
                }
                .disabled(isSending || serverURL.isEmpty)
                if !status.isEmpty {
                    Text(status).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Setup") {
                Text("On the computer run: python3 tools/lexdar_receiver.py --token YOUR_TOKEN. Use the same token here. Plans arrive as JSON in a received folder. The connection is plain HTTP, so use a network you trust.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Sync to Desktop")
    }

    @MainActor
    private func send() async {
        guard let base = URL(string: serverURL.trimmingCharacters(in: .whitespaces)),
              base.scheme == "http" || base.scheme == "https" else {
            status = "Enter a full address such as http://192.168.1.20:8765"
            return
        }
        isSending = true
        defer { isSending = false }
        var sent = 0
        for plan in store.floorPlans {
            var request = URLRequest(url: base.appendingPathComponent("upload"))
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(sharedToken, forHTTPHeaderField: "X-Lexdar-Token")
            request.httpBody = Data(PlanScheduleExport.json(for: plan).utf8)
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    status = "The receiver rejected \(plan.name) (check the token). Sent \(sent) before that."
                    return
                }
                sent += 1
            } catch {
                status = "Couldn't reach the receiver: \(error.localizedDescription)"
                return
            }
        }
        status = "Sent \(sent) floor plan\(sent == 1 ? "" : "s")."
    }
}
