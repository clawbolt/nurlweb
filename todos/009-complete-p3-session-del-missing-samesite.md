---
status: complete
priority: p3
tags: [code-review, security]
agent: security-sentinel
file: session.nu:31-36
---

# session_del Missing Explicit SameSite

## Finding
`session_set` explicitly sets `SameSite=Lax`, but `session_del` does not set SameSite — it relies on `cookie_opts_default` which may or may not default to Lax.

## Location
- `session.nu:28` — session_set: `= . opts same_site @ SameSite { SameSiteLax }`
- `session.nu:31-36` — session_del: no SameSite set

## Impact
- If stdlib defaults change, session_del cookies might have different SameSite than session_set
- Browsers may reject deletion if SameSite doesn't match the original cookie's value
- Low severity — most browsers are lenient with deletion cookies

## Recommendation
Add explicit SameSite to session_del to match session_set:

```nurl
@ session_del Ctx ctx HttpResponse r s name → v {
    : CookieOpts opts ( cookie_opts_default )
    = . opts path `/`
    = . opts max_age 0
    = . opts secure T
    = . opts http_only T
    = . opts same_site @ SameSite { SameSiteLax }  // add this
    ( response_set_cookie r name `` opts )
}
```
