import SwiftUI
import FitMacCore

struct UninstallView: View {
    @StateObject private var viewModel = UninstallViewModel()
    @State private var showDeleteConfirmation = false
    @State private var showSuccessAlert = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationSplitView {
            appListView
        } detail: {
            if let app = viewModel.selectedApp {
                appDetailView(app)
            } else {
                emptyDetailView
            }
        }
        .navigationTitle("Uninstall Apps")
        .task { await viewModel.loadInstalledApps() }
        .alert("Delete Leftovers", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                if viewModel.deleteLeftovers() {
                    showSuccessAlert = true
                }
            }
        } message: {
            Text("Move \(viewModel.foundLeftovers.count) items (\(SizeFormatter.format(viewModel.totalLeftoverSize))) to Trash?")
        }
        .alert("Files Moved to Trash", isPresented: $showSuccessAlert) {
            Button("OK") { }
        }
    }
    
    private var appListView: some View {
        List(selection: $viewModel.selectedApp) {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            }
            
            ForEach(filteredApps) { app in
                AppListRow(app: app)
                    .tag(app)
            }
        }
        .searchable(text: $searchText, prompt: "Search apps")
        .navigationSplitViewColumnWidth(min: 250, ideal: 300)
    }
    
    private var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return viewModel.installedApps
        }
        return viewModel.installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var emptyDetailView: some View {
        EmptyStateView(
            icon: "app",
            title: "Select an app to scan for leftovers"
        )
    }
    
    private func appDetailView(_ app: AppInfo) -> some View {
        VStack(spacing: 0) {
            appInfoSection(app)
            Divider()
            
            if viewModel.isScanningLeftovers {
                scanningView
            } else if !viewModel.foundLeftovers.isEmpty {
                leftoversListView
            } else {
                noLeftoversView
            }
        }
        .toolbar {
            if !viewModel.foundLeftovers.isEmpty {
                Button("Move to Trash") {
                    showDeleteConfirmation = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }
    
    private func appInfoSection(_ app: AppInfo) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "app.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 16) {
                    if let version = app.version {
                        Label("v\(version)", systemImage: "number")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if let size = app.size {
                        Label(SizeFormatter.format(size), systemImage: "externaldrive")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            Spacer()
            
            Button {
                Task { await viewModel.scanLeftovers(for: app) }
            } label: {
                Label("Scan Leftovers", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isScanningLeftovers)
        }
        .padding()
        .background(.primary.opacity(0.05))
    }
    
    private var scanningView: some View {
        ScanningStateView(message: "Scanning for leftover files...")
    }
    
    private var noLeftoversView: some View {
        NoResultStateView()
    }
    
    private var leftoversListView: some View {
        List {
            Section {
                ForEach(viewModel.foundLeftovers) { item in
                    LeftoverItemRow(item: item)
                }
            } header: {
                HStack {
                    Text("Found Leftovers")
                    Spacer()
                    Text("\(viewModel.foundLeftovers.count) items • \(SizeFormatter.format(viewModel.totalLeftoverSize))")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

struct AppListRow: View {
    let app: AppInfo
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "app.fill")
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body)
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct LeftoverItemRow: View {
    let item: CleanupItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(item.isDirectory ? .blue : .gray)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.path.lastPathComponent)
                    .font(.body)
                    .lineLimit(1)
                Text(shortenPath(item.path.path))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(SizeFormatter.format(item.size))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
    
    private func shortenPath(_ path: String) -> String {
        PathUtils.shorten(path)
    }
}

#Preview {
    UninstallView()
        .frame(width: 900, height: 600)
}
