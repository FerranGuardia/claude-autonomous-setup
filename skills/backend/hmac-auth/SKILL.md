---
name: hmac-auth
description: HMAC-SHA256 custom authentication for ASP.NET Web API 2. Request signing, nonce replay protection, timestamp validation, API key management, timing-safe comparison.
---

# HMAC-SHA256 Authentication (Web API 2)

## How It Works

1. Client and server share a secret key (never transmitted)
2. Client signs request parts with HMAC-SHA256
3. Server rebuilds the signature from the same parts
4. If signatures match → authenticated
5. Nonce + timestamp prevent replay attacks

## Request Signing

### What to sign (canonical string)

```
{HTTP_METHOD}\n
{Request_URI}\n
{Timestamp}\n
{Nonce}\n
{Content_MD5_Hash}
```

### Authorization header format

```
Authorization: amx {AppId}:{Signature}:{Nonce}:{Timestamp}
```

### Signature Computation

```csharp
using System.Security.Cryptography;

public static string ComputeSignature(byte[] secretKey, string stringToSign)
{
    byte[] messageBytes = Encoding.UTF8.GetBytes(stringToSign);
    using (var hmac = new HMACSHA256(secretKey))
    {
        byte[] hashValue = hmac.ComputeHash(messageBytes);
        return Convert.ToBase64String(hashValue);
    }
}

public static string ComputeContentMD5(byte[] content)
{
    using (var md5 = MD5.Create())
    {
        byte[] hash = md5.ComputeHash(content);
        return Convert.ToBase64String(hash);
    }
}
```

## Server-Side Validation

### DelegatingHandler (pipeline-level, runs before controllers)

```csharp
public class HmacAuthenticationHandler : DelegatingHandler
{
    private const int RequestMaxAgeInSeconds = 300; // 5 minutes
    private static readonly MemoryCache NonceCache = MemoryCache.Default;

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        // 1. Extract Authorization header
        if (request.Headers.Authorization == null ||
            request.Headers.Authorization.Scheme != "amx")
        {
            return await base.SendAsync(request, cancellationToken);
        }

        string rawAuthHeader = request.Headers.Authorization.Parameter;
        string[] authParts = rawAuthHeader.Split(':');
        if (authParts.Length != 4)
            return Unauthorized();

        string appId = authParts[0];
        string signature = authParts[1];
        string nonce = authParts[2];
        string timestamp = authParts[3];

        // 2. Look up the shared secret for this AppId
        byte[] sharedKey = await GetSecretForAppId(appId);
        if (sharedKey == null) return Unauthorized();

        // 3. Validate timestamp
        if (IsExpiredRequest(timestamp)) return Unauthorized();

        // 4. Validate nonce (replay protection)
        if (IsReplayRequest(nonce, timestamp)) return Unauthorized();

        // 5. Rebuild signature server-side
        string requestUri = request.RequestUri.AbsoluteUri.ToLower();
        string method = request.Method.Method;
        string contentMd5 = "";
        if (request.Content != null)
        {
            byte[] content = await request.Content.ReadAsByteArrayAsync();
            contentMd5 = ComputeContentMD5(content);
        }

        string stringToSign = $"{method}\n{requestUri}\n{timestamp}\n{nonce}\n{contentMd5}";
        string serverSignature = ComputeSignature(sharedKey, stringToSign);

        // 6. Constant-time comparison (CRITICAL — prevents timing attacks)
        if (!SlowEquals(
                Convert.FromBase64String(serverSignature),
                Convert.FromBase64String(signature)))
            return Unauthorized();

        // 7. Set principal
        var principal = new GenericPrincipal(
            new GenericIdentity(appId), null);
        Thread.CurrentPrincipal = principal;
        if (HttpContext.Current != null)
            HttpContext.Current.User = principal;

        return await base.SendAsync(request, cancellationToken);
    }

    private HttpResponseMessage Unauthorized()
    {
        return new HttpResponseMessage(HttpStatusCode.Unauthorized);
    }
}
```

### Register in WebApiConfig

