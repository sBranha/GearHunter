local ADDON, GHN = ...
-- Our independent Navigator explorer, reading our bundled MapHub location data.
-- Known spawn points are not live detection. Unknown means unknown (not uncollected).
local function zoneKey(name)
  if type(name)~="string" then return nil end
  return name:lower():gsub("[^%w]","")
end
local zoneAliases={azuremystisland="azuremystisle",bloodmystisland="bloodmystisle"}
local function rareDataFor(mapID,name)
  local data=GHN.WorldRareLocations
  if type(data)~="table" then return nil end
  local key=zoneKey(name)
  return data[mapID] or data[tostring(mapID)] or (key and (data[key] or data[zoneAliases[key]]))
end
function GHN:CurrentDiscoveryMapID()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local ok,id=pcall(C_Map.GetBestMapForUnit,"player")
  if ok and type(id)=="number" then return id end
end
function GHN:DiscoveryMapName(id)
  if id and C_Map and C_Map.GetMapInfo then
    local ok,info=pcall(C_Map.GetMapInfo,id)
    if ok and info and info.name then return info.name end
  end
  return id and ("Map "..id) or "Zone unavailable"
end
local mapIndex
local rareIndex={}
local function rebuild()
  mapIndex={}
  rareIndex={}
  for _,r in ipairs(GHN.CuratedLocations or {}) do
    if type(r.mapID)=="number" and type(r.x)=="number" and type(r.y)=="number"
      and r.x>=0 and r.x<=100 and r.y>=0 and r.y<=100 then
      local b=mapIndex[r.mapID]
      if not b then b={};mapIndex[r.mapID]=b end
      b[#b+1]=r
    end
  end
end
function GHN:GetZoneDiscoveries(mapID)
  if type(mapID)~="number" then return {} end
  if not mapIndex then rebuild() end
  local items,seen={},{}
  local function push(r)
    if r and type(r.name)=="string" and type(r.x)=="number" and type(r.y)=="number"
      and r.x>=0 and r.x<=100 and r.y>=0 and r.y<=100 then
      local key=tostring(self:DiscoveryCategoryKey(r.category) or r.category or "")..":"..(r.name:lower():gsub("[^%w]",""))..":"..math.floor(r.x*10+.5)..":"..math.floor(r.y*10+.5)
      if not seen[key] then seen[key]=true;items[#items+1]=r end
    end
  end
  for _,r in ipairs(mapIndex[mapID] or {}) do push(r) end
  local data=rareDataFor(mapID,self:DiscoveryMapName(mapID))
  if not rareIndex[mapID] then
    local records={}
    for _,r in ipairs(type(data)=="table" and data or {}) do
      local npc,x,y,name=r[1],r[2],r[3],r[4]
      if type(npc)=="number" and type(x)=="number" and type(y)=="number"
        and x>=0 and x<=100 and y>=0 and y<=100 and type(name)=="string" then
        records[#records+1]={
          id=("rare:%d:%d:%.2f:%.2f"):format(mapID,npc,x,y),
          mapID=mapID,x=x,y=y,name=name,category="Rare",npcID=npc,
          source="AllTheThings (MIT; via MapHub)",
          description="Documented possible spawn. Presence, phase and availability are not confirmed."
        }
      end
    end
    rareIndex[mapID]=records
  end
  for _,r in ipairs(rareIndex[mapID]) do push(r) end
  return items
end
function GHN:DiscoveryKey(r)
  return tostring(r.id or (r.mapID..":"..r.category..":"..r.name..":"..r.x..":"..r.y))
end
function GHN:DiscoveryVisited(r)
  if not r or not self.db then return false end
  local profile=self:Profile()
  if profile and profile.visitedDiscoveries and profile.visitedDiscoveries[self:DiscoveryKey(r)] then return true end
  -- A completed quest is evidence only when the data record contains a verified quest ID.
  if type(r.questID)=="number" and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
    local ok,done=pcall(C_QuestLog.IsQuestFlaggedCompleted,r.questID)
    if ok and done==true then return true end
  end
  return false
end
function GHN:ToggleDiscoveryVisited(r)
  if not r then return end
  local p=self:Profile()
  if not p then return end
  p.visitedDiscoveries=p.visitedDiscoveries or {}
  local key=self:DiscoveryKey(r)
  p.visitedDiscoveries[key]=not p.visitedDiscoveries[key] or nil
end
local function playerPosition(mapID)
  if not (C_Map and C_Map.GetPlayerMapPosition) then return end
  local ok,x,y=pcall(function()
    local pos=C_Map.GetPlayerMapPosition(mapID,"player")
    if not pos then return nil,nil end
    return pos:GetXY()
  end)
  if ok and type(x)=="number" and type(y)=="number" then return x*100,y*100 end
end
function GHN:FilteredDiscoveries(mapID)
  local q=(self.discoveryQuery or ""):lower()
  local category=self.discoveryCategory or "All"
  local hide=self.discoveryHideVisited==true
  local filtered={}
  local px,py=playerPosition(mapID)
  for _,r in ipairs(self:GetZoneDiscoveries(mapID)) do
    if (category=="All" or self:DiscoveryCategoryKey(r.category)==self:DiscoveryCategoryKey(category))
      and self:DiscoveryTypeVisible(r.category)
      and (not hide or not self:DiscoveryVisited(r))
      and (q=="" or (r.name.." "..(r.description or "").." "..(r.source or "")):lower():find(q,1,true)) then
      r._distance=px and ((px-r.x)^2+(py-r.y)^2) or nil
      filtered[#filtered+1]=r
    end
  end
  table.sort(filtered,function(a,b)
    if a._distance and b._distance and math.abs(a._distance-b._distance)>.001 then return a._distance<b._distance end
    local ac,bc=tostring(a.category or ""),tostring(b.category or "")
    if ac~=bc then return ac<bc end
    return tostring(a.name or "")<tostring(b.name or "")
  end)
  return filtered
end
function GHN:SetDiscoveryWaypoint(r)
  if not r or type(r.mapID)~="number" or type(r.x)~="number" or type(r.y)~="number"
    or r.x<0 or r.x>100 or r.y<0 or r.y>100 then
    return false,"Choose a valid known map location first."
  end
  if InCombatLockdown and InCombatLockdown() then return false,"Unavailable in combat." end
  if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
    return false,"World map waypoint API is unavailable." end
  if C_Map.CanSetUserWaypointOnMap then
    local ok,can=pcall(C_Map.CanSetUserWaypointOnMap,r.mapID)
    if not ok or not can then return false,"This map does not permit user waypoints." end
  end
  local ok=pcall(function()
    local result=C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(r.mapID,r.x/100,r.y/100))
    if result==false then error("SetUserWaypoint returned false")end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
  end)
  return ok,ok and "Known location waypoint set. Spawn not confirmed." or "Unable to set waypoint."
end
function GHN:BestLocalDiscovery()
  local id=self:CurrentDiscoveryMapID()
  if not id then return nil end
  local found=self:FilteredDiscoveries(id)
  for _,r in ipairs(found) do if not self:DiscoveryVisited(r) then return r end end
end
