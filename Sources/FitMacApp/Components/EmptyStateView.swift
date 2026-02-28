import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String?
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(
        icon: String,
        title: String,
        description: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: FitMacSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.title2)
                .foregroundStyle(.primary)
            
            if let description = description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, FitMacSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(FitMacSpacing.xxl)
    }
}

struct ScanningStateView: View {
    let message: String
    var itemCount: Int = 0
    
    var body: some View {
        VStack(spacing: FitMacSpacing.lg) {
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                ProgressView()
                    .scaleEffect(1.2)
            }
            
            Text(message)
                .font(.headline)
                .foregroundStyle(.primary)
            
            if itemCount > 0 {
                Text("\(itemCount) items found")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(FitMacSpacing.xxl)
    }
}

struct NoResultStateView: View {
    var body: some View {
        EmptyStateView(
            icon: "checkmark.circle",
            title: "All Clean!",
            description: "No items were found that need cleaning."
        )
    }
}

struct ErrorStateView: View {
    let message: String
    let retryAction: (() -> Void)?
    
    init(message: String, retryAction: (() -> Void)? = nil) {
        self.message = message
        self.retryAction = retryAction
    }
    
    var body: some View {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: "Something went wrong",
            description: message,
            actionTitle: retryAction != nil ? "Try Again" : nil,
            action: retryAction
        )
    }
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "trash.circle",
        title: "No Cache Found",
        description: "Click Scan to find cache files",
        actionTitle: "Scan Now",
        action: {}
    )
}

#Preview("Scanning State") {
    ScanningStateView(message: "Scanning cache files...", itemCount: 42)
}

#Preview("No Result") {
    NoResultStateView()
}

#Preview("Error State") {
    ErrorStateView(message: "Failed to scan files") {}
}
