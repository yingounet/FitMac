import SwiftUI
import FitMacCore

struct TrashView: View {
    @StateObject private var viewModel = TrashViewModel()
    @State private var showEmptyConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                toolbarSection
                
                if viewModel.isScanning {
                    scanningView
                } else if let result = viewModel.scanResult {
                    if result.bins.isEmpty {
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
        .navigationTitle("Trash Bins")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.scanResult != nil && !viewModel.selectedBins.isEmpty {
                    Button("Empty Selected", role: .destructive) {
                        showEmptyConfirmation = true
                    }
                    .disabled(viewModel.isEmptying)
                }
            }
        }
        .confirmationDialog(
            "Empty Trash Bins?",
            isPresented: $showEmptyConfirmation,
            titleVisibility: .visible
        ) {
            Button("Empty Selected", role: .destructive) {
                Task {
                    await viewModel.emptySelected(dryRun: false)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \(viewModel.selectedBins.count) trash bin(s), freeing \(SizeFormatter.format(viewModel.totalSelectedSize)). This action cannot be undone.")
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
        ScanningStateView(message: "Scanning trash bins...")
    }
    
    private var initialStateView: some View {
        EmptyStateView(
            icon: "trash",
            title: "Click Scan to check trash bins"
        )
    }
    
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "checkmark.circle.fill",
            title: "All trash bins are empty"
        )
    }
    
    private func contentView(_ result: TrashScanResult) -> some View {
        VStack(spacing: 16) {
            GroupBox("Summary") {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundStyle(.orange)
                            Text("Total Trash Bins:")
                                .foregroundStyle(.secondary)
                            Text("\(result.bins.count)")
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
                        if viewModel.hasExternalBins {
                            HStack {
                                Image(systemName: "externaldrive.badge.icloud")
                                    .foregroundStyle(.purple)
                                Text("Includes external drives")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                }
                .padding()
            }
            
            GroupBox("Trash Bins") {
                List {
                    ForEach(result.bins) { bin in
                        TrashBinRow(
                            bin: bin,
                            isSelected: viewModel.selectedBins.contains(bin.id)
                        ) {
                            if viewModel.selectedBins.contains(bin.id) {
                                viewModel.selectedBins.remove(bin.id)
                            } else {
                                viewModel.selectedBins.insert(bin.id)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: 200)
            }
        }
    }
    
    private func errorView(_ error: String) -> some View {
        ErrorStateView(message: error)
    }
}

struct TrashBinRow: View {
    let bin: TrashBin
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
            
            Image(systemName: bin.isExternal ? "externaldrive.fill" : "trash.fill")
                .foregroundStyle(bin.isExternal ? .purple : .orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(bin.name)
                    .font(.headline)
                Text(PathUtils.shorten(bin.path.path))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(SizeFormatter.format(bin.size))
                    .fontWeight(.semibold)
                Text(bin.volumeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

#Preview {
    TrashView()
        .frame(width: 700, height: 500)
}
