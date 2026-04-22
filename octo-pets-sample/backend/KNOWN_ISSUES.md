# Known Issues and Error Patterns

## ~~5xx Errors in Production~~ — RESOLVED (2026-04-22)

### Issue: Null Reference Exception in Listing Details Endpoint — FIXED
**Status**: **RESOLVED** — Error injection code permanently removed in [PR #7](https://github.com/kishoreismac/sre-master-demo-repo/pull/7)
**Location**: `backend/Endpoints/ListingEndpoints.cs`
**Error Type**: NullReferenceException (HTTP 500)
**Endpoint**: `GET /api/listings/{id}`

### What Was the Problem?
The endpoint contained intentional error injection code gated by an `ERRORS` environment variable. When `ERRORS=true`, the code threw a `NullReferenceException` on every request:

```csharp
// REMOVED in PR #7 — this code no longer exists
string nullString = null;
var length = nullString.Length; // Caused NullReferenceException -> HTTP 500
```

An `AReallyExpensiveOperation()` method (~1GB memory allocation simulation) was also present and has been removed.

### Incident History (2026-04-22)
This code caused **4 separate Sev3 alerts** in ~2 hours:

| # | Time (UTC) | Alert | Impact |
|---|------------|-------|--------|
| 1 | 10:25 | avgresponse on octopetsapi | 73.7% request failure rate |
| 2 | 11:38 | avgresponse on octopetsapi | Residual traffic to old revision |
| 3 | 11:38 | avgresponse on octopetsapi | Same residual traffic pattern |
| 4 | 11:50 | avgresponse on octopetsapi | ERRORS=true re-enabled; permanently fixed |

### Resolution
- **PR #7** merged (commit `c0c4909`) — permanently removed all error injection code
- The `ERRORS` environment variable no longer has any effect on the application
- The `ERRORS` env var can be safely removed from the container app configuration

### Lessons Learned
1. Never deploy intentional error injection code to production — use feature flags in a testing environment only
2. Add CI/CD guardrails to detect and reject error injection patterns before deployment
3. Monitor for sudden HTTP 500 rate increases, not just average response time
4. When setting env vars to `false` as mitigation, also pursue a permanent code fix immediately

## CRUD Operations Guard

### Feature: CRUD Disable Flag
**Location**: `backend/Endpoints/ListingEndpoints.cs`
**Endpoints**: POST, PUT, DELETE on `/api/listings`
**Trigger**: `ENABLE_CRUD` configuration flag set to `false`
**Behavior**: Returns `InvalidOperationException` with message "CRUD operations are currently disabled"

This is an intentional feature flag, not a bug. POST, PUT, and DELETE endpoints check `ENABLE_CRUD` (defaults to `true`) before performing write operations.
