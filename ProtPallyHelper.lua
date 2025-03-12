local frame = CreateFrame("Frame", "ProtPallyHelper", UIParent)
frame:SetSize(150, 50)
frame:SetPoint("CENTER", UIParent, "CENTER", 50, -120) -- 15px lower
frame:Hide()

local spells = {
    ["Shield of Righteousness"] = 1,
    ["Holy Shield"] = 2,
    ["Hammer of the Righteous"] = 3,
    ["Judgement of Wisdom"] = 4,
    ["Consecration"] = 5,
}

local spellDurations = { 
    ["Shield of Righteousness"] = 6, 
    ["Holy Shield"] = 9, 
    ["Hammer of the Righteous"] = 6, 
    ["Judgement of Wisdom"] = 9, 
    ["Consecration"] = 9
}

local is6secNext = true;

-- Create 1 icon

local spellIcon = CreateFrame("Frame", nil, frame)
spellIcon:SetSize(50, 50)
spellIcon.texture = spellIcon:CreateTexture(nil, "ARTWORK")
spellIcon.texture:SetAllPoints()
spellIcon:SetPoint("LEFT", frame, "LEFT", 0, 0)


local function GetBestAvailableSpell()
    local bestSpell = nil
    local bestPrio = 99  -- Set to a high value so any valid spell replaces it

    for spell, priority in pairs(spells) do
        local start, duration = GetSpellCooldown(spell)
        local remainingCD = (start + duration - GetTime())
        
        if remainingCD < 1.5 and priority < bestPrio and ((is6secNext and spellDurations[spell] == 6) or (not is6secNext and spellDurations[spell] == 9)) then
            bestSpell = { spell = spell, start = start, duration = duration, priority = priority }
            bestPrio = priority
            -- print(string.format(">>> New Best Spell: %s (Priority: %d)", spell, priority))
        end
    end

    return bestSpell  -- Returns nil if no spell meets the criteria
end


local function IsProtectionSpec()
    local name, _, pointsSpent = GetTalentTabInfo(2) -- Protection is the 2nd tree
    return pointsSpent and pointsSpent > 31
end

local function UpdateIcons()
    if not UnitAffectingCombat("player") then
        frame:Hide()
        return
    end

    if not IsProtectionSpec() then
        frame:Hide()
        return
    end

    frame:Show()

    local available = GetBestAvailableSpell()

    -- Ensure that the leftmost icon always shows the next spell to cast
    if available then
        local texture = GetSpellTexture(available.spell)
        spellIcon.texture:SetTexture(texture)

        local inRange = IsSpellInRange(available.spell, "target") -- Check range
        local start, duration = GetSpellCooldown(available.spell) -- Check cooldown
        local isUsable, notEnoughMana = IsUsableSpell(available.spell) -- Check mana

        -- Default color (fully available)
        spellIcon.texture:SetVertexColor(1, 1, 1, 1) 

        -- Apply color filters
        if inRange == 0 then
            spellIcon.texture:SetVertexColor(1, 0, 0, 1)  -- Red (out of range)
        elseif notEnoughMana then
            spellIcon.texture:SetVertexColor(0, 0, 1, 1)  -- Blue (not enough mana)
        elseif duration > 0 then
            spellIcon.texture:SetVertexColor(0.5, 0.5, 0.5, 1)  -- Gray (on cooldown)
        end
    else
        spellIcon.texture:SetTexture(nil)
    end
end

-- Periodic update function
local function PeriodicUpdate()
    if UnitAffectingCombat("player") then
        UpdateIcons() -- Update the icons every time while in combat
    end
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED") -- Leaving combat
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entering combat
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED") 
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN") -- Spell cooldowns update

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" and arg1 == "ProtPallyHelper" then
        print("ProtPallyHelper Loaded!") -- Debug print
    elseif event == "PLAYER_REGEN_ENABLED" then
        frame:Hide()
    elseif event == "PLAYER_REGEN_DISABLED" then
        UpdateIcons()
        frame:SetScript("OnUpdate", function(self, elapsed)
            PeriodicUpdate()
        end)
    -- elseif event == "PLAYER_TALENT_UPDATE" then
    --     UpdateIcons()
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        -- Update icons and rotation when cooldown changes
        UpdateIcons()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" then
        local spellName = GetSpellInfo(arg2)
        if spells[spellName] then
            local duration = spellDurations[spellName]
            if duration == 6 then
                is6secNext = false
            elseif duration == 9 then
                is6secNext = true
            end
            -- print(string.format("Cast: %s, Duration: %d sec, Next: %s", spellName, duration, is6secNext and "9-sec spell" or "6-sec spell"))
        end
    end
end)

