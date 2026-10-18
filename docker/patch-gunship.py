#!/usr/bin/env python3
"""Integrate the locked mod-gunship-skip source into the core ICC script.

Every transformation is deliberately exact. A source-layout change must fail the
image build rather than silently producing a partly patched worldserver.
"""
import os
import re
from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one matching source fragment, found {count}")
    return text.replace(old, new, 1)


def replace_all(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count < 1:
        raise SystemExit(f"{label}: expected source fragment is missing")
    return text.replace(old, new)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


root = Path(os.environ.get("AZEROTHCORE_ROOT", "/azerothcore"))
module_dir = root / "modules/mod-gunship-skip"
cmake = module_dir / "CMakeLists.txt"
module = module_dir / "src/boss_icecrown_gunship_battle.cpp"
loader = module_dir / "src/gunship_skip_loader.cpp"
stub = module_dir / "src/mod_gunship_skip_stub.cpp"
core = root / "src/server/scripts/Northrend/IcecrownCitadel/boss_icecrown_gunship_battle.cpp"

for path in (cmake, module, loader, core):
    require(path.is_file(), f"mod-gunship-skip layout changed; missing {path}")
require(not stub.exists(), f"mod-gunship-skip layout changed; unexpected {stub}")

cmake_text = cmake.read_text()
for source in ("boss_icecrown_gunship_battle.cpp", "gunship_skip_loader.cpp"):
    cmake_text = replace_once(
        cmake_text,
        f'AC_ADD_SCRIPT("${{CMAKE_CURRENT_LIST_DIR}}/src/{source}")',
        f"# {source} is integrated by docker/patch-gunship.py",
        f"CMake script registration for {source}",
    )
cmake_text = replace_once(
    cmake_text,
    'AC_ADD_SCRIPT_LOADER("GunshipSkip" "${CMAKE_CURRENT_LIST_DIR}/conf/gunship_skip.conf.dist")',
    "# Loader disabled: integrated into the core ICC script",
    "CMake loader registration",
)
require(not re.search(r"^\s*AC_ADD_SCRIPT\(", cmake_text, re.MULTILINE),
        "CMake patch left a module script registration")
require(not re.search(r"^\s*AC_ADD_SCRIPT_LOADER\(", cmake_text, re.MULTILINE),
        "CMake patch left a module loader registration")
cmake.write_text(cmake_text)

source = module.read_text()
source = replace_once(
    source,
    '#include "icecrown_citadel.h"',
    '#include "../../../src/server/scripts/Northrend/IcecrownCitadel/icecrown_citadel.h"',
    "ICC include path",
)
source = replace_once(
    source,
    '#include "SpellScript.h"\n',
    '#include "SpellScript.h"\n#include "ScriptedGossip.h"\n',
    "ScriptedGossip include",
)
source = replace_once(
    source,
    "void AddSC_mod_gunship_skip_scripts()",
    "void AddSC_boss_icecrown_gunship_battle()",
    "script loader name",
)
source = replace_once(
    source,
    "    // Master switch — when GunshipSkip.Enable = 0 in gunship_skip.conf, no\n"
    "    // scripts are registered and the server falls back to the core's\n"
    "    // stock Gunship Battle behaviour.\n"
    "    if (!sConfigMgr->GetOption<bool>(\"GunshipSkip.Enable\", true))\n"
    "        return;\n\n",
    "",
    "module-wide enable guard",
)
source = replace_all(
    source,
    "if (instance && instance->GetBossState(DATA_ICECROWN_GUNSHIP_BATTLE) != DONE)",
    'if (sConfigMgr->GetOption<bool>("GunshipSkip.Enable", true) && instance && '
    "instance->GetBossState(DATA_ICECROWN_GUNSHIP_BATTLE) != DONE)",
    "gossip enable guard",
)
require('#include "ScriptedGossip.h"' in source, "ScriptedGossip include was not applied")
require("void AddSC_boss_icecrown_gunship_battle()" in source, "core loader name was not applied")
require("AddSC_mod_gunship_skip_scripts" not in source, "old module loader name remains")
require("if (!sConfigMgr->GetOption<bool>(\"GunshipSkip.Enable\", true))" not in source,
        "module-wide enable guard remains")
require('sConfigMgr->GetOption<bool>("GunshipSkip.Enable", true) && instance' in source,
        "gossip enable guard was not applied")

core_text = core.read_text()
require("void AddSC_boss_icecrown_gunship_battle()" in core_text,
        "core ICC script no longer exposes the expected loader")
core.write_text(source)

module.rename(module.with_suffix(".cpp.disabled"))
loader.rename(loader.with_suffix(".cpp.disabled"))
stub.write_text("void Addmod_gunship_skipScripts() {}\n")
require(module.with_suffix(".cpp.disabled").is_file(), "module source was not disabled")
require(loader.with_suffix(".cpp.disabled").is_file(), "module loader was not disabled")
require(stub.read_text() == "void Addmod_gunship_skipScripts() {}\n", "module stub is invalid")
