import SwiftUI
import FitMacCore

struct FullDiskAccessView: View {
    @State private var hasPermission = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: hasPermission ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(hasPermission ? .green : .orange)
            
            Text(hasPermission ? "Full Disk Access Enabled" : "Full Disk Access Required")
                .font(.title)
                .fontWeight(.semibold)
            
            if hasPermission {
                Text("FitMac has access to scan all locations on your Mac.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                VStack(spacing: 16) {
                    Text("FitMac needs Full Disk Access to scan system caches and application leftovers.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        instructionStep(number: 1, text: "Click the button below to open System Settings")
                        instructionStep(number: 2, text: "Navigate to Privacy & Security → Full Disk Access")
                        instructionStep(number: 3, text: "Click the + button and add FitMac")
                        instructionStep(number: 4, text: "Restart FitMac")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Button {
                        PermissionHelper.openSystemPreferencesPrivacy()
                    } label: {
                        Label("Open System Settings", systemImage: "gear")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button {
                        hasPermission = PermissionHelper.hasFullDiskAccess()
                    } label: {
                        Text("Check Again")
                    }
                }
            }
        }
        .padding(40)
        .frame(maxWidth: 500)
        .onAppear {
            hasPermission = PermissionHelper.hasFullDiskAccess()
        }
    }
    
    private func instructionStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    FullDiskAccessView()
        .frame(width: 500, height: 500)
}
