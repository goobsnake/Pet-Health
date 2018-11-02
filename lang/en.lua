local strings = {
	SI_PET_HEALTH_COMBAT_ACTIVATED = "The pet health window is only active during a fight.",
	SI_PET_HEALTH_COMBAT_DEACTIVATED = "The pet health window is always active, as long a pet is summoned.",
	SI_PET_HEALTH_VALUES_ACTIVATED = "Pet health values are enabled.",
	SI_PET_HEALTH_VALUES_DEACTIVATED = "Pet health values are disabled.",
	SI_PET_HEALTH_LABELS_ACTIVATED = "Pet health labels are enabled.",
	SI_PET_HEALTH_LABELS_DEACTIVATED = "Pet health labels are disabled.",
	SI_PET_HEALTH_BACKGROUND_ACTIVATED = "Pet health frame background is enabled.",
	SI_PET_HEALTH_BACKGROUND_DEACTIVATED = "Pet health frame background is disabled.",
	SI_PET_HEALTH_CLASS = "Your class is not supported with this addon.",
	-- SLASH COMMANDS
	SI_PET_HEALTH_LSC_DEBUG = "Toggle debug mode.",
	SI_PET_HEALTH_LSC_COMBAT = "Toggle pet window in combat.",
	SI_PET_HEALTH_LSC_VALUES = "Toggle pet attribute values. They have to set up in eso combat settings.",
	SI_PET_HEALTH_LSC_LABELS = "Toggle pet name labels.",
	SI_PET_HEALTH_LSC_BACKGROUND = "Toggle pet window background.",
	--LAM Settings menu
	SI_PET_HEALTH_DESC				= "Show info about your pets",
	SI_PET_HEALTH_SAVE_TYPE			= "Save type",
	SI_PET_HEALTH_SAVE_TYPE_TT		= "Select if you want to save the settings diferently for each of your cahracters, or if you want to use the same account wide settings for each of them.",
	SI_PET_HEALTH_ACCOUNT_WIDE		= "Account wide",
	SI_PET_HEALTH_EACH_CHAR	 		= "Each character",
}

for stringId, stringValue in pairs(strings) do
   ZO_CreateStringId(stringId, stringValue)
   SafeAddVersion(stringId, 1)
end