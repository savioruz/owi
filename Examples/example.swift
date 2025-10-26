import Foundation
import Owi

// Example of using Owi in your Swift application

@main
struct ExampleApp {
    static func main() async throws {
        // Configure database (using SQLite for this example)
        let config = SQLiteConfiguration(storage: .file(path: "./example.db"))
        let driver = try await SQLiteDriver(configuration: config)
        
        // Create runner
        let runner = Runner(
            driver: driver,
            migrationDir: "./Examples/migrations"
        )
        
        // Run migrations
        try await runner.migrate()
        
        // Show status
        try await runner.status()
        
        // Clean up
        try await runner.close()
    }
}
