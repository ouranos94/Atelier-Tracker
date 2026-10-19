# Atelier Tracker 0.12.0 — build 19

[**Télécharger le DMG macOS Apple Silicon**](https://github.com/ouranos94/Atelier-Tracker/releases/download/v0.12.0/Atelier-Tracker-0.12.0-macOS-arm64.dmg)

Le DMG est distribué dans [GitHub Releases](https://github.com/ouranos94/Atelier-Tracker/releases/tag/v0.12.0), avec sa somme SHA-256. Il contient la version compilée existante, sans recompilation, la licence MIT et les instructions d’installation.

## Installation

1. Utiliser un Mac Apple Silicon avec macOS 14 ou ultérieur.
2. Télécharger et ouvrir le DMG.
3. Glisser `Atelier Tracker.app` vers le raccourci Applications.
4. Éjecter le disque, puis ouvrir l’application depuis Applications.

Xcode, Homebrew, Kickstart et AmigaOS ne sont pas nécessaires. L’application porte une signature locale ad hoc ; cette version n’est pas notarisée par Apple.

## Vérification du DMG

Le conteneur a été vérifié avec `hdiutil verify`, puis monté en lecture seule. Le bundle extrait a été contrôlé avec `codesign --verify --deep --strict`, sa version vérifiée et son exécutable ARM64 comparé au binaire existant.

Télécharger le DMG et `Atelier-Tracker-0.12.0-macOS-arm64.dmg.sha256` depuis GitHub Releases dans le même dossier, puis lancer :

```sh
shasum -a 256 -c Atelier-Tracker-0.12.0-macOS-arm64.dmg.sha256
```

## Archive ZIP alternative

L’[archive ZIP conservée dans Git](Atelier-Tracker-0.12.0-macOS-arm64.zip?raw=true) reste disponible. La décompresser, puis copier l’application dans Applications. Sa somme de contrôle est dans [SHA256SUMS](SHA256SUMS).

Le [guide fonctionnel](../../docs/FONCTIONNALITES.md) décrit les fonctions et limites. Les licences tierces sont incluses dans les ressources de l’application ; le code propre à Atelier Tracker relève de la [licence MIT](../../LICENSE).
