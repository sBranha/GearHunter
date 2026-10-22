local ADDON, GHN = ...
-- Compact, read-only in-game coach. The map database contains possible
-- locations; neither this tracker nor the addon detects live rare spawns.
local MODES = {"Auto", "Mount", "Quest", "Gear", "Discoveries"}
local function safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
end
local function button(parent, title, width, callback)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 25)
  b:SetText(title)
  b:SetScript("OnClick", callback)
  return b
end
local function font(parent, size, color)
  local f = parent:CreateFontString(nil, "OVERLAY", size == "large" and "GameFontNormal" or "GameFontNormalSmall")
  f:SetJustifyH("LEFT")
  f:SetJustifyV("TOP")
  f:SetTextColor(unpack(color or {0.86, 0.93, 1}))
  return f
end
local function coordinates(mapID)
  if not (mapID and C_Map and C_Map.GetPlayerMapPosition) then return nil end
  local ok, x, y = pcall(function()
    local p = C_Map.GetPlayerMapPosition(mapID, "player")
    if p then return p:GetXY() end
  end)
  if not ok or type(x) ~= "number" or type(y) ~= "number" then return nil end
  if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then return nil end
  if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
  return x * 100, y * 100
end
function GHN:SmartLocalSummary()
  local mapID = self:CurrentDiscoveryMapID()
  local zone = self:DiscoveryMapName(mapID)
  local px, py = coordinates(mapID)
  local nearest, best, count
  count = 0
  if mapID then
    for _, r in ipairs(self:GetZoneDiscoveries(mapID)) do
      if self:DiscoveryTypeVisible(r.category) and not self:DiscoveryVisited(r) then
        count = count + 1
        if px and py then
          local distance = (px - r.x)^2 + (py - r.y)^2
          if not best or distance < best then nearest, best = r, distance end
        elseif not nearest then nearest = r end
      end
    end
  end
  return {zone=zone, mapID=mapID, count=count, nearest=nearest}
end
local function mountGoal(self)
  local profile = self:Profile()
  local id = (profile and profile.activeMountID) or self.db.mountID
  if not (id and C_MountJournal and C_MountJournal.GetMountInfoByID) then return nil end
  local ok, name, _, icon, _, _, sourceType, _, _, _, _, collected = pcall(C_MountJournal.GetMountInfoByID, id)
  if not ok or not name or collected == true then return nil end
  local source, description
  if C_MountJournal.GetMountInfoExtraByID then
    local good, _, desc, src = pcall(C_MountJournal.GetMountInfoExtraByID, id)
    if good then source, description = src, desc end
  end
  local mount = {id=id, name=name, icon=icon, sourceType=sourceType, source=source, description=description, collected=false}
  local guide = self:GetMountGuide(name, mount)
  if not guide then return nil end
  local done = self:GuideSteps(guide)
  local step
  for i=1,#(guide.steps or {}) do if not done[i] then step=i; break end end
  local message = step and guide.steps[step] or "Checklist finished. Confirm collection in your Mount Journal."
  return {kind="Mount", title=name, step=step, guide=guide,
    instruction=(step and ("Step "..step..": ") or "")..message,
    help=(guide.tips and (guide.tips[step or 1] or guide.tips[2])) or
      "Use the Mount Journal source to confirm prerequisites; no additional route is verified."}
end
local function questGoal(self)
  local quests = self:ReadActiveQuests("")
  local id = self.db.smartQuestID
  if not id and C_SuperTrack then id = safe(C_SuperTrack.GetSuperTrackedQuestID) end
  local chosen
  for _,q in ipairs(quests or {}) do
    if id and q.id==id then chosen=q; break end
  end
  if not chosen and self.db.smartTrackerMode=="Quest" then chosen=quests and quests[1] end
  if not chosen then return nil end
  return {kind="Quest", title=chosen.name, quest=chosen,
    instruction=self:QuestHelp(chosen),
    help="Quest guidance is based on your live journal objectives. Track this quest and follow Blizzard's map marker; if it is missing, review your Quest Log."}
end
local function gearGoal(self)
  local profile = self:Profile()
  local item = profile and profile.gearTarget
  if not item then return nil end
  return {kind="Gear", title=tostring(item.name or "Selected item"),
    instruction="Possible source: "..tostring(item.source or "Not verified")..". Open Gear to review item eligibility and the in-game source.",
    help="Gear targets are suggestions, not owned items or guaranteed upgrades. The game has not supplied a verified travel waypoint for this source."}
