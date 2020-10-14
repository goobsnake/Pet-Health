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
	version         = "1.12",
	savedVarName	= "PetHealth_Save",
	savedVarVersion = 2,
	lamDisplayName 	= "PetHealth",
	lamAuthor		= "Scootworks, Goobsnake",
	lamUrl			= "https://www.esoui.com/downloads/info1884-PetHealth.html",
}
PetHealth.addonData = addon

local default = {
	saveMode = 1, -- Default for each character setting
	point = TOPLEFT,
	relPoint = CENTER,
	x = 0,
	y = 0,
	onlyInCombat = false,
	showValues = true,
	showLabels = true,
	hideInDungeon = false,
	lockWindow = false,
	lowHealthAlertSlider = 0,
	lowShieldAlertSlider = 0,
	petUnsummonedAlerts = false,
	onlyInCombatHealthSlider = 0,
	showBackground = true,
	useZosStyle = false,
	debug = false,
}

local UNIT_PLAYER_PET = "playerpet"
local UNIT_PLAYER_TAG = "player"

local base, background, savedVars--, savedVarCopy
local currentPets = {}
local PetHealthWarner
local window = {}
local inCombatAddon = false

local AddOnManager = GetAddOnManager()
local hideInDungeon = false
local LAM
local LSC
local lockWindow = false
local lowHealthAlertPercentage = 0
local lowShieldAlertPercentage = 0
local onlyInCombatHealthMax = 0
local onlyInCombatHealthCurrent = 0
local onlyInCombatHealthPercentage = 0
local onScreenHealthAlertPetOne = 0
local onScreenHealthAlertPetTwo = 0
local onScreenShieldAlertPetOne = 0
local onScreenShieldAlertPetTwo = 0
local unsummonedAlerts = false

local WINDOW_MANAGER = GetWindowManager()
local WINDOW_WIDTH = 250
local WINDOW_HEIGHT_ONE = 76
local WINDOW_HEIGHT_TWO = 116
local PET_BAR_FRAGMENT

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

local function CheckAddon(addonName)
	for i = 1, AddOnManager:GetNumAddOns() do
		local name, title, author, description, enabled, state, isOutOfDate = AddOnManager:GetAddOnInfo(i)
		if title == addonName and enabled == true and state == 2 then
			return true
		end
	end
end

local function GetPetNameLower(abilityId)
	--[[
	Um die Namen einfacher zu vergleichen, nur Kleinbuchstaben nutzen.
	Zudem formatiert zo_strformat() den Namen ins richtige Format.
	]]
	local abilityName = GetAbilityName(abilityId)
	local petName
	--Removing text from Sorc pet ability names to derive pet names / Not currently needed for Warden pets
	--Unstable Clannfear is abilityId 23319
	--if abilityId == 23319 or abilityId == 23304 then
	if abilityName:match('Summon ') then
		if abilityName:match('Summon Unstable ') then 
			petName = abilityName:gsub("Summon Unstable ","")
		else
			petName = abilityName:gsub("Summon ","")
		end
	else
		petName = abilityName
	end
	return zo_strformat("<<z:1>>", petName)
end

local validPets = {
	--[[
	Da einige abilityNames nicht mit abilityId übereinstimmt,
	müssen wir hier ein paar Sachen hardcoden.
	]]
	-- Familiar
	[GetPetNameLower(23304)] = true,
	["begleiter"] = true, -- de
	["familier"] = true, -- fr
	["призванный слуга"] = true, -- ru
	-- Clannfear
	[GetPetNameLower(23319)] = true,
	["clannbann"] = true, -- de
	["faucheclan"] = true, -- fr
	["кланфир"] = true, -- ru
	-- Volatile Familiar
	[GetPetNameLower(23316)] = true, -- en
	["explosiver begleiter"] = true, -- de
	["familier explosif"] = true, -- fr
	["взрывной призванный слуга"] = true, -- ru
	-- Winged Twilight
	[GetPetNameLower(24613)] = true, -- en
	["zwielichtschwinge"] = true, -- de
	["crépuscule ailé"] = true, -- fr
	["крылатый сумрак"] = true, -- ru
	-- Twilight Tormentor
	[GetPetNameLower(24636)] = true, -- en
	["zwielichtpeinigerin"] = true, -- de
	["tourmenteur crépusculaire"] = true, -- fr
	["сумрак-мучитель"] = true, -- ru
	-- Twilight Matriarch
	[GetPetNameLower(24639)] = true,
	["zwielichtmatriarchin"] = true, -- de
	["matriarche crépusculaire"] = true, -- fr
	["сумрак-матриарх"] = true, -- ru
	-- Warden Pets don't seem to need any de/fr localization entries
	-- Feral Guardian
	[GetPetNameLower(85982)] = true,
	["хищный страж"] = true, -- ru
	-- Eternal Guardian
	[GetPetNameLower(85986)] = true,
	["вечный страж"] = true, -- ru
	-- Wild Guardian
	[GetPetNameLower(85990)] = true,
	["дикий защитник"] = true, -- ru
}

