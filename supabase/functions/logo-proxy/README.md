# logo-proxy

Edge function that turns a service hostname into a brand logo image, fetching
from logo.dev server-side so the logo.dev API key never reaches a client.

```
GET /functions/v1/logo-proxy?domain=netflix.com&size=128
-> 200 image/jpeg  (cached 7 days)
```

Callers are `getLogoUrl()` in the desktop app (`src/config/logoApi.ts`) and
`KnownServices.swift` in the iOS app. Both consume the result as an `<img>` /
`AsyncImage` source with a letter-avatar fallback on error, so any non-200
degrades gracefully rather than surfacing an error to the user.

## Source provenance

**This file was recovered, not written from the deployed artifact.** The
function has been live since 2026-02-21, but its source was lost from `main`
during the 2026-08-01 branch cleanup. It was recovered from the archived
`app-review-suggestions` branch of the SubTrkr desktop repo:

```bash
git show dacbbe8:supabase/functions/logo-proxy/index.ts
```

The recovered file was byte-for-byte the deployed logic; the version here adds
the hardening below. See `docs/completed/2026-08-01-archived-branches.md` in the
desktop repo for the archive index.

## Parameters

| Param | Required | Accepted | Behavior |
| --- | --- | --- | --- |
| `domain` | yes | RFC-1123 hostname, ≥2 labels, alphabetic TLD, ≤253 chars | Anything else → `400` |
| `size` | no | integer, clamped to 16–512 | Absent/empty → `128`; non-integer → `400` |

`domain` is normalized (trimmed, lowercased, optional trailing root dot and
leading `www.` removed) *before* validation. Normalization never changes which
host is contacted — it only cleans up a value that is still required to pass the
hostname regex.

## SSRF posture

The upstream origin is the hard-coded constant `https://img.logo.dev`. The
caller contributes exactly one validated path segment and nothing else. No
caller-supplied URL, host, port, scheme, or userinfo is ever fetched — which
matters because this function runs inside Supabase's infrastructure, where a
caller-controlled fetch would reach internal metadata endpoints.

The validation regex rejects `https://…`, `//host`, `host:8080`, `user:pass@`,
`../` traversal, bare IPs, and `[::1]`, so those never reach URL construction.

## Hardening applied on recovery

The originally deployed version was functional but loose. Changes:

1. **Strict hostname regex.** The old `/^[a-z0-9.-]+$/` accepted `..`, `-`,
   `.foo.com`, and `foo..com`. Now each label must be a valid RFC-1123 label.
2. **`size` must be an integer.** The old version silently coerced garbage
   (`size=abc`) to the default. Now it returns `400`.
3. **Content-Type allowlist.** The old version echoed upstream's `Content-Type`
   verbatim, so an upstream `text/html` would be served as HTML from the
   project's `*.supabase.co` origin. Now the base type must be a known image
   type or it is downgraded to `image/png`. `X-Content-Type-Options: nosniff`
   and `Content-Security-Policy: default-src 'none'; sandbox` are also set, so a
   direct navigation to a proxied SVG cannot execute script.
4. **Upstream timeout.** 10s via `AbortSignal.timeout`; previously unbounded.
5. **Status mapping.** `404` still passes through (normal "no logo for this
   brand"). Other upstream failures now collapse to `502` instead of forwarding
   logo.dev's status — a bad token surfacing as `401` reads like a Supabase auth
   failure and sends debugging in the wrong direction.
6. **Longer cache.** `max-age` raised from 1 day to 7 days with
   `stale-while-revalidate=86400`, cutting logo.dev quota burn on repeat renders.

## Deployment

> The currently deployed version keeps serving until this is deployed. Nothing
> here is required to keep logos working today.

`LOGO_DEV_API_KEY` is already set on the project from the original 2026-02-21
setup, so step 1 is only needed if the key is being rotated.

### 1. (Only if rotating) Set the secret

Use the logo.dev **publishable** key — a secret key is rejected by
`img.logo.dev`.

```bash
supabase secrets set LOGO_DEV_API_KEY='<publishable-key>' \
  --project-ref bpgsfyallqqvvtjorybl
```

### 2. Deploy

`verify_jwt = false` is mandatory: an `<img>` tag cannot attach an
`Authorization` header. It is declared in `supabase/config.toml`, but pass the
flag explicitly so a stale local config cannot lock the function behind JWT
verification and black-hole every logo in both apps.

```bash
supabase functions deploy logo-proxy --no-verify-jwt \
  --project-ref bpgsfyallqqvvtjorybl
```

### 3. Verify

```bash
BASE=https://bpgsfyallqqvvtjorybl.supabase.co/functions/v1/logo-proxy

# happy path -> 200, content-type image/*
curl -sI "$BASE?domain=netflix.com&size=128"

# rejected inputs -> 400
curl -so /dev/null -w '%{http_code}\n' "$BASE?domain=https://evil.com"
curl -so /dev/null -w '%{http_code}\n' "$BASE?domain=169.254.169.254"
curl -so /dev/null -w '%{http_code}\n' "$BASE?domain=netflix.com&size=abc"

# unknown brand -> 404 (client falls back to the letter avatar)
curl -so /dev/null -w '%{http_code}\n' "$BASE?domain=definitely-not-a-real-brand-xyz.com"
```

## Known gaps

- **Unauthenticated and unrate-limited.** `verify_jwt = false` is required by the
  `<img>` call pattern, so anyone who knows the URL can use the project's
  logo.dev quota as a free logo API. The 7-day cache blunts this but does not
  fix it. Adding per-IP rate limiting was already flagged as a follow-up in the
  original 2026-02-21 setup notes.
- **Redirects are followed.** `fetch` defaults to `redirect: "follow"`, matching
  the deployed behavior (logo.dev appears to redirect to a CDN). The token is
  only in the initial request URL and is not re-sent as a header, but this does
  mean the final byte source is whatever logo.dev points at.

## Local development

```bash
supabase functions serve logo-proxy --no-verify-jwt --env-file supabase/.env.local
curl -sI 'http://localhost:54321/functions/v1/logo-proxy?domain=netflix.com&size=128'
```
