import Foundation
import Logging
import NIOCore
@preconcurrency import PostgresKit
@preconcurrency import PostgresNIO

public typealias PostgresConfiguration = SQLPostgresConfiguration

public final class PostgresDriver: DatabaseDriver, @unchecked Sendable {
  private let pool: EventLoopGroupConnectionPool<PostgresConnectionSource>
  private let eventLoopGroup: EventLoopGroup
  private let db: any PostgresDatabase

  public init(configuration: PostgresConfiguration) async throws {
    self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    let source = PostgresConnectionSource(
      sqlConfiguration: configuration
    )

    self.pool = EventLoopGroupConnectionPool(
      source: source,
      on: eventLoopGroup
    )

    self.db = pool.database(logger: Logger(label: "owi.postgres"))
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
      let dirty: Bool = try? row.decode(column: "dirty"),
      let modifiedAt: Date = try? row.decode(column: "modified_at")
    else {
      throw MigrationError.databaseError("Invalid schema version format")
    }

    return SchemaVersion(id: id, version: version, dirty: dirty, modifiedAt: modifiedAt)
  }

  public func updateSchemaVersion(_ version: Int, dirty: Bool, in table: String) async throws {
    // Try to update first, insert if not exists
    try await db.sql().raw(
      """
      INSERT INTO \(ident: table) (id, version, dirty, modified_at) 
      VALUES (1, \(bind: version), \(bind: dirty), NOW())
      ON CONFLICT (id) DO UPDATE SET 
          version = EXCLUDED.version,
          dirty = EXCLUDED.dirty,
          modified_at = NOW()
      """
    ).run().get()
  }

  public func createSchemaTable(named table: String) async throws {
    try await db.sql().raw(
      """
      CREATE TABLE IF NOT EXISTS \(ident: table) (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          version INTEGER NOT NULL DEFAULT 0,
          dirty BOOLEAN NOT NULL DEFAULT FALSE,
          modified_at TIMESTAMP NOT NULL DEFAULT NOW()
      )
      """
    ).run().get()
  }

  public func close() async throws {
    try await eventLoopGroup.shutdownGracefully()
  }
}
