-- Starter boost configuration
local TRIGGER_COMMAND = "starterboost"
local TRIGGER_COMMANDS = {starterboost = true, startbooster = true}
local MAX_LEVEL = 10
local DEATH_KNIGHT_MAX_LEVEL = 55
local GOLD_AMOUNT = 250 * 10000
local MAX_MONEY_AMOUNT = 2147483647
local BAG_ITEM_ID = 41600 -- Glacial Bag (22 slots)
local BAG_COUNT = 4
local CLAIM_TABLE = "custom_starter_boost_claims"
local ROUGH_ARROW_ITEM_ID = 2512
local LIGHT_SHOT_ITEM_ID = 2516
local RANGED_AMMO_COUNT = 200 -- Starter supply, usable from level 1
local HUNTER_GUN_ITEM_ID = 44093 -- Upgraded Dwarven Hand Cannon
local HUNTER_BOW_ITEM_ID = 42946 -- Charmed Ancient Bone Bow

local DREAD_PIRATE_RING = 50255
local MOUNT_ITEM_ID = 54811 -- Celestial Steed, same default as mod-startergear
local RIDING_SPELLS = {33388, 33391} -- Apprentice and Journeyman Riding

-- Weapon-training spell IDs required by each class profile below. They grant
-- the matching weapon skill; they are not race-specific. Dual Wield is included
-- where the kit contains two one-handed weapons.
local CLASS_WEAPON_SPELLS = {
    [1] = {197, 198, 264, 674}, -- Warrior: 2H axes, 1H maces, bows, dual wield
    [2] = {197, 198}, -- Paladin: 2H axes, 1H maces
    [3] = {197}, -- Hunter ranged training depends on its starter weapon.
    [4] = {1180, 264, 674}, -- Rogue: daggers, bows, dual wield
    [5] = {227}, -- Priest: staves
    [6] = {197, 198, 674}, -- Death Knight: 2H axes, 1H maces, dual wield
    [7] = {198, 674}, -- Shaman: 1H maces, dual wield
    [8] = {227}, -- Mage: staves
    [9] = {227}, -- Warlock: staves
    [11] = {227} -- Druid: staves
}

-- Dwarves and Tauren start with guns in 3.3.5. There is no heirloom
-- crossbow in the 3.3.5 item data, so all other hunters receive the bow.
local HUNTER_RANGED_KITS = {
    [3] = { item = HUNTER_GUN_ITEM_ID, ammo = LIGHT_SHOT_ITEM_ID, spell = 266 }, -- Dwarf: Guns
    [6] = { item = HUNTER_GUN_ITEM_ID, ammo = LIGHT_SHOT_ITEM_ID, spell = 266 }, -- Tauren: Guns
}
local DEFAULT_HUNTER_RANGED_KIT = {
    item = HUNTER_BOW_ITEM_ID,
    ammo = ROUGH_ARROW_ITEM_ID,
    spell = 264, -- Bows
}

local CLASS_WEAPON_RESOURCES = {
    [1] = {ROUGH_ARROW_ITEM_ID}, -- Warrior bow
    [4] = {ROUGH_ARROW_ITEM_ID} -- Rogue bow
}

local ITEM_COUNTS = {
    [ROUGH_ARROW_ITEM_ID] = RANGED_AMMO_COUNT,
    [LIGHT_SHOT_ITEM_ID] = RANGED_AMMO_COUNT,
}

local function GetHunterRangedKit(player)
    return HUNTER_RANGED_KITS[player:GetRace()] or DEFAULT_HUNTER_RANGED_KIT
end

local function GetWeaponTrainingSpells(player)
    local class = player:GetClass()
    local spells = CLASS_WEAPON_SPELLS[class] or {}
    if class ~= 3 then
        return spells
    end

    -- Do not mutate the class table; each hunter receives one ranged skill.
    return {197, GetHunterRangedKit(player).spell}
end

