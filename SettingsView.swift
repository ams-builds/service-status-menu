import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: StatusStore
    @State private var newName: String = ""
    @State private var newURL: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Manage Services")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if let error = store.configurationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            List {
                ForEach(store.services) { service in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(service.name)
                                .font(.body.weight(.medium))
                            Text(service.url.absoluteString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            store.removeService(id: service.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Remove \(service.name)")
                    }
                    .padding(.vertical, 3)
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 220)

            Divider()

            HStack(spacing: 8) {
                TextField("Service name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                TextField("https://status.example.com", text: $newURL)
                    .textFieldStyle(.roundedBorder)
                Button {
                    store.addService(name: newName, urlString: newURL)
                    if store.configurationError == nil {
                        newName = ""
                        newURL = ""
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .disabled(
                    newName.trimmingCharacters(in: .whitespaces).isEmpty
                        || newURL.trimmingCharacters(in: .whitespaces).isEmpty
                )
                .help("Add service")
            }
            .padding(12)
        }
        .frame(width: 420, height: 380)
    }
}
