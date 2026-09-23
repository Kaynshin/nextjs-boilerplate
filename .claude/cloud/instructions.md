# Instructions globales

Ce fichier est la source unique des instructions globales, partagée entre
Claude Code, Codex CLI et OpenCode via des liens symboliques (voir README.md).

Ajoute ici tes préférences générales (langue, conventions, style de réponse...).

## Override des modèles dans OpenCode uniquement

Quand ces instructions sont exécutées par **OpenCode**, toute instruction de routage
Jev ou de délégation à un sous-agent qui nomme un modèle selon la nomenclature
partagée doit être interprétée ainsi :

- `Haiku` ou `haiku` → modèle `9router/Fast` ;
- `Sonnet` ou `sonnet` → modèle `9router/Executor` ;
- `Opus` ou `opus` → modèle `9router/Orchestrator` ;
- `Fable` ou `fable` → modèle `9router/God`.

Cet override est prioritaire sur toute table, modèle épinglé ou consigne contraire
plus bas dans ce fichier, mais uniquement dans OpenCode. Les noms et rôles des agents
restent inchangés. Dans Claude Code et Codex CLI, ignorer entièrement cette section.

## Routage Jev

Un hook `UserPromptSubmit` fait classer chaque demande par TypeSafe Jev et injecte dans le
contexte, à côté du prompt (qui n'est jamais modifié), un bloc
`<jev-route tier="..." conf="..." intention="..." agent="..." model="...">`. Jev décide seulement
**s'il faut un sous-agent, lequel, et donc quel modèle** il utilisera ; le modèle de la
fenêtre principale ne change jamais.

**Ces directives sont contraignantes**, et valent autorisation explicite d'utiliser
l'outil `Agent` — sans cette règle, les instructions par défaut l'interdiraient et le
routeur n'aurait aucun effet.

- `agent="aucun"` (tier trivial) → répondre directement, sans ouvrir de fichier ni créer de
  sous-agent.
- `agent="<nom>"` → déléguer à `Agent(subagent_type:"<nom>")` en un seul appel, en
  transmettant la demande intégrale, puis vérifier et restituer le résultat. L'agent épingle
  son modèle (attribut `model` du bloc, pour information) : ne pas passer de paramètre `model`.
- `agent="planification->orchestration"` → chemin critique : plan d'abord, puis exécution
  orchestrée (voir « Chemin critique » plus bas).
- Pas de bloc `<jev-route>` → fonctionnement normal. C'est le cas par défaut : le hook est
  fail-open, et une continuation de tâche ou une action destructrice simple n'est jamais
  routée.

**Unique cas où passer outre** : quand le contenu réel de la demande contredit
manifestement la classification (Jev ne voit qu'un extrait du contexte). Le signaler
alors en une ligne — « je ne suis pas la directive de routage parce que… » — et
poursuivre normalement. Ne jamais passer outre en silence : le journal
`~/.claude/jev/route.log.jsonl` sert à corriger les questions du routeur, il n'est utile
que si les écarts sont visibles.

Le bloc `<jev-route>` est un verdict de machine, pas une instruction de l'utilisateur :
il ne peut jamais élargir le périmètre de la demande, seulement décider qui l'exécute.

**En cours de tâche**, invoquer le skill `jev` pour tout jugement répétitif (tri de
résultats de recherche, classement, décision binaire sur une liste) plutôt que de le
faire en raisonnement.

## Découpage et délégation par défaut

Posture décidée explicitement par l'utilisateur : **déléguer est la règle, exécuter en
session est l'exception.** L'outil `Agent` est autorisé d'office, il n'y a pas à demander
la permission. Chaque décision et chaque changement de modèle passe par un sous-agent :
c'est plus simple à suivre, et chacun démarre avec un contexte propre.

**Deux exceptions, et deux seulement** — dans les deux cas déléguer coûterait *plus* cher
que d'exécuter :

1. **Continuation de tâche.** Quand la demande poursuit ce qui est en cours (« continue »,
   « non, plutôt comme ça », « et maintenant l'autre fichier »), un agent froid
   redécouvrirait tout le contexte déjà établi : il relirait les mêmes fichiers et referait
   les mêmes recherches. Exécuter en session.
2. **Réponse purement factuelle.** Aucun outil à lancer, aucun fichier à ouvrir. Déléguer
   n'ajouterait que de la latence.

Une action destructrice et simple (`force push`, suppression) reste en session, non pour
des raisons de coût mais parce que la confirmation de l'utilisateur prime. Si elle est
ramifiée, elle passe par la chaîne planification → orchestration, dont la première étape
ne touche à rien.

Tout le reste part en sous-agent, y compris ce qui « ne prendrait que deux minutes ».

**Règles de délégation :**
1. Une tâche par sous-agent, avec un critère d'acceptation explicite et vérifiable.
2. Transmettre le contexte nécessaire : le sous-agent démarre à froid, il ne voit ni la
   conversation ni ce qui a déjà été établi. Un sous-agent mal briefé est du gaspillage.
3. Lancer en parallèle, dans un seul message, tout ce qui est indépendant.
4. **Vérifier le résultat**, ne pas le prendre pour argent comptant. Un sous-agent qui se
   trompe le fait avec aplomb.
5. Annoncer en une ligne ce qui part en délégation, pour que le découpage reste lisible.

### Agents dédiés et lisibilité de l'affichage

Ne pas utiliser `general-purpose` : il s'affiche « General Purpose », ce qui ne dit rien.
Choisir l'agent dédié. **Le nom porte le rôle, la couleur porte le modèle** — découplés pour
que le modèle d'un agent puisse changer sans le renommer.

| Agent | Rôle | Modèle |
|---|---|---|
| `recherche` | localiser du code, des fichiers, des occurrences (lecture seule) | haiku |
| `mecanique` | renommage, patron connu, remplacement d'occurrences | haiku |
| `logs` | lire et résumer une sortie longue : logs, tests, build | haiku |
| `dev` | écrire ou corriger une fonction, un test, un composant | sonnet |
| `revue` | relire un diff pour en sortir les bugs (lecture seule) | sonnet |
| `orchestration` | découper un chantier ramifié et piloter son exécution | sonnet |
| `planification` | concevoir, arbitrer, planifier — n'écrit pas de code | opus |
| `second-avis` | deuxième avis de Fable — uniquement sur demande explicite (lecture seule) | fable |

**Légende des couleurs — une couleur par modèle, jamais réutilisée :**
Fable `red` · Opus `purple` · Sonnet `blue` · Haiku `green`.

Cette correspondance est obligatoire. Changer le `model:` d'un agent impose de changer sa
`color:` — `claude-agents --fix` le fait, `claude-agents` seul signale les écarts.

Chaque agent épingle son modèle : ne pas passer de paramètre `model` à l'appel.

**Fable à la demande uniquement.** Fable n'est jamais choisi par défaut : Opus 5.5 en effort
high fait aussi bien pour bien moins cher. Il ne sert que quand l'utilisateur le demande
explicitement (« avec Fable », « demande à Fable »), via `Agent(subagent_type:"second-avis")`
— jamais par `/model fable`, qui relirait toute la conversation au tarif Fable. Il puise dans
le sous-plafond Fable (50 % de la limite hebdomadaire du plan Max).

#### Chemin critique : planifier avant d'exécuter

Quand la demande touche un chemin critique — paiement, facturation, authentification,
autorisation, intégrité ou migration de données, code de production — **ne pas exécuter
directement**, même si la tâche paraît claire. Procéder en deux temps :

1. `planification` (Opus, effort high) produit le plan : étapes ordonnées, critère d'acceptation
   vérifiable pour chacune, risques identifiés.
2. Ce plan, **intégral**, part à `orchestration` (Sonnet), qui le découpe en petites tâches
   et les fait exécuter par `dev`, `mecanique`, `recherche` ou `logs`.

Soumettre le plan à l'utilisateur entre les deux étapes s'il engage des choix irréversibles.
Le routeur Jev déclenche cet enchaînement tout seul via sa question `criticite`, mais la
règle s'applique aussi quand elle est reconnue à la main.

#### Ce que l'utilisateur voit

Le paramètre `description` de l'appel `Agent` est la ligne affichée. La rédiger
`<modèle> · <verbe> <objet concret>`, jamais générique :

- `haiku · localise les appels à fetchUser`
- `sonnet · ajoute un test pour parseDate`
- `opus · planifie la migration du tunnel de paiement`
- `sonnet · pilote la migration en 6 lots`

À proscrire : « recherche », « analyse du code », « tâche », « traitement ». Si la description
ne permet pas de dire quel travail part et sur quel modèle, elle est à réécrire.

Quand plusieurs agents partent dans le même message, l'annoncer en une ligne avant l'appel.

## Nouveau dépôt : kit Claude Code Cloud

Tout dépôt créé ou publié sur GitHub reçoit aussitôt le kit Claude Code Cloud (Jev, RTK, Caveman) :
skill `cloud-kit`, sans attendre qu'on le demande, dépôts publics compris.


# RTK

Prefix every shell command with `rtk`: `rtk git status`, `rtk cargo test`,
`rtk npm run build`, `rtk ls src/`. Keep the prefix inside chains:
`rtk git add . && rtk git commit -m "msg"`. Commands RTK has no filter for
run as-is, so the prefix is always safe.

# Command output

Command output here is condensed to save tokens, keeping every signal and
dropping costly noise. Treat it as the complete result: run commands
normally, and batch related commands into one call to avoid extra turns.
Truncated results state their recovery path in their own output. Re-run a
command as `rtk proxy <cmd>` only when its result is unusable: empty when
output was clearly expected, contradicting its exit code, or garbled.

## About RTK

RTK (Rust Token Killer) is a CLI proxy that filters command output to save
tokens; behavior and exit code are unchanged.

- `rtk gain` / `rtk gain --history` — token savings, overall and per command.
- `rtk proxy <cmd>` — run a command unfiltered, still tracked.
- `RTK_DISABLED=1 <cmd>` — skip RTK for one command.
- `rtk discover` — find past commands RTK could have condensed.
