local ADDON, GHN = ...
-- Navigator's original, local-only multi-source gear index. It observes actual
-- Blizzard UI data as the player plays. Never claims a complete vendor/quest/
-- crafting database and never invents item IDs, prices, locations or rewards.
local LIMIT=2600
local function call(fn,...)
  if type(fn)~="function" then return nil end
  local ok,a,b,c,d,e,f=pcall(fn,...)
  if ok then return a,b,c,d,e,f end
end
local function itemID(link)
  if type(link)=="number" and link>0 then return math.floor(link) end
  if type(link)=="string" then return tonumber(link:match("item:(%d+)")) end
end
local function itemMetadata(link)
  local id=itemID(link)
  if not id then return nil end
  local fn=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
  local _,_,_,equipLoc,_,classID,subclassID=call(fn,link)
  if type(equipLoc)~="string" or equipLoc=="" then
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID,id) end
    return nil
  end
  if classID~=2 and classID~=4 then return nil end -- weapons or armor, including rings/trinkets
  local name,realLink,quality,level,required,_,_,_,_,icon=call(C_Item and C_Item.GetItemInfo or GetItemInfo,link)
  return {itemID=id,link=realLink or link,name=name or ("Item #"..id),
    equipLoc=equipLoc,classID=classID,subclassID=subclassID,requiredLevel=required,
    itemLevel=call(C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo,link),icon=icon}
end
local function catalog(self)
  if not self.db then return nil end
  if type(self.db.sourceCatalog)~="table" then self.db.sourceCatalog={} end
  return self.db.sourceCatalog
end
local function position()
  if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return end
  local map=call(C_Map.GetBestMapForUnit,"player")
  if type(map)~="number" then return end
  local pos=call(C_Map.GetPlayerMapPosition,map,"player")
  local x,y=pos and call(pos.GetXY,pos)
  if type(x)=="number" and type(y)=="number" and x>0 and y>0 and x<1 and y<1 then
    return map,math.floor(x*1000+.5)/1000,math.floor(y*1000+.5)/1000
  end
end
function GHN:RememberObservedGear(link,source)
  local db=catalog(self)
  if not db or type(source)~="table" or not source.key then return false end
  local meta=itemMetadata(link)
  if not meta then return false end
  local key=tostring(meta.itemID)..":"..tostring(source.key)
  local count=0
  if db[key]==nil then
    for _ in pairs(db) do count=count+1 end
    if count>=LIMIT then return false end
  end
  local old=db[key]
  -- Old records can be stale after an expansion or level squish. Refresh live
  -- item metadata when possible; keep uncertain fields explicitly unknown.
  meta.sourceType=source.type
  meta.sourceName=source.name
  meta.sourceKey=source.key
  meta.mapID=source.mapID
  meta.x=source.x;meta.y=source.y
  meta.questID=source.questID
  meta.recipeID=source.recipeID
  meta.profession=source.profession
  meta.price=source.price
  meta.extendedCost=source.extendedCost
  meta.learned=source.learned
  meta.observed=true
  if old and old.name and meta.name:match("^Item #%d+$") then meta.name=old.name end
  db[key]=meta
  self.gearCatalogDirty=true
  return true
end
function GHN:CaptureVendorGear()
  if not (MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown()) then return nil end
  local num=call(GetMerchantNumItems)
  if type(num)~="number" then return 0 end
  local vendor=call(UnitName,"npc") or call(UnitName,"target") or "Unidentified vendor"
  local map,x,y=position()
  local captured=0
  local keyName=(tostring(vendor):lower():gsub("[^%w]","_"))
  for i=1,math.min(num,300) do
    local link=call(GetMerchantItemLink,i)
    local label,_,price,_,_,_,extended=call(GetMerchantItemInfo,i)
    if link and self:RememberObservedGear(link,{type="Vendor",name=vendor,
      key="vendor:"..keyName..":"..tostring(map or "unknown"),mapID=map,x=x,y=y,
      price=type(price)=="number" and price or nil,extendedCost=extended==true}) then captured=captured+1 end
  end
  return captured
