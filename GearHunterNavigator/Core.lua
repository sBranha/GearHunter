local ADDON, GHN = ...
_G.GearHunterNavigator = GHN
GHN.version = "0.5.3"
GHN.EVENT_LIMIT = 40
local defaults = { steps = {}, notes = {}, diagnostic = {}, mountID = nil, tab = "Dashboard" }

local function InitializeSaved()
  if type(GearHunterNavigatorDB) ~= "table" then GearHunterNavigatorDB = {} end
  for k,v in pairs(defaults) do
    if GearHunterNavigatorDB[k] == nil then
      GearHunterNavigatorDB[k] = type(v) == "table" and {} or v
    end
  end
  GHN.db = GearHunterNavigatorDB
end

function GHN:Log(kind, message)
  if not self.db then return end
  local events = self.db.diagnostic
  if type(events) ~= "table" then events = {}; self.db.diagnostic = events end
  local stamp = date and date("%Y-%m-%d %H:%M:%S") or "unknown time"
  table.insert(events, 1, {at=stamp, kind=tostring(kind or "INFO"), message=tostring(message or "")})
  while #events > self.EVENT_LIMIT do table.remove(events) end
  if self.RefreshDiagnostics and self.db.tab == "Diagnostics" then pcall(function() self:RefreshDiagnostics() end) end
end

function GHN:Safe(label, fn)
  local ok, result = pcall(fn)
  if not ok then self:Log("ERROR", label .. ": " .. tostring(result)) end
  return ok, result
end

function GHN:GetCharacterSummary()
  local className = UnitClass and UnitClass("player") or "Unknown"
  local faction = UnitFactionGroup and UnitFactionGroup("player") or "Unknown"
  local specName = "Not selected"
  if GetSpecialization and GetSpecializationInfo then
    local spec = GetSpecialization()
    if spec then local _, n = GetSpecializationInfo(spec); if n then specName = n end end
  end
  local ilevel = 0
  if GetAverageItemLevel then
    local _, equipped = GetAverageItemLevel()
    ilevel = tonumber(equipped) or 0
  end
  local mapName = "Unknown"
  if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID then local info = C_Map.GetMapInfo(mapID); if info and info.name then mapName = info.name end end
  end
  return {name=UnitName("player") or "Character", level=UnitLevel("player") or 0,
    class=className, spec=specName, faction=faction, ilevel=ilevel, zone=mapName}
end

function GHN:GetRecommendation()
  if self.GetSmartRecommendation then
    local title, why=self:GetSmartRecommendation()
    if title then return title, why end
  end
  if self.gearScan and self.gearScan.results and self.gearScan.results[1] then
    local best=self.gearScan.results[1]
    return "Potential bag upgrade: "..best.name,
      string.format("Already in bag %d, slot %d. %s: +%d item levels. Review stats and usability before equipping; this is not a BiS guarantee.",
        best.bag,best.bagSlot,best.slotName,best.delta)
  end
  local c = self:GetCharacterSummary()
  if c.level < 10 then
    return "Focus on your starting experience and available introductory quests.",
    "At this level, completing the nearby quest chain is a straightforward way to progress. This beta has no measured route rankings yet."
  end
  if c.level < 80 then
    return "Follow your current campaign and consider an available dungeon queue.",
    "Your level is "..c.level..". This is a general recommendation, NOT a verified fastest route; future guide data will compare actual XP routes."
  end
  return "Check achievable item upgrades and your current campaign.",
    "Your equipped average item level is "..string.format("%.1f",c.ilevel)..". Open Gear to review slots; open Gear to scan the in-game Encounter Journal for possible dungeon/raid upgrades."
end

