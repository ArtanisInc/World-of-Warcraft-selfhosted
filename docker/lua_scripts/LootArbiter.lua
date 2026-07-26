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

-- Helper to check if a spec should be compared against both weapon slots
local function CanDualWield(spec)
    local dwSpecs = {
        ["Hunter"] = true,
        ["Rogue"] = true,
        ["Shamy Enh"] = true,
        ["War Fury"] = true,
        ["DK Frost"] = true
    }
    return dwSpecs[spec] or false
end

-- Maps Weapon Subclasses to Skill IDs for HasSkill check
local WEAPON_SKILL_MAP = {
    [0]  = 44,  -- One-Handed Axes
    [1]  = 172, -- Two-Handed Axes
    [2]  = 45,  -- Bows
    [3]  = 46,  -- Guns
    [4]  = 54,  -- One-Handed Maces
    [5]  = 160, -- Two-Handed Maces
    [6]  = 229, -- Polearms
    [7]  = 55,  -- One-Handed Swords
    [8]  = 172, -- Two-Handed Swords
    [10] = 136, -- Staves
    [13] = 473, -- Fist Weapons
    [15] = 173, -- Daggers
    [18] = 226, -- Crossbows
    [19] = 166, -- Wands
}

-- Maps Player Class ID to their maximum allowed Armor Subclass
local MAX_ARMOR_MAP = {
    [1]  = 4, -- Warrior: Plate
    [2]  = 4, -- Paladin: Plate
    [3]  = 3, -- Hunter: Mail
    [4]  = 2, -- Rogue: Leather
    [5]  = 1, -- Priest: Cloth
    [6]  = 4, -- DK: Plate
    [7]  = 3, -- Shaman: Mail
    [8]  = 1, -- Mage: Cloth
    [9]  = 1, -- Warlock: Cloth
    [11] = 2, -- Druid: Leather
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
local function GetScoreByEntry(entry, weights)
    local query = WorldDBQuery(string.format("SELECT * FROM item_template WHERE entry = %d", entry))
    if not query then return 0, nil end
    local row = query:GetRow()

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
        score = score + (row.dmg_max1 * weights.WPW)
    end

    return score, row
end

-- [5] THE DELAYED EXECUTION
local function ExecuteDelayedTransfer(wGUID, tGUID, itemEntry, improvement)
    local winner = GetPlayerByGUID(wGUID)
    local target = GetPlayerByGUID(tGUID)

    if not winner or not target then return end

    local item = winner:GetItemByEntry(itemEntry)

    if item then
        local itemName = item:GetName()
        local group = winner:GetGroup()
        local suffixId = item:GetRandomSuffix()

        print(LOG_PREFIX .. "Executing transfer: " .. itemName .. " to " .. target:GetName())

        local addedItem = target:AddItem(itemEntry, 1, suffixId)

        if not addedItem then
            SendMail("Arbiter Loot Distribution", "Your bags were full. Here is your upgrade: " .. itemName, target:GetGUIDLow(), 0, 61, 0, 0, 0, itemEntry, 1, suffixId)
            target:SendBroadcastMessage(COLOR_PREFIX .. "Your bags were full! |cff00ff00" .. itemName .. "|r has been sent to your mail.")
        end

        winner:RemoveItem(item, 1)

        if group then
            local announce = string.format(COLOR_PREFIX .. "Arbiter: %s (+%.2f) transferred to %s.", itemName, improvement, target:GetName())
            local members = group:GetMembers()
            for _, member in ipairs(members) do
                member:SendBroadcastMessage(announce)
            end
        end
    end
end

-- Helper to check talent status for specialized weapon handling
local function HasTalent(player, talentId)
    local activeSpec = player:GetActiveSpec() or 0
    return player:HasTalent(talentId, activeSpec)
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
                local isEligible = true

                -- [A] WEAPON SKILL & TALENT RESTRICTIONS
                if template.class == 2 then
                    -- Skill check
                    local requiredSkill = WEAPON_SKILL_MAP[template.subclass]
                    if requiredSkill and not member:HasSkill(requiredSkill) then
                        isEligible = false
                    end

                    -- New Talent-Specific Weapon Restrictions
                    local is2H = (template.InventoryType == 17)
                    local is1H = (template.InventoryType == 13 or template.InventoryType == 21 or template.InventoryType == 22)

                    if spec == "Shamy Enh" then
                        if not HasTalent(member, 23588) and not is2H then isEligible = false end
                        if HasTalent(member, 23588) and not is1H then isEligible = false end
                    end

                    if spec == "War Fury" then
                        if not HasTalent(member, 46917) and not is1H then isEligible = false end
                        if HasTalent(member, 46917) and not is2H then isEligible = false end
                    end
                end

                -- [B] ARMOR TYPE CHECK
                if template.class == 4 then
                    local maxArmor = MAX_ARMOR_MAP[member:GetClass()] or 1
                    if template.subclass > maxArmor then isEligible = false end
                end

                -- [C] SPELL POWER SANITY CHECK
                local hasSP = false
                for i = 1, 10 do if template["stat_type"..i] == 45 then hasSP = true break end end
                if hasSP and (weights.SP or 0) <= 0 then isEligible = false end

                -- [D] SPEC OPTIMIZATION
                local isBadOpt = (template.InventoryType == 17 and
                    (spec == "Pally Prot" or spec == "War Prot" or spec == "DK Frost" or spec == "Shamy Enh"))

                -- FINAL VALIDATION AND SCORING
                if isEligible and not isBadOpt then
                    local lootedScore = GetScoreByEntry(itemEntry, weights)
                    local currentScore = 0

                    if (template.InventoryType == 13 or template.InventoryType == 21 or template.InventoryType == 22) and CanDualWield(spec) then
                        local mhItem = member:GetEquippedItemBySlot(15)
                        local ohItem = member:GetEquippedItemBySlot(16)
                        local mhScore = mhItem and GetScoreByEntry(mhItem:GetEntry(), weights) or 0
                        local ohScore = ohItem and GetScoreByEntry(ohItem:GetEntry(), weights) or 0

                        if template.InventoryType == 21 then currentScore = mhScore
                        elseif template.InventoryType == 22 then currentScore = ohScore
                        else currentScore = math.min(mhScore, ohScore) end
                    else
                        local slot = INV_TO_SLOT[template.InventoryType]
                        local currentItem = slot and member:GetEquippedItemBySlot(slot)
                        currentScore = currentItem and GetScoreByEntry(currentItem:GetEntry(), weights) or 0
                    end

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
        local wGUID = winner:GetGUID()
        local tGUID = bestPlayer:GetGUID()
        CreateLuaEvent(function() ExecuteDelayedTransfer(wGUID, tGUID, itemEntry, maxImprovement) end, 200, 1)
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