end
function GHN:CaptureQuestGear()
  if not (QuestFrame and QuestFrame.IsShown and QuestFrame:IsShown()) then return nil end
  local questID=call(GetQuestID)
  local title=call(GetTitleText)
  if not title and type(questID)=="number" and C_QuestLog then
    title=call(C_QuestLog.GetTitleForQuestID,questID)
  end
  if type(title)~="string" or title=="" then return 0 end
  local captured=0
  for _,kind in ipairs({"reward","choice"}) do
    local num=kind=="reward" and call(GetNumQuestRewards) or call(GetNumQuestChoices)
    if type(num)=="number" then
      for i=1,math.min(num,35) do
        local link=call(GetQuestItemLink,kind,i)
        if link and self:RememberObservedGear(link,{type="Quest",name=title,
          key="quest:"..tostring(questID or (title:lower():gsub("[^%w]","_"))),questID=questID}) then
          captured=captured+1
        end
      end
    end
  end
  return captured
end
local recipeFrame=CreateFrame("Frame")
local recipes
local function stopRecipes()
  recipes=nil
  recipeFrame:SetScript("OnUpdate",nil)
end
function GHN:CaptureCraftedGear()
  local api=C_TradeSkillUI
  if not api or type(api.GetAllRecipeIDs)~="function" then return nil end
  if not ((ProfessionsFrame and ProfessionsFrame.IsShown and ProfessionsFrame:IsShown()) or
    (TradeSkillFrame and TradeSkillFrame.IsShown and TradeSkillFrame:IsShown())) then return nil end
  local ids=call(api.GetAllRecipeIDs)
  if type(ids)~="table" then return 0 end
  local name=call(api.GetTradeSkillDisplayName) or "Profession"
  -- Bound work per frame to keep huge profession recipe lists responsive.
  recipes={ids=ids,index=1,profession=name,captured=0,elapsed=0}
  recipeFrame:SetScript("OnUpdate",function(_,dt)
    if not recipes or not GHN.db then stopRecipes();return end
    recipes.elapsed=recipes.elapsed+dt
    if recipes.elapsed<.07 then return end
    recipes.elapsed=0
    for _=1,30 do
      local id=recipes.ids[recipes.index]
      recipes.index=recipes.index+1
      if not id then
        GHN.sourceLastStatus="Observed "..recipes.captured.." crafted equipment recipes ("..tostring(recipes.profession)..")"
        stopRecipes();if GHN.RefreshSourceCatalog then GHN:RefreshSourceCatalog() end
        return
      end
      local info=call(api.GetRecipeInfo,id)
      local link=call(api.GetRecipeItemLink,id)
      if not link then
        local schematic=call(api.GetRecipeSchematic,id,false)
        if type(schematic)=="table" and type(schematic.outputItemID)=="number" then
          link="item:"..schematic.outputItemID
        end
      end
      if link and GHN:RememberObservedGear(link,{type="Crafted",name=type(info)=="table" and info.name or ("Recipe #"..id),
        key="recipe:"..id,recipeID=id,profession=recipes.profession,
        learned=type(info)=="table" and info.learned==true}) then recipes.captured=recipes.captured+1 end
    end
  end)
  return #ids