end
function GHN:SmartGoal(summary)
  local mode = self.db.smartTrackerMode or "Auto"
  local goal
  if mode=="Mount" then goal=mountGoal(self)
  elseif mode=="Quest" then goal=questGoal(self)
  elseif mode=="Gear" then goal=gearGoal(self)
  elseif mode=="Discoveries" then goal=nil
  else
    -- Explicitly selected mount goals outrank automatic journal suggestions.
    local profile=self:Profile()
    if profile and profile.activeMountID then goal=mountGoal(self) end
    goal=goal or questGoal(self) or gearGoal(self)
  end
  if goal then return goal end
  local r=summary.nearest
  if r then
    return {kind="Discovery", title=r.name, record=r,
      instruction=string.format("Known %s location at %.1f, %.1f. This is NOT a live spawn report.",
        tostring(r.category or "discovery"), r.x, r.y),
      help="Use WAYPOINT for this documented point. Spawn, phase, and collection availability are not confirmed."}
  end
  return {kind="None", title="Explore "..summary.zone,
    instruction=summary.mapID and "No unvisited, enabled discovery points are recorded for this zone." or "Zone map is unavailable. Move into a mapped area.",
    help="Navigator can guide from bundled discoveries, a selected mount, your active quests, or a tracked gear goal. It cannot fetch online data while WoW is running."}
end
function GHN:UpdateSmartTracker()
  local f=self.smartTracker
  if not (f and self.db) then return end
  local enabled=self.db.smartTrackerEnabled~=false
  f:SetShown(enabled and not (self.frame and self.frame:IsShown()))
  if not enabled then return end
  local ok,summary=pcall(self.SmartLocalSummary,self)
  if not ok or not summary then
    self:Log("SMART_TRACKER", "Unable to read current zone")
    return
  end
  local good,goal=pcall(self.SmartGoal,self,summary)
  if not good then self:Log("SMART_TRACKER",tostring(goal));return end
  self.smartCurrentGoal=goal
  f.zone:SetText(summary.zone.."  |  "..summary.count.." known unvisited point(s)")
  f.title:SetText(goal.kind..": "..goal.title)
  f.detail:SetText(self.smartHelpVisible and ("HELP: "..goal.help) or goal.instruction)
  f.mode:SetText("Focus: "..(self.db.smartTrackerMode or "Auto"))
  f.action:SetText(goal.kind=="Discovery" and "WAYPOINT" or goal.kind=="Mount" and
    (goal.guide and goal.guide.verified and goal.guide.mapID and "WAYPOINT" or "OPEN GUIDE") or
    goal.kind=="Quest" and "TRACK QUEST" or goal.kind=="Gear" and "OPEN GEAR" or "OPEN MAP")
  f.next:SetText(goal.kind=="Mount" and goal.step and "MARK STEP DONE" or "OPEN NAVIGATOR")
end
function GHN:SmartPrimaryAction()
  local g=self.smartCurrentGoal
  if not g then return end
  local ok,msg
  if g.kind=="Discovery" then ok,msg=self:SetDiscoveryWaypoint(g.record)
  elseif g.kind=="Mount" then
    if g.guide.verified and g.guide.mapID and g.guide.x and g.guide.y then
      ok,msg=self:TakeMeThere(g.guide)
    else self:Select("Mounts");self.frame:Show();return end
  elseif g.kind=="Quest" then ok,msg=self:TrackActiveQuest(g.quest.id)
  elseif g.kind=="Gear" then self:Select("Gear");self.frame:Show();return
  else self:Select("Map");self.frame:Show();return end
  self.smartHelpVisible=true
  if self.smartTracker and msg then self.smartTracker.detail:SetText(msg) end
  if ok==false then self:Log("SMART_TRACKER",msg or "Action was unavailable") end
end
function GHN:SmartNextAction()
  local g=self.smartCurrentGoal
  if g and g.kind=="Mount" and g.step then
    self:SetGuideStep(g.guide,g.step)
    self.smartHelpVisible=false
    self:UpdateSmartTracker()
  else
    self:Select(g and g.kind=="Quest" and "Quests" or g and g.kind=="Gear" and "Gear" or "Map")
    self.frame:Show()
  end
end
function GHN:ToggleSmartTracker()
  if not self.db then return end
  self.db.smartTrackerEnabled=not (self.db.smartTrackerEnabled~=false)
  self:UpdateSmartTracker()
