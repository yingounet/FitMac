import SwiftUI
import FitMacCore

struct HomebrewView: View {
    @StateObject private var viewModel = HomebrewViewModel()
    @State private var showCleanConfirmation = false
    @State private var showBrewCleanupConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                toolbarSection
                
                if viewModel.isScanning {
                    scanningView
                } else if let result = viewModel.scanResult {
                    if !result.isHomebrewInstalled {
                        notInstalledView
                    } else if result.items.isEmpty {
                        emptyStateView
                    } else {
                        contentView(result)
                    }
                } else {
                    initialStateView
                }
                
                if let error = viewModel.errorMessage {
                    errorView(error)
                }
            }
            .padding()
        }
        .navigationTitle("Homebrew")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let result = viewModel.scanResult, result.isHomebrewInstalled {
                    Menu {
                        Button {
                            showBrewCleanupConfirmation = true
                        } label: {
                            Label("Run brew cleanup", systemImage: "terminal")
                        }
                        
                        if !viewModel.selectedItems.isEmpty {
                            Divider()
                            Button(role: .destructive) {
                                showCleanConfirmation = true
                            } label: {
                                Label("Clean Selected", systemImage: "trash")
                            }
                        }
                    } label: {
                        Label("Actions", systemImage: "ellipsis.circle")
                    }
                    .disabled(viewModel.isCleaning)
                }
            }
        }
        .confirmationDialog(
            "Clean Homebrew Cache?",
            isPresented: $showCleanConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clean Selected", role: .destructive) {
                Task {
                    await viewModel.cleanSelected(dryRun: false)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will move \(viewModel.selectedItems.count) items to trash, freeing \(SizeFormatter.format(viewModel.totalSelectedSize)).")
        }
        .confirmationDialog(
            "Run brew cleanup?",
            isPresented: $showBrewCleanupConfirmation,
            titleVisibility: .visible
        ) {
            Button("Run brew cleanup", role: .destructive) {
                Task {
                    await viewModel.runBrewCleanup()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will run 'brew cleanup --prune=all' to remove old versions and clear the cache.")
        }
        .onAppear {
            viewModel.scan()
        }
    }
    
    private var toolbarSection: some View {
        HStack {
            Button {
                viewModel.scan()
            } label: {
                Label("Scan", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isScanning)
            
            Spacer()
            
            if viewModel.scanResult != nil && viewModel.scanResult?.isHomebrewInstalled == true {
                Button("Select All") {
                    viewModel.selectAll()
                }
                Button("Deselect All") {
                    viewModel.deselectAll()
                }
            }
        }
    }
    
    private var scanningView: some View {
        ScanningStateView(message: "Scanning Homebrew cache...")
    }
    
    private var initialStateView: some View {
        EmptyStateView(
            icon: "mug.fill",
            title: "Click Scan to check Homebrew cache"
        )
    }
    
    private var notInstalledView: some View {
        EmptyStateView(
            icon: "mug",
            title: "Homebrew Not Installed",
            description: "Install Homebrew from brew.sh to use this feature",
            actionTitle: "Visit brew.sh",
            action: { NSWorkspace.shared.open(URL(string: "https://brew.sh")!) }
        )
    }
    
    private var emptyStateView: some View {
        NoResultStateView()
    }
    
    private func contentView(_ result: HomebrewScanResult) -> some View {
        VStack(spacing: 16) {
            GroupBox("Summary") {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "mug.fill")
                                .foregroundStyle(.orange)
                            Text("Total Items:")
                                .foregroundStyle(.secondary)
                            Text("\(result.items.count)")
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Image(systemName: "externaldrive.fill")
                                .foregroundStyle(.blue)
                            Text("Total Size:")
                                .foregroundStyle(.secondary)
                            Text(SizeFormatter.format(result.totalSize))
                                .fontWeight(.semibold)
                        }
                        if let brewPath = result.brewPath {
                            HStack {
                                Image(systemName: "terminal")
                                    .foregroundStyle(.green)
                                Text("Brew Path:")
                                    .foregroundStyle(.secondary)
                                Text(brewPath)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    Spacer()
                }
                .padding()
            }
            
            ForEach(HomebrewItemType.allCases, id: \.self) { type in
                homebrewTypeGroupBox(result: result, type: type)
            }
            
            if viewModel.isCleaning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Cleaning...")
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            
            if let brewOutput = viewModel.brewCleanupOutput {
                GroupBox("Brew Cleanup Output") {
                    Text(brewOutput)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    @ViewBuilder
    private func homebrewTypeGroupBox(result: HomebrewScanResult, type: HomebrewItemType) -> some View {
        let items = result.items(for: type)
        if !items.isEmpty {
            GroupBox(type.displayName) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Size: \(SizeFormatter.format(result.size(for: type)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("(\(items.count) items)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    List {
                        ForEach(items) { item in
                            HomebrewItemRow(
                                item: item,
                                isSelected: viewModel.selectedItems.contains(item.id)
                            ) {
                                if viewModel.selectedItems.contains(item.id) {
                                    viewModel.selectedItems.remove(item.id)
                                } else {
                                    viewModel.selectedItems.insert(item.id)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .frame(minHeight: CGFloat(min(items.count, 5)) * 44 + 20)
                }
            }
        }
    }
    
    private func errorView(_ error: String) -> some View {
        ErrorStateView(message: error)
    }
}

struct HomebrewItemRow: View {
    let item: HomebrewCacheItem
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .gray)
            }
            .buttonStyle(.plain)
            
            Image(systemName: iconForType(item.type))
                .foregroundStyle(colorForType(item.type))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.headline)
                Text(PathUtils.shorten(item.path.path))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(SizeFormatter.format(item.size))
                    .fontWeight(.semibold)
                if let date = item.modifiedDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
    
    private func iconForType(_ type: HomebrewItemType) -> String {
        switch type {
        case .cache: return "folder.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .oldVersions: return "clock.arrow.circlepath"
        case .logs: return "doc.text.fill"
        case .cellar: return "archivebox.fill"
        }
    }
    
    private func colorForType(_ type: HomebrewItemType) -> Color {
        switch type {
        case .cache: return .orange
        case .downloads: return .blue
        case .oldVersions: return .purple
        case .logs: return .gray
        case .cellar: return .brown
        }
    }
}

#Preview {
    HomebrewView()
        .frame(width: 700, height: 600)
}
