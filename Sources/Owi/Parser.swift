import Foundation

/// Parser for SQL migration files
public struct Parser: Sendable {

  public init() {}

  /// Parse a single migration file
  /// - Parameters:
  ///   - fileURL: The URL of the migration file
  /// - Returns: A parsed Migration object
  /// - Throws: MigrationError if parsing fails
  public func parse(fileURL: URL) throws -> Migration {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw MigrationError.fileNotFound(fileURL.path)
    }

    let content = try String(contentsOf: fileURL, encoding: .utf8)
    let migrationId = fileURL.deletingPathExtension().lastPathComponent

    return try parse(content: content, id: migrationId, filePath: fileURL.path)
  }

  /// Parse migration content from a string
  /// Supports multiple up/down sections in a single file
  /// - Parameters:
  ///   - content: The SQL content to parse
  ///   - id: The migration identifier
  ///   - filePath: The file path (for reference)
  /// - Returns: A parsed Migration object
  /// - Throws: MigrationError if parsing fails
  public func parse(content: String, id: String, filePath: String) throws -> Migration {
    let lines = content.components(separatedBy: .newlines)

    var upSections: [String] = []
    var downSections: [String] = []
    var currentUpSQL = ""
    var currentDownSQL = ""
    var currentSection: Section?

    for line in lines {
      let trimmedLine = line.trimmingCharacters(in: .whitespaces)

      // Check for section markers
      if trimmedLine.lowercased().hasPrefix("-- migrate:up")
        || trimmedLine.lowercased().hasPrefix("--migrate:up")
      {
        // Save previous down section if exists
        if currentSection == .down {
          let sql = currentDownSQL.trimmingCharacters(in: .whitespacesAndNewlines)
          if !sql.isEmpty {
            downSections.append(sql)
          }
          currentDownSQL = ""
        }
        currentSection = .up
        continue
      } else if trimmedLine.lowercased().hasPrefix("-- migrate:down")
        || trimmedLine.lowercased().hasPrefix("--migrate:down")
      {
        // Save previous up section if exists
        if currentSection == .up {
          let sql = currentUpSQL.trimmingCharacters(in: .whitespacesAndNewlines)
          if !sql.isEmpty {
            upSections.append(sql)
          }
          currentUpSQL = ""
        }
        currentSection = .down
        continue
      }

      // Add lines to the appropriate section
      switch currentSection {
      case .up:
        currentUpSQL += line + "\n"
      case .down:
        currentDownSQL += line + "\n"
      case .none:
        // Ignore lines before any section marker
        continue
      }
    }

    // Save the last section
    if currentSection == .up {
      let sql = currentUpSQL.trimmingCharacters(in: .whitespacesAndNewlines)
      if !sql.isEmpty {
        upSections.append(sql)
      }
    } else if currentSection == .down {
      let sql = currentDownSQL.trimmingCharacters(in: .whitespacesAndNewlines)
      if !sql.isEmpty {
        downSections.append(sql)
      }
    }

    // Validate that we have at least one up section
    guard !upSections.isEmpty else {
      throw MigrationError.missingUpSection
    }

    // Combine all sections with semicolons
    let upSQL = upSections.joined(separator: ";\n\n")
    let downSQL = downSections.reversed().joined(separator: ";\n\n")

    return Migration(
      id: id,
      upSQL: upSQL,
      downSQL: downSQL,
      filePath: filePath
    )
  }

  /// Load all migrations from a directory
  /// - Parameter directoryURL: The directory containing migration files
  /// - Returns: An array of parsed migrations, sorted by version
  /// - Throws: MigrationError if parsing fails
  public func loadMigrations(from directoryURL: URL) throws -> [Migration] {
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: directoryURL.path) else {
      throw MigrationError.fileNotFound(directoryURL.path)
    }

    let files = try fileManager.contentsOfDirectory(
      at: directoryURL,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )

    let sqlFiles = files.filter { $0.pathExtension == "sql" }

    var migrations: [Migration] = []
    var seenIds = Set<String>()

    for fileURL in sqlFiles {
      let migration = try parse(fileURL: fileURL)

      // Check for duplicate IDs
      if seenIds.contains(migration.id) {
        throw MigrationError.duplicateMigration(migration.id)
      }
      seenIds.insert(migration.id)

      migrations.append(migration)
    }

    // Sort migrations by version number
    return migrations.sorted { lhs, rhs in
      guard let lhsVersion = lhs.version,
        let rhsVersion = rhs.version
      else {
        // If no version number, sort alphabetically
        return lhs.id < rhs.id
      }
      return lhsVersion < rhsVersion
    }
  }

  private enum Section {
    case up
    case down
  }
}
