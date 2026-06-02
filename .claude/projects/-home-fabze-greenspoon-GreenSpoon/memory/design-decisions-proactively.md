---
name: design-decisions-proactively
description: User prefers Claude to design and build UI/UX itself rather than present option menus
metadata:
  type: feedback
---

Bei UI/UX-/Design-Entscheidungen will der User, dass ich selbst etwas ausarbeite und umsetze ("Denke dir da was aus"), statt ihm ein AskUserQuestion-Auswahlmenü mit Varianten vorzulegen. Ein solcher Multiple-Choice-Vorschlag wurde abgelehnt; danach gab er selbst detaillierte Richtung und erwartete, dass ich es eigenständig baue.

**Why:** Er hat eigene Vorstellungen und gibt sie in Prosa; ein Optionsmenü bremst ihn eher, als dass es hilft.

**How to apply:** Bei Design-/Layout-Fragen eine sinnvolle Entscheidung treffen, kurz begründen und direkt implementieren. Nur dann zurückfragen, wenn etwas wirklich blockiert (z. B. Backend-Deploy, fachliche Daten). Konkrete Werte (z. B. Haltedauer) als einzelne Konstante exponieren, damit er leicht nachjustieren kann.
