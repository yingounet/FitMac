import SwiftUI
import FitMacCore

enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case cache = "Cache"
    case systemJunk = "System Junk"
    case systemApps = "System Apps"
    case trash = "Trash"
    case language = "Language"
    case iTunes = "iTunes"
    case mail = "Mail"
    case largeFiles = "Large Files"
    case uninstall = "Uninstall"
    case history = "History"
    case permissions = "Permissions"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .home: return "externaldrive.fill"
        case .cache: return "trash.circle.fill"
        case .systemJunk: return "gearshape.fill"
        case .systemApps: return "app.badge.minus"
        case .trash: return "trash"
        case .language: return "globe"
        case .iTunes: return "music.note"
        case .mail: return "envelope.fill"
        case .largeFiles: return "doc.fill"
        case .uninstall: return "xmark.bin.fill"
        case .history: return "clock.arrow.circlepath"
        case .permissions: return "lock.shield.fill"
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
                HomeView(selectedSidebarItem: $selectedSidebarItem)
            case .cache:
                CacheView()
            case .systemJunk:
                SystemJunkView()
            case .systemApps:
                SystemAppView()
            case .trash:
                TrashView()
            case .language:
                LanguageFilesView()
            case .iTunes:
                iTunesView()
            case .mail:
                MailAttachmentsView()
            case .largeFiles:
                LargeFilesView()
            case .uninstall:
                UninstallView()
            case .history:
                LogView()
            case .permissions:
                FullDiskAccessView()
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
