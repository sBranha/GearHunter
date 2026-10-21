local ADDON, GHN = ...
-- Navigator Intelligence v1: deterministic local, opt-in-by-use history.
-- No web requests, gameplay automation, model training or unverified crowdsourcing.
local MAX_HISTORY = 35
local MAX_ROUTE_SECONDS = 7200

local function Now()
  return (time and time()) or 0
end
local function Clock()
  return (GetTime and GetTime()) or 0
end
local function Ensure(t, key)
  if type(t[key]) ~= "table" then t[key] = {} end
  return t[key]
end
local function CanReadMount(id)
  if not (id and C_MountJournal and C_MountJournal.GetMountInfoByID) then return nil end
  local ok, name, _, _, _, _, _, _, _, _, _, collected = pcall(C_MountJournal.GetMountInfoByID, id)
  if not ok or not name then return nil end
  return collected == true
end

function GHN:GetCharacterKey()
  if UnitGUID then
    local ok, guid = pcall(UnitGUID,"player")
    if ok and type(guid) == "string" and guid ~= "" then return guid end
  end
  local name = UnitName and UnitName("player") or "Unknown"
  local realm = GetRealmName and GetRealmName() or "Unknown"
  return tostring(name).."-"..tostring(realm)
end
function GHN:Profile()
  if not self.db then return nil end
  local intelligence = Ensure(self.db, "intelligence")
  if intelligence.enabled == nil then intelligence.enabled = true end
  intelligence.version = 1
  local characters = Ensure(intelligence, "characters")
  local key = self:GetCharacterKey()
  local p = Ensure(characters, key)
  if type(p.priority) ~= "string" then p.priority = "Auto" end
  p.steps = Ensure(p, "steps")
  p.goals = Ensure(p, "goals")
  p.attempts = Ensure(p, "attempts")
  p.routes = Ensure(p, "routes")
  p.history = Ensure(p, "history")
  p.collected = Ensure(p, "collected")
  return p
end
function GHN:IsLearningEnabled()
  return self.db and self:Profile() and self.db.intelligence.enabled ~= false
end
function GHN:Remember(kind, message)
  if not self:IsLearningEnabled() then return end
  local p=self:Profile()
  table.insert(p.history,1,{at=Now(),kind=tostring(kind),message=tostring(message)})
  while #p.history > MAX_HISTORY do table.remove(p.history) end
end
function GHN:ChooseMount(id, name)
  if not self.db then return end
  self.db.mountID=id
  if not self:IsLearningEnabled() then return end
  local p=self:Profile()
  local key=tostring(id)
  local goal=Ensure(p.goals,key)
  goal.name=name or goal.name or "Mount"
  goal.selectedAt=Now()
  goal.selected=(tonumber(goal.selected) or 0)+1
  p.activeMountID=id
  self:Remember("GOAL","Selected "..goal.name)
end
function GHN:GuideSteps(guide)
  if not guide then return {} end
  local p=self:Profile()
  if not p then return self.db.steps[guide.title] or {} end
  local steps=p.steps[guide.title]
  if type(steps) ~= "table" then
    -- Retain checklist progress from the initial 0.1.0 test as a starting point.
    steps={}
    if type(self.db.steps[guide.title]) == "table" then
      for k,v in pairs(self.db.steps[guide.title]) do steps[k] = v end
      -- Old 0.1.0 checklists were account-wide; consume migration once so a reset stays reset.
      self.db.steps[guide.title]=nil
    end
    p.steps[guide.title]=steps
  end
  return steps
end
function GHN:SetGuideStep(guide, index)
  if not guide or not guide.steps[index] then return end
  local steps=self:GuideSteps(guide)
  steps[index]=not steps[index]
  if self:IsLearningEnabled() then
    self:Remember("STEP",guide.title.." step "..index..(steps[index] and " completed" or " reopened"))
  end
end
function GHN:RecordMountAttempt(guide)
  if not guide or not self.db then return false end
  if not self:IsLearningEnabled() then return false end
  local p=self:Profile()
  local key=tostring(self.db.mountID or guide.title)
  local a=Ensure(p.attempts,key)
  a.name=guide.title
  a.count=(tonumber(a.count) or 0)+1
  a.lastAt=Now()
  self:Remember("ATTEMPT",guide.title.." attempt #"..a.count.." (manually recorded)")
  return true
