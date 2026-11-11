-- AutoTrack: one secure button that always holds the tracking spell matching
-- your target's creature type. Blizzard requires a key press/click to cast,
-- and secure buttons can't be changed in combat, so the button is retargeted
-- out of combat and only warns you during combat.

local ADDON = ...

BINDING_HEADER_AUTOTRACK = "AutoTrack"
_G["BINDING_NAME_CLICK AutoTrackButton:LeftButton"] = "Cast matching tracking"

-- Creature type ID -> tracking spell ID
-- 1 Beast, 2 Dragonkin, 3 Demon, 4 Elemental, 5 Giant, 6 Undead, 7 Humanoid
local TRACK_BY_TYPE_ID = {
	[1] = 1494,  -- Track Beasts
	[2] = 19879, -- Track Dragonkin
	[3] = 19878, -- Track Demons
	[4] = 19880, -- Track Elementals
	[5] = 19882, -- Track Giants
	[6] = 19884, -- Track Undead
	[7] = 19883, -- Track Humanoids
}

-- Fixed modifier per creature type, used to pick a tracking manually in combat.
-- Prefix order must match SecureButton_GetModifierPrefix: alt-ctrl-shift-
local MOD_BY_TYPE = {
	[7] = { prefix = "shift",          label = "Shift" },        -- Humanoid
	[1] = { prefix = "ctrl",           label = "Ctrl" },         -- Beast
	[6] = { prefix = "alt",            label = "Alt" },          -- Undead
	[3] = { prefix = "ctrl-shift",     label = "Ctrl+Shift" },   -- Demon
	[4] = { prefix = "alt-shift",      label = "Alt+Shift" },    -- Elemental
	[2] = { prefix = "alt-ctrl",       label = "Alt+Ctrl" },     -- Dragonkin
	[5] = { prefix = "alt-ctrl-shift", label = "Alt+Ctrl+Shift" }, -- Giant
}

-- English fallback if C_CreatureInfo isn't available
local ENGLISH_TYPE_IDS = {
	Beast = 1, Dragonkin = 2, Demon = 3, Elemental = 4,
	Giant = 5, Undead = 6, Humanoid = 7,
}

local typeNameToId = {}
local function BuildTypeMap()
	wipe(typeNameToId)
	for name, id in pairs(ENGLISH_TYPE_IDS) do typeNameToId[name] = id end
	if C_CreatureInfo and C_CreatureInfo.GetCreatureTypeInfo then
		for id = 1, 7 do
			local info = C_CreatureInfo.GetCreatureTypeInfo(id)
			if info and info.name then typeNameToId[info.name] = id end
		end
	end
end

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	return (GetSpellInfo(id))
end

local function SpellIcon(id)
	if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
	return GetSpellTexture(id)
end

local function Knows(id)
	if IsPlayerSpell then return IsPlayerSpell(id) end
	return IsSpellKnown(id)
end

-- Spell ID of the currently active spell-type tracking, if any
local function ActiveTrackingSpell()
	for i = 1, C_Minimap.GetNumTrackingTypes() do
		local t = C_Minimap.GetTrackingInfo(i)
		if t and t.type == "spell" and t.active then return t.spellID end
	end
end

-- Tracking spell we want for the current target, or nil
local function WantedSpell()
	if not UnitExists("target") or UnitIsDead("target") then return end
	if not UnitCanAttack("player", "target") then return end
	local typeId = typeNameToId[UnitCreatureType("target") or ""]
	local spell = typeId and TRACK_BY_TYPE_ID[typeId]
	if spell and Knows(spell) then return spell, typeId end
end

---------------------------------------------------------------------------
-- Button
---------------------------------------------------------------------------
local btn = CreateFrame("Button", "AutoTrackButton", UIParent, "SecureActionButtonTemplate")
btn:SetSize(36, 36)
btn:SetPoint("CENTER", 0, -150)
btn:RegisterForClicks("AnyUp", "AnyDown") -- works with either ActionButtonUseKeyDown setting
btn:SetAttribute("type", "spell")
btn:SetMovable(true)
btn:SetClampedToScreen(true)
btn:RegisterForDrag("LeftButton")

