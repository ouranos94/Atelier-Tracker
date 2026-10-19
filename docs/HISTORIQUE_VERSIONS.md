> Archive du README antérieur à la préparation GitHub. Ce texte décrit plusieurs versions successives et peut contenir des limites désormais levées. Pour les fonctions actuelles, consulter [le guide fonctionnel](FONCTIONNALITES.md) et [la présentation](../README.MD).

# Atelier Tracker

Une application macOS native pour composer avec quatre pistes de samples, inspirée du fonctionnement de ProTracker et de [pt2-clone](https://github.com/8bitbubsy/pt2-clone). Interface SwiftUI en français, moteur Swift et sortie AVFoundation. Aucun émulateur, Kickstart ou AmigaOS.

## Composition — version 0.12.0

- **Fichier → Nouveau SymMOD** : 1 à 32 pistes, 16/32/64/128 lignes, banque de 1 à 64 instruments. Les nouveaux arrangements permettent ajout, duplication, partage et suppression de positions.
- **Banque Symphonie → Importer / remplacer** : déposer un WAV/AIFF sur le panneau ou saisir son chemin. Conversion mono 16 bits à 40 460 Hz, jusqu’à 60 s ; accord et boucle réinitialisés. La forme PCM permet sélection à la souris, boucle et préécoute.
- **Piano** : piste sélectionnée, ajout/déplacement des notes et glissement du bord droit pour leur durée. Les arrêts occupent une ligne source ; les conflits avec notes et commandes sont refusés.
- **Clavier MIDI** : entrée CoreMIDI, source/canal, vélocité, jeu monophonique, saisie pas à pas MOD/SymMOD et prise SymMOD quantifiée sur la position sélectionnée. Terminer applique la prise en une opération annulable.
- **Bibliothèque** : dépôt de fichiers ou chemin, recherche, favoris, renommage, préécoute et chargement dans l’instrument choisi. Copies locales ; les originaux restent intacts.
- **Suivre** : activer le suivi du transport, ou le désactiver pour consulter une autre position. Compteur d’occurrences source et marqueurs orange des commandes protégées.

Les arrangements importés complexes restent modifiables dans leur éditeur existant, mais leur agrandissement automatique est désactivé. L’édition PCM protège les banques stéréo, externes ou ambiguës. MIDI matériel et réouverture dans Symphonie Pro 3.2 sur Amiga restent à valider. Détails : [six étapes de composition](SIX_ETAPES_COMPOSITION.md).

## Démarrer

Sur un Mac Apple Silicon avec macOS 14 ou ultérieur : ouvrir `dist/v0.12.0/Atelier Tracker.app`. Une composition originale, **Neon tides**, est chargée avec quatre instruments générés par le code.

- **Espace** : lire / mettre en pause / reprendre à la même position. **Échap** : arrêter ou annuler la préparation.
- **⇧Entrée** : démarrer depuis la cellule sélectionnée. **⌘L** : activer/désactiver la boucle du pattern courant. **⌥I / ⌥O** : placer les repères A / B.
- **Entrée** : lire le pattern sélectionné depuis son début. La lecture s’arrête à sa fin.
- Cliquer une cellule du pattern pour donner le focus au séquenceur.
- **Z S X D C V G B H N J M** : douze demi-tons ; **Q 2 W 3 E R 5 T 6 Y 7 U** : octave supérieure (lettres selon la disposition active du clavier).
- **Flèches** : déplacer la sélection ; **⌫** : vider une cellule.
- Le panneau de droite permet de choisir une note sans clavier, son numéro de sample et son effet en hexadécimal.
- Choisir un instrument dans la liste de gauche avant de saisir des notes. Le commutateur **Écriture** désactive l’enregistrement pour simplement écouter les notes.
- **⌘Z / ⇧⌘Z** : annuler / rétablir les modifications musicales.
- **⌘S** : enregistrer le projet ; **⌘O** : ouvrir un projet, un MOD ou un SymMOD ; **⌘E** : exporter un WAV.

L’arrangement permet d’ajouter un pattern vide, de dupliquer le pattern courant et de supprimer une position. Les patterns déjà présents dans un MOD gardent leurs références partagées : modifier une occurrence modifie toutes celles qui pointent vers ce pattern.

## Transport — version 0.3.0

Le temps écoulé et la durée totale accompagnent une barre de progression déplaçable. Le déplacement pendant la lecture reprend au passage choisi ; pendant une pause, il conserve la pause. Cliquer une cellule choisit un point de départ pour **⇧Entrée**, sans déplacer le curseur de lecture. La position d’édition est indiquée sous la barre ; la partition suit la lecture ou la pause. Les boutons séparent lecture/pause, arrêt, lecture depuis la sélection et lecture unique du pattern.

Le sélecteur **Boucle** répète le pattern courant ou l’intervalle **A–B**. Placer A, avancer jusqu’à B, placer B, puis choisir **Sélection A–B**. La plage minimale est de 20 ms. Un déplacement hors de la boucle la désactive. Échap ramène au début du morceau.

L’ouverture prépare le morceau en arrière-plan. Son audio PCM et ses repères restent en mémoire : pause, reprise et déplacements ne relancent pas le rendu. La première préparation et toute modification des notes ou samples nécessitent un nouveau calcul. Les commandes de console s’appliquent en direct. Les samples déjà déclenchés et les DSP sont ceux du rendu à cet instant ; une boucle répète cet audio, sans accumuler de nouvelles réverbérations. Deux fondus de 2 ms limitent les clics aux limites de boucle, sans changer sa durée. Un choix de boucle conserve l’état lecture/pause. Ce fonctionnement utilise davantage de mémoire sur les longs fichiers SymMOD (environ 168 Mio pour 16 min 37 s de PCM).

Les durées et points accessibles restent soumis aux limites des moteurs : cinq minutes / premier retour pour MOD, trente minutes pour SymMOD. Une ligne sautée par la séquence n’est pas un départ accessible ; un message l’indique. Les notes et les vumètres suivent le temps du lecteur, y compris après un déplacement ou un retour de boucle.

## Apparence

Choisir **Clair**, **Sombre** ou **Système** depuis le menu **Apparence → Thème**, ou l’icône soleil/lune dans l’en-tête. Le choix est conservé dans les préférences de l’application entre les lancements. Le mode Système suit l’apparence macOS. Les deux palettes couvrent les contrôles, les pistes, les effets, les formes d’onde, les vumètres et la partition Symphonie. Le réglage est indépendant du morceau et ne modifie pas les fichiers musicaux.

## Lisibilité et disposition — version 0.4.0

Le bouton **Réglages de la partition** (trois curseurs, dans l’en-tête) ouvre les réglages de largeur des pistes, de taille des notes et de visibilité des panneaux. Le zoom horizontal va de 100 à 250 %, la taille des notes de 10 à 20 points. En vue générale SymMOD, les notes utilisent deux points de moins (minimum 10) pour garder les 16 pistes visibles aux réglages initiaux. Un fort zoom ou une grande police ajoute un défilement horizontal commun aux en-têtes, aux vumètres et à la partition.

Les séparateurs de l’arrangement et de l’inspecteur se déplacent à la souris. Leurs largeurs s’adaptent aussi à la fenêtre pour réserver de la place au transport. Leur visibilité, leurs largeurs, la police et le zoom sont mémorisés entre les lancements. En vue générale SymMOD, les panneaux restent masqués par défaut ; le bouton dédié ou le menu **Partition** permet de les retrouver. **Réinitialiser l’affichage** restaure ces préférences sans modifier le morceau.

Le sélecteur de pistes SymMOD propose **Toutes**, les groupes de quatre et **Piste sélectionnée**. Ce dernier affiche une seule piste avec son vumètre et un choix de numéro de piste. L’inspecteur décrit la cellule sélectionnée, sa note, son instrument, sa colonne de volume et son effet. Pour SymMOD, le commutateur Source affiche les événements originaux quand leur correspondance a été vérifiée ; le mode traduit reste disponible en consultation. Pour MOD, les effets et leurs paramètres ont une infobulle explicative. Le volume d’une voix MOD est porté par Cxx ou par le sample, sans colonne de volume séparée.

Le menu **Partition** donne aussi accès aux commandes au clavier : **⌘= / ⌘−** pour la largeur des pistes, **⇧⌘= / ⇧⌘−** pour la taille des notes. La partition SymMOD accepte les flèches à l’arrêt lorsqu’elle a le focus. Pour les technologies d’assistance, elle expose les cellules de la ligne sélectionnée dans les pistes visibles ; les contrôles de position, ligne et piste de l’inspecteur donnent accès aux autres cellules. La grille principale SymMOD permet désormais la saisie et les blocs en mode Source ; les éditeurs séparés restent disponibles (voir version 0.11.0).

## Symphonie / Symphonie Pro (.SymMOD)

La version 0.2.0 ouvre les fichiers à signature `SymM` ainsi que l’extension `.SymMOD`, depuis le menu Ouvrir (⌘O), le glisser-déposer ou le parcours d’import de sample. Le décodage et la lecture utilisent **libopenmpt 0.8.9**, compilé pour ARM64 et lié statiquement à l’application : aucun émulateur, Kickstart ou installation Homebrew n’est nécessaire pour l’utiliser.

- Partition multicanal et instruments affichés sans conversion en MOD quatre pistes. La vue Symphonie dessine uniquement les lignes visibles pour maintenir les commandes réactives ; les flèches sous la partition permettent de parcourir les lignes à l’arrêt.
- À l’ouverture d’un SymMOD, le sélecteur **Pistes** est réglé sur **Toutes** : les 16 pistes et leurs vumètres sont visibles simultanément. Les panneaux latéraux sont masqués pour donner toute la largeur à la partition ; **Afficher les panneaux** les restaure. Dans cette vue compacte, chaque cellule affiche la note et l’instrument sur une ligne, les effets sur la suivante. Si la fenêtre ou le nombre de pistes exige plus de place, un défilement horizontal commun garde les en-têtes, vumètres et notes alignés. Les groupes 1–4, 5–8, 9–12, etc. restent disponibles pour une vue détaillée. Les coupures de pistes s’appliquent à la prochaine lecture et au rendu WAV.
- Patterns de longueur variable, séquence, effets et DSP gérés par le décodeur Symphonie de libopenmpt. L’arrangement suit la représentation du lecteur, tandis que le mode Source affiche les événements originaux aux coordonnées vérifiées ; elle peut contenir des patterns/positions supplémentaires créés pour représenter les répétitions, les changements de hauteur et les sauts Symphonie.
- Lecture du morceau complet ou de la position sélectionnée ; rendu/export WAV stéréo 16 bits à 44,1 kHz. La limite du moteur Symphonie est de **30 minutes**, distincte des cinq minutes du moteur MOD.
- L’enregistrement `.atelier` conserve une copie exacte des octets du SymMOD original, réinterprétée par le décodeur à la réouverture. Le fichier source n’est pas modifié.
- **SymMOD** : édition des notes et volumes ordinaires dans les patterns source, puis export natif SymMOD. Les propriétés des instruments mono ordinaires et l’arrangement source (positions, plages et transpositions des séquences actives) sont éditables ; leurs données PCM et les DSP restent protégés. La composition par blocs SymMOD utilise un presse-papiers distinct, sans conversion implicite depuis MOD. L’export MOD est refusé pour éviter de perdre des pistes, des instruments ou des effets.
- La banque Symphonie propose une préécoute isolée et son enveloppe rendue, ainsi que les limites de boucle source. Cette enveloppe ne représente pas les données PCM brutes. Les instruments sont lus par libopenmpt et ne sont pas réduits aux samples mono 8 bits MOD.
- Les avertissements du décodeur sont affichés, s’il en émet. Cette intégration n’est pas une garantie d’identité sonore avec le logiciel Amiga d’origine pour tous les fichiers Symphonie.

Testé le **17 octobre 2026** avec le fichier fourni **TheSecret.SymMOD** : 16 pistes, 128 emplacements d’instrument, 151 positions et 111 patterns après interprétation par le décodeur ; rendu complet non silencieux de **997,20 secondes** (16 min 37 s). Le test vérifie aussi les 16 niveaux, la lecture d’une position, le silence lorsque toutes les pistes sont coupées et la conservation exacte de la source après sauvegarde du projet. Le fichier utilisateur n’est pas distribué.

## Repères dans le pattern

À l’arrêt, un cadre vert indique la cellule sélectionnée pour l’édition. Pendant la lecture, ce cadre disparaît et une bande verte sur toute la largeur des quatre pistes indique la ligne jouée. Le cadre d’édition réapparaît à l’arrêt.

## Vumètres

Les quatre jauges du groupe de pistes visible sont affichées au-dessus des pistes pendant la lecture du morceau ou d’un pattern. Les niveaux proviennent des crêtes réelles du signal de chaque voix, après volume et avant panoramique/gain de mixage, mesurées par fenêtres de 20 ms pour le moteur MOD. Pour Symphonie, les niveaux de voix fournis par libopenmpt sont relevés toutes les 10 ms. L’échelle va de −48 à 0 dBFS, avec zones verte, jaune (−12 dB) et rouge (−4 dB), un repère de crête maintenu 650 ms et une retombée progressive. Elles suivent le temps audio du lecteur, indépendamment du tempo ou du défilement des lignes. Les jauges reviennent à zéro à l’arrêt. L’écoute isolée d’un sample n’alimente pas ces vumètres de pistes.

## Composition par blocs — version 0.5.0

Ces outils concernent les **MOD à quatre pistes**. Pour SymMOD, utiliser l’éditeur des patterns source distinct. À l’arrêt ou en pause, cliquer une cellule place le curseur ; **Majuscule + clic** ou **Majuscule + flèches** étend un rectangle de lignes et de pistes. Le bloc est teinté en vert et ses bornes sont affichées au-dessus des pistes. Le bouton **Composer** permet aussi de régler sa dernière ligne et sa dernière piste avec des contrôles accessibles. **⌘A**, lorsque la partition a le focus, sélectionne le pattern entier.

- **⌘C / ⌘X / ⌘V**, dans la partition : copier, couper, coller. Hors de la partition, ces raccourcis gardent leur fonction native dans les champs de texte. Les boutons de la barre et le menu **Composition** agissent directement sur le bloc.
- Le collage commence en haut à gauche de la sélection. **Remplacer** copie tous les champs, y compris les vides. **Mélanger** conserve la destination pour les notes et instruments vides ; une commande d’effet non vide remplace ensemble l’effet et son paramètre. Le collage ne se répète pas pour remplir une sélection plus grande.
- Un bloc dépassant la ligne 3F ou la quatrième piste est **refusé intégralement**, sans tronquer ses notes. Le presse-papiers contient un bloc Atelier MOD et une représentation textuelle ; seul le bloc structuré est collable comme musique. Les événements Symphonie ne sont pas compatibles. Les numéros d’instruments font référence aux emplacements de samples du morceau destinataire ; les sons ne sont pas copiés avec le bloc.
- **Dupliquer** copie le bloc immédiatement en dessous. Les quatre flèches de **Composer → Déplacer** décalent le bloc d’une ligne ou d’une piste, en vidant son ancien emplacement. Le déplacement gère les zones qui se recouvrent et remplace les données de destination. S’il dépasse le pattern, il est refusé.
- **−1 / +1**, **−12 / +12** : transposer la cellule ou le bloc d’un demi-ton ou d’une octave. **⌥⌘↑ / ⌥⌘↓** transposent d’un demi-ton. Le menu permet également de transposer tout le pattern. Une note hors des trois octaves MOD fait refuser toute l’opération. Une période MOD entre deux notes est rapprochée de la note de référence la plus proche avant transposition ; les instruments et effets sont conservés.
- L’insertion et la suppression portent sur le nombre de lignes sélectionnées. Le commutateur **Insertion / suppression sur les quatre pistes** choisit toutes les pistes ou seulement celles du bloc. Les lignes suivantes sont décalées, le pattern conserve 64 lignes. L’insertion retire les données en fin de pattern ; la suppression y ajoute des événements vides. Ces changements sont annulables.

Chaque opération constitue une action de l’historique. **⌘Z / ⇧⌘Z** restaure les données, le curseur et le bloc sélectionné. Un glissement complet du volume d’un sample constitue aussi une seule action. Comme auparavant, les patterns partagés dans l’arrangement restent partagés : une modification affecte chaque position utilisant le même pattern. Le message de l’action le rappelle.

**Composer → Clavier musical** choisit une disposition **QWERTY** ou **AZERTY**, mémorisée entre les lancements, et affiche la correspondance des 24 touches avec les notes. La disposition initiale QWERTY conserve les touches des versions précédentes. La saisie utilise les caractères de la disposition macOS active. Les flèches déplacent le curseur, **⌫** efface la cellule ou le bloc. Saisir une note réduit la sélection à une cellule et avance selon le réglage **Avance**. Les outils de blocs sont désactivés pendant la lecture et la préparation ; une modification depuis une pause arrête le transport et invalide l’audio préparé.

## Éditeur de samples — version 0.6.0

Dans **Sample Lab**, choisir **Éditer** ouvre la forme d’onde agrandie. Le zoom va de 1 à 64× ; le curseur **Défilement** parcourt la partie agrandie et **Vue entière** retrouve tout le son. Glisser dans la forme d’onde sélectionne une plage ; les contrôles **Début / Fin** permettent un réglage précis et accessible. Les limites sont exprimées en points, par multiples de deux ; la fin est exclue. Le nombre de points et la durée de la sélection sont affichés.

- **Garder la sélection** retire ce qui l’entoure. **Supprimer la sélection** joint les parties avant et après. Ces actions exigent une sélection explicite ; **Tout** sélectionne le sample complet.
- **Normaliser** amène la crête de la sélection à 127 sur 8 bits. **Retourner** inverse l’ordre des points ; **Inverser la polarité** change leur signe, avec saturation du cas −128 vers +127. Les fondus linéaires vont de zéro au niveau initial, ou inversement. Sans sélection explicite, ces traitements concernent tout le sample.
- Les poignées orange **A / B** déplacent les limites de boucle. Les contrôles numériques font la même chose ; une boucle MOD comporte au moins quatre points. **Boucler la sélection** reprend ses limites. Après une découpe, les positions sont décalées et la partie conservée de la boucle est utilisée ; une boucle supprimée ou trop courte est désactivée. Les traitements qui ne changent pas la longueur gardent les positions des marqueurs.
- **Écouter** joue la sélection, ou le sample complet à défaut, à C-3. **Écouter la boucle** répète ses points jusqu’à **Arrêter**. Cliquer la forme d’onde puis utiliser le clavier musical écoute les notes à l’octave choisie sans écrire dans le pattern. Les très courts instruments bouclés sont maintenus au moins 250 ms pour l’écoute au clavier, en conservant leur attaque. La sélection explicite reste une préécoute ponctuelle. Le démarrage/reprise du morceau, le changement de sample et la fermeture de l’éditeur arrêtent la préécoute.

Les opérations, les limites de boucle et la sélection sont intégrées à **⌘Z / ⇧⌘Z**. Un glissement d’une poignée de boucle compte comme une seule action ; l’annulation retrouve aussi le zoom et le défilement précédents. Modifier un sample change toutes les notes qui utilisent cet emplacement d’instrument.

Le MOD ne stocke pas une fréquence fixe comme un WAV : la vitesse de lecture dépend de la période de note et du finetune. L’éditeur affiche **C-3 ≈ 16 574 Hz**, avant finetune, avec l’horloge PAL du moteur. Les données sont mono, signées sur 8 bits. L’import explique la conversion avant le choix du fichier : mono 8 bits, 16 574 Hz, au plus 131 070 points (environ 7,91 s), avec suppression du surplus dans le sample importé. Le fichier audio source reste intact. Les découpes n’augmentent pas ces limites et les points de boucle restent alignés pour l’export MOD.

Cet éditeur de formes d’onde traite les samples MOD. Pour SymMOD, la version 0.9.0 propose un éditeur distinct des propriétés d’instruments mono ; les données audio restent protégées. L’édition des données audio et des instruments Symphonie complexes reste au programme de l’étape 6.

## Récupération automatique

Après une modification musicale, une copie de récupération est écrite environ **500 ms après la dernière action**, dans `~/Library/Application Support/Atelier Tracker/Recovery/`. Elle est distincte du projet enregistré et conserve une version précédente. Une écriture atomique protège le dernier point de récupération ; si la copie actuelle est illisible ou invalide, l’application essaie la précédente au lancement.

Après une fermeture anormale, une proposition permet de **Restaurer** le morceau, ses samples et les sélections du dernier point enregistré. L’historique d’annulation n’est pas rechargé. Il faut ensuite enregistrer le projet pour conserver ce travail dans un fichier choisi. **Ignorer cette récupération** supprime ces copies. Un enregistrement normal, un remplacement volontaire du morceau ou une fermeture confirmée nettoie la récupération de la session terminée. Le délai de 500 ms laisse une courte fenêtre pendant laquelle la dernière action peut ne pas encore être sauvegardée.

L’icône d’horloge dans la barre d’état et l’éditeur de samples donnent l’état de la récupération. Les erreurs d’écriture y sont signalées. Cette copie protège la session locale ; elle ne remplace pas les sauvegardes des fichiers de travail.

## Instruments et fichiers

Importer un fichier WAV/AIFF ou un autre format audio décodable par AVFoundation, de 30 secondes maximum. Il est converti en mono 8 bits à 16 574 Hz, plafonné à 131 070 octets (environ 7,9 secondes). Le volume et une boucle sur le sample complet sont réglables. Les boucles internes importées depuis un MOD sont conservées tant que le commutateur de boucle n’est pas modifié.

Les modules MOD peuvent être ouverts avec **⌘O**, déposés sur la fenêtre ou sélectionnés depuis **Importer un sample** : ils sont alors redirigés vers l’ouverture du morceau complet. Les extensions `.MOD`, les noms Amiga `mod.nom` et les signatures MOD sans extension sont reconnus avant tout appel au décodeur audio Apple.

Le projet `.atelier` conserve tous les patterns, instruments, tempo et vitesse. Il est préférable pour travailler. L’import MOD ne remplace pas le fichier original lors du premier enregistrement : choisir un chemin pour le projet.

**Exporter MOD** produit un fichier ProTracker 4 pistes / 31 samples. Ce format ne conserve pas les patterns inutilisés. Le tempo/vitesse différents des valeurs par défaut sont inscrits dans des emplacements d’effet libres de la première ligne ; si elle est pleine, l’application refuse l’export plutôt que de perdre ces réglages. Les notes et les effets saisis sont conservés. Le MOD ne conserve pas les réglages de console. Muet et Solo sont des réglages temporaires d’écoute ; les exports Console les appliquent, le projet ne les mémorise pas.

**Exporter WAV** ouvre le choix entre mixage complet et pistes séparées. Les WAV sont stéréo float32 / 44,1 kHz. Les détails de niveau, d’effets et d’alignement sont décrits ci-dessous.

## Compatibilité de la version 0.11.0

- Import MOD : signatures `M.K.`, `M!K!`, `4CHN`, `FLT4`, 31 samples, quatre pistes, jusqu’à 128 positions/patterns.
- Effets interprétés : `0xy` arpège, `1xx` montée, `2xx` descente, `9xx` offset de sample, `Axy` volume slide, `Bxx` saut de position, `Cxx` volume, `Dxx` saut de ligne et `Fxx` tempo/vitesse.
- Les autres effets sont préservés à la sauvegarde, ignorés par le moteur et signalés dans la barre d’état. Le moteur est simplifié : il ne reproduit pas toutes les subtilités de mémoire des effets et de déclenchement de ProTracker.
- Pour le moteur MOD, lecture/export limités à cinq minutes et arrêt au premier retour sur une même position/ligne, pour borner les morceaux contenant des boucles.
- Pas de simulation Paula, de filtres Amiga, de fidélité cycle par cycle ou de garantie de lecture identique à pt2-clone.
- Pas encore de MIDI, d’enregistrement audio, de plug-ins, ni d’édition des données audio d’instruments Symphonie.
- Version de développement signée localement (ad hoc), sans notarisation Apple pour la distribution publique.

## Développement

Xcode ou les outils de développement Swift récents sont nécessaires pour reconstruire :

```sh
swift build --build-system native
swift test --build-system native
./scripts/build-app.sh dist/v0.9.0
open "dist/v0.11.0/Atelier Tracker.app"
```

Ouvrir `Package.swift` dans Xcode pour développer. Le décodeur ARM64 précompilé se trouve dans `Vendor/OpenMPT/lib`. Pour le reconstruire depuis les sources officielles, lancer `./scripts/build-openmpt.sh` (téléchargement avec vérification SHA-256, puis compilation sans dépendances audio optionnelles). Le script de création du `.app` le fait automatiquement si l’archive statique manque. Le système de compilation natif SwiftPM est utilisé pour éviter un refus d’accès au répertoire de travail de l’indexeur C du système Xcode dans cet environnement.

- `Sources/TrackerCore/Module.swift` : modèle, morceau de démonstration, lecture/écriture MOD.
- `Sources/TrackerCore/Renderer.swift` : séquenceur MOD, mixage de quatre voix, WAV et marqueurs de lecture.
- `Sources/TrackerCore/Symphonie.swift` : import et rendu Symphonie via libopenmpt, positions, partition et niveaux multicanaux.
- `Vendor/OpenMPT` : bibliothèque ARM64, en-têtes, passerelle C et licences.
- `Sources/AtelierTracker/Studio.swift` : opérations d’édition, fichiers, transport et import audio.
- `Sources/AtelierTracker/StudioView.swift` : interface SwiftUI et clavier.
- `Tests/TrackerCoreTests` : fichiers malformés, aller-retour MOD, intégrité des samples, tempo, silence et terminaison des boucles.

Voir `THIRD_PARTY_NOTICES.md` pour les crédits.

## Vérification du correctif d’import

Le 15 octobre 2026 : tests de routage et d’intégration réussis pour `.mod`, `mod.nom`, signature sans extension et fichier invalide. Le fichier utilisateur **After The Storm.mod** a été ouvert depuis le parcours d’import de sample puis rendu : 30 positions, 21 patterns, 191,26 secondes, audio non silencieux et aucun effet signalé comme non pris en charge. Ce contrôle ne constitue pas une comparaison sonore avec ProTracker. Le fichier utilisateur n’est pas inclus dans le dépôt.

Pour répéter ce test avec un fichier local :

```sh
TRACKER_TEST_MOD="/chemin/vers/morceau.mod" swift test --build-system native --filter ImportTests
```

Pour tester le fichier Symphonie fourni :

```sh
TRACKER_TEST_SYMMOD="/chemin/vers/TheSecret.SymMOD" swift test --build-system native
```

## Correctif 0.2.3 : changement SymMOD / MOD

Le rapport de plantage du 17 octobre 2026 signalait un accès hors limites dans un vumètre : SwiftUI conservait momentanément la vue à 16 pistes alors que les tableaux de niveaux étaient ramenés à quatre éléments. Chaque morceau possède désormais son propre objet de vumètres ; les lectures de pistes déjà retirées retournent le silence. Le chargement arrête et libère le lecteur, les repères et les niveaux du morceau précédent. Les rappels du minuteur sont associés à une génération de lecture et ne peuvent pas modifier un nouveau morceau. Les sélections et les listes de l’interface restent valides pendant le remplacement.

Vérifications : transition SymMOD → MOD à l’arrêt, pendant la lecture et pendant le rendu, puis démarrage du MOD ; conservation des objets encore observés par l’ancienne vue, protection des index et régression des deux moteurs. Suite complète : 25 tests réussis avec les fichiers utilisateur, sans erreur ni test ignoré.

## Validation du transport 0.3.0

Le 17 octobre 2026 : **30 tests réussis**, sans test ignoré, avec `After The Storm.mod` et `TheSecret.SymMOD`. Vérification de la pause/reprise, conservation du lecteur et du cache lors d’un déplacement, indépendance du curseur d’édition, boucles A–B et pattern, reprise après déplacement, découpe PCM sans perte de l’état sonore, annulation de préparation et transitions SymMOD → MOD à l’arrêt, en lecture, en pause et pendant la préparation. Contrôle de l’interface sur les deux formats et de la navigation en pause.

## Validation de la disposition 0.4.0

Le 17 octobre 2026 : **33 tests réussis**, sans test ignoré, avec les deux fichiers fournis. Les nouveaux contrôles vérifient que les 16 pistes tiennent à la largeur minimale avec les réglages initiaux, que le zoom réserve suffisamment de place aux caractères, que les panneaux laissent de la place au transport et que la vue d’une piste revient correctement à quatre pistes lors d’un changement de format. Vérification de l’interface dans les deux thèmes, des curseurs de zoom/police et du redimensionnement accessible. La représentation d’accessibilité du Canvas expose la note, l’instrument et les commandes de la cellule ; elle ne constitue pas une certification d’accessibilité complète.

## Validation de la composition 0.5.0

Le 17 octobre 2026 : **47 tests réussis**, sans test ignoré, avec les deux fichiers fournis pour les régressions de lecture/import. Les tests de composition couvrent les blocs inversés, les quatre limites du pattern, les collages incompatibles ou vides, le mélange des champs, les déplacements avec chevauchement, la duplication, les limites de transposition et le décalage des lignes. Chaque opération de bloc est annulée puis rétablie avec comparaison des données et de la sélection ; le regroupement d’un glissement de volume et les patterns partagés sont également contrôlés. Les mutations sont refusées sur SymMOD.

Contrôle dans l’application sur la démo : extension du bloc au clavier et par les contrôles accessibles, copie/collage par raccourcis, annulation par le menu, routage de Copier vers les champs de texte, affichage des correspondances AZERTY / QWERTY et lisibilité du panneau Composer. La démo a été remise dans son état initial après ces contrôles.

## Validation de l’éditeur de samples 0.6.0

Le 17 octobre 2026 : **64 tests réussis**, sans test ignoré, avec les fichiers MOD et SymMOD fournis pour les régressions. Les nouveaux tests couvrent la découpe, le déplacement ou la désactivation des boucles, les valeurs extrêmes signées, les fondus, la restitution des données et de la sélection par l’historique, le regroupement des poignées, les préécoutes et leur arrêt, et l’aller-retour des samples modifiés par le codec MOD. La récupération est vérifiée dans des dossiers temporaires : restauration des samples/sélections, repli sur la copie précédente, annulation des écritures d’une ancienne session et nettoyage après enregistrement.

Contrôle de l’interface sur la démo : éditeur agrandi, écoute en boucle, sélection et limites accessibles, découpe avec recalcul de la boucle, annulation, zoom et activation du défilement. La récupération automatique a été observée pendant l’édition et nettoyée à la fermeture normale de la session de vérification.


## Console de mixage — version 0.7.0

Le bouton **Console de mixage** (trois curseurs verticaux dans l’en-tête) ouvre les commandes de toutes les pistes, avec défilement horizontal pour SymMOD. **Préparer les pistes** calcule un cache temporaire sur disque, avec progression et annulation. Son estimation apparaît avant le lancement : environ 2,6 Gio pour les 16 pistes de TheSecret. Le cache est conservé pendant la session, puis libéré au changement de morceau, à une modification musicale ou à la fermeture normale. Un arrêt conserve le cache ; une interruption brutale peut laisser des fichiers temporaires au système.

Choisir **Console** pour régler chaque volume de 0 à 200 %, la balance gauche/droite, **M** (muet) et **S** (solo). Plusieurs solos sont possibles ; Muet gagne toujours sur Solo. La balance atténue un côté du signal stéréo existant, sans recentrer les voix initialement panoramiquées. Les gains changent dans le moteur audio actif avec un lissage allant jusqu’à 20 ms : le lecteur, sa position et ses boucles restent conservés. Le changement de source Original/Console remplace le lecteur à la position courante et peut produire une brève coupure.

Le niveau général va de 0 à 100 % dans les deux sources. Les vumètres de la console et de la partition utilisent les crêtes après gain en mode Console. Le bandeau **MASTER** indique les crêtes stéréo avant limitation ; **SATURATION** reste allumé jusqu’à son effacement ou à la remise à zéro du transport. L’écoute Console limite les sorties à ±1 ; baisser les volumes pour éviter l’écrêtage. Ces indicateurs ne détectent pas une saturation déjà présente dans le fichier source ou dans le rendu d’un effet.

Les volumes, balances et niveau général sont enregistrés dans `.atelier`, y compris pour SymMOD, avec annulation/rétablissement et récupération automatique. Muet, Solo et le choix de source sont temporaires. À la réouverture, l’écoute reste Original tant que la console n’est pas préparée et activée ; les réglages des pistes restent conservés. Les samples SymMOD restent en lecture seule ; les notes ordinaires disposent d’un éditeur source distinct depuis la version 0.8.0.

### Exports et effets

Dans la fenêtre d’export, renseigner le nom et le dossier de destination (Téléchargements par défaut). Un dossier peut aussi être déposé depuis le Finder sur le champ de destination.

**Exporter le mixage complet** suit la source sélectionnée : Original avec niveau général seul, ou Console avec volumes, balances, Muet et Solo. **Exporter les pistes de la console** nécessite son cache, même si la source Original est sélectionnée. Le morceau entier est exporté, indépendamment de la boucle ou de la position courante. La préparation initiale d’un rendu Original affiche un état de préparation sans pourcentage interne ; la progression chiffrée accompagne ensuite l’écriture du WAV. L’export peut être annulé ; une ouverture de morceau annule également le travail précédent.

Chaque piste séparée est un WAV stéréo float32 / 44,1 kHz avec le même nombre de frames, départ zéro et fin commune au rendu du morceau. Aucune queue de réverbération supplémentaire n’est ajoutée. Les effets sont rendus séparément avec chaque piste ; il n’y a pas de fichier distinct de retour d’effet partagé. **Les DSP partagés ou non linéaires SymMOD peuvent donc différer du rendu Original.** Les fichiers séparés se réassemblent en reproduisant le mix Console avant sa limitation, avec ses réglages au lancement de l’export. Les pistes exclues par Muet/Solo restent présentes, silencieuses.

Les exports float32 conservent les crêtes au-delà de 0 dBFS, sans limitation finale ni normalisation séparée ; réduire le niveau dans le logiciel de destination si nécessaire. Leur source reste le rendu interne PCM 16 bits : float32 n’ajoute pas de précision au décodage. Le dossier contient les réglages `Mixage.json` et un `Lisez-moi.txt` rappelant les pistes muettes/solo et la politique d’effets. Un nom déjà utilisé est refusé. Les fichiers sont écrits dans une zone temporaire puis déplacés à destination après succès ; une erreur ou annulation retire les fichiers partiels de cette opération.

### Validation 0.7.0

Le 17 octobre 2026 : **74 tests réussis**, sans test ignoré, dont les tests du mixage, du lissage, des niveaux, des interactions Muet/Solo, de la pause/navigation, de la conservation du lecteur pendant les réglages et leur annulation, des projets anciens/nouveaux, de l’export WAV lu par AVFoundation et du réassemblage des pistes. Contrôle d’un extrait réel des 16 pistes de TheSecret et régressions complètes MOD/SymMOD. Les fichiers utilisateur restent hors du dépôt.

Contrôle final de l’interface 0.7.0 : préparation et activation de la console, lecture et solo, réglage du volume, affichage complet des explications, export du mix et des quatre pistes depuis le formulaire intégré, retour à la partition. Les quatre WAV créés par l’interface ont chacun 338 688 frames, en float32 stéréo ; signature de l’application vérifiée.


## Édition source SymMOD — premier lot, version 0.8.0

Ouvrir un SymMOD, puis **Fichier → Éditer les patterns SymMOD**, ou cliquer le bouton crayon de l’en-tête. L’éditeur affiche les patterns d’origine sur toutes les pistes, dans une grille défilante. Choisir le numéro de pattern source, cliquer une cellule, régler la note, l’instrument source (numéroté depuis 0) et le volume, puis **Appliquer**. **Effacer** retire un événement ordinaire. Les commandes spécialisées sont affichées mais protégées.

Les notes ordinaires acceptent les hauteurs −1/0…84 et les volumes 0…100. L’édition requiert l’arrêt ou la pause ; appliquer une modification arrête le transport et invalide ses caches. Relancer pour l’entendre. Les patterns partagés affectent toutes leurs occurrences. La grille principale reste une traduction de lecture, dont les indices peuvent différer : TheSecret possède 128 patterns source, contre 111 patterns traduits.

**⌘Z / ⇧⌘Z** annulent/rétablissent les éditions. Fermer l’éditeur puis **⌘S** pour conserver le projet Atelier et sa récupération automatique. La source importée originale reste conservée, séparément de la version modifiée. La réouverture d’un projet utilise les octets modifiés pour reconstruire la grille et le rendu.

**Fichier → Exporter SymMOD** crée un véritable module contenant les changements. Renseigner le nom et le dossier, ou déposer un dossier du Finder sur le champ de destination. Un fichier existant n’est pas remplacé. Sans édition, les octets exportés restent identiques à la source. Le mixage de console n’est pas inscrit dans le fichier SymMOD ; utiliser le projet Atelier ou l’export WAV pour le conserver.

Ce premier lot ne modifie pas les banques, les boucles d’instruments, les séquences ni les DSP. Les blocs autres que celui des événements restent inchangés ; la compression du bloc d’événements peut être retirée après édition. Une structure inconnue désactive l’édition sans retirer la lecture principale. **La compatibilité complète avec Symphonie Pro 3.2 et la validation dans le logiciel Amiga restent à établir.** Les détails, le corpus et les limites sont documentés dans [docs/SYMMOD.md](SYMMOD.md).

### Validation 0.8.0

83 tests réussis avec les fichiers fournis, dont conservation exacte, compression PACK (y compris un bloc réel recompressé pour le test), limites et commandes protégées, édition audible, réouverture par libopenmpt, historique, projet et récupération. Les rendus équivalents tolèrent le faible dithering du lecteur ; une note modifiée produit une différence audio mesurée au-delà de ce bruit. Contrôle de l’interface sur les seize pistes de TheSecret : événement DSP protégé, changement de volume d’une note de 100 à 99 %, puis export SymMOD contenant exactement ce changement.


## Propriétés des instruments SymMOD — version 0.9.0

Ouvrir **Fichier → Éditer les instruments SymMOD**, ou le bouton clavier de piano dans l’en-tête. La liste utilise les enregistrements source et leurs noms d’origine ; elle ne suppose pas de correspondance avec les indices des samples traduits par le lecteur. Les instruments mono ordinaires ou à boucle continue peuvent être modifiés ; les emplacements vides, instruments virtuels/transwave, paires stéréo et sustain restent en consultation seule.

Les réglages proposés sont le volume, la transposition en demi-tons, l’accord fin et l’option d’ignorer les transpositions de position/séquence. **Le volume source 0 signifie le volume par défaut (100), pas silence.** Les valeurs 1…100 règlent le niveau de l’instrument ; 101…199 utilisent l’amplification avec compression du lecteur Symphonie. Il s’agit d’un réglage de l’instrument enregistré dans le module, distinct du curseur de console.

**Modifier la boucle** permet d’activer/désactiver sa répétition continue, et de régler départ et longueur en pourcentage du sample. Une boucle activée doit avoir une longueur positive et finir au plus à 100 %. Ses nouvelles limites utilisent la précision fine Symphonie ; le lecteur les arrondit aux points audio. Les limites d’une ancienne boucle gardent leur encodage et leurs arrondis tant qu’elles ne sont pas changées. Désactiver conserve les limites dormantes. Le mode sustain et ses répétitions ne sont pas modifiés.

Choisir **Appliquer**, puis relancer le morceau pour écouter le résultat. L’application arrête le transport et invalide les caches. L’édition est possible à l’arrêt ou en pause, hors préparation/export. **⌘Z / ⇧⌘Z**, récupération automatique, sauvegarde `.atelier` et export SymMOD conservent ces propriétés. Fermer l’éditeur avant de sauvegarder ou d’exporter. Les éditions d’instruments et de notes peuvent être combinées ; la source originale reste conservée.

Les seuls octets réécrits sont ceux des propriétés choisies dans l’enregistrement d’instrument. Une banque PACK modifiée est réémise non compressée ; les événements, fichiers de samples et blocs de DSP restent identiques. Les filtres, les flags de DSP, les données audio, noms/chemins et structures virtuelles ne sont pas réécrits. Le rendu dépend des limites documentées de libopenmpt ; la validation dans Symphonie Pro 3.2 sur Amiga reste à faire.

### Validation 0.9.0

91 tests réussis avec les deux fichiers fournis : conservation des blocs, banques PACK, bornes, propriétés protégées, effets audibles, historique, caches, récupération, projet et export. Vérification dans l’interface de TheSecret : transposition de l’instrument source 2 de 0 à 1, puis export SymMOD. La comparaison des 2 574 974 octets confirme une seule différence, le champ de transposition choisi ; toutes les autres données sont identiques.

## Arrangement SymMOD — version 0.10.1

Ouvrir **File → Éditer l’arrangement SymMOD**, ou le bouton de liste dans l’en-tête. Cet éditeur distinct présente les tables d’origine : les numéros de position, séquence et pattern commencent à 0 et ne correspondent pas forcément aux ordres/patterns traduits dans la grille principale.

Une **position** choisit le pattern source, sa première ligne, le nombre de lignes jouées, la vitesse (1…31 ticks), les répétitions (0…16) et la transposition (−24…24 demi-tons). Les valeurs source 0 et 1 jouent une fois. La plage doit rester dans le même pattern ; les positions qui lisent au-delà d’un pattern, ou utilisent des valeurs hors de ces limites, restent consultables. Une modification affecte toutes les séquences qui référencent cette position ; une position inutilisée ne change pas l’écoute actuelle.

Une **séquence active** définit sa première position, le nombre de positions et sa transposition (−24…24). La plage reste dans la table et doit contenir des positions prises en charge. Les transpositions de séquence et de position se cumulent, sauf si l’instrument les ignore. Les séquences ignorées, le marqueur de fin, les entrées situées après lui, les états inconnus et les boucles de séquence restent protégés. **libopenmpt 0.8.9 ne restitue pas les répétitions de séquence** : leur valeur est affichée et conservée, sans commande d’édition.

Choisir **Appliquer**, puis relancer pour écouter. La partition et la durée sont reconstruites ; transport, caches et points A/B sont réinitialisés. La sélection est ramenée dans les limites si le morceau raccourcit. Annulation/rétablissement, récupération automatique, projet `.atelier` et export SymMOD conservent ces changements, combinables avec les notes et propriétés d’instruments. Fermer l’éditeur avant de sauvegarder/exporter.

L’écriture conserve les pointeurs et compteurs internes, marqueurs, boucles de séquence, octets réservés, événements, instruments, PCM et DSP. Seuls les champs choisis de l’enregistrement sont remplacés ; une table PACK modifiée est réémise non compressée. Une édition sans changement conserve exactement le fichier. L’expansion est limitée avant décodage à 4 096 positions jouées, 1 000 000 de lignes et 4 000 000 de cellules jouées. Aucun ajout/suppression de table ni déplacement des indices n’est proposé. La validation dans Symphonie Pro 3.2 sur Amiga reste à faire.

Les erreurs des éditeurs source et de l’export SymMOD sont affichées dans leur fenêtre, pour corriger immédiatement une plage invalide ou une destination incorrecte.

### Validation 0.10.1

100 tests réussis avec les deux fichiers fournis : tables brutes et PACK, conservation des champs opaques, marqueurs/entrées protégés, bornes et expansion, reconstruction des ordres et de la durée, transposition audible, réouverture et rendu après export, historique, récupération et projet. Contrôle de l’interface sur TheSecret : 512 positions, 64 séquences, marqueur de fin protégé ; répétition source de la position 0 passée de 1 à 2, soit 152 positions jouées. L’export de 2 574 974 octets contient exactement ce changement d’un octet, le reste est identique. Les erreurs de plage et de destination sont visibles immédiatement dans l’éditeur concerné et permettent de revenir au formulaire.

## Composition SymMOD intégrée — version 0.11.0

Dans la partition principale, activer **Source**, cliquer une cellule puis utiliser le clavier musical défini dans **Composer**. Le bouton **Écriture** distingue saisie et audition ; **Composer** règle octave, avance, instrument source et disposition AZERTY/QWERTY. Les hauteurs affichées sont celles de la source, avant transposition de position/séquence. La transposition de lecture est indiquée sous la grille. Les instruments source commencent à 0. Les préférences Source, panneau de paramètres, note de préécoute et sélections des éditeurs sont mémorisées.

Le rapprochement des ordres du lecteur avec les positions source vérifie dimensions, répétitions, séparateurs et identité des patterns partagés. En cas de désaccord ou structure inconnue, la source n’est pas éditable depuis la grille. Les séparateurs de séquence n’ont pas de cellule source. La représentation traduite est conservée avec le commutateur Source désactivé ; elle reste en consultation. Le détail sous la grille indique les coordonnées source exactes ; une édition affecte toutes leurs occurrences.

**Note et effet…** développe les contrôles sous la grille. Une cellule contient une commande : choisir un effet remplace la note présente dans cette cellule. Effets proposés : glissements de volume et de hauteur, vitesse, trémolo et vibrato. Leurs plages et approximations sont expliquées dans l’interface. Les commandes DSP, spéciales et paramètres hors des plages prises en charge restent protégés, y compris contre effacement/collage. **SPxx** indique un paramètre de note spécialisé, et non un volume. Le volume de note 0 conserve le niveau précédent ; il ne signifie pas silence.

**Majuscule + clic/flèches** étend un bloc. Copier/couper/coller, duplication, déplacement et transposition utilisent les événements source et forment chacun une opération d’historique. Un dépassement, une note hors 0…84 ou une commande protégée annule toute l’opération. Les effets traversés par une transposition restent inchangés ; seuls les événements de note sont transposés. Mélanger le collage ignore les cellules complètement vides, sans fusionner deux commandes. La copie porte l’empreinte de la banque d’instruments ; il faut recopier après un changement de banque, sans remappage implicite. Les samples ne sont pas copiés. Les blocs MOD et SymMOD sont distincts. L’insertion/suppression de lignes reste réservée aux patterns MOD.

La banque d’instruments propose une préécoute native isolée à une hauteur choisie et une enveloppe rendue de deux secondes maximum. La barre de boucle est exprimée en pourcentage du sample source ; elle ne se superpose pas à l’enveloppe temporelle de la préécoute. Les canaux stéréo sont préécoutés séparément ; les étiquettes distinguent mono, stéréo, sustain, virtuel et types spécialisés. Les données PCM et instruments complexes restent protégés. Les éditeurs utilisent la palette de l’application ; les champs de texte gardent leurs commandes de collage après une saisie musicale.

Le suivi des six améliorations et les limites de validation sont dans [docs/SIX_ETAPES.md](SIX_ETAPES.md), [docs/COMPATIBILITE_011.md](COMPATIBILITE_011.md) et [docs/SYMMOD.md](SYMMOD.md).

### Validation 0.11.0

110 tests Swift réussis avec les deux fichiers utilisateur et les dix modules synthétiques ; cinq tests Python supplémentaires du vérificateur indépendant. Contrôle de la saisie dans la grille, de son export (trois octets changés dans une seule cellule), de la préécoute d’instrument, des thèmes clair/sombre et du collage dans les champs après saisie musicale. La validation du rendu dans Symphonie Pro 3.2 sur Amiga reste nécessaire ; elle n’a pas pu être exécutée ici.
