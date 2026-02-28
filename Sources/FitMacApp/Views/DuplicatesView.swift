import SwiftUI
import FitMacCore

struct DuplicatesView: View {
    @StateObject private var viewModel = DuplicatesViewModel()
    @State private var showDeleteConfirmation = false
    @State private var showSuccessAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            toolbarSection
            Divider()
            
            if viewModel.isScanning {
                scanningView
            } else if let result = viewModel.scanResult, !result.groups.isEmpty {
                duplicatesListView(result)
            } else if viewModel.scanResult != nil {
                emptyStateView
            } else {
                initialScanView
            }
        }
        .navigationTitle("Duplicates")
        .alert("Delete Duplicates", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                Task {
                    _ = await viewModel.clean(dryRun: false)
                    showSuccessAlert = true
                }
            }
        } message: {
            Text("Move \(viewModel.selectedFiles.count) duplicate files (\(SizeFormatter.format(viewModel.totalSelectedSize))) to Trash?")
        }
        .alert("Files Moved to Trash", isPresented: $showSuccessAlert) {
            Button("OK") {
                viewModel.scanResult = nil
            }
        }
    }
    
    private var toolbarSection: some View {
        HStack(spacing: 12) {
            TextField("Min MB", text: $viewModel.minSize)
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isScanning)
            
            Text("MB min size")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if !viewModel.selectedFiles.isEmpty {
                Text("\(viewModel.selectedFiles.count) selected")
                    .foregroundStyle(.secondary)
                
                Button("Move to Trash") {
                    showDeleteConfirmation = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
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
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isScanning ? .red : .blue)
        }
        .padding()
        .background(.primary.opacity(0.05))
    }
    
    private var scanningView: some View {
        ScanningStateView(
            message: "Scanning for duplicate files...",
            itemCount: viewModel.scannedCount
        )
    }
    
    private var initialScanView: some View {
        EmptyStateView(
            icon: "doc.on.doc.fill",
            title: "Find Duplicate Files",
            description: "Scan your files to find duplicates",
            actionTitle: "Start Scan",
            action: { viewModel.scan() }
        )
    }
    
    private var emptyStateView: some View {
        NoResultStateView()
    }
    
    private func duplicatesListView(_ result: DuplicatesScanResult) -> some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(result.groups.count) groups found")
                            .font(.headline)
                        Text("Potential savings: \(SizeFormatter.format(result.totalWastage))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Select All Duplicates") {
                        viewModel.selectAllDuplicates()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.selectedFiles.count == result.totalFiles - result.groups.count)
                    Button("Deselect All") {
                        viewModel.deselectAll()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
            }
            
            ForEach(result.groups) { group in
                DuplicateGroupRow(
                    group: group,
                    isExpanded: viewModel.expandedGroups.contains(group.id),
                    selectedFiles: $viewModel.selectedFiles,
                    onToggleExpand: {
                        if viewModel.expandedGroups.contains(group.id) {
                            viewModel.expandedGroups.remove(group.id)
                        } else {
                            viewModel.expandedGroups.insert(group.id)
                        }
                    },
                    onSelectDuplicates: {
                        viewModel.selectDuplicatesInGroup(group, keepFirst: true)
                    }
                )
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .safeAreaInset(edge: .bottom) {
            if !viewModel.selectedFiles.isEmpty {
                bottomBar
            }
        }
    }
    
    private var bottomBar: some View {
        HStack {
            Text("\(viewModel.selectedFiles.count) files selected")
                .foregroundStyle(.secondary)
            Spacer()
            Text("Total: \(SizeFormatter.format(viewModel.totalSelectedSize))")
                .font(.headline)
        }
        .padding()
        .background(.regularMaterial)
    }
}

struct DuplicateGroupRow: View {
    let group: DuplicateGroup
    let isExpanded: Bool
    @Binding var selectedFiles: Set<URL>
    let onToggleExpand: () -> Void
    let onSelectDuplicates: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                onToggleExpand()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    
                    Image(systemName: "doc.on.doc.fill")
                        .foregroundStyle(.orange)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(group.files.count) identical files")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("Each: \(SizeFormatter.format(group.fileSize)) • Wasted: \(SizeFormatter.format(group.wastage))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Select Duplicates") {
                        onSelectDuplicates()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(group.files.enumerated()), id: \.element.id) { index, file in
                        DuplicateFileRow(
                            file: file,
                            index: index,
                            isSelected: selectedFiles.contains(file.path),
                            isFirst: index == 0
                        ) {
                            if selectedFiles.contains(file.path) {
                                selectedFiles.remove(file.path)
                            } else {
                                selectedFiles.insert(file.path)
                            }
                        }
                    }
                }
                .padding(.leading, 28)
                .padding(.bottom, 8)
            }
        }
    }
}

struct DuplicateFileRow: View {
    let file: DuplicateFile
    let index: Int
    let isSelected: Bool
    let isFirst: Bool
    let toggleSelection: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button {
                toggleSelection()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .red : .gray)
            }
            .buttonStyle(.plain)
            
            if isFirst {
                Text("(Original)")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Text("Duplicate")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(file.path.lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                Text(PathUtils.shorten(file.path.deletingLastPathComponent().path))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let date = file.modifiedDate {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { toggleSelection() }
    }
}

#Preview {
    DuplicatesView()
        .frame(width: 800, height: 600)
}
