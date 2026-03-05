---
name: context7
description: Fetches up-to-date library documentation from Context7. Use when needing docs for any library, framework, or package. Also use as a discovery tool when encountering unfamiliar libraries, CLIs, or tools — resolve-library-id can tell you if Context7 knows about it.
---

# Context7 Library Docs

Fetch up-to-date documentation for any library via `mcporter call context7.*`.

**Also use as a discovery tool** — when you encounter an unfamiliar library, CLI, or tool, call `resolve-library-id` first to see if Context7 has documentation for it before falling back to web search.

## Quick Reference

### 1. Resolve Library ID

Find the Context7 library ID. **Both parameters are required.**

```bash
# Standard syntax
mcporter call context7.resolve-library-id query="React hooks" libraryName=react

# Also works: parenthetical syntax
mcporter call "context7.resolve-library-id(query: \"state management\", libraryName: \"riverpod\")"
```

This returns a list of matching libraries with:
- **Library ID**: e.g., `/vercel/next.js`
- **Code Snippets**: Number of examples
- **Benchmark Score**: Quality indicator (100 = best)
- **Source Reputation**: High/Medium/Low
- **Versions**: Available versions (if any)

### 2. Query Docs

Use the library ID to fetch docs. **Be specific and descriptive with queries.**

```bash
mcporter call context7.query-docs libraryId=/vercel/next.js query="How to set up App Router middleware"

# Also works: flag syntax
mcporter call context7.query-docs --libraryId /facebook/react query="How to use useEffect cleanup function"
```

## Parameters

### resolve-library-id

| Parameter | Required | Description |
|-----------|----------|-------------|
| `query` | Yes | Descriptive question about what you're trying to accomplish |
| `libraryName` | Yes | Library name to search for |

### query-docs

| Parameter | Required | Description |
|-----------|----------|-------------|
| `libraryId` | Yes | Library ID from resolve step (e.g., `/vercel/next.js`) |
| `query` | Yes | **Be specific and descriptive.** Good: "How to set up authentication with JWT in Express.js". Bad: "auth" or "hooks" |

## Query Guidelines

**Be descriptive** — Context7 ranks results by relevance to your query:
- ✅ `query="How to invalidate a query in React Query"`
- ✅ `query="Set up server-side rendering with streaming in Next.js"`
- ❌ `query="hooks"` (too vague)
- ❌ `query="auth"` (too vague)

**Don't call more than 3 times per question** — if you can't find what you need after 3 calls, use the best result you have.

## Examples

### Discover an Unknown Library

```bash
# Someone mentions "polymarket cli" — find out if Context7 knows about it
mcporter call context7.resolve-library-id query="Polymarket CLI trading tool" libraryName=polymarket
# Returns: /polymarket/polymarket-cli (130 snippets, High reputation)

# Then fetch docs
mcporter call context7.query-docs libraryId=/polymarket/polymarket-cli query="How to place trades and manage positions"
```

### Get React Hooks Documentation

```bash
mcporter call context7.resolve-library-id query="React hooks for state management" libraryName=react
# Returns: /websites/react_dev (2796 snippets, score 93.5)

mcporter call context7.query-docs libraryId=/websites/react_dev query="How to use useEffect with cleanup and dependency array"
```

### Get Riverpod State Management Docs

```bash
mcporter call context7.resolve-library-id query="State management with providers" libraryName=riverpod
# Returns: /rrousselgit/riverpod

mcporter call context7.query-docs libraryId=/rrousselgit/riverpod query="How to create and use providers for async data"
```

### Get Next.js App Router Concepts

```bash
mcporter call context7.resolve-library-id query="App Router routing and middleware" libraryName=next.js
# Returns: /vercel/next.js

mcporter call context7.query-docs libraryId=/vercel/next.js query="How to create middleware that checks authentication"
```

### Get Version-Specific Docs

```bash
# If resolve returns versions like "riverpod-v3.0.2", use the versioned ID:
mcporter call context7.query-docs libraryId=/rrousselgit/riverpod/riverpod-v3.0.2 query="Provider lifecycle and disposal"
```

## Common Library IDs

### Frameworks & Libraries

| Library | ID | Snippets |
|---------|-----|----------|
| React | `/websites/react_dev` | 2796 |
| React (reference) | `/websites/react_dev_reference` | 2517 |
| Next.js | `/vercel/next.js` | — |
| Riverpod | `/rrousselgit/riverpod` | 375 |
| Flutter Riverpod | `/websites/pub_dev_packages_flutter_riverpod` | — |
| Supabase | `/supabase/supabase` | — |
| Tailwind CSS | `/tailwindlabs/tailwindcss` | — |
| Ruby Async | `/socketry/async` | — |

### Cloud & Infrastructure

| Vendor | ID | Notes |
|--------|-----|-------|
| Vultr | `/llmstxt/vultr_llms_txt` | Includes Terraform, K8s, API docs |
| Vultr API | `/websites/vultr_api` | Direct API reference |
| AWS | `/llmstxt/aws_documentation` | All AWS services |
| GCP | `/llmstxt/google_cloud_docs` | Google Cloud docs |
| Azure | `/websites/azure_docs` | Microsoft Azure |

Always run `resolve-library-id` first to get the exact ID unless you already know it — IDs can change as Context7 adds better sources.

## When to Use Context7

1. **Discovery**: Encounter an unfamiliar library/CLI/tool? Resolve it to see if Context7 has docs.
2. **Up-to-date docs**: Need current API docs for a fast-moving framework (Next.js, React, etc.)
3. **Version-specific**: Need docs for a specific version of a library.
4. **Code examples**: Need working code snippets from official sources.

## Important Usage Notes

### Choosing the Right libraryName

Use the **product/company name**, not necessarily the technology:

```bash
# ✅ Vultr docs include Terraform examples
mcporter call context7.resolve-library-id query="Terraform infrastructure" libraryName=vultr

# ✅ AWS docs include all AWS services
mcporter call context7.resolve-library-id query="Lambda functions" libraryName=aws

# ✅ For specific libraries, use the library name
mcporter call context7.resolve-library-id query="React server components" libraryName=react
```

### Website APIs vs Libraries

Context7 has two types of sources:
1. **Libraries** (e.g., `/facebook/react`, `/vercel/next.js`) — GitHub repos, npm packages
2. **Website docs** (e.g., `/websites/react_dev`, `/llmstxt/vultr_llms_txt`) — official documentation sites

Website docs often have higher benchmark scores and more snippets. When resolve returns multiple matches, prefer the one with higher benchmark score and more snippets.

## Troubleshooting

- **Library not found** — Try the product/company name instead of the technology name
- **Poor results** — Make your query more descriptive and specific
- **Multiple matches** — Pick the one with highest benchmark score + most snippets
- **Outdated library ID** — Always re-resolve if unsure; IDs can change
