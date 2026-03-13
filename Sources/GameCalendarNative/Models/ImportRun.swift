import Foundation
import SwiftData

@Model
final class ImportRun {
    var source: String
    var startedAt: Date
    var completedAt: Date?
    var status: String          // "Running" | "Completed" | "Failed"
    var itemsInserted: Int
    var itemsUpdated: Int
    var itemsSkipped: Int
    var itemsFiltered: Int
    var errorSummary: String?

    init(source: String) {
        self.source = source
        self.startedAt = Date()
        self.status = "Running"
        self.itemsInserted = 0
        self.itemsUpdated = 0
        self.itemsSkipped = 0
        self.itemsFiltered = 0
    }
}
