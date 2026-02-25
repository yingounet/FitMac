import Foundation
import FitMacCore
import Combine

@MainActor
final class DiskStatusViewModel: ObservableObject {
    @Published var diskStatus: DiskStatus?
    
    func refresh() {
        diskStatus = DiskUtils.getDiskStatus()
    }
}
