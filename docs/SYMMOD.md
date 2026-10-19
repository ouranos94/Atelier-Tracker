# SymMOD : édition source (0.8.0 et 0.9.0)

## Périmètre vérifié

Le conteneur visé porte `SymM`, une version binaire 1, puis le bloc −1 indiquant le nombre de pistes. Cette version de conteneur ne donne pas la version de l’application qui a créé le fichier : elle ne permet pas de certifier à elle seule Symphonie Pro 3.2.

Le corpus local comprend **TheSecret.SymMOD**, fourni par l’utilisateur, et des fichiers de test synthétiques (structures, compression, limites et erreurs). Le fichier utilisateur reste hors du dépôt. TheSecret contient 16 pistes, 128 lignes par pattern et 128 patterns source. Les 111 patterns et 151 positions affichés dans la grille principale proviennent de la traduction du lecteur ; ils ne sont pas les indices de la table de patterns source.

La référence de structure est le [chargeur officiel OpenMPT/libopenmpt 0.8.9](https://github.com/OpenMPT/openmpt/blob/libopenmpt-0.8.9/soundlib/Load_symmod.cpp), sous licence BSD 3-Clause, dont la licence est distribuée avec l’application. Le lecteur natif libopenmpt sert à relire les fichiers produits par l’écrivain Swift. Aucun contrôle dans Symphonie Pro sur Amiga n’a été effectué : la validation dans le logiciel d’origine et l’extension du corpus restent à faire.

## Conservation et structure

Les nombres sont en big-endian. Les blocs de valeurs −1 à −7, ainsi que 10, 11 et 12, ont une valeur de 32 bits. −12 marque un sample vide et n’a pas de longueur ni de payload. Les blocs binaires connus −10, −11, −13 à −21 sont précédés d’une longueur de 32 bits. Une structure inconnue arrête l’analyse : le reste est conservé comme données opaques et l’édition est désactivée pour ce fichier.

L’archive conserve le fichier intégral. Sans modification, son encodage est **identique octet pour octet**, y compris la compression. Une modification d’un événement non compressé ne change que les octets de cette cellule. Si les événements sont compressés, seul leur bloc est remplacé par son équivalent non compressé ; les autres blocs restent identiques, dans leur ordre d’origine. Les champs inutilisés, samples, instruments, messages, séquences et DSP ne sont pas reconstruits.

La compression de blocs commence par `PACK FF FF`, puis la longueur décompressée sur 32 bits. Les opérations prises en charge sont la copie littérale (0), la répétition d’un mot de quatre octets (1), sa copie double (2), l’insertion de zéros (3), et la fin (FF). Une longueur incohérente, un opcode inconnu ou un bloc incomplet est refusé. La décompression de chaque table est limitée à 16 Mio ; les fichiers sont limités à 64 Mio. Les doublons de tables ou de valeurs structurantes sont refusés pour l’édition.

## Coordonnées et événements

−2 indique la hauteur des patterns ; −5 doit indiquer des événements de quatre octets. Le bloc −13 contient les événements, dans cet ordre : pattern, ligne, piste. L’offset est `((pattern × lignes + ligne) × pistes + piste) × 4`.

Un événement comporte **commande non signée / hauteur signée / paramètre non signé / instrument non signé**. Les instruments source commencent à zéro, contrairement aux numéros traduits de la grille principale. L’éditeur affiche les hauteurs selon l’échelle du lecteur, avant transposition : la hauteur source 0 correspond à C-2 dans cette représentation. Les commandes spécialisées apparaissent sous la forme FXxx avec leurs octets.

Ce lot autorise uniquement les événements de note ordinaires : commande 0, hauteur −1 (absence de note) ou 0…84, paramètre-volume 0…100, instrument existant. Une cellule portant une commande spécialisée ou un paramètre de contrôle reste en consultation seule. Effacer remplace un événement ordinaire par `00 FF 00 00`. Les données d’une commande DSP ne peuvent pas être écrasées par ce bouton.

La table de positions −10 utilise des enregistrements de 32 octets : répétitions à +4, pattern à +8, première ligne à +10, longueur à +12, vitesse à +14 et transposition signée à +16. La table de séquences −15 utilise des enregistrements de 16 octets : début, longueur, boucles, information et transposition signée. Elles sont consultées pour expliquer les références et restent conservées.

Le lecteur peut fabriquer un pattern distinct pour chaque combinaison de pattern source, début, longueur, vitesse et transposition de position/séquence. Il peut aussi traduire les effets, synthétiser des événements de synchronisation et les partenaires stéréo. L’application **ne déduit pas** une coordonnée source à partir d’une cellule traduite. L’éditeur source est donc distinct de la grille de lecture. Un pattern source partagé modifie toutes les occurrences qui l’emploient, y compris un extrait débordant depuis le pattern précédent.

## Projet, lecture et export

Le projet Atelier conserve séparément la source originale (`source`) et, après édition, la source modifiée (`editedSource`). Un ancien projet sans ce champ reste lisible. Le moteur et les rendus de console utilisent la source modifiée lorsqu’elle existe. La grille traduite est recalculée à partir de ces octets, et non sauvegardée comme substitut du fichier natif. L’annulation/rétablissement et la récupération automatique conservent les deux sources.

Une édition arrête la lecture et invalide les caches audio. Il faut relancer pour entendre le résultat. L’édition est désactivée pendant la lecture, une préparation ou un export ; elle est possible en pause. L’export SymMOD écrit les données réellement modifiées, après relecture par libopenmpt. Sans édition, il écrit la source exacte. Un nom déjà utilisé est refusé, le projet courant et le fichier importé restent inchangés.

Les volumes, balances, Muet/Solo et le niveau général de console ne sont pas des modifications d’événements Symphonie : ils ne sont pas inscrits dans un export SymMOD. Le projet Atelier et les exports WAV portent ces réglages selon leurs règles habituelles.

## Limites du premier lot 0.8.0 et suite

Les blocs MOD et le clavier de composition de la grille principale ne sont pas étendus aux événements Symphonie. Pas d’édition des instruments, samples, séquences, répétitions, transpositions, filtres, délais ou DSP dans ce premier lot. Les effets complexes conservent leur représentation d’origine. Les fichiers chargés par libopenmpt mais refusés par l’analyse stricte restent lisibles dans la grille principale.

La suite du chantier doit couvrir davantage de modules, comparer avec Symphonie Pro 3.2, puis introduire l’édition de ces structures avec des garanties de conservation équivalentes. Les cases générales de l’étape 6 ne sont pas toutes réalisées par cette livraison.


## Instruments mono — lot 0.9.0

Le bloc −14 contient des enregistrements de 256 octets. Le nom ou la structure virtuelle occupe les 128 premiers octets. L’éditeur distingue les indices source des samples créés ou dupliqués par libopenmpt. Il refuse les enregistrements vides, les signatures ViRT, les canaux autres que mono et les types autres que normal (0) ou boucle continue (4), ainsi que les volumes hors domaine.

Champs concernés, offsets relatifs à l’enregistrement : type signé +128 ; début/longueur entiers +129/+130 ; canal +132 ; volume +134 ; accord fin signé +138 ; transposition signée +139 ; flags de sample +140 ; flags d’instrument +142 ; fractions de boucle big-endian +150/+152. Le volume accepte 0…199 : 0 a le sens de valeur par défaut, 101…199 déclenche la compression native. L’accord fin est exprimé en 1/128 de demi-ton ; les deux champs d’accordage signés gardent la plage −128…127.

Seul le bit 0 de +142 est éditable : il ignore les transpositions de position/séquence. Le bit NoDSP et tous les autres bits sont conservés. La boucle fine utilise `(entier << 16) + fraction`, avec 100 % représentés par `100 << 16`. Une modification de limites active le bit 16 (valeur 0x10) des flags de sample, en préservant les autres bits ; le lecteur convertit ensuite les pourcentages en points. L’ancien système de boucle a des règles d’arrondi et de recherche de fin différentes. Les encodages sont conservés lors d’un changement de volume/accordage ou d’une application sans changement. Désactiver la boucle ne modifie que son type.

La banque non compressée est modifiée dans le seul enregistrement choisi. Une banque compressée est décompressée puis réémise comme bloc −14 non compressé, sans reconstruire les autres blocs. Les éditions successives de notes et d’instruments utilisent toujours la dernière source modifiée. La source importée reste séparée, comme dans le lot 0.8.0. Les banques virtuelles, paires stéréo, sustain, filtres et PCM restent hors périmètre éditable de ce lot.

## Écriture de l’arrangement (0.10.1)

Les positions (`-10`) sont des enregistrements de 32 octets, les séquences (`-15`) de 16 octets, en big-endian. Layout et interprétation sont vérifiés dans le [lecteur OpenMPT 0.8.9](https://raw.githubusercontent.com/OpenMPT/openmpt/libopenmpt-0.8.9/soundlib/Load_symmod.cpp).

| Table | Offsets modifiables | Conservés |
| --- | --- | --- |
| Position | 4 : répétitions u16 ; 8 : pattern u16 ; 10 : première ligne u16 ; 12 : longueur u16 ; 14 : vitesse u16 ; 16 : transposition i16 | 0…3 : données internes ; 6…7 : compteur de lecture ; 18…31 : événements par ligne et réserves |
| Séquence active | 0 : première position u16 ; 2 : longueur u16 ; 8 : transposition i16 | 4…5 : boucle ; 6…7 : état signé ; 10…15 : réserves |

L’état −1 termine la lecture des séquences ; 1 indique une séquence ignorée ; seul l’état ordinaire 0 avant la fin est éditable. Les positions utilisent `max(1, répétitions)` ; les boucles de séquence sont ignorées par le lecteur et restent protégées. La transposition d’instrument peut neutraliser les transpositions de position/séquence. L’éditeur limite les positions aux plages dans un même pattern et aux vitesses 1…31, répétitions 0…16, transpositions −24…24. Les plages actives sont vérifiées avant l’appel natif, avec une limite d’expansion de 4 096 positions / 1 000 000 de lignes / 4 000 000 de cellules jouées. Les erreurs de décodage/validation ne modifient ni projet ni historique.

Les tables conservent leurs indices et tailles logiques. Si compressées, elles sont décompressées pour la réécriture ; une opération sans changement garde les octets PACK d’origine. Les autres blocs et les champs réservés sont préservés. Pas d’insertion/suppression ni d’édition des marqueurs. La grille traduite, la durée et les caches sont reconstruits après changement ; les sélections sont bornées après raccourcissement et pendant l’historique. Voir README pour le parcours utilisateur et les limites de compatibilité.

## Composition intégrée (0.11.0)

La métadonnée optionnelle `orderSource` est recalculée depuis les octets lus, jamais supposée depuis le numéro de pattern traduit. Le rapprochement reproduit l’expansion des positions/répétitions et séparateurs, puis vérifie le nombre d’ordres, les longueurs et la correspondance bidirectionnelle des clés de positions avec les indices natifs. Un échec retire l’édition intégrée ; le lecteur reste disponible. Un séparateur n’a pas de cellule source. Les plages qui traversent un pattern sont converties en coordonnées linéaires puis en pattern/ligne source. Les anciens projets sans métadonnée restent lisibles et sont reconstruits à l’ouverture.

L’écriture groupée vérifie tous les événements et toutes les coordonnées avant remplacement du bloc `-13`. Les opérations ont un unique instantané d’historique. Événements proposés : note/volume (0), glissements de volume (1/2), de hauteur (3/4), vitesse (9), trémolo (12), vibrato (13). Les autres commandes et paramètres spécialisés de KeyOn restent protégés. Les octets inutilisés des effets sont préservés ; vitesse et profondeur de modulation utilisent les champs natifs, sans instrument implicite. Les paramètres et approximations du lecteur sont indiqués dans l’interface ; ces opérations n’ajoutent pas une seconde commande dans une cellule.

Les blocs SymMOD possèdent un type de presse-papiers distinct, des dimensions bornées et une empreinte SHA-256 des enregistrements d’instruments. Le collage ne copie pas les sons et ne convertit ni MOD ni texte. Une cellule protégée, un dépassement ou une transposition hors 0…84 refuse tout le geste. Le mélange ignore les événements vides et ne fusionne pas deux effets. Les événements d’effets traversés par une transposition gardent leurs octets.

La préécoute déclenche un instrument par l’interface interactive native avec les pistes du morceau coupées. Son enveloppe est issue du PCM stéréo rendu (maximum deux secondes), pas des données audio source. Les coordonnées de boucle ont donc une barre distincte en pourcentage. Annulation, changement d’instrument ou de fichier invalident les travaux encore en cours. Les canaux stéréo sont préécoutés séparément ; aucune édition PCM n’est ajoutée.

Le corpus reproductible et les contrôles indépendants sont décrits dans `COMPATIBILITE_011.md`. Ils ne remplacent pas les essais dans Symphonie Pro sur Amiga.
