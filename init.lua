local mehModifier = { "alt", "shift", "ctrl" }

-- Replace values on the right with EXACT IDs from hs.keycodes.currentSourceID()
local sourceForKey = {
	["z"] = "com.apple.keylayout.PolishPro",
	["x"] = "com.apple.keylayout.RussianWin",
	["c"] = "org.unknown.keylayout.PolishColemakCapital",
	["v"] = "com.apple.keylayout.Ukrainian-PC",
}

local previousId
for key, sourceID in pairs(sourceForKey) do
	hs.hotkey.bind(mehModifier, key, function()
		if previousId then
			hs.alert.closeSpecific(previousId)
		end
		local ok = hs.keycodes.currentSourceID(sourceID)

		previousId = hs.alert.show((ok and "⌨️ " or "⚠️ ") .. sourceID, ok and 0.6 or 1.2)
	end)
end

-- Map hotkeys to app names
local appBindings = {
	H = "Google Chrome",
	E = "Microsoft Edge",
	G = "Ghostty",
	M = "Mail",
	T = "Microsoft Teams",
	W = "Windows App",
	["1"] = "Safari",
	["0"] = "0",
}

for key, appName in pairs(appBindings) do
	hs.hotkey.bind(mehModifier, key, function()
		if key == "0" then
			local win = hs.window.focusedWindow()
			if not win then
				hs.alert.show("No focused window")
				return
			end
			local app = win:application()
			local name = app and app:name() or "(unknown)"
			local bundleID = app and app:bundleID() or "(unknown)"
			hs.alert.show(name .. "\n" .. bundleID)
			print("Focused app:", name, bundleID)
			return
		end

		local app = hs.application.get(appName)

		-- App not running: launch it
		if not app then
			hs.application.launchOrFocus(appName)
			return
		end

		local windows = hs.fnutils.filter(app:allWindows(), function(w)
			return w:isStandard() and w:isVisible()
		end)

		-- No standard windows: just activate app
		if #windows == 0 then
			app:activate()
			return
		end

		-- Only one window: focus + activate
		if #windows == 1 then
			app:activate()
			windows[1]:focus()
			return
		end

		-- Multiple windows: cycle
		table.sort(windows, function(a, b)
			return a:id() < b:id()
		end)

		local focused = hs.window.focusedWindow()
		local isAppFocused = focused and focused:application():name() == appName

		if not isAppFocused then
			-- App not currently focused: bring to front, focus first window
			app:activate()
			windows[1]:focus()
		else
			-- App already focused: cycle to next window
			local currentIdx = 1
			for i, w in ipairs(windows) do
				if focused and w:id() == focused:id() then
					currentIdx = i
					break
				end
			end
			local nextIdx = (currentIdx % #windows) + 1
			windows[nextIdx]:focus()
		end
	end)
end