btn.icon = btn:CreateTexture(nil, "ARTWORK")
btn.icon:SetAllPoints()
btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

btn.border = btn:CreateTexture(nil, "OVERLAY")
btn.border:SetPoint("TOPLEFT", -3, 3)
btn.border:SetPoint("BOTTOMRIGHT", 3, -3)
btn.border:SetColorTexture(1, 0.82, 0, 0.9)
btn.border:SetDrawLayer("BACKGROUND")

-- Modifier hint shown on the red (in-combat) state
btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
btn.label:SetPoint("TOP", btn, "BOTTOM", 0, -4)
btn.label:SetTextColor(1, 0.2, 0.2)
btn.label:Hide()

-- Pulsing border for mismatch
btn.pulse = btn.border:CreateAnimationGroup()
btn.pulse:SetLooping("BOUNCE")
local fade = btn.pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0.15)
fade:SetDuration(0.45)
fade:SetSmoothing("IN_OUT")

local function SetBorder(r, g, b)
	btn.border:SetColorTexture(r, g, b, 1)
	btn.border:Show()
	if not btn.pulse:IsPlaying() then btn.pulse:Play() end
end

local function ClearBorder()
	btn.pulse:Stop()
	btn.border:Hide()
	btn.label:Hide()
end

-- Mouse input follows visibility out of combat; in combat it keeps whatever state it entered with,
-- so a button visible at the pull stays shift-clickable.
local function SetShown(visible, alpha)
	btn:SetAlpha(visible and alpha or 0)
	if not visible and GameTooltip:IsOwned(btn) then GameTooltip:Hide() end
	if not InCombatLockdown() then btn:EnableMouse(visible) end
end

-- Out of combat: load every learned tracking spell onto its modifier (shift-spell, ctrl-spell, ...).
-- Unset modifiers fall back to the plain "spell" attribute.
local function ApplyModifierSpells()
	if InCombatLockdown() then return end
	for typeId, mod in pairs(MOD_BY_TYPE) do
		local spell = TRACK_BY_TYPE_ID[typeId]
		btn:SetAttribute(mod.prefix .. "-spell", Knows(spell) and SpellName(spell) or nil)
	end
end

btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

btn:SetScript("OnDragStart", function(self)
	if not AutoTrackDB.locked and not InCombatLockdown() then self:StartMoving() end
end)
btn:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local point, _, relPoint, x, y = self:GetPoint()
	AutoTrackDB.pos = { point, relPoint, x, y }
end)
btn:SetScript("OnEnter", function(self)
	if self:GetAlpha() == 0 then return end
	local s = self:GetAttribute("spell")
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine("AutoTrack")
	GameTooltip:AddLine(s and ("Will cast: " .. s) or "No matching tracking for target", 1, 1, 1)
	for typeId = 1, 7 do
		local mod, spell = MOD_BY_TYPE[typeId], TRACK_BY_TYPE_ID[typeId]
		if Knows(spell) then
			GameTooltip:AddDoubleLine(mod.label, SpellName(spell), 1, 0.82, 0, 1, 1, 1)
		end
	end
	if not AutoTrackDB.locked then
		GameTooltip:AddLine("Unlocked: drag to move. Always visible", 0.6, 0.6, 0.6)
		GameTooltip:AddLine("while unlocked. /autotrack lock to enable auto-hide.", 0.6, 0.6, 0.6)
	end
	GameTooltip:Show()
end)
btn:SetScript("OnLeave", function(self)
	if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end)

