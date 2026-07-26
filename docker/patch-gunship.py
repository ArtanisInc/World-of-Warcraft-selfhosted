#!/usr/bin/env python3
from pathlib import Path

root = Path("/azerothcore")
module_dir = root / "modules/mod-gunship-skip"
cmake = module_dir / "CMakeLists.txt"
module = module_dir / "src/boss_icecrown_gunship_battle.cpp"
loader = module_dir / "src/gunship_skip_loader.cpp"
stub = module_dir / "src/mod_gunship_skip_stub.cpp"
core = root / "src/server/scripts/Northrend/IcecrownCitadel/boss_icecrown_gunship_battle.cpp"

if not all((cmake.exists(), module.exists(), core.exists())):
    raise SystemExit("mod-gunship-skip layout changed; refusing an unpatched build")

text = cmake.read_text()
for source in ("boss_icecrown_gunship_battle.cpp", "gunship_skip_loader.cpp"):
    text = text.replace(
        f'AC_ADD_SCRIPT("${{CMAKE_CURRENT_LIST_DIR}}/src/{source}")',
        f"# {source} is integrated by docker/patch-gunship.py",
    )
text = text.replace(
    'AC_ADD_SCRIPT_LOADER("GunshipSkip" "${CMAKE_CURRENT_LIST_DIR}/conf/gunship_skip.conf.dist")',
    "# Loader disabled: integrated into the core ICC script",
)
text = text.replace(
    'AC_ADD_SCRIPT_LOADER("GunshipSkip" "${CMAKE_CURRENT_LIST_DIR}/src/gunship_skip_loader.h")',
    "# Loader disabled: integrated into the core ICC script",
)
cmake.write_text(text)

source = module.read_text()
source = source.replace(
    '#include "icecrown_citadel.h"',
    '#include "../../../src/server/scripts/Northrend/IcecrownCitadel/icecrown_citadel.h"',
)
if '#include "ScriptedGossip.h"' not in source:
    source = source.replace(
        '#include "SpellScript.h"\n',
        '#include "SpellScript.h"\n#include "ScriptedGossip.h"\n',
    )
source = source.replace(
    "void AddSC_mod_gunship_skip_scripts()",
    "void AddSC_boss_icecrown_gunship_battle()",
)
source = source.replace(
    "    // Master switch — when GunshipSkip.Enable = 0 in gunship_skip.conf, no\n"
    "    // scripts are registered and the server falls back to the core's\n"
    "    // stock Gunship Battle behaviour.\n"
    "    if (!sConfigMgr->GetOption<bool>(\"GunshipSkip.Enable\", true))\n"
    "        return;\n\n",
    "",
)
source = source.replace(
    "if (instance && instance->GetBossState(DATA_ICECROWN_GUNSHIP_BATTLE) != DONE)",
    'if (sConfigMgr->GetOption<bool>("GunshipSkip.Enable", true) && instance && '
    "instance->GetBossState(DATA_ICECROWN_GUNSHIP_BATTLE) != DONE)",
)
core.write_text(source)

module.rename(module.with_suffix(".cpp.disabled"))
if loader.exists():
    loader.rename(loader.with_suffix(".cpp.disabled"))
stub.write_text("void Addmod_gunship_skipScripts() {}\n")