end
function GHN:CaptureOpenGearSources()
  local parts={};local total=0
  for _,entry in ipairs({{"Vendor",self.CaptureVendorGear},{"Quest",self.CaptureQuestGear},{"Crafting",self.CaptureCraftedGear}}) do
    local n=entry[2](self)
    if n~=nil then parts[#parts+1]=entry[1].." "..n;total=total+n end
  end
  if #parts==0 then
    self.sourceLastStatus="Open a vendor, quest reward, or profession window to learn equipment sources."
  else
    self.sourceLastStatus="Observed sources: "..table.concat(parts,", ")
  end
  if self.db and self.db.tab=="Gear Hunter" and self.RefreshSourceCatalog then self:RefreshSourceCatalog() end
  return total
end
function GHN:FindObservedGearUpgrades(search,filter)
  local list,stats={}, {observed=0,unknown=0,ineligible=0,notUpgrade=0}
  local q=tostring(search or ""):lower()
  local f=filter or "All"
  for _,item in pairs(catalog(self) or {}) do
    stats.observed=stats.observed+1
    if (f=="All" or item.sourceType==f) and
      (q=="" or (tostring(item.name).." "..tostring(item.sourceName).." "..tostring(item.itemID)):lower():find(q,1,true)) then
      local link=item.link or (item.itemID and "item:"..item.itemID)
      local rec,reason=self:EvaluateExternalLoot(link)
      if rec then
        for key,val in pairs(item) do
          if rec[key]==nil then rec[key]=val end
        end
        rec.origin="observed"
        rec.source=item.sourceType..": "..tostring(item.sourceName or "unknown")
        list[#list+1]=rec
      elseif reason=="uncached-required-level" or reason=="uncached-link" or reason=="uncached-type" or reason=="uncached-level" or reason=="uncached-equipped" then
        stats.unknown=stats.unknown+1
        if item.itemID and C_Item and C_Item.RequestLoadItemDataByID then
          pcall(C_Item.RequestLoadItemDataByID,item.itemID)
        end
      elseif reason=="too-high-level" or reason=="armorMismatch" or reason=="restricted" then stats.ineligible=stats.ineligible+1
      else stats.notUpgrade=stats.notUpgrade+1 end
    end
  end
  table.sort(list,function(a,b)
    if a.levelGroup~=b.levelGroup then return a.levelGroup=="now" end
    if a.delta~=b.delta then return a.delta>b.delta end
    return (a.name or "")<(b.name or "")
  end)
  return list,stats
end
function GHN:TryObservedWaypoint(r)
  if not r or not r.mapID or not r.x or not r.y then return false,"No observed map coordinates for this source." end
  if InCombatLockdown and InCombatLockdown() then return false,"Unavailable in combat." end
  if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
    return false,"Waypoint API unavailable." end
  if C_Map.CanSetUserWaypointOnMap and call(C_Map.CanSetUserWaypointOnMap,r.mapID)==false then
    return false,"Cannot place a waypoint on this map." end
  local ok=pcall(function()
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(r.mapID,r.x,r.y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
  end)
  return ok,ok and "Observed vendor location waypoint set; inventory may change." or "Waypoint failed."
end
local event=CreateFrame("Frame")
for _,name in ipairs({"MERCHANT_SHOW","MERCHANT_UPDATE","QUEST_COMPLETE","QUEST_ITEM_UPDATE",
  "TRADE_SKILL_SHOW","TRADE_SKILL_LIST_UPDATE","ITEM_DATA_LOAD_RESULT","GET_ITEM_INFO_RECEIVED"}) do
  pcall(event.RegisterEvent,event,name)
end
event:SetScript("OnEvent",function(_,name)
  if not GHN.db then return end
  if name=="MERCHANT_SHOW" or name=="MERCHANT_UPDATE" then GHN:CaptureVendorGear()
  elseif name=="QUEST_COMPLETE" or name=="QUEST_ITEM_UPDATE" then GHN:CaptureQuestGear()
  elseif name=="TRADE_SKILL_SHOW" then GHN:CaptureCraftedGear()
  elseif (name=="ITEM_DATA_LOAD_RESULT" or name=="GET_ITEM_INFO_RECEIVED") and GHN.db.tab=="Gear Hunter" and
    GHN.frame and GHN.frame:IsShown() and not GHN._refreshingSources then
    -- Caching events can burst; simply flag dirtiness until the player opens a tab.
    GHN.gearCatalogDirty=true
  end
end)
