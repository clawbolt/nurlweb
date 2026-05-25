// nurlweb/orm.nu — SQLite ORM-lite
//
// Wraps NURL's sqlite3 C builtins directly. Zero stdlib dependency beyond
// string/vec utilities. All queries use parameterized binding — no SQL injection.
//
// API: orm_open, orm_close, orm_exec, orm_query, orm_query_one, orm_insert,
//      orm_row_get, orm_row_len, orm_row_free, orm_rows_free,
//      param_int, param_text, param_null

$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`

// ── Types ─────────────────────────────────────────────────────────────

: DbErr { i code }

: OrmDB   { i handle }
: OrmRow  { s hnd }

: OrmParam {
    i ptype
    i ival
    s sval
}

// ── OrmParam constructors ─────────────────────────────────────────────

@ param_int i v → OrmParam   { ^ @ OrmParam { 1 v `` } }
@ param_text s v → OrmParam  { ^ @ OrmParam { 2 0 v } }
@ param_null → OrmParam       { ^ @ OrmParam { 3 0 `` } }
// ── orm_quote_ident — safe SQL identifier quoting ────────────────────
// Double-quotes the identifier and escapes embedded quotes per SQLite
// rules. Use for table/column names built from user input.
//
//   ( orm_quote_ident `users` )  →  `"users"`
//   ( orm_quote_ident `a"b` )    →  `"a""b"`

@ orm_quote_ident s name → String {
    : i nlen ( nurl_str_len name )
    : String out ( string_with_cap + nlen 4 )
    ( string_push_char out 34 )  // opening quote
    : ~ i pos 0
    ~ < pos nlen {
        : i ch ( nurl_str_get name pos )
        ? == ch 34 {
            ( string_push_char out 34 )
            ( string_push_char out 34 )
        } {
            ( string_push_char out ch )
        }
        = pos + pos 1
    }
    ( string_push_char out 34 )  // closing quote
    ^ out
}


// ── OrmRow ops ────────────────────────────────────────────────────────

@ __o2v OrmRow row → ( Vec String ) { ^ @ ( Vec String ) { . row hnd } }

@ orm_row_get OrmRow row i idx → String {
    : ( Vec String ) v ( __o2v row )
    : ?String s_opt ( vec_get [String] v idx )
    ?? s_opt { T s → { ^ s } F → { : String e ( string_with_cap 0 ) ^ e } }
}

@ orm_row_len OrmRow row → i {
    : ( Vec String ) v ( __o2v row )
    ^ ( vec_len [String] v )
}

@ orm_row_free OrmRow row → v {
    : ( Vec String ) v ( __o2v row )
    ( vec_free [String] v )
}

@ orm_rows_free ( Vec OrmRow ) rows → v {
    : i n ( vec_len [OrmRow] rows )
    : ~ i k 0
    ~ < k n {
        : ?OrmRow r_opt ( vec_get [OrmRow] rows k )
        ?? r_opt { T r → { ( orm_row_free r ) } F → {} }
        = k + k 1
    }
    ( vec_free [OrmRow] rows )
}

// ── DB open/close ─────────────────────────────────────────────────────

@ orm_open s path → ! OrmDB IoErr {
    : i h ( nurl_sqlite_open path )
    ? != h 0 { ^ @ ! OrmDB IoErr { T @ OrmDB { h } } }
            { ^ @ ! OrmDB IoErr { F @ IoErr {} } }
}

@ orm_close OrmDB db → v {
    : i h . db handle
    ? != h 0 { ( nurl_sqlite_close h ) } {}
}

// ── orm_exec ──────────────────────────────────────────────────────────

@ orm_exec OrmDB db s sql → ! i DbErr {
    : i stmt ( nurl_sqlite_prepare . db handle sql )
    ? == stmt 0 { ^ @ ! i DbErr { F @ DbErr { -1 } } } {}
    : i rc ( nurl_sqlite_step stmt )
    ( nurl_sqlite_finalize stmt )
    ? == rc 101 { ^ @ ! i DbErr { T 0 } }
                { ^ @ ! i DbErr { F @ DbErr { rc } } }
}

