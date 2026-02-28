import SwiftUI
import FitMacCore

struct LoginItemsView: View {
    @StateObject private var viewModel = LoginItemsViewModel()
    @State private var showRemoveConfirmation = false
    @State private var itemToRemove: LoginItem?
    
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
        .navigationTitle("Login Items")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.scanResult != nil {
                    Button {
                        viewModel.scan()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isScanning || viewModel.isToggling)
                }
            }
        }
        .confirmationDialog(
            "Remove Login Item?",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let item = itemToRemove {
                    Task {
                        await viewModel.remove(item: item)
                        itemToRemove = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                itemToRemove = nil
            }
        } message: {
            if let item = itemToRemove {
                Text("This will disable and remove '\(item.name)' from your login items. The plist file will be moved to trash.")
            }
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
            
            if let result = viewModel.scanResult {
                Text("\(result.enabledCount) enabled, \(result.disabledCount) disabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning login items...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var initialStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Click Scan to check login items")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("No login items found")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func contentView(_ result: LoginItemsScanResult) -> some View {
        VStack(spacing: 16) {
            GroupBox("Summary") {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundStyle(.blue)
                            Text("Total Items:")
                                .foregroundStyle(.secondary)
                            Text("\(result.items.count)")
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Enabled:")
                                .foregroundStyle(.secondary)
                            Text("\(result.enabledCount)")
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Disabled:")
                                .foregroundStyle(.secondary)
                            Text("\(result.disabledCount)")
                                .fontWeight(.semibold)
                        }
                    }
                    Spacer()
                }
                .padding()
            }
            
            ForEach(LoginItemType.allCases, id: \.self) { type in
                loginItemsGroupBox(result: result, type: type)
            }
        }
    }
    
    @ViewBuilder
    private func loginItemsGroupBox(result: LoginItemsScanResult, type: LoginItemType) -> some View {
        let items = result.items(for: type)
        if !items.isEmpty {
            GroupBox(type.displayName) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(items.count) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    List {
                        ForEach(items) { item in
                            LoginItemRow(
                                item: item,
                                isToggling: viewModel.togglingItemId == item.id
                            ) { enable in
                                Task {
                                    await viewModel.toggle(item: item, enable: enable)
                                }
                            } onRemove: {
                                itemToRemove = item
                                showRemoveConfirmation = true
                            }
                        }
                    }
                    .listStyle(.plain)
                    .frame(minHeight: CGFloat(min(items.count, 5)) * 60 + 20)
                }
            }
        }
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

struct LoginItemRow: View {
    let item: LoginItem
    let isToggling: Bool
    let onToggle: (Bool) -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if isToggling {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20)
            } else {
                Toggle("", isOn: Binding(
                    get: { item.isEnabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.checkbox)
                .disabled(item.isSystemItem)
            }
            
            Image(systemName: iconForType(item.itemType))
                .foregroundStyle(colorForType(item.itemType))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.name)
                        .font(.headline)
                    if item.isSystemItem {
                        Text("System")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                if let program = item.programPath {
                    Text(PathUtils.shorten(program))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if !item.isSystemItem {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .opacity(item.isSystemItem ? 0.7 : 1.0)
    }
    
    private func iconForType(_ type: LoginItemType) -> String {
        switch type {
        case .launchAgent: return "bolt.fill"
        case .launchDaemon: return "gearshape.2.fill"
        case .loginItem: return "person.fill"
        }
    }
    
    private func colorForType(_ type: LoginItemType) -> Color {
        switch type {
        case .launchAgent: return .blue
        case .launchDaemon: return .purple
        case .loginItem: return .green
        }
    }
}

#Preview {
    LoginItemsView()
        .frame(width: 700, height: 600)
}
