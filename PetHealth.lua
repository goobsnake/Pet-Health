--Elder Scrolls: Online addon (written in LUA) which adds persistent in-game health bars to all permanent pets. 
--Original/base work of this addon was developed by SCOOTWORKS and I was granted permission by him to take over full development and distribution of this addon.
PetHealth = PetHealth or {}
--The supported classes for this addon (ClassId from function GetUnitClassId("player"))
PetHealth.supportedClasses = {
	[2] = true,	-- Sorcerer
	[4] = true, -- Warden
}
local addon = {
	name 			= "PetHealth",
	displayName 	= "PetHealth",
    version         = "1.03",
	savedVarName	= "PetHealth_Save",
	savedVarVersion = 2,
	lamDisplayName 	= "PetHealth",
	lamAuthor		= "Scootworks, Goobsnake",
	lamUrl			= "https://www.esoui.com/downloads/info1884-PetHealthMurkmire.html",
}
PetHealth.addonData = addon

local default = {
    saveMode = 1, -- Each character
    point = TOPLEFT,
    relPoint = CENTER,
    x = 0,
    y = 0,
	onlyInCombat = false,
	showValues = true,
	showLabels = true,
	lowHealthAlertSlider = 0,
	lowShieldAlertSlider = 0,
	petUnsummonedAlerts = false,
	hideFrameUntilHealthSlider = 0,
	showBackground = true,
	debug = false,
}

local UNIT_PLAYER_PET = "playerpet"
local UNIT_PLAYER_TAG = "player"

local base, background, savedVars--, savedVarCopy
local currentPets = {}
local window = {}
local inCombatAddon = false

local AddOnManager = GetAddOnManager()
local hideFrameUntilHealthPercentage = 0
local LSC
local lowHealthAlertPercentage = 0
local lowShieldAlertPercentage = 0
local onScreenHealthAlertPetOne = 0
local onScreenHealthAlertPetTwo = 0
local onScreenShieldAlertPetOne = 0
local onScreenShieldAlertPetTwo = 0
local unsummonedAlerts = false

local WINDOW_MANAGER = GetWindowManager()
local WINDOW_WIDTH = 250
local WINDOW_HEIGHT_ONE = 76
local WINDOW_HEIGHT_TWO = 116
local PET_BAR_FRAGMENT = nil

----------
-- UTIL --
---------- 

local function OnScreenMessage(message)
	local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)
	messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_COUNTDOWN) 
	messageParams:SetText(message)
	CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
end

local function ChatOutput(message)
	CHAT_SYSTEM:AddMessage(message)
end

local function CheckAddon(addon)
	for i = 1, AddOnManager:GetNumAddOns() do
        local name, title, author, description, enabled, state, isOutOfDate = AddOnManager:GetAddOnInfo(i)          
        if title == addon and enabled == true then
			return true
        end
    end
end

local function GetPetNameLower(abilityId)
	--[[
	Um die Namen einfacher zu vergleichen, nur Kleinbuchstaben nutzen.
	Zudem formatiert zo_strformat() den Namen ins richtige Format.
	]]
	return zo_strformat("<<z:1>>", GetAbilityName(abilityId))
end

local validPets = {
	--[[
	Da einige abilityNames nicht mit abilityId übereinstimmt,
	müssen wir hier ein paar Sachen hardcoden.
	]]
	-- Familiar
	[GetPetNameLower(18602)] = true,
	-- Clannfear
	["clannfear"] = true, -- en
	["clannbann"] = true, -- de
	["faucheclan"] = true, -- fr
	-- Volatile Familiar
	[GetPetNameLower(30678)] = true, -- en/de
	-- Winged Twilight
	[GetPetNameLower(30589)] = true,
	["familier explosif"] = true, -- fr
	-- Twilight Tormentor
	[GetPetNameLower(30594)] = true, -- en
	["zwielichtpeinigerin"] = true, -- de
	["tourmenteur crépusculaire"] = true, -- fr
	-- Twilight Matriarch
	[GetPetNameLower(30629)] = true,
	-- Feral Guardian
	[GetPetNameLower(94376)] = true,
	-- Eternal Guardian
	[GetPetNameLower(94394)] = true,
	-- Wild Guardian
	[GetPetNameLower(94408)] = true,
}