local function IsUnitValidPet(unitTag)
	--[[
	Hier durchsuchen wir die Tabellen oben, ob wir den unitTag wirklich in unsere Tabelle aufnehmen.
	]]
	local unitName = zo_strformat("<<z:1>>", GetUnitName(unitTag))
	--zo_callLater(function() ChatOutput(unitName) end, 10000)
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
	--GetSlotBoundId values 3 thru 8 to obtain the slotbar's abiltiyId's (8 is ultimate)
	-- d(GetSlotBoundId(3))
	-- d(GetPetNameLower(GetSlotBoundId(3)))
	-- d(GetAbilityName(23319))
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
	if not combatState and savedVars.onlyInCombat == true then
		if onlyInCombatHealthPercentage == 0 then
			setToHidden = false
		elseif onlyInCombatHealthCurrent > (onlyInCombatHealthMax*.01*onlyInCombatHealthPercentage) then
			setToHidden = true
		end
	end
	if savedVars.hideInDungeon == true then
		local inDungeon = IsUnitInDungeon("player")
		local zoneDifficulty = GetCurrentZoneDungeonDifficulty()
		--zoneDifficulty 0 is for all overland/non-dungeon content, 1 = normal dungeon/arena/trial, 2 = veteran dungeon/arena/trial
		if inDungeon == true and zoneDifficulty > 0 then
			local currentZone = GetUnitZone("player")
			if currentZone ~= 'Maelstrom Arena' then
				setToHidden = true
			end
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
		if lowShieldAlertPercentage > 1 and value ~= 0 and value < (maxValue*.01*lowShieldAlertPercentage) then
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
		if lowShieldAlertPercentage > 1 and value ~= 0 and value < (maxValue*.01*lowShieldAlertPercentage) then
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
	local ctrl, ctrlr;
	if (not savedVars.useZosStyle) then
		ctrl = window[i].shield
	else
		ctrl = window[i].shieldleft
		ctrlr = window[i].shieldright
	end

	if handler ~= nil then
		if not ctrl:IsHidden() or value == 0 then
			ctrl:SetHidden(true)
			if (savedVars.useZosStyle) then
				ctrlr:SetHidden(true)
			end
		end
	else
		if ctrl:IsHidden() then
			ctrl:SetHidden(false)
			if (savedVars.useZosStyle) then
				ctrlr:SetHidden(false)
			end
		end
	end
	if maxValue > 0 then
		if (savedVars.useZosStyle) then
			value = value / 2;
			maxValue = maxValue / 2;
			ZO_StatusBar_SmoothTransition(window[i].shieldleft, value, maxValue, (initial == "true" and true or false))
			ZO_StatusBar_SmoothTransition(window[i].shieldright, value, maxValue, (initial == "true" and true or false))
		else
			ZO_StatusBar_SmoothTransition(window[i].shield, value, maxValue, (initial == "true" and true or false))
		end
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
	if onlyInCombatHealthPercentage > 1 and savedVars.onlyInCombat == true then
		onlyInCombatHealthMax = powerMax
		onlyInCombatHealthCurrent = powerValue
		RefreshPetWindow()
	end
	local i = GetKeyWithData(unitTag)
	if i == nil then
		--ChatOutput(string.format("OnHealthUpdate() unitTag: %s - pet not active", unitTag))
		return
	elseif i == 1 then
		local petOne = currentPets[1].unitName
		if lowHealthAlertPercentage > 1 and powerValue ~= 0 and powerValue < (powerMax*.01*lowHealthAlertPercentage) then
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
		if lowHealthAlertPercentage > 1 and powerValue ~= 0 and powerValue < (powerMax*.01*lowHealthAlertPercentage) then
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
	if (savedVars.useZosStyle) then
		local halfValue = powerValue / 2
		local halfMax = powerMax / 2
		ZO_StatusBar_SmoothTransition(window[i].barleft, halfValue, halfMax, (initial == "true" and true or false))
		ZO_StatusBar_SmoothTransition(window[i].barright, halfValue, halfMax, (initial == "true" and true or false))
		window[i].warner:OnHealthUpdate(powerValue, powerMax);
	else
		ZO_StatusBar_SmoothTransition(window[i].healthbar, powerValue, powerMax, (initial == "true" and true or false))
	end
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
	if i == nil or i > 2 then
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
			UpdatePetStats(unitTag)
		end
	end
	-- update
	zo_callLater(function() RefreshPetWindow() end, 300)
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

