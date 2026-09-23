---
name: jev
description: Déporter vers TypeSafe Jev le travail de jugement répétitif — trier, classer, filtrer, décider en oui/non — au lieu de le faire soi-même en raisonnement. Déclenche quand une recherche (Grep, Glob, find, git log) renvoie plus de 15 résultats et qu'il faut choisir lesquels lire ; quand il faut arbitrer entre au moins 3 fichiers à ouvrir ; quand la même question binaire revient sur une liste d'éléments (« ce test est-il instable ? », « ce fichier est-il concerné ? », « ce diff touche-t-il à la sécurité ? ») ; quand il faut classer ou prioriser des tickets, des erreurs de logs, des TODO, des passages de documentation. Ne déclenche JAMAIS pour écrire du code, expliquer, résumer ou rédiger.
---

# jev — jugement structuré à 0,042 $/M tokens

Jev n'est pas un LLM génératif. Il prend un **état** et des **questions typées**, et
renvoie des réponses structurées avec une probabilité et une `confidence`. Entrée
facturée 0,042 $/M, **sortie gratuite**, et sur une facturation TypeSafe séparée : rien
de ce qui passe par Jev ne consomme le plan Max.

L'usage correct est de remplacer un **tour de raisonnement** par un appel. Si je lis 40
résultats de `grep` pour en retenir 3, j'ai payé 40 résultats en contexte Opus pour un
travail que Jev fait pour une fraction de centime.

## Les trois primitives

| Primitive | Question posée | Retour |
|---|---|---|
| `Noul` | une affirmation est-elle vraie ? | `0.0`–`1.0` |
| `Choice` | laquelle de ces options ? (≤ 255) | option + probabilités + `confidence` |
| `Score` | où sur cette échelle ? (2 à 10 niveaux) | score + `confidence` |

## Commandes

```bash
# Oui/non, sur un état passé en stdin
git diff | jev noul "Ce diff modifie la gestion de l'authentification ou des secrets."

# Choisir parmi des options
cat erreur.log | jev choice "Quelle est la cause première ?" reseau config permissions dependance
# -> config<TAB>0.87

# Noter sur une rubrique
cat rapport.md | jev score "Niveau de finition" "brouillon" "relisible" "publiable"
# -> 1.0<TAB>0.72

# Re-classer une liste (UN seul appel pour tous les candidats)
grep -rn "token" src/ | jev-rank --goal "trouver où le token est validé" --top 5
rg --files src/ | jev-rank --goal "fichiers de configuration du build" --top 8 --scores

# Plusieurs questions en un appel (pattern fan-out recommandé par TypeSafe)
cat ticket.txt | jev ask mes-questions.json
```

## Règles d'emploi

**Poser des questions atomiques.** « Ce fichier concerne-t-il l'authentification ? » se
répond de façon fiable ; « analyse ce fichier » n'est pas une question pour Jev. Un
problème complexe se découpe en plusieurs questions indépendantes, recomposées ensuite
dans le code — c'est le principe de conception de TypeSafe.

**Tout demander en un appel.** Les questions sont évaluées en parallèle ; en ajouter ne
coûte presque rien en latence. Poser même les questions spéculatives (utiles seulement
selon la réponse à une autre) et trier ensuite, plutôt que d'enchaîner des appels.

**Toujours lire la `confidence`.** En dessous de 0,5, le verdict ne vaut rien : revenir
au raisonnement normal ou demander à l'utilisateur. Le seuil dépend de l'enjeu — plus
l'action est difficile à annuler, plus il doit être haut.

**Ne jamais agir de façon destructrice sur un seul verdict Jev.** Un `noul` sert à
filtrer et à trier, pas à autoriser une suppression ou un `push --force`.

## Ce pour quoi Jev est inutile

Générer du texte ou du code, expliquer, résumer, traduire, reformuler. Jev ne produit
pas de langage — il ne renvoie que des nombres et des étiquettes choisies dans une liste
fournie d'avance. Pour tout le reste, raisonner normalement.

## Panne

`jev` et `jev-rank` sont **fail-open** : en cas d'erreur, sortie vide (ou ordre d'origine
pour `jev-rank`) et code de retour 0. Une sortie vide n'est pas une réponse négative —
c'est l'absence de réponse : reprendre le raisonnement normal. Diagnostic : `jev selftest`,
ou `JEV_DEBUG=1` pour la cause exacte sur stderr.
