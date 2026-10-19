# Feuille de route — Atelier Tracker

> Pour le périmètre actuel de la version 0.12.0, consulter le [guide fonctionnel](docs/FONCTIONNALITES.md) et le [cycle de composition livré](docs/SIX_ETAPES_COMPOSITION.md). Les bilans ci-dessous décrivent les étapes successives du développement.

Ce document rassemble les améliorations graphiques et fonctionnelles proposées pour Atelier Tracker. Les cases cochées indiquent les travaux livrés. Les autres restent à réaliser.

## Point de départ

À la version 0.2.3, l’application propose une interface native macOS Apple Silicon, les thèmes clair/sombre/système, la composition MOD à quatre pistes, l’import de samples, la sauvegarde des projets Atelier et l’export WAV. Les fichiers SymMOD sont accessibles en lecture seule, avec une vue de toutes les pistes, des vumètres et un moteur de lecture libopenmpt.

La transition entre SymMOD et MOD a reçu un correctif contre un accès hors limites dans les vumètres. Ce scénario doit rester couvert par les tests au fil des évolutions.

## Ordre de réalisation

| Étape | Sujet | Priorité | Dépendances principales |
| --- | --- | --- | --- |
| 1 | Pause, reprise et navigation audio | Haute | Architecture de lecture |
| 2 | Zoom, lisibilité et disposition de l’interface | Haute | Aucune pour les premiers réglages |
| 3 | Sélections et outils de composition | Haute | Repères d’édition et historique |
| 4 | Éditeur de samples | Moyenne | Sélections et historique |
| 5 | Mixage et export de pistes séparées | Moyenne | Lecture continue et commandes en direct |
| 6 | Édition et écriture SymMOD | Chantier distinct | Modèle éditable et spécification du format |

La fiabilité et les tests accompagnent **chaque étape**. La sauvegarde automatique est à intégrer tôt, avant les opérations d’édition plus importantes.

## Socle transversal — Fiabilité et récupération

- [x] Ajouter une sauvegarde automatique de récupération, distincte du fichier enregistré par l’utilisateur.
- [x] Proposer de restaurer la session après une fermeture anormale.
- [x] Conserver une version de récupération précédente lorsque c’est utile.
- [ ] Ajouter une liste des fichiers récents et gérer les fichiers déplacés ou supprimés.
- [ ] Afficher précisément les formats, effets et opérations pris en charge ou limités.
- [ ] Préserver les données originales lors d’une opération non prise en charge ou d’un export incompatible.
- [ ] Maintenir les tests de changement de format : SymMOD → MOD et MOD → SymMOD, à l’arrêt, en lecture et pendant la préparation audio.
- [ ] Vérifier également l’ouverture d’un autre fichier pendant un export, l’annulation et les erreurs de fichier.

**Validation :** après une interruption, le travail récupérable est proposé au prochain lancement. Une erreur de chargement ne remplace pas le morceau courant. Les lecteurs, minuteurs, niveaux et sélections d’un ancien morceau ne peuvent pas agir sur le nouveau.

## Étape 1 — Transport audio complet

### Fonctions

- [x] Ajouter une vraie pause qui conserve la position courante.
- [x] Reprendre la lecture sans repartir du début.
- [x] Afficher le temps écoulé et la durée totale dans un format lisible.
- [x] Ajouter une barre de progression cliquable et déplaçable.
- [x] Démarrer depuis une position ou une ligne sélectionnée.
- [x] Définir une boucle sur un pattern ou une sélection.
- [x] Distinguer clairement lecture, pause, arrêt et préparation dans l’interface.
- [x] Documenter les raccourcis clavier correspondants.

### Travail technique

- [x] Séparer l’état du transport, la position de lecture et le curseur d’édition.
- [x] Permettre la lecture continue et les déplacements sans recalculer systématiquement tout le morceau.
- [x] Synchroniser les notes affichées et les vumètres avec le temps audio.
- [x] Définir le comportement des effets, des samples déjà déclenchés et des DSP lors d’un déplacement ou d’une boucle.
- [x] Conserver l’annulation des opérations et l’isolation des sessions de lecture.

**Validation :** pause/reprise et déplacement fonctionnent avec un MOD et un SymMOD. L’affichage reste synchronisé, sans blocage de l’interface. Les boucles ne produisent ni silence inattendu ni accumulation incontrôlée des effets.

