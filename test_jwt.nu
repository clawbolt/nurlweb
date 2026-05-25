// nurlweb/test_jwt.nu — Compile-time unit tests for auth_jwt.nu
//
// Run: ./build/nurlc nurlweb/test_jwt.nu
// Expected: exit 0 (clean compile)

$ `nurlweb/auth_jwt.nu`

// ── jwt_sign returns a string ─────────────────────────────────────────

@ test_jwt_sign → s {
    ^ ( jwt_sign `hello` `secret123` )
}

// ── jwt_verify returns ?String ────────────────────────────────────────

@ test_jwt_verify → ?String {
    : s token ( jwt_sign `data` `key` )
    ^ ( jwt_verify token `key` )
}

// ── jwt_verify wrong secret returns None ──────────────────────────────

@ test_jwt_bad_secret → ?String {
    : s token ( jwt_sign `payload` `goodkey` )
    : ?String result ( jwt_verify token `badkey` )
    ^ result
}

// ── jwt_create pipeline ───────────────────────────────────────────────

@ test_jwt_create → s {
    ^ ( jwt_create `{"sub":"user1"}` `secret` )
}

// ── jwt_claims extracts payload ───────────────────────────────────────

@ test_jwt_claims → s {
    : s token ( jwt_sign `mydata` `key` )
    ^ ( jwt_claims token )
}

// ── jwt_verify valid token returns Some ───────────────────────────────

@ test_jwt_roundtrip → ?String {
    : s claims `{"id":42}`
    : s token ( jwt_sign claims `secret` )
    : ?String vr ( jwt_verify token `secret` )
    ?? vr {
        T payload → { ^ @ ?String { T payload } }
        F → { ^ @ ?String { F } }
    }
}

// ── Main ──────────────────────────────────────────────────────────────

@ main → i { ^ 0 }
