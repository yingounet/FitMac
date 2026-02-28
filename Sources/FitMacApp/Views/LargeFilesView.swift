import SwiftUI
import FitMacCore

struct LargeFilesView: View {
    @StateObject private var viewModel = LargeFilesViewModel()
    @State private var showDeleteConfirmation = false
    @State private var showSuccessAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            toolbarSection
            Divider()
            
            if viewModel.isScanning {
                scanningView
            } else if !viewModel.files.isEmpty {
                filesListView
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Large Files")
        .alert("Delete Files", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                Task {
                    _ = await viewModel.deleteSelected()
                    showSuccessAlert = true
                }
            }
        } message: {
            Text("Move \(viewModel.selectedFiles.count) files (\(SizeFormatter.format(viewModel.totalSelectedSize))) to Trash?")
        }
        .alert("Files Moved to Trash", isPresented: $showSuccessAlert) {
            Button("OK") { }
        }
    }
    
    private var toolbarSection: some View {
        HStack(spacing: 12) {
            TextField("Min Size", text: $viewModel.minSize)
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isScanning)
            
            Picker("Sort", selection: $viewModel.sortBy) {
                ForEach(LargeFilesViewModel.SortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .frame(width: 120)
            .disabled(viewModel.isScanning)
            
            Picker("Limit", selection: $viewModel.maxResults) {
                Text("20").tag(20)
                Text("50").tag(50)
                Text("100").tag(100)
                Text("200").tag(200)
            }
            .frame(width: 80)
            .disabled(viewModel.isScanning)
            
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
            message: "Scanning for large files...",
            itemCount: viewModel.scannedCount
        )
    }
    
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "doc",
            title: "No large files found",
            description: "Try adjusting the minimum size filter"
        )
    }
    
    private var filesListView: some View {
        List {
            ForEach(viewModel.files) { file in
                LargeFileRow(file: file, isSelected: viewModel.selectedFiles.contains(file.path)) {
                    if viewModel.selectedFiles.contains(file.path) {
                        viewModel.selectedFiles.remove(file.path)
                    } else {
                        viewModel.selectedFiles.insert(file.path)
                    }
                }
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

struct LargeFileRow: View {
    let file: LargeFile
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
            
            Image(systemName: iconForFileType(file.fileType))
                .foregroundStyle(colorForFileType(file.fileType))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.path.lastPathComponent)
                    .font(.body)
                    .lineLimit(1)
                Text(shortenPath(file.path.deletingLastPathComponent().path))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let date = file.modifiedDate {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 100, alignment: .trailing)
            }
            
            Text(SizeFormatter.format(file.size))
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { toggleSelection() }
    }
    
    private func shortenPath(_ path: String) -> String {
        PathUtils.shorten(path)
    }
    
    private func iconForFileType(_ type: String) -> String {
        if type.contains("image") { return "photo.fill" }
        if type.contains("video") { return "video.fill" }
        if type.contains("audio") { return "music.note" }
        if type.contains("zip") || type.contains("archive") { return "doc.zipper.fill" }
        if type.contains("pdf") { return "doc.richtext.fill" }
        return "doc.fill"
    }
    
    private func colorForFileType(_ type: String) -> Color {
        if type.contains("image") { return .purple }
        if type.contains("video") { return .pink }
        if type.contains("audio") { return .red }
        return .gray
    }
}

#Preview {
    LargeFilesView()
        .frame(width: 800, height: 600)
}
