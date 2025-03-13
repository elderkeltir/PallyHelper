
local function IsEnabled()
    local playerClass, _ = UnitClass("player")
    local playerLevel = UnitLevel("player")

    return (playerClass == "Paladin" and playerLevel == 80)
end

local frame = nil
if IsEnabled() then
    frame = CreateFrame("Frame", "PallyHelper", UIParent)
    frame:SetSize(150, 50)
    frame:SetPoint("CENTER", UIParent, "CENTER", 50, -120) -- 15px lower
    frame:Hide()
end


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

local spellBindProt = { 
    ["Shield of Righteousness"] = "4", 
    ["Holy Shield"] = "3", 
    ["Hammer of the Righteous"] = "1", 
    ["Judgement of Wisdom"] = "E", 
    ["Consecration"] = "2"
}

local spellsRet = {
    ["Judgement of Wisdom"] = 1,
    ["Hammer of Wrath"] = 2,
    ["Crusader Strike"] = 3,
    ["Divine Storm"] = 4,
    ["Consecration"] = 5,
    ["Exorcism "] = 6
}

local spellBindRet = {
    ["Judgement of Wisdom"] = "E",
    ["Hammer of Wrath"] = "4",
    ["Crusader Strike"] = "1",
    ["Divine Storm"] = "3",
    ["Consecration"] = "2",
    ["Exorcism "] = "R"
}

local is6secNext = true;

-- Create 1 icon
local spellIcon = nil
if IsEnabled() then
    spellIcon = CreateFrame("Frame", nil, frame)
    spellIcon:SetSize(50, 50)
    spellIcon.texture = spellIcon:CreateTexture(nil, "ARTWORK")
    spellIcon.texture:SetAllPoints()
    spellIcon:SetPoint("LEFT", frame, "LEFT", 0, 0)

    spellIcon.text = spellIcon:CreateFontString(nil, "OVERLAY")
    spellIcon.text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE") -- Ensure valid font
    spellIcon.text:SetPoint("BOTTOMRIGHT", spellIcon, "BOTTOMRIGHT", -2, 2) -- Position in bottom-right
    spellIcon.text:SetText("") -- Example keybind
end

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

local function GetBind(spellname)
    -- print("Spec " .. GetSpec() .. "spellname " .. spellname)
    if GetSpec() == "Prot" then
        -- print("res " .. spellBindProt[spellname])
        return spellBindProt[spellname]

    elseif GetSpec() == "Ret" then
        -- print("res " .. spellBindRet[spellname])
        return spellBindRet[spellname]
    else
        return "T"
    end
end

-- function FindActionForSpell(spellName)
--     for slot = 1, 120 do
--         local texture = GetActionTexture(slot)
--         if texture then
--             local spellTexture = GetSpellTexture(spellName)  -- Get spell icon texture
--             if spellTexture and texture == spellTexture then
--                 print(slot)
--                 return slot -- Found matching spell on action bar
--             end
--         end
--     end
--     return nil
-- end


-- function GetKeybindForSpell(spellName)
--     local actionSlot = FindActionForSpell(spellName)
--     if actionSlot then
--         local keys = { GetBindingKey("ACTIONBUTTON" .. actionSlot) } -- Always a table
--         if #keys > 0 then
--             return table.concat(keys, ", ") -- Join keys if multiple bindings exist
--         end
--     end
--     return "Unbound"
-- end

-- function GetKeybindForSpell(spellName)
--     local actionSlot = FindActionForSpell(spellName)
--     if not actionSlot then
--         return "Unbound"
--     end

--     local keys = {}

--     -- Try Blizzard default bars
--     local blizzardBindings = {
--         [1] = "ACTIONBUTTON",  -- Main bar
--         [13] = "MULTIACTIONBAR1BUTTON",  -- Right bar 1
--         [25] = "MULTIACTIONBAR2BUTTON",  -- Right bar 2
--         [37] = "MULTIACTIONBAR3BUTTON",  -- Bottom left
--         [49] = "MULTIACTIONBAR4BUTTON",  -- Bottom right
--     }

--     for startSlot, bindingPrefix in pairs(blizzardBindings) do
--         if actionSlot >= startSlot and actionSlot < startSlot + 12 then
--             local buttonIndex = actionSlot - startSlot + 1
--             local bindingKey = GetBindingKey(bindingPrefix .. buttonIndex)
--             if bindingKey then
--                 table.insert(keys, bindingKey)
--             end
--         end
--     end

--     -- Try Bartender
--     local bt4binding = GetBindingKey("BT4Button" .. actionSlot)
--     if bt4binding then
--         table.insert(keys, bt4binding)
--     end

--     -- Return keybinds as a string
--     if #keys > 0 then
--         return table.concat(keys, ", ")
--     end

--     return "Unbound"
-- end



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
        -- -- local spellName = "Shield of Righteousness"  -- Example spell
        -- local spellName = available.spell

        -- local keybind = GetKeybindForSpell(spellName)
        -- print("Keybind for " .. spellName .. ": " .. keybind)

       spellIcon.text:SetText(GetBind(available.spell)) -- Example keybind

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
if IsEnabled() then
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED") -- Leaving combat
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entering combat
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED") 
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN") -- Spell cooldowns update

    eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
        if event == "ADDON_LOADED" and arg1 == "PallyHelper" then
            print("PallyHelper Loaded!") -- Debug print
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

end