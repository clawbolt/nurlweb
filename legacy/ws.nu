// nurlweb/ws.nu — WebSocket Integration
//
// Ergonomic WebSocket server on a separate port. stdlib websocket.nu
// is comprehensive but low-level; ws.nu provides accept-loop management
// and sensible defaults so user code is a single message handler.
//
// Design note: HttpRequest carries no TcpConn, so WebSocket upgrade
// cannot share the HTTP port. ws.nu creates its own listener on a
// different port. Nginx can proxy both ports to the same domain.
//
// API:
//   ( app_ws          s host i port handler )  → !v WsErr
//   ( ws_serve_loop   TcpConn conn handler )   → !v WsErr
//   ( ws_limits_default )                      → WsLimits
//
// Handler signature: ( @ !v WsErr WsMessage )
//   Receives each assembled text/binary message. Return !v WsErr { T 0 }
//   to continue; return !v WsErr { F ... } to close the connection.
//
// Usage:
//   ( app_ws `127.0.0.1` 3912
//       \ WsMessage msg → !v WsErr {
//           : s text ( string_data ( vec_data [u] . msg payload ) )
//           ( nurl_print text )
//           ^ @ !v WsErr { T 0 }
//       })

$ `stdlib/std/net.nu`
$ `stdlib/ext/websocket.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`

// ── Default limits ────────────────────────────────────────────────────

@ ws_limits_default → WsLimits {
    ^ ( ws_default_limits )
}

// ── Per-connection serve loop ─────────────────────────────────────────

// Thin wrapper around ws_serve_messages with default limits. The handler
// receives assembled WsMessage values (text or binary) and returns
// !v WsErr to signal continue or close.
@ ws_serve_loop TcpConn conn ( @ !v WsErr WsMessage ) handler → !v WsErr {
    : WsLimits limits ( ws_default_limits )
    ^ ( ws_serve_messages conn limits handler )
}

// ── Full WebSocket server ─────────────────────────────────────────────

// Listens on host:port, accepts connections in a loop, and runs the
// message handler for each client. Blocks the calling fiber/thread;
// each connection is handled sequentially (single-threaded).
//
// The accept loop continues until tcp_accept returns an error (listener
// closed, signal, etc.). Each connection is served to completion before
// the next connection is accepted.
//
// Handler closure captures user state by value — each connection gets
// a fresh invocation through ws_serve_messages.
@ app_ws s host i port ( @ !v WsErr WsMessage ) handler → !v WsErr {
    : ! TcpListener NetErr lr ( tcp_listen host port )
    ?? lr {
        T listener → {
            ( nurl_print `[ws] listening on ws://` )
            ( nurl_print host )
            ( nurl_print `:` )
            ( nurl_print_str ( nurl_str_int port ) )
            ( nurl_print `\n` )

            : ~ b running T
            ~ == running 1 {
                : ! TcpConn NetErr cr ( tcp_accept listener )
                ?? cr {
                    T conn → {
                        : !v WsErr rr ( ws_serve_loop conn handler )
                        ?? rr {
                            T _ → {}
                            F e → {
                                ( nurl_eprint `[ws] error: ` )
                                ( nurl_eprintln ( ws_err_name e ) )
                            }
                        }
                        ( tcp_close_conn conn )
                    }
                    F _ → { = running F }
                }
            }

            ( tcp_close_listener listener )
            ^ @ !v WsErr { T 0 }
        }
        F e → {
            ^ @ !v WsErr { F WsOther }
        }
    }
}
