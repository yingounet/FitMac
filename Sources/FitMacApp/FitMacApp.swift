import SwiftUI

@main
struct FitMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        Settings {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("dryRunByDefault") private var dryRunByDefault = true
    @AppStorage("showConfirmationDialogs") private var showConfirmationDialogs = true
    
    var body: some View {
        Form {
            Section("Safety") {
                Toggle("Dry-run by default", isOn: $dryRunByDefault)
                Toggle("Show confirmation dialogs", isOn: $showConfirmationDialogs)
            }
            .formStyle(.grouped)
        }
        .padding()
    }
}
