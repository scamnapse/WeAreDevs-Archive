if not Sleep then Sleep = sleep end

math.randomseed(os.time())

activateProtection()
hideAllCEWindows()

openProcess'RobloxPlayerBeta.exe'
pause()
getApplication().Title = "Check Cashed, by Louka - "..tostring(math.random(0, 25565))
getMainForm():SetCaption("Check Cashed, by Louka - "..tostring(math.random(0, 25565)))
getSettingsForm():SetCaption("Check Cashed, by Louka - "..tostring(math.random(0, 25565)))
getMemoryViewForm():SetCaption("Check Cashed, by Louka - "..tostring(math.random(0, 25565)))
getLuaEngine():SetCaption("Check Cashed, by Louka - "..tostring(math.random(0, 25565)))

if getSettings().Value["Scanfolder"] == "C:\\" then
	getSettings().Value["Scanfolder"] = "C:\\Program Files\\"
else
	getSettings().Value["Scanfolder"] = "C:\\"
end

reloadSettingsFromRegistry()
unhideMainCEwindow()

unpause();