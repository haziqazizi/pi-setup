# Global Agent Instructions

## Python
- Always use `uv` instead of `pip`, `python`, or `venv` for Python tasks.
- Run scripts with `uv run script.py`, add deps with `uv add`, manage envs with `uv venv`.
- For standalone scripts, use inline script metadata (`# /// script` blocks).

## Shell
- When using `rg` (ripgrep), always search from the current working directory (`.`) explicitly.
