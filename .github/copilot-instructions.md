# OVERVIEW.md

This file provides guidance AI coding tools when working with code in this repository.

## Project Overview

Bucketeer iOS SDK is a client-side SDK for iOS and tvOS that provides feature flag management with advanced capabilities like staged rollouts, user segmentation, and event tracking. The SDK is designed for mobile environments with intelligent caching, batch event processing, and adaptive retry logic.

**Platforms**: iOS 12.0+, tvOS 12.0+
**Language**: Swift 5.3+
**Xcode**: 13.1+
**Project Generation**: XcodeGen (project.yml)
**Library Management**: Mint

## Essential Commands

### Project Setup

```bash
# Install Mint (requires Homebrew)
make install-mint

# Install dependencies
make bootstrap-mint

# Setup environment config (API_ENDPOINT and API_KEY for E2E tests and Example app)
make environment-setup

# Generate Xcode project file (required after updating project.yml)
make generate-project-file
```

### Build & Test

```bash
# Build the SDK
make build

# Build example app
make build-example

# Build for testing with E2E credentials
make build-for-testing E2E_API_ENDPOINT=<YOUR_API_ENDPOINT> E2E_API_KEY=<YOUR_API_KEY>

# Run unit tests only (excludes E2E tests)
make test-without-building

# Run E2E tests only
make e2e-without-building

# Run all tests including E2E
make all-test-without-building

# Run linter
make run-lint

# Clean build artifacts
make clean
```

### Testing Individual Components

To run specific test classes or methods, use xcodebuild directly:

```bash
# Run a specific test class
xcodebuild test -project Bucketeer.xcodeproj -scheme Bucketeer \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:BucketeerTests/BucketeerTests

# Run a specific test method
xcodebuild test -project Bucketeer.xcodeproj -scheme Bucketeer \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:BucketeerTests/BucketeerTests/testMethodName
```

## Code Architecture

### High-Level Structure

The SDK uses a layered architecture with dependency injection:

```
BKTClient (Public API/Facade)
    ↓
Component (DI Container)
    ↓
├── EvaluationInteractor ← Manages feature flag lifecycle
├── EventInteractor ← Tracks events (evaluation, goal, metrics)
├── TaskScheduler ← Foreground/background task coordination
    ↓
├── Storage Layer
│   ├── EvaluationStorage (3-tier: Memory → SQLite → UserDefaults)
│   └── EventSQLDao (SQLite event queue)
└── ApiClient ← Remote API communication with retry logic
```

### Key Components

**BKTClient** (`Bucketeer/Sources/Public/BKTClient.swift`)
- Singleton entry point initialized with `BKTConfig` and `BKTUser`
- Variation API: `boolVariation()`, `intVariation()`, `doubleVariation()`, `stringVariation()`, `objectVariation()`
- User management: `updateUserAttributes()`, `currentUser()`
- Event tracking: `track(goalId:value:)`
- Lifecycle: `fetchEvaluations()`, `flush()`, `addEvaluationUpdateListener()`

**EvaluationInteractor** (`Bucketeer/Sources/Internal/Evaluation/`)
- Fetches evaluations from remote API
- Manages 3-tier caching: Memory cache (fast) → SQLite (persistent) → UserDefaults (metadata)
- Tracks evaluation state changes (evaluatedAt, userAttributesUpdated)
- Notifies listeners on updates

**EventInteractor** (`Bucketeer/Sources/Internal/Event/`)
- Tracks three event types:
  - Evaluation events: when a variation is used
  - Goal events: user conversions
  - Metrics events: API latency, errors, response sizes
- Batches events in SQLite queue
- Flushes based on threshold (queue size) or time interval
- Deduplicates metrics events by unique key

**TaskScheduler** (`Bucketeer/Sources/Internal/Scheduler/`)
- **Foreground tasks** (always active when app is visible):
  - `EvaluationForegroundTask`: Polls evaluations at configured interval with retry logic
  - `EventForegroundTask`: Flushes events periodically or on threshold
- **Background tasks** (iOS 13.0+ only):
  - `EvaluationBackgroundTask`: Periodic updates in background
  - `EventBackgroundTask`: Deferred event flushing

