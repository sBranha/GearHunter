-- Gear Hunter v0.3.1: item sources from the in-game Encounter Journal.
-- The Season 2 chest reward brackets below are published reward levels, not
-- the ilvl on an individual generated bonus-ID item link.
local addonName, GH = ...
local J=CreateFrame("Frame")
GH.journalWorker=J
GH.journalStatus="Not scanned"

local seasonDungeons={
    altaroffangs=true, murderrow=true, denofnalorakk=true,
    theblindingvale=true, blindingvale=true, voidscararena=true,
    rubylifepools=true, kingsrest=true, templeofsethraliss=true,
}
local function norm(n) return type(n)=="string" and n:lower():gsub("[^%a%d]", "") or "" end
function GH:IsSeason2Dungeon(name) return not not seasonDungeons[norm(name)] end
local rewards={ [2]=295,[3]=295,[4]=298,[5]=302,[6]=305,[7]=305,[8]=308,[9]=308,[10]=311 }
local rewardKeys={2,4,5,6,8,10} -- first key yielding each distinct ilvl
function GH:GetPlusRewardLevel(key)
    key=tonumber(key) or 10
    if key>=10 then return 311 end
    return rewards[key]
end
function GH:DescribeDifficulty(id,raid,rec)
    if rec and rec.mythicPlus then
        return "Mythic+ "..tostring(rec.keystoneLevel or 10).." end chest"
    end
    if raid then return ({[17]="Raid Finder",[14]="Raid Normal",[15]="Raid Heroic",[16]="Raid Mythic"})[id] or ("Raid "..tostring(id)) end
    return ({[1]="Dungeon Normal",[2]="Dungeon Heroic",[23]="Dungeon Mythic"})[id] or ("Dungeon "..tostring(id))
end
function GH:InitializeJournal()
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn,"Blizzard_EncounterJournal") end
    return EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex and EJ_SelectInstance
       and EJ_GetNumLoot and C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex
end
local function restore(state)
    if not state then return end
    if state.oldTier and EJ_SelectTier then pcall(EJ_SelectTier,state.oldTier) end
    if state.oldDifficulty and EJ_SetDifficulty then pcall(EJ_SetDifficulty,state.oldDifficulty) end
    if EJ_SetLootFilter and state.oldClass and state.oldSpec then
        pcall(EJ_SetLootFilter,state.oldClass,state.oldSpec)
    elseif EJ_ResetLootFilter then pcall(EJ_ResetLootFilter) end
end
-- A loot row alone does NOT prove that the selected raid/dungeon supplied it.
-- Blizzard may retain the preceding instance's loot while the new list loads.
-- Only emit records whose boss resolves back to this exact journal instance ID.
function GH:ValidateLootSource(item,job)
    if not item or type(item.encounterID)~="number" or item.encounterID<=0
        or not EJ_GetEncounterInfo then return nil end
    local ok,name,_,encounterID,_,_,ownerInstanceID =
        pcall(EJ_GetEncounterInfo,item.encounterID)
    if not ok or type(ownerInstanceID)~="number"
        or ownerInstanceID~=job.instanceID
        or encounterID~=item.encounterID
        or type(name)~="string" or name=="" then
        return nil
    end
    return name