function GHN:TakeMeThere(guide)
  if not guide or not guide.mapID then return false, "This mount does not have a verified route in this test build." end
  if InCombatLockdown and InCombatLockdown() then return false, "Map/waypoint actions are paused in combat." end
  if not (C_Map and C_Map.GetMapInfo) then return false, "World map API not available." end
  local info = C_Map.GetMapInfo(guide.mapID)
  if not info or info.name ~= guide.mapName then
    return false, "The zone map identifier did not match; no waypoint was placed."
  end
  local made = false
  if C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    local ok = pcall(function()
      local point = UiMapPoint.CreateFromCoordinates(guide.mapID, guide.x, guide.y)
      C_Map.SetUserWaypoint(point)
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
      end
    end)
    made = ok
    if not ok then self:Log("WAYPOINT", "Waypoint placement was unavailable") end
  end
  -- Do not open the Blizzard world map behind the Navigator interface.
  -- The separate OPEN MAP control opens the map with Navigator hidden.
  if made and self.StartMeasuredRoute then self:StartMeasuredRoute(guide) end
  return made, made and "Waypoint set. Choose OPEN MAP to view your destination." or
    "Waypoint API unavailable. Use OPEN MAP to view the destination manually."
end

local event = CreateFrame("Frame")
event:RegisterEvent("ADDON_LOADED")
event:RegisterEvent("PLAYER_LOGIN")
event:RegisterEvent("QUEST_LOG_UPDATE")
event:RegisterEvent("UPDATE_FACTION")
event:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
event:RegisterEvent("TOYS_UPDATED")
event:RegisterEvent("NEW_TOY_ADDED")

