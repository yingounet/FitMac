import SwiftUI
import FitMacCore

struct LogView: View {
    @StateObject private var viewModel = LogViewModel()
    @State private var showClearConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            toolbarSection
            Divider()
            
            if viewModel.isLoading {
                loadingView
            } else if viewModel.logs.isEmpty {
                emptyStateView
            } else {
                logsListView
            }
        }
        .navigationTitle("Cleanup History")
        .task { await viewModel.loadLogs() }
        .alert("Clear History", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task { await viewModel.clearLogs() }
            }
        } message: {
            Text("Are you sure you want to clear all cleanup history?")
        }
    }
    
    private var toolbarSection: some View {
        HStack {
            Text("\(viewModel.logs.count) entries")
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if !viewModel.logs.isEmpty {
                Button("Clear History") {
                    showClearConfirmation = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            
            Button {
                Task { await viewModel.loadLogs() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.primary.opacity(0.05))
    }
    
    private var loadingView: some View {
        ScanningStateView(message: "Loading history...")
    }
    
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "clock.arrow.circlepath",
            title: "No cleanup history",
            description: "Cleanup operations will be logged here"
        )
    }
    
    private var logsListView: some View {
        List {
            ForEach(viewModel.logs) { log in
                LogEntryRow(log: log)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

struct LogEntryRow: View {
    let log: CleanupLog
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForOperation(log.operation))
                    .foregroundStyle(colorForOperation(log.operation))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.operation)
                        .font(.headline)
                    Text(log.date.formatted(date: .complete, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(log.itemsDeleted) items")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(SizeFormatter.format(log.freedSpace))
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation { isExpanded.toggle() }
            }
            
            if isExpanded && !log.details.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(log.details.prefix(10), id: \.self) { path in
                        HStack(spacing: 4) {
                            Image(systemName: "doc")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(shortenPath(path))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    if log.details.count > 10 {
                        Text("... and \(log.details.count - 10) more")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.leading, 28)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func iconForOperation(_ operation: String) -> String {
        if operation.contains("Cache") { return "trash.circle.fill" }
        if operation.contains("Large") { return "doc.fill" }
        if operation.contains("Leftover") { return "xmark.bin.fill" }
        return "checkmark.circle.fill"
    }
    
    private func colorForOperation(_ operation: String) -> Color {
        if operation.contains("Cache") { return .orange }
        if operation.contains("Large") { return .purple }
        if operation.contains("Leftover") { return .red }
        return .green
    }
    
    private func shortenPath(_ path: String) -> String {
        PathUtils.shorten(path)
    }
}

#Preview {
    LogView()
        .frame(width: 800, height: 600)
}
