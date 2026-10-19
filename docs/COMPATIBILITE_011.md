# Compatibilité et validation 0.11.0

Date : 18 octobre 2026. Cible : macOS 14+, Apple Silicon, libopenmpt 0.8.9 embarqué.

Validation automatisée : **110 tests Swift réussis**, plus **5 tests du vérificateur Python réussis**. Le test d’effets a été élargi au trémolo puis relancé avec succès.

## Ce qui a été vérifié

- Régressions des fichiers utilisateur TheSecret.SymMOD et After The Storm.mod ; les fichiers fournis ne sont pas inclus dans le dépôt.
- Correspondance de chaque ordre et ligne de TheSecret avec les positions source, y compris après répétition et après réouverture d’un ancien projet sans métadonnées de correspondance.
- Saisie depuis la grille principale, édition d’effets, sélection/blocs, annulation/rétablissement, projet, récupération, invalidation des caches et changement SymMOD → MOD.
- Écriture atomique des événements : une cellule protégée ou un dépassement refuse la totalité du geste.
- Effets sur le rendu mesurés pour glissement de volume, glissement de hauteur, vibrato, trémolo et vitesse. Les autres effets proposés sont bornés et rendus par le lecteur ; cela ne prouve pas leur identité avec le moteur Amiga.
- Préécoute isolée, distinction entre instruments, arrêt des travaux d’audition après un changement de morceau ; comparaison entre un morceau actif et le même morceau aux événements vidés pour détecter une fuite de notes dans la préécoute.
- Écriture et réouverture des dix modules synthétiques ci-dessous, conservation de leurs autres blocs et comparaison des rendus après réouverture (tolérance au dithering).
- Vérificateur Python des données, indépendant de TrackerCore et du décodeur audio ; cinq tests propres couvrent aussi les altérations de DSP, événements protégés, blocs opaques et PACK invalide.

## Corpus original reproductible

Les données et signaux sont créés par `scripts/generate-symmod-corpus.py`, sans musique ni samples externes. `Tests/Fixtures/SymMOD/manifest.json` décrit les dix fichiers générés. Ce corpus teste des constructions précises ; il ne représente pas toute la diversité des modules historiques.

| Module | Fonction vérifiée |
| --- | --- |
| mono | Deux patterns, instruments mono à boucle continue |
| packed | Tables de patterns, instruments, positions et séquences PACK |
| sixteen | Seize pistes et références d’instruments |
| stereo | Sample WAV stéréo et paire d’instruments gauche/droite |
| virtual | Instrument virtuel construit depuis des sources internes |
| sustain | Instrument à boucle sustain, propriétés protégées |
| dsp | Événement d’écho conservé et non éditable |
| sequences | Séquence ignorée, séparateur, transposition et marqueur de fin |
| repeat | Répétition de position et partage de pattern |
| cross-pattern | Plage de position traversant la frontière d’un pattern |

Reproduction :

```sh
python3 scripts/generate-symmod-corpus.py
python3 scripts/test-symmod-audit.py
TRACKER_TEST_SYMMOD="/chemin/TheSecret.SymMOD" TRACKER_TEST_MOD="/chemin/After The Storm.mod" swift test --build-system native
python3 scripts/audit-symmod.py original.SymMOD --compare export.SymMOD --allow-events
```

Le vérificateur affiche SHA-256, dimensions et changements par bloc. Sans option d’autorisation, toute modification sémantique est refusée. `--allow-instruments` et `--allow-arrangement` autorisent les champs documentés de ces tables ; les réserves et flags DSP restent vérifiés. Une décompression PACK peut changer les octets physiques sans changer les enregistrements. Cet outil vérifie la structure et la conservation, **pas le rendu sonore**.

## Contrôle de l’interface

Sur TheSecret : saisie musicale dans la piste 13 de la grille principale (E-2, instrument source 0), avance automatique, retour au clavier et édition du volume 100 → 99. Le module exporté contient trois octets changés, tous dans cette cellule source : hauteur 4, volume 99, instrument 0. Le vérificateur indépendant confirme qu’aucun autre bloc ne change. Préécoute de l’instrument source 2 et enveloppe visibles dans la banque. Les fichiers de contrôle sont supprimés après vérification, sans toucher à l’original.

## Validation externe encore nécessaire

**Aucune exécution de Symphonie Pro 3.2 sur Amiga n’a été effectuée.** Le logiciel et le matériel d’origine ne sont pas disponibles dans cet environnement. libopenmpt est un lecteur distinct de Symphonie, mais c’est aussi le moteur de cette application : son aller-retour ne constitue pas une validation indépendante du rendu. Le parseur Python apporte une indépendance structurelle uniquement.

Pour compléter :

1. Conserver une copie des modules d’origine et relever leur SHA-256.
2. Exporter un module sans changement, puis un export distinct par modification : note, volume, glissement, vibrato, vitesse, boucle d’instrument, position et séquence.
3. Passer chaque paire au vérificateur en autorisant uniquement la famille de champs attendue.
4. Ouvrir et jouer chaque export dans Symphonie Pro 3.2 sur Amiga ; relever chargement, instruments, événements, positions, tempo et boucles.
5. Enregistrer un rendu du logiciel d’origine avec les mêmes conditions d’écoute ; comparer les changements et queues de DSP, sans exiger une égalité numérique entre matériels différents.
6. Ajouter les résultats, la version du logiciel et la configuration matérielle à ce document. Un fichier qui charge ne prouve pas encore une lecture correcte de tous ses effets.

Les DSP, commandes non prises en charge, PCM brut, instruments stéréo/virtuels/sustain et boucles de séquence restent protégés à l’édition. Certaines subtilités des effets sont approximées par le lecteur. L’enveloppe affichée est celle d’une préécoute rendue, pas une extraction PCM brute.
