# Atelier Tracker 0.12.0 — build 19

[**Télécharger l’application macOS Apple Silicon**](Atelier-Tracker-0.12.0-macOS-arm64.zip?raw=true)

Cette archive contient la version compilée existante, sans recompilation, ainsi que la licence MIT et un fichier de démarrage. Elle est conservée dans Git ; il ne s’agit pas d’une entrée GitHub Releases distincte.

## Installation

1. Utiliser un Mac Apple Silicon avec macOS 14 ou ultérieur.
2. Télécharger puis décompresser le ZIP.
3. Copier `Atelier Tracker.app` dans le dossier souhaité, par exemple Applications, puis l’ouvrir.

Xcode, Homebrew, Kickstart et AmigaOS ne sont pas nécessaires pour utiliser cette application. La signature est locale ad hoc ; cette version n’est pas notarisée par Apple.

## Vérification

Le bundle extrait a été contrôlé avec `codesign --verify --deep --strict` et son exécutable ARM64 comparé au binaire existant. La somme de contrôle est disponible dans [SHA256SUMS](SHA256SUMS).

Après téléchargement du ZIP et du fichier SHA256SUMS dans le même dossier :

```sh
shasum -a 256 -c SHA256SUMS
```

Le [guide fonctionnel](../../docs/FONCTIONNALITES.md) décrit les fonctions et limites de cette version. Les licences tierces sont incluses dans les ressources de l’application ; le code propre à Atelier Tracker relève de la [licence MIT](../../LICENSE).
