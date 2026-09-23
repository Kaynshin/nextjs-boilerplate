#!/usr/bin/env bash
# jev-done.sh — hook Stop : Jev vérifie que la tâche est réellement terminée.
#
# Remplace un hook `type:"prompt"`, qui coûterait un vrai appel modèle à chaque
# fin de tour, par un appel Jev à deux nouls (~0,00002 $).
#
# Deux garde-fous, parce qu'un hook Stop qui boucle coûte bien plus cher que le
# problème qu'il résout :
#   1. les deux conditions doivent être réunies (tâche incomplète ET promesse non tenue) ;
#   2. une seule relance par session, comptée sur disque.

set -o pipefail
JEV_DIR="${JEV_DIR:-$HOME/.claude/jev}"
JEV_BIN="${JEV_BIN:-$HOME/.local/bin/jev}"
export JEV_TIMEOUT="${JEV_TIMEOUT:-6}"

passthrough() { exit 0; }
fge() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a+0 >= b+0)}'; }

input="$(cat)"; [ -n "$input" ] || passthrough
session="$(printf '%s' "$input"    | jq -r '.session_id // "?"' 2>/dev/null)"
transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
active="$(printf '%s' "$input"     | jq -r '.stop_hook_active // false' 2>/dev/null)"

[ "$active" = "true" ] && passthrough          # déjà relancé par un hook Stop
[ -x "$JEV_BIN" ] || passthrough
[ -n "$transcript" ] && [ -f "$transcript" ] || passthrough

# Garde-fou : une seule relance par session.
guard="$JEV_DIR/stop-$session.done"
[ -f "$guard" ] && passthrough

tail_txt="$(tail -n 300 "$transcript" 2>/dev/null | jq -r '
    select(.message.role == "user" or .message.role == "assistant")
    | ((.message.role | ascii_upcase) + ": " +
       ((.message.content // empty)
        | if type=="string" then . else (map(select(.type=="text") | .text) | join(" ")) end))
    | select(length > 12)' 2>/dev/null | tail -n 4 | tail -c 4000)"
[ -n "$tail_txt" ] || passthrough

cat > "$JEV_DIR/.done.questions.json" <<'QQ'
{
  "tache_accomplie": {
    "type": "noul",
    "instructions": "La demande de l'utilisateur a reçu une réponse complète : rien d'essentiel n'est laissé en suspens."
  },
  "promesse_non_tenue": {
    "type": "noul",
    "instructions": "La dernière réponse de l'assistant annonce une action à venir (« je vais lancer », « je vais créer », « je m'en occupe ») sans l'avoir réellement exécutée dans ce tour."
  }
}
QQ

ans="$(printf '%s' "$tail_txt" | "$JEV_BIN" ask "$JEV_DIR/.done.questions.json" 2>/dev/null)"
[ -n "$ans" ] || passthrough

done_v="$(printf '%s' "$ans" | jq -r '.tache_accomplie.noul // 1')"
prom_v="$(printf '%s' "$ans" | jq -r '.promesse_non_tenue.noul // 0')"

# Conditions cumulatives.
fge 0.3 "$done_v" || passthrough          # tache_accomplie >= 0.3 -> on laisse finir
fge "$prom_v" 0.7 || passthrough

: > "$guard"
# Stop : `hookSpecificOutput.additionalContext` relance le tour (mêmes garde-fous que
# decision:"block" — stop_hook_active et plafond de 8 relances) sans afficher d'erreur.
# `continue` n'empêche pas l'arrêt : c'est `continue:false` qui arrête tout.
jq -nc --arg m "Jev signale une action annoncée mais non exécutée (accompli=$done_v, promesse=$prom_v). Termine ce qui a été annoncé, ou dis explicitement pourquoi tu ne le fais pas." \
  '{hookSpecificOutput:{hookEventName:"Stop",additionalContext:$m}}'
exit 0
