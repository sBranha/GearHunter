local ADDON, GHN = ...
-- Level-window policy for ALL future Gear Hunter upgrade sources. This only
-- reads Blizzard's local item cache, never queries the web or automates play.
-- "Now" requires an item whose itemMinLevel <= the player's character level;
-- "Soon" is limited to the configured +5 (default) or +10 levels, never beyond the
-- character's expansion level cap. UNKNOWN metadata is NOT a recommendation.
local function SafeNumber(fn)
  if type(fn)~="function" then return nil end
  local ok,value=pcall(fn)
  if not ok then return nil end
  if type(issecretvalue)=="function" then
    local safe,secret=pcall(issecretvalue,value)
    if not safe or secret then return nil end
  end
  if type(value)~="number" or value<1 or value>1000 then return nil end
  return math.floor(value)
end
-- A single limit shared by Navigator, the classic Gear Hunter views, and
-- any observed-source scans. Existing SavedVariables default to +5.
function GHN:GetGearAheadLevels()
  local n=self.db and self.db.gearAheadLevels
  return n==10 and 10 or 5
end
function GHN:SetGearAheadLevels(n)
  if not self.db then return end
  self.db.gearAheadLevels=(n==10) and 10 or 5
  -- Results from the previous window must not remain in a visible list.
  self.gearSelected=nil
  self.gearSelectedData=nil
  self.sourceSelected=nil
  self.gearUpgradePage=1
  self.gearScanDirty=true
  self.journalScan=nil
  self.sourcePage=1
  if self.gearSource=="journal" and self.db.tab=="Gear" and self.ScanJournalUpgrades then
    -- ScanJournalUpgrades cancels a previous job and restores the Journal
    -- selection before restarting with the new level limit.
    self:ScanJournalUpgrades()
  end
  local engine=self.GearEngine
  if engine then
    engine.selected=nil
    engine.selectedSearchRec=nil
    if engine.Refresh then engine:Refresh() end
    if engine.RefreshGearSearch then engine:RefreshGearSearch() end
    if engine.RefreshBossLootHunter then engine:RefreshBossLootHunter() end
  end
  if self.Refresh then self:Refresh() end
end
function GHN:ToggleGearAheadLevels()
  self:SetGearAheadLevels(self:GetGearAheadLevels()==5 and 10 or 5)
end
function GHN:GetGearLevelWindow()
  local current=SafeNumber(function() return UnitLevel("player") end)
  if not current then return nil,nil end
  local expansionCap=SafeNumber(GetMaxLevelForPlayerExpansion)
  local cap=expansionCap or SafeNumber(GetMaxPlayerLevel)
  local top=current+self:GetGearAheadLevels()
  if cap and cap>=current then top=math.min(top,cap) end
  return current,top
end
-- WoW's item cache can return a low/base required level for a Journal
-- item whose ACTUAL tooltip says "Requires Level 25". Both sources are
-- checked and the STRICTER level wins. Never compare item iLvl to a
-- character's level: iLvl and required character level are different.
local function IsSafeNumber(value)
  if type(value)~="number" or value<0 or value>1000 then return false end
  if type(issecretvalue)=="function" then
    local ok,secret=pcall(issecretvalue,value)
    if not ok or secret then return false end
  end
  return true
end
local function RequirementPattern(template)
  if type(template)~="string" or not template:find("%d",1,true) then return nil end
  -- Blizzard's localized ITEM_MIN_LEVEL is a printf-style template.
  -- Escape pattern metacharacters and substitute the numeric placeholder.
  local marker="\1"
  local pattern=template:gsub("%%d",marker)
  pattern=pattern:gsub("([^%w%s\1])","%%%1")
  pattern=pattern:gsub(marker,function() return "(%d+)" end)
  return pattern
end
local requirementPattern=RequirementPattern(ITEM_MIN_LEVEL or "Requires Level %d")
local fallbackPattern="[Rr]equires%s+[Ll]evel%s*(%d+)"
local function TooltipRequirement(data)
  if type(data)~="table" or type(data.lines)~="table" or #data.lines==0 then return nil,false end
  local required=0
  for _,line in ipairs(data.lines) do
    if type(line)=="table" then
      for _,value in pairs({line.leftText,line.rightText}) do
        if type(value)=="string" then
          local safe=not issecretvalue
          if not safe then
            local ok,secret=pcall(issecretvalue,value)
            safe=ok and not secret
          end
          if safe then
            local ok,n=pcall(function()
              local clean=value:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
              local found=requirementPattern and clean:match(requirementPattern) or nil
              if not found then found=clean:match(fallbackPattern) end
              return tonumber(found)
            end)
            if ok and n and n>required and n<=1000 then required=n end
          end
        end
      end
    end
  end
  return required,true
