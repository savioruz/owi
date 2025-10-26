import ArgumentParser
import Foundation
import Owi

@main
struct OwiCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "owi",
    abstract: "A simple database migration tool",
    subcommands: [New.self, Migrate.self, Rollback.self, Status.self],
    defaultSubcommand: Status.self
  )
}

extension OwiCLI {
  struct New: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Create a new migration file"
    )

    @Argument(help: "The name of the migration (e.g., create_users_table)")
    var name: String

    @Option(name: [.customShort("m"), .long], help: "Directory to create the migration in")
    var migrationsDir: String = "./migrations"

    func run() throws {
      let fileManager = FileManager.default

      // Create migrations directory if it doesn't exist
      if !fileManager.fileExists(atPath: migrationsDir) {
        try fileManager.createDirectory(
          atPath: migrationsDir,
          withIntermediateDirectories: true
        )
      }

      // Get existing migration count to generate new ID
      let existingFiles = try fileManager.contentsOfDirectory(atPath: migrationsDir)
        .filter { $0.hasSuffix(".sql") }

      let nextNumber = String(format: "%03d", existingFiles.count + 1)
      let filename = "\(nextNumber)_\(name).sql"
      let filepath = "\(migrationsDir)/\(filename)"

      // Create migration template
      let template = """
        -- migrate:up


        -- migrate:down


        """

      try template.write(toFile: filepath, atomically: true, encoding: .utf8)

      print("Created migration: \(filepath)")
    }
  }

  struct Migrate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Run all pending migrations"
    )

    @Option(name: [.customShort("u"), .long], help: "Database URL")
    var databaseUrl: String

    @Option(name: [.customShort("m"), .long], help: "Migrations directory")
    var migrationsDir: String = "./migrations"

    @Option(name: .long, help: "Database type (sqlite, postgres, mysql)")
    var type: String = "sqlite"

    func run() async throws {
      let driver = try await createDriver(type: type, database: databaseUrl)
      let runner = Runner(driver: driver, migrationDir: migrationsDir)

      do {
        try await runner.migrate()
        try await runner.close()
      } catch {
        try? await runner.close()
        throw error
      }
    }
  }

  struct Rollback: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Rollback the last migration(s)"
    )

    @Option(name: [.customShort("u"), .long], help: "Database URL")
    var databaseUrl: String

    @Option(name: [.customShort("m"), .long], help: "Migrations directory")
    var migrationsDir: String = "./migrations"

    @Option(name: .long, help: "Database type (sqlite, postgres, mysql)")
    var type: String = "sqlite"

    @Option(name: .shortAndLong, help: "Number of migrations to rollback")
    var count: Int = 1

    func run() async throws {
      let driver = try await createDriver(type: type, database: databaseUrl)
      let runner = Runner(driver: driver, migrationDir: migrationsDir)

      do {
        try await runner.rollback(count: count)
        try await runner.close()
      } catch {
        try? await runner.close()
        throw error
      }
    }
  }

  struct Status: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show migration status"
    )

    @Option(name: [.customShort("u"), .long], help: "Database URL")
    var databaseUrl: String

    @Option(name: [.customShort("m"), .long], help: "Migrations directory")
    var migrationsDir: String = "./migrations"

    @Option(name: .long, help: "Database type (sqlite, postgres, mysql)")
    var type: String = "sqlite"

    func run() async throws {
      let driver = try await createDriver(type: type, database: databaseUrl)
      let runner = Runner(driver: driver, migrationDir: migrationsDir)

      do {
        try await runner.status()
        try await runner.close()
      } catch {
        try? await runner.close()
        throw error
      }
    }
  }
}

/// Helper function to create database driver based on type
func createDriver(type: String, database: String) async throws -> any DatabaseDriver {
  switch type.lowercased() {
  case "sqlite":
    let config = SQLiteConfiguration(storage: .file(path: database))
    return try await SQLiteDriver(configuration: config)

  case "postgres", "postgresql":
    // Parse postgres://user:password@host:port/database
    guard let url = URL(string: database),
      let host = url.host,
      let user = url.user,
      let password = url.password,
      let database = url.path.split(separator: "/").last
    else {
      throw OwiError.invalidDatabaseURL
    }

    let port = url.port ?? 5432
    let config = PostgresConfiguration(
      hostname: host,
      port: port,
      username: user,
      password: password,
      database: String(database),
      tls: .disable
    )
    return try await PostgresDriver(configuration: config)

  case "mysql":
    // Parse mysql://user:password@host:port/database
    guard let url = URL(string: database),
      let host = url.host,
      let user = url.user,
      let password = url.password,
      let database = url.path.split(separator: "/").last
    else {
      throw OwiError.invalidDatabaseURL
    }

    let port = url.port ?? 3306
    let config = MySQLConfiguration(
      hostname: host,
      port: port,
      username: user,
      password: password,
      database: String(database)
    )
    return try await MySQLDriver(configuration: config)

  default:
    throw OwiError.unsupportedDatabaseType(type)
  }
}

enum OwiError: Error, CustomStringConvertible {
  case invalidDatabaseURL
  case unsupportedDatabaseType(String)

  var description: String {
    switch self {
    case .invalidDatabaseURL:
      return "Invalid database URL"
    case .unsupportedDatabaseType(let type):
      return "Unsupported database type: \(type)"
    }
  }
}
