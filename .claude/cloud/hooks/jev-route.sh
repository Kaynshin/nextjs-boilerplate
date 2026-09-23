#!/usr/bin/env bash
# jev-route.sh — hook UserPromptSubmit : fait classer le prompt par Jev et
# injecte une directive de routage contraignante dans le contexte.
#
# Rappel d'architecture : aucun hook ne peut changer le modèle de la session,
# ni réécrire le prompt (UserPromptSubmit n'accepte pas `updatedInput`). Le seul
# levier est hookSpecificOutput.additionalContext, ajouté à côté du prompt. Le
# routage porte donc sur le choix du SOUS-AGENT (et, par lui, de son modèle
# épinglé), jamais sur le modèle de la fenêtre principale.
#
# Le prompt de l'utilisateur n'est jamais touché : une erreur de classification
# ne peut pas altérer sa demande.
#
# JEV_DRY_RUN=1 -> journalise le verdict sans rien injecter.

set -o pipefail
JEV_DIR="${JEV_DIR:-$HOME/.claude/jev}"
JEV_BIN="${JEV_BIN:-$HOME/.local/bin/jev}"
LOG="$JEV_DIR/route.log.jsonl"
QUESTIONS="$JEV_DIR/router.questions.json"
export JEV_TIMEOUT="${JEV_TIMEOUT:-4}"     # court : ce hook est sur le chemin critique

# Mode : "dry" (journalise seulement) ou "auto" (réécrit le prompt).
# Piloté par $JEV_DIR/MODE ; par sécurité, tout contenu inattendu vaut "dry".
MODE="$(head -n1 "$JEV_DIR/MODE" 2>/dev/null | tr -d "[:space:]")"
[ "$MODE" = "auto" ] || JEV_DRY_RUN=1

passthrough() { exit 0; }                  # ne rien émettre = prompt inchangé
fge() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a+0 >= b+0)}'; }

input="$(cat)"
[ -n "$input" ] || passthrough

prompt="$(printf '%s' "$input"     | jq -r '.prompt // empty' 2>/dev/null)"
session="$(printf '%s' "$input"    | jq -r '.session_id // "?"' 2>/dev/null)"
transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
[ -n "$prompt" ] || passthrough

