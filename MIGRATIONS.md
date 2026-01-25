# SwiftData Schema Migrations

This document explains how the app's data persistence is structured to prevent data loss during model changes.

## Current Setup

The app now uses SwiftData's schema versioning and migration system. This ensures that when you modify the data model, existing user data can be properly migrated to the new schema.

### Files

- **Task.swift** - The main data model
- **SchemaVersions.swift** - Schema versioning and migration configuration
- **TimeApp.swift** - Initializes the ModelContainer with the migration plan

## App Version vs Schema Version

These are **different concepts** and should not be kept in sync:

- **App Version** (e.g., 1.0.0, 1.1.0, 2.0.0) - User-facing version that changes with every release
- **Schema Version** (e.g., v1, v2, v3) - Internal database structure version that only changes when the Task model changes

Your app might go through many versions (1.0.0 → 1.0.1 → 1.1.0) while staying on Schema v1, then finally bump to Schema v2 when you add a new property to Task.

## How It Works

### Schema Version 1 (Current)

The current schema (`SchemaV1`) includes:
- `Task` model with properties: id, taskDescription, startTime, endTime, isActive

The app initializes with:
```swift
let container = try ModelContainer(
    for: Task.self,
    migrationPlan: TaskMigrationPlan.self
)
```

This tells SwiftData to use the migration plan, which currently has no migrations (since we're on version 1).

## Making Schema Changes

When you need to modify the Task model in the future, follow these steps:

### 1. Lightweight Changes (Recommended)

For simple changes like adding optional properties or renaming properties, use lightweight migration:

1. **Define the new schema version** in `SchemaVersions.swift`:

```swift
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        let taskType: any PersistentModel.Type = Task.self
        return [taskType]
    }
}
```

2. **Update the migration plan**:

```swift
enum TaskMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]  // Add new version
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
        ]
    }
}
```

3. **Update the Task model** with your changes

4. SwiftData will automatically migrate existing data on next launch

### 2. Complex Changes (Custom Migration)

For complex changes like data transformations or removing required properties, use custom migration:

```swift
.custom(
    fromVersion: SchemaV1.self,
    toVersion: SchemaV2.self,
    willMigrate: { context in
        // Pre-migration logic
        // Access old data and prepare for migration
    },
    didMigrate: { context in
        // Post-migration logic
        // Transform or clean up data
    }
)
```

## Examples of Common Changes

### Adding an Optional Property

**New property:**
```swift
@Model
final class Task: Identifiable {
    // ... existing properties ...
    var tags: [String]?  // New optional property
}
```

**Migration:** Lightweight (automatic)

### Renaming a Property

Use `@Attribute(.originalName("oldName"))`:

```swift
@Attribute(.originalName("taskDescription"))
var description: String  // Renamed from taskDescription
```

**Migration:** Lightweight (automatic)

### Changing Property Type

This requires custom migration to transform the data.

### Adding a Required Property

This requires custom migration to provide default values for existing records.

## Preventing Data Loss

The migration system prevents data loss by:

1. **Versioning** - Each schema version is tracked
2. **Staged migrations** - Changes are applied in sequence
3. **Safe defaults** - SwiftData validates migrations before applying them
4. **Automatic backups** - SwiftData creates backups before major migrations

## Testing Migrations

Before releasing schema changes:

1. Create test data in the old schema
2. Update to the new schema
3. Run the app and verify data migrated correctly
4. Check that all existing records are present and correct

## Recovering from the TimeEntry → Task Rename

The original rename from `TimeEntry` to `Task` caused data loss because no migration was configured. Unfortunately, that data cannot be automatically recovered without:

1. The original database file (usually in `~/Library/Application Support/TwiiK.Time/`)
2. Creating a custom migration that reads the old `TimeEntry` table

If you still have the old database file and need to recover that data, you can create a custom migration that reads from the old table name.
