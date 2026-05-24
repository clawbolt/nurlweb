// nurlweb/test_ws.nu — Compile-time unit tests for ws.nu
//
// Run: ./build/nurlc nurlweb/test_ws.nu
// Expected: exit 0

$ `nurlweb/ws.nu`

// ── Test: ws_limits_default ───────────────────────────────────────────

@ test_ws_limits_default → WsLimits {
    ^ ( ws_limits_default )
}

// ── Test: ws_serve_loop type signature ────────────────────────────────

@ test_ws_serve_loop TcpConn conn → !v WsErr {
    ^ ( ws_serve_loop conn
        \ WsMessage msg → !v WsErr {
            ^ @ !v WsErr { T 0 }
        })
}

// ── Test: handler receives WsMessage and can access fields ────────────

@ test_ws_handler → ( @ !v WsErr WsMessage ) {
    ^ \ WsMessage msg → !v WsErr {
        : i op . msg opcode
        : i plen ( vec_len [u] . msg payload )
        ? == op 1 {
            : *u data ( vec_data [u] . msg payload )
            ^ @ !v WsErr { T 0 }
        } {
            ^ @ !v WsErr { T 0 }
        }
    }
}

// ── Test: ws_serve_loop with text handler ─────────────────────────────

@ test_ws_serve_loop_text TcpConn conn → !v WsErr {
    ^ ( ws_serve_loop conn
        \ WsMessage msg → !v WsErr {
            : i op . msg opcode
            : *u data ( vec_data [u] . msg payload )
            : i n ( vec_len [u] . msg payload )
            ? > n 0 {
                : String s ( string_from_bytes data n )
                ( string_free s )
            } {}
            ^ @ !v WsErr { T 0 }
        })
}

// ── Main ──────────────────────────────────────────────────────────────

@ main → i { ^ 0 }