Livré dans la version **0.3.0** : audio préparé en arrière-plan et conservé en mémoire, navigation et boucles sur le PCM, fondus de 2 ms aux limites. Les effets et DSP sont répétés tels que rendus, sans accumulation. Voir les commandes et limites dans `README.MD`. Validation : 30 tests réussis avec les deux fichiers fournis, plus contrôle de l’interface.

## Étape 2 — Interface adaptable et lisible

- [x] Ajouter un zoom horizontal des pistes.
- [x] Permettre de régler la taille de la police de la partition.
- [x] Conserver la vue générale de toutes les pistes SymMOD.
- [x] Ajouter une vue détaillée de la piste sélectionnée.
- [x] Rendre les panneaux latéraux redimensionnables.
- [x] Mémoriser leur visibilité, leurs dimensions et les réglages de zoom.
- [x] Identifier les champs : note, instrument, volume et effet.
- [x] Ajouter des infobulles expliquant les effets et leurs paramètres.
- [x] Distinguer les commandes du fichier d’origine et leur représentation interne lorsque le décodeur les traduit.
- [x] Renforcer la hiérarchie visuelle et les contrastes dans les deux thèmes.
- [x] Conserver les couleurs des pistes et les repères distincts de lecture et d’édition.
- [x] Vérifier l’accessibilité des contrôles et de la partition, y compris lorsque celle-ci est dessinée sur un Canvas.

**Validation :** les notes et effets restent lisibles à la taille minimale de fenêtre. La vue à 16 pistes et la vue détaillée restent alignées avec les vumètres. Les réglages sont retrouvés au prochain lancement. Le clavier et les technologies d’assistance donnent accès aux fonctions principales.

Livré dans la version **0.4.0** : réglages de zoom et de police, panneaux redimensionnables et mémorisés, vue d’une piste, légendes, explications des cellules et commandes accessibles pour la partition SymMOD. Validation : 33 tests réussis avec les deux fichiers fournis ; contrôle visuel des thèmes clair et sombre et des réglages dans l’application.

## Étape 3 — Outils de composition

- [x] Sélectionner une cellule, plusieurs lignes ou un bloc de plusieurs pistes.
- [x] Copier, couper, coller, déplacer et dupliquer un bloc.
- [x] Définir le comportement du collage : remplacement ou mélange des champs, limites du pattern et données incompatibles.
- [x] Transposer une note, une sélection ou un pattern.
- [x] Insérer et supprimer des lignes avec un comportement explicite sur les autres pistes.
- [x] Ajouter une configuration du clavier musical pour AZERTY et QWERTY.
- [x] Afficher les raccourcis et la correspondance entre touches et notes.
- [x] Regrouper l’historique par action utilisateur : un geste sur un curseur correspond à une annulation.
- [x] Conserver les sélections et le curseur de façon cohérente après une modification ou une annulation.
- [x] Respecter le caractère partagé des patterns référencés plusieurs fois dans l’arrangement.
- [x] Désactiver explicitement les opérations d’édition pour les formats encore en lecture seule.

**Validation :** chaque opération peut être annulée puis rétablie avec restitution exacte des données. Les cas limites sont vérifiés : dernière ligne, dernière piste, sélection vide, collage trop grand et dépassement de hauteur de note.

Livré dans la version **0.5.0** : blocs MOD, presse-papiers structuré, collage par remplacement ou mélange, déplacements et duplications, transposition, décalage des lignes, clavier AZERTY / QWERTY et historique conservant la sélection. Le collage hors limites est refusé et les outils sont désactivés pour SymMOD. Validation : 47 tests réussis et contrôle des outils dans l’application.

## Étape 4 — Éditeur de samples

- [x] Zoomer et se déplacer dans la forme d’onde.
- [x] Sélectionner une plage et afficher ses limites et sa durée.
- [x] Découper ou conserver uniquement la sélection.
- [x] Normaliser le niveau, inverser le sample et appliquer des fondus d’entrée ou de sortie.
- [x] Déplacer visuellement les points de boucle.
- [x] Écouter une sélection ou une boucle.
- [x] Jouer le sample immédiatement au clavier musical.
- [x] Afficher la fréquence d’échantillonnage, la résolution, le nombre de canaux et la hauteur de référence.
- [x] Expliquer les conversions et les limites du format MOD avant une opération qui réduit les données.
- [x] Intégrer les modifications de samples à l’historique et à la récupération automatique.
- [x] Prévoir séparément l’extraction et l’édition des instruments Symphonie ; leur affichage actuel ne donne pas accès à leurs données audio dans l’éditeur MOD.

