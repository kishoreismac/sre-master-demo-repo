# Known Issues and Error Patterns

## 5xx Errors in Production (RESOLVED)

### Issue: Null Reference Exception in Listing Details Endpoint
**Status**: ✅ RESOLVED — Error injection code removed in `fix/remove-error-injection` branch.
**Location**: `backend/Endpoints/ListingEndpoints.cs`
**Error Type**: NullReferenceException (HTTP 500)
**Endpoint**: `GET /api/listings/{id}`
**Trigger**: ERRORS configuration flag set to true
**Root Cause**: Intentional null reference exception for testing and monitoring purposes
**User Impact**: Users could not view listing details when clicking on a pet listing
**Error Message**: "Object reference not set to an instance of an object"

**Incident History**:
- 2026-04-22 ~09:55 UTC: First occurrence. ERRORS env var was set to true, causing 73.7% failure rate. Mitigated by setting ERRORS=false and restarting.
- 2026-04-22 ~11:38 UTC: Recurrence. Residual traffic hit old revision (octopetsapi--0000002) during transition to new revision (--0000003). Alert auto-closed after investigation confirmed transient nature.

**Permanent Fix**: Removed the error injection code block and `AReallyExpensiveOperation()` method entirely from `ListingEndpoints.cs`.

## Recommendations
1. Do not include intentional error injection code in production codebases
2. Use feature flags via a dedicated service (e.g., Azure App Configuration) instead of env vars for test scenarios
3. Add CI/CD checks that reject builds containing intentional error patterns
