import SwiftUI
import UIKit
import WidgetKit

struct SettingsView: View {
    @Binding var showSettings: Bool

    @AppStorage("postcode", store: sharedDefaults) private var savedPostcode: String?
    @AppStorage("uprn", store: sharedDefaults) private var savedUprn: String?
    @AppStorage("addressText", store: sharedDefaults) private var savedAddressText: String?
    @AppStorage("remindersEnabled", store: sharedDefaults) private var remindersEnabled = true
    @AppStorage("reminderHour", store: sharedDefaults) private var reminderHour = 20
    @AppStorage("reminderMinute", store: sharedDefaults) private var reminderMinute = 0

    @State private var postcode = ""
    @State private var addresses: [Address] = []
    @State private var searching = false
    @State private var error: String?
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    @State private var notificationsDenied = false

    private var isFirstLaunch: Bool { savedUprn == nil }

    private var homeIconStatus: String {
        switch UIApplication.shared.alternateIconName {
        case "BlackBin":
            return "Refuse (grey)"
        case .some(let name):
            return name
        case nil:
            return "Recycling (green)"
        }
    }

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

                if savedUprn != nil {
                    Section {
                        LabeledContent("Home screen icon", value: homeIconStatus)

                        Toggle("Collection reminders", isOn: $remindersEnabled)

                        if remindersEnabled {
                            DatePicker(
                                "Reminder time",
                                selection: $reminderTime,
                                displayedComponents: .hourAndMinute
                            )
                            Text("Day before collection")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if notificationsDenied && remindersEnabled {
                            Text("Enable notifications in iOS Settings to receive reminders.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Reminders")
                    } footer: {
                        if remindersEnabled {
                            Text("Notifies you the evening before each bin collection.")
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
                reminderTime = reminderDate(hour: reminderHour, minute: reminderMinute)
                Task { await refreshNotificationStatus() }
            }
            .onChange(of: remindersEnabled) { _, enabled in
                Task {
                    if enabled {
                        await ReminderScheduler.rescheduleFromStoredAddress()
                    } else {
                        await ReminderScheduler.cancelAll()
                    }
                    await refreshNotificationStatus()
                }
            }
            .onChange(of: reminderTime) { _, newTime in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                reminderHour = comps.hour ?? 20
                reminderMinute = comps.minute ?? 0
                Task { await ReminderScheduler.rescheduleFromStoredAddress() }
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
        WidgetCenter.shared.reloadAllTimelines()
        Task { await ReminderScheduler.rescheduleFromStoredAddress() }
        showSettings = false
    }

    private func refreshNotificationStatus() async {
        let denied = await ReminderScheduler.isNotificationsDenied()
        await MainActor.run {
            notificationsDenied = denied
        }
    }

    private func reminderDate(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }
}
