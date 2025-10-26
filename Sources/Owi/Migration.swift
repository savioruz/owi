import Foundation

public struct Migration: Codable, Sendable {
  /// The migration identifier (e.g., "001_todo")
  public let id: String

  /// The SQL to execute when migrating up
  public let upSQL: String

  /// The SQL to execute when migrating down (rollback)
  public let downSQL: String

  /// The file path of the migration
  public let filePath: String

  public init(id: String, upSQL: String, downSQL: String, filePath: String) {
    self.id = id
    self.upSQL = upSQL
    self.downSQL = downSQL
    self.filePath = filePath
  }

  /// Extract the numeric prefix from the migration ID (e.g., "001" from "001_todo")
  public var version: Int? {
    let components = id.split(separator: "_")
    guard let first = components.first else { return nil }
    return Int(first)
  }
}

/// Represents the schema version state in the database (single row)
public struct SchemaVersion: Codable, Sendable {
  public let id: Int
  public let version: Int
  public let dirty: Bool
  public let modifiedAt: Date

  public init(id: Int = 1, version: Int, dirty: Bool, modifiedAt: Date) {
    self.id = id
    self.version = version
    self.dirty = dirty
    self.modifiedAt = modifiedAt
  }
}

public enum MigrationError: Error, CustomStringConvertible {
  case invalidFormat(String)
  case missingUpSection
  case missingDownSection
  case fileNotFound(String)
  case duplicateMigration(String)
  case databaseError(String)
  case parsingError(String)

  public var description: String {
    switch self {
    case .invalidFormat(let details):
      return "Invalid migration format: \(details)"
    case .missingUpSection:
      return "Missing '-- migrate:up' section in migration file"
    case .missingDownSection:
      return "Missing '-- migrate:down' section in migration file"
    case .fileNotFound(let path):
      return "Migration file not found: \(path)"
    case .duplicateMigration(let id):
      return "Duplicate migration ID: \(id)"
    case .databaseError(let message):
      return "Database error: \(message)"
    case .parsingError(let details):
      return "Error parsing migration: \(details)"
    }
  }
}