local function IsUnitValidPet(unitTag)
	--[[
	Hier durchsuchen wir die Tabellen oben, ob wir den unitTag wirklich in unsere Tabelle aufnehmen.
	]]
	local unitName = zo_strformat("<<z:1>>", GetUnitName(unitTag))
	return DoesUnitExist(unitTag) and validPets[unitName]
end

local function GetKeyWithData(unitTag)
    --[[
    Wir suchen nach dem table key.
    ]]
    for k, v in pairs(currentPets) do
        if v.unitTag == unitTag then return k end
    end
    return nil
end

local function GetAlphaFromControl(savedVariable)
	return (not savedVariable and 0) or 1
end

local function GetCombatState()
	return not inCombatAddon and savedVars.onlyInCombat
end

local function SetPetWindowHidden(hidden, combatState)
	local setToHidden = hidden
	if combatState then
		setToHidden = true
	end	
	PET_BAR_FRAGMENT:SetHiddenForReason("NoPetOrOnlyInCombat", setToHidden)
	-- debug
	--ChatOutput(string.format("SetPetWindowHidden() setToHidden: %s, onlyInCombat: %s", tostring(setToHidden), tostring(onlyInCombat)))
end

local function PetUnSummonedAlerts(unitTag)
	if unsummonedAlerts then
		local i = GetKeyWithData(unitTag)
		if i == nil then
			return
		end
		local petName = currentPets[i].unitName
		local swimming = IsUnitSwimming("player")
		local inCombat = IsUnitInCombat("player")
		if swimming then
			OnScreenMessage(string.format(GetString(SI_PET_HEALTH_UNSUMMONED_SWIMMING_MSG)))
		elseif inCombat then
			OnScreenMessage(zo_strformat("<<1>> <<2>>", petName, GetString(SI_PET_HEALTH_UNSUMMONED_MSG)))
		end
	end
end

local function RefreshPetWindow()
	local countPets = #currentPets
	local combatState = GetCombatState()
	if PET_BAR_FRAGMENT:IsHidden() and countPets == 0 and combatState then
		return 
	end
	local height = 0
	local setToHidden = true
	if countPets > 0 then
		if countPets == 1 then
			height = WINDOW_HEIGHT_ONE
			window[1]:SetHidden(false)
			window[2]:SetHidden(true)
			setToHidden = false
		else
			height = WINDOW_HEIGHT_TWO
			window[1]:SetHidden(false)
			window[2]:SetHidden(false)
			setToHidden = false			
		end
	end	
	base:SetHeight(height)
	background:SetHeight(height)
	-- set hidden state
	SetPetWindowHidden(setToHidden, combatState)
	-- debug
	--ChatOutput(string.format("RefreshPetWindow() countPets: %d", countPets))
end