**ApiClient** (`Bucketeer/Sources/Internal/Remote/`)
- Two main endpoints: `getEvaluations()`, `registerEvents()`
- Automatic retry with exponential backoff (1s, 2s, 4s) for HTTP 499
- Tracks request latency and response size
- Configurable timeout (default: 30s)

**SQLite Layer** (`Bucketeer/Sources/Internal/Database/SQLite/`)
- Custom ORM-like abstraction with type-safe columns
- Two tables: `evaluations`, `events`
- Database version 2 with migration support
- Storage location: Library dir (iOS), Cache dir (tvOS)

### Concurrency Model

- **SDK Queue**: Serial dispatch queue for all operations except specific read paths
  - API calls, database writes, event tracking, evaluation fetches
  - Prevents race conditions
- **Main Thread**: Listener callbacks dispatched here
- **UI Thread Safe Reads**: `getBy(featureId)` reads from memory cache without locks
- **Memory Cache**: Uses internal concurrent queue for thread safety
- **Semaphore-based Sync**: API client blocks SDK queue until response arrives
- **User Attribute Updates**: Protected by `NSLock` with version counter

### Data Flow

**Evaluation Request Flow:**
1. User calls `boolVariation(featureId, defaultValue)`
2. Check memory cache first (fast path)
3. If found: Return cached evaluation + track evaluation event
4. If not found: Return default value + track default event
5. Event queued in SQLite by EventInteractor
6. Poller triggers send when threshold/interval reached
7. API batches events, server responds with status per event
8. SDK deletes successfully sent events

**Evaluation Refresh Flow:**
1. `EvaluationForegroundTask` calls `fetch()` at polling interval
2. ApiClient sends `getEvaluations` with current evaluation ID, user attributes state
3. Server responds with new evaluations, archived feature IDs, force update flag
4. Storage updates: full replace if `forceUpdate=true`, merge+delete archived otherwise
5. Notifies evaluation listeners on main thread
6. Tracks metrics event with response latency/size

## Development Patterns

### Testing

- Unit tests use Mock objects (see `BucketeerTests/Mock/`)
- E2E tests require `E2E_API_ENDPOINT` and `E2E_API_KEY` environment variables
- Tests are separated: unit tests skip E2E tests by default
- Mock implementations: `MockApiClient`, `MockClock`, `MockIdGenerator`, `MockDevice`, etc.

### Commit Messages

Follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>[(optional scope)]: <description>

[optional body]

[optional footer(s)]
```

**Types**: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`

Examples:
- `feat(event): implement event flush worker`
- `fix(evaluation): handle race condition in cache update`
- `test: add E2E tests for forced evaluation updates`

### XcodeGen Project Management

The Xcode project file is generated from `project.yml`. When modifying project structure:

1. Edit `project.yml` (targets, settings, dependencies)
2. Run `make generate-project-file`
3. Never manually edit `Bucketeer.xcodeproj` as changes will be overwritten

### Code Locations

- Public API: `Bucketeer/Sources/Public/`
- Internal implementation: `Bucketeer/Sources/Internal/`
- Tests: `BucketeerTests/`
- Example apps: `Example/`, `ExampleSwiftUI/`, `ExampleTVOS/`
- Project config: `project.yml`, `Makefile`
- Build scripts: `hack/` directory

### Important Configuration

Key defaults in `Constant.swift`:
- `DEFAULT_FLUSH_INTERVAL_MILLIS`: ~60 seconds
- `DEFAULT_MAX_QUEUE_SIZE`: 100 events before flush
- `DEFAULT_POLLING_INTERVAL_MILLIS`: ~5 minutes
- `MINIMUM_POLLING_INTERVAL_MILLIS`: 1 minute floor
- `RETRY_POLLING_INTERVAL`: Fast retry during failures

### Dependency Injection

The SDK uses `Component` protocol for DI:
- `ComponentImpl` assembles all dependencies
- `DataModule` provides shared resources (config, storage, API client, etc.)
- All dependencies injected through protocol interfaces for testability

### Thread Safety Considerations

When modifying code:
- Database operations must run on SDK queue
- Memory cache reads can be lock-free (accepts momentary staleness)
- Listener notifications must dispatch to main thread
- User attribute updates need lock protection
- Use semaphores for blocking operations on SDK queue
