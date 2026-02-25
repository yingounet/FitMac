import SwiftUI
import FitMacCore

struct HomeView: View {
    @StateObject private var viewModel = DiskStatusViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                diskStatusSection
                quickActionsSection
            }
            .padding()
        }
        .navigationTitle("Home")
        .onAppear { viewModel.refresh() }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("FitMac")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Make Your Mac Fit Again")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var diskStatusSection: some View {
        GroupBox("Disk Status") {
            if let status = viewModel.diskStatus {
                VStack(spacing: 16) {
                    DiskGaugeView(status: status)
                        .frame(height: 200)
                    
                    HStack(spacing: 32) {
                        StatusItem(title: "Total", value: SizeFormatter.format(status.totalSpace))
                        StatusItem(title: "Used", value: SizeFormatter.format(status.usedSpace))
                        StatusItem(title: "Available", value: SizeFormatter.format(status.availableSpace))
                    }
                }
                .padding()
            } else {
                Text("Unable to get disk status")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }
    
    private var quickActionsSection: some View {
        GroupBox("Quick Actions") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                QuickActionCard(
                    icon: "trash.circle.fill",
                    title: "Clean Cache",
                    description: "Scan and clean system & app caches",
                    color: .orange
                )
                QuickActionCard(
                    icon: "doc.fill",
                    title: "Find Large Files",
                    description: "Locate large files taking up space",
                    color: .purple
                )
                QuickActionCard(
                    icon: "xmark.bin.fill",
                    title: "Uninstall Apps",
                    description: "Remove apps with all leftovers",
                    color: .red
                )
                QuickActionCard(
                    icon: "gearshape.fill",
                    title: "System Status",
                    description: "View detailed disk information",
                    color: .blue
                )
            }
            .padding()
        }
    }
}

struct DiskGaugeView: View {
    let status: DiskStatus
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 20)
            
            Circle()
                .trim(from: 0, to: status.usedPercentage / 100)
                .stroke(
                    colorForUsage(status.usedPercentage),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: status.usedPercentage)
            
            VStack(spacing: 4) {
                Text("\(Int(status.usedPercentage))%")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text("Used")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func colorForUsage(_ percentage: Double) -> Color {
        if percentage < 60 {
            return .green
        } else if percentage < 80 {
            return .orange
        } else {
            return .red
        }
    }
}

struct StatusItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    HomeView()
        .frame(width: 700, height: 600)
}