------------
-- SHIELD --
------------
local function OnShieldUpdate(handler, unitTag, value, maxValue, initial)
	--[[
	Zeigt das Schadenschild des Begleiters an.
	]]
	local i = GetKeyWithData(unitTag)
	if i == nil then
		--ChatOutput(string.format("OnShieldUpdate() unitTag: %s - pet not active", unitTag))
		return
	elseif i == 1 then
		local petOne = currentPets[1].unitName
		if lowShieldAlertPercentage > 0 and value < maxValue*.01*lowShieldAlertPercentage then
			if onScreenShieldAlertPetOne == 0 then
				OnScreenMessage(zo_strformat("|c000099<<1>>\'s <<2>>|r", petOne, GetString(SI_PET_HEALTH_LOW_SHIELD_WARNING_MSG)))
				onScreenShieldAlertPetOne = 1
			end
		else
			onScreenShieldAlertPetOne = 0
		end
	else 
		local name = currentPets[i].unitName
		local petOne = currentPets[1].unitName
		local petTwo = currentPets[2].unitName
		if lowShieldAlertPercentage > 0 and value < maxValue*.01*lowShieldAlertPercentage then
			if name == petOne and onScreenShieldAlertPetOne == 0 then
				OnScreenMessage(zo_strformat("|c000099<<1>>\'s <<2>>|r", petOne, GetString(SI_PET_HEALTH_LOW_SHIELD_WARNING_MSG)))
				onScreenShieldAlertPetOne = 1
			elseif name == petTwo and onScreenShieldAlertPetTwo == 0 then
				OnScreenMessage(zo_strformat("|c000099<<1>>\'s <<2>>|r", petTwo, GetString(SI_PET_HEALTH_LOW_SHIELD_WARNING_MSG)))
				onScreenShieldAlertPetTwo = 1
			end
		else
			if name == petOne then
				onScreenShieldAlertPetOne = 0
			elseif name == petTwo then
				onScreenShieldAlertPetTwo = 0
			end
		end
	end
	local ctrl = window[i].shield
	if handler ~= nil then
		if not ctrl:IsHidden() or value == 0 then
			ctrl:SetHidden(true)
		end
	else
		if ctrl:IsHidden() then
			ctrl:SetHidden(false)
		end
	end
	if maxValue > 0 then
		ZO_StatusBar_SmoothTransition(window[i].shield, value, maxValue, (initial == "true" and true or false))
	end
end

local function GetShield(unitTag)
	local value, maxValue = GetUnitAttributeVisualizerEffectInfo(unitTag, ATTRIBUTE_VISUAL_POWER_SHIELDING, STAT_MITIGATION, ATTRIBUTE_HEALTH, POWERTYPE_HEALTH)
	if value == nil then
		value = 0
		maxValue = 0
	end
	OnShieldUpdate(_, unitTag, value, maxValue, "true")
end


------------
-- HEALTH --
------------
local function OnHealthUpdate(_, unitTag, _, _, powerValue, powerMax, initial)
	--[[
	Zeigt das Leben des Begleiters an.
	]]
	local i = GetKeyWithData(unitTag)
	if i == nil then
		--ChatOutput(string.format("OnHealthUpdate() unitTag: %s - pet not active", unitTag))
		return
	elseif i == 1 then
		local petOne = currentPets[1].unitName
		if lowHealthAlertPercentage > 0 and powerValue < (powerMax*.01*lowHealthAlertPercentage) then
			if onScreenHealthAlertPetOne == 0 then
				OnScreenMessage(zo_strformat("|cff0000<<1>> <<2>>|r", petOne, GetString(SI_PET_HEALTH_LOW_HEALTH_WARNING_MSG)))
				onScreenHealthAlertPetOne = 1
			end
		else
			onScreenHealthAlertPetOne = 0
		end
	else 
		local name = currentPets[i].unitName
		local petOne = currentPets[1].unitName
		local petTwo = currentPets[2].unitName
		if lowHealthAlertPercentage > 0 and powerValue < (powerMax*.01*lowHealthAlertPercentage) then
			if name == petOne and onScreenHealthAlertPetOne == 0 then
				OnScreenMessage(zo_strformat("|cff0000<<1>> <<2>>|r", petOne, GetString(SI_PET_HEALTH_LOW_HEALTH_WARNING_MSG)))
				onScreenHealthAlertPetOne = 1
			elseif name == petTwo and onScreenHealthAlertPetTwo == 0 then
				OnScreenMessage(zo_strformat("|cff0000<<1>> <<2>>|r", petTwo, GetString(SI_PET_HEALTH_LOW_HEALTH_WARNING_MSG)))
				onScreenHealthAlertPetTwo = 1
			end
		else
			if name == petOne then
				onScreenHealthAlertPetOne = 0
			elseif name == petTwo then
				onScreenHealthAlertPetTwo = 0
			end
		end
	end
	-- health values
	window[i].values:SetText(ZO_FormatResourceBarCurrentAndMax(powerValue, powerMax))
	-- health bar
	ZO_StatusBar_SmoothTransition(window[i].healthbar, powerValue, powerMax, (initial == "true" and true or false))
end

