import SwiftUI
import FitMacCore

struct CacheView: View {
    @StateObject private var viewModel = CacheViewModel()
    @AppStorage("dryRunByDefault") private var dryRunByDefault = true
    @State private var showConfirmation = false
    @State private var showCleanSuccess = false
    
    var body: some View {
        VStack(spacing: 0) {
            toolbarSection
            Divider()
            
            if viewModel.isScanning {
                scanningView
            } else if let result = viewModel.scanResult {
                resultsView(result)
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Cache Cleaner")
        .alert("Clean Cache", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clean") {
                Task { await performClean() }
            }
        } message: {
            Text("This will clean \(viewModel.selectedItems.count) items (\(SizeFormatter.format(viewModel.totalSelectedSize))). Continue?")
        }
        .alert("Clean Complete", isPresented: $showCleanSuccess) {
            Button("OK") { }
        } message: {
            if let result = viewModel.cleanupResult {
                Text("Freed \(SizeFormatter.format(result.freedSpace))")
            }
        }
    }
    
    private var toolbarSection: some View {
        HStack {
            Menu {
                ForEach(CacheCategory.allCases, id: \.self) { category in
                    Button {
                        if viewModel.selectedCategories.contains(category) {
                            viewModel.selectedCategories.remove(category)
                        } else {
                            viewModel.selectedCategories.insert(category)
                        }
                    } label: {
                        HStack {
                            Text(category.displayName)
                            if viewModel.selectedCategories.contains(category) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Categories", systemImage: "line.3.horizontal.decrease.circle")
            }
            .disabled(viewModel.isScanning)
            
            Spacer()
            
            if viewModel.scanResult != nil {
                Button("Select All") {
                    viewModel.selectAll()
                }
                .disabled(viewModel.isScanning || viewModel.isCleaning)
                
                Button("Deselect All") {
                    viewModel.deselectAll()
                }
                .disabled(viewModel.isScanning || viewModel.isCleaning)
            }
            
            Button {
                if viewModel.isScanning {
                    viewModel.cancelScan()
                } else {
                    viewModel.scan()
                }
            } label: {
                if viewModel.isScanning {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                        Text("Cancel")
                    }
                } else {
                    Label("Scan", systemImage: "magnifyingglass")
                }
            }
            .disabled(viewModel.isCleaning || viewModel.selectedCategories.isEmpty)
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isScanning ? .red : .blue)
            
            if viewModel.scanResult != nil && !viewModel.selectedItems.isEmpty {
                Button {
                    showConfirmation = true
                } label: {
                    Label("Clean", systemImage: "trash")
                }
                .disabled(viewModel.isCleaning)
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
    }
    
    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning cache files...")
                .foregroundStyle(.secondary)
            if viewModel.scannedCount > 0 {
                Text("\(viewModel.scannedCount) locations found")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Click Scan to find cache files")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Select categories from the menu and scan for cache files")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func resultsView(_ result: ScanResult) -> some View {
        List {
            ForEach(CacheCategory.allCases, id: \.self) { category in
                let items = result.items(for: category)
                if !items.isEmpty {
                    Section {
                        ForEach(items) { item in
                            CacheItemRow(item: item, isSelected: viewModel.selectedItems.contains(item.path)) {
                                if viewModel.selectedItems.contains(item.path) {
                                    viewModel.selectedItems.remove(item.path)
                                } else {
                                    viewModel.selectedItems.insert(item.path)
                                }
                            }
                        }
                    } header: {
                        CategoryHeader(category: category, items: items)
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .safeAreaInset(edge: .bottom) {
            if !viewModel.selectedItems.isEmpty {
                bottomBar
            }
        }
    }
    
    private var bottomBar: some View {
        HStack {
            Text("\(viewModel.selectedItems.count) items selected")
                .foregroundStyle(.secondary)
            Spacer()
            Text("Total: \(SizeFormatter.format(viewModel.totalSelectedSize))")
                .font(.headline)
        }
        .padding()
        .background(.regularMaterial)
    }
    
    private func performClean() async {
        await viewModel.clean(dryRun: dryRunByDefault)
        if viewModel.cleanupResult != nil && !dryRunByDefault {
            showCleanSuccess = true
            viewModel.scanResult = nil
        }
    }
}

struct CategoryHeader: View {
    let category: CacheCategory
    let items: [CleanupItem]
    
    var body: some View {
        HStack {
            Text(category.displayName)
                .font(.headline)
            Spacer()
            Text(SizeFormatter.format(items.reduce(0) { $0 + $1.size }))
                .foregroundStyle(.secondary)
        }
    }
}

struct CacheItemRow: View {
    let item: CleanupItem
    let isSelected: Bool
    let toggleSelection: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                toggleSelection()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .gray)
            }
            .buttonStyle(.plain)
            
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
        .contentShape(Rectangle())
        .onTapGesture { toggleSelection() }
    }
    
    private func shortenPath(_ path: String) -> String {
        PathUtils.shorten(path)
    }
}

#Preview {
    CacheView()
        .frame(width: 800, height: 600)
}
