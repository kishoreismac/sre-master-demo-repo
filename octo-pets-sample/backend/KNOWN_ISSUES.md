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
This code caused **9+ separate Sev3 alerts** across ~4 hours before and after permanent removal:

| # | Time (UTC) | Alert | Impact |
|---|------------|-------|--------|
| 1 | 10:25 | avgresponse on octopetsapi | 73.7% request failure rate |
| 2 | 11:38 | avgresponse on octopetsapi | Residual traffic to old revision |
| 3 | 11:38 | avgresponse on octopetsapi | Same residual traffic pattern |
| 4 | 11:50 | avgresponse on octopetsapi | ERRORS=true re-enabled; permanently fixed |
| 5 | 11:56 | avgresponse on octopetsapi | 18,297% deviation; scale-up triggered (Issue [#9](https://github.com/kishoreismac/sre-master-demo-repo/issues/9)) |
| 6 | ~12:05 | avgresponse on octopetsapi | Post-fix stale telemetry in evaluation window |
| 7 | 12:51 | avgresponse on octopetsapi | Cold-start latency + sparse traffic (Issue [#11](https://github.com/kishoreismac/sre-master-demo-repo/issues/11)) |
| 8 | ~13:11 | avgresponse on octopetsapi | Statistical noise at sub-ms response times |
| 9+ | 13:27 | avgresponse on octopetsapi | 236.88% deviation at sub-2ms; noise (Issue [#12](https://github.com/kishoreismac/sre-master-demo-repo/issues/12)) |

### Resolution
- **PR #7** merged (commit `c0c4909`) — permanently removed all error injection code
- The `ERRORS` environment variable no longer has any effect on the application
- The `ERRORS` env var can be safely removed from the container app configuration

### Lessons Learned
1. Never deploy intentional error injection code to production — use feature flags in a testing environment only
2. Add CI/CD guardrails to detect and reject error injection patterns before deployment
3. Monitor for sudden HTTP 500 rate increases, not just average response time
4. When setting env vars to `false` as mitigation, also pursue a permanent code fix immediately

### Alert Configuration Recommendations

The `avgresponse` alert rule fired 9+ times in a single day. To prevent alert storms:

1. **Add minimum request count threshold** — Don't evaluate average response time when fewer than 10 requests exist in the evaluation window. Sparse traffic causes high variance.
2. **Add alert cooldown/suppression** — After an alert fires and is mitigated, suppress re-firing for at least 30 minutes.
3. **Use absolute thresholds for sub-ms baselines** — A 5% deviation threshold is meaningless when baseline is 0.3ms (triggers at 0.315ms). Use an absolute threshold of ≥100ms.
4. **Add HTTP 500 error rate alert** — Average response time is a lagging indicator. A dedicated error rate alert catches issues faster.
5. **Increase evaluation window** — Consider 10-minute instead of 2-minute windows to smooth out variance.

### Scale-Up Impact (2026-04-22)

Automated scale-ups were applied to `octopetsfe` due to alert-triggered policies:

| Time (UTC) | Before | After | Trigger |
|------------|--------|-------|---------|
| 11:59 | 0.5 vCPU / 1Gi | 1.0 vCPU / 2Gi | Alert [#5](https://github.com/kishoreismac/sre-master-demo-repo/issues/5) (18,297% deviation) |
| 12:54 | 1.0 vCPU / 2Gi | 2.0 vCPU / 4Gi | Alert [#7](https://github.com/kishoreismac/sre-master-demo-repo/issues/7) (2,275% deviation) |
| 13:31 | 2.0 vCPU / 4Gi | 4.0 vCPU / 8Gi | Alert [#9+](https://github.com/kishoreismac/sre-master-demo-repo/issues/12) (236% deviation) |

**Note:** octopetsfe is currently significantly oversized at 4.0 vCPU / 8Gi for actual traffic levels (~9 requests/30min). Scale back down after confirming stability.

## CRUD Operations Guard

### Feature: CRUD Disable Flag
**Location**: `backend/Endpoints/ListingEndpoints.cs`
**Endpoints**: POST, PUT, DELETE on `/api/listings`
**Trigger**: `ENABLE_CRUD` configuration flag set to `false`
**Behavior**: Returns `InvalidOperationException` with message "CRUD operations are currently disabled"

This is an intentional feature flag, not a bug. POST, PUT, and DELETE endpoints check `ENABLE_CRUD` (defaults to `true`) before performing write operations.
