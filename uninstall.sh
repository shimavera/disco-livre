#!/bin/zsh
# Remove o disco-livre (ferramenta, skill e vigilância). Não mexe em nada que ele limpou.
"$HOME/.local/bin/disco-livre" desativar 2>/dev/null
launchctl bootout "gui/$UID/com.disco-livre.app" 2>/dev/null
launchctl disable "gui/$UID/com.disco-livre.app" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/com.disco-livre.app.plist"
pkill -x DiscoLivre 2>/dev/null
rm -rf "/Applications/Disco Livre.app" "$HOME/Applications/Disco Livre.app"
rm -f "$HOME/.local/bin/disco-livre"
rm -rf "$HOME/.claude/skills/disco-livre" "$HOME/.codex/skills/disco-livre" "$HOME/.config/disco-livre"
print -r -- "✓ disco-livre removido. (O histórico fica em ~/Library/Logs/disco-livre.log)"
