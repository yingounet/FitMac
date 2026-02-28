import SwiftUI

struct ProgressOverlay<Content: View>: View {
    let isShowing: Bool
    let progress: Double?
    let message: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        ZStack {
            content()
                .disabled(isShowing)
                .blur(radius: isShowing ? 2 : 0)
            
            if isShowing {
                overlayContent
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(FitMacAnimation.spring, value: isShowing)
    }
    
    private var overlayContent: some View {
        VStack(spacing: FitMacSpacing.lg) {
            if let progress = progress {
                circularProgress(progress)
            } else {
                indeterminateProgress
            }
            
            Text(message)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .padding(FitMacSpacing.xxl)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .frame(maxWidth: 280)
    }
    
    private func circularProgress(_ progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 6)
                .frame(width: 60, height: 60)
            
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 60, height: 60)
                .animation(FitMacAnimation.progress, value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
        }
    }
    
    private var indeterminateProgress: some View {
        ProgressView()
            .scaleEffect(1.5)
            .frame(width: 60, height: 60)
    }
}

struct ScanningOverlay: ViewModifier {
    let isScanning: Bool
    let scannedCount: Int
    let message: String
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if isScanning {
                    ZStack {
                        Color.primary.opacity(0.1)
                            .ignoresSafeArea()
                        
                        VStack(spacing: FitMacSpacing.lg) {
                            ZStack {
                                Circle()
                                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 4)
                                    .frame(width: 50, height: 50)
                                
                                ProgressView()
                                    .scaleEffect(1.2)
                            }
                            
                            Text(message)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            if scannedCount > 0 {
                                Text("\(scannedCount) items found")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(FitMacSpacing.xl)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .transition(.opacity)
                }
            }
            .animation(FitMacAnimation.`default`, value: isScanning)
    }
}

extension View {
    func scanningOverlay(isScanning: Bool, scannedCount: Int = 0, message: String = "Scanning...") -> some View {
        modifier(ScanningOverlay(isScanning: isScanning, scannedCount: scannedCount, message: message))
    }
}

#Preview("Progress Overlay") {
    ProgressOverlay(isShowing: true, progress: 0.65, message: "Scanning files...") {
        List {
            ForEach(0..<20) { i in
                Text("Item \(i)")
            }
        }
    }
}

#Preview("Indeterminate") {
    ProgressOverlay(isShowing: true, progress: nil, message: "Loading...") {
        Color.gray.opacity(0.2)
    }
}

#Preview("Scanning Modifier") {
    List {
        ForEach(0..<20) { i in
            Text("Item \(i)")
        }
    }
    .scanningOverlay(isScanning: true, scannedCount: 42, message: "Scanning cache...")
}
