// nurlweb/session.nu — Cookie + server-side session management
//
// Two layers:
//   1. Cookie helpers — ergonomic wrapper around stdlib http_auth.nu
//      (session_get / session_set / session_del). Stateless; data lives
//      in the cookie. Max ~3800 bytes per value.
//   2. SessionStore — in-memory server-side store (MemorySessionStore
//      default). get/set/del interface, minimal by design. Redis/
//      Postgres backends planned for v2.
//
// MAX_COOKIE_VALUE = 3800
//
// API:
//   Cookie layer:
//     ( session_get       Ctx ctx s name )                       → ?String
//     ( session_set       Ctx ctx HttpResponse r s name s value ) → v
//     ( session_del       Ctx ctx HttpResponse r s name )         → v
//
//   Store layer:
//     ( session_store_new   )                                    → SessionStore
//     ( session_store_get   SessionStore store s key )           → ?String
//     ( session_store_set   SessionStore store s key s value )   → v
//     ( session_store_del   SessionStore store s key )           → v
//     ( session_store_free  SessionStore store )                 → v
//
// Usage:
//   // Cookie
//   : ?String sid ( session_get ctx `session_id` )
//   ( session_set ctx res `session_id` `abc123` )
//
//   // Store
//   : SessionStore store ( session_store_new )
//   ( session_store_set store `user` `alice` )
//   : ?String user ( session_store_get store `user` )

$ `nurlweb/ctx.nu`
$ `stdlib/ext/http_auth.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`

// ── Cookie helpers ──────────────────────────────────────────────────

@ session_get Ctx ctx s name → ?String {
    ^ ( request_cookie . ctx req name )
}

@ session_set Ctx ctx HttpResponse r s name s value → v {
    : CookieOpts opts ( cookie_opts_default )
    = . opts path `/`
    = . opts secure T
    = . opts http_only T
    = . opts same_site @ SameSite { SameSiteLax }
    ( response_set_cookie r name value opts )
}

@ session_del Ctx ctx HttpResponse r s name → v {
    : CookieOpts opts ( cookie_opts_default )
    = . opts path `/`
    = . opts max_age 0
    = . opts secure T
    = . opts http_only T
    = . opts same_site @ SameSite { SameSiteLax }
    ( response_set_cookie r name `` opts )
}

// ── SessionStore — server-side session storage ──────────────────────
//
// Memory-backed default. Uses Vec<SessionEntry> because NURL Map
// stores i64 values only. Linear scan for key lookup — acceptable
// for typical session counts (< 1000 active sessions).
//
// Interface is deliberately minimal (get/set/del) — this is the
// only irreversible architecture decision in v1.2. Redis/Postgres
// backends in v2 will implement the same 3-function contract.

: SessionEntry {
    String key
    String value
}

: SessionStore {
    ( Vec SessionEntry ) entries
}

// ── session_store_new — allocate empty in-memory store ────────────

@ session_store_new → SessionStore {
    : ( Vec SessionEntry ) v ( vec_new [SessionEntry] )
    ^ @ SessionStore { v }
}

// ── __session_store_find — linear scan for key index ──────────────

@ __session_store_find SessionStore store s key → i {
    : i n ( vec_len [SessionEntry] . store entries )
    : ~ i k 0
    ~ < k n {
        : ?SessionEntry e_opt ( vec_get [SessionEntry] . store entries k )
        ?? e_opt {
            T e → {
                ? != 0 ( nurl_str_eq . e key key ) { ^ k } {}
            }
            F → {}
        }
        = k + k 1
    }
    ^ -1
}

// ── session_store_get — read a value by key ───────────────────────

@ session_store_get SessionStore store s key → ?String {
    : i idx ( __session_store_find store key )
    ? >= idx 0 {
        : ?SessionEntry e_opt ( vec_get [SessionEntry] . store entries idx )
        ?? e_opt {
            T e → { ^ @ ?String { T . e value } }
            F → { ^ @ ?String { F `` } }
        }
    } { ^ @ ?String { F `` } }
}

// ── session_store_set — upsert a key/value pair ───────────────────

@ session_store_set SessionStore store s key s value → v {
    : i idx ( __session_store_find store key )
    ? >= idx 0 {
        // Update existing entry
        : ?SessionEntry e_opt ( vec_get [SessionEntry] . store entries idx )
        ?? e_opt {
            T e → {
                ( string_free . e value )
                : String vcopy ( string_new )
                ( string_push_str vcopy value )
                = . e value vcopy
            }
            F → {}
        }
    } {
        // Insert new entry
        : SessionEntry ne @ SessionEntry {
            ( string_new ) ( string_new )
        }
        ( string_push_str . ne key key )
        ( string_push_str . ne value value )
        ( vec_push [SessionEntry] . store entries ne )
    }
}

// ── session_store_del — remove a key ──────────────────────────────

@ session_store_del SessionStore store s key → v {
    : i idx ( __session_store_find store key )
    ? >= idx 0 {
        : ?SessionEntry e_opt ( vec_get [SessionEntry] . store entries idx )
        ?? e_opt {
            T e → {
                ( string_free . e key )
                ( string_free . e value )
            }
            F → {}
        }
        ( vec_remove [SessionEntry] . store entries idx )
    } {}
}

// ── session_store_free — release all entries and vec ──────────────

@ session_store_free SessionStore store → v {
    : i n ( vec_len [SessionEntry] . store entries )
    : ~ i k 0
    ~ < k n {
        : ?SessionEntry e_opt ( vec_get [SessionEntry] . store entries k )
        ?? e_opt {
            T e → {
                ( string_free . e key )
                ( string_free . e value )
            }
            F → {}
        }
        = k + k 1
    }
    ( vec_free [SessionEntry] . store entries )
}
