# AzerothCore Playerbots — Docker et Podman

Environnement Compose validé avec Docker et Podman pour compiler et exécuter
AzerothCore WoW 3.3.5a, la branche Playerbot, 52 modules additionnels et trois
scripts Lua personnalisés.

Les images de compilation et d'exécution reposent sur Ubuntu 26.04. Le core
est compilé avec Clang 20, conformément à la plateforme CI prise en charge par
AzerothCore.

## Prérequis

- Docker Engine avec Docker Compose v2 (`docker compose`), **ou**
- Podman avec un fournisseur Compose (`podman compose`, testé avec
  `podman-compose` 1.6)
- GNU Make pour les raccourcis `make` (optionnel)

## Installation

```bash
./scripts/init-env.sh
```

Cette commande crée un `.env` en mode `0600` avec trois secrets aléatoires.
Vérifiez ensuite au minimum :

```env
BIND_ADDRESS=127.0.0.1
REALMLIST_IP=127.0.0.1
BUILD_JOBS=4
```

Puis construisez et démarrez la plateforme avec Docker :

```bash
make up
```

Avec Podman :

```bash
podman compose up -d --build
```

Les scripts et le `Makefile` détectent automatiquement Docker Compose ou
Podman Compose. Pour imposer un moteur, définissez `COMPOSE_COMMAND`, par
exemple `COMPOSE_COMMAND="podman compose" make up`.

Le premier lancement est long : Docker clone 52 modules, compile le core,
importe les bases et télécharge les données client.

```bash
make status
make logs
```

Avec Podman :

```bash
podman compose ps
podman compose logs -f authserver worldserver
```

Les services one-shot affichés comme `Exited (0)` ont terminé normalement. Les
services permanents `database`, `authserver` et `worldserver` doivent être
`healthy` après l'initialisation. La première création des Playerbots peut
prendre plusieurs minutes.

Validez ensuite l'installation complète :

```bash
make health
make diagnose
```

`make health` doit se terminer par `Healthcheck: OK`. Sous Podman, ces scripts
fonctionnent avec le paquet de compatibilité `podman-docker`.

## Architecture

| Service | Rôle | Persistance |
|---|---|---|
| `database` | MySQL 8.4 | volume `database` |
| `database-init` | création des quatre bases et de l'utilisateur applicatif | one-shot |
| `database-preflight` | détection des collisions SQL de Portals/Rare Drops | one-shot |
| `client-data` | téléchargement des DBC/maps/vmaps/mmaps | volume `client-data` |
| `db-import` | migrations du core et des modules | one-shot |
| `database-post-import` | synchronisation idempotente des schémas et données des modules | one-shot |
| `realm-init` | configuration de `realmlist` | one-shot |
| `authserver` | authentification WoW | conteneur permanent |
| `worldserver` | serveur de jeu, Playerbots et modules | conteneur permanent |
| `operations` | comptes, GM, AHBot, santé, métriques et diagnostic | profil outils |

Les bases, données client, configurations et logs sont placés dans des volumes
Compose. Recréer une image ou un conteneur ne supprime donc pas les données.

## Variables principales

`./scripts/init-env.sh` génère les secrets et reprend les valeurs documentées
dans `.env.example`. Les variables les plus importantes sont :

| Variable | Rôle | Valeur conseillée |
|---|---|---|
| `BIND_ADDRESS` | interface exposant les ports jeu | `127.0.0.1` en local, `0.0.0.0` sur le LAN |
| `REALMLIST_IP` | adresse communiquée au client WoW | IP réellement joignable par le client |
| `BUILD_JOBS` | compilations C++ parallèles | `4`, à réduire si la RAM est limitée |
| `DB_BACKUP_RETENTION` | nombre de sauvegardes conservées | `7`, ou `0` pour tout conserver |
| `ALE_LUA_VERSION` | moteur Lua compilé pour ALE | `lua52` |

## Modules inclus

