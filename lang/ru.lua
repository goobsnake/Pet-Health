local strings = {
	SI_PET_HEALTH_COMBAT_ACTIVATED = "Здоровье питомца отображается только во время боя.",
	SI_PET_HEALTH_COMBAT_DEACTIVATED = "Здоровье питомца всегда отоброжается на экране.",
	SI_PET_HEALTH_VALUES_ACTIVATED = "Значений здоровья питомца включены.",
	SI_PET_HEALTH_VALUES_DEACTIVATED = "Значений здоровья питомца отключены.",
	SI_PET_HEALTH_LABELS_ACTIVATED = "Названия питомцев включены.",
	SI_PET_HEALTH_LABELS_DEACTIVATED = "Названия питомцев отключены.",
	SI_PET_HEALTH_BACKGROUND_ACTIVATED = "Фон панели здоровья питомца включен.",
	SI_PET_HEALTH_BACKGROUND_DEACTIVATED = "Фон панели здоровья питомца отключен.",
	SI_PET_HEALTH_UNSUMMONEDALERTS_ACTIVATED = "Оповещение о состоянии питомца включены.",
	SI_PET_HEALTH_UNSUMMONEDALERTS_DEACTIVATED = "Оповещение о состоянии питомца отключены.",
	SI_PET_HEALTH_CLASS = "Ваш класс не поддерживается этим дополнением.",
	-- SLASH COMMANDS
	SI_PET_HEALTH_LSC_DEBUG = "Режим отладки.",
	SI_PET_HEALTH_LSC_COMBAT = "Отоброжать здоровье питомца только в бою.",
	SI_PET_HEALTH_LSC_COMBAT_HEALTH = "Установите, начиная с какого процента здоровья питомца будет отображаться панель. Укажите целое число от 0 до 99 !",
	SI_PET_HEALTH_LSC_VALUES = "Переключить состояние отображения атрибутов питомцев. Необходимо дополнительно включить в настройках самой игры.",
	SI_PET_HEALTH_LSC_LABELS = "Переключить состояние отображения названий питомцев.",
	SI_PET_HEALTH_LSC_BACKGROUND = "Переключить состояние отображения фона панели питомцев.",
	SI_PET_HEALTH_LSC_UNSUMMONEDALERTS = "Переключить состояние отображения статуса питомца (не призван / убит).",
	SI_PET_HEALTH_LSC_WARN_HEALTH = "Установите порог предупреждения в процентах для здоровья домашнего животного. Укажите целое число от 0 до 99 !",
	SI_PET_HEALTH_LSC_WARN_SHIELD = "Установите порог предупреждения в процентах для щита домашнего животного. Укажите целое число от 0 до 99 !",
	--Low health/shield warnings
	SI_PET_HEALTH_LOW_HEALTH_WARNING_MSG = "сильно ранен!",
	SI_PET_HEALTH_LOW_SHIELD_WARNING_MSG = "повредил свой щит!",
	--Unsummoned messages
	SI_PET_HEALTH_UNSUMMONED_SWIMMING_MSG = "Питомцы отозваны пока вы плывете!",
	SI_PET_HEALTH_UNSUMMONED_MSG = "был убит!",
	--LAM Settings menu
	SI_PET_HEALTH_DESC = "Отображение информации о ваших питомцах",
	SI_PET_HEALTH_SAVE_TYPE = "Настройки для:",
	SI_PET_HEALTH_SAVE_TYPE_TT = "Выберите для кого хотите сохранить настройки дополнения (для текущего персонажа / для всего аккаунта).",
	SI_PET_HEALTH_ACCOUNT_WIDE = "Аккаунта",
	SI_PET_HEALTH_EACH_CHAR = "Текущего персонажа",
	SI_PET_HEALTH_LAM_HEADER_VISUAL = "Настройка панели здоровья",
	SI_PET_HEALTH_LAM_BACKGROUND = 'Фон панели',
	SI_PET_HEALTH_LAM_BACKGROUND_TT = 'Переключение состояния отображения панели здоровья питомца.',
	SI_PET_HEALTH_LAM_LABELS = 'Названия питомцев',
	SI_PET_HEALTH_LAM_LABELS_TT = 'Переключение состояния отображения названий питомцев.',
	SI_PET_HEALTH_LAM_VALUES = 'Значения здоровья',
	SI_PET_HEALTH_LAM_VALUES_TT = 'Переключение состояния отображения значения зоровья питомца.\nЗначения отображаются согласно оригинальным настройкам игры!',
	SI_PET_HEALTH_LAM_UNSUMMONED_ALERT = 'Оповещение состояния питомца',
	SI_PET_HEALTH_LAM_UNSUMMONED_ALERT_TT = 'Дополнение оповещает о смерти вашего питомца, а так же об изменении его показателей.',
	SI_PET_HEALTH_LAM_LOW_HEALTH_WARN	= "Порог оповещения о низком здоровье питомца",
	SI_PET_HEALTH_LAM_LOW_HEALTH_WARN_TT= "Дополнение оповещает что здоровье питомца упало ниже установленного значения.",
	SI_PET_HEALTH_LAM_LOW_SHIELD_WARN	= "Порог оповещения о низком значении щита",
	SI_PET_HEALTH_LAM_LOW_SHIELD_WARN_TT= "Дополнение оповещает что показатель щита питомца упал ниже установленного значения.",
	SI_PET_HEALTH_LAM_HEADER_BEHAVIOR = "настройка отображения панели",
	SI_PET_HEALTH_LAM_ONLY_IN_COMBAT = "Только в бою",
	SI_PET_HEALTH_LAM_ONLY_IN_COMBAT_TT = "Дополнение отображает панель здоровья питомца только в бою.",
	SI_PET_HEALTH_LAM_ONLY_IN_COMBAT_HEALTH	= "Порог отображения панели здоровья в бою",
	SI_PET_HEALTH_LAM_ONLY_IN_COMBAT_HEALTH_TT = "Дополнение отображает панель здоровья питомца при значениях ниже или равном указанному.",
}

for stringId, stringValue in pairs(strings) do
   ZO_CreateStringId(stringId, stringValue)
   SafeAddVersion(stringId, 1)
end