local function GetHealth(unitTag)
	local powerValue, powerMax = GetUnitPower(unitTag, POWERTYPE_HEALTH)
	OnHealthUpdate(_, unitTag, _, _, powerValue, powerMax, "true")
end


-----------
-- STATS --
-----------
local function GetControlText(control)
	local controlText = control:GetText()
	if controlText ~= nil then return controlText end
	return ""
end

local function UpdatePetStats(unitTag)
	local i = GetKeyWithData(unitTag)
	if i == nil then
		--ChatOutput(string.format("UpdatePetStats() unitTag: %s - pet not active", unitTag))
		return
	end
	local name = currentPets[i].unitName
	local control = window[i].label
	if GetControlText(control) ~= name then
		window[i].label:SetText(name)
	end
	GetHealth(unitTag)
	GetShield(unitTag)
	-- debug
	--ChatOutput(string.format("UpdatePetStats() unitTag: %s, name: %s", unitTag, name))
end



local function GetActivePets()
	--[[
	Hier werden alle Begleiter des Spielers ausgelesen und in die Begleitertabelle geschrieben.
	]]
	currentPets = {}
	for i=1,7 do
		local unitTag = UNIT_PLAYER_PET..i		
		if IsUnitValidPet(unitTag) then
			table.insert(currentPets, { unitTag = unitTag, unitName = GetUnitName(unitTag) })
			zo_callLater(function() UpdatePetStats(unitTag) end, 50)
		end
	end
	-- update
	RefreshPetWindow()
end

-----------
-- COMBAT --
-----------
local function OnPlayerCombatState(_, inCombat)
	--[[
	Setzt den Kampfstatus: in Kampf oder ausserhalb Kampf.
	]]
	inCombatAddon = inCombat
	-- debug
	--ChatOutput(string.format("OnPlayerCombatState() inCombat: %s, inCombatAddon: %s", tostring(inCombat), tostring(inCombatAddon)))
	-- refresh
	RefreshPetWindow()
end


