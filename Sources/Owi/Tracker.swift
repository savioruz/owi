import Foundation

/// Tracks the current schema version in the database
public struct Tracker: Sendable {
  private let driver: any DatabaseDriver
  private let tableName: String

  public init(driver: any DatabaseDriver, tableName: String = "owi_schema") {
    self.driver = driver
    self.tableName = tableName
  }

  /// Ensure the schema version tracking table exists
  public func setup() async throws {
    try await driver.createSchemaTable(named: tableName)
  }

  /// Get the current schema version
  public func getVersion() async throws -> Int {
    guard let schema = try await driver.getSchemaVersion(from: tableName) else {
      return 0
    }
    return schema.version
  }

  /// Check if the schema is in a dirty state
  public func isDirty() async throws -> Bool {
    guard let schema = try await driver.getSchemaVersion(from: tableName) else {
      return false
    }
    return schema.dirty
  }

  /// Update the schema version
  public func setVersion(_ version: Int, dirty: Bool = false) async throws {
    try await driver.updateSchemaVersion(version, dirty: dirty, in: tableName)
  }
}
