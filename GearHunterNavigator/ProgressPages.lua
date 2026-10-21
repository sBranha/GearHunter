local ADDON, GHN = ...
-- Character-owned information, read from Blizzard's in-game journal APIs.
-- No remote lookups, guesses, mount-guide fallbacks, or background game actions.
local function lower(v) return tostring(v or ""):lower() end
local function matches(name, filter)
 return filter == nil or filter == "" or lower(name):find(lower(filter), 1, true) ~= nil
end
local function read(fn, ...)
 if type(fn) ~= "function" then return nil end
 local ok, a,b,c,d,e,f,g,h,i,j,k,l,m,n,o = pcall(fn, ...)
 if ok then return a,b,c,d,e,f,g,h,i,j,k,l,m,n,o end
 return nil
end
function GHN:ReadActiveQuests(search)
 local results={}
 local log=C_QuestLog
 if not (log and log.GetNumQuestLogEntries and log.GetInfo) then
   return results,"Quest Journal API unavailable on this client."
 end
 local n=read(log.GetNumQuestLogEntries) or 0
 for index=1,math.min(n,1000) do
   local info=read(log.GetInfo,index)
   if type(info)=="table" and not info.isHeader and info.questID and info.title and not info.isHidden then
     if matches(info.title,search) then
       local objectives=read(log.GetQuestObjectives,info.questID)
       local complete=read(log.IsComplete,info.questID)==true
       local todo=0
       if type(objectives)=="table" then
         for _,obj in ipairs(objectives) do if not obj.finished then todo=todo+1 end end
       end
       results[#results+1]={id=info.questID,name=info.title,level=info.level or 0,
          complete=complete,objectives=type(objectives)=="table" and objectives or {},remaining=todo,
          campaign=info.campaignID~=nil and info.campaignID~=0,zone=info.header or ""}
     end
   end
 end
 table.sort(results,function(a,b)
   if a.complete~=b.complete then return a.complete end
   if a.campaign~=b.campaign then return a.campaign end
   local level=UnitLevel and UnitLevel("player") or 1
   local da=math.abs((a.level or level)-level);local db=math.abs((b.level or level)-level)
   if da~=db then return da<db end
   return a.name<b.name
 end)
 return results,nil
end
function GHN:ReadReputations(search)
 local list={}
 local api=C_Reputation
 if not (api and api.GetNumFactions and api.GetFactionDataByIndex) then
   return list,"Reputation API unavailable on this client."
 end
 local n=read(api.GetNumFactions) or 0
 local hidden=0
 for idx=1,math.min(n,1500) do
   local data=read(api.GetFactionDataByIndex,idx)
   if type(data)=="table" and data.isHeader and data.isCollapsed then hidden=hidden+1 end
   if type(data)=="table" and data.name and (not data.isHeader or data.isHeaderWithRep) and matches(data.name,search) then
     local value=tonumber(data.currentStanding) or 0
     local low=tonumber(data.currentReactionThreshold) or 0
     local high=tonumber(data.nextReactionThreshold) or low
     local label=(_G and _G["FACTION_STANDING_LABEL"..tostring(data.reaction or 4)]) or
          ({"Hated","Hostile","Unfriendly","Neutral","Friendly","Honored","Revered","Exalted"})[data.reaction or 4] or "Standing"
     local renown=nil
     if data.factionID and C_MajorFactions and C_MajorFactions.GetMajorFactionData then
       local major=read(C_MajorFactions.GetMajorFactionData,data.factionID)
       if type(major)=="table" and type(major.renownLevel)=="number" then
         renown=major.renownLevel
         label="Renown "..renown
         value=tonumber(major.renownReputationEarned) or 0
         low=0;high=tonumber(major.renownLevelThreshold) or 0
       end
     end
     list[#list+1]={id=data.factionID,name=data.name,label=label,current=value,
       low=low,high=high,description=data.description or "",accountWide=data.isAccountWide,
       watched=data.isWatched,renown=renown}
   end
 end
 table.sort(list,function(a,b) return a.name<b.name end)
 return list, hidden>0 and (hidden.." collapsed reputation group(s) may hide additional factions. Choose EXPAND GROUPS to show them.") or nil
