import SwiftUI
import FitMacCore

struct iTunesView: View {
    @StateObject private var viewModel = iTunesViewModel()
    @State private var showCleanConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                toolbarSection
                
                if viewModel.isScanning {
                    scanningView
                } else if let result = viewModel.scanResult {
                    if result.items.isEmpty {
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
        .navigationTitle("iTunes Junk")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.scanResult != nil && !viewModel.selectedItems.isEmpty {
                    Button("Clean Selected", role: .destructive) {
                        showCleanConfirmation = true
                    }
                    .disabled(viewModel.isCleaning)
                }
            }
        }
        .confirmationDialog(
            "Clean iTunes Junk?",
            isPresented: $showCleanConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clean Selected", role: .destructive) {
                Task {
                    await viewModel.clean(dryRun: false)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will clean \(viewModel.selectedItems.count) item(s), freeing \(SizeFormatter.format(viewModel.totalSelectedSize)). Make sure you have backups of important data.")
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
            
            if viewModel.scanResult != nil {
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
        ScanningStateView(message: "Scanning iTunes junk...")
    }
    
    private var initialStateView: some View {
        EmptyStateView(
            icon: "music.note",
            title: "Click Scan to find iTunes junk",
            description: "iOS backups, podcast downloads, and old mobile apps"
        )
    }
    
    private var emptyStateView: some View {
        NoResultStateView()
    }
    
    private func contentView(_ result: iTunesJunkScanResult) -> some View {
        VStack(spacing: 16) {
            summaryBox(result)
            
            ForEach(iTunesJunkCategory.allCases, id: \.self) { category in
                let categoryItems = result.items(for: category)
                if !categoryItems.isEmpty {
                    categorySection(category: category, items: categoryItems)
                }
            }
            
            if !viewModel.selectedItems.isEmpty {
                bottomBar
            }
        }
    }
    
    private func summaryBox(_ result: iTunesJunkScanResult) -> some View {
        GroupBox("Summary") {
            VStack(alignment: .leading, spacing: 8) {
                summaryRow(icon: "music.note", color: .purple, label: "Total Items:", value: "\(result.items.count)")
                summaryRow(icon: "externaldrive.fill", color: .green, label: "Total Size:", value: SizeFormatter.format(result.totalSize))
            }
            .padding()
        }
    }
    
    private func summaryRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
        }
    }
    
    private func categorySection(category: iTunesJunkCategory, items: [iTunesJunkItem]) -> some View {
        GroupBox(category.displayName) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    iTunesJunkItemRow(
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
            .padding()
        }
    }
    
    private var bottomBar: some View {
        HStack {
            Text("\(viewModel.selectedItems.count) items selected")
                .foregroundStyle(.secondary)
            Spacer()
            Text("Total: \(SizeFormatter.format(viewModel.totalSelectedSize))")
                .fontWeight(.semibold)
        }
        .padding()
        .background(.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: FitMacSpacing.md))
    }
    
    private func errorView(_ error: String) -> some View {
        ErrorStateView(message: error)
    }
}

struct iTunesJunkItemRow: View {
    let item: iTunesJunkItem
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
            
            Image(systemName: item.category.icon)
                .foregroundStyle(.purple)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.headline)
                Text(PathUtils.shorten(item.path.path))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let details = item.details {
                    Text(details)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            Text(SizeFormatter.format(item.size))
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

#Preview {
    iTunesView()
        .frame(width: 700, height: 600)
}
