import Foundation
import Logging
@preconcurrency import MySQLKit
@preconcurrency import MySQLNIO
import NIOCore

public typealias MySQLConfiguration = MySQLKit.MySQLConfiguration

public final class MySQLDriver: DatabaseDriver, @unchecked Sendable {
  private let pool: EventLoopGroupConnectionPool<MySQLConnectionSource>
  private let eventLoopGroup: EventLoopGroup
  private let db: any MySQLDatabase

  public init(configuration: MySQLConfiguration) async throws {
    self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    let source = MySQLConnectionSource(
      configuration: configuration
    )

    self.pool = EventLoopGroupConnectionPool(
      source: source,
      on: eventLoopGroup
    )

    self.db = pool.database(logger: Logger(label: "owi.mysql"))
  }

  public func execute(_ sql: String) async throws {
    try await db.sql().raw(SQLQueryString(sql)).run().get()
  }

  public func getSchemaVersion(from table: String) async throws -> SchemaVersion? {
    let rows = try await db.sql().raw(
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
      let modifiedAt: Date = try? row.decode(column: "modified_at")
    else {
      throw MigrationError.databaseError("Invalid schema version format")
    }

    return SchemaVersion(id: id, version: version, dirty: dirty != 0, modifiedAt: modifiedAt)
  }

  public func updateSchemaVersion(_ version: Int, dirty: Bool, in table: String) async throws {
    let dirtyInt = dirty ? 1 : 0

    // Try to update first, insert if not exists
    try await db.sql().raw(
      """
      INSERT INTO \(ident: table) (id, version, dirty, modified_at) 
      VALUES (1, \(bind: version), \(bind: dirtyInt), NOW())
      ON DUPLICATE KEY UPDATE 
          version = VALUES(version),
          dirty = VALUES(dirty),
          modified_at = NOW()
      """
    ).run().get()
  }

  public func createSchemaTable(named table: String) async throws {
    try await db.sql().raw(
      """
      CREATE TABLE IF NOT EXISTS \(ident: table) (
          id INT PRIMARY KEY CHECK (id = 1),
          version INT NOT NULL DEFAULT 0,
          dirty TINYINT(1) NOT NULL DEFAULT 0,
          modified_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
      """
    ).run().get()
  }

  public func close() async throws {
    try await eventLoopGroup.shutdownGracefully()
  }
}
