import SwiftUI
import FitMacCore

struct LanguageFilesView: View {
    @StateObject private var viewModel = LanguageFilesViewModel()
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
        .navigationTitle("Language Files")
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
            "Remove Language Files?",
            isPresented: $showCleanConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Selected", role: .destructive) {
                Task {
                    await viewModel.clean(dryRun: false)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove \(viewModel.selectedItems.count) language file(s), freeing \(SizeFormatter.format(viewModel.totalSelectedSize)). Your current language will be preserved.")
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
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning language files...")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("\(viewModel.scannedCount) apps scanned")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var initialStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Click Scan to find unused language files")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("This will scan applications and find language files that are not your current system language")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("No unused language files found")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func contentView(_ result: LanguageScanResult) -> some View {
        VStack(spacing: 16) {
            summaryBox(result)
            
            if !result.removableItems.isEmpty {
                languageFilesList(result)
            }
            
            if !viewModel.selectedItems.isEmpty {
                bottomBar
            }
        }
    }
    
    private func summaryBox(_ result: LanguageScanResult) -> some View {
        GroupBox("Summary") {
            VStack(alignment: .leading, spacing: 8) {
                summaryRow(icon: "globe", color: .blue, label: "Current Language:", value: result.currentLanguage)
                summaryRow(icon: "doc.fill", color: .orange, label: "Total Language Files:", value: "\(result.items.count)")
                summaryRow(icon: "trash.fill", color: .red, label: "Removable Files:", value: "\(result.removableItems.count)")
                summaryRow(icon: "externaldrive.fill", color: .green, label: "Space to Free:", value: SizeFormatter.format(result.removableSize), valueColor: .green)
            }
            .padding()
        }
    }
    
    private func summaryRow(icon: String, color: Color, label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(valueColor)
        }
    }
    
    private func languageFilesList(_ result: LanguageScanResult) -> some View {
        GroupBox("Removable Language Files") {
            List {
                ForEach(groupedByApp(items: result.removableItems), id: \.self) { app in
                    Section(header: Text(app)) {
                        ForEach(result.removableItems.filter { $0.appName == app }) { item in
                            LanguageFileRow(
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
                }
            }
            .listStyle(.plain)
            .frame(minHeight: 300)
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
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func errorView(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(error)
                .foregroundStyle(.red)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func groupedByApp(items: [LanguageFile]) -> [String] {
        let apps = Set(items.map(\.appName))
        return apps.sorted()
    }
}

struct LanguageFileRow: View {
    let item: LanguageFile
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
            
            Image(systemName: "globe")
                .foregroundStyle(.orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.languageCode)
                    .font(.headline)
                Text(PathUtils.shorten(item.lprojPath.path))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    LanguageFilesView()
        .frame(width: 700, height: 600)
}