-- Complete heirloom profiles covering the useful specializations of each class.
-- Riding and the default mount follow mod-startergear's starter package.
local CLASS_BOOSTS = {
    [1] = { -- Warrior: two-handed, dual-wield and ranged pulling
        48685, 42949, 42943, 48716, 48716, 42946, 42991, 42991
    },
    [2] = { -- Paladin: melee and healing
        48685, 42949, 42943, 42948, 42991, 42992
    },
    [3] = { -- Hunter: ranged weapon added from its race-appropriate kit
        48677, 42950, 42943, 42991, 42991
    },
    [4] = { -- Rogue: dual-wield and ranged pulling
        48689, 42952, 42944, 44091, 42946, 42991, 42991
    },
    [5] = { -- Priest: damage and healing
        48691, 42985, 42947, 42992, 42992
    },
    [6] = { -- Death Knight: two-handed and dual-wield
        48685, 42949, 42943, 48716, 48716, 42991, 42991
    },
    [7] = { -- Shaman: enhancement, elemental and restoration
        48677, 48683, 42950, 42951, 48716, 48716, 42948, 42991, 42992
    },
    [8] = { -- Mage
        48691, 42985, 42947, 42992, 42992
    },
    [9] = { -- Warlock
        48691, 42985, 42947, 42992, 42992
    },
    [11] = { -- Druid: caster, healer and feral
        48687, 48689, 42984, 42952, 42947, 42992, 42991
    }
}

local function QueryClaim(guid)
    return CharDBQuery(
        string.format("SELECT 1 FROM `%s` WHERE `guid`=%u LIMIT 1", CLAIM_TABLE, guid)
    ) ~= nil
end

local function NewClaimToken(guid)
    -- Ownership, not secrecy: enough uniqueness to distinguish simultaneous
    -- reservations of the same character across world-server processes.
    return string.format("%u-%u-%u-%u", guid, GetGameTime(), GetCurrTime(), math.random(1, 2147483647))
end

local function ReserveClaim(guid, token)
    -- Execute synchronously: CharDBExecute is asynchronous, so selecting
    -- immediately after it can miss our own insert and falsely reject a new
    -- claim. INSERT IGNORE still makes exactly one token durable across
    -- simultaneous requests; the SELECT confirms which request owns it.
    CharDBQuery(
        string.format(
            "INSERT IGNORE INTO `%s` (`guid`, `claim_token`) VALUES (%u, '%s')",
            CLAIM_TABLE,
            guid,
            token
        )
    )
    local result = CharDBQuery(
        string.format("SELECT `claim_token` FROM `%s` WHERE `guid`=%u LIMIT 1", CLAIM_TABLE, guid)
    )
    return result and result:GetString(0) == token
end

local function ReleaseClaim(guid, token)
    -- A losing concurrent request must never remove the winner's reservation.
    CharDBQuery(
        string.format(
            "DELETE FROM `%s` WHERE `guid`=%u AND `claim_token`='%s'",
            CLAIM_TABLE,
            guid,
            token
        )
    )
end

