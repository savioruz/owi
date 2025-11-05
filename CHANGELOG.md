# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Update CI workflow to use Makefile commands
- Improve code formatting across the project
- Improve migration logging and remove redundant messages

## [0.0.4] - 2025-10-27

### Added
- macOS Intel (x86_64) support in release builds
- Universal binary support for macOS (ARM64 + x86_64)

### Changed
- Enhanced release workflow to build separate architectures
- Improved GitHub Actions release process

## [0.0.3] - 2025-10-27

### Added
- Vapor integration support with dedicated initializers
- Database drivers now support both standalone and Vapor integration modes
- Example Vapor integration code (`Examples/VaporIntegration.swift`)
- Install script for automated installation (`install.sh`)
- Badges for release, workflow status, and downloads in README

### Changed
- Database drivers (PostgreSQL, MySQL, SQLite) now have dual initializers:
  - `init(configuration:)` - For standalone/CLI usage (manages own connection pool)
  - `init(database:)` - For Vapor integration (reuses existing connection)
- Updated documentation to reflect Vapor integration patterns
- Improved connection lifecycle management

### Fixed
- Connection pool shutdown issues when integrating with Vapor

## [0.0.2] - 2025-10-18

### Added
- Xcode scheme and test plan configurations
- Comprehensive CI workflows with test execution
- Linux architecture split in release builds (x86_64 and aarch64)

### Changed
- Removed dependency installation step for Linux tests
- Enhanced CI workflows with better test coverage
- Split release workflow for better parallel builds

### Fixed
- Test execution in CI pipeline

## [0.0.1] - 2025-10-18

### Added
- Initial release of Owi migration tool
- Support for PostgreSQL, MySQL, and SQLite databases
- CLI tool with commands:
  - `new` - Create new migration files
  - `migrate` - Run pending migrations
  - `rollback` - Rollback migrations
  - `status` - Show migration status
- Library support for integration with Vapor and other Swift frameworks
- Migration file format with `-- migrate:up` and `-- migrate:down` markers
- Support for multiple up/down pairs in a single migration file
- Single-row schema tracking with dirty flag protection
- Native configuration support (PostgresConfiguration, MySQLConfiguration, SQLiteConfiguration)
- Comprehensive test suite using Swift Testing framework
- GitHub Actions CI/CD for macOS and Linux
- Homebrew tap support for easy installation
- Makefile for build automation

### Documentation
- Complete README with installation instructions
- API documentation
- Vapor integration guide
- Homebrew tap setup guide
- Release checklist

[Unreleased]: https://github.com/savioruz/owi/compare/v0.0.4...HEAD
[0.0.4]: https://github.com/savioruz/owi/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/savioruz/owi/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/savioruz/owi/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/savioruz/owi/releases/tag/v0.0.1