# --- exclusions : on ne route jamais ces cas ------------------------------
case "$prompt" in
  /*)               passthrough ;;          # commande slash, déjà explicite
  *"<jev-route"*)   passthrough ;;          # déjà routé, pas de double préfixe
  "<task-notification>"*) passthrough ;;    # notification de tâche, pas une demande
  "<local-command"*)      passthrough ;;    # sortie de commande locale
  "<command-name>"*)      passthrough ;;    # expansion de commande slash
esac
[ "${#prompt}" -lt 8 ] && passthrough       # "ok", "continue", "oui"...
[ -x "$JEV_BIN" ] || passthrough
[ -f "$QUESTIONS" ] || passthrough

# --- état : les 2 derniers échanges + le prompt courant -------------------
history=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  history="$(tail -n 400 "$transcript" 2>/dev/null | jq -r '
      select(.message.role == "user" or .message.role == "assistant")
      | (.message.content // empty)
      | if type=="string" then .
        else (map(select(.type=="text") | .text) | join(" ")) end
      | select(length > 0)' 2>/dev/null \
    | tail -n 4 | cut -c1-1200 | tail -c 3000)"
fi

state="$(printf 'HISTORIQUE RÉCENT (contexte seulement) :\n%s\n\n=== DERNIER MESSAGE DE LUTILISATEUR, À CLASSER ===\n%s\n' \
         "${history:-<aucun, début de session>}" "$prompt")"

answers="$(printf '%s' "$state" | "$JEV_BIN" ask "$QUESTIONS" 2>/dev/null)"
[ -n "$answers" ] || passthrough
printf '%s' "$answers" | jq -e '.tier.choice' >/dev/null 2>&1 || passthrough

tier="$(printf   '%s' "$answers" | jq -r '.tier.choice')"
conf="$(printf   '%s' "$answers" | jq -r '.tier.confidence // 0')"
ctx="$(printf    '%s' "$answers" | jq -r '.besoin_contexte.score // 0')"
intent="$(printf '%s' "$answers" | jq -r '.intention.choice // "?"')"
intentc="$(printf '%s' "$answers" | jq -r '.intention.confidence // 0')"
suite="$(printf  '%s' "$answers" | jq -r '.est_suite.noul // 0')"
nat="$(printf    '%s' "$answers" | jq -r '.nature_complexe.choice // ""')"
natc="$(printf   '%s' "$answers" | jq -r '.nature_complexe.confidence // 0')"
risk="$(printf   '%s' "$answers" | jq -r '.risque.noul // 0')"
crit="$(printf   '%s' "$answers" | jq -r '.criticite.noul // 0')"

# --- table de décision ----------------------------------------------------
# Posture : déléguer par défaut. Deux exceptions seulement, chacune justifiée par
# le fait que déléguer y coûterait PLUS cher que d'exécuter en session.
model=""; mode=""; reason=""
if printf '%s' "$prompt" | grep -qiE '(avec|demande à|demander à|confie à|confier à|par) fable\b'; then
  # Fable n'est jamais choisi par défaut : seulement quand l'utilisateur le nomme.
  mode="delegate"; model="second-avis"; reason="Fable demandé explicitement"
elif fge "$suite" 0.7; then
  # Continuation : un agent froid redécouvrirait le contexte déjà établi —
  # il relirait les mêmes fichiers. C'est l'inverse de l'économie recherchée.
  reason="continuation de tâche ($suite)"

elif [ "$tier" = "complexe" ] && fge "$conf" 0.50 && fge "$crit" 0.60; then
  # Chemin critique : planifier avant d'exécuter, puis orchestrer le découpage.
  mode="chain"; model="planification->orchestration"; reason="chemin critique ($crit)"

elif fge "$risk" 0.6; then
  if [ "$tier" = "complexe" ] && fge "$conf" 0.50; then
    # Destructif mais ramifié : la chaîne est plus sûre que l'exécution directe,
    # son étape 1 ne touche à rien et le plan passe sous tes yeux.
    mode="chain"; model="planification->orchestration"; reason="destructif et ramifié ($risk)"
  else
    # Destructif et simple (force push, suppression) : ta confirmation prime.
    reason="action destructrice ($risk)"
  fi

elif [ "$tier" = "trivial" ] && fge "$conf" 0.50; then
  # Réponse factuelle : aucun outil à lancer, déléguer n'ajouterait que de la latence.
  mode="direct"

else
  mode="delegate"
  case "$tier" in
    mecanique)
      case "$intent" in
        recherche)            model="recherche" ;;
        debug|analyse_sortie) model="logs" ;;
        *) model="mecanique" ;;  # Haiku refuse s'il faut arbitrer ; la session reprend
      esac ;;
    standard)
      case "$intent" in
        recherche)            model="recherche" ;;
        debug|analyse_sortie) model="logs" ;;
        conception)           model="planification" ;;
        *)                    model="dev" ;;
      esac ;;
    complexe)
      case "$nat" in
        reflexion)
          case "$intent" in
            conception|question) model="planification" ;;
            *) model="orchestration"; reason="réflexion mais intention=$intent" ;;
          esac ;;
        execution) model="dev" ;;
        *)         model="orchestration" ;;
      esac ;;
    *)
      # Palier incertain : on délègue quand même. Une intention nette désigne
      # l'agent ; sinon orchestration, qui sait découper et redispatcher.
      case "$intent" in
        recherche)            model="recherche" ;;
        debug|analyse_sortie) model="logs" ;;
        conception)           model="planification" ;;
        edition_code)         model="dev" ;;
        *)                    model="orchestration" ;;
      esac
      reason="palier incertain ($conf) -> routé sur l intention" ;;
  esac
fi

# Modèle épinglé par l'agent choisi (frontmatter `model:`), pour l'afficher dans la
# directive et le journal. Le sous-agent l'applique de lui-même : on ne le passe jamais.
agent_model() {
  local f
  for f in "${CLAUDE_PROJECT_DIR:+$CLAUDE_PROJECT_DIR/.claude/agents/$1.md}" "$HOME/.claude/agents/$1.md"; do
    [ -n "$f" ] && [ -f "$f" ] || continue
    awk '/^model:/{print $2; exit}' "$f" 2>/dev/null
    return
  done
  echo "?"
}
sub_model=""
case "$mode" in
  chain)    sub_model="$(agent_model planification)->$(agent_model orchestration)" ;;
  delegate) sub_model="$(agent_model "$model")" ;;
esac

ts="$(date -Iseconds)"
jq -nc --arg ts "$ts" --arg s "$session" --arg t "$tier" --arg c "$conf" \
       --arg i "$intent" --arg x "$ctx" --arg su "$suite" --arg r "$risk" \
       --arg cr "$crit" \
       --arg m "$mode" --arg mo "$model" --arg sm "$sub_model" --arg rs "$reason" \
       --arg dry "${JEV_DRY_RUN:-0}" --arg p "$(printf '%s' "$prompt" | cut -c1-160)" \
  '{ts:$ts,session:$s,tier:$t,confidence:($c|tonumber? // 0),intention:$i,
    besoin_contexte:($x|tonumber? // 0),est_suite:($su|tonumber? // 0),
    risque:($r|tonumber? // 0),criticite:($cr|tonumber? // 0),
    mode:$m,agent:$mo,agent_model:$sm,raison:$rs,dry_run:($dry=="1"),
    prompt:$p}' >> "$LOG" 2>/dev/null

[ "${JEV_DRY_RUN:-0}" = "1" ] && passthrough
[ -n "$mode" ] || passthrough

# Addendum "périmètre large" : inutile sur la chaîne critique, dont l'étape 1
# (planification) fait sa propre lecture du code avant d'arbitrer.
explore=""
if [ "$mode" != "chain" ] && [ "$ctx" != "0" ] && fge "$ctx" 1.6; then
  explore=$'\n- Le périmètre est large : fais d\'abord localiser les fichiers par Agent(subagent_type:"recherche"), ne lis rien à l\'aveugle.'
fi

head_line="DIRECTIVE DE ROUTAGE (contraignante — voir la section « Routage Jev » des instructions globales)."
if [ "$mode" = "chain" ]; then
  directive="$head_line
Chemin critique détecté : ne pas exécuter directement. Procéder en deux temps.
1. Déléguer à Agent(subagent_type:\"planification\") [modèle $(agent_model planification)] pour obtenir un plan :
   étapes ordonnées, chacune avec un critère d'acceptation vérifiable, et les risques identifiés.
2. Passer ce plan INTÉGRAL à Agent(subagent_type:\"orchestration\") [modèle $(agent_model orchestration)], qui découpe
   en petites tâches et les fait exécuter par les agents adaptés.
Soumettre le plan à l'utilisateur avant l'étape 2 s'il engage des choix irréversibles.
Ces agents épinglent leur modèle : ne pas passer de paramètre model.$explore"
elif [ "$mode" = "direct" ]; then
  directive="$head_line
Pas de sous-agent. Réponds directement : n'ouvre aucun fichier, ne lance aucune recherche.
Jev classe cette demande comme triviale avec une confiance de $conf."
else
  directive="$head_line
Délègue cette demande à Agent(subagent_type:\"$model\") [modèle $sub_model] en un seul appel, sans
exploration préalable en session. L'agent épingle son modèle : ne passe pas de paramètre model.
Transmets-lui la demande de l'utilisateur intégralement (il ne voit pas la conversation), puis
vérifie et restitue son résultat.$explore"
fi

context="$(printf '<jev-route tier="%s" conf="%s" intention="%s" agent="%s" model="%s">\n%s\n</jev-route>' \
            "$tier" "$conf" "$intent" "${model:-aucun}" "${sub_model:-session}" "$directive")"

# UserPromptSubmit n'accepte que additionalContext (pas de réécriture du prompt).
jq -nc --arg c "$context" \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}}'
exit 0