--------------
-- CONTROLS --
--------------
local function CreateControls()
	-----------------
	-- ADD CONTROL --
	-----------------	
	local function AddControl(parent, cType, level)
		local c = WINDOW_MANAGER:CreateControl(nil, parent, cType)
		c:SetDrawLayer(DL_OVERLAY)
		c:SetDrawLevel(level)
		return c, c
	end
	
	---------------
	-- TOP LAYER --
	---------------
	base = WINDOW_MANAGER:CreateTopLevelWindow(addon.name.."_TopLevel")
	base:SetDimensions(WINDOW_WIDTH, WINDOW_HEIGHT_TWO)
	base:SetAnchor(savedVars.point, GuiRoot, savedVars.relPoint, savedVars.x, savedVars.y)
	base:SetMouseEnabled(true)
	base:SetMovable(true)
	base:SetDrawLayer(DL_OVERLAY)
	base:SetDrawLevel(0)
	base:SetHandler("OnMouseUp", function()
		local a, b
		a, savedVars.point, b, savedVars.relPoint, savedVars.x, savedVars.y = base:GetAnchor(0)
	end)
	base:SetHidden(true)

	----------------
	-- BACKGROUND --
	----------------
	local INSET_BACKGROUND = 32
	local baseWidth = base:GetWidth()
	local baseHeight = base:GetHeight()
	local ctrl

	background, ctrl = AddControl(base, CT_BACKDROP, 1)
	ctrl:SetEdgeTexture("esoui/art/chatwindow/chat_bg_edge.dds", 256, 128, INSET_BACKGROUND)
	ctrl:SetCenterTexture("esoui/art/chatwindow/chat_bg_center.dds")
	ctrl:SetInsets(INSET_BACKGROUND, INSET_BACKGROUND, -INSET_BACKGROUND, -INSET_BACKGROUND)
	ctrl:SetCenterColor(1,1,1,0.8)
	ctrl:SetEdgeColor(1,1,1,0.8)	
	ctrl:SetDimensions(baseWidth, baseHeight)
	ctrl:SetAnchor(TOPLEFT)
	ctrl:SetAlpha(GetAlphaFromControl(savedVars.showBackground))

	--------------
	-- PET BARS --
	--------------
	for i=1,2 do
		-- frame
		window[i], ctrl = AddControl(base, CT_BACKDROP, 5)
		ctrl:SetDimensions(baseWidth*0.8, 36)
		ctrl:SetCenterColor(1,0,1,0)
		ctrl:SetEdgeColor(1,0,1,0)
		ctrl:SetAnchor(CENTER, base)
	
		-- label
		local windowHeight = window[i]:GetHeight()
		window[i].label, ctrl = AddControl(window[i], CT_LABEL, 10)
		ctrl:SetFont("$(BOLD_FONT)|$(KB_16)|soft-shadow-thin")
		ctrl:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
		ctrl:SetDimensions(baseWidth, windowHeight*0.4)
		ctrl:SetAnchor(TOPLEFT, window[i])
		ctrl:SetAlpha(GetAlphaFromControl(savedVars.showLabels))
		
		-- border and background
		window[i].border, ctrl = AddControl(window[i], CT_BACKDROP, 20)
		ctrl:SetDimensions(window[i]:GetWidth(), windowHeight*0.45)
		ctrl:SetCenterColor(0,0,0,.6)
		ctrl:SetEdgeColor(1,1,1,0.4)
		ctrl:SetEdgeTexture("", 1, 1, 1)
		ctrl:SetAnchor(BOTTOM, window[i])
		
		-- healthbar
		local borderWidth = window[i].border:GetWidth()
		local borderHeight = window[i].border:GetHeight()
		window[i].healthbar, ctrl = AddControl(window[i].border, CT_STATUSBAR, 30)
		ctrl:SetColor(1,1,1,0.5)
		ctrl:SetGradientColors(.45, .13, .13, 1, .85, .19, .19, 1)
		ctrl:SetDimensions(borderWidth-2, borderHeight-2)
		ctrl:SetAnchor(CENTER, window[i].border)
		
		-- shield
		window[i].shield, ctrl = AddControl(window[i].healthbar, CT_STATUSBAR, 40)
		ctrl:SetColor(1,1,1,0.5)
		ctrl:SetGradientColors(.5, .5, 1, .3, .25, .25, .5, .5)
		ctrl:SetDimensions(borderWidth-2, borderHeight-2)
		ctrl:SetAnchor(CENTER, window[i].healthbar)
		ctrl:SetValue(0)
		ctrl:SetMinMax(0,1)

		-- values
		window[i].values, ctrl = AddControl(window[i].healthbar, CT_LABEL, 50)
		ctrl:SetFont("$(BOLD_FONT)|$(KB_14)|soft-shadow-thin")
		ctrl:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED))
		ctrl:SetAnchor(CENTER, window[i].healthbar)
		ctrl:SetAlpha(GetAlphaFromControl(savedVars.showValues))
		-- ctrl:SetHidden(not savedVars.showValues or false)
		
		-- clear anchors to reset it
		window[i]:ClearAnchors()
	end

	window[1]:SetAnchor(TOP, base, TOP, 0, 18)
	window[2]:SetAnchor(TOP, window[1], BOTTOM, 0, 2)

	-----------
	-- SCENE --
	-----------
	PET_BAR_FRAGMENT = ZO_HUDFadeSceneFragment:New(base)
	HUD_SCENE:AddFragment(PET_BAR_FRAGMENT)
	HUD_UI_SCENE:AddFragment(PET_BAR_FRAGMENT)
	PET_BAR_FRAGMENT:SetHiddenForReason("NoPetOrOnlyInCombat", true)
end