-- States:
--   match    : current tracking already right -> dim, no border
--   mismatch : button ready to fix it        -> bright + gold border
--   combat   : mismatch but button is locked  -> red border, icon of spell to press manually
local function Refresh()
	local wanted, typeId = WantedSpell()
	local active = ActiveTrackingSpell()

	if not InCombatLockdown() then
		btn:SetAttribute("spell", wanted and SpellName(wanted) or nil)
		ApplyModifierSpells()
	end

	local unlocked = not AutoTrackDB.locked -- always visible while positioning

	if not wanted then
		btn.icon:SetTexture(active and SpellIcon(active) or "Interface\\Icons\\INV_Misc_QuestionMark")
		btn.icon:SetDesaturated(true)
		ClearBorder()
		SetShown(unlocked or not AutoTrackDB.hideIdle, 0.4)
		return
	end

	btn.icon:SetTexture(SpellIcon(wanted))
	if wanted == active then
		btn.icon:SetDesaturated(true)
		ClearBorder()
		SetShown(unlocked or not AutoTrackDB.autoHide, 0.5)
	else
		btn.icon:SetDesaturated(false)
		SetShown(true, 1)
		if btn:GetAttribute("spell") == SpellName(wanted) then
			SetBorder(1, 0.82, 0)   -- flashing gold: press your key
			btn.label:Hide()
		else
			SetBorder(1, 0.1, 0.1)  -- flashing red: in combat, hold the modifier and press
			btn.label:SetText(MOD_BY_TYPE[typeId].label)
			btn.label:Show()
		end
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("MINIMAP_UPDATE_TRACKING")
ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterEvent("UNIT_FLAGS")

ev:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		AutoTrackDB = AutoTrackDB or {}
		if AutoTrackDB.locked == nil then AutoTrackDB.locked = false end
		if AutoTrackDB.autoHide == nil then AutoTrackDB.autoHide = true end
		if AutoTrackDB.hideIdle == nil then AutoTrackDB.hideIdle = true end
		local p = AutoTrackDB.pos
		if p then
			btn:ClearAllPoints()
			btn:SetPoint(p[1], UIParent, p[2], p[3], p[4])
		end
		return
	elseif event == "PLAYER_LOGIN" then
		BuildTypeMap()
		if select(2, UnitClass("player")) ~= "HUNTER" then
			btn:Hide()
			ev:UnregisterAllEvents()
			return
		end
	elseif event == "UNIT_FLAGS" and arg1 ~= "target" then
		return
	end
	Refresh()
end)

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
SLASH_AUTOTRACK1 = "/autotrack"
SlashCmdList.AUTOTRACK = function(msg)
	msg = (msg or ""):lower():trim()
	if msg == "lock" then
		AutoTrackDB.locked = true
		print("|cffffd100AutoTrack|r: locked.")
		Refresh()
	elseif msg == "unlock" then
		AutoTrackDB.locked = false
		print("|cffffd100AutoTrack|r: unlocked, drag to move. Button stays visible until you /autotrack lock.")
		Refresh()
	elseif msg == "autohide" then
		AutoTrackDB.autoHide = not AutoTrackDB.autoHide
		print("|cffffd100AutoTrack|r: hide when tracking matches " .. (AutoTrackDB.autoHide and "on" or "off") .. ".")
		Refresh()
	elseif msg == "hide" then
		AutoTrackDB.hideIdle = not AutoTrackDB.hideIdle
		print("|cffffd100AutoTrack|r: hide when idle " .. (AutoTrackDB.hideIdle and "on" or "off") .. ".")
		Refresh()
	elseif msg == "reset" then
		if InCombatLockdown() then return print("|cffffd100AutoTrack|r: not in combat.") end
		AutoTrackDB.pos = nil
		btn:ClearAllPoints()
		btn:SetPoint("CENTER", 0, -150)
	else
		print("|cffffd100AutoTrack|r: /autotrack lock | unlock | autohide | hide | reset")
		print("Bind a key: Esc > Options > Keybindings > AddOns > Cast matching tracking")
	end
end
