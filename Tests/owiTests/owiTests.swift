#if canImport(XCTest)
  import XCTest
  import Foundation
  @testable import Owi

  // MARK: - Migration Tests (Version Extraction)

  final class MigrationTests: XCTestCase {

    func test_migrationVersionExtraction() throws {
      let migration = Migration(
        id: "001_create_users",
        upSQL: "CREATE TABLE users (id INTEGER);",
        downSQL: "DROP TABLE users;",
        filePath: "/path/to/001_create_users.sql"
      )

      XCTAssertEqual(migration.version, 1, "Migration should extract version 1 from ID")
    }

    func test_migrationVersionMultipleDigits() throws {
      let migration = Migration(
        id: "123_add_index",
        upSQL: "CREATE INDEX;",
        downSQL: "DROP INDEX;",
        filePath: "/path/to/123_add_index.sql"
      )

      XCTAssertEqual(migration.version, 123, "Migration should extract version 123 from ID")
    }

    func test_migrationVersionInvalid() throws {
      let migration = Migration(
        id: "invalid_migration",
        upSQL: "CREATE TABLE test;",
        downSQL: "DROP TABLE test;",
        filePath: "/path/to/invalid_migration.sql"
      )

      XCTAssertNil(migration.version, "Migration should return nil for invalid version format")
    }

    func test_migrationVersionLeadingZeros() throws {
      let migration = Migration(
        id: "001_initial",
        upSQL: "CREATE TABLE test;",
        downSQL: "DROP TABLE test;",
        filePath: "/path/to/001_initial.sql"
      )

      XCTAssertEqual(
        migration.version, 1, "Migration should handle leading zeros and return version 1")
    }
  }

  // MARK: - Parser Tests

  final class ParserTests: XCTestCase {

    func test_parseSingleUpDownPair() throws {
      let content = """
        -- migrate:up
        CREATE TABLE users (id INTEGER PRIMARY KEY);

        -- migrate:down
        DROP TABLE users;
        """

      let tempURL = createTempFile(content: content, filename: "001_test.sql")
      defer { try? FileManager.default.removeItem(at: tempURL) }

      let parser = Parser()
      let migration = try parser.parse(fileURL: tempURL)

      XCTAssertEqual(migration.id, "001_test")
      XCTAssertTrue(migration.upSQL.contains("CREATE TABLE users"))
      XCTAssertTrue(migration.downSQL.contains("DROP TABLE users"))
    }

    func test_parseMultipleUpDownPairs() throws {
      let content = """
        -- migrate:up
        CREATE TABLE users (id INTEGER PRIMARY KEY);

        -- migrate:down
        DROP TABLE users;

        -- migrate:up
        ALTER TABLE users ADD COLUMN email TEXT;

        -- migrate:down
        ALTER TABLE users DROP COLUMN email;
        """

      let tempURL = createTempFile(content: content, filename: "002_test.sql")
      defer { try? FileManager.default.removeItem(at: tempURL) }

      let parser = Parser()
      let migration = try parser.parse(fileURL: tempURL)

      XCTAssertEqual(migration.id, "002_test")
      XCTAssertTrue(migration.upSQL.contains("CREATE TABLE users"))
      XCTAssertTrue(migration.upSQL.contains("ALTER TABLE users ADD COLUMN email"))
      XCTAssertTrue(migration.downSQL.contains("DROP COLUMN email"))
      XCTAssertTrue(migration.downSQL.contains("DROP TABLE users"))
    }

    func test_parseEmptyFile() throws {
      let content = ""
      let tempURL = createTempFile(content: content, filename: "003_empty.sql")
      defer { try? FileManager.default.removeItem(at: tempURL) }

      let parser = Parser()

      // Checks that an error is thrown when parsing the empty file
      XCTAssertThrowsError(try parser.parse(fileURL: tempURL))
    }

    func test_parseMissingUpSection() throws {
      let content = """
        -- migrate:down
        DROP TABLE users;
        """

      let tempURL = createTempFile(content: content, filename: "004_test.sql")
      defer { try? FileManager.default.removeItem(at: tempURL) }

      let parser = Parser()

      // Checks that an error is thrown (likely MigrationError, if it's public)
      XCTAssertThrowsError(try parser.parse(fileURL: tempURL)) { error in
        // Asserting the error type if MigrationError is accessible:
        // XCTAssertTrue(error is MigrationError)
      }
    }

    func test_parseWithComments() throws {
      let content = """
        -- This is a comment
        -- migrate:up
        -- Create users table
        CREATE TABLE users (id INTEGER);

        -- migrate:down
        -- Drop users table
        DROP TABLE users;
        """

      let tempURL = createTempFile(content: content, filename: "005_test.sql")
      defer { try? FileManager.default.removeItem(at: tempURL) }

      let parser = Parser()
      let migration = try parser.parse(fileURL: tempURL)

      XCTAssertTrue(migration.upSQL.contains("CREATE TABLE users"))
      XCTAssertTrue(migration.downSQL.contains("DROP TABLE users"))
    }
  }

  // MARK: - SchemaVersion Tests

  final class SchemaVersionTests: XCTestCase {
    func test_schemaVersionInitialization() {
      let date = Date()
      let schema = SchemaVersion(
        id: 1,
        version: 5,
        dirty: false,
        modifiedAt: date
      )

      XCTAssertEqual(schema.id, 1)
      XCTAssertEqual(schema.version, 5)
      XCTAssertFalse(schema.dirty)
      XCTAssertEqual(schema.modifiedAt, date)
    }

    func test_schemaVersionDirtyFlag() {
      let dirtySchema = SchemaVersion(
        id: 1,
        version: 3,
        dirty: true,
        modifiedAt: Date()
      )

      XCTAssertTrue(dirtySchema.dirty)
    }
  }

  // MARK: - Integration Tests

  final class IntegrationTests: XCTestCase {

    func test_parserLoadsMultipleMigrationsFromDirectory() throws {
      let tempDir = createTempDirectory()
      defer { try? FileManager.default.removeItem(at: tempDir) }

      // Create multiple migration files
      let migration1 = """
        -- migrate:up
        CREATE TABLE users (id INTEGER);
        -- migrate:down
        DROP TABLE users;
        """

      let migration2 = """
        -- migrate:up
        CREATE TABLE posts (id INTEGER);
        -- migrate:down
        DROP TABLE posts;
        """

      try migration1.write(
        to: tempDir.appendingPathComponent("001_create_users.sql"),
        atomically: true,
        encoding: .utf8
      )

      try migration2.write(
        to: tempDir.appendingPathComponent("002_create_posts.sql"),
        atomically: true,
        encoding: .utf8
      )

      let parser = Parser()
      let migrations = try parser.loadMigrations(from: tempDir)

      XCTAssertEqual(migrations.count, 2)
      XCTAssertTrue(migrations.contains { $0.id == "001_create_users" })
      XCTAssertTrue(migrations.contains { $0.id == "002_create_posts" })
    }

    func test_migrationsCanBeSortedByVersion() throws {
      let tempDir = createTempDirectory()
      defer { try? FileManager.default.removeItem(at: tempDir) }

      // Create migrations out of order
      let files = [
        ("003_third.sql", "-- migrate:up\nCREATE TABLE c;\n-- migrate:down\nDROP TABLE c;"),
        ("001_first.sql", "-- migrate:up\nCREATE TABLE a;\n-- migrate:down\nDROP TABLE a;"),
        ("002_second.sql", "-- migrate:up\nCREATE TABLE b;\n-- migrate:down\nDROP TABLE b;"),
      ]

      for (filename, content) in files {
        try content.write(
          to: tempDir.appendingPathComponent(filename),
          atomically: true,
          encoding: .utf8
        )
      }

      let parser = Parser()
      let migrations = try parser.loadMigrations(from: tempDir)

      XCTAssertEqual(migrations.count, 3)

      // Check they can be sorted by version
      let sorted = migrations.sorted { ($0.version ?? 0) < ($1.version ?? 0) }
      XCTAssertEqual(sorted[0].id, "001_first")
      XCTAssertEqual(sorted[1].id, "002_second")
      XCTAssertEqual(sorted[2].id, "003_third")
    }
  }

  // MARK: - Helper Functions (Adapted for XCTest environment)

  /// Creates a temporary file with the given content.
  private func createTempFile(content: String, filename: String) -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent(filename)
    // Using try? since file writing errors shouldn't prevent the test from running,
    // but should be caught by the test's error handling if the file isn't found.
    try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    return fileURL
  }

  /// Creates a temporary directory.
  private func createTempDirectory() -> URL {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(
      at: tempDir,
      withIntermediateDirectories: true
    )
    return tempDir
  }
#endif
