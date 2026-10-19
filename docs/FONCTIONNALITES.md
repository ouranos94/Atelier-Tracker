# Atelier Tracker — Guide complet des fonctions

**Version de référence : 0.12.0, build 19 — 18 octobre 2026.**

Ce document décrit les fonctions disponibles, leur utilisation et leurs limites. La [présentation du projet](../README.MD) contient les prérequis et les commandes de compilation. Les documents des anciennes versions constituent un historique ; ce guide décrit l’état actuel.

## Sommaire

1. [Environnement et interface](#1-environnement-et-interface)
2. [Morceaux, formats et fichiers](#2-morceaux-formats-et-fichiers)
3. [Transport et suivi de lecture](#3-transport-et-suivi-de-lecture)
4. [Partition et saisie musicale](#4-partition-et-saisie-musicale)
5. [Sélections et outils de composition](#5-sélections-et-outils-de-composition)
6. [Composition et effets MOD](#6-composition-et-effets-mod)
7. [Composition et édition SymMOD](#7-composition-et-édition-symmod)
8. [Samples MOD](#8-samples-mod)
9. [Instruments et samples SymMOD](#9-instruments-et-samples-symmod)
10. [Piano-roll SymMOD](#10-piano-roll-symmod)
11. [Entrée MIDI](#11-entrée-midi)
12. [Bibliothèque de samples](#12-bibliothèque-de-samples)
13. [Console et vumètres](#13-console-et-vumètres)
14. [Exports](#14-exports)
15. [Historique et récupération](#15-historique-et-récupération)
16. [Raccourcis](#16-raccourcis)
17. [Données locales et préférences](#17-données-locales-et-préférences)
18. [Compatibilité, tests et fonctions absentes](#18-compatibilité-tests-et-fonctions-absentes)

## 1. Environnement et interface

Atelier Tracker est une application native Swift/SwiftUI, en français, pour **macOS 14 ou ultérieur sur Apple Silicon**. Elle utilise AppKit, AVFoundation et CoreMIDI. Aucun émulateur ou système Amiga n’est nécessaire.

La fenêtre rassemble :

- L’en-tête : titre, ouverture/enregistrement, apparence, bibliothèque, MIDI, éditeurs source, console et export.
- Le panneau gauche : arrangement et instruments.
- Le transport : lecture, temps, navigation et boucles.
- La partition : notes, instruments et effets, outils de composition et vumètres.
- Le panneau droit : propriétés du morceau et de la cellule sélectionnée.
- La partie inférieure : Sample Lab MOD ou accès à la banque Symphonie, puis niveaux Master et état de l’application.

### Thèmes et disposition

**Apparence → Thème**, ou l’icône soleil/lune, propose Clair, Sombre et Système. Le dernier suit l’apparence de macOS.

**Réglages de la partition** permet de choisir la largeur des pistes de 100 à 250 %, une police de 10 à 20 points et la visibilité des panneaux latéraux. Les séparateurs permettent d’ajuster leur largeur. **Réinitialiser l’affichage** restaure les réglages de présentation sans modifier le morceau.

SymMOD propose les vues **Toutes**, par groupes de quatre et **Piste sélectionnée**. À l’ouverture, toutes les pistes sont sélectionnées ; 16 pistes tiennent simultanément avec les réglages initiaux et les panneaux masqués. Un nombre supérieur de pistes, une grande police ou un zoom accru peut nécessiter un défilement horizontal.

Les contrôles principaux disposent de libellés d’accessibilité. Le Canvas SymMOD expose les cellules de la ligne sélectionnée ; les contrôles de position, ligne et piste permettent d’atteindre les autres cellules. Cela ne constitue pas une certification complète d’accessibilité.

## 2. Morceaux, formats et fichiers

### Créer un morceau

**Fichier → Nouveau morceau** crée un MOD vide à quatre pistes. **Charger la démo** ouvre *Neon tides*, composition originale avec quatre instruments générés par le code.

**Fichier → Nouveau SymMOD…** propose :

| Réglage | Valeurs |
| --- | --- |
| Titre | Nom du morceau dans Atelier |
| Pistes | 1 à 32 |
| Lignes par pattern | 16, 32, 64 ou 128 |
| Emplacements d’instruments | 1 à 64 |
| Tempo demandé | 32 à 255 BPM, arrondi à la précision Symphonie |

Le nouveau SymMOD comporte un pattern vide, une position et une séquence de lecture. Le titre du projet Atelier ne doit pas être considéré comme une métadonnée garantie dans chaque export natif SymMOD.

### Ouvrir

**⌘O** ouvre un `.atelier`, un MOD compatible ou un SymMOD. Déposer un morceau sur la fenêtre principale ouvre également le document. Le parcours **Importer un sample** reconnaît les morceaux et les redirige vers l’ouverture complète au lieu de les décoder comme audio.

Les fichiers MOD nommés `mod.nom`, les extensions en majuscules et les signatures reconnues sans extension sont identifiés par leur contenu. Le fichier doit rester conforme au sous-ensemble pris en charge.

Un chargement invalide affiche une erreur et conserve le morceau courant. Remplacer un document modifié propose de l’enregistrer, d’annuler ou d’abandonner ses modifications.

### Enregistrer

Le format de travail recommandé est **`.atelier`** : patterns, instruments, samples, tempo, vitesse et réglages de mixage. Pour SymMOD, le projet conserve la source originale et sa version modifiée, réinterprétée à la réouverture.

**⌘S** enregistre ; **⇧⌘S** choisit une nouvelle destination. L’historique d’annulation n’est pas enregistré dans le projet. Les exports natifs et audio sont décrits en section 14.

## 3. Transport et suivi de lecture

- **Lecture / Pause** démarre, suspend ou reprend à la position actuelle.
- **Arrêt** interrompt le transport ou annule une préparation et remet le temps au début.
- **Depuis la sélection** démarre à la position et à la ligne d’édition.
- **Lire le pattern** joue une fois la position sélectionnée, puis s’arrête.
- La barre temporelle permet de naviguer ; un déplacement pendant la pause conserve la pause.
- Les indicateurs donnent l’état du transport, le temps écoulé, la durée et les coordonnées de lecture.

Choisir une cellule ne déplace pas directement le transport. Le bouton **Suivre** relie la partition à la lecture ; le désactiver permet de parcourir une autre position pendant que le son continue. Le réactiver retrouve la position jouée. Le curseur de lecture et la sélection d’édition restent distincts.

### Boucles

Le sélecteur **Boucle** propose Sans boucle, Pattern ou Sélection A–B. Les boutons A et B mémorisent les temps du transport ; la plage doit durer au moins 20 ms. Un déplacement hors de la boucle la désactive.

La lecture repose sur un rendu préparé en arrière-plan, conservé avec ses repères. Pause/reprise et navigation réutilisent ce rendu ; une modification musicale impose sa reconstruction. Les boucles répètent le PCM déjà rendu, avec des fondus de 2 ms aux bords : les DSP ne sont pas recalculés à chaque passage.

Le moteur MOD s’arrête au premier retour sur une même position/ligne et à cinq minutes maximum. Le moteur SymMOD est borné à trente minutes. Une ligne jamais parcourue par le séquenceur n’est pas un point de départ accessible.

## 4. Partition et saisie musicale

Une cellule représente une ligne sur une piste. Les lignes et les valeurs de tracker sont souvent affichées en hexadécimal : `3F` correspond à la ligne décimale 63. L’inspecteur et les légendes distinguent note, instrument, volume et effet selon le format.

À l’arrêt, le cadre vert désigne la cellule d’édition. Pendant la lecture, les repères de transport indiquent la ligne jouée. Choisir **Source** dans SymMOD affiche les événements d’origine quand leur correspondance est vérifiée ; le mode traduit montre la représentation interne de libopenmpt en consultation.

### Clavier de l’ordinateur

Cliquer la partition lui donne le focus. **Composer → Clavier musical** propose QWERTY ou AZERTY et affiche 24 touches correspondant à deux octaves chromatiques. La disposition utilise les caractères réellement produits par le clavier macOS.

| Disposition | Octave courante | Octave supérieure |
| --- | --- | --- |
| QWERTY | `Z S X D C V G B H N J M` | `Q 2 W 3 E R 5 T 6 Y 7 U` |
| AZERTY | `W S X D C V G B H N J ,` | `A É Z " E R ( T - Y È U` |

**Octave** choisit le registre ; **Avance** règle le nombre de lignes après saisie, de 0 à 16. Le mode **Écriture** permet de saisir des notes ou de se limiter à leur préécoute. Les hauteurs effectivement disponibles restent celles du format : trois octaves en MOD, hauteurs source 0 à 84 en SymMOD.

Les flèches déplacent la sélection et **⌫** efface une cellule ou un bloc lorsque l’édition est autorisée. Les champs de l’inspecteur offrent une saisie à la souris.

## 5. Sélections et outils de composition

Un clic sélectionne une cellule. **Majuscule + clic** ou **Majuscule + flèches** étend un bloc rectangulaire. Les contrôles du panneau Composer permettent aussi de régler sa dernière ligne et sa dernière piste. **⌘A**, avec la partition au premier plan, sélectionne le pattern affiché.

Les outils permettent copie, coupe, collage, effacement, duplication en dessous, déplacement d’une ligne ou d’une piste, et transposition d’un demi-ton ou d’une octave. Le menu Composition propose également la transposition du pattern entier.

| Opération | MOD | SymMOD source |
| --- | --- | --- |
| Coller en remplaçant | Copie tous les champs, y compris les vides | Remplace les événements entiers |
| Coller en mélangeant | Ignore les champs vides ; effet et paramètre restent liés | Ignore les événements vides |
| Presse-papiers | Bloc MOD structuré et texte de consultation | Bloc SymMOD distinct ; banque d’instruments compatible requise |
| Insertion/suppression de lignes | Disponible, sur toutes les pistes ou celles de la sélection | Indisponible |
| Transposition | Trois octaves MOD | Hauteur source 0…84, avant transpositions de l’arrangement |

Un collage hors limites est refusé sans tronquer le bloc. Le texte seul ne se colle pas comme données musicales. Les samples ne voyagent pas avec le bloc : les instruments sont des références aux emplacements du morceau. Après une modification d’instrument SymMOD, recopier le bloc si sa signature de banque n’est plus compatible.

Les déplacements et duplications peuvent remplacer la destination. L’insertion de lignes MOD conserve 64 lignes et retire les dernières lignes décalées hors du pattern ; la suppression ajoute des lignes vides à la fin. Ces gestes sont annulables.

Un pattern utilisé plusieurs fois reste partagé : modifier ses notes affecte toutes ses occurrences. Les structures ou cellules SymMOD protégées font refuser l’opération entière. Les outils musicaux sont désactivés pendant la lecture/préparation ; modifier depuis une pause arrête le transport et invalide le rendu.

## 6. Composition et effets MOD

### Structure et arrangement

Le codec cible les modules à quatre pistes et 31 samples, avec signatures `M.K.`, `M!K!`, `4CHN` ou `FLT4`. Un pattern comporte 64 lignes. La limite de l’application est de 128 positions/patterns.

Dans l’arrangement, **+** ajoute un pattern vide après la position sélectionnée ; **Dupliquer** ajoute une copie indépendante du pattern ; la corbeille retire une position. Au moins une position est conservée. Les patterns déjà partagés par un fichier importé gardent leurs références communes.

Le titre, le tempo et la vitesse sont réglables dans l’inspecteur. Chaque cellule contient une période de note, un numéro de sample et une commande d’effet avec son paramètre.

### Effets interprétés par le moteur MOD

| Commande | Fonction |
| --- | --- |
| `0xy` | Arpège |
| `1xx` / `2xx` | Montée / descente de hauteur |
| `9xx` | Départ du sample à un décalage donné |
| `Axy` | Glissement de volume |
| `Bxx` | Saut de position |
| `Cxx` | Volume de voix, de 0 à 64 |
| `Dxx` | Passage au pattern suivant à une ligne donnée |
| `Fxx` | Vitesse ou tempo |

Les autres effets sont conservés dans le fichier mais ignorés par ce moteur, avec signalement. Les infobulles décrivent les commandes. La mémoire des effets et les particularités de déclenchement ne reproduisent pas toutes les subtilités de ProTracker.

## 7. Composition et édition SymMOD

### Source et représentation du lecteur

Le lecteur utilise **libopenmpt 0.8.9**. Les patterns, positions et instruments affichés dans sa représentation traduite peuvent différer des tables du fichier original : répétitions, transpositions et sauts peuvent générer des entrées supplémentaires.

L’édition intégrée utilise une correspondance vérifiée entre ordre traduit et coordonnées source. Si elle est ambiguë, cette édition n’est pas proposée. Les éditeurs séparés des patterns, instruments et arrangements donnent accès aux structures explicitement interprétées.

Les instruments source sont numérotés **depuis 0**. Une modification de pattern s’applique à toutes ses occurrences ; le compteur Source indique le nombre d’entrées de lecture qui utilisent ce pattern. Un liseré orange et les descriptions de cellule signalent les commandes protégées.

### Événements éditables

| Commande source | Fonction et limites |
| --- | --- |
| `00` | Note, instrument et volume ordinaire : hauteur −1 (sans note) ou 0…84, volume 0…100 |
| `01` / `02` | Glissement de volume montant / descendant, intensité 0…255 |
| `03` / `04` | Glissement de hauteur montant / descendant, intensité 0…255 |
| `09` | Vitesse : 0…31 ; 0 utilise 4 ticks dans le lecteur |
| `0C` | Trémolo : profondeur et vitesse 0…120 |
| `0D` | Vibrato : profondeur 0…15, vitesse 0…120 |
| Arrêt `FE` | Forme canonique d’arrêt utilisée par le piano-roll et le MIDI, affichée `OFF` |

Volume de note 0 conserve le niveau précédent ; ce n’est pas une commande de silence. Les glissements et modulations suivent les approximations du lecteur embarqué ; les vitesses de modulation y utilisent des paliers. Les autres commandes spécialisées et les DSP sont préservés sans édition.

### Arrangement source

L’éditeur permet de modifier, pour les positions ordinaires, le pattern, la première ligne, la longueur, les répétitions, la vitesse et la transposition. Pour les séquences actives, il permet de modifier la plage et la transposition. Les états spéciaux et champs non interprétés restent protégés. Les boucles de séquence sont conservées dans le fichier mais ne sont pas restituées par le lecteur actuel.

Pour les arrangements compacts créés dans Atelier :

- **+** ajoute un pattern vide et sa position à la fin.
- **Dupliquer** copie le pattern source et ajoute une position indépendante.
- **Partager** ajoute une position utilisant le même pattern source.
- La corbeille retire une position ; les patterns non référencés restent présents, sans renumérotation.

L’agrandissement automatique requiert une séquence couvrant toutes les positions, suivie du marqueur de fin ; plafond de 512 positions/patterns. Les arrangements importés plus complexes conservent l’éditeur de leurs champs existants, sans agrandissement automatique. La duplication d’un pattern contenant des commandes protégées est refusée.

Toute modification acceptée reconstruit la représentation de lecture, arrête le transport et invalide ses caches. L’original conservé dans le projet n’est pas réécrit.

## 8. Samples MOD

### Import et propriétés

Choisir un emplacement puis **Importer…** dans Sample Lab, ou le bouton d’ajout d’instrument. WAV, AIFF et les formats audio acceptés par AVFoundation peuvent servir de source. L’import direct MOD accepte une source de 60 secondes maximum, puis la convertit en **mono signé 8 bits à 16 574 Hz**, avec au plus **131 070 points**, soit environ 7,91 secondes. Le surplus est retiré de la copie importée.

L’inspecteur permet de nommer le sample, régler son volume et activer sa boucle. Les limites importées depuis un MOD restent conservées tant qu’elles ne sont pas modifiées. Le remplacement d’un emplacement affecte toutes les notes qui l’utilisent.

### Éditeur Sample Lab

**Éditer** ouvre la forme d’onde agrandie : zoom 1 à 64×, défilement, vue entière, sélection à la souris et contrôles Début/Fin. Les limites sont alignées par multiples de deux points et la fin est exclue.

| Outil | Action |
| --- | --- |
| Tout | Sélectionne le sample entier |
| Garder la sélection | Retire les points avant et après la plage |
| Supprimer la sélection | Joint les parties avant et après la plage |
| Normaliser | Amène la crête de la sélection à la limite 8 bits |
| Retourner | Inverse l’ordre des points |
| Inverser la polarité | Change le signe des points avec saturation aux limites |
| Fondu d’entrée / sortie | Applique un fondu linéaire |
| Boucler la sélection | Définit la boucle depuis la plage sélectionnée |
| Désactiver la boucle | Retire la boucle du sample |

Sans sélection explicite, les traitements de niveau et de sens utilisent tout le sample. Les découpes exigent une sélection. Les poignées A/B permettent de déplacer la boucle ; celle-ci doit comporter au moins quatre points. Après découpe, ses limites sont recalculées ou la boucle est désactivée si elle devient invalide.

### Préécoute

Écouter joue la sélection ou tout le sample à C-3 ; Écouter la boucle répète jusqu’à Arrêter. Le clavier musical de la forme d’onde permet une audition à la hauteur choisie, sans écrire dans le pattern. Les très courts samples bouclés peuvent être maintenus au moins 250 ms pour l’audition au clavier.

C-3 correspond à environ 16 574 Hz dans le moteur PAL avant finetune ; un MOD ne stocke pas une fréquence de lecture fixe comme un WAV. Préécoute, traitements, boucles, sélection et gestes d’édition sont intégrés à l’historique. Le changement de sample et le démarrage du morceau arrêtent la préécoute.

## 9. Instruments et samples SymMOD

### Propriétés d’instrument

Ouvrir **Instruments SymMOD** ou **Ouvrir la banque**. La liste distingue emplacements vides, instruments ordinaires, boucles, instruments virtuels et structures protégées.

Pour un instrument mono ordinaire compatible, les propriétés éditables sont :

- Volume 0…199 : 0 signifie le niveau par défaut 100 ; 101…199 active l’amplification avec compression Symphonie.
- Transposition et accord fin ; une unité d’accord fin vaut 1/128 de demi-ton.
- Prise en compte ou ignorance des transpositions de position et de séquence.
- Boucle continue, départ et longueur en pourcentages fins ; départ + longueur doit rester dans le sample.

Les anciennes limites de boucle sont conservées si elles ne sont pas explicitement changées. Une réécriture utilise la précision fine Symphonie et peut modifier les arrondis du lecteur. Les DSP ne disposent pas d’un éditeur.

### Import et remplacement PCM

Dans **Importer / remplacer…**, saisir le chemin du WAV/AIFF ou déposer un fichier sur le panneau. La conversion utilise AVAudioConverter : **mono 16 bits à 40 460 Hz**, jusqu’à 60 secondes, au plus huit canaux en entrée et douze millions de trames source.

L’import remplace un seul emplacement, réinitialise son accord et sa boucle, et conserve les autres instruments ainsi que les DSP. Il requiert une banque interne mono dont la correspondance sample/instrument est vérifiée. Les banques externes, stéréo ou ambiguës, les conteneurs spécialisés et les instruments virtuels/sustain sont protégés.

L’extraction PCM prend en charge les WAV mono 8/16 bits, le brut signé 8 bits, `16BT`, les blocs delta `-17`/`-18` et la décompression PACK. Ce périmètre d’édition est plus restreint que celui de la lecture native.

### Forme d’onde et deux types d’audition

La **forme PCM source** affiche les vrais points audio. Glisser sélectionne une plage ; Début/Fin précisent ses limites ; **Définir la boucle** les applique à l’instrument. La préécoute de sélection ou de boucle utilise la référence C5 à 40 460 Hz, sans accord ni DSP.

La **préécoute isolée native** joue l’instrument à la note choisie pendant deux secondes maximum, avec ses propriétés interprétées par le lecteur. Son graphique est une enveloppe de niveau rendue, distincte de la forme d’onde PCM. Les canaux stéréo y sont préécoutés séparément.

Les traitements de découpe, normalisation et fondus de Sample Lab MOD ne sont pas proposés au PCM SymMOD.

## 10. Piano-roll SymMOD

Le bouton **Piano** affiche la piste sélectionnée sous forme de grille : temps horizontal, hauteur verticale. Le sélecteur Piste et le zoom permettent de choisir le canal et l’échelle. Les repères restent liés à la sélection du tracker et au transport.

1. Cliquer une case pour choisir une ligne et une hauteur.
2. Choisir l’instrument, la durée et le volume, puis **Ajouter**.
3. Cliquer une note pour afficher ses valeurs.
4. Glisser la note pour la déplacer, ou son bord droit pour changer sa durée.
5. Utiliser les contrôles puis **Appliquer**, ou **Effacer** pour la retirer.

Une piste est monophonique. La durée d’une note existante est déduite du déclenchement suivant, d’un arrêt explicite ou de la fin de position ; elle ne décrit pas son enveloppe ni la queue des DSP. L’édition écrit l’arrêt source `FE`.

Une ligne libre avant la fin de position est nécessaire pour un nouvel arrêt. Les chevauchements et les gestes qui écraseraient des commandes sont refusés intégralement. Un déclenchement à la frontière d’une note peut remplacer son arrêt et servir de limite commune. Une modification de note est une action annulable et affecte les occurrences partagées du pattern.

Le piano-roll est réservé aux positions SymMOD ayant une correspondance source vérifiée ; il n’est pas disponible pour MOD.

## 11. Entrée MIDI

Ouvrir **Clavier MIDI**, choisir une source et un canal ou Tous, puis activer l’entrée. Elle est désactivée au démarrage. Après branchement d’un périphérique, **Actualiser** relit les sources disponibles.

Le jeu est monophonique et utilise l’instrument choisi dans Atelier. La vélocité devient un volume. La plage est MIDI 24…108 en SymMOD, 36…71 en MOD. **Couper les notes** interrompt l’audition ; désactiver l’entrée ferme les ports. Fermer le panneau laisse l’entrée active.

### Saisie pas à pas

À l’arrêt, **Saisie pas à pas** écrit à la sélection et avance selon la quantification choisie : 1, 2, 4 ou 8 lignes. SymMOD utilise des notes et arrêts source ; MOD écrit la note, le sample et un volume `Cxx`.

### Prise quantifiée SymMOD

**Enregistrer une prise SymMOD** démarre depuis la sélection, sans boucle. Instrument, piste et position cible sont fixés pour la prise. Seule cette position est capturée ; l’enregistrement ne traverse pas l’arrangement. Les débuts et fins sont quantifiés à 1/2/4/8 lignes, avec au moins une ligne de durée.

**Terminer et appliquer** arrête le transport et écrit la prise en une seule action annulable. **Annuler la prise** la retire sans changer le morceau. Une prise est limitée à 256 notes. Un changement de source, une collision ou un chevauchement refuse l’ensemble de la prise.

MOD propose la saisie pas à pas, pas cette capture de durée pendant la lecture. La réception CoreMIDI a été testée avec une source virtuelle ; l’usage d’un clavier matériel et sa latence restent à valider. L’application ne propose ni sortie MIDI ni enregistrement audio du microphone.

## 12. Bibliothèque de samples

**Bibliothèque de samples** ouvre un catalogue local. Déposer plusieurs fichiers audio dans le panneau, ou **Ajouter…** puis saisir un chemin.

Les copies sont converties en WAV mono 16 bits à 40 460 Hz, jusqu’à 60 secondes. Un identifiant SHA-256 évite les doublons d’un même contenu converti. Les originaux ne sont ni déplacés ni modifiés.

Fonctions disponibles : recherche par nom insensible à la casse et aux accents, favoris, filtre Favoris, renommage dans le catalogue, préécoute et arrêt. **Utiliser ce sample** charge la copie dans l’emplacement sélectionné du morceau, selon les contraintes du format cible.

Pour MOD, la copie est reconvertie en mono 8 bits à 16 574 Hz et limitée à environ 7,91 secondes. Le parcours MOD direct et celui de la bibliothèque n’ont pas exactement les mêmes contraintes de décodage : la bibliothèque utilise le convertisseur borné décrit en section 9.

La bibliothèque est locale, sans synchronisation cloud. Le panneau actuel ne propose pas de suppression des fichiers du catalogue.

## 13. Console et vumètres

### Source Original ou Console

**Console de mixage → Préparer les pistes** construit un cache temporaire de chaque piste rendue isolément. L’interface affiche l’espace estimé, la progression et l’annulation. Le cache peut être volumineux sur les morceaux longs et multicanaux.

La source **Original** garde le rendu du moteur. La source **Console** permet :

- Volume par piste de 0 à 200 %.
- Balance de gauche à droite, en atténuant un côté de la stéréo existante.
- Muet et solo, avec plusieurs solos possibles ; Muet reste prioritaire.
- Niveau général de 0 à 100 %, également disponible en source Original.
- Remise à zéro des réglages du mixage.

Les gains de console changent pendant la lecture avec un lissage allant jusqu’à 20 ms, sans redémarrage du lecteur. Le passage Original/Console remplace le lecteur à sa position actuelle et peut produire une brève coupure.

Volumes, balances et niveau général sont enregistrés dans `.atelier`. Muet, Solo et la source d’écoute sont temporaires. À la réouverture, préparer puis activer Console pour écouter les réglages des pistes.

### Effets et limites du mixage

La console rend les effets avec chaque piste isolée. Des DSP SymMOD partagés ou non linéaires peuvent donc différer du rendu Original ; aucune équivalence systématique n’est promise. Le cache est invalidé par les modifications musicales. Il est réutilisé à l’arrêt et supprimé à la libération de la session ; une fermeture brutale peut laisser des fichiers temporaires.

### Niveaux

Les vumètres affichent les crêtes des pistes visibles, avec retombée et maintien de crête. L’échelle de présentation va de −48 à 0 dBFS, avec zones verte, jaune et rouge. Ils suivent le temps audio ; l’audition isolée d’un sample ne les alimente pas.

Le bandeau **Master** présente les niveaux gauche/droite et une saturation mémorisée jusqu’à effacement ou remise à zéro du transport. En Console, les mesures suivent les gains ; la sortie d’écoute est limitée à ±1. Les indicateurs ne peuvent pas détecter une saturation déjà inscrite dans le sample ou produite auparavant par un effet.

## 14. Exports

### Tableau des données conservées

| Destination | Données conservées | Limites |
| --- | --- | --- |
| Projet `.atelier` | Composition, samples, paramètres du morceau, mixage, sources SymMOD originales/modifiées | Ni historique d’annulation ni états temporaires Muet/Solo |
| MOD | Notes, effets, samples et boucles du MOD compatible | Quatre pistes ; pas de mixage de console ; patterns inutilisés exclus |
| SymMOD | Source avec changements natifs pris en charge | Pas de réglages de console ; structures spécialisées conservées sans édition |
| WAV mixage | Morceau entier selon la source d’écoute choisie | Audio, sans données d’édition ; limites de durée du moteur |
| WAV séparés | Une piste stéréo par canal avec réglages de console | Nécessite le cache ; différences possibles de DSP partagés |

### Module MOD

**Exporter MOD** produit un module à quatre pistes et 31 samples. Un tempo ou une vitesse initiale non standard doit être inscrit dans des emplacements d’effet libres de la première ligne. Si l’espace manque, l’export est refusé. L’export d’un SymMOD vers MOD est refusé pour éviter une réduction implicite des pistes et événements.

### Module SymMOD

**Exporter SymMOD…** demande un nom et un dossier. Le fichier produit contient les changements source acceptés et les autres blocs préservés ; il est relu avec le décodeur avant écriture. Un nom existant est refusé. Fermer les éditeurs source avant l’enregistrement du projet ou le lancement d’un autre export.

Les fichiers créés ou modifiés ont été testés avec le lecteur embarqué. Cela ne remplace pas leur validation dans Symphonie Pro 3.2 sur Amiga.

### Mixage WAV

**Exporter WAV…** propose un nom et un dossier ; un dossier du Finder peut être déposé sur le champ de destination. Les exports sont **stéréo float32, 44,1 kHz**.

Le mixage complet suit Original avec le niveau général, ou Console avec volumes, balances, Muet et Solo. Le morceau entier est exporté, indépendamment de la boucle et de la sélection de lecture. L’écriture affiche une progression et peut être annulée.

### Pistes séparées

L’export des pistes utilise le cache de console, y compris si l’écoute actuelle est Original. Les fichiers partent de zéro, ont le même nombre de trames et une fin commune, sans queue d’effet supplémentaire. Une piste exclue par Muet/Solo reste présente et silencieuse.

Le dossier comprend aussi `Mixage.json` et `Lisez-moi.txt`. Les pistes se réassemblent pour reproduire le mix Console avant limitation, avec les paramètres fixés au lancement de l’export. Il n’existe pas de fichier distinct de retour DSP partagé.

Les WAV float32 conservent les crêtes dépassant 0 dBFS : ni limitation finale ni normalisation séparée. Leur source reste le rendu interne PCM 16 bits ; float32 n’ajoute pas de précision au décodage. Un nom d’export audio existant est refusé ; les fichiers partiels de l’opération sont retirés en cas d’échec ou d’annulation.

## 15. Historique et récupération

**⌘Z** annule et **⇧⌘Z** rétablit les modifications musicales et les réglages de mixage. L’historique conserve aussi le curseur et les sélections concernés. Un geste continu de curseur ou de poignée est regroupé quand l’outil le prévoit ; une opération de bloc ou une prise MIDI acceptée correspond à une action.

La récupération automatique est distincte du fichier enregistré. Une copie de travail et une copie précédente valide peuvent être conservées après modification. Au lancement suivant, **Restaurer** retrouve le document récupéré et ses sélections ; **Ignorer cette récupération** permet de poursuivre sans le restaurer.

Une restauration ne réécrit pas le fichier enregistré et ne restaure pas l’historique d’annulation. Après récupération, enregistrer explicitement le projet. L’indicateur d’état signale l’activité ou un échec de récupération. La récupération est nettoyée lors des transitions prévues, notamment l’enregistrement et la fermeture normale.

## 16. Raccourcis

Les raccourcis musicaux dépendent du focus et de la disponibilité des outils ; dans un champ de texte, les commandes de presse-papiers gardent leur fonction textuelle.

| Raccourci | Action |
| --- | --- |
| `⌘N` | Nouveau morceau MOD |
| `⌘O` | Ouvrir |
| `⌘S` / `⇧⌘S` | Enregistrer / Enregistrer sous |
| `⌘E` | Ouvrir l’export audio |
| `⌘Z` / `⇧⌘Z` | Annuler / Rétablir |
| `Espace` | Lecture / Pause / Reprise |
| `Échap` | Arrêt / Annulation de préparation |
| `Entrée` | Lire le pattern une fois |
| `⇧Entrée` | Lire depuis la sélection |
| `⌘L` | Activer/désactiver la boucle du pattern |
| `⌥I` / `⌥O` | Placer les repères A / B |
| `Flèches` | Déplacer la sélection dans la partition |
| `Majuscule + clic` ou `Majuscule + flèches` | Étendre un bloc |
| `⌫` | Effacer la sélection éditable |
| `⌘A` | Sélectionner le pattern, avec le focus sur la partition |
| `⌘C` / `⌘X` / `⌘V` | Copier / Couper / Coller |
| `⌘D` | Dupliquer le bloc sous la sélection |
| `⌥⌘↑` / `⌥⌘↓` | Transposer d’un demi-ton |
| `⌘=` / `⌘−` | Élargir / Réduire les pistes |
| `⇧⌘=` / `⇧⌘−` | Agrandir / Réduire les notes |

Nouveau SymMOD, bibliothèque, MIDI et éditeurs source sont accessibles par les menus et boutons sans raccourci dédié.

## 17. Données locales et préférences

| Données | Emplacement ou conservation |
| --- | --- |
| Projets et exports | Destination choisie par l’utilisateur |
| Récupération | `~/Library/Application Support/Atelier Tracker/Recovery/` |
| Bibliothèque de samples | `~/Library/Application Support/AtelierTracker/SampleLibrary/` |
| Préférences | Préférences macOS de l’application |
| Rendus de console | Dossiers temporaires de session |

Les deux dossiers Application Support ont des noms différents dans la version actuelle. La bibliothèque comprend des copies WAV et `library.json`. Elle appartient à l’installation locale et n’est pas incorporée comme catalogue complet aux projets ; les samples chargés sont conservés avec le morceau selon son format.

Les thèmes, disposition de clavier, visibilité et dimensions des panneaux, zoom et certains choix des éditeurs source sont mémorisés. La récupération et le mixage ne doivent pas être confondus avec ces préférences d’interface. Le bouton Suivre et l’état MIDI ne constituent pas des réglages musicaux enregistrés dans le projet.

## 18. Compatibilité, tests et fonctions absentes

### Ce qui reste limité

- Le moteur MOD n’émule ni Paula, ni les filtres Amiga, ni les particularités cycle par cycle.
- Tous les effets MOD ne sont pas joués ; tous les événements, instruments et DSP SymMOD ne sont pas éditables.
- L’édition SymMOD exige une structure reconnue ; les correspondances ambiguës sont protégées.
- Les banques SymMOD complexes peuvent être lisibles sans être remplaçables par l’éditeur PCM.
- Le piano-roll et les prises de durée MIDI sont réservés à SymMOD ; l’enregistrement est monophonique par piste et par prise.
- Pas d’enregistrement audio du microphone, d’hébergement de plug-ins AU/VST, de sortie MIDI ou de synchronisation cloud.
- Pas de liste de fichiers récents intégrée ni de gestion de suppression dans la bibliothèque actuelle.
- Aucune garantie de fidélité identique à pt2-clone ou au logiciel Amiga d’origine.
- Construction ARM64 avec signature ad hoc ; aucune distribution notarisée Apple n’est fournie par les scripts actuels.

### Validation disponible

Le bilan 0.12.0 est de **121 tests Swift et 5 tests d’audit Python réussis**, avec fixtures synthétiques et deux modules locaux de référence. Il couvre notamment codecs, conservation des blocs, lecture, transitions MOD/SymMOD, édition et historique, récupération, mixage/export, PCM, piano-roll, prises MIDI atomiques et réception CoreMIDI virtuelle.

Pour lancer les vérifications standard depuis la racine :

```sh
swift test --build-system native
python3 scripts/test-symmod-audit.py
```

Les tests nécessitant les modules locaux utilisent des variables optionnelles :

```sh
TRACKER_TEST_MOD="/chemin/vers/morceau.mod" \
TRACKER_TEST_SYMMOD="/chemin/vers/morceau.SymMOD" \
swift test --build-system native
```

Sans ces fichiers, certains tests sont ignorés ; le total des tests effectivement exécutés peut donc différer du bilan ci-dessus. Les fichiers utilisateur de validation ne sont pas inclus dans le dépôt.

Le script `scripts/audit-symmod.py` fournit un contrôle structurel indépendant. Ses options historiques de comparaison n’autorisent que certains champs/blocs : ce n’est pas un validateur général de toutes les créations, extensions d’arrangement ou substitutions PCM de la version 0.12.0. Consulter `--help` et le [bilan d’édition](SIX_ETAPES_COMPOSITION.md) avant de l’utiliser.

### Validations restantes

La réouverture des nouveaux exports dans **Symphonie Pro 3.2 sur Amiga**, le clavier MIDI matériel, la latence et le branchement à chaud restent à vérifier. Les tests de lecture du moteur embarqué et de préservation des données n’établissent pas à eux seuls cette compatibilité externe.

Pour les détails de format, consulter [SYMMOD.md](SYMMOD.md), puis les ajouts et limites du [cycle 0.12.0](SIX_ETAPES_COMPOSITION.md). Les crédits et licences tierces sont dans [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
