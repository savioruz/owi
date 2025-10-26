import Foundation

/// Runs migrations against a database
public struct Runner: Sendable {
  private let driver: any DatabaseDriver
  private let parser: Parser
  private let tracker: Tracker
  private let migrationDir: String

  public init(
    driver: any DatabaseDriver,
    migrationDir: String,
    schemaTableName: String = "owi_schema"
  ) {
    self.driver = driver
    self.parser = Parser()
    self.tracker = Tracker(driver: driver, tableName: schemaTableName)
    self.migrationDir = migrationDir
  }

  /// Setup the schema version tracking table
  public func setup() async throws {
    try await tracker.setup()
  }

  /// Run all pending migrations
  public func migrate() async throws {
    try await setup()

    // Check if schema is dirty
    if try await tracker.isDirty() {
      throw MigrationError.databaseError(
        "Database is in a dirty state. Please resolve manually or rollback.")
    }

    let migrations = try parser.loadMigrations(from: URL(fileURLWithPath: migrationDir))
    let currentVersion = try await tracker.getVersion()

    let pending = migrations.filter { migration in
      guard let version = migration.version else { return false }
      return version > currentVersion
    }.sorted { ($0.version ?? 0) < ($1.version ?? 0) }

    guard !pending.isEmpty else {
      print("No pending migrations")
      return
    }

    print("Running \(pending.count) migration(s)...")

    for migration in pending {
      guard let version = migration.version else {
        throw MigrationError.databaseError("Migration \(migration.id) has no version")
      }

      print("  Applying: \(migration.id)")

      // Set dirty flag before migration
      try await tracker.setVersion(version, dirty: true)

      // Execute migration
      try await driver.execute(migration.upSQL)

      // Clear dirty flag after successful migration
      try await tracker.setVersion(version, dirty: false)

      print("  ✓ Applied: \(migration.id)")
    }

    print("Migration complete!")
  }

  /// Rollback the last N migrations
  public func rollback(count: Int = 1) async throws {
    try await setup()

    // Check if schema is dirty
    if try await tracker.isDirty() {
      throw MigrationError.databaseError("Database is in a dirty state. Please resolve manually.")
    }

    let currentVersion = try await tracker.getVersion()

    guard currentVersion > 0 else {
      print("No migrations to rollback")
      return
    }

    let migrations = try parser.loadMigrations(from: URL(fileURLWithPath: migrationDir))

    // Get migrations to rollback (in reverse order)
    let toRollback =
      migrations
      .filter { migration in
        guard let version = migration.version else { return false }
        return version <= currentVersion && version > (currentVersion - count)
      }
      .sorted { ($0.version ?? 0) > ($1.version ?? 0) }

    guard !toRollback.isEmpty else {
      print("No migrations to rollback")
      return
    }

    print("Rolling back \(toRollback.count) migration(s)...")

    for migration in toRollback {
      guard let version = migration.version else {
        continue
      }

      print("  Reverting: \(migration.id)")

      // Set dirty flag before rollback
      try await tracker.setVersion(version, dirty: true)

      // Execute rollback
      try await driver.execute(migration.downSQL)

      // Update to previous version and clear dirty flag
      try await tracker.setVersion(version - 1, dirty: false)

      print("  ✓ Reverted: \(migration.id)")
    }

    print("Rollback complete!")
  }

  /// Show migration status
  public func status() async throws {
    try await setup()

    let migrations = try parser.loadMigrations(from: URL(fileURLWithPath: migrationDir))
      .sorted { ($0.version ?? 0) < ($1.version ?? 0) }
    let currentVersion = try await tracker.getVersion()
    let isDirty = try await tracker.isDirty()

    print("Migration Status:")
    print("[i] Current Version: \u{001B}[32m\(currentVersion)\u{001B}[0m")
    print("[i] Dirty: \(isDirty ? "\u{001B}[33mYES\u{001B}[0m ⚠️" : "\u{001B}[32mNO\u{001B}[0m")")
    print("─────────────────────────────────────")

    var appliedCount = 0
    for migration in migrations {
      guard let version = migration.version else { continue }
      let status = version <= currentVersion ? "✓" : "✗"
      print("\(status) \(migration.id) (v\(version))")
      if version <= currentVersion {
        appliedCount += 1
      }
    }

    let pending = migrations.count - appliedCount
    print("─────────────────────────────────────")
    print("Applied: \(appliedCount), Pending: \(pending)")
  }

  /// Close database connection
  public func close() async throws {
    try await driver.close()
  }
}