----------
-- INIT --
----------
local function LoadEvents()
	-- events
	EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_POWER_UPDATE, OnHealthUpdate)
	EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_UNIT_CREATED, function(_, unitTag)
		if IsUnitValidPet(unitTag) then
			GetActivePets()
		end
	end)
	EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_UNIT_DESTROYED, function(_, unitTag)
		PetUnSummonedAlerts(unitTag)
		local key = GetKeyWithData(unitTag)
		if key ~= nil then
			table.remove(currentPets, key)
			-- debug
			--ChatOutput(string.format("%s destroyed", unitTag))
			-- refresh
			local countPets = #currentPets
			if countPets > 0 then
				for i = 1, countPets do
					local name = currentPets[i].unitName
					local control = window[i].label
					if GetControlText(control) ~= name then
						window[i].label:SetText(name)
					end
					GetHealth(unitTag)
					GetShield(unitTag)
				end
			end
			RefreshPetWindow()
		end	
	end)
	EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_PLAYER_DEAD, GetActivePets)
	EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_UNIT_DEATH_STATE_CHANGE, GetActivePets)
	EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ACTION_SLOT_ABILITY_SLOTTED, GetActivePets)
	-- event filters
	EVENT_MANAGER:AddFilterForEvent(addon.name, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG_PREFIX, UNIT_PLAYER_PET)
	EVENT_MANAGER:AddFilterForEvent(addon.name, EVENT_UNIT_CREATED, REGISTER_FILTER_UNIT_TAG_PREFIX, UNIT_PLAYER_PET)
	EVENT_MANAGER:AddFilterForEvent(addon.name, EVENT_UNIT_DESTROYED, REGISTER_FILTER_UNIT_TAG_PREFIX, UNIT_PLAYER_PET)
	EVENT_MANAGER:AddFilterForEvent(addon.name, EVENT_PLAYER_DEAD, REGISTER_FILTER_UNIT_TAG, UNIT_PLAYER_TAG)
	EVENT_MANAGER:AddFilterForEvent(addon.name, EVENT_UNIT_DEATH_STATE_CHANGE, REGISTER_FILTER_UNIT_TAG, UNIT_PLAYER_TAG)
	-- shield
	EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, function(_, unitTag, unitAttributeVisual, _, _, _, value, maxValue)
		if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
			OnShieldUpdate(nil, unitTag, value, maxValue, "true")
		end
	end)
	EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, function(_, unitTag, unitAttributeVisual, _, _, _, value, maxValue)
		if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
			OnShieldUpdate("removed", unitTag, value, maxValue, "false")
		end
	end)
	EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, function(_, unitTag, unitAttributeVisual, _, _, _, _, newValue, _, newMaxValue)
		if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
			OnShieldUpdate(nil, unitTag, newValue, newMaxValue, "false")
		end
	end)
	-- shield filters
	EVENT_MANAGER:AddFilterForEvent(addon.name, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG_PREFIX, UNIT_PLAYER_PET)
	EVENT_MANAGER:AddFilterForEvent(addon.name, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG_PREFIX, UNIT_PLAYER_PET)
	EVENT_MANAGER:AddFilterForEvent(addon.name, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG_PREFIX, UNIT_PLAYER_PET)
	-- for changes the style of the values
	EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_INTERFACE_SETTING_CHANGED, GetActivePets)
	EVENT_MANAGER:AddFilterForEvent(addon.name, EVENT_INTERFACE_SETTING_CHANGED, REGISTER_FILTER_SETTING_SYSTEM_TYPE, SETTING_TYPE_UI)
	-- handles the in combat stuff
	EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_PLAYER_COMBAT_STATE, OnPlayerCombatState)
	OnPlayerCombatState(_, IsUnitInCombat(UNIT_PLAYER_TAG))
	-- zone changes
	EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, function() zo_callLater(function() GetActivePets() end, 75) end)
end

function PetHealth.changeCombatState()
    OnPlayerCombatState(_, IsUnitInCombat(UNIT_PLAYER_TAG))
end


function PetHealth.changeBackground(toValue)
    background:SetAlpha(GetAlphaFromControl(toValue))
end

function PetHealth.changeValues(toValue)
    for i=1,2 do
        -- local alpha = GetAlphaFromControl(savedVars.showValues)
        -- d(alpha)
        window[i].values:SetAlpha(GetAlphaFromControl(toValue))
    end
end

function PetHealth.changeLabels(toValue)
    for i=1,2 do
        window[i].label:SetAlpha(GetAlphaFromControl(toValue))
    end
end

