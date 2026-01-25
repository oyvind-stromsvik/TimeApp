import Foundation
import SwiftData

/// Schema version 1 - Initial version with Task model
/// Fields: id, taskDescription, startTime, endTime, isActive
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        // Reference the Task model from the app
        // Using array literal to avoid Swift.Task ambiguity
        let taskType: any PersistentModel.Type = Task.self
        return [taskType]
    }
}

/// Migration plan for managing schema changes over time
/// Add new schema versions and migration stages here as your data model evolves
enum TaskMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // Migrations will be added here when schema changes
        // Example lightweight migration:
        // .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
        //
        // Example custom migration:
        // .custom(
        //     fromVersion: SchemaV1.self,
        //     toVersion: SchemaV2.self,
        //     willMigrate: { context in
        //         // Pre-migration logic
        //     },
        //     didMigrate: { context in
        //         // Post-migration logic
        //     }
        // )
        []
    }
}


