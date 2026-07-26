-- Starter boost configuration
local TRIGGER_COMMAND = "starterboost"
local MAX_LEVEL = 10
local GOLD_AMOUNT = 250 * 10000
local MAX_MONEY_AMOUNT = 2147483647
local BAG_ITEM_ID = 41600 -- Glacial Bag (22 slots)
local BAG_COUNT = 4
local CLAIM_TABLE = "custom_starter_boost_claims"

local DREAD_PIRATE_RING = 50255
local MOUNT_ITEM_ID = 54811 -- Celestial Steed, same default as mod-startergear
local RIDING_SPELLS = {33388, 33391} -- Apprentice and Journeyman Riding

-- Complete heirloom profiles covering the useful specializations of each class.
-- Riding and the default mount follow mod-startergear's starter package.
local CLASS_BOOSTS = {
    [1] = { -- Warrior: two-handed, dual-wield and ranged pulling
        48685, 42949, 42943, 48716, 48716, 42946, 42991, 42991
    },
    [2] = { -- Paladin: melee and healing
        48685, 42949, 42943, 42948, 42991, 42992
    },
    [3] = { -- Hunter: ranged and melee backup
        48677, 42950, 42946, 42943, 42991, 42991
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

local function ReserveClaim(guid)
    -- CharDBQuery is deliberately used for these writes because it is synchronous.
    CharDBQuery(
        string.format("INSERT IGNORE INTO `%s` (`guid`) VALUES (%u)", CLAIM_TABLE, guid)
    )
    return QueryClaim(guid)
end

local function ReleaseClaim(guid)
    CharDBQuery(
        string.format("DELETE FROM `%s` WHERE `guid`=%u", CLAIM_TABLE, guid)
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
    if player:GetLevel() > MAX_LEVEL then
        player:SendBroadcastMessage(
            "|cffff0000Erreur : cette commande est réservée aux personnages de niveau "
                .. MAX_LEVEL .. " maximum.|r"
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

local function RollBackItems(player, grantedItems)
    for index = #grantedItems, 1, -1 do
        player:RemoveItem(grantedItems[index], 1)
    end
end

local function GiveStarterBoost(player, rewards)
    local guid = player:GetGUIDLow()
    if not ReserveClaim(guid) then
        player:SendBroadcastMessage(
            "|cffff0000Erreur : impossible d'enregistrer le bonus. Réessayez plus tard.|r"
        )
        return
    end

    local grantedItems = {}
    for _, itemId in ipairs(rewards) do
        local item = player:AddItem(itemId, 1)
        if not item then
            RollBackItems(player, grantedItems)
            ReleaseClaim(guid)
            player:SendBroadcastMessage(
                "|cffff0000Erreur : l'attribution a échoué et a été annulée. Libérez de la place puis réessayez.|r"
            )
            return
        end
        grantedItems[#grantedItems + 1] = item
    end

    for _, spellId in ipairs(RIDING_SPELLS) do
        if not player:HasSpell(spellId) then
            player:LearnSpell(spellId)
        end
    end
    player:ModifyMoney(GOLD_AMOUNT)
    player:SaveToDB()
    player:CastSpell(player, 63660, true)
    player:SendBroadcastMessage(
        "|cff00ff00Bonus de départ attribué : équipement multi-spécialisations, "
            .. BAG_COUNT .. " sacs 22 emplacements, monture, monte et 250 pièces d'or.|r"
    )
end

local function OnPlayerCommand(event, player, command)
    local trigger = command:match("%S+")
    if not trigger then
        return
    end

    trigger = trigger:lower():gsub("^%.", "")
    if trigger ~= TRIGGER_COMMAND then
        return
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
        .. " (one claim per character, max level "
        .. MAX_LEVEL
        .. ")"
)
