-- Source: https://github.com/Brytenwally/Loot-Arbiter
-- Revision: c0cd6e4d2cf434672398544edc534aae52d80570
-- Local safety policy: only completed group rolls may trigger a transfer.

local LOG_PREFIX = "[SpecArbiter] "
local COLOR_PREFIX = "|cff00ff00[SpecArbiter]|r "

-- [1] DATA MAPS
local STAT_ID_MAP = {
    [4]="STR", [3]="AGI", [7]="STA", [5]="INT", [6]="SPI", [38]="AP", [45]="SP",
    [31]="HIT", [32]="CRIT", [36]="HASTE", [37]="EXP", [12]="DEF", [13]="DODGE",
    [14]="PARRY", [15]="BLOCK", [30]="ARM", [44]="ARPEN"
}

local INV_TO_SLOT = {
    [1]  = 0,  -- Head
    [2]  = 1,  -- Neck
    [3]  = 2,  -- Shoulders
    [5]  = 4,  -- Chest
    [6]  = 5,  -- Waist
    [7]  = 6,  -- Legs
    [8]  = 7,  -- Feet
    [9]  = 8,  -- Wrists
    [10] = 9,  -- Hands
    [11] = 10, -- Finger 1
    [12] = 12, -- Trinket 1
    [13] = 15, -- One-Hand (Slot 15)
    [14] = 16, -- Shield/Off-hand (Slot 16)
    [15] = 18, -- Ranged
    [16] = 14, -- Back
    [17] = 15, -- Two-Hand (Slot 15)
    [20] = 4,  -- Robe
    [21] = 15, -- Main Hand
    [22] = 16, -- Off Hand
}

-- [2] MASTER WEIGHTS (Derived from C++ StatsWeightCalculator)
local MASTER_WEIGHTS = {
    -- Melee/Phys Classes
    ["Hunter_0"] = {STA=0.1, ARM=0.001, AGI=2.5, AP=1.0, ARPEN=1.5, HIT=1.7, CRIT=1.4, HASTE=1.6, SP=0.0, WPW=7.51},
    ["Hunter_1"] = {STA=0.1, ARM=0.001, AGI=2.3, AP=1.0, ARPEN=2.25, HIT=2.1, CRIT=2.0, HASTE=1.8, SP=0.0, WPW=10.01},
    ["Hunter_2"] = {STA=0.1, ARM=0.001, AGI=2.5, AP=1.0, ARPEN=1.5, HIT=1.7, CRIT=1.4, HASTE=1.6, SP=0.0, WPW=7.51},
    ["Rogue_1"] = {STA=0.1, ARM=0.001, AGI=1.9, STR=1.1, AP=1.0, ARPEN=1.8, HIT=2.1, CRIT=1.4, HASTE=1.7, SP=0.0, EXP=2.0, WPW=7.01},
    ["Rogue_0"] = {STA=0.1, ARM=0.001, AGI=1.5, STR=1.1, AP=1.0, ARPEN=1.2, HIT=2.1, CRIT=1.1, HASTE=1.8, SP=0.0, EXP=2.1, WPW=5.01},
    ["Rogue_2"] = {STA=0.1, ARM=0.001, AGI=1.5, STR=1.1, AP=1.0, ARPEN=1.2, HIT=2.1, CRIT=1.1, HASTE=1.8, SP=0.0, EXP=2.1, WPW=5.01},
    ["War Arms"] = {STA=0.1, ARM=0.001, AGI=0.8, STR=2.5, AP=0.8, ARPEN=1.7, HIT=2.0, CRIT=1.9, HASTE=0.8, SP=-2.0, EXP=1.4, WPW=7.01},
    ["War Fury"] = {STA=0.1, ARM=0.001, AGI=0.8, STR=2.5, AP=0.8, ARPEN=2.1, HIT=2.3, CRIT=2.2, HASTE=0.8, SP=-2.0, EXP=2.5, WPW=7.01},
    ["War Prot"] = {STA=3.1, ARM=0.151, AGI=0.2, STR=1.3, AP=0.2, HIT=2.0, DEF=2.5, PARRY=2.0, DODGE=2.0, BLOCK=1.0, SP=-2.0, EXP=3.0, WPW=2.01},
    ["DK Blood"] = {STA=3.1, ARM=0.151, AGI=0.2, STR=1.3, AP=0.2, HIT=2.0, DEF=2.5, PARRY=2.0, DODGE=2.0, SP=-1.0, EXP=3.0, WPW=2.01},
    ["DK Frost"] = {STA=0.1, ARM=0.001, AGI=0.5, STR=2.5, AP=0.5, ARPEN=2.7, HIT=2.3, CRIT=2.2, HASTE=2.1, SP=-1.0, EXP=2.5, WPW=7.01},
    ["DK Unhol"] = {STA=0.1, ARM=0.001, AGI=0.5, STR=2.5, AP=0.5, ARPEN=1.3, HIT=2.2, CRIT=1.7, HASTE=1.8, SP=-1.0, EXP=1.5, WPW=5.01},
    ["Pally Ret"] = {STA=0.1, ARM=0.001, AGI=0.5, STR=2.5, AP=0.5, ARPEN=1.5, HIT=1.9, CRIT=1.7, HASTE=1.6, EXP=2.0, WPW=9.01},
    ["Pally Prot"] = {STA=3.1, ARM=0.151, AGI=0.2, STR=1.3, AP=0.2, HIT=2.0, DEF=2.5, PARRY=2.0, DODGE=2.0, BLOCK=1.0, SP=-2.0, EXP=3.0, WPW=2.01},
    ["Shamy Enh"] = {STA=0.1, ARM=0.001, AGI=1.4, STR=1.1, INT=0.3, AP=1.0, ARPEN=0.9, HIT=2.1, CRIT=1.5, HASTE=1.8, SP=0.5, EXP=2.0, WPW=8.51},
    ["Druid_Feral_DPS"] = {STA=0.1, ARM=0.001, AGI=2.2, STR=2.4, AP=1.0, ARPEN=2.3, HIT=1.9, CRIT=1.5, HASTE=2.1, EXP=2.1, WPW=15.01},
    ["Druid Bear"] = {STA=4.0, ARM=0.151, AGI=2.2, STR=2.4, AP=1.0, DEF=0.3, DODGE=0.7, HIT=3.0, CRIT=1.3, HASTE=2.3, EXP=3.7, WPW=3.01},
    -- Casters & Healers
    ["Caster"] = {STA=0.1, ARM=0.001, INT=0.3, SPI=0.6, HIT=1.1, CRIT=0.8, HASTE=1.0, SP=1.0, AP=-1.0, WPW=1.01},
    ["Mage Fire"] = {STA=0.1, ARM=0.001, INT=0.3, SPI=0.7, HIT=1.2, CRIT=1.1, HASTE=0.8, SP=1.0, AP=-1.0, WPW=1.01},
    ["Shamy Ele"] = {STA=0.1, ARM=0.001, INT=0.5, HIT=1.1, CRIT=0.8, HASTE=1.0, SP=1.2, MN_R=0.5, WPW=0.01},
    ["Shamy Resto"] = {STA=0.1, ARM=0.001, INT=0.9, SPI=0.15, CRIT=0.6, HASTE=0.8, SP=1.0, MN_R=0.9, WPW=0.01},
    ["Pally Holy"] = {STA=0.1, ARM=0.001, INT=0.9, SPI=0.15, CRIT=0.6, HASTE=0.8, SP=1.0, MN_R=0.9, WPW=0.01},
    ["Healer"] = {STA=0.1, ARM=0.001, INT=0.8, SPI=0.6, CRIT=0.6, HASTE=0.8, SP=1.0, MN_R=0.9, AP=-1.0, WPW=1.01},
	["Warlock"] = {STA=0.1, ARM=0.001, INT=0.3, SPI=0.6, HIT=1.1, CRIT=0.8, HASTE=1.0, SP=1.0, AP=-1.0, WPW=1.01},

}

