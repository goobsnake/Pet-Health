--Elder Scrolls: Online addon (written in LUA) which adds persistent in-game health bars to all permanent pets.
--Original/base work of this addon was developed by SCOOTWORKS and I was granted permission by him to take over full development and distribution of this addon.
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
        --[2] = GetString(SI_PET_HEALTH_ACCOUNT_WIDE),
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
            getFunc = function() return savedVariablesOptions[settings.saveMode] end,
            setFunc = function(value)
                for i,v in pairs(savedVariablesOptions) do
                    if v == value then
                        settings.saveMode = i
                    end
                end
            end,
            requiresReload = true,
        },
        --==============================================================================
        {
            type = 'header',
            name = 'Visual changes',
        },
        {
            type = "checkbox",
            name = 'Show background',
            tooltip = 'Show the background of the PetHealth UI',
            getFunc = function() return settings.showBackground end,
            setFunc = function(value) settings.showBackground = value
                PetHealth.changeBackground(value)
            end,
            default = defaults.showBackground,
            width="full",
        },
        {
            type = "checkbox",
            name = 'Show labels',
            tooltip = 'Show the labels at the PetHealth UI',
            getFunc = function() return settings.showLabels end,
            setFunc = function(value) settings.showLabels = value
                PetHealth.changeLabels(value)
            end,
            default = defaults.showLabels,
            width="full",
        },
        {
            type = "checkbox",
            name = 'Show values',
            tooltip = 'Show the values at the PetHealth UI.\nThe values are shown like you have defined them in the standard ESO settings for unit frames!',
            getFunc = function() return settings.showValues end,
            setFunc = function(value) settings.showValues = value
                PetHealth.changeValues(value)
            end,
            default = defaults.showValues,
            width="full",
        },
        {
		    type = "slider",
		    name = "Low Health Alert Percentage",
		    getFunc = function() return settings.lowHealthAlertSlider end,
		    setFunc = function(value) settings.lowHealthAlertSlider = value 
		    	PetHealth.lowHealthAlertPercentage(value) 
		    end,
		    min = 0,
		    max = 100,
		    step = 1,
		    clampInput = true, 
		   	decimals = 0,
		    autoSelect = false, 
		    inputLocation = "right",
		    tooltip = "Displays an on-screen alert depending on the pet health percentage value chosen", 
		    width = "full", 
		    default = defaults.lowHealthAlertSlider,
		},
		{
		    type = "slider",
		    name = "Low Shield Alert Percentage",
		    getFunc = function() return settings.lowShieldAlertSlider end,
		    setFunc = function(value) settings.lowShieldAlertSlider = value 
		    	PetHealth.lowShieldAlertPercentage(value) 
		    end,
		    min = 0,
		    max = 100,
		    step = 1,
		    clampInput = true, 
		   	decimals = 0,
		    autoSelect = false, 
		    inputLocation = "right",
		    tooltip = "Displays an on-screen alert depending on the pet shield percentage value chosen", 
		    width = "full", 
		    default = defaults.lowShieldAlertSlider,
		},
        --==============================================================================
        {
            type = 'header',
            name = 'Behavior changes',
        },
        {
            type = "checkbox",
            name = 'Only in combat',
            tooltip = 'Show the PetHealth UI onlky if you are in combat',
            getFunc = function() return settings.onlyInCombat end,
            setFunc = function(value) settings.onlyInCombat = value
                PetHealth.changeCombatState()
            end,
            default = defaults.onlyInCombat,
            width="full",
        },
    } -- optionsTable
    -- END OF OPTIONS TABLE

    --Create the LAM panel now
    PetHealth.LAM:RegisterOptionControls(addonVars.name .. "_LAM", optionsTable)
end