// ── __orm_bind_params ─────────────────────────────────────────────────

@ __orm_bind_params i stmt ( Vec OrmParam ) params → ! i DbErr {
    : i pn ( vec_len [OrmParam] params )
    : ~ i pi 0
    ~ < pi pn {
        : ?OrmParam p_opt ( vec_get [OrmParam] params pi )
        ?? p_opt {
            T p → {
                : i bidx + pi 1
                : i pt . p ptype
                ? == pt 1 {
                    : i br ( nurl_sqlite_bind_int stmt bidx . p ival )
                    ? != br 0 { ^ @ ! i DbErr { F @ DbErr { br } } } {}
                } {
                    ? == pt 2 {
                        : i br ( nurl_sqlite_bind_text stmt bidx . p sval )
                        ? != br 0 { ^ @ ! i DbErr { F @ DbErr { br } } } {}
                    } {
                        ? == pt 3 {
                            : i br ( nurl_sqlite_bind_null stmt bidx )
                            ? != br 0 { ^ @ ! i DbErr { F @ DbErr { br } } } {}
                        } {}
                    }
                }
            }
            F → {}
        }
        = pi + pi 1
    }
    ^ @ ! i DbErr { T 0 }
}

// ── __orm_bind_params ─────────────────────────────────────────────────

// ── orm_query: return rows as Vec of OrmRow ───────────────────────────
// NOTE: avoids Vec String locals due to nurlc type-erasure bug.
// Each row's columns are stored as a Vec String accessed only via
// the ctl handle (s) — never via a Vec String local.

