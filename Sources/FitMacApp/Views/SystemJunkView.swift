import SwiftUI
import FitMacCore

struct SystemJunkView: View {
    @StateObject private var viewModel = SystemJunkViewModel()
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
        .navigationTitle("System Junk")
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
            "Clean System Junk?",
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
            Text("This will clean \(viewModel.selectedItems.count) item(s), freeing \(SizeFormatter.format(viewModel.totalSelectedSize)).")
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
                categoryPicker
                Button("Select All") {
                    viewModel.selectAll()
                }
                Button("Deselect All") {
                    viewModel.deselectAll()
                }
            }
        }
    }
    
    private var categoryPicker: some View {
        Menu {
            ForEach(SystemJunkCategory.allCases, id: \.self) { category in
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
    }
    
    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning system junk...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var initialStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Click Scan to find system junk")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Temporary files, broken downloads, document versions, and system leftovers")
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
            Text("No system junk found")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func contentView(_ result: SystemJunkScanResult) -> some View {
        VStack(spacing: 16) {
            summaryBox(result)
            
            ForEach(SystemJunkCategory.allCases, id: \.self) { category in
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
    
    private func summaryBox(_ result: SystemJunkScanResult) -> some View {
        GroupBox("Summary") {
            VStack(alignment: .leading, spacing: 8) {
                summaryRow(icon: "doc.text.fill", color: .blue, label: "Total Items:", value: "\(result.items.count)")
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
    
    private func categorySection(category: SystemJunkCategory, items: [SystemJunkItem]) -> some View {
        GroupBox(category.displayName) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    SystemJunkItemRow(
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
}

struct SystemJunkItemRow: View {
    let item: SystemJunkItem
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
                .foregroundStyle(.orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.path.lastPathComponent)
                    .font(.headline)
                Text(PathUtils.shorten(item.path.path))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let desc = item.description {
                    Text(desc)
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
    SystemJunkView()
        .frame(width: 700, height: 600)
}