function PetHealth.lowHealthAlertPercentage(toValue)
	lowHealthAlertPercentage = toValue
end

function PetHealth.lowShieldAlertPercentage(toValue)
	lowShieldAlertPercentage = toValue
end

function PetHealth.unsummonedAlerts(toValue)
	unsummonedAlerts = toValue
end

function PetHealth.hideFrameUntilHealthPercentage(toValue)
	hideFrameUntilHealthPercentage = toValue
end



local function SlashCommands()

	-- LSC:Register("/pethealthdebug", function()
	-- 	savedVars.debug = not savedVars.debug
	-- 	savedVars.debug = savedVars.debug
	-- 	if savedVars.debug then
	-- 		ChatOutput(string.format("%s %s!", GetString(SI_SETTINGSYSTEMPANEL6), GetString(SI_ADDONLOADSTATE2)))
	-- 	else
	-- 		ChatOutput(string.format("%s %s!", GetString(SI_SETTINGSYSTEMPANEL6), GetString(SI_ADDONLOADSTATE3)))
	-- 	end
	-- end, GetString(SI_PET_HEALTH_LSC_DEBUG))
	
	LSC:Register("/pethealthcombat", function()
		savedVars.onlyInCombat = not savedVars.onlyInCombat
		if savedVars.onlyInCombat then
			ChatOutput(GetString(SI_PET_HEALTH_COMBAT_ACTIVATED))
		else
			ChatOutput(GetString(SI_PET_HEALTH_COMBAT_DEACTIVATED))
		end
        PetHealth.changeCombatState()
	end, GetString(SI_PET_HEALTH_LSC_COMBAT))
	
	LSC:Register("/pethealthvalues", function()
		savedVars.showValues = not savedVars.showValues
		if savedVars.showValues then
			ChatOutput(GetString(SI_PET_HEALTH_VALUES_ACTIVATED))
		else
			ChatOutput(GetString(SI_PET_HEALTH_VALUES_DEACTIVATED))
		end
        PetHealth.changeValues(savedVars.showValues)
	end, GetString(SI_PET_HEALTH_LSC_VALUES))
	
	LSC:Register("/pethealthlabels", function()
		savedVars.showLabels = not savedVars.showLabels
		if savedVars.showLabels then
			ChatOutput(GetString(SI_PET_HEALTH_LABELS_ACTIVATED))
		else
			ChatOutput(GetString(SI_PET_HEALTH_LABELS_DEACTIVATED))
        end
        PetHealth.changeLabels(savedVars.showLabels)
	end, GetString(SI_PET_HEALTH_LSC_LABELS))
	
	LSC:Register("/pethealthbackground", function()
		savedVars.showBackground = not savedVars.showBackground
		if savedVars.showBackground then
			ChatOutput(GetString(SI_PET_HEALTH_BACKGROUND_ACTIVATED))
		else
			ChatOutput(GetString(SI_PET_HEALTH_BACKGROUND_DEACTIVATED))
        end
        PetHealth.changeBackground(savedVars.showBackground)
	end, GetString(SI_PET_HEALTH_LSC_BACKGROUND))

	LSC:Register("/pethealthunsummonedalerts", function()
		savedVars.petUnsummonedAlerts = not savedVars.petUnsummonedAlerts
		if savedVars.petUnsummonedAlerts then
			ChatOutput(GetString(SI_PET_HEALTH_UNSUMMONEDALERTS_ACTIVATED))
		else
			ChatOutput(GetString(SI_PET_HEALTH_UNSUMMONEDALERTS_DEACTIVATED))
        end
        PetHealth.unsummonedAlerts(savedVars.petUnsummonedAlerts)
	end, GetString(SI_PET_HEALTH_LSC_UNSUMMONEDALERTS))

	LSC:Register("/pethealthwarnhealth", function(healthValuePercent)
		if healthValuePercent == nil or healthValuePercent == "" then
			ChatOutput(GetString(SI_PET_HEALTH_LAM_LOW_HEALTH_WARN) .. ": " .. tostring(savedVars.lowHealthAlertSlider))
		else
			local healthValuePercentNumber = tonumber(healthValuePercent)
			if type(healthValuePercentNumber) == "number" then
				if healthValuePercentNumber < 0 then healthValuePercentNumber = 0 end
				if healthValuePercentNumber >= 100 then healthValuePercentNumber = 99 end
				savedVars.lowHealthAlertSlider = healthValuePercentNumber
				PetHealth.lowHealthAlertPercentage(healthValuePercentNumber)
				ChatOutput(GetString(SI_PET_HEALTH_LAM_LOW_HEALTH_WARN) .. ": " .. tostring(healthValuePercentNumber))
			end
		end
	end, GetString(SI_PET_HEALTH_LSC_WARN_HEALTH))

	LSC:Register("/pethealthwarnshield", function(shieldValuePercent)
		if shieldValuePercent == nil or shieldValuePercent == "" then
			ChatOutput(GetString(SI_PET_HEALTH_LAM_LOW_SHIELD_WARN) .. ": " .. tostring(savedVars.lowShieldAlertSlider))
		else
			local shieldValuePercentNumber = tonumber(shieldValuePercent)
			if type(shieldValuePercentNumber) == "number" then
				if shieldValuePercentNumber < 0 then shieldValuePercentNumber = 0 end
				if shieldValuePercentNumber >= 100 then shieldValuePercentNumber = 99 end
				savedVars.lowShieldAlertSlider = shieldValuePercentNumber
				PetHealth.lowShieldAlertPercentage(shieldValuePercentNumber)
				ChatOutput(GetString(SI_PET_HEALTH_LAM_LOW_SHIELD_WARN) .. ": " .. tostring(shieldValuePercentNumber))
			end
		end
	end, GetString(SI_PET_HEALTH_LSC_WARN_SHIELD))