end
function GHN:GetTooltipRequiredGearLevel(itemInfo)
  local tooltipAPI=C_TooltipInfo
  local getLink=tooltipAPI and tooltipAPI.GetHyperlink
  local getID=tooltipAPI and tooltipAPI.GetItemByID
  if type(getLink)~="function" and type(getID)~="function" then return nil,false end
  local player=SafeNumber(function() return UnitLevel("player") end) or 0
  if self.gearTooltipCacheLevel~=player then
    self.gearTooltipCacheLevel=player
    self.gearTooltipCache={}
  end
  local key=type(itemInfo)=="string" and itemInfo or "item:"..tostring(itemInfo)
  local cache=self.gearTooltipCache
  local saved=cache[key]
  if saved then return saved.required,saved.verified end
  if self.gearTooltipBudget and self.gearTooltipBudget<=0 then
    self.gearTooltipDeferred=true
    return nil,false
  end
  if self.gearTooltipBudget then self.gearTooltipBudget=self.gearTooltipBudget-1 end
  local ok,data
  if type(getLink)=="function" then
    ok,data=pcall(getLink,key)
  end
  if (not ok or type(data)~="table") and type(getID)=="function" then
    local id=type(itemInfo)=="number" and itemInfo or tonumber(key:match("item:(%d+)"))
    if id then ok,data=pcall(getID,id) end
  end
  local required,verified=TooltipRequirement(ok and data or nil)
  -- Cache even an unavailable tooltip for this pass. Unknown means HIDDEN,
  -- not "no required level". New item-data events or a rescan clear the cache.
  cache[key]={required=required,verified=verified}
  return required,verified
end
function GHN:BeginGearLevelFilterPass()
  self.gearTooltipBudget=120
  self.gearTooltipDeferred=false
end
function GHN:FinishGearLevelFilterPass()
  self.gearTooltipBudget=nil
  if not self.gearTooltipDeferred or self.gearTooltipRefreshPending then return end
  if not (C_Timer and type(C_Timer.After)=="function") then return end
  self.gearTooltipRefreshPending=true
  C_Timer.After(0.08,function()
    self.gearTooltipRefreshPending=false
    if self.db and self.db.tab=="Gear Hunter" and self.GearEngine
       and self.GearEngine.frame and self.GearEngine.frame:IsShown() then
       self.GearEngine:Refresh()
    end
  end)
end
function GHN:GetRequiredGearLevel(itemInfo)
  if type(itemInfo)~="string" and type(itemInfo)~="number" then return nil end
  local fn=C_Item and C_Item.GetItemInfo
  if type(fn)~="function" then fn=GetItemInfo end
  local required
  if type(fn)=="function" then
    -- GetItemInfo: 1 name, 2 link, 3 quality, 4 item level,
    -- 5 MINIMUM CHARACTER LEVEL (do not use the fourth return).
    local ok,_,__,___,____,minimum=pcall(fn,itemInfo)
    if ok and IsSafeNumber(minimum) then required=math.floor(minimum) end
  end
  local tooltipLevel,verified=self:GetTooltipRequiredGearLevel(itemInfo)
  if verified then
    if not IsSafeNumber(required) then return tooltipLevel end
    -- If a tooltip says level 25 but cached GetItemInfo says 0/1,
    -- suppress it for a level-4 character rather than trusting the low value.
    return math.max(required,tooltipLevel)
  end
  -- Cache metadata alone may understate the requirement of a scaled item.
  -- High known requirements can always be rejected, but never ACCEPT an
  -- unverified low requirement while tooltip data is still loading.
  local _,maximum=self:GetGearLevelWindow()
  if required and maximum and required>maximum then return required end
  if not (C_TooltipInfo and (type(C_TooltipInfo.GetHyperlink)=="function"
       or type(C_TooltipInfo.GetItemByID)=="function")) then
    return required and required>0 and required or nil
  end
  if required==nil and C_Item and C_Item.RequestLoadItemDataByID then
    local id=type(itemInfo)=="number" and itemInfo or tonumber(tostring(itemInfo):match("item:(%d+)"))
    if id then
      self.gearRequestedItemIDs=self.gearRequestedItemIDs or {}
      if not self.gearRequestedItemIDs[id] then
        self.gearRequestedItemIDs[id]=true
        pcall(C_Item.RequestLoadItemDataByID,id)
      end
    end
  end
  return nil
end
function GHN:ClassifyGearLevel(required)
  local player,maximum=self:GetGearLevelWindow()
  if not player then return nil,"unknown-player-level" end
  if type(required)~="number" then return nil,"uncached-required-level" end
  if required>maximum then return nil,"too-high-level" end
  if required>player then return "soon" end
  return "now"
end
function GHN:GearLevelResultLabel(entry)
  if entry.levelGroup=="soon" then
    return "SOON Lv"..tostring(entry.requiredLevel or "?")
  end
  if entry.needsEligibilityCheck then return "NOW: CHECK" end
  return "EQUIP NOW"
end
