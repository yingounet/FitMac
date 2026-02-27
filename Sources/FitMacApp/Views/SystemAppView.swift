import SwiftUI
import FitMacCore

struct SystemAppView: View {
    @StateObject private var viewModel = SystemAppViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isScanning {
                scanningView
            } else if let result = viewModel.scanResult {
                if result.apps.isEmpty {
                    emptyView
                } else {
                    resultsView(result)
                }
            } else {
                initialView
            }
        }
        .navigationTitle("System Apps")
        .onAppear {
            viewModel.scan()
        }
        .alert("Remove System App?", isPresented: $viewModel.showRemoveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let app = viewModel.appToRemove {
                    Task {
                        await viewModel.removeApp(app, dryRun: false)
                    }
                }
            }
        } message: {
            if let app = viewModel.appToRemove {
                Text("Are you sure you want to remove \(app.name)? This action cannot be undone.")
            }
        }
    }
    
    private var initialView: some View {
        VStack(spacing: 20) {
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            Text("Scan System Apps")
                .font(.title2)
            Text("Find system apps that can be safely removed to free up space")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Start Scan") {
                viewModel.scan()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var scanningView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning system apps...")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("No Removable Apps Found")
                .font(.title2)
            Text("All system apps are either essential or already removed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func resultsView(_ result: SystemAppScanResult) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Found \(result.apps.count) removable apps")
                        .font(.headline)
                    Text("Total size: \(SizeFormatter.format(result.totalSize))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button("Rescan") {
                        viewModel.scan()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            List {
                ForEach(SystemAppCategory.allCases, id: \.self) { category in
                    let appsInCategory = result.apps(for: category)
                    if !appsInCategory.isEmpty {
                        Section(category.displayName) {
                            ForEach(appsInCategory) { app in
                                SystemAppRow(app: app) {
                                    viewModel.confirmRemove(app)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}

struct SystemAppRow: View {
    let app: SystemApp
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: app.category.icon)
                .font(.title2)
                .foregroundStyle(colorForWarning(app.warningLevel))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(app.name)
                        .font(.headline)
                    
                    if let version = app.version {
                        Text("v\(version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    warningBadge(app.warningLevel)
                }
                
                Text(app.path.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(SizeFormatter.format(app.size))
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Button("Remove") {
                    onRemove()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(app.warningLevel == .warning)
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func warningBadge(_ level: WarningLevel) -> some View {
        switch level {
        case .safe:
            EmptyView()
        case .caution:
            Text("Caution")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
        case .warning:
            Text("Not Recommended")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.2))
                .foregroundStyle(.red)
                .clipShape(Capsule())
        }
    }
    
    private func colorForWarning(_ level: WarningLevel) -> Color {
        switch level {
        case .safe: return .green
        case .caution: return .orange
        case .warning: return .red
        }
    }
}

#Preview {
    SystemAppView()
        .frame(width: 800, height: 600)
}
