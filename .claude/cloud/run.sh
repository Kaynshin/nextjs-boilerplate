#!/usr/bin/env bash
# Point d'entrée des hooks du kit cloud. Inerte hors de Claude Code Cloud :
# en local, ~/.claude fait déjà le même travail.
[ "$CLAUDE_CODE_REMOTE" = "true" ] || exit 0
K="$(cd "$(dirname "$0")" && pwd)"
export JEV_BIN="$K/bin/jev" JEV_DIR="$HOME/.claude/jev"
# La vraie clé est ajoutée par le proxy (API credential sur api.typesafe.ai) ;
# jev exige seulement que la variable soit non vide.
export TYPESAFE_API_KEY="${TYPESAFE_API_KEY:-proxy}"

case "$1" in
  start)
    mkdir -p "$JEV_DIR/cache" && cp "$K"/jev/* "$JEV_DIR/"   # jev ne crée pas cache/ lui-même
    # jev et jev-rank utilisables depuis Bash et depuis le skill jev
    [ -n "$CLAUDE_ENV_FILE" ] && printf 'export PATH="%s:$PATH" JEV_DIR="%s" TYPESAFE_API_KEY="%s"\n' \
      "$K/bin" "$JEV_DIR" "$TYPESAFE_API_KEY" >> "$CLAUDE_ENV_FILE"
    # Consignes globales injectées seulement dans le cloud (pas de doublon avec ~/.claude/CLAUDE.md en local)
    cat "$K/instructions.md"
    # Caveman actif d'office, niveau lite (même hook qu'en local) ; corps du skill sans son en-tête YAML
    printf '\nCAVEMAN MODE ACTIVE — level: lite. Switch: /caveman full|ultra|off\n\n'
    awk 'f>=2; /^---$/{f++}' "$K/../skills/caveman/SKILL.md" ;;
  rtk)
    command -v rtk >/dev/null || exit 0
    exec rtk hook claude ;;
  *)
    exec bash "$K/hooks/$1.sh" ;;
esac
exit 0
