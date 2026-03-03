#!/bin/bash
set -e

echo "🥧 Setting up Pi coding agent..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Install Pi
if ! command -v pi &>/dev/null; then
  echo "📦 Installing Pi..."
  npm install -g @mariozechner/pi-coding-agent
fi

# 2. Copy config
echo "⚙️  Copying config..."
mkdir -p ~/.pi/agent
cp -n "$SCRIPT_DIR/settings.json" ~/.pi/agent/settings.json 2>/dev/null || true
cp -n "$SCRIPT_DIR/models.json" ~/.pi/agent/models.json 2>/dev/null || true

# 3. Install packages
echo "📦 Installing packages..."
pi install npm:mitsupi

# 4. Install skills
echo "🧠 Installing skills..."
for skill_dir in "$SCRIPT_DIR"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  pi install "$skill_dir" 2>/dev/null || echo "  Skill $skill_name: copy manually to ~/.pi/skills/$skill_name"
done

echo ""
echo "✅ Done!"
echo ""
echo "Next steps:"
echo "  1. Set your API key:  export FIREWORKS_API_KEY=your-key"
echo "  2. Run: pi"
