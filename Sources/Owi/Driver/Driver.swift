import Foundation

/// Protocol for database drivers that support migrations
public protocol DatabaseDriver: Sendable {
  /// Execute a raw SQL query
  func execute(_ sql: String) async throws

  /// Get the current schema version
  func getSchemaVersion(from table: String) async throws -> SchemaVersion?

  /// Update the schema version
  func updateSchemaVersion(_ version: Int, dirty: Bool, in table: String) async throws

  /// Create the schema version tracking table if it doesn't exist
  func createSchemaTable(named table: String) async throws

  /// Close the database connection
  func close() async throws
}
