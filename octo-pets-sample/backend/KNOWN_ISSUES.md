# Known Issues and Error Patterns

## 5xx Errors in Production

### Issue: Null Reference Exception in Listing Details Endpoint
**Location**: `backend/Endpoints/ListingEndpoints.cs` - Line ~60
**Error Type**: NullReferenceException (HTTP 500)
**Endpoint**: `GET /api/listings/{id}`
**Trigger**: ERRORS configuration flag set to true
**Root Cause**: Intentional null reference exception for testing and monitoring purposes
**User Impact**: Users cannot view listing details when clicking on a pet listing
**Error Message**: "Object reference not set to an instance of an object"

**Code Pattern**:
```csharp
string nullString = null;
var length = nullString.Length; // Causes NullReferenceException -> HTTP 500
```

## Resolution Steps
1. Navigate to Azure Container App configuration
2. Update environment variable: `ERRORS=false`
3. Restart the container app
4. Verify listing details endpoint returns 200 status
5. Alternatively, remove the error injection code block from ListingEndpoints.cs

## Alternative Error Mechanism
The code also includes `AReallyExpensiveOperation()` which simulates memory exhaustion by allocating ~1GB of memory. This is currently commented out in favor of the clearer NullReferenceException.