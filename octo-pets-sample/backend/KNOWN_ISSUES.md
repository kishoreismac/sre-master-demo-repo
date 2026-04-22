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
This code caused **6 separate Sev3 alerts** in ~2 hours:

| # | Time (UTC) | Alert | Root Cause | Deviation | Action |
|---|------------|-------|------------|-----------|--------|
| 1 | 10:25 | avgresponse on octopetsapi | ERRORS=true, 73.7% failure | +3,507% | Set ERRORS=false, restart |
| 2 | 11:38 | avgresponse on octopetsapi | Residual traffic to old revision | -52.51% | Alert closed (transient) |
| 3 | 11:38 | avgresponse on octopetsapi | Same residual traffic pattern | 0.00% | Alert closed (transient) |
| 4 | 11:50 | avgresponse on octopetsapi | ERRORS=true re-enabled | -26.47% | ERRORS=false + PR #7 merged permanently |
| 5 | 11:56 | avgresponse on octopetsapi | ERRORS=true still on deployed image | +18,297% | Scale-up octopetsfe + Issue #9 + ERRORS=false |
| 6 | 12:08 | avgresponse on octopetsapi | Stale data in alert window | -99.39% | No action — system healthy |

### Post-Incident Verification
- **12:46 UTC**: Scheduled diagnostic confirmed system stable — zero errors, zero failed requests, ERRORS=false, all replicas healthy.
- **9 revisions** of octopetsapi were created during the incident response cycle.

### Resolution
- **PR #7** merged (commit `c0c4909`) — permanently removed all error injection code
- The `ERRORS` environment variable no longer has any effect on the application
- The `ERRORS` env var can be safely removed from the container app configuration

### Lessons Learned
1. Never deploy intentional error injection code to production — use feature flags in a testing environment only
2. Add CI/CD guardrails to detect and reject error injection patterns before deployment
3. Monitor for sudden HTTP 500 rate increases, not just average response time
4. When setting env vars to `false` as mitigation, also pursue a permanent code fix immediately
5. After merging a code fix, **rebuild and redeploy** from clean source — toggling env vars alone is insufficient if the old image is still running
6. Investigate Activity Logs when env vars are repeatedly changed to identify the responsible actor/automation

## EF Core Warnings (Non-Critical)

### Issue: Missing Value Comparers on Collection Properties
**Status**: Active (non-critical warning)
**Location**: `backend/Models/Listing.cs`
**Properties**: `Listing.AllowedPets`, `Listing.Amenities`
**EF Core Event ID**: 10620
**Severity**: Low

**Warning Message**:
> The property 'Listing.AllowedPets' is a collection or enumeration type with a value converter but with no value comparer. Set a value comparer to ensure the collection/enumeration elements are compared correctly.

**Impact**: EF Core may not correctly detect modifications to these collection properties during change tracking. This could lead to missed updates when saving changes to listings that modify allowed pets or amenities.

**Recommended Fix**: Add explicit `ValueComparer` configurations in `AppDbContext.cs` for these properties:
```csharp
modelBuilder.Entity<Listing>()
    .Property(l => l.AllowedPets)
    .Metadata.SetValueComparer(new ValueComparer<List<string>>(
        (c1, c2) => c1.SequenceEqual(c2),
        c => c.Aggregate(0, (a, v) => HashCode.Combine(a, v.GetHashCode())),
        c => c.ToList()));
```

## CRUD Operations Guard

### Feature: CRUD Disable Flag
**Location**: `backend/Endpoints/ListingEndpoints.cs`
**Endpoints**: POST, PUT, DELETE on `/api/listings`
**Trigger**: `ENABLE_CRUD` configuration flag set to `false`
**Behavior**: Returns `InvalidOperationException` with message "CRUD operations are currently disabled"

This is an intentional feature flag, not a bug. POST, PUT, and DELETE endpoints check `ENABLE_CRUD` (defaults to `true`) before performing write operations.
