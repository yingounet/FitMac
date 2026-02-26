import SwiftUI
import FitMacCore

struct MailAttachmentsView: View {
    @StateObject private var viewModel = MailAttachmentsViewModel()
    @State private var showCleanConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                toolbarSection
                
                if viewModel.isScanning {
                    scanningView
                } else if let result = viewModel.scanResult {
                    if result.attachments.isEmpty {
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
        .navigationTitle("Mail Attachments")
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
            "Remove Mail Attachments?",
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
            Text("This will remove \(viewModel.selectedItems.count) attachment(s), freeing \(SizeFormatter.format(viewModel.totalSelectedSize)). Original emails will remain, but attachments won't be accessible.")
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
                Picker("Sort by", selection: $viewModel.sortBy) {
                    ForEach(MailAttachmentsViewModel.SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .frame(width: 100)
                
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
            Text("Scanning mail attachments...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var initialStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Click Scan to find large mail attachments")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Scan Mail.app for large attachments that can be safely removed")
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
            Text("No large mail attachments found")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("All attachments are smaller than \(SizeFormatter.format(viewModel.minSizeKB * 1024))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func contentView(_ result: MailScanResult) -> some View {
        VStack(spacing: 16) {
            summaryBox(result)
            
            GroupBox("Attachments") {
                List {
                    ForEach(viewModel.sortedAttachments) { attachment in
                        MailAttachmentRow(
                            attachment: attachment,
                            isSelected: viewModel.selectedItems.contains(attachment.id)
                        ) {
                            if viewModel.selectedItems.contains(attachment.id) {
                                viewModel.selectedItems.remove(attachment.id)
                            } else {
                                viewModel.selectedItems.insert(attachment.id)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: 300)
            }
            
            if !viewModel.selectedItems.isEmpty {
                bottomBar
            }
        }
    }
    
    private func summaryBox(_ result: MailScanResult) -> some View {
        GroupBox("Summary") {
            VStack(alignment: .leading, spacing: 8) {
                summaryRow(icon: "envelope.fill", color: .blue, label: "Total Attachments:", value: "\(result.attachments.count)")
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

struct MailAttachmentRow: View {
    let attachment: MailAttachment
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
            
            Image(systemName: "paperclip")
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let mailbox = attachment.mailbox {
                        Text(mailbox)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let date = attachment.receivedDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            Spacer()
            
            Text(SizeFormatter.format(attachment.size))
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
    MailAttachmentsView()
        .frame(width: 700, height: 600)
}