local function CreateWarner()
	if savedVars.useZosStyle then
		local HEALTH_ALPHA_PULSE_THRESHOLD = 0.25

		local RESOURCE_WARNER_FLASH_TIME  = 300
		
		PetHealthWarner = ZO_Object:Subclass()

		function PetHealthWarner:New(...)
			local warner = ZO_Object.New(self)
			warner:Initialize(...)
			return warner
		end

		function PetHealthWarner:Initialize(parent)
			self.warning = GetControl(parent, "Warner")

			self.OnPowerUpdate = function(_, unitTag, powerIndex, powerType, health, maxHealth)
				self:OnHealthUpdate(health, maxHealth)
			end
			local function OnPlayerActivated()
				local current, max = GetUnitPower(self.unitTag, POWERTYPE_HEALTH)
				self:OnHealthUpdate(current, max)
			end

			self.warning:RegisterForEvent(EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

			self.warnAnimation = ZO_AlphaAnimation:New(self.warning)
			self.statusBar = parent
			self.paused = false
		end

		function PetHealthWarner:SetPaused(paused)
			if self.paused ~= paused then
				self.paused = paused
				if paused then
					if self.warnAnimation:IsPlaying() then
						self.warnAnimation:Stop()
					end
				else
					local current, max = GetUnitPower("player", POWERTYPE_HEALTH)
					self.warning:SetAlpha(0)
					self:UpdateAlphaPulse(current / max)
				end
			end
		end

		function PetHealthWarner:UpdateAlphaPulse(healthPerc)
			if healthPerc <= HEALTH_ALPHA_PULSE_THRESHOLD then
				if not self.warnAnimation:IsPlaying() then
					self.warnAnimation:PingPong(0, 1, RESOURCE_WARNER_FLASH_TIME)
				end
			else
				if self.warnAnimation:IsPlaying() then
					self.warnAnimation:Stop()
					self.warning:SetAlpha(0)
				end
			end
		end

		function PetHealthWarner:OnHealthUpdate(health, maxHealth)
			if not self.paused then
				local healthPerc = health / maxHealth
				self:UpdateAlphaPulse(healthPerc)
			end
		end
	end
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
	if savedVars.lockWindow == true then
		base:SetMovable(false)
	else
		base:SetMovable(true)
	end
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
	if (not savedVars.useZosStyle) then
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
	else
		local CHILD_DIRECTIONS = { "Left", "Right", "Center" }

		local function SetColors(self)
			local powerType = self.powerType
			local gradient = ZO_POWER_BAR_GRADIENT_COLORS[powerType]
			for i, control in ipairs(self.barControls) do
				ZO_StatusBar_SetGradientColor(control, gradient)
				control:SetFadeOutLossColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_POWER_FADE_OUT, powerType))
				control:SetFadeOutGainColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_POWER_FADE_IN, powerType))
			end
		end	

		local PAB_TEMPLATES = {
			[POWERTYPE_HEALTH] = {
				background = {
					Left = "ZO_PlayerAttributeBgLeftArrow",
					Right = "ZO_PlayerAttributeBgRightArrow",
					Center = "ZO_PlayerAttributeBgCenter",
				},
				frame = {
					Left = "ZO_PlayerAttributeFrameLeftArrow",
					Right = "ZO_PlayerAttributeFrameRightArrow",
					Center = "ZO_PlayerAttributeFrameCenter",
				},
				warner = {
					texture = "ZO_PlayerAttributeHealthWarnerTexture",
					Left = "ZO_PlayerAttributeWarnerLeftArrow",
					Right = "ZO_PlayerAttributeWarnerRightArrow",
					Center = "ZO_PlayerAttributeWarnerCenter",
				},
				anchors = {
					"ZO_PlayerAttributeHealthBarAnchorLeft",
					"ZO_PlayerAttributeHealthBarAnchorRight",
				},
			},
			statusBar = "ZO_PlayerAttributeStatusBar",
			statusBarGloss = "ZO_PlayerAttributeStatusBarGloss",
			resourceNumbersLabel = "ZO_PlayerAttributeResourceNumbers",
		}

		local function ApplyStyle(bar)
			local powerTypeTemplates = PAB_TEMPLATES[bar.powerType]
			local backgroundTemplates = powerTypeTemplates.background
			local frameTemplates = powerTypeTemplates.frame

			local warnerControl = bar:GetNamedChild("Warner")
			local bgControl = bar:GetNamedChild("BgContainer")

			local warnerTemplates = powerTypeTemplates.warner

			for _, direction in pairs(CHILD_DIRECTIONS) do
				local bgChild = bgControl:GetNamedChild("Bg" .. direction)
				ApplyTemplateToControl(bgChild, ZO_GetPlatformTemplate(backgroundTemplates[direction]))

				local frameControl = bar:GetNamedChild("Frame" .. direction)
				ApplyTemplateToControl(frameControl, ZO_GetPlatformTemplate(frameTemplates[direction]))

				local warnerChild = warnerControl:GetNamedChild(direction)
				ApplyTemplateToControl(warnerChild, ZO_GetPlatformTemplate(warnerTemplates.texture))
				ApplyTemplateToControl(warnerChild, ZO_GetPlatformTemplate(warnerTemplates[direction]))
			end

			for i, subBar in pairs(bar.barControls) do
				ApplyTemplateToControl(subBar, ZO_GetPlatformTemplate(PAB_TEMPLATES.statusBar))

				local gloss = subBar:GetNamedChild("Gloss")
				ApplyTemplateToControl(gloss, ZO_GetPlatformTemplate(PAB_TEMPLATES.statusBarGloss))

				local anchorTemplates = powerTypeTemplates.anchors
				if anchorTemplates then
					subBar:ClearAnchors()
					ApplyTemplateToControl(subBar, ZO_GetPlatformTemplate(anchorTemplates[i]))
				else
					ApplyTemplateToControl(subBar, ZO_GetPlatformTemplate(PAB_TEMPLATES.anchor))
				end
			end
		   
			local resourceNumbersLabel = bar:GetNamedChild("ResourceNumbers")
			if resourceNumbersLabel then
				ApplyTemplateToControl(resourceNumbersLabel, ZO_GetPlatformTemplate(PAB_TEMPLATES.resourceNumbersLabel))
			end
		end
		
		for i=1,2 do
			window[i] = WINDOW_MANAGER:CreateControlFromVirtual("PetHealth"..i, base, "PetHealth_ZOSStyleBar")

			-- label
			local windowHeight = window[i]:GetHeight()
			window[i].label, ctrl = AddControl(window[i], CT_LABEL, 10)
			ctrl:SetFont("$(BOLD_FONT)|$(KB_16)|soft-shadow-thin")
			ctrl:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
			ctrl:SetDimensions(baseWidth, windowHeight*0.4)
			ctrl:SetAnchor(BOTTOMLEFT, window[i], TOPLEFT, 0, -10.5)
			ctrl:SetAlpha(GetAlphaFromControl(savedVars.showLabels))

			-- bars
			window[i].barleft = window[i]:GetNamedChild("BarLeft")
			window[i].barright = window[i]:GetNamedChild("BarRight")
			
			window[i].barControls = { window[i].barleft, window[i].barright }
			window[i].powerType = POWERTYPE_HEALTH

			SetColors(window[i])
			ApplyStyle(window[i])

			-- shield
			window[i].shieldleft = window[i]:GetNamedChild("ShieldLeft")
			window[i].shieldright = window[i]:GetNamedChild("ShieldRight")
			
			-- values
			window[i].values = window[i]:GetNamedChild("ResourceNumbers")
			window[i].values:SetAlpha(GetAlphaFromControl(savedVars.showValues))
			-- ctrl:SetHidden(not savedVars.showValues or false)

			window[i].warner = PetHealthWarner:New(window[i]);
		end

		window[1]:SetAnchor(TOP, base, TOP, 0, 18)
		window[2]:SetAnchor(TOP, window[1], BOTTOM, 0, 20)	
	end

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
					unitTag = currentPets[i].unitTag
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