Les 52 modules suivants sont clonés lors du build. Les modules C++ sont intégrés
à `worldserver` ; les modules SQL-only sont appliqués pendant l'import de la base :

| # | Module | Fonction | Dépôt |
|---:|---|---|---|
| 1 | `mod-playerbots` | Ajoute les joueurs contrôlés par IA et leur base dédiée. | [mod-playerbots/mod-playerbots](https://github.com/mod-playerbots/mod-playerbots) |
| 2 | `mod-ah-bot-plus` | Vend et achète aux hôtels des ventes avec prix, stocks, catégories et plusieurs personnages vendeurs configurables. | [NathanHandley/mod-ah-bot-plus](https://github.com/NathanHandley/mod-ah-bot-plus) |
| 3 | `mod-autobalance` | Adapte les donjons et raids aux groupes réduits ou au jeu solo. | [azerothcore/mod-autobalance](https://github.com/azerothcore/mod-autobalance) |
| 4 | `mod-aoe-loot` | Permet de ramasser en une fois le butin des créatures proches. | [azerothcore/mod-aoe-loot](https://github.com/azerothcore/mod-aoe-loot) |
| 5 | `mod-learn-spells` | Apprend automatiquement les sorts de classe pendant la progression. | [azerothcore/mod-learn-spells](https://github.com/azerothcore/mod-learn-spells) |
| 6 | `mod-solo-lfg` | Permet les groupes incomplets, mais reste désactivé dans le profil fourni afin que les Playerbots remplissent normalement les cinq rôles du Dungeon Finder. | [azerothcore/mod-solo-lfg](https://github.com/azerothcore/mod-solo-lfg) |
| 7 | `mod-challenge-modes` | Propose par personnage des défis de progression : Hardcore, Semi-Hardcore, Self Crafted, qualité limitée, XP réduite/quête uniquement et Iron Man, avec récompenses de paliers. | [ZhengPeiRu21/mod-challenge-modes](https://github.com/ZhengPeiRu21/mod-challenge-modes) |
| 8 | `mod-player-bot-level-brackets` | Contrôle la distribution des niveaux des Playerbots par tranches. | [DustinHendrickson/mod-player-bot-level-brackets](https://github.com/DustinHendrickson/mod-player-bot-level-brackets) |
| 9 | `mod-junk-to-gold` | Vend automatiquement les objets gris au moment où le joueur les ramasse. | [kadeshar/mod-junk-to-gold](https://github.com/kadeshar/mod-junk-to-gold) |
| 10 | `mod-rare-drops` | Ajoute par SQL du butin vert ou bleu thématique aux 450 créatures rares classiques de Kalimdor et des Royaumes de l'Est. | [StraysFromPath/mod-rare-drops](https://github.com/StraysFromPath/mod-rare-drops) |
| 11 | `mod-transmog-plus` | Ajoute la transmogrification étendue (collections, formes, illusions et sacs) avec un PNJ placé dans chacune des huit capitales. | [buildthehomelab/wow-mod-transmog-plus](https://github.com/buildthehomelab/wow-mod-transmog-plus) |
| 12 | `mod-reagent-bank-account` | Ajoute une banque de composants par personnage, avec stockage et exclusions configurables, et les PNJ placés dans les principales villes. | [buildthehomelab/mod-reagent-bank-account](https://github.com/buildthehomelab/mod-reagent-bank-account) |
| 13 | `mod-daily-reset` | Ajoute directement la commande `.daily reset`, sans option de configuration, pour réinitialiser les quêtes journalières et instances du joueur. | [binboupan/mod-daily-reset](https://github.com/binboupan/mod-daily-reset) |
| 14 | `mod-mount-scaling` | Fait évoluer progressivement la vitesse des montures avec le niveau. | [claudevandort/mod-mount-scaling](https://github.com/claudevandort/mod-mount-scaling) |
| 15 | `mod-ale` | Fournit le moteur Lua AzerothCore utilisé par les scripts serveur. | [azerothcore/mod-ale](https://github.com/azerothcore/mod-ale) |
| 16 | `mod-quest-loot-party` | Partage les objets de quête admissibles entre membres du groupe. | [pangolp/mod-quest-loot-party](https://github.com/pangolp/mod-quest-loot-party) |
| 17 | `mod-TimeIsTime` | Permet de régler la vitesse du cycle jour/nuit. | [dunjeon/mod-TimeIsTime](https://github.com/dunjeon/mod-TimeIsTime) |
| 18 | `mod-boss-announcer` | Annonce les victoires sur les boss ; les annonces de wipe sont désactivées dans le profil fourni. | [azerothcore/mod-boss-announcer](https://github.com/azerothcore/mod-boss-announcer) |
| 19 | `mod-duel-reset` | Réinitialise vie, ressources et cooldowns admissibles autour des duels. | [azerothcore/mod-duel-reset](https://github.com/azerothcore/mod-duel-reset) |
| 20 | `NoProfessionLimit` | Autorise jusqu'aux 11 professions principales de WotLK ; la limite native du core est également fixée à 11. | [AlsoNotMehh/NoProfessionLimit](https://github.com/AlsoNotMehh/NoProfessionLimit) |
| 21 | `mod-no-hearthstone-cooldown` | Supprime immédiatement le cooldown de la pierre de foyer. | [BytesGalore/mod-no-hearthstone-cooldown](https://github.com/BytesGalore/mod-no-hearthstone-cooldown) |
| 22 | `mod-autofish` | Automatise la capture, le butin et la relance de la pêche. | [Flerp/mod-autofish](https://github.com/Flerp/mod-autofish) |
| 23 | `mod-skip-dk-starting-area` | Permet, selon sa configuration, de passer automatiquement ou facultativement la zone de départ des chevaliers de la mort. | [d23monkey/mod-skip-dk-starting-area](https://github.com/d23monkey/mod-skip-dk-starting-area) |
| 24 | `mod-gunship-skip` | Ajoute sur Muradin/Saurfang une option solo qui termine la Canonnière ICC, distribue son butin par courrier et téléporte après le combat. | [BlaMacfly/mod-gunship-skip](https://github.com/BlaMacfly/mod-gunship-skip) |
| 25 | `portals-in-all-capitals` | Ajoute automatiquement par SQL 24 portails près des entraîneurs de mages et de portails des capitales. | [azerothcore/portals-in-all-capitals](https://github.com/azerothcore/portals-in-all-capitals) |
| 26 | `mod-gain-honor-guard` | Accorde de l'honneur pour les gardes et/ou élites non gris, hors arène et joueur vivant, avec taux, annonces et partage de groupe configurables. | [azerothcore/mod-gain-honor-guard](https://github.com/azerothcore/mod-gain-honor-guard) |
| 27 | `mod-dungeon-master` | Ajoute des donjons procéduraux jouables seul ou en groupe, avec difficulté, thèmes, mise à l'échelle, récompenses et mode roguelike à affixes. | [InstanceForge/mod-dungeon-master](https://github.com/InstanceForge/mod-dungeon-master) |
| 28 | `mod-dungeon-questgivers` | Place un Émissaire des quêtes neutre à l'entrée de 49 donjons à cinq joueurs afin d'y proposer directement les quêtes associées ; les PNJ et lieux de restitution d'origine restent inchangés. | [and-elf/mod-dungeon-questgivers](https://github.com/and-elf/mod-dungeon-questgivers) |
| 29 | `mod-auto-gather` | Récolte automatiquement à proximité les plantes, minerais et créatures dépeçables admissibles, tout en conservant les prérequis et gains de compétence. | [thanhtong89/mod-auto-gather](https://github.com/thanhtong89/mod-auto-gather) |
| 30 | `DungeonRespawn` | Après libération de l'esprit dans un donjon ou raid classique, ressuscite le joueur à 50 % de vie et le replace à l'entrée enregistrée. | [riksbyville/DungeonRespawn](https://github.com/riksbyville/DungeonRespawn) |
| 31 | `mod-multibot-bridge` | Fournit à l'addon client MultiBot-Chatless un pont structuré vers Playerbots afin d'actualiser son interface sans analyser les réponses du chat. | [Wishmaster117/mod-multibot-bridge](https://github.com/Wishmaster117/mod-multibot-bridge) |
| 32 | `mod-npc-enchanter` | Ajoute un PNJ qui applique des enchantements à l'équipement, placé près des entraîneurs d'enchantement dans les huit capitales. | [azerothcore/mod-npc-enchanter](https://github.com/azerothcore/mod-npc-enchanter) |
| 33 | `mod-optimal-bot-raid` | Assemble et téléporte des groupes ou raids optimisés de 5 à 40 Playerbots avec répartition des rôles, synergies de buffs et niveaux configurables via `.botraid`. | [barnaclebarry/mod-optimal-bot-raid](https://github.com/barnaclebarry/mod-optimal-bot-raid) |
| 34 | `mod-level-one-mounts` | Rend la compétence de monte initiale et une sélection de montures terrestres accessibles dès le niveau 1 à prix réduit. | [tomcoffingiii/mod-level-one-mounts](https://github.com/tomcoffingiii/mod-level-one-mounts) |
| 35 | `mod-npc-all-mounts` | Ajoute « The Mountain », un PNJ capable d'enseigner les montures disponibles, placé près de l'entraîneur de portails dans chacune des huit capitales. | [azerothcore/mod-npc-all-mounts](https://github.com/azerothcore/mod-npc-all-mounts) |
| 36 | `mod-increased-ghost-speed` | Multiplie par `2` la vitesse de course et de nage des joueurs libérés en fantôme, sans modifier leur vitesse lorsqu'ils sont vivants. | [TheTollski/mod-increased-ghost-speed](https://github.com/TheTollski/mod-increased-ghost-speed) |
| 37 | `mod-dungeon-clear` | Permet à un tank Playerbot de conduire automatiquement le groupe dans les donjons : navigation, pulls, boss, portes, butin, repos et récupération après combat. | [jrad7/mod-dungeon-clear](https://github.com/jrad7/mod-dungeon-clear) |
| 38 | `mod-guildhouse` | Ajoute une maison en phase propre à chaque guilde, achetable puis aménageable avec PNJ, services et portails. | [azerothcore/mod-guildhouse](https://github.com/azerothcore/mod-guildhouse) |
| 39 | `mod-player-bot-guildhouse` | Envoie périodiquement des Playerbots de guilde dans leur maison et les en fait ressortir sans déplacer les bots des guildes sans joueur humain connecté. | [DustinHendrickson/mod-player-bot-guildhouse](https://github.com/DustinHendrickson/mod-player-bot-guildhouse) |
| 40 | `mod-individual-progression` | Réintroduit une progression Vanilla, TBC puis WotLK individuelle par personnage, avec phases, niveaux plafonnés, attunements et contenu historique. | [ZhengPeiRu21/mod-individual-progression](https://github.com/ZhengPeiRu21/mod-individual-progression) |
| 41 | `mod-assistant` | Ajoute un PNJ Assistant dans les capitales, offrant héritages, glyphes, gemmes, consommables, changements de personnage, métiers, trajets aériens et réinitialisation d’instances selon configuration. | [noisiver/mod-assistant](https://github.com/noisiver/mod-assistant) |
| 42 | `mod-flightpath-discovery` | Ajoute des tableaux près des maîtres de vol pour acheter et apprendre des trajets voisins configurés, sans téléportation. | [bl1tzkr13g/mod-flightpath-discovery](https://github.com/bl1tzkr13g/mod-flightpath-discovery) |
| 43 | `mod-forever-hunter` | Ajoute l’échelle des familiers, Lone Wolf, Summon Hawk, la retenue des familiers en donjon et les effets Hunter de Shadowstrike/Thunderstrike. | [buildthehomelab/wow-mod-forever-hunter](https://github.com/buildthehomelab/wow-mod-forever-hunter) |
| 44 | `mod-raid-clear` | Ajoute des stratégies Playerbot spécialisées pour les raids, les boss et les mécaniques de raid. | [buildthehomelab/wow-mod-raid-clear](https://github.com/buildthehomelab/wow-mod-raid-clear) |
| 44a | `mod-lost-legendaries` | Réintroduit plusieurs objets légendaires oubliés dans les raids et quêtes. | [buildthehomelab/wow-mod-lost-legendaries](https://github.com/buildthehomelab/wow-mod-lost-legendaries) |
| 44b | `mod-forever-rogue` | Conserve les points de combo du voleur lors des changements de cible. | [buildthehomelab/wow-mod-forever-rogue](https://github.com/buildthehomelab/wow-mod-forever-rogue) |
| 44c | `mod-forever-periodic-crit` | Autorise les critiques des ticks DoT/HoT selon les règles WoW Forever. | [buildthehomelab/wow-mod-forever-periodic-crit](https://github.com/buildthehomelab/wow-mod-forever-periodic-crit) |
| 45 | `mod-lfg-progression` | Verrouille la file LFG selon la progression Vanilla/TBC/WotLK du personnage et des Playerbots. | [buildthehomelab/wow-mod-lfg-progression](https://github.com/buildthehomelab/wow-mod-lfg-progression) |
| 46 | `mod-forever-journal` | Ajoute un journal en jeu des donjons, monstres, quêtes, butin, apparences et lore. Remplace `mod-npc-finder`. | [buildthehomelab/wow-mod-forever-journal](https://github.com/buildthehomelab/wow-mod-forever-journal) |
| 47 | `mod-beast-collection` | Ajoute la collection, le dex et les récompenses de familiers de chasseur. | [buildthehomelab/wow-mod-beast-collection](https://github.com/buildthehomelab/wow-mod-beast-collection) |
| 48 | `mod-playerbots-pvp-life` | Anime les Playerbots avec du PvP mondial, des fronts, des défenses de capitales et des duels. | [vrzgames/mod-playerbots-pvp-life](https://github.com/vrzgames/mod-playerbots-pvp-life) |
| 49 | `mod-playerbots-city-life` | Anime les capitales et villes avec des Playerbots résidents, activités, déplacements et points d’intérêt. | [vrzgames/mod-playerbots-city-life](https://github.com/vrzgames/mod-playerbots-city-life) |
| 50 | `mod-retail-ah` | Remplace la fenêtre d’hôtel des ventes par une interface retail, avec filtres, progression individuelle, transmog, registre des ventes et compatibilité AHBot. | [buildthehomelab/wow-mod-retail-ah](https://github.com/buildthehomelab/wow-mod-retail-ah) |
| 51 | `mod-retail-professions` | Remplace la fenêtre des métiers par une interface retail, avec recettes, suivi, sources, milling/prospecting et statistiques de craft. | [buildthehomelab/wow-mod-retail-professions](https://github.com/buildthehomelab/wow-mod-retail-professions) |
| 52 | `mod-black-market` | Ajoute un hôtel des ventes noir avec enchères quotidiennes, montures, compagnons et objets rares, accessible auprès de Mister Chu à Baie-du-Butin. | [buildthehomelab/wow-mod-black-market](https://github.com/buildthehomelab/wow-mod-black-market) |

### Maisons de guilde

Les réglages officiels des deux modules sont copiés automatiquement au premier
démarrage dans le volume de configuration, comme ceux des autres modules. Une
maison coûte 1000 po et son propriétaire peut acheter les services avec les
tarifs par défaut. Les Playerbots ne s'y rendent que si un joueur réel de leur
guilde est connecté ; le cycle est de 120 secondes, avec cinq bots au plus par
entrée ou sortie et les journaux de diagnostic désactivés. Le PNJ d'achat (`500030`) est placé
automatiquement près des entraîneurs de portails des huit capitales : aucune
commande GM manuelle n'est nécessaire.

### Addons clients

- `mod-multibot-bridge` nécessite l'addon
  [MultiBot-Chatless](https://github.com/Wishmaster117/MultiBot-Chatless),
  installé côté client dans `Interface/AddOns/MultiBot`.
- `mod-retail-ah` nécessite l'addon client `RetailAH` dans
  `Interface/AddOns/RetailAH`.
- `mod-retail-professions` nécessite l'addon client `RetailProfessions` dans
  `Interface/AddOns/RetailProfessions`.
- `mod-black-market` nécessite l'addon client `BlackMarket` dans
  `Interface/AddOns/BlackMarket`. Le PNJ Mister Chu est créé par le SQL du module ;
  utilisez `.npc move` si vous souhaitez changer son emplacement.

Certains dépôts utilisent encore des API AzerothCore anciennes. Les adaptations
de compatibilité nécessaires sont appliquées automatiquement et de façon
reproductible par `docker/build-source.sh` et le `Dockerfile`.

## Scripts Lua inclus

| Script | Activation | Fonction |
|---|---|---|
| [`starter_boost.lua`](docker/lua_scripts/starter_boost.lua) | `.starterboost` / `.startbooster` | Offre une seule fois par personnage de niveau 10 maximum — niveau 55 pour un chevalier de la mort — l'équipement héritage multi-spécialisations de `mod-startergear`, les compétences d'armes nécessaires, 200 flèches avec chaque arc fourni, quatre sacs glaciaires de 22 emplacements, la monte, une monture et 250 pièces d'or. L'utilisation est enregistrée dans `acore_characters.custom_starter_boost_claims`. |
| [`SitMeansRest.lua`](https://github.com/Brytenwally/SitMeansRest) | `/sit` hors combat | Applique une régénération de 20 secondes, annulée dès que le personnage se déplace. |
| [`LootArbiter.lua`](https://github.com/Brytenwally/Loot-Arbiter) | Automatique après un jet de groupe ; diagnostic avec `.lootspec` | Attribue le butin au membre pour lequel il représente la meilleure amélioration. Le hook général d'obtention d'objet est désactivé afin de ne pas redistribuer les achats, courriers et récompenses hors jet de groupe. |

Les trois scripts sont intégrés à l'image `worldserver`. Leur chargement peut
être contrôlé dans les journaux avec :

```bash
docker compose logs worldserver | grep '\[ALE\]'
```

Sous Podman, remplacez `docker compose` par `podman compose`.

## Better Professions — densité des ressources

Le projet porte uniquement la partie minerais/plantes du pack MIT
[Better Professions](https://github.com/Upload-Academy/azerothcore-daisy/tree/master/packs/mcrilly/better-professions).
Les quêtes et le script Lua du pack original ne sont pas installés.

Au premier passage post-import, les valeurs AzerothCore d'origine des pools
concernés sont sauvegardées dans
`custom_better_professions_pool_baseline`. La densité est ensuite toujours
recalculée depuis cette référence : les redémarrages ne cumulent donc jamais le
multiplicateur. Les réglages se trouvent dans `.env` :

```env
BETTER_PROFESSIONS_HERBALISM_MULTIPLIER=6
BETTER_PROFESSIONS_MINING_MULTIPLIER=6
```

Le profil couvre les plantes et minerais de Classic, Outreterre et Norfendre.
La plage acceptée est `1–10`. La valeur `1` restaure la densité importée du
core. La modification s'applique au prochain `podman compose up -d` ou en
recréant explicitement `database-post-import`.

## Ports

| Port | Service | Exposition par défaut |
|---|---|---|
| `3724` | authserver | `127.0.0.1` |
| `8085` | worldserver | `127.0.0.1` |
| `7878` | SOAP | toujours `127.0.0.1` |
| `3306` | MySQL | non exposé |

Pour permettre un accès depuis le réseau local, définissez par exemple :

```env
BIND_ADDRESS=0.0.0.0
REALMLIST_IP=192.168.1.50
```

Assurez-vous alors que le pare-feu n'autorise que les sources nécessaires.

## Connexion du client WoW 3.3.5a

Le client doit être une version **3.3.5a (build 12340)**. Dans son fichier
`Data/<locale>/realmlist.wtf`, utilisez la même adresse que `REALMLIST_IP` :

```text
set realmlist 127.0.0.1
```

Pour un client situé sur une autre machine, remplacez `127.0.0.1` par l'adresse
LAN du serveur. Vérifiez que les ports TCP `3724` et `8085` sont accessibles et
que `BIND_ADDRESS=0.0.0.0`. Il n'est pas nécessaire d'exposer MySQL ni SOAP.

## Créer le compte administrateur

Le projet ne crée volontairement plus de compte `admin/admin`. La méthode
recommandée, compatible avec les schémas SHA1 et SRP6, est :

```bash
./scripts/create-account.sh admin 'MOT_DE_PASSE'
./scripts/set-gm.sh admin 3 -1
```

Sans la compatibilité `podman-docker`, utilisez directement :

```bash
podman compose --profile tools run --rm operations \
  python3 /azerothcore/tools/admin.py create-account admin 'MOT_DE_PASSE'
podman compose --profile tools run --rm operations \
  python3 /azerothcore/tools/admin.py set-gm admin 3 -1
```

Équivalent avec Make :

```bash
make account ACCOUNT=admin PASS='MOT_DE_PASSE'
make gm ACCOUNT=admin LEVEL=3 REALM=-1
```

La console interactive reste disponible :

```bash
make console
```

Dans la console worldserver :

```text
account create admin MOT_DE_PASSE MOT_DE_PASSE
account set gmlevel admin 3 -1
```

Pour détacher la console sans arrêter le serveur, utilisez `Ctrl-p`, puis
`Ctrl-q`. N'utilisez pas `Ctrl-c`.

## Commandes courantes

```bash
make up          # construire et démarrer
make down        # arrêter les conteneurs
make restart     # redémarrer authserver/worldserver
make status      # état des services
make logs        # journaux applicatifs
make console     # console worldserver interactive
make backup      # sauvegarde SQL compressée dans backups/
make health      # santé MySQL/auth/world/SOAP
make metrics     # snapshot JSON strict
make diagnose    # services, ressources, DB, modules et logs
make watch       # healthcheck périodique, INTERVAL=30 par défaut
make bots-help   # aide des commandes Playerbots
make clean-logs  # supprimer les fichiers de logs applicatifs
make update      # reconstruction complète depuis les sources distantes
```

Compose laisse jusqu'à deux minutes à `worldserver` pour sauvegarder son état et
fermer proprement ses connexions avant de forcer son arrêt.

Commandes Docker Compose directes :

```bash
docker compose logs -f worldserver
docker compose restart worldserver
docker compose exec database mysql -uroot -p
```

Sous Podman, remplacez simplement `docker compose` par `podman compose` :

```bash
podman compose logs -f worldserver
podman compose restart worldserver
podman compose exec database mysql -uroot -p
```

## Configuration AzerothCore et modules

Les réglages versionnés se trouvent dans `docker/acore.env`. Ce profil contient
les réglages statiques du profil Compose (plus les secrets injectés par
Compose). Le point devient
un underscore, les transitions minuscule/majuscule reçoivent un underscore et
la clé est préfixée par `AC_` :

```text
Rate.XP.Kill                  -> AC_RATE_XP_KILL
Playerbots.MinRandomBots      -> AC_PLAYERBOTS_MIN_RANDOM_BOTS
AutoBalance.MinPlayers        -> AC_AUTO_BALANCE_MIN_PLAYERS
```

Les valeurs `AC_*` sont autoritaires et sont réappliquées au démarrage ;
modifiez donc `docker/acore.env`, pas le fichier du volume `config`.

Après une modification :

```bash
docker compose up -d --force-recreate authserver worldserver
```

Les configurations générées sont conservées dans le volume `config`.

## AHBot

AHBot n'utilise plus automatiquement un personnage joueur comme solution de
secours. Créez d'abord le compte dédié :

```bash
./scripts/bootstrap-ahbot.sh ahbot 'MOT_DE_PASSE'
```

Créez son personnage avec le client WoW, récupérez son GUID, puis :

```bash
./scripts/setup-ahbot.sh 123
# Plusieurs personnages : ./scripts/setup-ahbot.sh 123,456
```

Le script vérifie les GUID, active le vendeur dans la configuration persistante,
puis exécute `.ahbot reload` et trois mises à jour via SOAP. Le compte technique
SOAP défini dans `.env` est créé automatiquement avec les droits requis pendant
l'initialisation des bases.

## Sauvegarde et restauration

```bash
make backup
```

`DB_BACKUP_RETENTION` dans `.env` conserve les N derniers snapshots. Chaque
sauvegarde est écrite dans un répertoire temporaire, vérifiée avec `gzip -t`,
puis publiée atomiquement. `0` conserve tous les snapshots.

Restauration d'une base :

```bash
gunzip -c backups/DATE/acore_characters.sql.gz | \
  docker compose exec -T database \
  sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" acore_characters'
```

Arrêtez `worldserver` avant de restaurer `acore_characters`.

## Mise à jour

`make update` reconstruit intégralement les images. Effectuez toujours une
sauvegarde avant :

```bash
make backup
make update
```

Avec Podman :

```bash
./scripts/backup-db.sh
podman compose build --pull --no-cache
podman compose down
podman compose up -d
```

La recréation des conteneurs après la reconstruction garantit l'utilisation
des nouvelles images. Les volumes de base de données et de données client sont
conservés par `podman compose down`.

Les dépendances externes sont verrouillées par commit dans `docker/sources.lock`. Une
reconstruction avec `--pull --no-cache` récupère les versions amont disponibles ;
les changements incompatibles peuvent nécessiter une adaptation locale.

MySQL utilise maintenant `innodb_flush_log_at_trx_commit=1` pour éviter de
perdre des transactions validées lors d'un arrêt brutal.

## Dépannage

Commencez par le diagnostic intégré :

```bash
make status
make health
make diagnose
```

Sous Podman sans `podman-docker` :

```bash
podman compose ps
podman compose logs --tail=200 authserver worldserver
podman compose --profile tools run --rm operations python3 /azerothcore/tools/diagnose.py
```

### Échec de compilation

Conservez toute la sortie avant de rechercher la première erreur réelle :

```bash
podman compose build worldserver 2>&1 | tee build.log
grep -n -m1 -B20 -A30 -E 'error:|fatal error:|Killed|undefined reference' build.log
```

Une ligne finale `gmake: Error 2` n'est généralement qu'une conséquence. En cas
de processus `Killed`, réduisez `BUILD_JOBS` dans `.env`, puis reconstruisez.

### Sélection interactive de l'image MySQL avec Podman

Si Podman demande quel registre utiliser pour `mysql:8.4`, choisissez
`docker.io/library/mysql:8.4`. Le fichier Compose utilise volontairement cette
référence pleinement qualifiée afin d'éviter la question lors des prochains
lancements.

### Services one-shot

`database-init`, `database-preflight`, `db-import`, `database-post-import`,
`realm-init` et `client-data` doivent terminer en `Exited (0)`. Tout autre code
signale un échec ; consultez par exemple :

```bash
podman compose logs database-preflight database-post-import db-import
```

## Suppression complète

La commande suivante détruit également toutes les bases et données client :

```bash
docker compose down --volumes
```

Équivalent Podman :

```bash
podman compose down --volumes
```

Elle est irréversible sans sauvegarde.

## Références

- [Documentation Docker officielle AzerothCore](https://www.azerothcore.org/wiki/install-with-docker)
- [Installation Docker de mod-playerbots](https://github.com/mod-playerbots/mod-playerbots)