-- [3] HEURISTIC SPEC IDENTIFIER
local function GetHeuristicSpec(player)
    local class = player:GetClass()
    local tree = player:GetMostPointsTalentTree()
    local activeSpec = player:GetActiveSpec() or 0

    if class == 1 then -- Warrior
        if tree == 0 then return "War Arms" elseif tree == 1 then return "War Fury" else return "War Prot" end
    elseif class == 2 then -- Paladin
        if tree == 0 then return "Pally Holy" elseif tree == 1 then return "Pally Prot" else return "Pally Ret" end
    elseif class == 3 then -- Hunter
        return "Hunter_" .. tree
    elseif class == 4 then -- Rogue
        return "Rogue_" .. tree
    elseif class == 5 then -- Priest
        return (tree == 2) and "Caster" or "Healer"
    elseif class == 6 then -- Death Knight
        if tree == 0 then return "DK Blood" elseif tree == 1 then return "DK Frost" else return "DK Unhol" end
    elseif class == 7 then -- Shaman
        if tree == 0 then return "Shamy Ele" elseif tree == 1 then return "Shamy Enh" else return "Shamy Resto" end
    elseif class == 8 then -- Mage
        return (tree == 1) and "Mage Fire" or "Caster"
    elseif class == 9 then -- Warlock
        return "Caster"
    elseif class == 11 then -- Druid
        if tree == 0 then return "Caster" elseif tree == 2 then return "Healer"
        else return player:HasTalent(16929, activeSpec) and "Druid Bear" or "Druid_Feral_DPS" end
    end
    return "Unknown"
end

-- [4] CORE SCORING ENGINE
local ITEM_TEMPLATE_CACHE = {}

local function GetItemTemplateRow(entry)
    local cached = ITEM_TEMPLATE_CACHE[entry]
    if cached ~= nil then
        return cached or nil
    end

    local query = WorldDBQuery(string.format("SELECT * FROM item_template WHERE entry = %d", entry))
    local row = query and query:GetRow() or false
    ITEM_TEMPLATE_CACHE[entry] = row
    return row or nil
end

