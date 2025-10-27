# Owi - Simple Database Migrations for Swift

A clean and simple database migration tool for Swift, designed to work seamlessly with Vapor and other Swift web frameworks.

## Installation

### As a Library (for Vapor apps)

Add to your `Package.swift`:

```swift
    .package(url: "https://github.com/savioruz/owi.git", from: "0.0.1")
```

Then add to your target:

```swift
    .product(name: "Owi", package: "owi")
```

### @TODO As a CLI Tool

## Migration File Format

Migrations are written in SQL files with a specific format:

```sql
-- migrate:up
CREATE TABLE users (id SERIAL PRIMARY KEY);

-- migrate:down
DROP TABLE users;

-- migrate:up
ALTER TABLE users ADD COLUMN email VARCHAR(255);

-- migrate:down
ALTER TABLE users DROP COLUMN email;
```

### Rules

1. Each file can contain **single or multiple up/down pairs**
2. Sections are marked with `-- migrate:up` and `-- migrate:down`
3. Down sections are applied in **reverse order** during rollback
4. File names should follow the pattern: `{number}_{description}.sql`
   - Example: `001_create_users_table.sql`

## CLI Usage

### Create a New Migration

```bash
owi new create_users_table

# With custom directory
owi new create_users_table -m ./db/migrations
```

This creates a new migration file with an auto-incremented number:

```
migrations/
  001_create_users_table.sql
```

### Run Migrations

```bash
# SQLite
owi migrate -u ./db.sqlite -m ./migrations

# PostgreSQL
owi migrate -u "postgres://user:pass@localhost:5432/mydb" --type postgres -m ./migrations

# MySQL
owi migrate -u "mysql://user:pass@localhost:3306/mydb" --type mysql -m ./migrations
```

### Rollback Migrations

```bash
# Rollback last migration
owi rollback -u ./db.sqlite

# Rollback last 3 migrations
owi rollback -u ./db.sqlite --count 3
```

### Check Status

```bash
owi status -u ./db.sqlite -m ./migrations
```

Output:
```
Migration Status:
─────────────────────────────────────
✓ 001_create_users_table
✓ 002_add_email_to_users
✗ 003_create_posts_table
─────────────────────────────────────
Applied: 2, Pending: 1
```

### CLI Options

All commands support these options:

- `-u, --database-url <url>` - Database URL or path
- `-m, --migrations-dir <dir>` - Migrations directory (default: `./migrations`)
- `--type <type>` - Database type: `sqlite`, `postgres`, or `mysql` (default: `sqlite`)

## Library Usage (Vapor Integration)

### In Your Vapor App

```swift
import Vapor
import Owi
import PostgresKit

func configureMigrations(_ app: Application) async throws {
    // Create configuration using native PostgresKit types
    let config = PostgresConfiguration(
        hostname: "localhost",
        port: 5432,
        username: "postgres",
        password: "postgres",
        database: "myapp",
        tls: .disable
    )
    
    // Create Owi driver
    let driver = try await PostgresDriver(configuration: config)
    
    // Create runner
    let runner = Runner(
        driver: driver,
        migrationDir: "./Migrations"
    )
    
    // Run migrations
    try await runner.migrate()
    try await runner.close()
}
```

### In `configure.swift`

```swift
public func configure(_ app: Application) async throws {
    // ... your database configuration
    
    // Run migrations on startup (optional)
    try await configureMigrations(app)
    
    // ... rest of configuration
}
```

### Manual Control

```swift
import Owi
import SQLiteKit

// Create configuration using native SQLiteKit types
let config = SQLiteConfiguration(storage: .file(path: "./db.sqlite"))

// Create driver
let driver = try await SQLiteDriver(configuration: config)

// Create runner
let runner = Runner(driver: driver, migrationDir: "./Migrations")

// Run migrations
try await runner.migrate()

// Check status
try await runner.status()

// Rollback
try await runner.rollback(count: 1)

// Clean up
try await runner.close()
```

## Example Project Structure

```
MyVaporApp/
├── Package.swift
├── Sources/
│   └── App/
│       ├── configure.swift
│       └── ...
├── Migrations/
│   ├── 001_create_users_table.sql
│   ├── 002_create_posts_table.sql
│   └── 003_add_indexes.sql
└── ...
```

## Database Support

### SQLite

```swift
import SQLiteKit

let config = SQLiteConfiguration(storage: .file(path: "./database.sqlite"))
// Or for in-memory database:
// let config = SQLiteConfiguration(storage: .memory)

let driver = try await SQLiteDriver(configuration: config)
```

### PostgreSQL

```swift
import PostgresKit

let config = PostgresConfiguration(
    hostname: "localhost",
    port: 5432,
    username: "postgres",
    password: "postgres",
    database: "myapp",
    tls: .disable
)

let driver = try await PostgresDriver(configuration: config)
```

### MySQL

```swift
import MySQLKit

let config = MySQLConfiguration(
    hostname: "localhost",
    port: 3306,
    username: "root",
    password: "password",
    database: "myapp"
)

let driver = try await MySQLDriver(configuration: config)
```

**Note:** Owi uses the native configuration types from PostgresKit, MySQLKit, and SQLiteKit, so you can use all the configuration options provided by those libraries.

## API Reference

### `Runner`

Main migration runner.

```swift
public struct Runner {
    public init(
        driver: any DatabaseDriver,
        migrationDir: String,
        schemaTableName: String = "owi_schema"
    )
    
    public func migrate() async throws
    public func rollback(count: Int = 1) async throws
    public func status() async throws
    public func close() async throws
}
```

### `Parser`

Parses migration files.

```swift
public struct Parser {
    public func parse(fileURL: URL) throws -> Migration
    public func loadMigrations(from directoryURL: URL) throws -> [Migration]
}
```

### `Migration`

Represents a single migration.

```swift
public struct Migration {
    public let id: String
    public let upSQL: String
    public let downSQL: String
    public let filePath: String
    public var version: Int? // Extracted from ID (e.g., "001" -> 1)
}
```

### `SchemaVersion`

Represents the current schema version state in the database.

```swift
public struct SchemaVersion {
    public let id: Int          // Always 1
    public let version: Int     // Current migration version
    public let dirty: Bool      // Is a migration in progress?
    public let modifiedAt: Date // Last modification time
}
```

### Database Schema

The schema tracking table (`owi_schema` by default, customizable) stores **a single row**:

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER | Always 1 (enforced by CHECK constraint) |
| `version` | INTEGER | Current migration version (e.g., 0, 1, 2, 3) |
| `dirty` | BOOLEAN/INTEGER | Migration in progress flag |
| `modified_at` | TIMESTAMP/TEXT | Last modification timestamp |

Example table content:
```
id | version | dirty | modified_at
1  | 3       | 0     | 2025-10-26 20:08:53
```

**Benefits of single-row design:**
- Minimal storage footprint (always 1 row regardless of migration count)
- Fast queries (no table scans)
- Dirty flag protection (prevents running migrations during incomplete state)
- Simple and efficient

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

[MIT License](LICENSE) - feel free to use in your projects!

## Inspiration

Inspired by tools like [dbmate](https://github.com/amacneil/dbmate.git), but designed specifically for Swift and Vapor.
