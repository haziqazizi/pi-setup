# pi-setup

My [Pi coding agent](https://github.com/badlogicgames/pi) configuration — models, skills, and extensions.

```bash
git clone https://github.com/haziqazizi/pi-setup.git
cd pi-setup
./setup.sh
```

Then set your [Fireworks AI](https://fireworks.ai) API key and start coding:

```bash
export FIREWORKS_API_KEY=your-key
pi
```

---

## What's included

### Default model

**MiniMax M2.5** via Fireworks — 196k context, 255 t/s output speed (5x faster than MiniMax direct), $0.30/M input tokens, $1.20/M output tokens. Scores 80.2% on SWE-Bench Verified — nearly identical to Claude Opus 4.6 (80.8%) at a fraction of the cost.

### All available models

| Model | Type | Context | Vision | Best for |
|-------|------|---------|--------|----------|
| **MiniMax M2.5** (default) | Chat | 196k | ❌ | Daily coding, fast + cheap |
| Kimi K2.5 | Reasoning | 262k | ✅ | Complex tasks, agents |
| DeepSeek V3.1 | Chat | 131k | ❌ | Fast general coding |
| DeepSeek V3.2 | Reasoning | 131k | ❌ | Multi-step problems |
| Kimi K2 | Chat | 131k | ❌ | Lightweight alternative |
| Qwen 2.5 VL 32B | Vision | 131k | ✅ | Image + code tasks |

Switch models anytime: `pi --model kimi-k2p5 "solve this"` or cycle with `Ctrl+P`.

---

## Prompt caching with Fireworks

This config includes **`x-session-affinity: !uuidgen`** in the Fireworks provider headers, which enables automatic prompt caching per Pi session.

### How it works

- Fireworks caches the KV (key-value) matrices from your prompt prefix on the GPU replica
- `x-session-affinity` pins all requests in a Pi session to the **same replica**, so the cache stays warm
- `!uuidgen` generates a unique ID per Pi process — each session gets its own affinity key
- Multiple concurrent Pi sessions don't compete for cache space

### What gets cached

Your system prompt + tool definitions + code context form a **stable prefix** that stays identical across turns. Fireworks caches this prefix and only processes the new tokens (conversation history + latest message) on each turn.

Typical cache hit rate: **~90%** of the prefix (verified with `fireworks-cached-prompt-tokens` response header).

### Cost impact

| | Input | Cached input | Output |
|---|---|---|---|
| Fireworks (MiniMax M2.5) | $0.30/M | **$0.03/M** (90% off) | $1.20/M |

Caching saves ~35% on input costs. Combined with MiniMax's already low base price:

| Scenario | MiniMax/Fireworks | Claude Max 5x | Claude Max 20x |
|---|---|---|---|
| 8hr daily, 30 days/mo | **~$18/mo** | $100/mo | $200/mo |
| Extreme (20 turns/hr) | **~$39/mo** | $100/mo | $200/mo |
| Session caps | **None** | 50/mo | 50/mo |
| Throttling | **Never** | 5hr windows | 5hr windows |

Even without caching, MiniMax on Fireworks is ~$28/mo for heavy daily use — the low base token price is the main cost driver, caching is a bonus.

---

## Skills

Four architecture skills for Rails and Flutter development:

| Skill | Lines | What it covers |
|-------|-------|----------------|
| **rails-api** | 523 | Layered architecture (Filter → Query → Resource), SQL JSON aggregation, Alba serialization, async Falcon, ActiveRecord performance |
| **rails-fullstack** | 334 | View components, presenters, form objects, Turbo/Hotwire patterns |
| **rspec-testing** | 110 | Three-layer testing strategy, flaky test prevention, factory best practices |
| **flutter-arch** | 372 | Services → Repositories → ValueNotifiers, Result pattern, contract testing, cursor pagination, isolate parsing |

### Packages

- **[mitsupi](https://github.com/mitsuhiko/agent-stuff)** — Armin Ronacher's Pi commands, skills, and extensions

---

## Files

```
pi-setup/
├── settings.json     # Default provider + model + packages
├── models.json       # Fireworks provider with 6 models + caching headers
├── setup.sh          # Install Pi, copy config, install skills
├── skills/
│   ├── rails-api/
│   ├── rails-fullstack/
│   ├── rspec-testing/
│   └── flutter-arch/
└── README.md
```

## Customizing

**Change default model** — edit `settings.json`:
```json
{
  "defaultProvider": "fireworks",
  "defaultModel": "accounts/fireworks/models/minimax-m2p5"
}
```

**Add more models** — edit `models.json` and add entries to the `models` array.

**Add skills** — drop a folder with a `SKILL.md` into `skills/` and re-run `./setup.sh`.

**Disable caching** — remove the `headers` block from `models.json` (not recommended).