end
function GHN:CreateSmartTracker()
  if self.smartTracker or not self.db or not UIParent then return end
  if self.db.smartTrackerEnabled==nil then self.db.smartTrackerEnabled=true end
  local f=CreateFrame("Frame","GearHunterNavigatorSmartTracker",UIParent,"BackdropTemplate")
  f:SetSize(365,205);f:SetFrameStrata("MEDIUM");f:SetClampedToScreen(true)
  f:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=14,insets={left=3,right=3,top=3,bottom=3}})
  f:SetBackdropColor(.025,.045,.09,.97)
  f:SetBackdropBorderColor(.65,.51,.24,1)
  f:SetPoint("CENTER",UIParent,"CENTER",tonumber(self.db.smartTrackerX) or 0,tonumber(self.db.smartTrackerY) or -100)
  f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart",function(w) if not (InCombatLockdown and InCombatLockdown()) then w:StartMoving() end end)
  f:SetScript("OnDragStop",function(w)
    w:StopMovingOrSizing()
    local cx,cy=w:GetCenter();local px,py=UIParent:GetCenter()
    if cx and cy and px and py then
      GHN.db.smartTrackerX=cx-px;GHN.db.smartTrackerY=cy-py
    end
    w:ClearAllPoints()
    w:SetPoint("CENTER",UIParent,"CENTER",GHN.db.smartTrackerX or 0,GHN.db.smartTrackerY or -100)
  end)
  local top=font(f,"large",{1,.82,.4});top:SetPoint("TOPLEFT",12,-11);top:SetText("Gear Hunter | Smart Tracker")
  local hide=button(f,"X",25,function()GHN:ToggleSmartTracker()end)
  hide:SetPoint("TOPRIGHT",-9,-7)
  local mode=button(f,"Focus: Auto",145,function()
    local selected=GHN.db.smartTrackerMode or "Auto"
    for i,v in ipairs(MODES) do if v==selected then GHN.db.smartTrackerMode=MODES[i%#MODES+1];break end end
    GHN.smartHelpVisible=false;GHN:UpdateSmartTracker()
  end)
  mode:SetPoint("TOPRIGHT",-38,-7);f.mode=mode
  f.zone=font(f);f.zone:SetPoint("TOPLEFT",12,-42);f.zone:SetSize(340,19)
  f.title=font(f,"large",{1,.82,.4});f.title:SetPoint("TOPLEFT",12,-62);f.title:SetSize(340,20)
  f.detail=font(f);f.detail:SetPoint("TOPLEFT",12,-88);f.detail:SetSize(341,67)
  f.action=button(f,"WAYPOINT",107,function()GHN:SmartPrimaryAction()end)
  f.action:SetPoint("BOTTOMLEFT",10,10)
  f.next=button(f,"OPEN NAVIGATOR",141,function()GHN:SmartNextAction()end)
  f.next:SetPoint("LEFT",f.action,"RIGHT",2,0)
  local help=button(f,"GET HELP",97,function()
    GHN.smartHelpVisible=not GHN.smartHelpVisible;GHN:UpdateSmartTracker()
  end)
  help:SetPoint("LEFT",f.next,"RIGHT",2,0)
  self.smartTracker=f
  if self.frame and self.frame.HookScript then
    self.frame:HookScript("OnShow",function()GHN:UpdateSmartTracker()end)
    self.frame:HookScript("OnHide",function()GHN:UpdateSmartTracker()end)
  end
  self:UpdateSmartTracker()
end
SLASH_GHNTRACK1="/ghtrack"
SlashCmdList.GHNTRACK=function()GHN:ToggleSmartTracker()end
local watcher=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","ZONE_CHANGED","ZONE_CHANGED_INDOORS","ZONE_CHANGED_NEW_AREA","QUEST_LOG_UPDATE","SUPER_TRACKING_CHANGED","COMPANION_UPDATE"}) do
  watcher:RegisterEvent(event)
end
watcher:SetScript("OnEvent",function(_,event)
  if event=="PLAYER_LOGIN" then
    GHN:Safe("SmartTracker startup",function()GHN:CreateSmartTracker()end)
  elseif GHN.db then
    GHN:Safe("SmartTracker refresh",function()GHN:UpdateSmartTracker()end)
  end
end)
local elapsed=0
watcher:SetScript("OnUpdate",function(_,dt)
  if not (GHN.smartTracker and GHN.db and GHN.db.smartTrackerEnabled~=false) then return end
  elapsed=elapsed+dt
  if elapsed>=12 then elapsed=0;GHN:Safe("SmartTracker position",function()GHN:UpdateSmartTracker()end) end
end)