function PetHealth.hideInDungeon(toValue)
	hideInDungeon = toValue
	RefreshPetWindow()
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

function PetHealth.lockPetWindow(toValue)
	lockWindow = toValue
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

function PetHealth.onlyInCombatHealthPercentage(toValue)
	onlyInCombatHealthPercentage = toValue
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

	LSC:Register("/pethealthhideindungeon", function()
		savedVars.hideInDungeon = not savedVars.hideInDungeon
		if savedVars.hideInDungeon then
			ChatOutput(GetString(SI_PET_HEALTH_HIDE_IN_DUNGEON_ACTIVATED))
		else
			ChatOutput(GetString(SI_PET_HEALTH_HIDE_IN_DUNGEON_DEACTIVATED))
		end
		PetHealth.hideInDungeon()
	end, GetString(SI_PET_HEALTH_LSC_DUNGEON))
	
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

	if not savedVars.useZosStyle then
		LSC:Register("/pethealthbackground", function()
			savedVars.showBackground = not savedVars.showBackground
			if savedVars.showBackground then
				ChatOutput(GetString(SI_PET_HEALTH_BACKGROUND_ACTIVATED))
			else
				ChatOutput(GetString(SI_PET_HEALTH_BACKGROUND_DEACTIVATED))
			end
			PetHealth.changeBackground(savedVars.showBackground)
		end, GetString(SI_PET_HEALTH_LSC_BACKGROUND))
	else
		-- Forcing show background to off for anyone that may have accidentally enabled this when ZOS style frames are enabled
		showBackground = false
		savedVars.showBackground = false
	end

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
				if healthValuePercentNumber <= 0 then healthValuePercentNumber = 0 end
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
				if shieldValuePercentNumber <= 0 then shieldValuePercentNumber = 0 end
				if shieldValuePercentNumber >= 100 then shieldValuePercentNumber = 99 end
				savedVars.lowShieldAlertSlider = shieldValuePercentNumber
				PetHealth.lowShieldAlertPercentage(shieldValuePercentNumber)
				ChatOutput(GetString(SI_PET_HEALTH_LAM_LOW_SHIELD_WARN) .. ": " .. tostring(shieldValuePercentNumber))
			end
		end
	end, GetString(SI_PET_HEALTH_LSC_WARN_SHIELD))

	LSC:Register("/pethealthcombathealth", function(combatHealthValuePercent)
		if combatHealthValuePercent == nil or combatHealthValuePercent == "" then
			ChatOutput(GetString(SI_PET_HEALTH_LAM_ONLY_IN_COMBAT_HEALTH) .. ": " .. tostring(savedVars.onlyInCombatHealthSlider))
		else
			local combatHealthPercentNumber = tonumber(combatHealthValuePercent)
			if type(combatHealthPercentNumber) == "number" then
				if combatHealthPercentNumber <= 0 then combatHealthPercentNumber = 0 end
				if combatHealthPercentNumber >= 100 then combatHealthPercentNumber = 99 end
				savedVars.onlyInCombatHealthSlider = combatHealthPercentNumber
				PetHealth.onlyInCombatHealthPercentage(combatHealthPercentNumber)
				ChatOutput(GetString(SI_PET_HEALTH_LAM_ONLY_IN_COMBAT_HEALTH) .. ": " .. tostring(combatHealthPercentNumber))
			end
		end
	end, GetString(SI_PET_HEALTH_LSC_COMBAT_HEALTH))
