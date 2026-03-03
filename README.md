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

**Kimi K2.5** via Fireworks — Moonshot AI's flagship agentic model. 262k context, vision support, reasoning mode, $0.60/M input tokens. Outperforms most closed-source models on coding and agent benchmarks.

### All available models

| Model | Type | Context | Vision | Best for |
|-------|------|---------|--------|----------|
| **Kimi K2.5** (default) | Reasoning | 262k | ✅ | Coding, agents, complex tasks |
| DeepSeek V3.1 | Chat | 131k | ❌ | Fast general coding |
| DeepSeek V3.2 | Reasoning | 131k | ❌ | Multi-step problems |
| Kimi K2 | Chat | 131k | ❌ | Lightweight alternative |
| Qwen 2.5 VL 32B | Vision | 131k | ✅ | Image + code tasks |

Switch models anytime: `pi --model deepseek-v3p2 "solve this"` or cycle with `Ctrl+P`.

### Skills

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
├── models.json       # Fireworks provider with 5 models
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
  "defaultModel": "accounts/fireworks/models/kimi-k2p5"
}
```

**Add more models** — edit `models.json` and add entries to the `models` array.

**Add skills** — drop a folder with a `SKILL.md` into `skills/` and re-run `./setup.sh`.
