import SwiftUI
import FitMacCore

enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case cache = "Cache"
    case largeFiles = "Large Files"
    case uninstall = "Uninstall"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .home: return "externaldrive.fill"
        case .cache: return "trash.circle.fill"
        case .largeFiles: return "doc.fill"
        case .uninstall: return "xmark.bin.fill"
        }
    }
    
    var title: String { rawValue }
}

struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem? = .home
    
    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selectedSidebarItem) { item in
                Label(item.title, systemImage: item.icon)
                    .tag(item)
            }
            .navigationTitle("FitMac")
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selectedSidebarItem {
            case .home:
                HomeView()
            case .cache:
                CacheView()
            case .largeFiles:
                LargeFilesView()
            case .uninstall:
                UninstallView()
            case .none:
                Text("Select a feature")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}
