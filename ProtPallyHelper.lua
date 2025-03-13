local frame = CreateFrame("Frame", "ProtPallyHelper", UIParent)
frame:SetSize(150, 50)
frame:SetPoint("CENTER", UIParent, "CENTER", 50, -120) -- 15px lower
frame:Hide()

local spellsProt = {
    ["Shield of Righteousness"] = 1,
    ["Holy Shield"] = 2,
    ["Hammer of the Righteous"] = 3,
    ["Judgement of Wisdom"] = 4,
    ["Consecration"] = 5,
}

local spellDurationsProt = { 
    ["Shield of Righteousness"] = 6, 
    ["Holy Shield"] = 9, 
    ["Hammer of the Righteous"] = 6, 
    ["Judgement of Wisdom"] = 9, 
    ["Consecration"] = 9
}

local spellsRet = {
    ["Judgement of Wisdom"] = 1,
    ["Hammer of Wrath"] = 2,
    ["Crusader Strike"] = 3,
    ["Divine Storm"] = 4,
    ["Consecration"] = 5,
    ["Exorcism "] = 6
}

local is6secNext = true;

-- Create 1 icon

local spellIcon = CreateFrame("Frame", nil, frame)
spellIcon:SetSize(50, 50)
spellIcon.texture = spellIcon:CreateTexture(nil, "ARTWORK")
spellIcon.texture:SetAllPoints()
spellIcon:SetPoint("LEFT", frame, "LEFT", 0, 0)

local function IsProtectionSpec()
    local name, _, pointsSpent = GetTalentTabInfo(2) -- Protection is the 2nd tree
    return pointsSpent and pointsSpent > 31
end

local function IsRetributionSpec()
    local name, _, pointsSpent = GetTalentTabInfo(3) -- Protection is the 2nd tree
    return pointsSpent and pointsSpent > 31
end

local function GetSpec()
    if IsProtectionSpec() then
        return "Prot"
    elseif IsRetributionSpec() then
        return "Ret"
    else
        return "Holy"
    end
end

function hasArtOfWar()
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then break end
        if name == "The Art of War" then
            return true
        end
    end
    return false
end


local function GetBestAvailableSpell()
    local bestSpell = nil
    local bestPrio = 99  -- Set to a high value so any valid spell replaces it

    if GetSpec() == "Prot" then
        for spell, priority in pairs(spellsProt) do
            local start, duration = GetSpellCooldown(spell)
            local remainingCD = (start + duration - GetTime())
            
            if remainingCD < 1.5 and priority < bestPrio and ((is6secNext and spellDurationsProt[spell] == 6) or (not is6secNext and spellDurationsProt[spell] == 9)) then
                bestSpell = { spell = spell, start = start, duration = duration, priority = priority }
                bestPrio = priority
                -- print(string.format(">>> New Best Spell: %s (Priority: %d)", spell, priority))
            end
        end

    elseif GetSpec() == "Ret" then
        local target_hp = UnitHealth("target") / UnitHealthMax("target") * 100
        local player_mana = UnitPower("player", 0) / UnitPowerMax("player", 0) * 100

        for spell2, priority2 in pairs(spellsRet) do
            local start, duration = GetSpellCooldown(spell2)
            if duration == nil then
                -- print(spell2)
                start, duration = GetSpellCooldown(48801)
            end
            local remainingCD = (start + duration - GetTime())
            local insta_exorcism = hasArtOfWar()

            if remainingCD < 1.5 and priority2 < bestPrio then

                if spell2 == "Hammer of Wrath" and target_hp < 20 then
                    bestSpell = { spell = spell2, start = start, duration = duration, priority = priority2 }
                    bestPrio = priority2
                elseif spell2 == "Consecration" and player_mana > 30 then
                    bestSpell = { spell = spell2, start = start, duration = duration, priority = priority2 }
                    bestPrio = priority2
                elseif spell2 == "Exorcism" and insta_exorcism then
                    bestSpell = { spell = spell2, start = start, duration = duration, priority = priority }
                    bestPrio = priority2
                elseif spell2 ~= "Hammer of Wrath" and spell2 ~= "Consecration" and spell2 ~= "Exorcism" then
                    bestSpell = { spell = spell2, start = start, duration = duration, priority = priority2 }
                    bestPrio = priority2
                end
            end
        end
    end

    return bestSpell  -- Returns nil if no spell meets the criteria
end

local function UpdateIcons()
    if not UnitAffectingCombat("player") then
        frame:Hide()
        return
    end

    if (not IsProtectionSpec()) and (not IsRetributionSpec()) then
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
        if start == nil then
            start, duration = GetSpellCooldown(48801) -- Check cooldown
        end
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
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" and IsProtectionSpec() then
        local spellName = GetSpellInfo(arg2)
        if spellsProt[spellName] then
            local duration = spellDurationsProt[spellName]
            if duration == 6 then
                is6secNext = false
            elseif duration == 9 then
                is6secNext = true
            end
            -- print(string.format("Cast: %s, Duration: %d sec, Next: %s", spellName, duration, is6secNext and "9-sec spell" or "6-sec spell"))
        end
    end
end)

