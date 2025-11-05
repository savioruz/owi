# Owi - Simple Database Migrations for Swift

![GitHub Release](https://img.shields.io/github/v/release/savioruz/owi)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/savioruz/owi/ci.yml)
![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/savioruz/owi/total)


A clean and simple database migration tool for Swift, designed to work seamlessly with Vapor and other Swift web frameworks.
See [Changelogs](CHANGELOG.md)

# Table of Contents

1. [Overview](#overview)
   - [Introduction](#overview)
   - [Features](#overview)

2. [Installation](#installation)
   - [As a Library (for Vapor apps)](#as-a-library-for-vapor-apps)
   - [As a CLI Tool](#as-a-cli-tool)
     - [Quick Install](#quick-install)
     - [Homebrew Installation](#homebrew)
     - [Manual Installation](#manual-installation)

3. [Migration File Format](#migration-file-format)
   - [Example](#migration-file-format)
   - [Rules](#rules)

4. [CLI Usage](#cli-usage)
   - [Create a New Migration](#create-a-new-migration)
   - [Run Migrations](#run-migrations)
   - [Rollback Migrations](#rollback-migrations)
   - [Check Status](#check-status)
   - [CLI Options](#cli-options)

5. [Library Usage (Vapor Integration)](#library-usage-vapor-integration)
   - [Using Vapor’s Database Connection](#using-vapors-database-connection-recommended)
   - [Integration in `configure.swift`](#in-configureswift)
   - [Standalone Usage (Without Vapor)](#standalone-usage-without-vapor)
   - [Key Differences](#key-difference)

6. [API Reference](#api-reference)
   - [`Runner`](#runner)
   - [`Parser`](#parser)
   - [`Migration`](#migration)
   - [`SchemaVersion`](#schemaversion)

7. [Database Schema](#database-schema)
   - [Schema Tracking Table (`owi_schema`)](#database-schema)
   - [Example Table Content](#database-schema)

8. [Contributing](#contributing)

9. [License](#license)

10. [Inspiration](#inspiration)


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

### As a CLI Tool

#### Quick Install

Using the install script:

```bash
curl -fsSL https://raw.githubusercontent.com/savioruz/owi/main/install.sh | sh
```

Or download and run:

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/savioruz/owi/main/install.sh
chmod +x install.sh
./install.sh
```

#### Homebrew

```bash
brew tap savioruz/homebrew-tap
brew install owi
```

#### Manual Installation

Download the latest release from [GitHub Releases](https://github.com/savioruz/owi/releases):

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

### Using Vapor's Database Connection (Recommended)

When integrating with Vapor, pass your existing database connection to avoid connection pool issues:

```swift
import Vapor
import Owi

func configureMigrations(_ app: Application) async throws {
    // Use Vapor's existing database connection - no pool management needed!
    let driver = PostgresDriver(database: app.db(.psql))
    
    // Create runner
    let runner = Runner(
        driver: driver,
        migrationDir: "./Migrations"
    )
    
    // Run migrations
    try await runner.migrate()
    
    // No need to call close() - Vapor manages the connection!
}
```

**For MySQL:**
```swift
let driver = MySQLDriver(database: app.db(.mysql))
```

**For SQLite:**
```swift
let driver = SQLiteDriver(database: app.db(.sqlite))
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

### Standalone Usage (Without Vapor)

If you're building a CLI tool or not using Vapor, create your own connection:

```swift
import Owi
import PostgresKit

// Create configuration using native PostgresKit types
let config = PostgresConfiguration(
    hostname: "localhost",
    port: 5432,
    username: "postgres",
    password: "postgres",
    database: "myapp",
    tls: .disable
)

// Create driver (manages its own connection pool)
let driver = try await PostgresDriver(configuration: config)

// Create runner
let runner = Runner(driver: driver, migrationDir: "./Migrations")

// Run migrations
try await runner.migrate()

// Check status
try await runner.status()

// Rollback
try await runner.rollback(count: 1)

// IMPORTANT: Close the connection when done!
try await runner.close()
```

**Key Difference:**
- **With Vapor database**: `PostgresDriver(database: app.db(.psql))` - NO `close()` needed
- **With configuration**: `PostgresDriver(configuration: config)` - MUST call `close()`

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

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

[MIT License](LICENSE) - feel free to use in your projects!

## Inspiration

Inspired by tools like [dbmate](https://github.com/amacneil/dbmate.git), but designed specifically for Swift and Vapor.
