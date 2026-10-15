# E2E tests

These tests run the SDK against a real Bucketeer backend. They are left out of the unit suite (`make test-without-building`) and run with `make e2e-without-building`, which the `E2E tests` workflow (`.github/workflows/e2e.yml`) does on CI.

## Running them

Environment variables (passed to the test run through the `Bucketeer` scheme, see `project.yml`):

| Variable | Used by |
|---|---|
| `E2E_API_ENDPOINT` | Every E2E test |
| `E2E_API_KEY` | Every E2E test (client key) |
| `E2E_PUBLIC_API_KEY` | The streaming patch tests only: a key that can update flags through `PATCH /v1/feature` |

Backend setup the tests expect, for the `ios` tag:

- `feature-ios-e2e-string`: default `value-1`; a rule that serves `value-2` (reason `RULE`) when the user's `app_version` attribute is `0.0.1`.
- `feature-ios-e2e-sse-string`: a string flag that only the streaming patch tests write to. Each run writes a fresh value, and no test reads a previous value back, so it is never restored.

## Streaming tests

`E2EStreamingProxyTests` and `E2EStreamingDirectTests` cover the stream (`BKTConfig.Builder.with(enableStreaming:)`): flag updates pushed by the backend over Server-Sent Events.

### What they check

1. The stream opens after `initialize`.
2. When the initial fetch times out, the evaluations still arrive, over the stream.
3. After `updateUserAttributes`, the stream reconnects and the new attributes are evaluated over it (`value-2`, reason `RULE`, listener called).
4. A flag change made on the backend reaches the open stream.

### Why the tests need to see the network

With streaming on, a value can reach the app in two ways: over the stream, or through a REST `get_evaluations` fetch (the initial fetch, or the polling fallback that starts if the stream gives up). An app sees the same value either way. To prove the stream delivered it, a test has to count the `get_evaluations` requests: exactly one (the initial fetch) means nothing else fetched.

The SDK has no public way to observe its requests, and its network sessions are internal. Two things that look usable are not:

- **Metrics events**: the SDK drops a metrics event when one of the same kind is already stored, so two fetches can leave one event.
- **Log lines**: no line is logged when the stream opens, and tying tests to log text written for people is fragile.

### The proxy server

`RecordingProxy` is a small HTTP server that the test starts on `127.0.0.1`. The SDK is pointed at it through the public `apiEndpoint` setting. The proxy forwards every request to the real backend, passes each reply back as it arrives (the stream piece by piece), and records each request's path and reply status.

A stream counts as open only while its reply is 200, with no error, and has not ended. A stream the backend ended normally, or one the SDK closed to reconnect, no longer counts.

This keeps the client exactly as an app gets it: it is created by the public `BKTClient.initialize`, and nothing inside it is replaced. Only its address changes.

Approaches not used, and why:

- **Plugging a recorder into the SDK's internal network sessions**: the test would build the client itself and swap internal parts, so it would no longer test the client an app gets.
- **Patching `URLSessionConfiguration.default` for the whole test process**: global, so it affects every other test in the run.

The proxy has its own tests, `BucketeerTests/RecordingProxyTests.swift`. They run in the unit suite with a scripted fake backend (`MockURLProtocol`), so they need no keys. The E2E tests never use the fake backend.

### Two classes

| | `E2EStreamingProxyTests` | `E2EStreamingDirectTests` |
|---|---|---|
| Connects to | The proxy, which forwards to the backend | The backend directly |
| Checks | Values, plus the request count and the stream's reply | Only what an app can see: values, reasons, listener calls |
| Tests | 1, 2, 3, 4 | 3, 4 |
| Cannot see | The SDK's own connection to the real gateway: through the proxy the SDK talks plain HTTP to a local server, which forwards over its own connection, so TLS, HTTP/2 and the gateway's chunking are not exercised | Where a value came from. If the stream failed at once, the polling fallback would fetch and these tests could still pass; the proxy class catches that |

The two classes cover each other's blind spots. Tests 3 and 4 are copied between them on purpose, so each class reads on its own.

Tests 1 and 2 have no direct version: an app cannot see the stream open, and in test 2 it cannot tell whether the value came from the stream or from the late initial fetch.

### Known limits

- **The direct patch test can race the stream opening.** Without the proxy there is no way to wait until the stream is open, so a flag change written before that may not arrive, and the test fails with its own message. The proxy version waits for the stream's reply first.
- **The direct class can pass through the polling fallback** (see the table). The proxy class checks the same cases with the request count.
- **Through the proxy, replies have no `Content-Length`** (the proxy ends each reply by closing the connection), so the SDK's response-size metric is -1 in proxy runs.

### Timing

Each wait has its own timeout and failure message (`E2EStreamingTimeout`): 20s for the stream to open, 20s for a value, 10s for the test's own flag update. All stay under 60s on purpose. With streaming off, the E2E config polls every 60s, so a longer wait could let a poll deliver the value and hide a broken stream.

### Shared state

Every E2E test shares `UserDefaults.standard` and one SQLite file, so each class clears them in `setUp` and `tearDown`. The proxy class also starts a new proxy for each test and stops it after `BKTClient.destroy()`, so traffic from an old stream is never counted in the next test.

The E2E backend is also shared between CI runs, and the streaming tests write a shared flag. An update listener reads the current value only when it is called, so two runs at once can hide each other's values. The `E2E tests` job therefore runs in one concurrency group (`ios-e2e-backend`) for every branch and trigger: one run at a time, every other run waits its turn, and none is cancelled.