**Validation :** les opérations sont audibles, visibles et annulables. Les points de boucle restent valides après une découpe ou un changement de longueur. Les exports respectent les limites annoncées du format choisi.

Livré dans la version **0.6.0** : éditeur de samples MOD, zoom/sélection, traitements, découpes, boucles et préécoute, avec historique et récupération automatique. Validation : 64 tests réussis et contrôle de l’interface. Les instruments Symphonie restent explicitement hors de cet éditeur.

## Étape 5 — Console de mixage et exports

- [x] Ajouter un solo par piste et définir son interaction avec les pistes muettes.
- [x] Régler le volume et le panoramique de chaque piste.
- [x] Appliquer les commandes de mixage pendant la lecture, sans redémarrer le morceau.
- [x] Ajouter un niveau général et un indicateur de saturation.
- [x] Conserver les vumètres sur la vue générale et la vue détaillée.
- [x] Distinguer les réglages du morceau, ceux du mixage et ceux de l’écoute temporaire.
- [x] Définir quels réglages sont enregistrés dans le projet Atelier.
- [x] Exporter le mixage complet en WAV.
- [x] Exporter les pistes séparées avec des durées et des points de départ communs.
- [x] Proposer une politique explicite pour les retours d’effets, les DSP partagés et les queues de réverbération dans les exports séparés.
- [x] Afficher la progression de l’export et permettre son annulation.

**Validation :** les commandes restent réactives pendant la lecture. Un export complet utilise les réglages annoncés. Les pistes séparées peuvent être réassemblées sans décalage ; les éventuelles différences dues aux effets partagés sont expliquées.

Livré dans la version **0.7.0** : 74 tests réussis avec les deux fichiers fournis ; console activable, volumes/balances en direct, Muet/Solo, niveau général et saturation, réglages persistants, mixage et pistes séparées WAV float32 alignées, progression/annulation. Les DSP sont rendus indépendamment par piste ; les différences possibles avec le mix SymMOD original sont annoncées avant préparation et export. Voir `README.MD`.

## Étape 6 — Édition et écriture SymMOD

Cette étape dépasse l’ajout d’un lecteur. libopenmpt fournit actuellement le décodage et le rendu ; il faut prévoir un modèle éditable et une écriture capables de préserver les particularités Symphonie.

- [ ] Documenter les versions Symphonie / Symphonie Pro visées et constituer un ensemble de fichiers de validation.
- [ ] Définir un modèle conservant événements, séquences, répétitions, instruments et DSP.
- [ ] Préserver les informations du fichier d’origine qui ne sont pas encore interprétées.
- [ ] Identifier la correspondance entre la partition Symphonie originale et la représentation interne du lecteur.
- [ ] Permettre la modification des notes et événements multicanaux.
- [ ] Permettre l’édition des instruments, de leurs boucles et de leurs propriétés.
- [ ] Ajouter l’édition des effets et DSP pris en charge.
- [ ] Répercuter les changements dans le moteur de lecture.
- [ ] Implémenter une écriture SymMOD documentée, avec messages précis en cas de fonctionnalité non exportable.
- [ ] Valider les fichiers enregistrés avec un lecteur indépendant et, lorsque possible, le logiciel d’origine.
- [ ] Comparer le rendu avant/après sauvegarde sur des morceaux couvrant les différentes fonctionnalités.

**Validation :** un fichier ouvert puis enregistré sans modification conserve son contenu. Les modifications attendues sont présentes à la réouverture, sans perte des autres données. L’application ne présente pas un simple export du fichier original comme un enregistrement des changements.

### Premier lot de l’étape 6 — version 0.8.0

- [x] Ajouter une archive source SymM version 1 conservant les octets et les blocs opaques.
- [x] Lire strictement les événements, positions et séquences, y compris les tables PACK.
- [x] Proposer un éditeur distinct des patterns source pour les notes, instruments de note et volumes ordinaires.
- [x] Reconstruire la grille et la lecture à partir du fichier modifié ; conserver l’historique et la récupération.
- [x] Exporter ces changements dans un véritable fichier SymMOD, en conservant les autres blocs.
- [x] Documenter le décalage entre patterns source et patterns traduits, ainsi que les limites de validation.