end
function GHN:ExpandReputationGroups()
 local api=C_Reputation
 if not (api and api.GetNumFactions and api.GetFactionDataByIndex and api.ExpandFactionHeader) then
    return false,"Faction group expansion is not supported by this client."
 end
 local expanded=0
 -- Expand from the bottom so earlier list indices stay stable.
 local n=math.min(read(api.GetNumFactions) or 0,1500)
 for idx=n,1,-1 do
    local faction=read(api.GetFactionDataByIndex,idx)
    if type(faction)=="table" and faction.isHeader and faction.isCollapsed then
      local ok=pcall(api.ExpandFactionHeader,idx)
      if ok then expanded=expanded+1 end
    end
 end
 return true,"Expanded "..expanded.." reputation group(s) in the Blizzard list."
end
function GHN:ReadCollectionItems(collectionType,onlyCollected,search)
 local items={}
 local total=0;local learned=0
 if collectionType=="Toys" then
   local api=C_ToyBox
   if not (api and api.GetNumFilteredToys and api.GetToyFromIndex and api.GetToyInfo) then
     return items,0,0,"Toy Box API unavailable."
   end
   local n=read(api.GetNumFilteredToys) or 0
   for idx=1,math.min(n,5000) do
     local id=read(api.GetToyFromIndex,idx)
     if type(id)=="number" and id>0 then
       local _,name,icon=read(api.GetToyInfo,id)
       local hasToy=read(PlayerHasToy,id)==true
       if hasToy then learned=learned+1 end
       total=total+1
       if name and matches(name,search) and (not onlyCollected or hasToy) then
         items[#items+1]={id=id,name=name,icon=icon,collected=hasToy,kind="Toy"}
       end
     end
   end
   table.sort(items,function(a,b) return a.name<b.name end)
   return items,learned,total,"Toy Box filters may hide items. Use SHOW ALL TOYS to reset."
 end
 local api=C_MountJournal
 if not (api and api.GetMountIDs and api.GetMountInfoByID) then
   return items,0,0,"Mount Journal API unavailable."
 end
 local ids=read(api.GetMountIDs)
 if type(ids)~="table" then return items,0,0,"Mount information is not loaded yet." end
 for _,id in ipairs(ids) do
   local name,_,icon,_,_,_,_,_,_,hideOnChar,collected=read(api.GetMountInfoByID,id)
   if name and not hideOnChar then
     total=total+1
     if collected then learned=learned+1 end
     if matches(name,search) and (not onlyCollected or collected) then
       items[#items+1]={id=id,name=name,icon=icon,collected=collected==true,kind="Mount"}
     end
   end
 end
 table.sort(items,function(a,b) return a.name<b.name end)
 return items,learned,total,nil
end
function GHN:QuestHelp(quest)
 if not quest then return "Select one of your active quests first." end
 if quest.complete then
   return "All tracked objectives are complete. Follow the quest's return marker and speak to its quest giver to turn it in."
 end
 for _,objective in ipairs(quest.objectives or {}) do
   if not objective.finished then
     local action="Work on this objective"
     if objective.type=="monster" or objective.type=="kill" then action="Defeat the enemies named in this objective"
     elseif objective.type=="item" then action="Collect the required items"
     elseif objective.type=="object" or objective.type=="interact" then action="Interact with the objective in the world" end
     local progress=""
     if type(objective.numFulfilled)=="number" and type(objective.numRequired)=="number" and objective.numRequired>0 then
       progress=" ("..objective.numFulfilled.."/"..objective.numRequired.." completed)"
     end
     return action..": "..tostring(objective.text or "Quest objective")..progress..". Track the quest and follow Blizzard's map marker. If no quest marker is available, check the in-game Quest Log's description."
   end
 end
 return "This quest has no incomplete objectives exposed by WoW right now. Open your Quest Log for the quest description or turn-in details."
end
function GHN:TrackActiveQuest(id)
 if not id then return false,"Choose an active quest first." end
 if C_SuperTrack and type(C_SuperTrack.SetSuperTrackedQuestID)=="function" then
   local ok=pcall(C_SuperTrack.SetSuperTrackedQuestID,id)
   if ok then return true,"Tracking the selected quest. Follow Blizzard's quest marker." end
 end
 return false,"Quest tracking is unavailable on this client. Open the WoW Quest Log."
end