end

local function OnAddOnLoaded(_, addonName)
	if addonName ~= addon.name then return end
	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)
	
	savedVars = ZO_SavedVars:NewAccountWide(addon.savedVarName, addon.savedVarVersion, nil, default, GetWorldName())
	if savedVars.saveMode == 1 then
		savedVars = ZO_SavedVars:NewCharacterIdSettings(addon.savedVarName, addon.savedVarVersion, nil, default, GetWorldName()) 
	end

	--savedVarCopy = savedVars -- during playing, it takes only the local savedVars settings instead picking the savedVars
	PetHealth.savedVars = savedVars
	PetHealth.savedVarsDefault = default
	lowHealthAlertPercentage = savedVars.lowHealthAlertSlider
	lowShieldAlertPercentage = savedVars.lowShieldAlertSlider
	unsummonedAlerts = savedVars.petUnsummonedAlerts
	onlyInCombatHealthPercentage = savedVars.onlyInCombatHealthSlider

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
	local isLAMActive = CheckAddon('LibAddonMenu-2.0')
	local isLSCActive = CheckAddon('LibSlashCommander')
	
	if isLAMActive then
    --Build the LAM addon menu if the library LibAddonMenu-2.0 was found loaded properly
    	LAM = LibAddonMenu2
    	PetHealth.LAM = LAM
		PetHealth.buildLAMAddonMenu()
	end

	if isLSCActive then
   	--Build the slash commands if the library LibSlashCommander was found loaded properly
		LSC = LibSlashCommander
		SlashCommands()
	end

	-- create ui
	CreateWarner()
	CreateControls()
	-- do stuff
	--GetActivePets()
	LoadEvents()
	
	-- debug
	--ChatOutput("loaded")
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
