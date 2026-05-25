// nurlweb/auth_jwt.nu — Signed token authentication (JWT-compatible subset)
//
// Uses NURL's built-in nurl_hmac_sha256_hex for HMAC-SHA256 signing.
// Token format: payload.hex_signature  (upgradeable to full JWT with base64url)
//
// API:
//   jwt_sign(s payload, s secret) → s           — returns "payload.hexsig"
//   jwt_verify(s token, s secret) → ?String      — Some(payload) or None
//   jwt_create(s claims_json, s secret) → s      — sign JSON claims
//   jwt_claims(s token) → s                       — extract payload (no verify)

$ `stdlib/core/string.nu`

// ── jwt_sign — sign a payload string with HMAC-SHA256 ─────────────────

@ jwt_sign s payload s secret → s {
    : s sig_hex ( nurl_hmac_sha256_hex payload secret )
    : s dot `.`
    : s result ( nurl_str_cat3 payload dot sig_hex )
    ^ result
}

// ── jwt_verify — verify token and return payload if valid ─────────────

@ jwt_verify s token s secret → ?String {
    // Find the last dot separator
    : i tlen ( nurl_str_len token )
    : i last_dot -1
    : ~ i i - tlen 1
    ~ >= i 0 {
        : i ch ( nurl_str_get token i )
        ? == ch 46 {   // '.'
            = last_dot i
            = i 0      // break loop
        } {}
        = i - i 1
    }

    ? == last_dot -1 {
        ^ @ ?String { F }
    } {}

    // Split payload and signature
    : s payload ( nurl_str_slice token 0 last_dot )
    : i sig_start + last_dot 1
    : s sig ( nurl_str_slice token sig_start - tlen sig_start )

    // Recompute signature
    : s expected ( nurl_hmac_sha256_hex payload secret )

    // Compare (constant-time-ish via nurl_str_eq)
    : i match ( nurl_str_eq sig expected )
    ? != match 0 {
        ^ @ ?String { T payload }
    } {
        ^ @ ?String { F }
    }
}

// ── jwt_create — sign JSON claims string ─────────────────────────────
// Input is a raw JSON string like '{"sub":"123","exp":9999999999}'

@ jwt_create s claims s secret → s {
    ^ ( jwt_sign claims secret )
}

// ── jwt_claims — extract payload from token (no verification) ─────────

@ jwt_claims s token → s {
    : i tlen ( nurl_str_len token )
    : i last_dot -1
    : ~ i i - tlen 1
    ~ >= i 0 {
        : i ch ( nurl_str_get token i )
        ? == ch 46 {
            = last_dot i
            = i 0
        } {}
        = i - i 1
    }
    ? == last_dot -1 {
        ^ token
    } {}
    ^ ( nurl_str_slice token 0 last_dot )
}