end
function GHN:SetPriority(priority)
  if not self:IsLearningEnabled() then return end
  if priority ~= "Auto" and priority ~= "Mounts" and priority ~= "Gear" and priority ~= "Leveling" and priority ~= "Rares" then return end
  self:Profile().priority=priority
  self:Remember("PREFERENCE", "Priority set to "..priority)
end
function GHN:ToggleLearning()
  if not self.db then return end
  self:Profile()
  self.db.intelligence.enabled = not self.db.intelligence.enabled
  -- Pausing also discards in-flight measurement; never store a fabricated duration.
  self.activeRoute=nil
  self:Log("LEARNING", self.db.intelligence.enabled and "Local learning resumed" or "Local learning paused")
end
function GHN:ResetMyLearning()
  if not self.db then return end
  local p=self:Profile()
  if not p then return end
  self.db.intelligence.characters[self:GetCharacterKey()] = nil
  self.activeRoute=nil
  self:Profile()
  self:Log("LEARNING", "This character's Navigator Intelligence history cleared")
end
function GHN:CheckCollectedGoal()
  if not self:IsLearningEnabled() then return end
  local p=self:Profile()
  if not p then return end
  for key, goal in pairs(p.goals) do
    local id=tonumber(key)
    local owned=CanReadMount(id)
    if owned ~= nil then
      -- First observation is a baseline, not evidence of a new acquisition.
      if p.collected[key] == false and owned then
        self:Remember("COLLECTED",tostring(goal.name or "Mount").." collected (journal confirmed)")
      end
      p.collected[key]=owned
    end
  end
end
function GHN:StartMeasuredRoute(guide)
  if not guide or not self:IsLearningEnabled() then return end
  self.activeRoute={title=guide.title,mapID=guide.mapID,x=guide.x,y=guide.y,
    mountID=self.db.mountID,started=Clock(),startEpoch=Now(),zoneSeen=false}
  self:Remember("ROUTE", "Started route toward "..guide.title)
end
local function IsMapOrChild(current, destination)
  if not (current and destination and C_Map and C_Map.GetMapInfo) then return false end
  for _=1,8 do
    if current==destination then return true end
    local ok, info=pcall(C_Map.GetMapInfo,current)
    if not ok or not info or not info.parentMapID or info.parentMapID==0 or info.parentMapID==current then break end
    current=info.parentMapID
  end
  return false
end
function GHN:UpdateMeasuredRoute()
  local r=self.activeRoute
  if not r or not self:IsLearningEnabled() then return end
  local seconds=Clock()-r.started
  if seconds < 0 or seconds > MAX_ROUTE_SECONDS then
    self.activeRoute=nil
    self:Remember("ROUTE", "Route stopped without confirmed arrival")
    return
  end
  local mapID
  if C_Map and C_Map.GetBestMapForUnit then
    local ok, id=pcall(C_Map.GetBestMapForUnit,"player")
    if ok then mapID=id end
  end
  if not IsMapOrChild(mapID,r.mapID) then return end
  if not r.zoneSeen then
    r.zoneSeen=true
    self:Remember("ROUTE", "Entered destination zone for "..r.title)
  end
  if not (C_Map and C_Map.GetPlayerMapPosition and r.x and r.y) then return end
  -- If the game hides position or makes its values inaccessible, do not guess.
  local ok, near=pcall(function()
    local pos=C_Map.GetPlayerMapPosition(r.mapID,"player")
    if not pos then return false end
    local x,y=pos:GetXY()
    if type(x) ~= "number" or type(y) ~= "number" then return false end
    local dx,dy=x-r.x,y-r.y
    return dx*dx+dy*dy <= 0.0049 -- <= 7% of normalized map width/height
  end)
  if not ok or not near then return end
  local p=self:Profile()
  local rkey=tostring(r.mapID)..":"..r.title
  local stats=Ensure(p.routes,rkey)
  stats.name=r.title
  stats.mapID=r.mapID
  stats.count=(tonumber(stats.count) or 0)+1
  stats.totalSeconds=(tonumber(stats.totalSeconds) or 0)+math.floor(seconds)
  stats.fastestSeconds=math.min(tonumber(stats.fastestSeconds) or 999999,math.floor(seconds))
  stats.lastSeconds=math.floor(seconds)
  self.activeRoute=nil
  self:Remember("ROUTE", "Arrived near "..r.title.." waypoint in "..math.floor(seconds).." sec")
  self:Log("LEARNING", "Route arrival measured for "..r.title)
  if self.Refresh then self:Refresh() end
