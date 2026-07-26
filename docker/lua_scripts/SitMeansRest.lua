-- Source: https://github.com/Brytenwally/SitMeansRest
-- Revision: 52a119dd4ca307c5ff95740029156d604bd03713

local CONFIG = {
    DURATION = 20,          -- Seconds to rest
    CHECK_INTERVAL = 500,   -- Check for movement every 500ms
    REGEN_AURA = 25990,     -- Graccu's Mistletoe (Fruitcake effect)
    EVENT_ID = 99100,
    SIT_EMOTE_ID = 86,      -- TEXT_EMOTE_SIT
}

local function StopResting(player)
    if not player then return end

    player:RemoveAura(CONFIG.REGEN_AURA)
    player:RemoveEvents(CONFIG.EVENT_ID)
    player:SetData("RestX", nil)
    player:SetData("RestY", nil)
    player:SendAreaTriggerMessage("You stand up.")
end

local function RestMovementCheck(event, delay, repeats, player)
    if not player or not player:HasAura(CONFIG.REGEN_AURA) then
        StopResting(player)
        return
    end

    local x, y = player:GetLocation()
    local oldX = player:GetData("RestX") or 0
    local oldY = player:GetData("RestY") or 0

    -- Cancel if player moves more than 0.1 yards
    if math.abs(x - oldX) > 0.1 or math.abs(y - oldY) > 0.1 then
        StopResting(player)
        return
    end

    if repeats == 1 then
        player:RemoveAura(CONFIG.REGEN_AURA)
        player:SendAreaTriggerMessage("|cff00ff00Fully Rested!|r")
    end
end

local function OnEmote(event, player, textEmote, emoteNum, guid)
    if textEmote == CONFIG.SIT_EMOTE_ID then
        if player:IsInCombat() then
            player:SendBroadcastMessage("You can't rest while in combat!")
            return
        end

        -- Record initial position
        local x, y = player:GetLocation()
        player:SetData("RestX", x)
        player:SetData("RestY", y)

        -- Apply Regen Aura (Fruitcake effect)
        player:AddAura(CONFIG.REGEN_AURA, player)
        player:SendAreaTriggerMessage("|cff00ccffResting...|r")

        -- Start the movement checker
        player:RemoveEvents(CONFIG.EVENT_ID)
        player:RegisterEvent(RestMovementCheck, CONFIG.CHECK_INTERVAL, CONFIG.DURATION * 2, CONFIG.EVENT_ID)
    end
end

RegisterPlayerEvent(24, OnEmote)

print("[ALE] SitMeansRest enabled via /sit")
