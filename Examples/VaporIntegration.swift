import Vapor
import Owi

// In your configure.swift file, add this function:
func runMigrations(_ app: Application) async throws {
    // Use Vapor's existing database connection (recommended)
    let driver = SQLiteDriver(database: app.db(.sqlite))
    
    // Create migration runner
    let runner = Runner(
        driver: driver,
        migrationDir: "./Migrations"
    )
    
    // Log migration status
    app.logger.info("Running database migrations...")
    
    // Run migrations
    try await runner.migrate()
    
    // Show status in logs
    try await runner.status()
    app.logger.info("Migration complete!")
    
    // No close() needed - Vapor manages the connection!
}

// Then in your configure function:
public func configure(_ app: Application) async throws {
    // ... your other configuration ...
    
    // Run migrations on startup
    try await runMigrations(app)
    
    // ... rest of configuration ...
}

// -------------------------------------------
// Example with PostgreSQL for production
// -------------------------------------------

func runPostgresMigrations(_ app: Application) async throws {
    let driver = PostgresDriver(database: app.db(.psql))
    let runner = Runner(driver: driver, migrationDir: "./Migrations")
    
    app.logger.info("Running database migrations...")
    try await runner.migrate()
    app.logger.info("Migration complete!")
    
    // No close() needed!
}

// -------------------------------------------
// Alternative Standalone connection
// -------------------------------------------

func runStandaloneMigrations(_ app: Application) async throws {
    // Only use this if NOT using Vapor's database
    let config = PostgresConfiguration(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Int(Environment.get("DATABASE_PORT") ?? "5432") ?? 5432,
        username: Environment.get("DATABASE_USERNAME") ?? "postgres",
        password: Environment.get("DATABASE_PASSWORD") ?? "",
        database: Environment.get("DATABASE_NAME") ?? "vapor_db",
        tls: .disable
    )
    
    let driver = try await PostgresDriver(configuration: config)
    let runner = Runner(driver: driver, migrationDir: "./Migrations")
    
    app.logger.info("Running database migrations...")
    try await runner.migrate()
    app.logger.info("Migration complete!")
    
    // IMPORTANT: Must close when using configuration-based init!
    try await runner.close()
}

// -------------------------------------------
// Example route for manual migrations
// -------------------------------------------

func routes(_ app: Application) throws {
    // Add a protected endpoint to run migrations manually
    app.get("admin", "migrate") { req async throws -> String in
        // TODO: Add authentication here!
        
        // Use Vapor's existing database connection
        let driver = SQLiteDriver(database: app.db(.sqlite))
        let runner = Runner(driver: driver, migrationDir: "./Migrations")
        
        try await runner.migrate()
        // No close() needed!
        
        return "Migrations completed successfully!"
    }
    
    // Check migration status
    app.get("admin", "migrate", "status") { req async throws -> [String: Any] in
        // TODO: Add authentication here!
        
        // Use Vapor's existing database connection
        let driver = SQLiteDriver(database: app.db(.sqlite))
        let tracker = Tracker(driver: driver, tableName: "owi_schema")
        
        try await tracker.setup()
        let currentVersion = try await tracker.getVersion()
        let isDirty = try await tracker.isDirty()
        // No close() needed!
        
        return [
            "current_version": currentVersion,
            "dirty": isDirty
        ]
    }
}

// -------------------------------------------
// Complete example for MySQL
// -------------------------------------------

func runMySQLMigrations(_ app: Application) async throws {
    // Use Vapor's existing MySQL connection
    let driver = MySQLDriver(database: app.db(.mysql))
    let runner = Runner(driver: driver, migrationDir: "./Migrations")
    
    app.logger.info("Running MySQL migrations...")
    try await runner.migrate()
    app.logger.info("Migration complete!")
}
