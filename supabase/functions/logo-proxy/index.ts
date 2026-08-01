import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// Supabase Edge Function: logo-proxy
//
// Proxies logo.dev brand images so the logo.dev API key never reaches a client.
// Clients call GET /functions/v1/logo-proxy?domain=<hostname>&size=<px> and get
// raw image bytes back (see src/config/logoApi.ts in the SubTrkr desktop repo).
//
// Source recovered from the archived `app-review-suggestions` branch of the
// SubTrkr desktop repo (commit dacbbe8, originally added 2026-02-21) and
// hardened before being re-homed here. Hardening applied on recovery:
//   1. Strict hostname validation (per-label RFC-1123 shape) instead of the old
//      permissive /^[a-z0-9.-]+$/, which accepted "..", "-", and bare dots.
//   2. `size` must be an integer; garbage now 400s instead of silently
//      falling back to the default.
//   3. Upstream Content-Type is allowlisted rather than echoed verbatim, so the
//      function can never serve attacker-influenced HTML from the project's
//      *.supabase.co origin.
//   4. Upstream request has an explicit timeout, and non-404 upstream failures
//      collapse to 502 instead of leaking logo.dev's status codes (a bad token
//      surfacing as a 401 reads like a Supabase auth failure).
//
// SSRF posture: the upstream origin is a hard-coded constant and the caller
// only ever contributes a single validated path segment. No caller-supplied
// URL, host, port, or scheme is ever fetched.

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
};

// The ONLY host this function will ever fetch from.
const UPSTREAM_ORIGIN = "https://img.logo.dev";

const MIN_SIZE = 16;
const MAX_SIZE = 512;
const DEFAULT_SIZE = 128;
const MAX_DOMAIN_LENGTH = 253;
const UPSTREAM_TIMEOUT_MS = 10_000;

// Logos are effectively immutable per (domain, size); a week of caching keeps
// the logo.dev quota down and makes list views instant on repeat renders.
const CACHE_CONTROL = "public, max-age=604800, stale-while-revalidate=86400";

// RFC-1123 hostname: dot-separated labels of [a-z0-9] that may contain interior
// hyphens, each label 1-63 chars, at least two labels, alphabetic TLD.
// Deliberately rejects schemes, slashes, ports, userinfo, IP literals, and the
// bracketed IPv6 form -- none of those are valid logo.dev lookup keys.
const HOSTNAME_PATTERN =
  /^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/;

const SIZE_PATTERN = /^\d{1,4}$/;

// Content types we are willing to re-serve from our own origin.
const ALLOWED_IMAGE_TYPES = new Set([
  "image/png",
  "image/jpeg",
  "image/jpg",
  "image/gif",
  "image/webp",
  "image/avif",
  "image/svg+xml",
  "image/x-icon",
  "image/vnd.microsoft.icon",
]);

function errorResponse(message: string, status: number) {
  return new Response(message, {
    status,
    headers: { ...corsHeaders, "Content-Type": "text/plain; charset=utf-8" },
  });
}

// Normalizes a caller-supplied domain and validates it as a hostname.
// Returns null when the input is not a plain hostname -- callers turn that
// into a 400. Normalization is limited to case, surrounding whitespace, the
// optional FQDN root dot, and a leading "www." (logo.dev keys brands off the
// apex domain); nothing that could change which host is contacted.
function sanitizeDomain(input: string): string | null {
  const normalized = input
    .trim()
    .toLowerCase()
    .replace(/\.$/, "")
    .replace(/^www\./, "");

  if (!normalized || normalized.length > MAX_DOMAIN_LENGTH) return null;
  if (!HOSTNAME_PATTERN.test(normalized)) return null;

  return normalized;
}

// Returns the clamped size, or null when the parameter is present but is not a
// plain integer. An absent or empty parameter falls back to DEFAULT_SIZE.
function sanitizeSize(input: string | null): number | null {
  if (input === null) return DEFAULT_SIZE;

  const trimmed = input.trim();
  if (!trimmed) return DEFAULT_SIZE;
  if (!SIZE_PATTERN.test(trimmed)) return null;

  const parsed = Number(trimmed);
  if (!Number.isInteger(parsed)) return null;

  return Math.max(MIN_SIZE, Math.min(MAX_SIZE, parsed));
}

// Upstream may answer "image/jpeg; charset=binary" or something unexpected.
// Strip parameters, allowlist the base type, and fall back to image/png rather
// than ever echoing a document type back to the browser.
function resolveContentType(raw: string | null): string {
  const base = (raw ?? "").split(";")[0].trim().toLowerCase();
  return ALLOWED_IMAGE_TYPES.has(base) ? base : "image/png";
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'GET') {
    return errorResponse("Method not allowed", 405);
  }

  const url = new URL(req.url);
  const domain = sanitizeDomain(url.searchParams.get("domain") ?? "");
  if (!domain) {
    return errorResponse("Invalid domain parameter", 400);
  }

  const size = sanitizeSize(url.searchParams.get("size"));
  if (size === null) {
    return errorResponse("Invalid size parameter", 400);
  }

  const apiKey = Deno.env.get("LOGO_DEV_API_KEY");
  if (!apiKey) {
    console.error("LOGO_DEV_API_KEY is not set; cannot proxy logo requests");
    return errorResponse("Server logo API key not configured", 500);
  }

  // Built from a constant origin. `domain` is a validated hostname and goes in
  // as a single path segment; the token and size go in as encoded query params.
  const upstreamUrl = new URL(`/${domain}`, UPSTREAM_ORIGIN);
  upstreamUrl.searchParams.set("token", apiKey);
  upstreamUrl.searchParams.set("size", String(size));

  try {
    const upstream = await fetch(upstreamUrl, {
      method: "GET",
      headers: { Accept: "image/*" },
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
    });

    if (!upstream.ok) {
      // 404 is a normal "this brand has no logo" answer and is passed through
      // so the client can fall back to its initial-letter avatar. Everything
      // else is our problem, not the caller's, so it reports as a bad gateway.
      //
      // Drain the unused body so the connection is released. A failure here is
      // irrelevant to the caller and must not turn a 404 into a 502.
      await upstream.body?.cancel().catch(() => {});

      if (upstream.status === 404) {
        return errorResponse("Logo not found", 404);
      }

      console.error(`logo.dev returned ${upstream.status} for ${domain}`);
      return errorResponse("Failed to fetch logo", 502);
    }

    const headers = new Headers(corsHeaders);
    headers.set("Content-Type", resolveContentType(upstream.headers.get("Content-Type")));
    headers.set("Cache-Control", CACHE_CONTROL);
    // Belt and braces for the case where someone navigates straight to this
    // URL: no sniffing away from the image type, and no script execution if
    // upstream ever serves an SVG with embedded JS.
    headers.set("X-Content-Type-Options", "nosniff");
    headers.set("Content-Security-Policy", "default-src 'none'; sandbox");

    return new Response(upstream.body, { status: 200, headers });
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error(`Logo proxy request failed for ${domain}: ${msg}`);
    return errorResponse("Logo proxy request failed", 502);
  }
});
