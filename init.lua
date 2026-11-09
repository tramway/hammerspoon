local mehModifier = { "alt", "shift", "ctrl" }

-- Optional machine-local extensions (git-ignored): ~/.hammerspoon/.hammerspoon_extensions.lua
-- The file may return a table with any of:
--   appBindings  = { [key] = "App Name" }       -- add/override app shortcuts
--   sourceForKey = { [key] = "keylayout.id" }   -- add/override input source shortcuts
--   hotkeys      = { [key] = function() end }   -- custom hotkeys bound with meh modifier
--   setup        = function(ctx) end            -- arbitrary code; ctx = { mehModifier, describe(key, text) }
--                                                  (describe adds an entry to the meh+9 help overlay)
--   ignore       = { "space", "q" }             -- keys (with meh) this config must NOT bind,
--                                                  e.g. reserved for another tool; case-insensitive
local shortcuts = {}
local function describe(key, text)
	local entry = { key = tostring(key):upper(), text = text }
	shortcuts[#shortcuts + 1] = entry
	return entry
end

local extensions = {}
do
	local path = hs.configdir .. "/.hammerspoon_extensions.lua"
	if hs.fs.attributes(path) then
		local chunk, loadErr = loadfile(path)
		local ok, result
		if chunk then
			ok, result = pcall(chunk)
		else
			ok, result = false, loadErr
		end
		if ok and type(result) == "table" then
			extensions = result
		elseif not ok then
			hs.alert.show("⚠️ Extensions error: see console", 2)
			print("Extensions error:", result)
		elseif result ~= nil then
			print("Extensions: expected a table, got " .. type(result))
		end
	end
end

-- Returns extensions[name] if it is a table, otherwise {} (with a console warning)
local function extTable(name)
	local v = extensions[name]
	if v == nil then
		return {}
	end
	if type(v) ~= "table" then
		print(("Extensions: '%s' must be a table, got %s"):format(name, type(v)))
		return {}
	end
	return v
end

-- Merge string values from src into dst; keys are case-insensitive (src replaces any case variant)
local function merge(dst, src)
	for k, v in pairs(src) do
		if type(v) ~= "string" then
			print(("Extensions: value for key '%s' must be a string, got %s"):format(tostring(k), type(v)))
		else
			local lk = tostring(k):lower()
			for dk in pairs(dst) do
				if tostring(dk):lower() == lk then
					dst[dk] = nil
				end
			end
			dst[k] = v
		end
	end
end

local ignored = {}
local ignoredKeys = {}
for _, key in ipairs(extTable("ignore")) do
	ignored[tostring(key):lower()] = true
	ignoredKeys[#ignoredKeys + 1] = tostring(key):upper()
end

-- Bind meh+key and list it in the help overlay, unless the key is in the ignore list.
-- Re-binding the same key replaces the earlier binding (last one wins).
local bound = {}
local function bind(key, text, fn)
	local k = tostring(key):lower()
	if ignored[k] then
		return
	end
	if type(fn) ~= "function" then
		print(("Skipping meh+%s: handler is not a function"):format(k))
		return
	end
	local prev = bound[k]
	if prev then
		print(("meh+%s rebound: '%s' -> '%s'"):format(k, prev.entry.text, text))
		prev.hotkey:delete()
	end
	local ok, hotkey = pcall(hs.hotkey.bind, mehModifier, k, fn)
	if not ok then
		print(("Failed to bind meh+%s: %s"):format(k, tostring(hotkey)))
		return
	end
	if prev then
		prev.hotkey = hotkey
		prev.entry.text = text
	else
		bound[k] = { hotkey = hotkey, entry = describe(key, text) }
	end
end

-- Replace values on the right with EXACT IDs from hs.keycodes.currentSourceID()
local sourceForKey = {
	["z"] = "com.apple.keylayout.PolishPro",
	["x"] = "com.apple.keylayout.RussianWin",
	["c"] = "org.unknown.keylayout.PolishColemakCapital",
	["v"] = "com.apple.keylayout.Ukrainian-PC",
}
merge(sourceForKey, extTable("sourceForKey"))

bind("2", "Spotify volume down", hs.spotify.volumeDown)
bind("4", "Spotify volume up", hs.spotify.volumeUp)

local previousId
for key, sourceID in pairs(sourceForKey) do
	bind(key, "Input source: " .. sourceID:gsub("^.*%.", ""), function()
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
	U = "Microsoft Edge Beta",
	G = "Ghostty",
	M = "Mail",
	T = "Microsoft Teams",
	W = "Windows App",
	["1"] = "Safari",
	["0"] = "0",
}
merge(appBindings, extTable("appBindings"))

for key, appName in pairs(appBindings) do
	bind(key, appName == "0" and "Show focused app name / bundle ID" or ("App: " .. appName), function()
		if appName == "0" then
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

for key, fn in pairs(extTable("hotkeys")) do
	bind(key, "Custom", fn)
end

if type(extensions.setup) == "function" then
	local ok, err = pcall(extensions.setup, { mehModifier = mehModifier, describe = describe })
	if not ok then
		hs.alert.show("⚠️ Extensions setup error: see console", 2)
		print("Extensions setup error:", err)
	end
end

-- meh + 9: toggle an overlay listing all assigned shortcuts
local helpAlertId, helpTimer
bind("9", "Show this shortcut list", function()
	if helpAlertId then
		hs.alert.closeSpecific(helpAlertId, 0.1)
		helpAlertId = nil
		if helpTimer then
			helpTimer:stop()
			helpTimer = nil
		end
		return
	end

	table.sort(shortcuts, function(a, b)
		local ta, tb = tostring(a.text):lower(), tostring(b.text):lower()
		if ta ~= tb then
			return ta < tb
		end
		return a.key < b.key
	end)
	local lines = { "Meh = ⌃⌥⇧", "" }
	for _, s in ipairs(shortcuts) do
		lines[#lines + 1] = string.format("%-6s %s", s.key, s.text)
	end
	if #ignoredKeys > 0 then
		table.sort(ignoredKeys)
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Ignored (reserved for other tools):"
		for _, key in ipairs(ignoredKeys) do
			lines[#lines + 1] = string.format("%-6s", key)
		end
	end

	helpAlertId = hs.alert.show(table.concat(lines, "\n"), {
		textFont = "Menlo",
		textSize = 16,
		radius = 10,
	}, hs.screen.mainScreen(), 15)
	-- keep a reference so the timer isn't garbage-collected before it fires
	helpTimer = hs.timer.doAfter(15, function()
		helpAlertId = nil
		helpTimer = nil
	end)
end)

-- Fallback for unassigned letters: meh+<letter> activates a running app whose name starts
-- with that letter; repeated presses cycle through all matching apps (sorted by name).
local function activateByFirstLetter(letter)
	local matches = {}
	for _, app in ipairs(hs.application.runningApplications()) do
		local name = app:name()
		if app:kind() == 1 and name and name:sub(1, 1):lower() == letter then
			matches[#matches + 1] = app
		end
	end
	if #matches == 0 then
		hs.alert.show("No running app starting with " .. letter:upper(), 0.8)
		return
	end
	table.sort(matches, function(a, b)
		local na, nb = a:name():lower(), b:name():lower()
		if na ~= nb then
			return na < nb
		end
		return a:pid() < b:pid()
	end)

	local front = hs.application.frontmostApplication()
	local nextIdx = 1
	for i, app in ipairs(matches) do
		if front and app:pid() == front:pid() then
			nextIdx = (i % #matches) + 1
			break
		end
	end
	local target = matches[nextIdx]
	if target:isHidden() then
		target:unhide()
	end
	target:activate()
end

local taken = {}
for _, s in ipairs(shortcuts) do
	taken[s.key:lower()] = true -- includes keys added via describe() in extensions.setup
end
local letterCount = 0
for byte = string.byte("a"), string.byte("z") do
	local letter = string.char(byte)
	if not taken[letter] and not ignored[letter] then
		hs.hotkey.bind(mehModifier, letter, function()
			activateByFirstLetter(letter)
		end)
		letterCount = letterCount + 1
	end
end
if letterCount > 0 then
	describe("A-Z", "Running app by first letter (unassigned letters, repeat to cycle)")
end
