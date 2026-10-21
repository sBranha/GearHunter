local ADDON, GHN = ...
-- Opt-in, read-only Encounter Journal discovery. Never controls the character,
-- simulates play, guesses drop item IDs, or claims missing journal data is BiS.
local function Call(fn,...)
  if type(fn)~="function" then return nil end
  local ok,a,b,c,d,e,f,g,h,i,j=pcall(fn,...)
  if ok then return a,b,c,d,e,f,g,h,i,j end
end
local function LootAt(index)
  if C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex then
    local info=Call(C_EncounterJournal.GetLootInfoByIndex,index)
    if type(info)=="table" then return info end
  end
  -- Classic tuple, for compatibility. Retail uses the table above.
  if EJ_GetLootInfoByIndex then
    local id,encounterID,name,icon,slot,armorType,link=Call(EJ_GetLootInfoByIndex,index)
    if type(id)=="number" then
      return {itemID=id,encounterID=encounterID,name=name,icon=icon,slot=slot,armorType=armorType,link=link}
    end
  end
end
local function SourceFor(info, instanceName)
  local boss=info.encounterID and Call(EJ_GetEncounterInfo,info.encounterID)
  if type(boss)=="string" and boss~="" then return instanceName.." - "..boss end
  return instanceName.." (boss not confirmed)"
end
local function RestoreJournal(job)
  -- Never leave Blizzard's slot filter or journal difficulty altered.
  if job.oldSlotFilter~=nil and EJ_SetSlotFilter then pcall(EJ_SetSlotFilter,job.oldSlotFilter) end
  -- Restore filters and expansion/difficulty if known. WoW does not expose a
  -- reliable API to restore every journal selection across all versions.
  if job.oldClass~=nil and EJ_SetLootFilter then
    pcall(EJ_SetLootFilter,job.oldClass,job.oldSpec or 0)
  end
  if job.oldTier and EJ_SelectTier then pcall(EJ_SelectTier,job.oldTier) end
  if job.oldDifficulty and EJ_SetDifficulty then pcall(EJ_SetDifficulty,job.oldDifficulty) end
end

-- Explicit, deterministic difficulty preferences. Dungeon and raid IDs differ.
local DIFFICULTIES={Normal={dungeon=1,raid=14},Heroic={dungeon=2,raid=15},Mythic={dungeon=23,raid=16}}
local function ApplyDifficulty(job,source)
  local pair=DIFFICULTIES[job.difficultyMode] or DIFFICULTIES.Normal
  local wanted=source.raid and pair.raid or pair.dungeon
  local allowed=true
  if type(EJ_IsValidInstanceDifficulty)=="function" then
    local ok,result=pcall(EJ_IsValidInstanceDifficulty,wanted)
    if ok and result==false then allowed=false end
  end
  if allowed and type(EJ_SetDifficulty)=="function" then pcall(EJ_SetDifficulty,wanted) end
  local actual=Call(EJ_GetDifficulty)
  source.difficulty=type(actual)=="number" and actual or nil
  if not allowed or (source.difficulty and source.difficulty~=wanted) then
    job.difficultyFallbacks=job.difficultyFallbacks+1
    source.difficultyWarning=true
  end
  return source.difficulty or wanted
end
-- Item data arrives asynchronously in retail WoW. Never classify an item as
-- unusable just because GetItemInfo/GetDetailedItemLevelInfo returned nil.
local function RequestItem(job, itemID)
  if not itemID or job.requested[itemID] then return end
  job.requested[itemID]=true
  if C_Item and type(C_Item.RequestLoadItemDataByID)=="function" then
    local ok=pcall(C_Item.RequestLoadItemDataByID,itemID)
    if ok then job.requests=job.requests+1;return end
  end
  -- Classic/older compatible fallback: requesting GetItemInfo warms the cache.
  if type(GetItemInfo)=="function" then
    pcall(GetItemInfo,itemID)
    job.requests=job.requests+1
  end
