#!/bin/bash
set -e

echo "🥧 Setting up Pi coding agent..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Install Pi
if ! command -v pi &>/dev/null; then
  echo "📦 Installing Pi..."
  npm install -g @mariozechner/pi-coding-agent
fi

# 2. Install mcporter (needed by context7 and other MCP-based skills)
if ! command -v mcporter &>/dev/null; then
  echo "📦 Installing mcporter..."
  npm install -g mcporter
fi

# 3. Copy config
echo "⚙️  Copying config..."
mkdir -p ~/.pi/agent
cp -n "$SCRIPT_DIR/settings.json" ~/.pi/agent/settings.json 2>/dev/null || true
cp -n "$SCRIPT_DIR/models.json" ~/.pi/agent/models.json 2>/dev/null || true
cp -n "$SCRIPT_DIR/AGENTS.md" ~/.pi/agent/AGENTS.md 2>/dev/null || true

# 4. Install packages
echo "📦 Installing packages..."
pi install npm:mitsupi

# 5. Install skills to ~/.agents/skills/
echo "🧠 Installing skills..."
mkdir -p ~/.agents/skills
for skill_dir in "$SCRIPT_DIR"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  target="$HOME/.agents/skills/$skill_name"
  if [ -d "$target" ]; then
    echo "  $skill_name: already exists, skipping"
  else
    cp -r "$skill_dir" "$target"
    echo "  $skill_name: installed"
  fi
done

echo ""
echo "✅ Done!"
echo ""
echo "Next steps:"
echo "  1. Set your API key:  export ANTHROPIC_API_KEY=your-key"
echo "  2. Run: pi"