end
function GHN:GetIntelligenceSummary()
  local p=self:Profile()
  if not p then return {enabled=false,priority="Auto",history={},routes=0,attempts=0,goals=0} end
  local nr, na, ng=0,0,0
  for _,v in pairs(p.routes) do nr=nr+(tonumber(v.count) or 0) end
  for _,v in pairs(p.attempts) do na=na+(tonumber(v.count) or 0) end
  for _ in pairs(p.goals) do ng=ng+1 end
  local last=p.history[1]
  return {enabled=self:IsLearningEnabled(),priority=p.priority or "Auto",history=p.history,
    routes=nr,attempts=na,goals=ng,last=last,active=self.activeRoute ~= nil}
end
function GHN:GetSmartRecommendation()
  local p=self:Profile()
  if not p or not self:IsLearningEnabled() then return nil end
  local c=self:GetCharacterSummary()
  local focus=p.priority or "Auto"
  local id=p.activeMountID or self.db.mountID
  local name
  local owned=false
  if id and C_MountJournal and C_MountJournal.GetMountInfoByID then
    local ok, n, _,_,_,_,_,_,_,_,_,o=pcall(C_MountJournal.GetMountInfoByID,id)
    if ok then name=n; owned=o==true end
  end
  local journalMount
  if id and name then
    local src
    if C_MountJournal and C_MountJournal.GetMountInfoExtraByID then
      local ok,_,_,source=pcall(C_MountJournal.GetMountInfoExtraByID,id)
      if ok then src=source end
    end
    journalMount={id=id,name=name,source=src,collected=owned}
  end
  local guide=name and self:GetMountGuide(name,journalMount)
  if (focus=="Mounts" or focus=="Auto" and id) and name and not owned then
    if guide then
      local steps=self:GuideSteps(guide)
      local nextStep
      for i=1,#guide.steps do if not steps[i] then nextStep=i; break end end
      local a=p.attempts[tostring(id)]
      local tries=a and (tonumber(a.count) or 0) or 0
      local route=p.routes[tostring(guide.mapID)..":"..guide.title]
      local measured=""
      if route and (tonumber(route.count) or 0)>0 then
        local n=tonumber(route.count)
        local average=math.floor(((tonumber(route.totalSeconds) or 0)/n)/60 + 0.5)
        measured=" Your observed trip to the waypoint averaged about "..average.." min across "..n.." completed route(s)."
      end
      if nextStep then
        return "Continue "..name.." — step "..nextStep,
          guide.steps[nextStep].."  |  "..tries.." attempts manually logged."..measured..
          (guide.verified and " This follows your saved detailed guide, not a guaranteed fastest route." or
            " This is a journal-based checklist; exact routes must be verified in game.")
      end
      return "Review your "..name.." attempt",
        "All checklist steps are marked. Confirm your journal/loot and log the attempt if needed; checklist completion does not mean the mount dropped."
    end
    return "Continue your saved mount goal: "..name,
      "Your preference is remembered, but there is not yet a verified step-by-step guide for this mount. Use the journal source information."
  end
  if focus=="Leveling" then
    return "Follow a quest chain appropriate for level "..c.level,
      "Leveling is your selected priority. Route ranking will require verified guide data; Navigator does not invent the fastest path."
  end
  if (focus=="Gear" or focus=="Auto") and p.gearTarget then
    local goal=p.gearTarget
    return "Tracked gear goal: "..tostring(goal.name or "Item"),
      "Potential source: "..tostring(goal.source or "Unknown").." ("..tostring(goal.kind or "Journal").."). Open Gear to compare equipped stats and view the source in WoW's Adventure Guide. Drops and eligibility are not guaranteed."
  end
  if focus=="Gear" then
    return "Search for possible gear improvements",
      "Gear is your priority. Equipped item level: "..string.format("%.1f",c.ilevel)..". Open Gear to scan your bags or the Encounter Journal; item level is not a full best-in-slot rating."
  end
  return nil -- Fall back to the safe, level-aware baseline recommendations.
end
