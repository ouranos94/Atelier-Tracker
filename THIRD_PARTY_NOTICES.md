# Inspiration et crédits

Atelier Tracker est une nouvelle implémentation Swift/SwiftUI, inspirée du flux de composition de ProTracker et du projet pt2-clone d’Olav Sørensen : https://github.com/8bitbubsy/pt2-clone

Aucun fichier source, moteur audio, graphisme ou morceau de pt2-clone n’est intégré à cette version. Le dépôt de référence a été consulté pour comprendre son périmètre, sa structure de module et ses choix de compatibilité. Le moteur de cette application n’offre pas la fidélité de pt2-clone. Aucune affiliation ou approbation de son auteur n’est revendiquée.

Les quatre samples et le morceau de démonstration sont générés par le code de l’application. SwiftUI, AppKit et AVFoundation sont des frameworks Apple fournis par macOS.

## libopenmpt 0.8.9

La lecture Symphonie / Symphonie Pro utilise libopenmpt 0.8.9, compilé pour ARM64 et lié statiquement à l’application. Site officiel : https://lib.openmpt.org/libopenmpt/ . Sources officielles : https://lib.openmpt.org/files/libopenmpt/src/libopenmpt-0.8.9+release.autotools.tar.gz .

La bibliothèque n’a pas été modifiée. Les composants optionnels zlib, mpg123, Ogg/Vorbis, FLAC, sndfile et PortAudio sont désactivés. La passerelle C d’Atelier est distincte de la bibliothèque.

Copyright (c) 2004–2026, OpenMPT Project Developers and Contributors. Copyright (c) 1997–2003, Olivier Lapicque. BSD 3-Clause. Le texte complet est conservé dans `Vendor/OpenMPT/LICENSE` et distribué dans `Contents/Resources/Licenses/OpenMPT-BSD.txt`. Les textes de licence du composant mpt sont également distribués dans ce dossier. Aucune affiliation ou approbation des auteurs n’est revendiquée.

L’analyse du conteneur et de la compression SymMOD de l’écrivain Swift s’appuie sur la structure documentée par le chargeur OpenMPT `soundlib/Load_symmod.cpp` (Devin Acker et OpenMPT Devs), sous la même licence BSD 3-Clause distribuée avec l’application. Référence : https://github.com/OpenMPT/openmpt/blob/libopenmpt-0.8.9/soundlib/Load_symmod.cpp .