local function BuildRewardList(player)
    local classItems = CLASS_BOOSTS[player:GetClass()]
    if not classItems then
        return nil
    end

    local rewards = {DREAD_PIRATE_RING, MOUNT_ITEM_ID}
    for _, itemId in ipairs(classItems) do
        rewards[#rewards + 1] = itemId
    end

    if player:GetClass() == 3 then
        local rangedKit = GetHunterRangedKit(player)
        rewards[#rewards + 1] = rangedKit.item
        rewards[#rewards + 1] = rangedKit.ammo
    end

    for _, itemId in ipairs(CLASS_WEAPON_RESOURCES[player:GetClass()] or {}) do
        rewards[#rewards + 1] = itemId
    end

    for _ = 1, BAG_COUNT do
        rewards[#rewards + 1] = BAG_ITEM_ID
    end

    return rewards
end

local function ValidateRewards(rewards)
    for _, itemId in ipairs(rewards) do
        if not GetItemTemplate(itemId) then
            PrintError(
                string.format("[ALE] Starter Boost: item template %u does not exist", itemId)
            )
            return false
        end
    end
    return true
end

local function CanClaimBoost(player, rewards)
    local maxLevel = player:GetClass() == 6 and DEATH_KNIGHT_MAX_LEVEL or MAX_LEVEL
    if player:GetLevel() > maxLevel then
        player:SendBroadcastMessage(
            "|cffff0000Erreur : cette commande est réservée aux personnages de niveau "
                .. maxLevel .. " maximum pour cette classe.|r"
        )
        return false
    end

    if QueryClaim(player:GetGUIDLow()) then
        player:SendBroadcastMessage(
            "|cffff0000Erreur : ce personnage a déjà récupéré son équipement de départ.|r"
        )
        return false
    end

    if player:GetCoinage() > MAX_MONEY_AMOUNT - GOLD_AMOUNT then
        player:SendBroadcastMessage(
            "|cffff0000Erreur : vous possédez trop d'or pour recevoir les 250 pièces d'or du kit.|r"
        )
        return false
    end

    if not rewards then
        player:SendBroadcastMessage(
            "|cffff0000Erreur : aucun profil d'équipement n'existe pour cette classe.|r"
        )
        return false
    end

    if not ValidateRewards(rewards) then
        player:SendBroadcastMessage(
            "|cffff0000Erreur : le kit est temporairement indisponible. Consultez les logs serveur.|r"
        )
        return false
    end

    local freeSlots = player:GetInventoryFreeSlots()
    if freeSlots < #rewards then
        player:SendBroadcastMessage(
            string.format(
                "|cffff0000Erreur : %u emplacements libres sont requis (%u disponibles).|r",
                #rewards,
                freeSlots
            )
        )
        return false
    end

    return true
end

local function ValidateUsableRewards(player, rewards)
    -- Let the core decide: it includes class, race, level, required spell,
    -- reputation and weapon proficiency, including custom data changes.
    for _, itemId in ipairs(rewards) do
        if not player:CanUseItem(itemId) then
            PrintError(
                string.format(
                    "[ALE] Starter Boost: class %u race %u cannot use item %u",
                    player:GetClass(),
                    player:GetRace(),
                    itemId
                )
            )
            return false
        end
    end
    return true
end

local function RollBackItems(player, grantedItems)
    for index = #grantedItems, 1, -1 do
        local grantedItem = grantedItems[index]
        player:RemoveItem(grantedItem.item, grantedItem.count)
    end
end

local function LearnMissingSpells(player, spells)
    for _, spellId in ipairs(spells or {}) do
        if not player:HasSpell(spellId) then
            player:LearnSpell(spellId)
        end
    end
end

local function GiveStarterBoost(player, rewards)
    local guid = player:GetGUIDLow()
    local claimToken = NewClaimToken(guid)
    if not ReserveClaim(guid, claimToken) then
        player:SendBroadcastMessage(
            "|cffff0000Erreur : ce personnage a déjà récupéré son équipement de départ.|r"
        )
        return
    end

    -- Learn weapon/riding spells first so CanUseItem checks the effective kit.
    LearnMissingSpells(player, GetWeaponTrainingSpells(player))
    LearnMissingSpells(player, RIDING_SPELLS)
    if not ValidateUsableRewards(player, rewards) then
        ReleaseClaim(guid, claimToken)
        player:SendBroadcastMessage(
            "|cffff0000Erreur : ce kit contient un objet incompatible avec votre race ou classe. Consultez les logs serveur.|r"
        )
        return
    end

    local grantedItems = {}
    for _, itemId in ipairs(rewards) do
        local count = ITEM_COUNTS[itemId] or 1
        local item = player:AddItem(itemId, count)
        if not item then
            RollBackItems(player, grantedItems)
            ReleaseClaim(guid, claimToken)
            player:SendBroadcastMessage(
                "|cffff0000Erreur : l'attribution a échoué et a été annulée. Libérez de la place puis réessayez.|r"
            )
            return
        end
        grantedItems[#grantedItems + 1] = {item = item, count = count}
    end

    player:ModifyMoney(GOLD_AMOUNT)
    player:SaveToDB()
    player:CastSpell(player, 63660, true)
    player:SendBroadcastMessage(
        "|cff00ff00Bonus de départ attribué : équipement, compétences et munitions, "
            .. BAG_COUNT .. " sacs 22 emplacements, monture, monte et 250 pièces d'or.|r"
    )
end

local function OnPlayerCommand(event, player, command)
    local trigger = command:match("%S+")
    if not trigger then
        return
    end

    trigger = trigger:lower():gsub("^%.", "")
    if not TRIGGER_COMMANDS[trigger] then
        return
    end

    if not player then
        PrintError("[ALE] Starter Boost: command is only available to in-game players")
        return false
    end

    local rewards = BuildRewardList(player)
    if CanClaimBoost(player, rewards) then
        GiveStarterBoost(player, rewards)
    end
    return false
end

RegisterPlayerEvent(42, OnPlayerCommand)

print(
    "[ALE] Starter Boost enabled via ."
        .. TRIGGER_COMMAND
        .. " or .startbooster (one claim per character, max level "
        .. MAX_LEVEL
        .. ", Death Knight "
        .. DEATH_KNIGHT_MAX_LEVEL
        .. ")"
)
