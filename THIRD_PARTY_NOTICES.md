# Third-party notices

This inventory covers locally derived works and the AzerothCore source plus the 55 modules listed in `docker/sources.lock`. License statements are recorded as observed in the cited source; they are not a legal compatibility determination. “Not pinned” means the upstream reference is a mutable branch or repository URL, so this repository does not identify the exact source revision.

| Component | Observed declaration | Upstream reference / pinned commit | Evidence at that revision or reference |
|---|---|---|---|
| `SitMeansRest` | MIT | `main` (not pinned) | [LICENSE](https://github.com/Brytenwally/SitMeansRest/blob/main/LICENSE) |
| `LootArbiter` | MIT | `c0cd6e4d2cf4` (source comment only; not pinned by build) | [LICENSE](https://github.com/Brytenwally/Loot-Arbiter/blob/c0cd6e4d2cf434672398544edc534aae52d80570/LICENSE) |
| `starter_boost` | MIT | `main` (not pinned) | [LICENSE](https://github.com/Kyroth88/ale-scripts/blob/main/LICENSE) |
| `Better Professions resource-template selection` | MIT | `master` (not pinned) | [LICENSE](https://github.com/Upload-Academy/azerothcore-daisy/blob/master/LICENSE) |
| `core` | GPL-2.0-or-later + AGPL-3.0-or-later file-level declarations; separate third-party dependencies | [8a4e76eac8c4](<https://github.com/mod-playerbots/azerothcore-wotlk/commit/8a4e76eac8c4ccebf547113afe7b51d6c3e91641>) | [LICENSE](https://github.com/mod-playerbots/azerothcore-wotlk/blob/8a4e76eac8c4ccebf547113afe7b51d6c3e91641/LICENSE); [.github/README.md](https://github.com/mod-playerbots/azerothcore-wotlk/blob/8a4e76eac8c4ccebf547113afe7b51d6c3e91641/.github/README.md) |
| `mod-playerbots` | GPL-2.0-or-later | [d750b4b3a50e](<https://github.com/mod-playerbots/mod-playerbots/commit/d750b4b3a50effdf22bedc8032f0e8e5f7cb8091>) | [LICENSE](https://github.com/mod-playerbots/mod-playerbots/blob/d750b4b3a50effdf22bedc8032f0e8e5f7cb8091/LICENSE) |
| `mod-dungeon-clear` | AGPL-3.0-or-later | [381554742ac0](<https://github.com/jrad7/mod-dungeon-clear/commit/381554742ac04361fff5cab95a12e0564fb16382>) | [LICENSE](https://github.com/jrad7/mod-dungeon-clear/blob/381554742ac04361fff5cab95a12e0564fb16382/LICENSE) |
| `mod-optimal-bot-raid` | AGPL v3 (no later version specified in the license text) | [a866e1b01418](<https://github.com/barnaclebarry/mod-optimal-bot-raid/commit/a866e1b01418286b633cdd4f3bbcc061f1b60835>) | [LICENSE](https://github.com/barnaclebarry/mod-optimal-bot-raid/blob/a866e1b01418286b633cdd4f3bbcc061f1b60835/LICENSE) |
| `mod-multibot-bridge` | No license declaration found — permission to redistribute should be confirmed | [8f703da2bbdb](<https://github.com/Wishmaster117/mod-multibot-bridge/commit/8f703da2bbdbb4a6daf6b0aaa292387a89f4ccc4>) | [Audited repository tree](https://github.com/Wishmaster117/mod-multibot-bridge/tree/8f703da2bbdbb4a6daf6b0aaa292387a89f4ccc4) |
| `mod-ah-bot-plus` | GPL-2.0-or-later + AGPL v3 by file; no LICENSE file | [f685832994c8](<https://github.com/NathanHandley/mod-ah-bot-plus/commit/f685832994c825f90aa5a3dc0e1620aa568e875b>) | [Audited repository tree](https://github.com/NathanHandley/mod-ah-bot-plus/tree/f685832994c825f90aa5a3dc0e1620aa568e875b) |
| `mod-autobalance` | GPL-2.0-or-later in AutoBalance.cpp; other headers refer to the AzerothCore license; no LICENSE file | [1d707cb61a09](<https://github.com/azerothcore/mod-autobalance/commit/1d707cb61a0962ab01e4123681e2d3b66cc558a2>) | [Audited repository tree](https://github.com/azerothcore/mod-autobalance/tree/1d707cb61a0962ab01e4123681e2d3b66cc558a2) |
| `mod-aoe-loot` | AGPL v3 (LICENSE); source files declare GPL-2.0-or-later | [44486b1aeceb](<https://github.com/azerothcore/mod-aoe-loot/commit/44486b1aecebd86944ce115972b3c839544903d3>) | [LICENSE](https://github.com/azerothcore/mod-aoe-loot/blob/44486b1aecebd86944ce115972b3c839544903d3/LICENSE) |
| `mod-learn-spells` | AGPL v3 (no later version specified in the license text) | [016b92d520f3](<https://github.com/azerothcore/mod-learn-spells/commit/016b92d520f343d074ffd5d46016a94f4a3a6ebd>) | [LICENSE.md](https://github.com/azerothcore/mod-learn-spells/blob/016b92d520f343d074ffd5d46016a94f4a3a6ebd/LICENSE.md) |
| `mod-solo-lfg` | MIT | [3821fe1d108a](<https://github.com/azerothcore/mod-solo-lfg/commit/3821fe1d108ade8d2b7ad6611e41154e05864c65>) | [LICENSE](https://github.com/azerothcore/mod-solo-lfg/blob/3821fe1d108ade8d2b7ad6611e41154e05864c65/LICENSE) |
| `mod-challenge-modes` | MIT (LICENSE) + AGPL v3 source headers | [1930525b9530](<https://github.com/ZhengPeiRu21/mod-challenge-modes/commit/1930525b9530d329cb9fe0504a3c9b5b40a12261>) | [LICENSE](https://github.com/ZhengPeiRu21/mod-challenge-modes/blob/1930525b9530d329cb9fe0504a3c9b5b40a12261/LICENSE) |
| `mod-dungeon-master` | AGPL v3 (no later version specified in the license text) | [612eaf804cd7](<https://github.com/InstanceForge/mod-dungeon-master/commit/612eaf804cd7fc4af74fde66d376a571a5550077>) | [LICENSE](https://github.com/InstanceForge/mod-dungeon-master/blob/612eaf804cd7fc4af74fde66d376a571a5550077/LICENSE) |
| `mod-dungeon-questgivers` | No license declaration found — permission to redistribute should be confirmed | [b266f558da86](<https://github.com/and-elf/mod-dungeon-questgivers/commit/b266f558da862beae2ce707291535d1ffcfac560>) | [Audited repository tree](https://github.com/and-elf/mod-dungeon-questgivers/tree/b266f558da862beae2ce707291535d1ffcfac560) |
| `mod-auto-gather` | GPL v2 declared in README; no LICENSE file | [4831935ce4da](<https://github.com/thanhtong89/mod-auto-gather/commit/4831935ce4da489581de6708bddf56d0dcd05cb1>) | [README.md](https://github.com/thanhtong89/mod-auto-gather/blob/4831935ce4da489581de6708bddf56d0dcd05cb1/README.md) |
| `DungeonRespawn` | MIT (LICENSE) + AGPL v3 source header | [28cbd7b150d2](<https://github.com/riksbyville/DungeonRespawn/commit/28cbd7b150d219ef34e6140d557c0e99f7cd1c34>) | [LICENSE](https://github.com/riksbyville/DungeonRespawn/blob/28cbd7b150d219ef34e6140d557c0e99f7cd1c34/LICENSE) |
| `mod-player-bot-level-brackets` | CONFLICT: AGPL v3 (LICENSE), GPL v2 (README) | [a94f9c6458bf](<https://github.com/DustinHendrickson/mod-player-bot-level-brackets/commit/a94f9c6458bf6264164436a53ddd4e5c3ed44fdb>) | [LICENSE](https://github.com/DustinHendrickson/mod-player-bot-level-brackets/blob/a94f9c6458bf6264164436a53ddd4e5c3ed44fdb/LICENSE); [README.md](https://github.com/DustinHendrickson/mod-player-bot-level-brackets/blob/a94f9c6458bf6264164436a53ddd4e5c3ed44fdb/README.md) |
| `mod-junk-to-gold` | AGPL v3 (no later version specified in the license text) | [99f21e6cfd36](<https://github.com/kadeshar/mod-junk-to-gold/commit/99f21e6cfd36e4aa87a6dd9ef68d6a818bea0316>) | [LICENSE](https://github.com/kadeshar/mod-junk-to-gold/blob/99f21e6cfd36e4aa87a6dd9ef68d6a818bea0316/LICENSE) |
| `mod-rare-drops` | MIT (LICENSE) + AGPL v3 source headers | [cf6ea06d32d7](<https://github.com/StraysFromPath/mod-rare-drops/commit/cf6ea06d32d751328836b65d9b7270975aa3c68a>) | [LICENSE](https://github.com/StraysFromPath/mod-rare-drops/blob/cf6ea06d32d751328836b65d9b7270975aa3c68a/LICENSE) |
| `mod-transmog-plus` | AGPL v3 (no later version specified in the license text) | [d859ffbd7362](<https://github.com/buildthehomelab/wow-mod-transmog-plus/commit/d859ffbd736233e498f37cfa8e2e733647bc0e8f>) | [LICENSE](https://github.com/buildthehomelab/wow-mod-transmog-plus/blob/d859ffbd736233e498f37cfa8e2e733647bc0e8f/LICENSE) |
| `mod-reagent-bank-account` | MIT (LICENSE) + AGPL-3.0-or-later (sources) | [e98b2ef241da](<https://github.com/buildthehomelab/mod-reagent-bank-account/commit/e98b2ef241da6f5f743acc696391908f4b8c9da7>) | [LICENSE](https://github.com/buildthehomelab/mod-reagent-bank-account/blob/e98b2ef241da6f5f743acc696391908f4b8c9da7/LICENSE) |
| `mod-daily-reset` | MIT (LICENSE) + AGPL v3 source header | [cb44f62577ce](<https://github.com/binboupan/mod-daily-reset/commit/cb44f62577ce6d9732252f738793f7813b3fd758>) | [LICENSE](https://github.com/binboupan/mod-daily-reset/blob/cb44f62577ce6d9732252f738793f7813b3fd758/LICENSE) |
| `mod-mount-scaling` | No license declaration found — permission to redistribute should be confirmed | [309da733af3b](<https://github.com/claudevandort/mod-mount-scaling/commit/309da733af3bcb233c33d51fbddcdc5f05aa99bf>) | [Audited repository tree](https://github.com/claudevandort/mod-mount-scaling/tree/309da733af3bcb233c33d51fbddcdc5f05aa99bf) |
| `mod-level-one-mounts` | AGPL v3 (no later version specified in the license text) | [143f5dae20e9](<https://github.com/tomcoffingiii/mod-level-one-mounts/commit/143f5dae20e981423eb72de15dd24855aa946dec>) | [LICENSE](https://github.com/tomcoffingiii/mod-level-one-mounts/blob/143f5dae20e981423eb72de15dd24855aa946dec/LICENSE) |
| `mod-ale` | GPL v3 (LICENSE/engine); glue GPL-2.0-or-later; StackTracePlus/lmarshal MIT | [84b85cc55980](<https://github.com/azerothcore/mod-ale/commit/84b85cc55980dbf67d596f3d5cb34ded10c59102>) | [LICENSE](https://github.com/azerothcore/mod-ale/blob/84b85cc55980dbf67d596f3d5cb34ded10c59102/LICENSE); [src/LuaEngine/extensions/StackTracePlus/LICENSE](https://github.com/azerothcore/mod-ale/blob/84b85cc55980dbf67d596f3d5cb34ded10c59102/src/LuaEngine/extensions/StackTracePlus/LICENSE) |
| `mod-quest-loot-party` | AGPL v3 (no later version specified in the license text) | [c3955915c76d](<https://github.com/pangolp/mod-quest-loot-party/commit/c3955915c76d5a22a9d25a44482345d368a8de82>) | [LICENSE](https://github.com/pangolp/mod-quest-loot-party/blob/c3955915c76d5a22a9d25a44482345d368a8de82/LICENSE) |
| `mod-TimeIsTime` | AGPL v3 (no later version specified in the license text) | [155aaf1cc61d](<https://github.com/dunjeon/mod-TimeIsTime/commit/155aaf1cc61deb7ec89e4a9c828bb35ef4926418>) | [LICENSE](https://github.com/dunjeon/mod-TimeIsTime/blob/155aaf1cc61deb7ec89e4a9c828bb35ef4926418/LICENSE) |
| `mod-boss-announcer` | AGPL v3 (no later version specified in the license text) | [3af6e83e976a](<https://github.com/azerothcore/mod-boss-announcer/commit/3af6e83e976a9a143ded51f4e8afeb69863fb5ec>) | [LICENSE.md](https://github.com/azerothcore/mod-boss-announcer/blob/3af6e83e976a9a143ded51f4e8afeb69863fb5ec/LICENSE.md) |
| `mod-increased-ghost-speed` | No license declaration found — permission to redistribute should be confirmed | [9a9c90db5fdb](<https://github.com/TheTollski/mod-increased-ghost-speed/commit/9a9c90db5fdbcee61c8fe18e4fcc75010c0870d6>) | [Audited repository tree](https://github.com/TheTollski/mod-increased-ghost-speed/tree/9a9c90db5fdbcee61c8fe18e4fcc75010c0870d6) |
| `mod-duel-reset` | AGPL v3 (no later version specified in the license text) | [f2c67d4d82b7](<https://github.com/azerothcore/mod-duel-reset/commit/f2c67d4d82b79cefccfc89a4696a428529cf8cfd>) | [LICENSE](https://github.com/azerothcore/mod-duel-reset/blob/f2c67d4d82b79cefccfc89a4696a428529cf8cfd/LICENSE) |
| `NoProfessionLimit` | CONFLICT: GPL v2 (LICENSE), MIT (README) | [5c64277a52d7](<https://github.com/AlsoNotMehh/NoProfessionLimit/commit/5c64277a52d7014a7501f6cf6a111cef137f2888>) | [LICENSE](https://github.com/AlsoNotMehh/NoProfessionLimit/blob/5c64277a52d7014a7501f6cf6a111cef137f2888/LICENSE); [README.md](https://github.com/AlsoNotMehh/NoProfessionLimit/blob/5c64277a52d7014a7501f6cf6a111cef137f2888/README.md) |
| `mod-no-hearthstone-cooldown` | AGPL v3 (no later version specified in the license text) | [832ef5e6d726](<https://github.com/BytesGalore/mod-no-hearthstone-cooldown/commit/832ef5e6d7268876112be65202ee8e60d287a936>) | [LICENSE](https://github.com/BytesGalore/mod-no-hearthstone-cooldown/blob/832ef5e6d7268876112be65202ee8e60d287a936/LICENSE) |
| `mod-autofish` | MIT | [0f9221577601](<https://github.com/Flerp/mod-autofish/commit/0f92215776017754355e1b5cfeec77cefc98b40b>) | [LICENSE](https://github.com/Flerp/mod-autofish/blob/0f92215776017754355e1b5cfeec77cefc98b40b/LICENSE) |
| `mod-skip-dk-starting-area` | MIT | [287f0fd990c5](<https://github.com/d23monkey/mod-skip-dk-starting-area/commit/287f0fd990c55ee69fa756ab1fdb5a285a757b96>) | [LICENSE](https://github.com/d23monkey/mod-skip-dk-starting-area/blob/287f0fd990c55ee69fa756ab1fdb5a285a757b96/LICENSE) |
| `mod-gunship-skip` | GPL-2.0-or-later in source headers; no LICENSE file | [12d5fd847c92](<https://github.com/BlaMacfly/mod-gunship-skip/commit/12d5fd847c9243793c967c5c8bf76759fc7fae7b>) | [Audited repository tree](https://github.com/BlaMacfly/mod-gunship-skip/tree/12d5fd847c9243793c967c5c8bf76759fc7fae7b) |
| `portals-in-all-capitals` | AGPL v3 (no later version specified in the license text) | [9adae9c851a5](<https://github.com/azerothcore/portals-in-all-capitals/commit/9adae9c851a5fe0c600c40bc10291d361d9c23ff>) | [LICENSE](https://github.com/azerothcore/portals-in-all-capitals/blob/9adae9c851a5fe0c600c40bc10291d361d9c23ff/LICENSE) |
| `mod-gain-honor-guard` | AGPL v3 (no later version specified in the license text) | [db8de7481c84](<https://github.com/azerothcore/mod-gain-honor-guard/commit/db8de7481c849acb5ec394b28fe75b29b1151856>) | [LICENSE](https://github.com/azerothcore/mod-gain-honor-guard/blob/db8de7481c849acb5ec394b28fe75b29b1151856/LICENSE) |
| `mod-npc-enchanter` | AGPL v3 (no later version specified in the license text) | [af32add66eaf](<https://github.com/azerothcore/mod-npc-enchanter/commit/af32add66eafc0e0eb8775999e76ceed75f18b74>) | [LICENSE.md](https://github.com/azerothcore/mod-npc-enchanter/blob/af32add66eafc0e0eb8775999e76ceed75f18b74/LICENSE.md) |
| `mod-npc-all-mounts` | AGPL v3 (no later version specified in the license text) | [c6899d4cafb4](<https://github.com/azerothcore/mod-npc-all-mounts/commit/c6899d4cafb4539b4dd326e8a3811fa0fdc91423>) | [LICENSE.md](https://github.com/azerothcore/mod-npc-all-mounts/blob/c6899d4cafb4539b4dd326e8a3811fa0fdc91423/LICENSE.md) |
| `mod-guildhouse` | No license declaration found — permission to redistribute should be confirmed | [0b3cc14e947a](<https://github.com/azerothcore/mod-guildhouse/commit/0b3cc14e947a859f8a7751a10676107d6316275b>) | [Audited repository tree](https://github.com/azerothcore/mod-guildhouse/tree/0b3cc14e947a859f8a7751a10676107d6316275b) |
| `mod-player-bot-guildhouse` | CONFLICT: MIT (LICENSE), GPL v2 (README) | [1d4d649982a5](<https://github.com/DustinHendrickson/mod-player-bot-guildhouse/commit/1d4d649982a523b674321f6ca4c23d11e60c1b7b>) | [LICENSE](https://github.com/DustinHendrickson/mod-player-bot-guildhouse/blob/1d4d649982a523b674321f6ca4c23d11e60c1b7b/LICENSE); [README.md](https://github.com/DustinHendrickson/mod-player-bot-guildhouse/blob/1d4d649982a523b674321f6ca4c23d11e60c1b7b/README.md) |
| `mod-individual-progression` | MIT (LICENSE) + AGPL v3 / GPL v2 or later by file | [acaa9b3c73f7](<https://github.com/ZhengPeiRu21/mod-individual-progression/commit/acaa9b3c73f7b756dcf0a7c388b438dcc68cdd17>) | [LICENSE](https://github.com/ZhengPeiRu21/mod-individual-progression/blob/acaa9b3c73f7b756dcf0a7c388b438dcc68cdd17/LICENSE) |
| `mod-assistant` | AGPL v3 (no later version specified in the license text) | [77505b1a3d56](<https://github.com/noisiver/mod-assistant/commit/77505b1a3d561438a13fd3fabfe40676daa7fdfe>) | [LICENSE](https://github.com/noisiver/mod-assistant/blob/77505b1a3d561438a13fd3fabfe40676daa7fdfe/LICENSE) |
| `mod-flightpath-discovery` | CONFLICT: GPL v3 (LICENSE), AGPL-3.0 (README) | [fe5b55207eaa](<https://github.com/bl1tzkr13g/mod-flightpath-discovery/commit/fe5b55207eaa6f55aa57d8c8219decb6a4351c8e>) | [LICENSE](https://github.com/bl1tzkr13g/mod-flightpath-discovery/blob/fe5b55207eaa6f55aa57d8c8219decb6a4351c8e/LICENSE); [README.md](https://github.com/bl1tzkr13g/mod-flightpath-discovery/blob/fe5b55207eaa6f55aa57d8c8219decb6a4351c8e/README.md) |
| `mod-forever-hunter` | MIT | [708733622f2c](<https://github.com/buildthehomelab/wow-mod-forever-hunter/commit/708733622f2c96ccb640c40f7bc13db6e5d573df>) | [LICENSE](https://github.com/buildthehomelab/wow-mod-forever-hunter/blob/708733622f2c96ccb640c40f7bc13db6e5d573df/LICENSE) |
| `mod-raid-clear` | MIT | [fa299223a92a](<https://github.com/buildthehomelab/wow-mod-raid-clear/commit/fa299223a92a0806eb778a182e85a76f3f3feb62>) | [LICENSE](https://github.com/buildthehomelab/wow-mod-raid-clear/blob/fa299223a92a0806eb778a182e85a76f3f3feb62/LICENSE) |
| `mod-lfg-progression` | AGPL v3 (no later version specified in the license text) | [5d64585dd2ac](<https://github.com/buildthehomelab/wow-mod-lfg-progression/commit/5d64585dd2ac6d9313165f8c46f278980ae89f37>) | [LICENSE](https://github.com/buildthehomelab/wow-mod-lfg-progression/blob/5d64585dd2ac6d9313165f8c46f278980ae89f37/LICENSE) |
| `mod-forever-journal` | MIT | [061dda3f3cb7](<https://github.com/buildthehomelab/wow-mod-forever-journal/commit/061dda3f3cb78abb46b4dc974572390a539d5c49>) | [LICENSE](https://github.com/buildthehomelab/wow-mod-forever-journal/blob/061dda3f3cb78abb46b4dc974572390a539d5c49/LICENSE) |
| `mod-beast-collection` | MIT | [61ef9e08d0ce](<https://github.com/buildthehomelab/wow-mod-beast-collection/commit/61ef9e08d0ce38a33055ced89956303db68d4ae8>) | [LICENSE](https://github.com/buildthehomelab/wow-mod-beast-collection/blob/61ef9e08d0ce38a33055ced89956303db68d4ae8/LICENSE) |
| `mod-playerbots-pvp-life` | GPL-2.0-or-later | [997d8317e510](<https://github.com/vrzgames/mod-playerbots-pvp-life/commit/997d8317e5109cfcbc6cae2308d13235abf7363d>) | [LICENSE](https://github.com/vrzgames/mod-playerbots-pvp-life/blob/997d8317e5109cfcbc6cae2308d13235abf7363d/LICENSE) |
| `mod-playerbots-city-life` | GPL-2.0-or-later; LICENSE is a declaration/link, not the full license text | [274110c26ff0](<https://github.com/vrzgames/mod-playerbots-city-life/commit/274110c26ff0785a369debdf84dd44ed38ec29fd>) | [LICENSE](https://github.com/vrzgames/mod-playerbots-city-life/blob/274110c26ff0785a369debdf84dd44ed38ec29fd/LICENSE) |
| `mod-retail-ah` | MIT | [358ba1ce65e4](<https://github.com/buildthehomelab/wow-mod-retail-ah/commit/358ba1ce65e4f22779dfe3a27b8c451552ba5dc3>) | [LICENSE](https://github.com/buildthehomelab/wow-mod-retail-ah/blob/358ba1ce65e4f22779dfe3a27b8c451552ba5dc3/LICENSE) |
| `mod-retail-professions` | MIT | [edec6c7cb576](<https://github.com/buildthehomelab/wow-mod-retail-professions/commit/edec6c7cb57677d14fc2587a9cd4fc47dac32818>) | [LICENSE](https://github.com/buildthehomelab/wow-mod-retail-professions/blob/edec6c7cb57677d14fc2587a9cd4fc47dac32818/LICENSE) |
| `mod-black-market` | MIT | [3b8f9121f25c](<https://github.com/buildthehomelab/wow-mod-black-market/commit/3b8f9121f25cb7332b376b0e5f67254dd8ee4578>) | [LICENSE](https://github.com/buildthehomelab/wow-mod-black-market/blob/3b8f9121f25cb7332b376b0e5f67254dd8ee4578/LICENSE) |
| `mod-lost-legendaries` | MIT | [63b0dcce4f7f](<https://github.com/buildthehomelab/wow-mod-lost-legendaries/commit/63b0dcce4f7f6e7863be7ccd5f1960d0325314ae>) | [LICENSE](https://github.com/buildthehomelab/wow-mod-lost-legendaries/blob/63b0dcce4f7f6e7863be7ccd5f1960d0325314ae/LICENSE) |
| `mod-forever-rogue` | MIT | [cee36757ce0f](<https://github.com/buildthehomelab/wow-mod-forever-rogue/commit/cee36757ce0fff37ae5c06826c6593508f607db7>) | [LICENSE](https://github.com/buildthehomelab/wow-mod-forever-rogue/blob/cee36757ce0fff37ae5c06826c6593508f607db7/LICENSE) |
| `mod-forever-periodic-crit` | MIT | [a0d17150fdce](<https://github.com/buildthehomelab/wow-mod-forever-periodic-crit/commit/a0d17150fdceb44df509866f6850b69b0237c7d4>) | [LICENSE](https://github.com/buildthehomelab/wow-mod-forever-periodic-crit/blob/a0d17150fdceb44df509866f6850b69b0237c7d4/LICENSE) |
## Notes and unresolved license declarations

Five pinned modules have no license declaration identified: `mod-multibot-bridge`, `mod-dungeon-questgivers`, `mod-guildhouse`, `mod-increased-ghost-speed`, and `mod-mount-scaling`. Redistribution permission should be confirmed with their authors.

Conflicting declarations were found for `NoProfessionLimit`, `mod-flightpath-discovery`, `mod-player-bot-guildhouse`, and `mod-player-bot-level-brackets`. Some projects also pair a root MIT license with GPL/AGPL source headers. These observations are shown per component and are not treated as a grant of dual licensing.

## MIT license texts for locally derived works

The following files contain the complete MIT license text. Copyright attributions are listed in the inventory above.

### SitMeansRest and Loot Arbiter

Copyright (c) 2026 Brytenwally

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

### ALE starter boost

Copyright (c) 2026 Kyroth88

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

### Better Professions resource selection

Copyright (c) 2025 Upload Academy

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
