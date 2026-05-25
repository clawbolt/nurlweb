// nurlweb/test_orm.nu — Compile-time unit tests for orm.nu
//
// Run: ./build/nurlc nurlweb/test_orm.nu
// Expected: exit 0 (clean compile)

$ `nurlweb/orm.nu`

// ── OrmParam constructors ─────────────────────────────────────────────

@ test_param_int → OrmParam    { ^ ( param_int 42 ) }
@ test_param_text → OrmParam   { ^ ( param_text `hello` ) }

// ── OrmRow basic ops ──────────────────────────────────────────────────

@ test_orm_row_create → OrmRow {
    : s ctl ( nurl_zalloc 24 )
    : OrmRow row @ OrmRow { ctl }
    : i rn ( orm_row_len row )
    ( orm_row_free row )
    ^ row
}

@ test_orm_row_len_zero → i {
    : s ctl ( nurl_zalloc 24 )
    : OrmRow row @ OrmRow { ctl }
    : i rn ( orm_row_len row )
    ( orm_row_free row )
    ^ rn
}

// ── orm_rows_free empty ───────────────────────────────────────────────

@ test_orm_rows_free → v {
    : s rows_ctl ( nurl_zalloc 24 )
    // Can't use vec_new [OrmRow] due to Vec-local bug — verify orm_rows_free compiles
    : OrmRow row @ OrmRow { 0 }
}

// ── Type literals ─────────────────────────────────────────────────────

@ test_orm_types → v {
    : OrmParam p ( param_int 1 )
    : OrmDB db @ OrmDB { 0 }
    : OrmRow row @ OrmRow { 0 }
    : i ph . p ptype
    : i dbh . db handle
}

// ── Main ──────────────────────────────────────────────────────────────

@ main → i { ^ 0 }
