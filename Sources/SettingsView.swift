import SwiftUI

struct SettingsView: View {
    @Binding var showSettings: Bool

    @AppStorage("postcode", store: sharedDefaults) private var savedPostcode: String?
    @AppStorage("uprn", store: sharedDefaults) private var savedUprn: String?
    @AppStorage("addressText", store: sharedDefaults) private var savedAddressText: String?

    @State private var postcode = ""
    @State private var addresses: [Address] = []
    @State private var searching = false
    @State private var error: String?

    private var isFirstLaunch: Bool { savedUprn == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Postcode", text: $postcode)
                            .textContentType(.postalCode)
                            .textInputAutocapitalization(.characters)

                        Button("Search") {
                            Task { await search() }
                        }
                        .disabled(postcode.count < 5 || searching)
                    }
                } header: {
                    Text("Central Bedfordshire postcode")
                }

                if searching {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }

                if !addresses.isEmpty {
                    Section("Select your address") {
                        ForEach(addresses) { addr in
                            Button {
                                select(addr)
                            } label: {
                                Text(addr.text)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }

                if let error {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Setup")
            .toolbar {
                if !isFirstLaunch {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showSettings = false }
                    }
                }
            }
            .onAppear {
                if postcode.isEmpty {
                    postcode = savedPostcode ?? "SG18 8BQ"
                }
            }
        }
    }

    private func search() async {
        searching = true
        error = nil
        addresses = []
        do {
            addresses = try await BinService.fetchAddresses(postcode: postcode)
            if addresses.isEmpty {
                error = "No addresses found. Check the postcode is in Central Bedfordshire."
            }
        } catch {
            self.error = "Could not reach the council website. Please check your connection."
        }
        searching = false
    }

    private func select(_ addr: Address) {
        savedPostcode = postcode
        savedUprn = addr.id
        savedAddressText = addr.text
        showSettings = false
    }
}