```csharp
config.MessageHandlers.Add(new HmacAuthenticationHandler());
```

**Key insight**: If the handler creates a response without calling `base.SendAsync`, the request skips the rest of the pipeline (never reaches controllers).

### Setting the Principal (IIS-hosted — must set BOTH)

```csharp
Thread.CurrentPrincipal = principal;
if (HttpContext.Current != null)
    HttpContext.Current.User = principal;
```

## Replay Protection

### Nonce Cache

```csharp
private static readonly MemoryCache NonceCache = MemoryCache.Default;

private bool IsReplayRequest(string nonce, string requestTimestamp)
{
    if (NonceCache.Contains(nonce))
        return true;  // Nonce already used

    NonceCache.Add(nonce, requestTimestamp,
        DateTimeOffset.UtcNow.AddSeconds(RequestMaxAgeInSeconds));
    return false;
}
```

### Timestamp Validation

```csharp
private bool IsExpiredRequest(string requestTimestamp)
{
    var epochStart = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);
    var currentTs = (DateTime.UtcNow - epochStart).TotalSeconds;
    var requestTs = Convert.ToDouble(requestTimestamp);

    return Math.Abs(currentTs - requestTs) > RequestMaxAgeInSeconds;
}
```

## Timing-Safe Comparison (CRITICAL)

**NEVER use `==` or `string.Equals` to compare signatures.** Variable-time comparison leaks info about which bytes match.

```csharp
private static bool SlowEquals(byte[] a, byte[] b)
{
    int diff = a.Length ^ b.Length;
    for (int i = 0; i < a.Length && i < b.Length; i++)
    {
        diff |= a[i] ^ b[i];
    }
    return diff == 0;
}
```

## Alternative: IAuthenticationFilter (Web API 2)

```csharp
public class HmacAuthFilter : Attribute, IAuthenticationFilter
{
    public bool AllowMultiple => false;

    public async Task AuthenticateAsync(
        HttpAuthenticationContext context, CancellationToken ct)
    {
        var request = context.Request;

        // Validate HMAC...
        if (!isValid)
        {
            context.ErrorResult = new AuthenticationFailureResult(
                "Invalid HMAC signature", request);
            return;
        }

        context.Principal = new GenericPrincipal(
            new GenericIdentity(appId), null);
    }

    public Task ChallengeAsync(
        HttpAuthenticationChallengeContext context, CancellationToken ct)
    {
        // Add WWW-Authenticate header on 401 if needed
        return Task.CompletedTask;
    }
}
```

Can be applied per-controller, per-action, or globally:
```csharp
config.Filters.Add(new HmacAuthFilter());
```

## API Key Management

- Store AppId (public) + Secret (hashed/encrypted) in database
- Each client gets unique AppId + Secret, shared out-of-band
- Key rotation: issue new keys with overlap period, deprecate old
- NEVER log the secret or include in error messages
- NEVER transmit the secret — only the AppId travels in requests

## Common Vulnerabilities

| Vulnerability | Mitigation |
|---------------|------------|
| Timing attacks on signature comparison | Use `SlowEquals` constant-time comparison |
| Replay attacks | Nonce cache + timestamp window (5 min) |
| Body tampering | Include Content-MD5 in signed string |
| Clock skew | Allow tolerance window (±5 min), use UTC |
| Secret exposure in logs | Never log Authorization header value |
| Nonce cache overflow | Use TTL-based eviction (MemoryCache handles this) |
| Secret in source code | Store in database or secrets manager, not config |

## Checklist

- [ ] Signature includes: method, URI, timestamp, nonce, content hash
- [ ] Constant-time comparison (`SlowEquals`) used for signature validation
- [ ] Nonce cache with TTL prevents replay attacks
- [ ] Timestamp window rejects old requests (≤5 min)
- [ ] Principal set on BOTH `Thread.CurrentPrincipal` AND `HttpContext.Current.User`
- [ ] Secrets stored securely (database, not source code)
- [ ] Authorization header never logged
- [ ] Content-MD5 included for requests with body