end
local function MakeLink(record)
  if type(record.link)=="string" and record.link~="" then return record.link end
  local id=record.itemID
  local _,cachedLink
  if C_Item and type(C_Item.GetItemInfo)=="function" then
    _,cachedLink=Call(C_Item.GetItemInfo,id)
  end
  if type(cachedLink)~="string" and type(GetItemInfo)=="function" then
    _,cachedLink=Call(GetItemInfo,id)
  end
  return type(cachedLink)=="string" and cachedLink or nil
end
local function EvaluateRecord(job,record)
  local link=MakeLink(record)
  local candidate,reason
  if link and type(GHN.EvaluateExternalLoot)=="function" then
    candidate,reason=GHN:EvaluateExternalLoot(link)
  else
    reason="uncached-link"
  end
  if candidate then
    candidate.name=record.name or candidate.name
    candidate.itemID=record.itemID
    candidate.source=record.source
    candidate.instanceID=record.instanceID
    candidate.instanceName=record.instanceName
    candidate.tierIndex=job.tierIndex
    candidate.tierName=job.tierName
    candidate.encounterID=record.encounterID
    candidate.kind=record.kind
    candidate.difficulty=record.difficulty
    candidate.dungeonAreaMapID=record.dungeonAreaMapID
    candidate.specFiltered=job.specFilterApplied
    candidate.origin="journal"
    local key=table.concat({tostring(record.itemID),tostring(record.instanceID),tostring(record.encounterID or 0),tostring(record.difficulty or 0)},":")
    if not job.resultKeys[key] then
      job.resultKeys[key]=true
      job.results[#job.results+1]=candidate
      if candidate.needsEligibilityCheck then job.needsReview=job.needsReview+1 end
      if candidate.levelGroup=="soon" then job.comingSoon=job.comingSoon+1
      else job.equipNow=job.equipNow+1 end
    end
  elseif reason=="too-high-level" then
    job.tooHighLevel=job.tooHighLevel+1
  elseif reason=="notHigher" then
    job.notHigher=job.notHigher+1
  elseif reason=="armorMismatch" then
    job.armorMismatch=job.armorMismatch+1
    job.unusable=job.unusable+1
  elseif reason=="restricted" then
    job.restricted=job.restricted+1
    job.unusable=job.unusable+1
  elseif reason=="notEquipment" or reason=="unsupportedSlot" then
    job.notEquipment=job.notEquipment+1
    job.unusable=job.unusable+1
  elseif type(reason)=="string" and reason:sub(1,8)=="uncached" then
    return false,reason
  else
    job.unclassified=job.unclassified+1
  end
  return true,reason
end
local function RefreshProgress(job)
  if GHN.journalScan~=job or not (GHN.frame and GHN.frame:IsShown()) then return end
  if GHN.db and GHN.db.tab=="Gear" and GHN.RenderGearUpgrades then
    GHN:Safe("Journal progress",function()GHN:RenderGearUpgrades()end)
  end
end
local function CountUnknownReasons(job)
  local reasons={link=job.missingJournal or 0,info=0,level=0,equipped=0,required=0}
  for _,record in ipairs(job.pending) do
    local r=record.missingReason
    if r=="uncached-link" then reasons.link=reasons.link+1
    elseif r=="uncached-type" then reasons.info=reasons.info+1
    elseif r=="uncached-level" then reasons.level=reasons.level+1
    elseif r=="uncached-equipped" then reasons.equipped=reasons.equipped+1
    elseif r=="uncached-required-level" then reasons.required=reasons.required+1
    else reasons.info=reasons.info+1 end
  end
  job.unknownReasons=reasons
  job.unknown=#job.pending+(job.missingJournal or 0)
end
local function RequestWornEquipment(job)
  -- Needed if a journal candidate loaded but its equipped comparison slot
  -- was uncached. Requesting only the dungeon drop wouldn't resolve it.
  if type(GetInventoryItemID)~="function" then return end
  for _,slot in ipairs({1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17}) do
    local id=Call(GetInventoryItemID,"player",slot)
    if type(id)=="number" then RequestItem(job,id) end
  end
end
local function Finish(job)
  if GHN.journalJob~=job then return end
  GHN.journalJob=nil
  RestoreJournal(job)
  job.busy=false
  CountUnknownReasons(job)
  table.sort(job.results,function(a,b)
    if a.levelGroup~=b.levelGroup then return a.levelGroup=="now" end
    if a.delta==b.delta then return a.name<b.name end
    return a.delta>b.delta
  end)
  if job.instancesScanned==0 then
    job.status="No dungeon or raid loot was readable. Open the Adventure Guide and try again."
  else
    job.status=string.format(
      "%d sources, %d drops: %d potential iLvl gains (%d need eligibility review); %d lower/equal, %d wrong armor, %d non-gear/unsupported, %d still unknown after %d requests.",
      job.instancesScanned,job.lootRead,#job.results,job.needsReview,job.notHigher,
      job.armorMismatch,job.notEquipment,job.unknown,job.requests)
    job.status=job.status..string.format(" %d equip now, %d within %d levels, %d blocked by level cap.",
      job.equipNow,job.comingSoon,GHN:GetGearAheadLevels(),job.tooHighLevel)
    local reasons=job.unknownReasons
    job.status=job.status..string.format(" %s difficulty, %d source(s) used a fallback. Missing breakdown: %d links, %d item types, %d item levels, %d equipped levels.",
      job.difficultyMode,job.difficultyFallbacks,reasons.link,reasons.info,reasons.level,reasons.equipped)
    if reasons.required>0 then job.status=job.status.." Missing minimum-level metadata: "..reasons.required.."." end
    if job.emptySources>0 then
      job.status=job.status..string.format(" %d sources had no readable loot after a retry.",job.emptySources)
    end
  end
  RefreshProgress(job)
end
local function RetryPending(job)
  if GHN.journalJob~=job or not job.sourcesFinished then return end
  local remaining={}
  for _,record in ipairs(job.pending) do
    local handled,reason=EvaluateRecord(job,record)
    if not handled then
      record.missingReason=reason
      remaining[#remaining+1]=record
    end
  end
  job.pending=remaining
  CountUnknownReasons(job)
end
local function ScheduleRetry(job,delay)
  if GHN.journalJob~=job or not job.sourcesFinished or job.retryScheduled then return end
  if not (C_Timer and type(C_Timer.After)=="function") then Finish(job);return end
  job.retryScheduled=true
  C_Timer.After(delay or 0.3,function()
    if GHN.journalJob~=job then return end
    job.retryScheduled=false
    RetryPending(job)
    RefreshProgress(job)
    if #job.pending==0 then
      Finish(job)
      return
    end
    job.retryRounds=job.retryRounds+1
    if job.retryRounds>=16 then
      Finish(job) -- bounded wait: some item IDs will never resolve.
      return
    end
    job.status=string.format("Waiting for WoW item data: %d unresolved of %d drops (%d requests, retry %d/16).",
      #job.pending,job.lootRead,job.requests,job.retryRounds)
    ScheduleRetry(job,0.75)
  end)
end
-- Driven by GET_ITEM_INFO_RECEIVED and ITEM_DATA_LOAD_RESULT. Individual
-- events accelerate rechecks, but the bounded timer handles missed events.
function GHN:JournalItemDataLoaded(itemID,success)
  local job=self.journalJob
  if not job or not job.sourcesFinished then return end
  if itemID and not job.requested[itemID] then return end
  ScheduleRetry(job,0.10)
end
local function ScanNext(job)
  if GHN.journalJob~=job then return end
  local info=job.instances[job.index]
  if not info then
    job.sourcesFinished=true
    CountUnknownReasons(job)
    if #job.pending>0 then
      job.status=string.format("Read %d sources and %d drops. Loading %d missing item records (%d requests sent)...",
        job.instancesScanned,job.lootRead,#job.pending,job.requests)
      RefreshProgress(job)
      ScheduleRetry(job,0.5)
    else
      Finish(job)
    end
    return
  end
  if not info.prepared then
    -- Journal selection can return before its loot list is ready. Apply
    -- filters only once, then allow the client to populate the selected list.
    info.prepared=true
    info.selectedOK=pcall(EJ_SelectInstance,info.id)
    if info.selectedOK then
      if EJ_SetLootFilter and job.classID then
        pcall(EJ_SetLootFilter,job.classID,job.specID or 0)
      end
      if type(EJ_ResetSlotFilter)=="function" then pcall(EJ_ResetSlotFilter) end
      ApplyDifficulty(job,info)
      if C_Timer and type(C_Timer.After)=="function" then
        job.status="Loading loot for "..tostring(info.name).."..."
        RefreshProgress(job)
        C_Timer.After(.12,function()ScanNext(job)end)
        return
      end
    end
  end
  local selectedOK=info.selectedOK
  local n=selectedOK and Call(EJ_GetNumLoot) or 0
  if not selectedOK then job.failedSources=job.failedSources+1 end
  if type(n)~="number" or n<0 then n=0 end
  n=math.min(n,400)
  -- Instance selection can return before the Encounter Journal loot arrives.
  -- Wait once for a zero-count source rather than declaring an empty table on
  -- the initial asynchronous frame. This is bounded even for truly empty loot.
  if selectedOK and n==0 and not info.waitedForLoot and C_Timer and C_Timer.After then
    info.waitedForLoot=true
    job.status="Waiting briefly for loot from "..tostring(info.name).." ("..job.index.."/"..#job.instances..")..."
    RefreshProgress(job)
    C_Timer.After(.35,function()ScanNext(job)end)
    return
  end
  job.index=job.index+1
  job.instancesScanned=job.instancesScanned+1
  if n==0 then job.emptySources=job.emptySources+1 end
  for i=1,n do
    local drop=LootAt(i)
    if drop and type(drop.itemID)=="number" then
      job.lootRead=job.lootRead+1
      local record={itemID=drop.itemID,
        link=type(drop.link)=="string" and drop.link or drop.itemLink,
        name=type(drop.name)=="string" and drop.name:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","") or nil,
        encounterID=drop.encounterID,source=SourceFor(drop,info.name),
        instanceID=info.id,instanceName=info.name,
        dungeonAreaMapID=info.dungeonAreaMapID, difficulty=info.difficulty,
        kind=info.raid and "Raid" or "Dungeon"}
      local handled,reason=EvaluateRecord(job,record)
      if not handled then
        record.missingReason=reason
        job.pending[#job.pending+1]=record
        RequestItem(job,drop.itemID)
        if reason=="uncached-equipped" then RequestWornEquipment(job) end
      end
    else
      -- EJ_LOOT_DATA_RECIEVED may later populate this journal slot, but the
      -- item has no ID to request safely. Report it as unknown.
      job.missingJournal=job.missingJournal+1
    end
  end
  CountUnknownReasons(job)
  RefreshProgress(job)
  if C_Timer and type(C_Timer.After)=="function" then
    C_Timer.After(0.06,function()ScanNext(job)end)
  else
    job.status="Partial scan: async timer unavailable."
    Finish(job)
  end
end
-- Journal tier is selected by the player; never assume an expansion has
-- relevant max-level gear or a verified world-map waypoint.
local function LoadJournal()
  if EJ_GetNumTiers and EJ_GetInstanceByIndex then return true end
  if C_AddOns and type(C_AddOns.LoadAddOn)=="function" then
    pcall(C_AddOns.LoadAddOn,"Blizzard_EncounterJournal")
  elseif type(LoadAddOn)=="function" then pcall(LoadAddOn,"Blizzard_EncounterJournal") end
  return type(EJ_GetNumTiers)=="function" and type(EJ_GetInstanceByIndex)=="function"
end
function GHN:GetGearJournalTier()
  if not LoadJournal() then return nil,nil,0 end
  local count=Call(EJ_GetNumTiers)
  if type(count)~="number" or count<1 then return nil,nil,0 end
  local offset=math.max(0,math.floor(tonumber(self.gearJournalTierOffset) or 0))
  offset=math.min(offset,count-1)
  local index=count-offset
  local name=Call(EJ_GetTierInfo,index)
  if type(name)~="string" or name=="" then name="Expansion "..index end
  return index,name,count
end
function GHN:CycleGearJournalTier()
  local _,_,n=self:GetGearJournalTier()
  if n==0 then return end
  self.gearJournalTierOffset=((self.gearJournalTierOffset or 0)+1)%n
  self:ScanJournalUpgrades()
  if self.SetGearView then self:SetGearView("Upgrades") end
end
function GHN:CycleGearJournalDifficulty()
  local current=self.gearJournalDifficultyMode or "Mythic"
  self.gearJournalDifficultyMode=current=="Normal" and "Heroic" or
    (current=="Heroic" and "Mythic" or "Normal")
  self.gearUpgradePage=1
  self.gearSelected=nil
  self:ScanJournalUpgrades()
  if self.SetGearView then self:SetGearView("Upgrades") end
end
function GHN:CycleGearJournalType()
  local current=self.gearJournalKind or "All"
  self.gearJournalKind=current=="All" and "Dungeons" or (current=="Dungeons" and "Raids" or "All")
  self:ScanJournalUpgrades()
  if self.SetGearView then self:SetGearView("Upgrades") end
end
-- Verified ONLY from Blizzard's discovered entrance POIs for the mapped
-- journal instance. An interior map ID alone is NOT an entrance coordinate.
function GHN:FindGearEntrance(entry)
  if type(entry)~="table" or type(entry.instanceID)~="number" then return nil end
  if not (C_Map and type(C_Map.GetMapInfo)=="function" and C_EncounterJournal and
      type(C_EncounterJournal.GetDungeonEntrancesForMap)=="function") then return nil end
  local id=entry.dungeonAreaMapID
  local seen={}
  for _=1,12 do
    if type(id)~="number" or id<=0 or seen[id] then break end
    seen[id]=true
    local ok,entrances=pcall(C_EncounterJournal.GetDungeonEntrancesForMap,id)
    if ok and type(entrances)=="table" then
      for _,poi in ipairs(entrances) do
        if poi.journalInstanceID==entry.instanceID and poi.position then
          local x,y
          if type(poi.position.GetXY)=="function" then
            local good,a,b=pcall(poi.position.GetXY,poi.position)
            if good then x,y=a,b end
          end
          if not x then x=poi.position.x;y=poi.position.y end
          if type(x)=="number" and type(y)=="number" and x>=0 and x<=1 and y>=0 and y<=1 then
            return {mapID=id,x=x,y=y,name=poi.name or entry.instanceName}
          end
        end
      end
    end
    local valid,map=pcall(C_Map.GetMapInfo,id)
    if not valid or type(map)~="table" then break end
    id=map.parentMapID
  end
  return nil
end
function GHN:OpenGearEntrance()
  local entry=self.gearSource=="journal" and self.gearSelected
  if not entry then return false,"Choose a dungeon/raid item first." end
  if InCombatLockdown and InCombatLockdown() then return false,"Map unavailable in combat." end
  local entrance=self:FindGearEntrance(entry)
  if not entrance then return false,"WoW has not provided a discovered entrance for this dungeon/raid. Open its Adventure Guide instead." end
  local marked=false
  if C_Map and type(C_Map.SetUserWaypoint)=="function" and UiMapPoint and type(UiMapPoint.CreateFromCoordinates)=="function" then
    marked=pcall(function()
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(entrance.mapID,entrance.x,entrance.y))
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
      end
    end)
  end
  local wasShown=self.frame and self.frame:IsShown()
  if wasShown then self.frame:Hide() end
  local opened=false
  if type(OpenWorldMap)=="function" then opened=pcall(OpenWorldMap,entrance.mapID)
  elseif type(ToggleWorldMap)=="function" then opened=pcall(ToggleWorldMap) end
  if opened and WorldMapFrame and WorldMapFrame.IsShown and not WorldMapFrame:IsShown() then opened=false end
  if not opened and wasShown then self.frame:Show() end
  if opened and wasShown and WorldMapFrame and WorldMapFrame.HookScript then
    self.restoreAfterWorldMap=true
    if not self.mapCloseHookInstalled then
      self.mapCloseHookInstalled=true
      WorldMapFrame:HookScript("OnHide",function()
        if GHN.restoreAfterWorldMap then
          GHN.restoreAfterWorldMap=false
          if GHN.frame and not GHN.frame:IsShown() then GHN.frame:Show() end
        end
      end)
    end
  end
  return opened or marked,opened and
    (marked and "Opened a verified dungeon entrance and set a waypoint." or "Opened WoW's discovered entrance map; no waypoint was set.") or
    (marked and "Waypoint set; open your world map to see it." or "World map unavailable; no waypoint was set.")
end
function GHN:OpenGearSource()
  local entry=self.gearSource=="journal" and self.gearSelected
  if not entry or not entry.instanceID then return false,"Select a journal gear result first." end
  if InCombatLockdown and InCombatLockdown() then return false,"Open your source when out of combat." end
  if not LoadJournal() then return false,"WoW's Encounter Journal is unavailable. Try Shift+J." end
  -- Stop the asynchronous scan before changing Blizzard's selected encounter.
  if self.journalJob then
    local pending=self.journalJob
    self.journalJob=nil
    RestoreJournal(pending)
    pending.status="Scan stopped because the selected source was opened."
  end
  -- The built-in Encounter Journal API is responsible for navigation.
  -- When present it opens the correct dungeon/raid and boss, if known.
  if type(EncounterJournal_OpenJournal)=="function" then
    local ok=pcall(EncounterJournal_OpenJournal,tonumber(entry.difficulty),entry.instanceID,entry.encounterID,nil,entry.tierIndex)
    if ok then
      if self.frame then self.frame:Hide() end
      return true,"Opened the Encounter Journal. Check the loot drop and difficulty."
    end
  end
  -- Older clients: reveal Blizzard's journal without pretending its boss is selected.
  if type(ToggleEncounterJournal)=="function" then
    local ok=pcall(ToggleEncounterJournal)
    if ok then
      if self.frame then self.frame:Hide() end
      return true,"Opened the journal. Select "..tostring(entry.instanceName or entry.source).." manually."
    end
  end
  return false,"Encounter Journal navigation is not available on this client; use Shift+J."
end
function GHN:TrackGearTarget()
  if not self.db then return end
  local e=self.gearSource=="journal" and self.gearSelected or nil
  if not e then return false,"Select a dungeon/raid gear result before tracking." end
  local profile=self.Profile and self:Profile()
  if not profile then return false,"This character's saved profile is unavailable." end
  profile.gearTarget={itemID=e.itemID,name=e.name,source=e.source,kind=e.kind,
    instanceID=e.instanceID,instanceName=e.instanceName,tierIndex=e.tierIndex,
    tierName=e.tierName,encounterID=e.encounterID,difficulty=e.difficulty,
    slotName=e.slotName,selectedIlvl=e.ilvl,requiredLevel=e.requiredLevel,
    needsEligibilityCheck=e.needsEligibilityCheck}
  return true,"Tracked "..tostring(e.name).." (does not mark the loot as owned)."
end
function GHN:ScanJournalUpgrades()
  self.gearSelected=nil
  self.gearSelectedData=nil
  self.gearSelectionManual=false
  self.gearUpgradePage=1
  if self.journalJob then
    local previous=self.journalJob
    self.journalJob=nil -- pending timer callbacks see the changed job and exit.
    RestoreJournal(previous)
  end
  self.gearSource="journal"
  local job={results={},busy=false,status="",index=1,instances={},
    instancesScanned=0,lootRead=0,unknown=0,unusable=0,notHigher=0,emptySources=0,
    restricted=0,needsReview=0,armorMismatch=0,notEquipment=0,unclassified=0,
    tooHighLevel=0,equipNow=0,comingSoon=0,
    requested={},requests=0,pending={},missingJournal=0,retryRounds=0,
    retryScheduled=false,sourcesFinished=false,failedSources=0,
    resultKeys={},difficultyFallbacks=0,
    difficultyMode=self.gearJournalDifficultyMode or "Mythic"}
  self.journalScan=job
  if InCombatLockdown and InCombatLockdown() then
    job.status="Journal scanning is paused in combat."
    return job
  end
  if not(EJ_GetNumTiers and EJ_GetInstanceByIndex and EJ_SelectTier and EJ_SelectInstance
      and EJ_GetNumLoot and (C_EncounterJournal or EJ_GetLootInfoByIndex)) then
    if C_AddOns and C_AddOns.LoadAddOn then
      pcall(C_AddOns.LoadAddOn,"Blizzard_EncounterJournal")
    elseif LoadAddOn then pcall(LoadAddOn,"Blizzard_EncounterJournal") end
  end
  if not(EJ_GetNumTiers and EJ_GetInstanceByIndex and EJ_SelectTier and EJ_SelectInstance
      and EJ_GetNumLoot and (C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex or EJ_GetLootInfoByIndex)) then
    job.status="Encounter Journal APIs are unavailable. Open the Adventure Guide and retry."
    return job
  end
  local tiers=Call(EJ_GetNumTiers)
  if type(tiers)~="number" or tiers<1 then
    job.status="No Encounter Journal expansion tiers were available."
    return job
  end
  job.tierIndex,job.tierName= self:GetGearJournalTier()
  if not job.tierIndex then job.status="No journal expansion could be selected.";return job end
  job.kind=self.gearJournalKind or "All"
  job.oldTier=Call(EJ_GetCurrentTier)
  job.oldDifficulty=Call(EJ_GetDifficulty)
  if EJ_GetLootFilter then job.oldClass,job.oldSpec=Call(EJ_GetLootFilter) end
  if EJ_GetSlotFilter then job.oldSlotFilter=Call(EJ_GetSlotFilter) end
  -- User-chosen journal tier (defaults to latest, but older ones can be cycled).
  if not pcall(EJ_SelectTier,job.tierIndex) then
    job.status="Could not select the latest Encounter Journal expansion. No results were assumed."
    return job
  end
  -- Restrict Journal's loot view to this character's spec when supported.
  local _,_,classID=Call(UnitClass,"player")
  local specIndex=Call(GetSpecialization)
  local specID=specIndex and Call(GetSpecializationInfo,specIndex)
  job.specFilterApplied=false
  job.classID=type(classID)=="number" and classID or nil
  job.specID=type(specID)=="number" and specID or nil
  if type(classID)=="number" and EJ_SetLootFilter then
    local ok=pcall(EJ_SetLootFilter,classID,type(specID)=="number" and specID or 0)
    job.specFilterApplied=ok and type(specID)=="number"
  end
  for _,isRaid in ipairs({false,true}) do
    if job.kind=="All" or (isRaid and job.kind=="Raids") or (not isRaid and job.kind=="Dungeons") then
    for index=1,80 do
      local id,name,_,_,_,_,_,dungeonAreaMapID=Call(EJ_GetInstanceByIndex,index,isRaid)
      if type(id)~="number" then break end
      job.instances[#job.instances+1]={id=id,name=type(name)=="string" and name or ("Instance "..id),raid=isRaid,
        dungeonAreaMapID=type(dungeonAreaMapID)=="number" and dungeonAreaMapID or nil}
    end
    end
  end
  if #job.instances==0 then
    job.status="No raid or dungeon entries were returned for "..job.tierName.."."
    RestoreJournal(job)
    return job
  end
  job.busy=true
  job.status="Scanning "..job.tierName.." ("..job.kind..", "..job.difficultyMode.."); results update as sources are read."
  self.journalJob=job
  if C_Timer and type(C_Timer.After)=="function" then
    C_Timer.After(0,function()ScanNext(job)end)
  else Finish(job) end
  return job
end
