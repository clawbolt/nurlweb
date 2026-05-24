---
review_agents: [code-simplicity-reviewer, security-sentinel, performance-oracle, architecture-strategist]
plan_review_agents: [code-simplicity-reviewer]
---

# Review Context

NurlWeb is an LLM-first web framework for the NURL programming language.
- Stack: NURL (~180 LOC app.nu + ~135 LOC ctx.nu)
- Target: standalone repo cloned into NURL projects
- Key concerns: API surface minimality, LLM ergonomics, zero stdlib forking
- No runtime — compile-time framework (NURL → LLVM IR → native binary)