Ce premier lot ne termine pas l’étape 6 : les instruments, séquences et DSP ne sont pas éditables. Le corpus initial est limité à TheSecret et aux fixtures synthétiques ; la validation dans Symphonie Pro 3.2 sur Amiga reste à faire. Voir `docs/SYMMOD.md` et `README.MD`.

### Deuxième lot de l’étape 6 — version 0.9.0

- [x] Lire les enregistrements d’instruments source, indépendamment des samples traduits.
- [x] Régler volume, transposition, accord fin et transpositions de position/séquence des instruments mono ordinaires.
- [x] Régler les boucles continues en pourcentages fins, sans changer les anciennes limites lorsqu’elles ne sont pas éditées.
- [x] Conserver les PCM, DSP, structures protégées et blocs voisins, y compris avec une banque compressée.
- [x] Intégrer ces modifications à la lecture, l’historique, la récupération, au projet et à l’export natif.

Validation : 91 tests réussis et export depuis l’interface de TheSecret vérifié octet par octet après transposition d’un instrument.

Les instruments virtuels, paires stéréo et sustain restent protégés ; l’édition des données audio et des DSP reste à réaliser. Ce lot ne termine pas l’étape 6.

### Troisième lot de l’étape 6 — version 0.10.1

- [x] Éditer les champs ordinaires des positions source : pattern, plage de lignes, vitesse, répétitions et transposition.
- [x] Éditer les plages et transpositions des séquences actives, en préservant les états spéciaux et boucles.
- [x] Conserver compteurs internes, réserves et blocs voisins, avec les tables PACK.
- [x] Reconstruire partition/durée, borner la sélection après raccourcissement et invalider transport, caches et points A/B.
- [x] Intégrer l’arrangement à l’historique, la récupération, au projet et à l’export natif.

Validation : 100 tests réussis et contrôle de l’interface. Export depuis TheSecret après modification d’une répétition : un seul octet changé, toutes les autres données identiques. Erreurs de plage et de destination corrigibles sans fermer l’éditeur.

Ce lot ne termine pas l’étape 6 : commandes spécialisées, DSP, instruments complexes et PCM restent à traiter. Les boucles de séquence sont conservées mais non restituées par le lecteur. Aucun ajout/suppression de table ni déplacement d’indices. La validation sur Amiga reste à faire.

### Composition intégrée et six améliorations — version 0.11.0

- [x] Vérifier la correspondance des ordres traduits et coordonnées source ; désactiver l’édition si elle est ambiguë.
- [x] Afficher/saisir les notes source dans la grille principale avec écoute isolée et coordonnées explicites.
- [x] Éditer les glissements ordinaires, vitesse, trémolo et vibrato avec explications et limites.
- [x] Composer par blocs SymMOD : copie/collage, duplication, déplacement et transposition atomiques, historique/projet/récupération.
- [x] Ajouter préécoute d’instrument, enveloppe rendue, limites de boucle et types identifiables.
- [x] Harmoniser les éditeurs, mémoriser leur état et exposer les outils/claviers depuis la partition.
- [x] Ajouter dix modules synthétiques reproductibles et un contrôle structurel indépendant en Python.
- [ ] Faire valider les exports dans Symphonie Pro 3.2 sur Amiga (environnement indisponible).

Les sources originales, PCM, DSP et commandes non prises en charge restent protégés. L’enveloppe de préécoute ne constitue pas une extraction de PCM brut. Voir `docs/SIX_ETAPES.md` et `docs/COMPATIBILITE_011.md` pour le bilan et la validation externe restante.

## Premier ensemble de livrables recommandé

1. Pause/reprise, temps de lecture et navigation vers un passage précis.
2. Zoom des pistes, taille de police et disposition mémorisée.
3. Sélections de blocs, copier/coller et transposition.
4. Sauvegarde automatique et récupération, développées en parallèle de ces fonctions.

Pour chaque livraison : préciser les fonctions ajoutées, les formats concernés, les vérifications effectuées et les limites restantes ; mettre à jour la documentation et produire une nouvelle application versionnée.
