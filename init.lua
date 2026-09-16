local mods = { "alt", "shift", "ctrl" }

-- Replace values on the right with EXACT IDs from hs.keycodes.currentSourceID()
local sourceForKey = {
	["z"] = "com.apple.keylayout.PolishPro",
	["x"] = "com.apple.keylayout.RussianWin",
	["c"] = "org.unknown.keylayout.PolishColemakCapital",
	["v"] = "com.apple.keylayout.Ukrainian-PC",
}

local previousId
for key, sourceID in pairs(sourceForKey) do
	hs.hotkey.bind(mods, key, function()
		if previousId then
			hs.alert.closeSpecific(previousId)
		end
		local ok = hs.keycodes.currentSourceID(sourceID)

		previousId = hs.alert.show((ok and "⌨️ " or "⚠️ ") .. sourceID, ok and 0.6 or 1.2)
	end)
end