@ orm_query OrmDB db s sql ( Vec OrmParam ) params → ! ( Vec OrmRow ) DbErr {
    : i stmt ( nurl_sqlite_prepare . db handle sql )
    ? == stmt 0 { ^ @ ! ( Vec OrmRow ) DbErr { F @ DbErr { -1 } } } {}

    : ! i DbErr br ( __orm_bind_params stmt params )
    ?? br {
        T _ → {}
        F e → { ( nurl_sqlite_finalize stmt ) ^ @ ! ( Vec OrmRow ) DbErr { F e } }
    }

    : s rows_ctl ( nurl_zalloc 24 )
    : ~ b done F
    ~ ! done {
        : i rc ( nurl_sqlite_step stmt )
        ? == rc 100 {
            : i ncols ( nurl_sqlite_column_count stmt )
            // Read row directly into an OrmRow via ctl handle
            : s ctl ( nurl_zalloc 24 )
            : ~ i ci 0
            ~ < ci ncols {
                : i ctype ( nurl_sqlite_column_type stmt ci )
                ? == ctype 3 {
                    : i8 raw ( nurl_sqlite_column_text stmt ci )
                    : i slen ( nurl_str_len raw )
                    : String val ( string_from_bytes raw slen )
                    : String copy ( string_clone val )
                    ( string_free val )
                    // Push copy into the Vec managed by ctl
                    : String col_val copy
                    // vec_push [String] inlined: use raw ctl calls
                    : i vcap ( nurl_peek ctl 2 )
                    : i vlen ( nurl_peek ctl 1 )
                    ? < vlen vcap {
                        : s data ( nurl_peek ctl 0 )
                        // store String (single ptr) at data + vlen*8
                        : i off * vlen 8
                        : i addr + # i data off
                        ( nurl_poke addr 0 # i ( string_data col_val ) )
                        ( nurl_poke ctl 1 + vlen 1 )
                    } {
                        // Grow: vec_grow then push
                        : i new_cap ? == vcap 0 4 * vcap 2
                        : s old_data ( nurl_peek ctl 0 )
                        : i z ? == vcap 0 0 8
                        : s new_data ( nurl_realloc old_data * z new_cap )
                        ( nurl_poke ctl 0 # i new_data )
                        ( nurl_poke ctl 2 new_cap )
                        : i off * vlen 8
                        : i addr + # i new_data off
                        ( nurl_poke addr 0 # i ( string_data col_val ) )
                        ( nurl_poke ctl 1 + vlen 1 )
                    }
                } {
                    // Non-text: push empty String (zero pointer)
                    : i vlen2 ( nurl_peek ctl 1 )
                    : i vcap2 ( nurl_peek ctl 2 )
                    ? < vlen2 vcap2 {
                        : s data2 ( nurl_peek ctl 0 )
                        : i off2 * vlen2 8
                        : i addr2 + # i data2 off2
                        ( nurl_poke addr2 0 0 )
                        ( nurl_poke ctl 1 + vlen2 1 )
                    } {
                        : i nc2 ? == vcap2 0 4 * vcap2 2
                        : s od2 ( nurl_peek ctl 0 )
                        : i z2 ? == vcap2 0 0 8
                        : s nd2 ( nurl_realloc od2 * z2 nc2 )
                        ( nurl_poke ctl 0 # i nd2 )
                        ( nurl_poke ctl 2 nc2 )
                        : i off2 * vlen2 8
                        : i addr2 + # i nd2 off2
                        ( nurl_poke addr2 0 0 )
                        ( nurl_poke ctl 1 + vlen2 1 )
                    }
                }
                = ci + ci 1
            }
            : OrmRow row @ OrmRow { ctl }
            // Push row into rows_ctl (manual vec_push for OrmRow)
            : i vr_cap ( nurl_peek rows_ctl 2 )
            : i vr_len ( nurl_peek rows_ctl 1 )
            ? < vr_len vr_cap {
                : s vr_data ( nurl_peek rows_ctl 0 )
                // OrmRow is { s hnd } = single ptr = 8 bytes
                : i vr_off * vr_len 8
                : i vr_addr + # i vr_data vr_off
                ( nurl_poke vr_addr 0 # i ( string_data ctl ) )  // ctl is OrmRow's hnd, casted
                ( nurl_poke rows_ctl 1 + vr_len 1 )
            } {
                : i vr_nc ? == vr_cap 0 4 * vr_cap 2
                : s vr_od ( nurl_peek rows_ctl 0 )
                : i vr_z ? == vr_cap 0 0 8
                : s vr_nd ( nurl_realloc vr_od * vr_z vr_nc )
                ( nurl_poke rows_ctl 0 # i vr_nd )
                ( nurl_poke rows_ctl 2 vr_nc )
                : i vr_off * vr_len 8
                : i vr_addr + # i vr_nd vr_off
                ( nurl_poke vr_addr 0 # i ( string_data ctl ) )
                ( nurl_poke rows_ctl 1 + vr_len 1 )
            }
        } {
            = done T
        }
    }

    ( nurl_sqlite_finalize stmt )
    ^ @ ! ( Vec OrmRow ) DbErr { T @ ( Vec OrmRow ) { rows_ctl } }
}

// ── orm_query_one ─────────────────────────────────────────────────────

@ orm_query_one OrmDB db s sql ( Vec OrmParam ) params → ! OrmRow DbErr {
    : i stmt ( nurl_sqlite_prepare . db handle sql )
    ? == stmt 0 { ^ @ ! OrmRow DbErr { F @ DbErr { -1 } } } {}

    : ! i DbErr br ( __orm_bind_params stmt params )
    ?? br {
        T _ → {}
        F e → { ( nurl_sqlite_finalize stmt ) ^ @ ! OrmRow DbErr { F e } }
    }

    : i rc ( nurl_sqlite_step stmt )
    ? == rc 100 {
        : i ncols ( nurl_sqlite_column_count stmt )
        : s ctl ( nurl_zalloc 24 )
        : ~ i ci 0
        ~ < ci ncols {
            : i ctype ( nurl_sqlite_column_type stmt ci )
            ? == ctype 3 {
                : i8 raw ( nurl_sqlite_column_text stmt ci )
                : i slen ( nurl_str_len raw )
                : String val ( string_from_bytes raw slen )
                : String copy ( string_clone val )
                ( string_free val )
                : String col_val copy
                : i vcap ( nurl_peek ctl 2 )
                : i vlen ( nurl_peek ctl 1 )
                ? < vlen vcap {
                    : s data ( nurl_peek ctl 0 )
                    : i off * vlen 8
                    : i addr + # i data off
                    ( nurl_poke addr 0 # i ( string_data col_val ) )
                    ( nurl_poke ctl 1 + vlen 1 )
                } {
                    : i new_cap ? == vcap 0 4 * vcap 2
                    : s old_data ( nurl_peek ctl 0 )
                    : i z ? == vcap 0 0 8
                    : s new_data ( nurl_realloc old_data * z new_cap )
                    ( nurl_poke ctl 0 # i new_data )
                    ( nurl_poke ctl 2 new_cap )
                    : i off * vlen 8
                    : i addr + # i new_data off
                    ( nurl_poke addr 0 # i ( string_data col_val ) )
                    ( nurl_poke ctl 1 + vlen 1 )
                }
            } {
                : i vlen2 ( nurl_peek ctl 1 )
                : i vcap2 ( nurl_peek ctl 2 )
                ? < vlen2 vcap2 {
                    : s data2 ( nurl_peek ctl 0 )
                    : i off2 * vlen2 8
                    : i addr2 + # i data2 off2
                    ( nurl_poke addr2 0 0 )
                    ( nurl_poke ctl 1 + vlen2 1 )
                } {
                    : i nc2 ? == vcap2 0 4 * vcap2 2
                    : s od2 ( nurl_peek ctl 0 )
                    : i z2 ? == vcap2 0 0 8
                    : s nd2 ( nurl_realloc od2 * z2 nc2 )
                    ( nurl_poke ctl 0 # i nd2 )
                    ( nurl_poke ctl 2 nc2 )
                    : i off2 * vlen2 8
                    : i addr2 + # i nd2 off2
                    ( nurl_poke addr2 0 0 )
                    ( nurl_poke ctl 1 + vlen2 1 )
                }
            }
            = ci + ci 1
        }
        ( nurl_sqlite_finalize stmt )
        : OrmRow row @ OrmRow { ctl }
        ^ @ ! OrmRow DbErr { T row }
    } {
        ( nurl_sqlite_finalize stmt )
        ^ @ ! OrmRow DbErr { F @ DbErr { -2 } }
    }
}

// ── orm_insert ────────────────────────────────────────────────────────

@ orm_insert OrmDB db s table ( Vec s ) cols ( Vec OrmParam ) vals → ! i DbErr {
    : i cn ( vec_len [s] cols )
    : i vn ( vec_len [OrmParam] vals )
    : i n ? < cn vn cn vn
    ? == n 0 { ^ @ ! i DbErr { F @ DbErr { -1 } } } {}

    : String sql ( string_with_cap 256 )
    ( string_push_str sql `INSERT INTO ` )
    ( string_push_str sql table )
    ( string_push_str sql ` (` )
    : ~ i k 0
    ~ < k n {
        : ?String c_opt ( vec_get [s] cols k )
        ?? c_opt { T c → { ( string_push_str sql ( string_data c ) ) } F → {} }
        ? < k - n 1 { ( string_push_str sql `, ` ) } {}
        = k + k 1
    }
    ( string_push_str sql `) VALUES (` )
    : ~ i k2 0
    ~ < k2 n {
        ( string_push_str sql `?` )
        ? < k2 - n 1 { ( string_push_str sql `, ` ) } {}
        = k2 + k2 1
    }
    ( string_push_str sql `)` )

    : s sql_data ( string_data sql )
    : i stmt ( nurl_sqlite_prepare . db handle sql_data )
    ( string_free sql )
    ? == stmt 0 { ^ @ ! i DbErr { F @ DbErr { -1 } } } {}

    : ! i DbErr br ( __orm_bind_params stmt vals )
    ?? br {
        T _ → {}
        F e → { ( nurl_sqlite_finalize stmt ) ^ @ ! i DbErr { F e } }
    }

    : i rc ( nurl_sqlite_step stmt )
    ( nurl_sqlite_finalize stmt )
    ? == rc 101 { ^ @ ! i DbErr { T 0 } }
                { ^ @ ! i DbErr { F @ DbErr { rc } } }
}