local function GetScoreByEntry(entry, weights)
    local row = GetItemTemplateRow(entry)
    if not row then return 0, nil end

    local score = 0
    -- Standard Stat Scoring
    for i = 1, 10 do
        local sType = row["stat_type"..i]
        local sVal  = row["stat_value"..i]
        local key   = STAT_ID_MAP[sType]
        if key and sVal and sVal > 0 then
            score = score + (sVal * (weights[key] or 0))
        end
    end

    -- Armor Scaling (New requirement from C++ code)
    if weights["ARM"] and row["armor"] then
        score = score + (row["armor"] * weights["ARM"])
    end

    -- Weapon Damage Scaling
    if row.class == 2 and weights.WPW then
        score = score + ((row.dmg_max1 or 0) * weights.WPW)
    end

    return score, row
end

-- [5] SAFE AWARD NOTICE
-- Eluna cannot move an item instance between inventories. Recreating it loses
-- its instance data (enchantments, gems, durability and random properties),
-- while removing by entry can delete a different item. Never transfer/delete
-- loot from Lua: announce the recommendation and leave the completed roll intact.
local function AnnounceRecommendation(winner, target, itemName, improvement)
    local group = winner:GetGroup()
    if not group then return end

    local announce = string.format(
        COLOR_PREFIX .. "Arbiter recommendation: %s (+%.2f) would suit %s. Loot remains with roll winner %s.",
        itemName, improvement, target:GetName(), winner:GetName()
    )
    for _, member in ipairs(group:GetMembers()) do
        member:SendBroadcastMessage(announce)
    end
end

local function GetCurrentScore(member, template, weights)
    local inventoryType = template.InventoryType
    local function ScoreSlot(slot)
        local equipped = member:GetEquippedItemBySlot(slot)
        return equipped and GetScoreByEntry(equipped:GetEntry(), weights) or 0
    end

    if inventoryType == 11 then -- Finger: compare with weaker ring.
        return math.min(ScoreSlot(10), ScoreSlot(11))
    end
    if inventoryType == 12 then -- Trinket: compare with weaker trinket.
        return math.min(ScoreSlot(12), ScoreSlot(13))
    end
    if inventoryType == 13 then -- One-hand: use off-hand only when Dual Wield is learned.
        if member:HasSpell(674) then
            return math.min(ScoreSlot(15), ScoreSlot(16))
        end
        return ScoreSlot(15)
    end

    local slot = INV_TO_SLOT[inventoryType]
    return slot and ScoreSlot(slot) or 0
end

-- [6] CORE EVALUATION & REWARD HANDLER
local function EvaluateAndTransferLoot(winner, item)
    local group = winner:GetGroup()
    if not group then return end

    local itemEntry = item:GetEntry()
    local _, template = GetScoreByEntry(itemEntry, {})

    if not template then return end

    local bestPlayer = nil
    local maxImprovement = 0
    local members = group:GetMembers()

    for _, member in ipairs(members) do
        if member and member:IsInWorld() then
            local spec = GetHeuristicSpec(member)
            local weights = MASTER_WEIGHTS[spec]

            if weights then
                -- CanUseItem validates the real character restrictions: class,
                -- race, level, proficiency, reputation and requirements.
                -- ALE's CanUseItem binding accepts the item entry ID, not an
                -- Item userdata. Passing the rolled object raises a Lua
                -- binding type error and aborts recommendation processing.
                local isEligible = member:CanUseItem(itemEntry)

                -- [C] SPELL POWER SANITY CHECK
                local hasSP = false
                for i = 1, 10 do if template["stat_type"..i] == 45 then hasSP = true break end end
                if hasSP and (weights.SP or 0) <= 0 then isEligible = false end

                -- FINAL VALIDATION AND SCORING
                if isEligible then
                    local lootedScore = GetScoreByEntry(itemEntry, weights)
                    local currentScore = GetCurrentScore(member, template, weights)

                    local improvement = lootedScore - currentScore
                    if improvement > maxImprovement then
                        maxImprovement = improvement
                        bestPlayer = member
                    end
                end
            end
        end
    end

    if bestPlayer and bestPlayer:GetGUID() ~= winner:GetGUID() and maxImprovement > 0 then
        AnnounceRecommendation(winner, bestPlayer, item:GetName(), maxImprovement)
    end
end

-- [7] EVENT ROUTERS
local function OnGroupRollReward(event, winner, item, count, voteType, roll)
    if not winner or not item or not winner:GetGroup() then return end
    EvaluateAndTransferLoot(winner, item)
end

local function OnPlayerChat(event, player, msg, type, lang)
    local command = msg:lower()
    if command == ".lootspec" or command == "lootspec" then
        local spec = GetHeuristicSpec(player)
        player:SendBroadcastMessage(COLOR_PREFIX .. "Detected Spec: " .. spec)
        return false
    end
end

-- [8] REGISTRATIONS
RegisterPlayerEvent(18, OnPlayerChat)
RegisterPlayerEvent(56, OnGroupRollReward) -- PLAYER_EVENT_ON_GROUP_ROLL_REWARD

print("[ALE] Loot Arbiter enabled for group-roll rewards")