event:RegisterEvent("PLAYER_ENTERING_WORLD")
event:RegisterEvent("ZONE_CHANGED_NEW_AREA")
event:RegisterEvent("ZONE_CHANGED")
event:RegisterEvent("ZONE_CHANGED_INDOORS")
event:RegisterEvent("COMPANION_UPDATE")
event:RegisterEvent("BAG_UPDATE_DELAYED")
event:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
event:RegisterEvent("UNIT_MODEL_CHANGED")
event:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
event:RegisterEvent("PLAYER_LEVEL_UP")
event:RegisterEvent("UPDATE_EXPANSION_LEVEL")
event:RegisterEvent("GET_ITEM_INFO_RECEIVED")
event:RegisterEvent("ITEM_DATA_LOAD_RESULT")
event:RegisterEvent("ADDON_ACTION_BLOCKED")
event:RegisterEvent("ADDON_ACTION_FORBIDDEN")
event:SetScript("OnEvent", function(_, name, arg1, arg2)
  if name=="GET_ITEM_INFO_RECEIVED" or name=="ITEM_DATA_LOAD_RESULT" then
    GHN.gearTooltipCache={}
    if GHN.gearRequestedItemIDs and type(arg1)=="number" then
      GHN.gearRequestedItemIDs[arg1]=nil
    end
  end
  if name == "ADDON_LOADED" and arg1 == ADDON then
    InitializeSaved()
    GHN:Log("INFO", "Gear Hunter Navigator 0.5.3 smart navigation initialized")
  elseif name == "PLAYER_LOGIN" then
    if not GHN.db then InitializeSaved() end
    GHN:Safe("IntelligenceProfile",function() GHN:Profile() end)
    GHN:Safe("Discovery icon filters",function() GHN:InitializeDiscoveryFilters() end)
    GHN:Safe("CreateUI",function() GHN:CreateUI() end)
    GHN:Safe("MinimapLauncher",function() GHN:CreateMinimapLauncher() end)
  elseif (name == "PLAYER_ENTERING_WORLD" or name == "ZONE_CHANGED_NEW_AREA" or name == "ZONE_CHANGED" or name == "ZONE_CHANGED_INDOORS") and GHN.db then
    GHN:Safe("RouteProgress",function() GHN:UpdateMeasuredRoute() end)
    if GHN.db.tab=="Map" and GHN.frame and GHN.frame:IsShown() then GHN:Safe("Zone Explorer",function()GHN:UpdateDiscoveryZone(true)end)end
    GHN:Safe("CollectionProgress",function() GHN:CheckCollectedGoal() end)
  elseif (name == "PLAYER_LEVEL_UP" or name == "UPDATE_EXPANSION_LEVEL") and GHN.db then
    -- A level change changes the five-level eligibility window; never show
    -- candidates evaluated under the previous window as if they were current.
    GHN.gearScanDirty=true
    GHN.gearSelected=nil
    GHN.gearSelectedData=nil
    if GHN.gearSource=="journal" then
      GHN:Safe("LevelChangedJournal",function() GHN:ScanJournalUpgrades() end)
    end
    if GHN.frame and GHN.frame:IsShown() then
      GHN:Safe("LevelChangedUI",function() GHN:Refresh() end)
    end
  elseif (name == "GET_ITEM_INFO_RECEIVED" or name == "ITEM_DATA_LOAD_RESULT") and GHN.journalJob then
    GHN.gearScanDirty=true
    GHN:Safe("JournalItemCache",function() GHN:JournalItemDataLoaded(arg1,arg2) end)
  elseif (name == "BAG_UPDATE_DELAYED" or name == "PLAYER_EQUIPMENT_CHANGED" or name == "PLAYER_SPECIALIZATION_CHANGED" or name == "GET_ITEM_INFO_RECEIVED" or name == "ITEM_DATA_LOAD_RESULT" or (name == "UNIT_MODEL_CHANGED" and arg1 == "player")) and GHN.db then
    GHN.gearScanDirty=true
    GHN.characterModelNeedsRefresh=true
    if GHN.db.tab == "Character" and GHN.frame and GHN.frame:IsShown() then
      GHN:Safe("CharacterChanged",function()GHN:RefreshCharacterStage(true);GHN:Refresh()end)
    end
    if GHN.db.tab == "Gear" and GHN.frame and GHN.frame:IsShown() then
      GHN:Safe("GearChange",function()GHN:Refresh()end)
    end
  elseif (name == "QUEST_LOG_UPDATE" or name == "UPDATE_FACTION" or name == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" or name == "TOYS_UPDATED" or name == "NEW_TOY_ADDED") and GHN.db then
    local current=GHN.db.tab
    if GHN.frame and GHN.frame:IsShown() and
       ((name=="QUEST_LOG_UPDATE" and current=="Quests") or
       ((name=="UPDATE_FACTION" or name=="MAJOR_FACTION_RENOWN_LEVEL_CHANGED") and current=="Reputation") or
       ((name=="TOYS_UPDATED" or name=="NEW_TOY_ADDED") and current=="Collections")) then
      GHN:Safe("Live journal refresh",function()GHN:RefreshProgressPage()end)
    end
  elseif name == "COMPANION_UPDATE" and GHN.db then
    -- Mount collection state changed; cached journal records must refresh.
    GHN.mountCache=nil
    GHN:Safe("CollectionUpdate",function() GHN:CheckCollectedGoal() end)
    if GHN.frame and GHN.frame:IsShown() then
      GHN:Safe("MountCollectionUI",function() GHN:Refresh();GHN:RefreshChooser() end)
    end
  elseif (name == "ADDON_ACTION_BLOCKED" or name == "ADDON_ACTION_FORBIDDEN") and GHN.db then
    local offender = tostring(arg1 or "unknown")
    if offender == ADDON or offender == "GearHunterNavigator" then
      GHN:Log("PROTECTED_UI", name .. ": " .. tostring(arg2 or "unknown function"))
    end
  end
end)

local elapsed=0
local zoneElapsed=0
event:SetScript("OnUpdate",function(_,dt)
  if GHN.db and GHN.db.tab=="Map" and GHN.frame and GHN.frame:IsShown() then
    zoneElapsed=zoneElapsed+dt
    if zoneElapsed>=2 then
      zoneElapsed=0
      GHN:Safe("Auto zone map",function() GHN:UpdateDiscoveryZone(false) end)
    end
  else
    zoneElapsed=0
  end
  if GHN.activeRoute then
    elapsed=elapsed+dt
    if elapsed>=5 then
      elapsed=0
      GHN:Safe("RouteTick",function() GHN:UpdateMeasuredRoute() end)
    end
  else elapsed=0 end
end)

-- Native, click-only launcher. Never controls the player's character.
-- Stored minimap position is cosmetic and does not alter intelligence history.
function GHN:CreateMinimapLauncher()
  if self.minimapButton or not (Minimap and CreateFrame) then return end
  local btn=CreateFrame("Button","GearHunterNavigatorMinimapButton",Minimap)
  btn:SetSize(33,33)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel((Minimap:GetFrameLevel() or 0)+8)
  btn:RegisterForClicks("LeftButtonUp","RightButtonUp")
  btn:RegisterForDrag("LeftButton")
  local border=btn:CreateTexture(nil,"BACKGROUND")
  border:SetAllPoints()
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  local icon=btn:CreateTexture(nil,"ARTWORK")
  icon:SetTexture("Interface\\AddOns\\GearHunterNavigator\\Art\\UIIcons\\shield.tga")
  icon:SetPoint("CENTER",btn,"CENTER",0,0)
  icon:SetSize(21,21)
  local function Reposition()
    if not GHN.db then return end
    local angle=math.rad(tonumber(GHN.db.minimapAngle) or 230)
    local radius=(Minimap:GetWidth() or 140)*.57
    btn:ClearAllPoints()
    btn:SetPoint("CENTER",Minimap,"CENTER",math.cos(angle)*radius,math.sin(angle)*radius)
  end
  local dragging=false
  local function UpdateAngle()
    if not (GHN.db and GetCursorPosition and Minimap:GetCenter()) then return end
    local x,y=GetCursorPosition()
    local mx,my=Minimap:GetCenter()
    local scale=Minimap:GetEffectiveScale() or 1
    if not (x and y and mx and my and scale>0) then return end
    local dx=x/scale-mx
    local dy=y/scale-my
    local a
    if math.atan2 then
      a=math.deg(math.atan2(dy,dx))
    elseif dx==0 then
      a=dy>=0 and 90 or -90
    else
      a=math.deg(math.atan(dy/dx))
      if dx<0 then a=a+180 end
    end
    GHN.db.minimapAngle=a
    Reposition()
  end
  btn:SetScript("OnDragStart",function()dragging=true;UpdateAngle()end)
  btn:SetScript("OnUpdate",function()if dragging then UpdateAngle()end end)
  btn:SetScript("OnDragStop",function()dragging=false;UpdateAngle()end)
  btn:SetScript("OnClick",function(_,button)
    if dragging then return end
    if button=="RightButton" and GHN.ToggleSmartTracker then GHN:ToggleSmartTracker()
    elseif SlashCmdList and SlashCmdList.GHNAV then SlashCmdList.GHNAV() end
  end)
  btn:SetScript("OnEnter",function(f)
    if not GameTooltip then return end
    GameTooltip:SetOwner(f,"ANCHOR_LEFT")
    GameTooltip:AddLine("Gear Hunter Navigator")
    GameTooltip:AddLine("Click: Open or close full-screen Navigator",1,1,1)
    GameTooltip:AddLine("Right-click: Show / hide Smart Tracker",.76,.84,.95)
    GameTooltip:AddLine("Drag: Move around minimap",.76,.84,.95)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide()end end)
  self.minimapButton=btn
  Reposition()
end

SLASH_GHNAV1 = "/ghnav"
SLASH_GHNAV2 = "/gearnav"
SlashCmdList.GHNAV = function()
  if not GHN.frame then GHN:Safe("CreateUI", function() GHN:CreateUI() end) end
  if GHN.frame then
    if GHN.frame:IsShown() then GHN.frame:Hide() else GHN.frame:Show(); GHN:Refresh() end
  else
    print("Gear Hunter Navigator: UI could not load. See saved diagnostics after reload.")
  end
end

function GearHunterNavigator_OnAddonCompartmentClick()
  SlashCmdList.GHNAV()
end
