---
status: complete
priority: p2
tags: [code-review, simplicity, architecture]
agent: code-simplicity-reviewer
---

# P2: Ctx as dead parameter in respond.nu delegation chain

## Finding
Every `ctx_*` response function takes `Ctx c` but drops it immediately:

```nurl
@ ctx_text Ctx c i status s body → HttpResponse {
    ^ ( respond_text status body )  // c is never used
}
```

The comment says "passed through for API consistency only." This trains LLMs to pass context where it's irrelevant.

## Recommendation
Either: (A) Remove Ctx from these signatures and use standalone respond.nu, or (B) Find a real use for Ctx (e.g., auto-logging the response).
