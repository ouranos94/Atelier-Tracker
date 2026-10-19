# Atelier Tracker

**Un studio de composition à base de samples, natif pour macOS Apple Silicon.**

Atelier Tracker associe l’écriture verticale d’un tracker à une interface SwiftUI moderne, en français. Il permet de composer des modules MOD à quatre pistes, de lire et d’éditer une partie du format Symphonie / Symphonie Pro, et d’exporter le résultat en audio.

L’application fonctionne sans émulateur, sans Kickstart et sans AmigaOS. Son ergonomie s’inspire de ProTracker et de [pt2-clone](https://github.com/8bitbubsy/pt2-clone) ; son code applicatif est une implémentation distincte en Swift.

**Version documentée : 0.12.0 — build 19.** Projet en développement, destiné à macOS 14 ou ultérieur sur Mac Apple Silicon.

## Fonctionnalités principales

- **Composition MOD** : quatre pistes, 31 samples, clavier musical AZERTY/QWERTY, effets, sélections, copier/coller, transposition et historique.
- **Symphonie / Symphonie Pro** : lecture multicanal, vue simultanée des 16 pistes, édition source protégée et export SymMOD des changements pris en charge.
- **Nouveaux morceaux SymMOD** : choix de 1 à 32 pistes, patterns et arrangement, duplication ou partage des patterns.
- **Samples** : forme d’onde, préécoute, boucles ; traitements et découpe pour MOD ; import et remplacement PCM mono pour les banques SymMOD compatibles.
- **Piano-roll SymMOD** : ajout, déplacement et réglage de la durée des notes sur la piste sélectionnée.
- **MIDI** : entrée CoreMIDI, vélocité, saisie pas à pas et prise SymMOD quantifiée sur une position.
- **Bibliothèque locale** : recherche, favoris, renommage, préécoute et chargement des samples.
- **Lecture et mixage** : pause/reprise, navigation, boucles, vumètres, solo, volumes, balances et niveau général.
- **Exports** : projets `.atelier`, modules MOD/SymMOD et WAV du mixage ou des pistes séparées.
- **Interface** : thèmes clair, sombre et système, zoom, panneaux redimensionnables et suivi de lecture désactivable.
- **Protection du travail** : annulation/rétablissement et récupération automatique de session.

[Consulter le guide complet des fonctions](docs/FONCTIONNALITES.md)

## Démarrer

L’application s’ouvre sur **Neon tides**, une démonstration originale dont les quatre instruments sont générés par le code.

1. Lire la démonstration avec **Espace**, ou ouvrir un morceau avec **⌘O**.
2. Choisir **Fichier → Nouveau morceau** pour un MOD, ou **Nouveau SymMOD…** pour une composition multicanal.
3. Choisir un instrument, importer un sample, puis cliquer une cellule de la partition pour saisir des notes.
4. Utiliser **Composer**, **Piano** ou **Clavier MIDI** selon le mode d’écriture souhaité.
5. Enregistrer le travail en `.atelier` avec **⌘S** ; utiliser les commandes d’export pour produire un module ou un WAV.

Le piano-roll et la prise de durée MIDI concernent SymMOD. Le guide précise les différences avec l’édition MOD.

## Télécharger l’application

Télécharger le [DMG macOS Apple Silicon 0.12.0](https://github.com/ouranos94/Atelier-Tracker/releases/download/v0.12.0/Atelier-Tracker-0.12.0-macOS-arm64.dmg) depuis [GitHub Releases](https://github.com/ouranos94/Atelier-Tracker/releases/tag/v0.12.0), l’ouvrir puis glisser l’application dans Applications. Aucun outil de développement n’est requis. Voir les [instructions d’installation et de vérification](releases/v0.12.0/README.md). Cette version porte une signature locale ad hoc et n’est pas notarisée par Apple.

## Construire l’application

Prérequis : un Mac Apple Silicon, macOS 14 ou ultérieur et une installation Xcode fournissant Swift et les outils C/C++. Le manifeste SwiftPM utilise `swift-tools-version: 5.9`. Python 3 est nécessaire aux outils d’audit complémentaires.

Depuis la racine du dépôt :

```sh
./scripts/build-app.sh dist/v0.12.0
open "dist/v0.12.0/Atelier Tracker.app"
```

Le script compile en ARM64, crée le bundle `.app`, ajoute l’icône et les licences tierces, puis applique une signature locale ad hoc. Si `libopenmpt.a` est absente, il lance sa reconstruction à partir d’une archive officielle dont le SHA-256 est vérifié ; cette étape nécessite Internet.

Pour développer et tester directement :

```sh
swift build --build-system native
swift test --build-system native
python3 scripts/test-symmod-audit.py
```

`Package.swift` peut aussi être ouvert dans Xcode. L’option SwiftPM `--build-system native`, utilisée par les scripts actuels, peut produire un avertissement de dépréciation avec les outils récents.

Les applications construites et les caches sont ignorés par Git (`dist/`, `.build/`). Le dépôt ne propose pas encore d’installateur signé Developer ID ni de distribution notarisée.

## Compatibilité et limites

| Format | Utilisation actuelle |
| --- | --- |
| `.atelier` | Format de travail : composition, samples, mixage et sources SymMOD originales/modifiées. |
| MOD | Lecture, édition et export des modules ProTracker compatibles à quatre pistes et 31 samples. |
| SymMOD | Lecture par libopenmpt 0.8.9 ; édition et écriture des structures explicitement prises en charge. |
| WAV / AIFF | Import comme samples, avec conversion selon le format du morceau. |
| WAV | Export stéréo float32 à 44,1 kHz, mixage complet ou pistes séparées. |

Le moteur MOD est simplifié : il ne vise pas une émulation Paula ou une reproduction exacte de ProTracker. Les DSP et structures SymMOD spécialisés restent protégés ; les effets partagés peuvent sonner différemment dans la console. La lecture est bornée à cinq minutes pour MOD et trente minutes pour SymMOD.

Les nouveaux exports SymMOD ont été relus avec le lecteur embarqué. Leur réouverture dans **Symphonie Pro 3.2 sur Amiga** et le fonctionnement d’un **clavier MIDI matériel** restent à valider. Ces limites sont détaillées dans le guide fonctionnel.

## Validation et documentation

La validation de la version 0.12.0 comprend **121 tests Swift et 5 tests Python réussis**, avec les fichiers de référence locaux et les fixtures synthétiques. Les tests dépendant de fichiers utilisateur peuvent être ignorés si ces fichiers ne sont pas fournis ; ils ne sont pas distribués avec le dépôt.

- [Guide complet des fonctions](docs/FONCTIONNALITES.md) : utilisation, raccourcis, formats et limites.
- [Structure et édition SymMOD](docs/SYMMOD.md) : documentation technique du format, à lire avec les ajouts de la version 0.12.0.
- [Cycle de composition 0.12.0](docs/SIX_ETAPES_COMPOSITION.md) : périmètre livré et validations.
- [Feuille de route](ROADMAP.md) : étapes de développement et travaux restants.
- [Archives des versions](docs/HISTORIQUE_VERSIONS.md) : ancien README conservé comme historique.

Pour signaler un problème, indiquer la version de macOS, la version de l’application, le format du morceau et les étapes permettant de reproduire le comportement. Ne joindre un module que si sa redistribution est autorisée.

## Crédits et licences

L’inspiration, les dépendances et leurs licences sont recensées dans [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). libopenmpt est distribué sous licence BSD 3-Clause ; son texte de licence est inclus dans le dépôt et dans l’application. Aucun code, graphisme ou morceau de pt2-clone n’est intégré.

Le code propre à Atelier Tracker est publié sous [licence MIT](LICENSE), conformément à la licence du dépôt. Les composants tiers conservent leurs licences respectives, notamment BSD 3-Clause pour libopenmpt.
