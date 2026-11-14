--[[
  Dziennik - kronika przygod Twojej postaci: nowe strefy (ze zrzutem ekranu),
  poziomy, smierci. Inne addony moga dopisywac wpisy przez Dziennik_Add.
]]
local _, ns = ...
local C, T = ns.CONFIG, ns.T

local ONCE = { zone = true, gather = true, fish = true, vendor = true }

local function Entries()
	local j = ns.db.journal[ns.charKey]
	if not j then
		j = {}
		ns.db.journal[ns.charKey] = j
	end
	return j
end

local function Firsts()
	local f = ns.db.firsts[ns.charKey]
	if not f then
		f = {}
		ns.db.firsts[ns.charKey] = f
	end
	return f
end

local function Render(e)
	return T("j_" .. e.k, tostring(e.a or "?"), tostring(e.b or "?"))
end

local window -- tworzone przy pierwszym otwarciu
local RefreshWindow

local function Add(kind, a, b)
	local entry = { t = time(), k = kind, a = a, b = b }
	table.insert(Entries(), entry)
	if ns.db.settings.announce then ns.Print(Render(entry)) end
	if window and window:IsShown() then RefreshWindow() end
end

-- Publiczne API dla innych addonow:
--   Dziennik_Add("gather" | "fish" | "vendor", nazwa, strefa)
-- Wpis "pierwszy raz" dodawany jest tylko raz na postac.
function Dziennik_Add(kind, name, zone)
	if not ns.db or not ns.charKey or not kind or not name then return end
	if not C.locales.pl["j_" .. kind] then return end
	if ONCE[kind] then
		local key = kind .. ":" .. tostring(name)
		local firsts = Firsts()
		if firsts[key] then return end
		firsts[key] = time()
	end
	Add(kind, name, zone)
end

local function CurrentZoneName()
	local mapID = C_Map.GetBestMapForUnit("player")
	if ns.Usable(mapID) and mapID then return ns.MapName(ns.ZoneMapID(mapID)) end
	local z = GetZoneText and GetZoneText()
	return ns.Usable(z) and z or "?"
end

------------------------------------------------------------------------
-- Zdarzenia gry
------------------------------------------------------------------------

local function CheckZone()
	local mapID = C_Map.GetBestMapForUnit("player")
	if not ns.Usable(mapID) or not mapID then return end
	local zoneID = ns.ZoneMapID(mapID)
	local key = "zone:" .. zoneID
	local firsts = Firsts()
	if firsts[key] then return end
	firsts[key] = time()
	Add("zone", ns.MapName(zoneID))
	if ns.db.settings.screenshots and Screenshot then
		C_Timer.After(2.5, function() pcall(Screenshot) end)
	end
end

ns.On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, CheckZone) end)
ns.On("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(1, CheckZone) end)
ns.On("PLAYER_LEVEL_UP", function(level) Add("level", level, CurrentZoneName()) end)
ns.On("PLAYER_DEAD", function() Add("death", CurrentZoneName()) end)

------------------------------------------------------------------------
-- Okno dziennika
------------------------------------------------------------------------

local function CreateWindow()
	local f = CreateFrame("Frame", "DziennikFrame", UIParent, "BackdropTemplate")
	f:SetSize(480, 440)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	tinsert(UISpecialFrames, "DziennikFrame") -- Esc zamyka okno

	f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	f.Title:SetPoint("TOP", 0, -20)

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)

	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 22, -50)
	scroll:SetPoint("BOTTOMRIGHT", -40, 22)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(410, 10)
	scroll:SetScrollChild(child)

	f.Text = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.Text:SetPoint("TOPLEFT")
	f.Text:SetWidth(410)
	f.Text:SetJustifyH("LEFT")
	f.Text:SetJustifyV("TOP")
	f.Text:SetSpacing(4)
	f.Child = child

	f:Hide()
	return f
end

RefreshWindow = function()
	local who = ns.charKey and (ns.charKey:match("^[^-]+") or ns.charKey) or "?"
	window.Title:SetText(T("title", who))
	local entries = Entries()
	local lines = {}
	for i = #entries, 1, -1 do
		local e = entries[i]
		lines[#lines + 1] = "|cff9a9a9a" .. date("%d.%m.%Y %H:%M", e.t) .. "|r   " .. Render(e)
	end
	window.Text:SetText(#lines > 0 and table.concat(lines, "\n") or T("empty"))
	window.Child:SetHeight(window.Text:GetStringHeight() + 10)
end

local function ToggleWindow()
	window = window or CreateWindow()
	if window:IsShown() then
		window:Hide()
	else
		RefreshWindow()
		window:Show()
	end
end

------------------------------------------------------------------------
-- Komendy
------------------------------------------------------------------------

C.onEmpty = ToggleWindow

C.onCommand = function(cmd)
	if cmd == "screenshots" then
		ns.db.settings.screenshots = not ns.db.settings.screenshots
		ns.Print(T("screenshots", ns.OnOff(ns.db.settings.screenshots)))
		return true
	elseif cmd == "open" then
		ToggleWindow()
		return true
	end
end

C.stats = function()
	ns.Print(T("stats", #Entries()))
end

C.clearLabel = function() return T("title", ns.charKey or "?") end
C.clear = function()
	ns.db.journal[ns.charKey] = {}
	ns.db.firsts[ns.charKey] = {}
	if window and window:IsShown() then RefreshWindow() end
end