end
local function emit(item,job,seen)
    if type(item)~="table" or type(item.itemID)~="number" then return nil end
    local filter=item.filterType
    if type(filter)~="number" or not GH.slotForFilter[filter] then return nil end
    if item.handError or item.weaponTypeError then return nil end
    local encounter=GH:ValidateLootSource(item,job)
    if not encounter then
        return false
    end
    GH.sourceAccepted=(GH.sourceAccepted or 0)+1
    local link=item.link or ("item:"..item.itemID)
    local name=item.name or ("Item "..item.itemID)
    local function add(diff,level,source,key)
        if not level or level<=0 then return end
        local dedupe=table.concat({job.instanceID,diff,item.itemID,item.encounterID or 0,key or 0},":")
        if seen[dedupe] then return end
        seen[dedupe]=true
        local record={itemID=item.itemID,name=name,icon=item.icon,link=link,
            level=level,levelSource=source,filter=filter,
            requiredLevel=GH:GetRequiredItemLevel(link),
            instance=job.name,instanceID=job.instanceID,
            encounter=encounter,encounterID=item.encounterID,
            difficulty=diff,raid=job.raid,tier=job.tier,
            mythicPlus=job.mythicPlus,keystoneLevel=key,
            sourceVerified=true,sourceValidation="boss-to-instance match",
        }
        GH.items[#GH.items+1]=record
        if GH.RememberGearItem then GH:RememberGearItem(record) end
    end
    if job.mythicPlus then
        -- End-of-dungeon Mythic+ chest: same dungeon's loot pool, not a boss drop.
        for _,key in ipairs(rewardKeys) do
            add(23,GH:GetPlusRewardLevel(key),"Season 2 end-chest reward bracket (estimate)",key)
        end
    else
        local level
        if C_Item and C_Item.GetDetailedItemLevelInfo then
            local ok,n=pcall(C_Item.GetDetailedItemLevelInfo,link)
            if ok then level=GH.SafeNumber(n) end
        end
        if not level and C_Item and C_Item.GetItemInfo then
            local ok,_,_,_,n=pcall(C_Item.GetItemInfo,link)
            if ok then level=GH.SafeNumber(n) end
        end
        add(job.difficulty,level,"Encounter Journal difficulty preview",nil)
    end
    return true
end
local function journalReady(job)
    -- Selection can succeed while the previous loot list is still displayed.
    if EJ_GetInstanceInfo then
        local ok,currentName=pcall(EJ_GetInstanceInfo)
        if not ok or norm(currentName)~=norm(job.name) then return false end
    end
    if EJ_GetDifficulty then
        local ok,currentDiff=pcall(EJ_GetDifficulty)
        if not ok or currentDiff~=job.difficulty then return false end
    end
    if EJ_IsLootListOutOfDate then
        local ok,outdated=pcall(EJ_IsLootListOutOfDate)
        if not ok or outdated then return false end
    end
    return true
end
function GH:CancelJournalScan()
    restore(self.scanJob)
    self.scanJob=nil;self.scanRunning=false
    J:SetScript("OnUpdate",nil)
    self.journalStatus="Scan stopped - partial results"
    self:Refresh()
end
local function collectJobs(self)
    local count=EJ_GetNumTiers() or 0
    local jobs,matched={},0
    local leveling=self:IsLevelingCharacter()
    -- For leveling, scan NORMAL dungeon loot across journal expansion tiers.
    -- Character level/loot requirement filtering happens per item. Instanced
    -- loot does not cover quests, crafting, or all outdoor upgrades.
    for tier=1,count do
        if pcall(EJ_SelectTier,tier) then
            if leveling then
                for i=1,90 do
                    local id,name=EJ_GetInstanceByIndex(i,false)
                    if not id then break end
                    jobs[#jobs+1]={instanceID=id,name=name or ("Dungeon "..id),
                        tier=tier,raid=false,difficulty=1,leveling=true}
                end
            else
                for raidIndex=1,2 do
                    local isRaid=raidIndex==2
                    for i=1,90 do
                        local id,name=EJ_GetInstanceByIndex(i,isRaid)
                        if not id then break end
                        if isRaid and norm(name)=="thevenomousabyss" then
                            for _,diff in ipairs({17,14,15,16}) do
                                jobs[#jobs+1]={instanceID=id,name=name or ("Raid "..id),
                                    tier=tier,raid=true,difficulty=diff}
                            end
                        elseif self:IsSeason2Dungeon(name) then
                            matched=matched+1
                            jobs[#jobs+1]={instanceID=id,name=name,tier=tier,
                                raid=false,difficulty=23,mythicPlus=true}
                        end
                    end
                end
            end
        end
    end
    return jobs,matched
end
function GH:StartJournalScan()
    if not self.db then return end
    if self.gearCatalogRunning then
        self:Print("The Gear Search catalog is being indexed. Stop that scan first.")
        return
    end
    if self.scanRunning then self:CancelJournalScan(); return end
    self.firstScanStarted=true
    if EncounterJournal and EncounterJournal.IsShown and EncounterJournal:IsShown() then
        self:Print("Close the Adventure Guide before scanning.");return
    end
    if not self:InitializeJournal() then
        self:Print("Blizzard's Encounter Journal is unavailable.");return
    end
    local oldTier=EJ_GetCurrentTier and EJ_GetCurrentTier()
    local oldDifficulty=EJ_GetDifficulty and EJ_GetDifficulty()
    local oldClass,oldSpec
    if EJ_GetLootFilter then oldClass,oldSpec=EJ_GetLootFilter() end
    local jobs,matched=collectJobs(self)
    if #jobs==0 then
        if oldTier then pcall(EJ_SelectTier,oldTier) end
        self.journalStatus="No raid or seasonal dungeon was found in the Encounter Journal"
        self:Print(self.journalStatus);self:Refresh();return
    end
    self.items={};self.selected=nil
    self.sourceAccepted=0;self.sourceRejected=0;self.sourceTimeouts=0
    local classID=select(3,UnitClass("player"))
    local specIndex=GetSpecialization and GetSpecialization()
    local specID=specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex)
    self.scanRunning=true
    self.scanJob={jobs=jobs,index=0,phase="next",seen={},elapsed=0,retries=0,
        classID=classID,specID=specID,oldTier=oldTier,oldDifficulty=oldDifficulty,
        oldClass=oldClass,oldSpec=oldSpec,matchedDungeons=matched}
    self.journalStatus=self:IsLevelingCharacter() and ("Scanning "..#jobs.." dungeon tables for usable leveling gear...") or ("Scanning all raid difficulties + "..matched.." seasonal dungeons...")
    self:Refresh()
    J:SetScript("OnUpdate",function(_,elapsed)
        local s=GH.scanJob
        if not s then J:SetScript("OnUpdate",nil);return end
        s.elapsed=s.elapsed+elapsed
        if s.elapsed<0.11 then return end
        s.elapsed=0
        if s.phase=="next" then
            s.index=s.index+1
            local job=s.jobs[s.index]
            if not job then
                restore(s)
                GH.scanRunning=false;GH.scanJob=nil;J:SetScript("OnUpdate",nil)
                GH.journalStatus="Scanned "..#s.jobs.." tables: "..#GH.items.." verified rewards ("..
                    tostring(GH.sourceRejected).." mismatched/unverified rows, "..
                    tostring(GH.sourceTimeouts).." unavailable lists omitted)"
                GH:Print(GH.journalStatus);GH:Refresh()
                return
            end
            pcall(EJ_SelectTier,job.tier)
            pcall(EJ_SelectInstance,job.instanceID)
            if EJ_SetDifficulty then pcall(EJ_SetDifficulty,job.difficulty) end
            if EJ_SetLootFilter and s.classID and s.specID then
                pcall(EJ_SetLootFilter,s.classID,s.specID)
            end
            s.retries=0;s.phase="read"
            GH.journalStatus="Scanning "..s.index.."/"..#s.jobs..": "..job.name
            GH:Refresh()
        else
            local job=s.jobs[s.index]
            local ready=journalReady(job)
            local ok,num=pcall(EJ_GetNumLoot)
            num=ok and type(num)=="number" and num or 0
            if (not ready or num==0) and s.retries<15 then
                s.retries=s.retries+1
            elseif not ready then
                -- Never label a stale or unavailable loot table with this job.
                GH.sourceTimeouts=GH.sourceTimeouts+1
                s.phase="next"
            else
                local accepted,rejected=0,0
                for n=1,math.min(num,500) do
                    local success,item=pcall(C_EncounterJournal.GetLootInfoByIndex,n)
                    if success then
                        local verified=emit(item,job,s.seen)
                        if verified==true then accepted=accepted+1
                        elseif verified==false then rejected=rejected+1 end
                    end
                end
                if rejected>0 and accepted==0 and s.retries<15 then
                    -- The list appears to belong entirely to the previous
                    -- instance. Wait for Blizzard's journal to finish refreshing.
                    s.retries=s.retries+1
                else
                    GH.sourceRejected=GH.sourceRejected+rejected
                    s.phase="next"
                end
            end
        end
    end)
end
local function stronger(a,b)
    if not b then return true end
    if a.level~=b.level then return (a.level or 0)>(b.level or 0) end
    if a.encounter and not b.encounter then return true end
    if a.raid and not b.raid then return true end
    return false
end
function GH:GetVisibleItems(tab,slotID,allSources)
    local result={}
    if tab=="My Gear" then
        return self:GetEquippedRecords(slotID)
    elseif tab=="Progress" then
        for savedKey,rec in pairs(self.db.goals) do
            local copy={};for k,v in pairs(rec) do copy[k]=v end
            copy.itemID=rec.itemID or (type(savedKey)=="number" and savedKey)
            copy.acquired,copy.acquiredWhere=self:HasItem(copy.itemID,copy.level)
            result[#result+1]=copy
        end
    else
        local filter=(self.db and self.db.options.sourceFilter) or "All"
        local pool={}
        for _,rec in ipairs(self.items) do pool[#pool+1]=rec end
        -- Actual bag equipment is useful at level 1 even before the
        -- dungeon journal can return suitable loot.
        if tab~="Tonight" then
            for _,rec in ipairs(self.bagUpgrades or {}) do pool[#pool+1]=rec end
        end
        for _,rec in ipairs(pool) do
            local effective=self:EffectiveSlot(rec)
            local isSelected=not slotID or slotID==0 or effective==slotID
                or (rec.filter==12 and (slotID==11 or slotID==12))
                or (rec.filter==13 and (slotID==13 or slotID==14))
            local permitted=filter=="All" or rec.fromBag or (filter=="Raid" and rec.raid)
                 or (filter=="Mythic+" and rec.mythicPlus)
            if tab=="Tonight" then
                -- Personal difficulty plan: a preference, NOT an assertion the
                -- character is eligible for this reward or will receive it.
                local limits=self.db.options
                local rank={ [17]=1,[14]=2,[15]=3,[16]=4 }
                if rec.mythicPlus then
                    permitted=permitted and rec.keystoneLevel and
                        rec.keystoneLevel <= (limits.tonightKey or 6)
                elseif rec.raid then
                    permitted=permitted and rank[rec.difficulty] and
                        rank[rec.difficulty] <= (rank[limits.tonightRaid] or 3)
                else
                    permitted=false
                end
            end
            -- When a specific ring or trinket slot is clicked, compare
            -- against THAT equipped slot (not whichever of the pair is weaker).
            -- All-slots view still picks the weaker of two slots.
            local candidate=rec
            if slotID and slotID~=0 and (rec.filter==12 or rec.filter==13) and isSelected then
                candidate={}
                for k,v in pairs(rec) do candidate[k]=v end
                candidate.compareSlot=slotID
            end
            if allSources then permitted=true end
            local gain=self:Gain(candidate)
            if isSelected and permitted and self:CanShowForLevel(candidate) and gain and gain>=1 then result[#result+1]=candidate end
        end
    end
    if tab=="What to Farm" or tab=="Best in Slot" or tab=="Upgrade Route" or tab=="Tonight" then
        -- One strongest target per equipped slot (never a fabricated DPS ranking).
        local best={}
        for _,rec in ipairs(result) do
            local slot=self:EffectiveSlot(rec)
            if slot and stronger(rec,best[slot]) then best[slot]=rec end
        end
        result={}
        for _,rec in pairs(best) do result[#result+1]=rec end
    end
    table.sort(result,function(a,b)
        if tab=="Progress" then
            if a.acquired~=b.acquired then return not a.acquired end
            return tostring(a.name or "")<tostring(b.name or "")
        end
        if tab=="Upgrade Route" then
            local an,bn=tostring(a.instance or ""),tostring(b.instance or "")
            if an~=bn then return an<bn end
        end
        if tab=="Upgrades" then
            local as,bs=self:EffectiveSlot(a) or 999,self:EffectiveSlot(b) or 999
            if as~=bs then return as<bs end
        end
        local ag,bg=self:Gain(a),self:Gain(b)
        if ag and bg and ag~=bg then return ag>bg end
        if ag and not bg then return true end
        if bg and not ag then return false end
        if a.level and b.level and a.level~=b.level then return a.level>b.level end
        return tostring(a.name or "")<tostring(b.name or "")
    end)
    return result
end
