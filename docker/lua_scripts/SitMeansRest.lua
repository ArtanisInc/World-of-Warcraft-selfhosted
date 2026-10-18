-- Source: https://github.com/Brytenwally/SitMeansRest
-- Revised for AzerothCore Eluna: each rest session owns only its own timer.

local CONFIG = {
    DURATION = 20,          -- Seconds to rest
    CHECK_INTERVAL = 500,   -- Check for movement every 500ms
    REGEN_AURA = 25990,     -- Graccu's Mistletoe (Fruitcake effect)
    SIT_EMOTE_ID = 86,      -- TEXT_EMOTE_SIT
}

-- Eluna Player:RemoveEvents() removes every Lua timer owned by the player.
-- Keep our timer id locally so this script never cancels timers from modules.
local REST_STATES = {}

local function GetStateKey(player)
    return player:GetGUIDLow()
end

local function StopResting(player, announce)
    if not player then return end

    local key = GetStateKey(player)
    local state = REST_STATES[key]
    if state and state.eventId then
        player:RemoveEventById(state.eventId)
    end
    REST_STATES[key] = nil
    player:RemoveAura(CONFIG.REGEN_AURA)

    if announce then
        player:SendAreaTriggerMessage("You stand up.")
    end
end

local function RestMovementCheck(event, delay, repeats, player)
    if not player then return end

    local state = REST_STATES[GetStateKey(player)]
    if not state or not player:HasAura(CONFIG.REGEN_AURA) then
        StopResting(player, false)
        return
    end

    local x, y = player:GetLocation()
    -- Cancel if player moves more than 0.1 yards.
    if math.abs(x - state.x) > 0.1 or math.abs(y - state.y) > 0.1 then
        StopResting(player, true)
        return
    end

    if repeats == 1 then
        StopResting(player, false)
        player:SendAreaTriggerMessage("|cff00ff00Fully Rested!|r")
    end
end

local function StartResting(player)
    StopResting(player, false)

    local x, y = player:GetLocation()
    player:AddAura(CONFIG.REGEN_AURA, player)
    player:SendAreaTriggerMessage("|cff00ccffResting...|r")

    local eventId = player:RegisterEvent(RestMovementCheck, CONFIG.CHECK_INTERVAL, CONFIG.DURATION * 2)
    REST_STATES[GetStateKey(player)] = { x = x, y = y, eventId = eventId }
end

local function OnEmote(event, player, textEmote, emoteNum, guid)
    if textEmote ~= CONFIG.SIT_EMOTE_ID then return end

    if player:IsInCombat() then
        player:SendBroadcastMessage("You can't rest while in combat!")
        return
    end

    StartResting(player)
end

local function OnLogout(event, player)
    StopResting(player, false)
end

RegisterPlayerEvent(24, OnEmote)
RegisterPlayerEvent(4, OnLogout) -- PLAYER_EVENT_ON_LOGOUT

print("[ALE] SitMeansRest enabled via /sit")
