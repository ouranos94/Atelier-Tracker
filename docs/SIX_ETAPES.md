# Six améliorations de composition — suivi

Demande : lancer les six améliorations proposées après la version 0.10.1.

1. [x] Grille principale SymMOD reliée aux coordonnées source, saisie au clavier et écoute de note.
2. [x] Éditeur explicite des effets ordinaires pris en charge, paramètres expliqués et commandes inconnues protégées.
3. [x] Blocs SymMOD : sélection, copie/collage, duplication et transposition atomiques et annulables.
4. [x] Instruments : forme d’onde de préécoute, écoute individuelle, limites de boucle et types identifiables.
5. [x] Présentation cohérente des éditeurs, préférences mémorisées et aide de clavier accessible.
6. [x] Corpus reproductible plus varié, vérificateur indépendant des données et compte rendu de compatibilité.

La validation par Symphonie Pro sur Amiga nécessite le logiciel et le matériel adéquats. Son absence doit rester explicitement indiquée ; un test du lecteur intégré ne constitue pas une validation dans l’application d’origine.

Livraison : **0.11.0**. Les six chantiers ont une implémentation et une validation locale. La quatrième étape fournit une enveloppe de préécoute rendue, distincte de la forme PCM brute. Le sixième chantier comprend dix modules synthétiques originaux et un vérificateur de structure en Python indépendant du code Swift ; il ne constitue pas une validation sonore par un second lecteur.

- [ ] Validation externe des exports par Symphonie Pro 3.2 sur Amiga : logiciel/matériel non disponibles dans cet environnement.

Le protocole de reprise de cette vérification est dans `COMPATIBILITE_011.md`.