end

local function OnAddOnLoaded(_, addonName)
	if addonName ~= addon.name then return end
	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)
		
	-- savedVars
	savedVars = ZO_SavedVars:NewCharacterIdSettings(addon.savedVarName, addon.savedVarVersion, nil, default, GetWorldName())
	--savedVarCopy = savedVars -- during playing, it takes only the local savedVars settings instead picking the savedVars
    PetHealth.savedVars = savedVars
    PetHealth.savedVarsDefault = default
    lowHealthAlertPercentage = savedVars.lowHealthAlertSlider
	lowShieldAlertPercentage = savedVars.lowShieldAlertSlider
	unsummonedAlerts = savedVars.petUnsummonedAlerts
	hideFrameUntilHealthPercentage = savedVars.hideFrameUntilHealthSlider

	-- Addon is only enabled for the classIds which are given with the value true in the table PetHealth.supportedClasses
	local getUnitClassId = GetUnitClassId(UNIT_PLAYER_TAG)
	local supportedClasses = PetHealth.supportedClasses
	local supportedClass = supportedClasses[getUnitClassId] or false
	if not supportedClass then
		-- debug
		ChatOutput("[PetHealth] " .. GetString(SI_PET_HEALTH_CLASS))
		return
	end
	
	--Makes libs completely optional
	--If users want to change default values or expanded funcitonality, they will need to install applicable libs
	local isStubActive = CheckAddon('LibStub')
	if isStubActive then
		local isLAMActive = CheckAddon('LibAddonMenu-2.0')
		local isLSCActive = CheckAddon('LibSlashCommander')
		if isLAMActive then
		--Build the LAM addon menu if the library LibAddonMenu-2.0 was found loaded properly
			PetHealth.LAM = LibStub("LibAddonMenu-2.0")
			PetHealth.buildLAMAddonMenu()
		end
		if isLSCActive then
		--Build the slash commands if the library LibSlashCommander was found loaded properly
			LSC = LibStub("LibSlashCommander")
			SlashCommands()
		end
	end

	-- local LAM = LibStub("LibAddonMenu-2.0")
	-- if LAM ~= nil then
		
	-- end
	-- create ui
	CreateControls()
	-- do stuff
	--GetActivePets()
	LoadEvents()
	
	-- debug
	--ChatOutput("loaded")
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)