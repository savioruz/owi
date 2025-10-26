import Vapor
import Owi

// Example of integrating Owi with Vapor

// In your configure.swift file, add this function:
func runMigrations(_ app: Application) async throws {
    // Get database configuration from environment
    let dbPath = Environment.get("DATABASE_PATH") ?? "./vapor.db"
    
    // Create Owi driver using SQLiteKit configuration
    let config = SQLiteConfiguration(storage: .file(path: dbPath))
    let driver = try await SQLiteDriver(configuration: config)
    
    // Create migration runner
    let runner = Runner(
        driver: driver,
        migrationDir: "./migrations"
    )
    
    // Log migration status
    app.logger.info("Running database migrations...")
    
    // Run migrations
    try await runner.migrate()
    
    // Show status in logs
    try await runner.status()
    app.logger.info("Migration complete!")
    
    // Clean up
    try await runner.close()
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
    let config = PostgresConfiguration(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Int(Environment.get("DATABASE_PORT") ?? "5432") ?? 5432,
        username: Environment.get("DATABASE_USERNAME") ?? "postgres",
        password: Environment.get("DATABASE_PASSWORD") ?? "",,
        database: Environment.get("DATABASE_NAME") ?? "vapor_db",
        tls: .disable  // from .env or .prefer/.require with TLS config
    )
    
    let driver = try await PostgresDriver(configuration: config)
    let runner = Runner(driver: driver, migrationDir: "./migrations")
    
    app.logger.info("Running database migrations...")
    try await runner.migrate()
    app.logger.info("Migration complete!")
    
    try await runner.close()
}

// -------------------------------------------
// Example route for manual migrations
// -------------------------------------------

func routes(_ app: Application) throws {
    // Add a protected endpoint to run migrations manually
    app.get("admin", "migrate") { req async throws -> String in
        // Add authentication here!
        
        let config = SQLiteConfiguration(storage: .file(path: "./vapor.db"))
        let driver = try await SQLiteDriver(configuration: config)
        let runner = Runner(driver: driver, migrationDir: "./migrations")
        
        try await runner.migrate()
        try await runner.close()
        
        return "Migrations completed successfully!"
    }
    
    // Check migration status
    app.get("admin", "migrate", "status") { req async throws -> [String: Any] in
        // Add authentication here!
        
        let config = SQLiteConfiguration(storage: .file(path: "./vapor.db"))
        let driver = try await SQLiteDriver(configuration: config)
        let tracker = Tracker(driver: driver)
        
        try await tracker.setup()
        let applied = try await tracker.getAppliedMigrations()
        try await driver.close()
        
        return [
            "total": applied.count,
            "migrations": applied.map { ["id": $0.id, "applied_at": $0.appliedAt] }
        ]
    }
}
