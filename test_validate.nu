// nurlweb/test_validate.nu — Compile-time unit tests for validate.nu
//
// Verifies that Schema types and validation functions compile.
// Run: ./build/nurlc nurlweb/test_validate.nu
// Expected: exit 0

$ `nurlweb/validate.nu`
$ `stdlib/ext/json.nu`

// ── Test: schema_new + schema_field compiles ──────────────────────────

@ test_schema_build Ctx ctx → !Json ValidateErr {
    : Schema s ( schema_new )
    ( schema_field s `name` FIELD_TYPE_STRING REQUIRED )
    ( schema_field s `age` FIELD_TYPE_NUMBER OPTIONAL )
    ( schema_field s `active` FIELD_TYPE_BOOL REQUIRED )
    ( schema_field s `tags` FIELD_TYPE_ARRAY OPTIONAL )
    ( schema_field s `meta` FIELD_TYPE_OBJECT OPTIONAL )
    : !Json ValidateErr result ( validate_json ctx s )
    ( schema_free s )
    ^ result
}

// ── Test: validate_json return type compiles ──────────────────────────

@ test_validate_return Ctx ctx Schema s → !Json ValidateErr {
    ^ ( validate_json ctx s )
}

// ── Test: ValidateErr struct fields accessible ────────────────────────

@ test_validate_err_fields ValidateErr e → s {
    : s field . e field
    : s code  . e code
    : s expected . e expected
    : s got . e got
    ^ field
}

// ── Test: error path — parse error ────────────────────────────────────

@ test_validate_parse_error Ctx ctx Schema s → s {
    : !Json ValidateErr vr ( validate_json ctx s )
    ?? vr {
        T _ → { ^ `ok` }
        F e → { ^ . e code }
    }
}

// ── Test: schema_free compiles ────────────────────────────────────────

@ test_schema_free → v {
    : Schema s ( schema_new )
    ( schema_field s `x` FIELD_TYPE_STRING REQUIRED )
    ( schema_free s )
}

// ── Main ──────────────────────────────────────────────────────────────

@ main → i { ^ 0 }
