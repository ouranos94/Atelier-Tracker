# Cycle de composition — six étapes

Suite à la version 0.11.0 :

1. [x] Créer un SymMOD vierge, choisir pistes/patterns et construire un arrangement.
2. [x] Importer/remplacer les samples mono, afficher leur PCM, régler et préécouter une boucle/sélection.
3. [x] Piano-roll synchronisé : déplacement et durée des notes.
4. [x] Entrée MIDI : instrument, vélocité et capture quantifiée.
5. [x] Bibliothèque de samples : recherche, favoris et préécoute.
6. [x] Suivi de lecture verrouillable, occurrences partagées et commandes protégées identifiables.

Les formats et structures non pris en charge restent protégés. La validation par Symphonie Pro 3.2 sur Amiga reste distincte des tests du lecteur embarqué.

## Utilisation et périmètre livré — 0.12.0 (build 19)

### 1. Création et arrangement

Fichier → Nouveau SymMOD : titre, 1…32 pistes, 16/32/64/128 lignes, 1…64 instruments, tempo arrondi à la précision du format. Un pattern et une position sont créés. La barre latérale permet d’ajouter un pattern vide, Dupliquer crée une copie indépendante, Partager ajoute une occurrence du même pattern ; la corbeille retire une position sans renuméroter ni supprimer ses patterns.

L’agrandissement automatique requiert un arrangement compact : une séquence couvrant toutes les positions suivie du marqueur de fin, jusqu’à 512 positions/patterns. Les séquences complexes importées gardent leurs données et leur éditeur de positions existant.

### 2. PCM et boucles

Dans Instruments SymMOD, déposer un fichier audio sur le panneau ou utiliser Importer / remplacer puis saisir son chemin. Conversion AVAudioConverter vers mono 16 bits, 40 460 Hz, maximum 60 secondes. L’import remplace un seul emplacement et réinitialise son accord et sa boucle ; les autres samples et les DSP restent conservés. L’original SymMOD est conservé dans le projet Atelier.

La forme PCM est distincte de l’enveloppe de préécoute native. Glisser pour sélectionner une plage ; Écouter sélection ou Écouter boucle ; Définir la boucle applique ses limites à l’instrument. Les pourcentages de boucle sont arrondis à la précision source. La préécoute PCM utilise la fréquence de référence C5, sans accord ni DSP ; la préécoute isolée native permet d’écouter les propriétés effectives.

Prise en charge PCM : WAV mono 8/16 bits, brut signé 8 bits, 16BT, delta -17/-18 et décompression PACK. Remplacement réservé aux banques internes mono dont la correspondance un sample / instrument est prouvée. Les banques stéréo/externes, conteneurs spécialisés et instruments virtuels/sustain sont conservés sans remplacement PCM. Les sélecteurs système imbriqués ont été retirés de ces panneaux après détection d’un blocage lors des essais graphiques ; chemin et dépôt restent disponibles.

### 3. Piano-roll

Bouton Piano, puis sélectionner une piste. Clic dans la grille : choisir ligne et hauteur ; Ajouter crée la note avec l’instrument sélectionné. Cliquer une note pour ses valeurs ; glisser pour la déplacer, bord droit pour la durée. Les contrôles permettent aussi une saisie précise, Appliquer et Effacer.

Les notes sont monophoniques par piste. La durée d’une note existante est déduite du déclenchement suivant ou d’un arrêt explicite ; les enveloppes et DSP ne sont pas une durée de note. L’édition emploie l’arrêt source FE reconnu par le lecteur. Une ligne libre avant la fin de position est nécessaire. Les chevauchements, événements protégés et remplacements de commandes sont refusés sans édition partielle. Un arrêt à la ligne suivante peut être partagé avec le prochain déclenchement.

### 4. MIDI

Bouton Clavier MIDI : entrée désactivée au démarrage ; choisir source et canal, activer, puis jouer l’instrument et la piste sélectionnés. Jeu monophonique, vélocité convertie en volume. MIDI 24…108 pour SymMOD, 36…71 pour MOD. Actualiser après branchement d’une source. Couper les notes sert d’arrêt immédiat ; désactiver l’entrée ferme les ports. Fermer le panneau laisse l’entrée active.

Saisie pas à pas à l’arrêt, quantification 1/2/4/8 lignes. Enregistrer une prise SymMOD démarre depuis la sélection et capture uniquement cette position, sans boucle ; une prise ne traverse pas les positions. Terminer et appliquer arrête le transport et écrit toute la prise en une seule opération annulable. Annuler la prise garde le morceau intact. Prises limitées à 256 notes ; source modifiée, chevauchement ou collision refusent toute la prise. Le MOD dispose de la saisie pas à pas, pas de capture de durée en lecture.

La réception réelle CoreMIDI a été vérifiée avec une source virtuelle émettant des MIDIPacketList ; le clavier matériel, sa latence et le branchement à chaud restent à vérifier sur matériel.

### 5. Bibliothèque

Copies WAV normalisées dans Application Support/AtelierTracker/SampleLibrary, catalogue JSON atomique et identification SHA-256 pour éviter les doublons. Déposer plusieurs WAV/AIFF ou Ajouter avec un chemin ; recherche insensible aux accents et à la casse, favoris, renommage et préécoute. Utiliser charge la copie dans l’instrument choisi ; les contraintes du format cible s’appliquent (MOD : mono 8 bits / 16 574 Hz / 7,91 s). Aucun fichier source n’est déplacé ou supprimé.

### 6. Lisibilité de la lecture

Suivre relie la vue au transport. Désactiver permet la consultation d’une autre position sans déplacer ni reconstruire la lecture ; réactiver retrouve sa position actuelle. Le curseur de lecture est distinct de la sélection. Le compteur Source indique combien d’entrées de lecture utilisent ce pattern ; ses modifications sont partagées. Un liseré orange signale les commandes source protégées, également nommées dans l’inspecteur et l’accessibilité. Les arrêts éditables affichent OFF.

## Validation

121 tests Swift réussis avec TheSecret et After The Storm : création 1/4/16/32 pistes, arrangements, audio PCM, blocs préservés, exports et projets, annulation, collisions, arrêts audibles, piano et prise MIDI atomiques, CoreMIDI virtuel, bibliothèque et suivi sans mutation du transport. Les 5 tests Python d’audit réussissent aussi. La sauvegarde de récupération est attendue par sa tâche dans le test concerné, sans délai arbitraire.

Les fichiers utilisateur ne sont ni modifiés ni distribués. La réouverture des nouveaux fichiers dans Symphonie Pro 3.2 sur Amiga n’a pas été testée ; le chargement, le rendu et la relecture des exports sont validés avec le lecteur natif embarqué. La structure -3 ambiguë n’est pas produite par le créateur.
