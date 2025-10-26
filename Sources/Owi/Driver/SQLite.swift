import Foundation
import Logging
import NIOCore
@preconcurrency import SQLiteKit
@preconcurrency import SQLiteNIO

public typealias SQLiteConfiguration = SQLiteKit.SQLiteConfiguration

public final class SQLiteDriver: DatabaseDriver, @unchecked Sendable {
  private let connection: SQLiteConnection
  private let eventLoopGroup: EventLoopGroup
  private let threadPool: NIOThreadPool

  public init(configuration: SQLiteConfiguration) async throws {
    self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    self.threadPool = NIOThreadPool(numberOfThreads: 1)
    threadPool.start()

    let connectionStorage: SQLiteConnection.Storage
    switch configuration.storage {
    case .memory:
      connectionStorage = .memory
    case .file(let path):
      connectionStorage = .file(path: path)
    }

    self.connection = try await SQLiteConnection.open(
      storage: connectionStorage,
      threadPool: threadPool,
      logger: Logger(label: "owi.sqlite"),
      on: eventLoopGroup.next()
    ).get()
  }

  public func execute(_ sql: String) async throws {
    try await connection.sql().raw(SQLQueryString(sql)).run().get()
  }

  public func getSchemaVersion(from table: String) async throws -> SchemaVersion? {
    let rows = try await connection.sql().raw(
      """
      SELECT id, version, dirty, modified_at FROM \(ident: table) WHERE id = 1
      """
    ).all().get()

    guard let row = rows.first else {
      return nil
    }

    guard let id: Int = try? row.decode(column: "id"),
      let version: Int = try? row.decode(column: "version"),
      let dirty: Int = try? row.decode(column: "dirty"),
      let modifiedAtString: String = try? row.decode(column: "modified_at")
    else {
      throw MigrationError.databaseError("Invalid schema version format")
    }

    let formatter = ISO8601DateFormatter()
    guard let modifiedAt = formatter.date(from: modifiedAtString) else {
      throw MigrationError.databaseError("Invalid date format")
    }

    return SchemaVersion(id: id, version: version, dirty: dirty != 0, modifiedAt: modifiedAt)
  }

  public func updateSchemaVersion(_ version: Int, dirty: Bool, in table: String) async throws {
    let now = ISO8601DateFormatter().string(from: Date())
    let dirtyInt = dirty ? 1 : 0

    // Try to update first
    try await connection.sql().raw(
      """
      INSERT OR REPLACE INTO \(ident: table) (id, version, dirty, modified_at) 
      VALUES (1, \(bind: version), \(bind: dirtyInt), \(bind: now))
      """
    ).run().get()
  }

  public func createSchemaTable(named table: String) async throws {
    try await connection.sql().raw(
      """
      CREATE TABLE IF NOT EXISTS \(ident: table) (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          version INTEGER NOT NULL DEFAULT 0,
          dirty INTEGER NOT NULL DEFAULT 0,
          modified_at TEXT NOT NULL
      )
      """
    ).run().get()
  }

  public func close() async throws {
    try await connection.close().get()
    try await threadPool.shutdownGracefully()
    try await eventLoopGroup.shutdownGracefully()
  }
}
