--Initial LAM Settings support and code cleanup by Baertram

PetHealth = PetHealth or {}

function PetHealth.buildLAMAddonMenu()
    local settings = PetHealth.savedVars
    if not PetHealth.LAM or not settings then return false end
    local defaults = PetHealth.savedVarsDefault
    local addonVars = PetHealth.addonData

    local panelData = {
        type 				= 'panel',
        name 				= addonVars.name,
        displayName 		= addonVars.lamDisplayName,
        author 				= addonVars.lamAuthor,
        version 			= tostring(addonVars.version),
        registerForRefresh 	= false,
        registerForDefaults = true,
        slashCommand        = "/pethealthsettings",
        website             = addonVars.lamUrl
    }

    local savedVariablesOptions = {
        [1] = GetString(SI_PET_HEALTH_EACH_CHAR),
        [2] = GetString(SI_PET_HEALTH_ACCOUNT_WIDE),
    }
    --Register the LAM panel and add it to the global PetHealth table
    PetHealth.LAM_SettingsPanel = PetHealth.LAM:RegisterAddonPanel(addonVars.name .. "_LAM", panelData)
    --Create the options table for the LAM controls
    local optionsTable =
    {	-- BEGIN OF OPTIONS TABLE

        {
            type = 'description',
            text = GetString(SI_PET_HEALTH_DESC),
        },
        {
            type = 'dropdown',
            name = GetString(SI_PET_HEALTH_SAVE_TYPE),
            tooltip = GetString(SI_PET_HEALTH_SAVE_TYPE_TT),
            choices = savedVariablesOptions,
            getFunc = function() return savedVariablesOptions[PetHealth_Save[GetWorldName()][GetDisplayName()]['$AccountWide']["saveMode"]] end,
            setFunc = function(value)
                for i,v in pairs(savedVariablesOptions) do
                    if v == value then
                        PetHealth_Save[GetWorldName()][GetDisplayName()]['$AccountWide']["saveMode"] = i
                    end
                end
            end,
            requiresReload = true,
        },
        --==============================================================================
        {
            type = 'header',
            name = GetString(SI_PET_HEALTH_LAM_HEADER_VISUAL),
        },
        {
            type = "checkbox",
            name = GetString(SI_PET_HEALTH_LAM_LOCK_WINDOW),
            tooltip = GetString(SI_PET_HEALTH_LAM_LOCK_WINDOW_TT),
            getFunc = function() return settings.lockWindow end,
            setFunc = function(value) settings.lockWindow = value
                PetHealth.lockPetWindow(value)
            end,
            default = defaults.lockWindow,
            width="full",
            requiresReload = true,
        },
        {
            type = "checkbox",
            name = GetString(SI_PET_HEALTH_LAM_BACKGROUND),
            tooltip = GetString(SI_PET_HEALTH_LAM_BACKGROUND_TT),
            getFunc = function() return settings.showBackground end,
            setFunc = function(value) settings.showBackground = value
                PetHealth.changeBackground(value)
            end,
            default = defaults.showBackground,
            disabled = function() return settings.useZosStyle end,
            width="full",
        },
        {
            type = "checkbox",
            name = GetString(SI_PET_HEALTH_LAM_LABELS),
            tooltip = GetString(SI_PET_HEALTH_LAM_LABELS_TT),
            getFunc = function() return settings.showLabels end,
            setFunc = function(value) settings.showLabels = value
                PetHealth.changeLabels(value)
            end,
            default = defaults.showLabels,
            width="full",
        },
        {
            type = "checkbox",
            name = GetString(SI_PET_HEALTH_LAM_VALUES),
            tooltip = GetString(SI_PET_HEALTH_LAM_VALUES_TT),
            getFunc = function() return settings.showValues end,
            setFunc = function(value) settings.showValues = value
                PetHealth.changeValues(value)
            end,
            default = defaults.showValues,
            width="full",
        },
        {
            type = "checkbox",
            name = GetString(SI_PET_HEALTH_LAM_UNSUMMONED_ALERT),
            tooltip = GetString(SI_PET_HEALTH_LAM_UNSUMMONED_ALERT_TT),
            getFunc = function() return settings.petUnsummonedAlerts end,
            setFunc = function(value) settings.petUnsummonedAlerts = value
                PetHealth.unsummonedAlerts(value)
            end,
            default = defaults.petUnsummonedAlerts,
            width="full",
        },
        {
            type = "checkbox",
            name = GetString(SI_PET_HEALTH_LAM_USE_ZOS_STYLE),
            tooltip = GetString(SI_PET_HEALTH_LAM_USE_ZOS_STYLE_TT),
            getFunc = function() return settings.useZosStyle end,
            setFunc = function(value) settings.useZosStyle = value
                if value == true then
                    settings.showBackground = false
                    PetHealth.changeBackground(false)
                else
                    settings.showBackground = true
                    PetHealth.changeBackground(true)
                end
            end,
            width = "full",
            requiresReload = true,
        },
        {
		    type = "slider",
		    name = GetString(SI_PET_HEALTH_LAM_LOW_HEALTH_WARN),
            tooltip = GetString(SI_PET_HEALTH_LAM_LOW_HEALTH_WARN_TT),
		    getFunc = function() return settings.lowHealthAlertSlider end,
		    setFunc = function(value) settings.lowHealthAlertSlider = value 
		    	PetHealth.lowHealthAlertPercentage(value) 
		    end,
		    min = 0,
		    max = 99,
		    step = 1,
		    clampInput = true, 
		   	decimals = 0,
		    autoSelect = false, 
		    inputLocation = "right",
		    width = "full",
		    default = defaults.lowHealthAlertSlider,
		},
		{
		    type = "slider",
            name = GetString(SI_PET_HEALTH_LAM_LOW_SHIELD_WARN),
            tooltip = GetString(SI_PET_HEALTH_LAM_LOW_SHIELD_WARN_TT),
		    getFunc = function() return settings.lowShieldAlertSlider end,
		    setFunc = function(value) settings.lowShieldAlertSlider = value 
		    	PetHealth.lowShieldAlertPercentage(value) 
		    end,
		    min = 0,
		    max = 99,
		    step = 1,
		    clampInput = true, 
		   	decimals = 0,
		    autoSelect = false, 
		    inputLocation = "right",
		    width = "full",
		    default = defaults.lowShieldAlertSlider,
		},
        --==============================================================================
        {
            type = 'header',
            name = GetString(SI_PET_HEALTH_LAM_HEADER_BEHAVIOR),
        },
        {
            type = "checkbox",
            name = GetString(SI_PET_HEALTH_LAM_HIDE_IN_DUNGEON),
            tooltip = GetString(SI_PET_HEALTH_LAM_HIDE_IN_DUNGEON_TT),
            getFunc = function() return settings.hideInDungeon end,
            setFunc = function(value) settings.hideInDungeon = value
                PetHealth.hideInDungeon(value)
            end,
            default = defaults.hideInDungeon,
            width="full",
        },
        {
            type = "checkbox",
            name = GetString(SI_PET_HEALTH_LAM_ONLY_IN_COMBAT),
            tooltip = GetString(SI_PET_HEALTH_LAM_ONLY_IN_COMBAT_TT),
            getFunc = function() return settings.onlyInCombat end,
            setFunc = function(value) settings.onlyInCombat = value
                PetHealth.changeCombatState()
            end,
            default = defaults.onlyInCombat,
            width="full",
        },
        {
            type = "slider",
            name = GetString(SI_PET_HEALTH_LAM_ONLY_IN_COMBAT_HEALTH),
            tooltip = GetString(SI_PET_HEALTH_LAM_ONLY_IN_COMBAT_HEALTH_TT),
            getFunc = function() return settings.onlyInCombatHealthSlider end,
            setFunc = function(value) settings.onlyInCombatHealthSlider = value 
                PetHealth.onlyInCombatHealthPercentage(value) 
            end,
            min = 0,
            max = 99,
            step = 1,
            clampInput = true, 
            decimals = 0,
            autoSelect = false, 
            inputLocation = "right",
            width = "full",
            default = defaults.onlyInCombatHealthSlider,
        },
    } -- optionsTable
    -- END OF OPTIONS TABLE

    --Create the LAM panel now
    PetHealth.LAM:RegisterOptionControls(addonVars.name .. "_LAM", optionsTable)
end