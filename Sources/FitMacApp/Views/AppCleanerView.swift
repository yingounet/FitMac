import SwiftUI
import FitMacCore

struct AppCleanerView: View {
    @StateObject private var viewModel = AppCleanerViewModel()
    @State private var showCleanConfirmation = false
    @State private var selectedTab: CleanerTab = .orphan
    
    enum CleanerTab: String, CaseIterable {
        case orphan = "Orphan Leftovers"
        case installed = "Installed Apps"
        
        var icon: String {
            switch self {
            case .orphan: return "app.dashed"
            case .installed: return "app.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isScanning {
                scanningView
            } else if viewModel.orphanLeftovers.isEmpty && viewModel.installedAppData.isEmpty {
                initialStateView
            } else {
                contentView
            }
            
            if let error = viewModel.errorMessage {
                errorView(error)
            }
        }
        .navigationTitle("App Cleaner")
        .alert("Clean App Leftovers?", isPresented: $showCleanConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                Task { await viewModel.clean(dryRun: false) }
            }
        } message: {
            Text("This will clean \(viewModel.selectedItems.count) item(s), freeing \(SizeFormatter.format(viewModel.totalSelectedSize)).")
        }
    }
    
    private var scanningView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning app leftovers...")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var initialStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            EmptyStateView(
                icon: "app.badge.fill",
                title: "Click Scan to find app leftovers",
                description: "Scan for orphan files from uninstalled apps and cache from installed apps"
            )
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            scanButton
        }
    }
    
    private var contentView: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            
            TabView(selection: $selectedTab) {
                listView(viewModel.orphanLeftovers, isOrphan: true)
                    .tag(CleanerTab.orphan)
                
                listView(viewModel.installedAppData, isOrphan: false)
                    .tag(CleanerTab.installed)
            }
            .tabViewStyle(.automatic)
            
            if !viewModel.selectedItems.isEmpty {
                bottomBar
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !viewModel.selectedItems.isEmpty {
                cleanButton
            }
        }
    }
    
    private var topBar: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.scan()
            } label: {
                Label("Scan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isScanning)
            
            Spacer()
            
            HStack(spacing: 24) {
                statItem(
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    count: viewModel.orphanLeftovers.count,
                    size: viewModel.orphanLeftovers.reduce(0) { $0 + $1.size }
                )
                
                statItem(
                    icon: "app.fill",
                    color: .blue,
                    count: viewModel.installedAppData.count,
                    size: viewModel.installedAppData.reduce(0) { $0 + $1.size }
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    private func statItem(icon: String, color: Color, count: Int, size: Int64) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.medium)
            Text(SizeFormatter.format(size))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func listView(_ items: [AppLeftover], isOrphan: Bool) -> some View {
        Group {
            if items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text(isOrphan ? "No Orphan Leftovers Found" : "No Installed App Data")
                        .font(.headline)
                    Text(isOrphan ? "All apps are properly cleaned" : "No cache data found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    Section {
                        ForEach(items) { leftover in
                            AppLeftoverRow(
                                leftover: leftover,
                                isSelected: viewModel.selectedItems.contains(leftover.id)
                            ) {
                                if viewModel.selectedItems.contains(leftover.id) {
                                    viewModel.selectedItems.remove(leftover.id)
                                } else {
                                    viewModel.selectedItems.insert(leftover.id)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text(isOrphan ? "Orphan Leftovers" : "Installed Apps")
                                .font(.headline)
                            Spacer()
                            Text("\(items.count) items")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
    
    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("Deselect All") {
                viewModel.deselectAll()
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("Select All") {
                viewModel.selectAll()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 0)
                .fill(.primary.opacity(0.05))
        }
    }
    
    private var scanButton: some View {
        Button {
            viewModel.scan()
        } label: {
            Label("Scan", systemImage: "arrow.clockwise")
                .font(.headline)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding()
    }
    
    private var cleanButton: some View {
        VStack(spacing: 8) {
            Button {
                showCleanConfirmation = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                    Text("Clean Selected")
                }
                .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            
            Text("\(viewModel.selectedItems.count) items • \(SizeFormatter.format(viewModel.totalSelectedSize))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private func errorView(_ error: String) -> some View {
        ErrorStateView(message: error)
            .padding()
    }
}

struct AppLeftoverRow: View {
    let leftover: AppLeftover
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(leftover.appName)
                        .font(.headline)
                    
                    if !leftover.isInstalled {
                        Text("ORPHAN")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                
                Text(leftover.bundleId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label("\(leftover.paths.count)", systemImage: "folder.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Label(SizeFormatter.format(leftover.size), systemImage: "externaldrive.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            Text(SizeFormatter.format(leftover.size))
                .font(.headline)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(isSelected ? .blue : .secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

#Preview {
    AppCleanerView()
        .frame(width: 900, height: 700)
}
