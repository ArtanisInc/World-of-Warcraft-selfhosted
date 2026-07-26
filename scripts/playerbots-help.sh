#!/usr/bin/env bash
cat <<'EOF'
Playerbots commands
===================
Bot management:
  .playerbot add <class>       add a personal bot
  .playerbot remove all       remove personal bots
  .playerbot stats            display bot statistics

Behaviour:
  .playerbot follow           follow the master
  .playerbot grind            autonomous XP/farming
  .playerbot quest            quest mode
  .playerbot dungeon          dungeon mode
  .playerbot raid             raid mode
  .playerbot stay             remain in place

Random population:
  .rndbot login
  .rndbot logout

Target a bot and use .playerbot control to control it directly.
EOF
