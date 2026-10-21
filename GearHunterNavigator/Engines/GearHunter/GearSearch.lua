-- Gear Hunter v0.10.3: local gear encyclopedia + in-game source observations.
-- This never connects to Wowhead or to the internet. Sources must come from
-- Blizzard's Encounter Journal; external Wowhead URLs are copyable references.
local addonName, NAV = ...
local GH = NAV.GearEngine
local ICON_ROOT = "Interface\\AddOns\\GearHunterNavigator\\Art\\UIIcons\\"
local ink={0.020,0.040,0.078,0.99}
local navy={0.034,0.070,0.120,1}
local rim={0.44,0.57,0.75,1}
local gold={1,0.82,0.30,1}
local pale={0.82,0.89,1,1}
local green={0.35,1,0.57,1}
local MAX_CATALOG=18000
local MAX_RESULTS=150
local function frameStyle(f,b,e)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(unpack(b or ink));f:SetBackdropBorderColor(unpack(e or rim))
end
local function panel(parent,x,y,w,h)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);f:SetSize(w,h)
    frameStyle(f);return f
end
local function font(parent,t,x,y,w,large,color)
    local f=parent:CreateFontString(nil,"OVERLAY",large and "GameFontNormalLarge" or "GameFontNormal")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    if w then f:SetWidth(w);f:SetJustifyH("LEFT") end
    f:SetTextColor(unpack(color or pale));f:SetText(t or "")
    return f
end
local function button(parent,t,x,y,w,h,fn)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetSize(w,h);frameStyle(b,navy,rim)
    b.caption=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
    b.caption:SetAllPoints();b.caption:SetTextColor(1,0.87,0.56,1);b.caption:SetText(t)
    b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(unpack(gold)) end)
    b:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(unpack(rim)) end)
    b:SetScript("OnClick",fn)
    return b
end
local function cleanName(name)
    return type(name)=="string" and name~="" and name or nil
end
local function validID(itemID)
    return type(itemID)=="number" and itemID>=1 and itemID<100000000
end
local function itemIDFrom(text)
    if type(text)~="string" then return nil end
    local id=text:match("|Hitem:(%d+):") or text:match("^item:(%d+)")
        or text:match("^%s*(%d+)%s*$")
    id=tonumber(id)
    return validID(id) and id or nil
end
local function urlEncode(s)
    return (tostring(s or ""):gsub("([^%w%-%_%.%~])",function(ch)
        return string.format("%%%02X",string.byte(ch))
    end))
end
local function itemSource(rec)
    if rec.sourceVerified then
        return (rec.raid and "RAID" or "DUNGEON").."  |  "..(rec.instance or "Unknown instance")
    end
    if rec.sourceObserved and rec.sourceType=="Vendor" then
        return "VENDOR (OBSERVED)  |  "..tostring(rec.vendorName or "Unknown merchant")
    end
    if rec.sourceObserved and rec.sourceType=="Quest" then
        return "QUEST REWARD (OBSERVED)  |  "..tostring(rec.questName or "Unknown quest")
    end
    if rec.sourceObserved and rec.sourceType=="Crafted" then
        return "PROFESSION RECIPE (OBSERVED)  |  "..tostring(rec.recipeName or "Unknown recipe")
    end
    if rec.owned then return "OWNED / SEEN IN INVENTORY" end
    return "NO KNOWN SOURCE IN THE LOCAL INDEX"
end
function GH:GearSearchUrl(rec)
    local id=rec and rec.itemID or itemIDFrom(self.gearSearchQuery)
    if id then return "https://www.wowhead.com/item="..tostring(id) end
    local phrase=rec and rec.name or self.gearSearchQuery or ""
    return "https://www.wowhead.com/search?q="..urlEncode(phrase)
end
function GH:InitializeGearIndex()
    if not self.db then return end
    if type(self.db.gearSearchIndex)~="table" then self.db.gearSearchIndex={} end
    self.gearSearchIndex=self.db.gearSearchIndex
    -- Re-key the v0.10.1 index without mutating it while iterating.
    local replacement={}
    for k,v in pairs(self.gearSearchIndex) do
        if type(k)=="string" and type(v)=="table" and validID(v.itemID) then
            local newKey=k
            if v.sourceVerified and v.instanceID and v.encounterID then
                newKey="s:"..v.itemID..":"..v.instanceID..":"..
                    tostring(v.difficulty or 0)..":"..v.encounterID
            end
            if not replacement[newKey] then replacement[newKey]=v end
        end
    end
    self.db.gearSearchIndex=replacement
    self.gearSearchIndex=replacement
    self.gearSearchIndexCount=0
    for _,v in pairs(self.gearSearchIndex) do
        if type(v)=="table" then self.gearSearchIndexCount=self.gearSearchIndexCount+1 end
    end
    self.gearSearchQuery=self.gearSearchQuery or ""
    self.gearSearchFilter=self.gearSearchFilter or "All"
end
function GH:RememberGearItem(rec)
    if not self.gearSearchIndex or type(rec)~="table" or not validID(rec.itemID) then return end
    -- Never turn an unverified row into a verified source on the strength of a
    -- name alone. Only boss->instance cross-checked Journal loot is verified.
    local verified=rec.sourceVerified==true and type(rec.instanceID)=="number"
        and type(rec.encounterID)=="number"
    -- The three observed-source kinds are grounded in open Blizzard UI, NOT
    -- claimed to be an exhaustive database or confirmed acquisition route.
    local observed=rec.sourceObserved==true and
        (rec.sourceType=="Vendor" or rec.sourceType=="Quest" or rec.sourceType=="Crafted")
    local sourceKey=observed and type(rec.sourceKey)=="string" and rec.sourceKey or nil
    local key=verified and ("s:"..rec.itemID..":"..rec.instanceID..":"..tostring(rec.difficulty or 0)..":"..rec.encounterID)
        or (sourceKey and ("o:"..rec.itemID..":"..sourceKey)) or ("i:"..rec.itemID)
    local old=self.gearSearchIndex[key]
    if not old and (self.gearSearchIndexCount or 0)>=MAX_CATALOG then return end
    if old and old.sourceVerified and not verified then return end
    local name=cleanName(rec.name)
    if not name and type(rec.link)=="string" and type(GetItemInfo)=="function" then
        local ok,n=pcall(GetItemInfo,rec.link)
        if ok then name=cleanName(n) end
    end
    if not name and old and type(old.name)=="string" and not old.name:match("^Item #%d+$") then
        name=old.name
    end
    if not name then
        name="Item #"..rec.itemID
        if C_Item and C_Item.RequestLoadItemDataByID then
            self.gearPendingNames=self.gearPendingNames or {}
            self.gearPendingNames[rec.itemID]=true
            pcall(C_Item.RequestLoadItemDataByID,rec.itemID)
        end
    end
    local saved={itemID=rec.itemID,name=name,icon=rec.icon,
        level=type(rec.level)=="number" and rec.level or nil,
        requiredLevel=type(rec.requiredLevel)=="number" and rec.requiredLevel or nil,
        link=type(rec.link)=="string" and rec.link or "item:"..rec.itemID,
        sourceVerified=verified or false,owned=rec.owned==true or rec.fromBag==true or rec.isEquipped==true,
        raid=verified and rec.raid==true or false,
        instance=verified and rec.instance or nil,instanceID=verified and rec.instanceID or nil,
        encounter=verified and rec.encounter or nil,encounterID=verified and rec.encounterID or nil,
        difficulty=verified and rec.difficulty or nil,tier=verified and rec.tier or nil,
        filter=type(rec.filter)=="number" and rec.filter or nil,
        sourceObserved=observed or false,sourceType=observed and rec.sourceType or nil,
        sourceKey=observed and sourceKey or nil,
        vendorName=observed and rec.sourceType=="Vendor" and rec.vendorName or nil,
        questName=observed and rec.sourceType=="Quest" and rec.questName or nil,
        questID=observed and rec.sourceType=="Quest" and rec.questID or nil,
        recipeName=observed and rec.sourceType=="Crafted" and rec.recipeName or nil,
        recipeID=observed and rec.sourceType=="Crafted" and rec.recipeID or nil,
        profession=observed and rec.sourceType=="Crafted" and rec.profession or nil,
        recipeLearned=observed and rec.sourceType=="Crafted" and rec.recipeLearned or nil,
        mapID=observed and rec.sourceType=="Vendor" and rec.mapID or nil,
        mapX=observed and rec.sourceType=="Vendor" and rec.mapX or nil,
        mapY=observed and rec.sourceType=="Vendor" and rec.mapY or nil,
        price=observed and rec.sourceType=="Vendor" and rec.price or nil,
        extendedCost=observed and rec.sourceType=="Vendor" and rec.extendedCost or nil,
    }
    if old and old.level and (not saved.level or old.level>saved.level) then saved.level=old.level end
    if old and old.owned then saved.owned=true end
    self.gearSearchIndex[key]=saved
    if not old then self.gearSearchIndexCount=(self.gearSearchIndexCount or 0)+1 end
end
function GH:IndexKnownGear()
    for _,rec in ipairs(self.items or {}) do self:RememberGearItem(rec) end
    for _,rec in ipairs(self.bagUpgrades or {}) do
        local copy={};for k,v in pairs(rec) do copy[k]=v end
        copy.owned=true;self:RememberGearItem(copy)
    end
    for slot,rec in pairs(self.equipped or {}) do
        if validID(rec.itemID) then
            local name
            if rec.link and GetItemInfo then
                local ok,n=pcall(GetItemInfo,rec.link);if ok then name=n end
            end
            self:RememberGearItem({itemID=rec.itemID,name=name,link=rec.link,icon=rec.icon,
                level=rec.level,owned=true,equippedSlot=slot})
        end
    end
    for _,rec in pairs(self.db and self.db.goals or {}) do self:RememberGearItem(rec) end
end
function GH:GetGearSearchMatches()
    local q=tostring(self.gearSearchQuery or ""):lower():gsub("^%s+",""):gsub("%s+$","")
    if q=="" then return {} end
    self:IndexKnownGear()
    local targetID=itemIDFrom(self.gearSearchQuery)
    local filter=self.gearSearchFilter or "All"
    local results,seen={},{}
    local hasTargetID=false
    local function add(rec)
        if type(rec)~="table" then return end
        local id=rec.itemID
        if not validID(id) then return end
        -- Apply the same required-character-level window to the saved item
        -- catalog and exact-ID lookups. Item LEVEL is not required level.
        if not self:IsWithinGearLevelRange(rec) then return end
        if filter=="Raid" and (not rec.sourceVerified or not rec.raid) then return end
        if filter=="Dungeon" and (not rec.sourceVerified or rec.raid) then return end
        if filter=="Owned" and not rec.owned then return end
        if filter=="Vendor" and not (rec.sourceObserved and rec.sourceType=="Vendor") then return end
        if filter=="Quest" and not (rec.sourceObserved and rec.sourceType=="Quest") then return end
        if filter=="Crafted" and not (rec.sourceObserved and rec.sourceType=="Crafted") then return end
        local name=tostring(rec.name or ""):lower()
        if targetID~=id and not name:find(q,1,true) then return end
        local signature=tostring(id)..":"..tostring(rec.instanceID or 0)..":"..tostring(rec.difficulty or 0)..":"..tostring(rec.encounterID or 0)..":"..tostring(rec.sourceKey or "")
        if targetID==id then hasTargetID=true end
        if seen[signature] then return end
        seen[signature]=true
        local starts=name:sub(1,#q)==q
        local score=(targetID==id and 0 or name==q and 1 or starts and 2 or 3)
        results[#results+1]={rec=rec,score=score}
    end
    for _,rec in pairs(self.gearSearchIndex or {}) do add(rec) end
    -- An exact item ID or item link can be looked up in the local WoW client
    -- cache even if no source is known. It is not a worldwide name lookup.
    if targetID and not hasTargetID and filter=="All" then
        local name,link,icon,requiredLevel
        if type(GetItemInfo)=="function" then
            local ok,n,l,_,_,lvl,_,_,_,_,ico=pcall(GetItemInfo,targetID)
            if ok then name=n;link=l;requiredLevel=lvl;icon=ico end
        end
        if not name and C_Item and C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID,targetID)
        end
        add({itemID=targetID,name=name or ("Item #"..targetID),link=link or ("item:"..targetID),
            icon=icon,requiredLevel=requiredLevel,sourceVerified=false})
    end
    table.sort(results,function(a,b)
        if a.score~=b.score then return a.score<b.score end
        local an,bn=(a.rec.name or ""):lower(),(b.rec.name or ""):lower()
        if an~=bn then return an<bn end
        if a.rec.sourceVerified~=b.rec.sourceVerified then return a.rec.sourceVerified end
        return (a.rec.level or 0)>(b.rec.level or 0)
    end)
    local count=#results;local output={}
    for i=1,math.min(MAX_RESULTS,count) do output[i]=results[i].rec end
    return output,count
end

-- Optional full Adventure Guide indexing, independent of the player's level
-- and current upgrade comparison. One journal table is processed per tick.
local worker=CreateFrame("Frame")
local function sourceReady(job)
    if EJ_GetInstanceInfo then
        local ok,name=pcall(EJ_GetInstanceInfo)
        if not ok or type(name)~="string" or name:lower()~=job.name:lower() then return false end
    end
    if EJ_GetDifficulty then
        local ok,d=pcall(EJ_GetDifficulty)
        if not ok or d~=job.difficulty then return false end
    end
    if EJ_IsLootListOutOfDate then
        local ok,outdated=pcall(EJ_IsLootListOutOfDate)
        if not ok or outdated then return false end
    end
    return true
end
local function restoreJournal(scan)
    if scan and scan.oldTier then pcall(EJ_SelectTier,scan.oldTier) end
    if scan and scan.oldDifficulty and EJ_SetDifficulty then pcall(EJ_SetDifficulty,scan.oldDifficulty) end
    if scan and scan.oldClass and scan.oldSpec and EJ_SetLootFilter then
        pcall(EJ_SetLootFilter,scan.oldClass,scan.oldSpec)
    elseif EJ_ResetLootFilter then pcall(EJ_ResetLootFilter) end
end
function GH:StopGearCatalogScan(cancelled)
    local scan=self.gearCatalogScan
    if not scan then return end
    worker:SetScript("OnUpdate",nil)
    restoreJournal(scan)
    self.gearCatalogScan=nil;self.gearCatalogRunning=false
    self.gearCatalogStatus=(cancelled and "Indexing stopped" or "Catalog scan finished")..
        ": "..tostring(self.gearSearchIndexCount or 0).." saved records"
    if self.RefreshGearSearch then self:RefreshGearSearch() end
    if self.RefreshBossLootHunter then self:RefreshBossLootHunter() end
end
function GH:StartGearCatalogScan()
    if self.gearCatalogRunning then self:StopGearCatalogScan(true);return end
    if self.scanRunning then self:Print("Wait until the regular gear scan finishes first.");return end
    if EncounterJournal and EncounterJournal.IsShown and EncounterJournal:IsShown() then
        self:Print("Close the Adventure Guide to run the catalog scan.");return
    end
    if not self:InitializeJournal() then self:Print("Blizzard Adventure Guide is unavailable.");return end
    self:IndexKnownGear()
    local oldTier=EJ_GetCurrentTier and EJ_GetCurrentTier()
    local oldDifficulty=EJ_GetDifficulty and EJ_GetDifficulty()
    local oldClass,oldSpec
    if EJ_GetLootFilter then oldClass,oldSpec=EJ_GetLootFilter() end
    local jobs,seen={},{}
    local okN,n=pcall(EJ_GetNumTiers)
    if not okN or type(n)~="number" then return end
    for tier=1,n do
        if pcall(EJ_SelectTier,tier) then
            for raidValue=0,1 do
                local raid=raidValue==1
                for i=1,100 do
                    local ok,id,name=pcall(EJ_GetInstanceByIndex,i,raid)
                    if not ok or not id then break end
                    if not seen[id] then
                        seen[id]=true
                        jobs[#jobs+1]={tier=tier,instanceID=id,name=name or tostring(id),
                            raid=raid,difficulty=raid and 14 or 1}
                    end
                end
            end
        end
    end
    if #jobs==0 then restoreJournal({oldTier=oldTier,oldDifficulty=oldDifficulty,oldClass=oldClass,oldSpec=oldSpec});return end
    self.gearCatalogScan={jobs=jobs,index=0,phase="next",retries=0,elapsed=0,
        oldTier=oldTier,oldDifficulty=oldDifficulty,oldClass=oldClass,oldSpec=oldSpec,
        unique=0}
    self.gearCatalogRunning=true
    self.gearCatalogStatus="Indexing 0/"..#jobs.." dungeon and raid tables..."
    if EJ_ResetLootFilter then pcall(EJ_ResetLootFilter) end
    if self.RefreshGearSearch then self:RefreshGearSearch() end
    if self.RefreshBossLootHunter then self:RefreshBossLootHunter() end
    worker:SetScript("OnUpdate",function(_,elapsed)
        local scan=GH.gearCatalogScan
        if not scan then worker:SetScript("OnUpdate",nil);return end
        scan.elapsed=scan.elapsed+elapsed
        if scan.elapsed<0.14 then return end
        scan.elapsed=0
        if scan.phase=="next" then
            scan.index=scan.index+1
            local job=scan.jobs[scan.index]
            if not job or (GH.gearSearchIndexCount or 0)>=MAX_CATALOG then
                GH:StopGearCatalogScan(false);return
            end
            pcall(EJ_SelectTier,job.tier)
            pcall(EJ_SelectInstance,job.instanceID)
            if EJ_SetDifficulty then pcall(EJ_SetDifficulty,job.difficulty) end
            scan.phase="read";scan.retries=0
            if scan.index%5==1 then
                GH.gearCatalogStatus="Indexing "..scan.index.."/"..#scan.jobs..
                    " tables - "..(job.name or "")
                if GH.RefreshGearSearch then GH:RefreshGearSearch() end
                if GH.RefreshBossLootHunter then GH:RefreshBossLootHunter() end
            end
        else
            local job=scan.jobs[scan.index]
            local ok,num=pcall(EJ_GetNumLoot)
            num=(ok and type(num)=="number") and num or 0
            if (not sourceReady(job) or num==0) and scan.retries<10 then
                scan.retries=scan.retries+1;return
            end
            if sourceReady(job) and GH.RememberBossLootInstance then
                GH:RememberBossLootInstance(job)
            end
            if sourceReady(job) and num>0 then
                for i=1,math.min(num,450) do
                    local success,item=pcall(C_EncounterJournal.GetLootInfoByIndex,i)
                    if success and type(item)=="table" and validID(item.itemID)
                        and type(item.filterType)=="number" and GH.slotForFilter[item.filterType] then
                        local encounter=GH:ValidateLootSource(item,job)
                        if encounter then
                            local level
                            if C_Item and C_Item.GetDetailedItemLevelInfo and item.link then
                                local valid,n=pcall(C_Item.GetDetailedItemLevelInfo,item.link)
                                if valid and type(n)=="number" then level=n end
                            end
                            GH:RememberGearItem({itemID=item.itemID,name=item.name,icon=item.icon,
                                link=item.link,level=level,filter=item.filterType,
                                instance=job.name,instanceID=job.instanceID,
                                encounter=encounter,encounterID=item.encounterID,
                                difficulty=job.difficulty,tier=job.tier,raid=job.raid,
                                sourceVerified=true})
                        end
                    end
                end
            end
            scan.phase="next"
        end
    end)
end

function GH:SelectGearSearchResult(rec)
    if self.CancelMapSearch then self:CancelMapSearch() end
    self.selectedSearchRec=rec
    self:RefreshGearSearch()
end
function GH:RefreshGearSearch()
    local ui=self.gearSearchUI
    if not ui or not ui.panel or not ui.panel:IsShown() then return end
    self:IndexKnownGear()
    ui.scan.caption:SetText(self.gearCatalogRunning and "STOP INDEXING" or "INDEX ALL DUNGEONS / RAIDS")
    local status=self.gearCatalogRunning and self.gearCatalogStatus or
        self.gearSourceStatus or self.gearCatalogStatus or "Local source index"
    ui.status:SetText(tostring(status).."  |  Saved: "..tostring(self.gearSearchIndexCount or 0))
    for _,b in ipairs(ui.filters or {}) do
        local active=b.gearMode==(self.gearSearchFilter or "All")
        b:SetBackdropColor(active and 0.11 or 0.034,active and 0.20 or 0.070,
            active and 0.34 or 0.120,1)
        b:SetBackdropBorderColor(active and 1 or 0.44,active and 0.82 or 0.57,
            active and 0.30 or 0.75,1)
    end
    local records,count=self:GetGearSearchMatches()
    if self.selectedSearchRec and not self:IsWithinGearLevelRange(self.selectedSearchRec) then
        self.selectedSearchRec=nil
    end
    self.gearSearchMatches=records
    ui.resultCount:SetText(tostring(count or #records).." matches"..((count or 0)>MAX_RESULTS and " (first 150 shown)" or ""))
    ui.scrollChild:SetHeight(math.max(1,#records*51))
    local offset=ui.scroll:GetVerticalScroll() or 0
    local start=math.floor(math.max(0,offset)/51)+1
    for i=1,#ui.rows do
        local row=ui.rows[i]
        local rec=records[start+i-1]
        if rec then
            row:ClearAllPoints();row:SetPoint("TOPLEFT",ui.scrollChild,"TOPLEFT",0,-(start+i-2)*51)
            row.record=rec
            row.icon:SetTexture(self:GetDisplayItemIcon(rec))
            row.name:SetText(rec.name or ("Item #"..rec.itemID))
            row.source:SetText(itemSource(rec))
            row:Show()
            row:SetBackdropBorderColor(rec==self.selectedSearchRec and 1 or 0.28,
                rec==self.selectedSearchRec and 0.8 or 0.40,rec==self.selectedSearchRec and 0.3 or 0.62,1)
        else row.record=nil;row:Hide() end
    end
    local rec=self.selectedSearchRec
    ui.detailIcon:SetTexture(rec and self:GetDisplayItemIcon(rec) or ICON_ROOT.."item-placeholder.tga")
    ui.detailName:SetText(rec and (rec.name or ("Item #"..rec.itemID)) or "Select an item")
    if rec then
        local pieces={"Item ID: "..rec.itemID}
        if rec.level then pieces[#pieces+1]="Known item level: "..rec.level end
        if rec.requiredLevel then pieces[#pieces+1]="Required character level: "..rec.requiredLevel end
        if rec.sourceVerified then
            pieces[#pieces+1]="Verified in the Adventure Guide"
            pieces[#pieces+1]="Source: "..tostring(rec.instance or "Unknown")
            pieces[#pieces+1]="Boss: "..tostring(rec.encounter or "Unknown")
            pieces[#pieces+1]="Difficulty: "..self:DescribeDifficulty(rec.difficulty,rec.raid,rec)
        elseif rec.sourceObserved and rec.sourceType=="Vendor" then
            pieces[#pieces+1]="Found in a merchant window (not a global vendor index)"
            pieces[#pieces+1]="Vendor: "..tostring(rec.vendorName or "Unknown")
            if rec.mapID and rec.mapX and rec.mapY then
                pieces[#pieces+1]="Location: last seen at "..string.format("%.1f, %.1f",rec.mapX*100,rec.mapY*100)
            else pieces[#pieces+1]="Vendor location not captured" end
            if rec.price and rec.price>0 and GetCoinTextureString then
                pieces[#pieces+1]="Cost seen: "..GetCoinTextureString(rec.price)
            end
            if rec.extendedCost then pieces[#pieces+1]="Additional currency/items required (check vendor)" end
        elseif rec.sourceObserved and rec.sourceType=="Quest" then
            pieces[#pieces+1]="Reward shown in the quest window"
            pieces[#pieces+1]="Quest: "..tostring(rec.questName or "Unknown")
            if rec.questID then pieces[#pieces+1]="Quest ID: "..rec.questID end
            pieces[#pieces+1]="Quest giver/location not verified"
        elseif rec.sourceObserved and rec.sourceType=="Crafted" then
            pieces[#pieces+1]="Recipe shown in the profession window"
            pieces[#pieces+1]="Recipe: "..tostring(rec.recipeName or "Unknown")
            if rec.profession then pieces[#pieces+1]="Profession: "..rec.profession end
            pieces[#pieces+1]=(rec.recipeLearned and "Recipe learned on this character" or "Recipe availability not guaranteed")
        elseif rec.owned then
            pieces[#pieces+1]="Seen on this character (inventory or equipped)"
            pieces[#pieces+1]="Original acquisition source not known"
        else
            pieces[#pieces+1]="Source is not in the local index"
            pieces[#pieces+1]="Try indexing the Adventure Guide, or check Wowhead"
        end
        ui.description:SetText(table.concat(pieces,"\n"))
    else
        ui.description:SetText("Search a name, numeric item ID, or item link.\n\nIndex dungeons/raids, or visit merchants, quest reward windows, and profession panels to learn more sources. These are locally observed records, not a live Wowhead database.")
    end
    local verified=rec and rec.sourceVerified and rec.instanceID
    local seenVendor=rec and rec.sourceObserved and rec.sourceType=="Vendor" and
        type(rec.mapID)=="number" and type(rec.mapX)=="number" and type(rec.mapY)=="number"
    ui.map.caption:SetText(seenVendor and "LAST SEEN" or "SHOW ENTRANCE")
    if verified or seenVendor then ui.map:Enable();ui.map:SetAlpha(1)
    else ui.map:Disable();ui.map:SetAlpha(0.35) end
    if verified then ui.guide:Enable();ui.guide:SetAlpha(1)
    else ui.guide:Disable();ui.guide:SetAlpha(0.35) end
    local hasBoss=verified and type(rec.encounterID)=="number"
    if hasBoss then ui.boss:Enable();ui.boss:SetAlpha(1)
    else ui.boss:Disable();ui.boss:SetAlpha(0.35) end
    ui.wowheadBox:SetText(self:GearSearchUrl(rec))
    if ui.huntButton then
        local trackable=rec and type(rec.itemID)=="number"
        if trackable then ui.huntButton:Enable();ui.huntButton:SetAlpha(1)
        else ui.huntButton:Disable();ui.huntButton:SetAlpha(0.38) end
        ui.huntButton.caption:SetText(trackable and (self:IsHuntTracked(rec.itemID) and
            "UPDATE ITEM IN HUNT LIST" or "ADD SELECTED TO HUNT LIST") or "SELECT ITEM TO TRACK")
    end
end

function GH:CreateGearSearchPanel(parent)
    local p=panel(parent,29,-150,1542,558)
    self.gearSearchUI={panel=p}
    local ui=self.gearSearchUI
    font(p,"GEAR SEARCH",18,-13,380,true,gold)
    font(p,"Search saved dungeon/raid drops, merchant stock, quest rewards and profession recipes found in-game.",18,-44,1480,false,pale)
    local search=CreateFrame("EditBox",nil,p,"InputBoxTemplate")
    search:SetPoint("TOPLEFT",p,"TOPLEFT",24,-78)
    search:SetSize(780,33)
    search:SetAutoFocus(false)
    search:SetMaxLetters(120)
    search:SetText(self.gearSearchQuery or "")
    search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed",function(self) self:ClearFocus();GH:RefreshGearSearch() end)
    search:SetScript("OnTextChanged",function(self)
        GH.gearSearchQuery=self:GetText() or ""
        if GH.CancelMapSearch then GH:CancelMapSearch() end
        if ui.scroll then ui.scroll:SetVerticalScroll(0) end
        GH.selectedSearchRec=nil
        GH:RefreshGearSearch()
    end)
    ui.search=search
    button(p,"CLEAR",826,-78,110,32,function() search:SetText("");search:SetFocus() end)
    ui.scan=button(p,"INDEX ALL DUNGEONS / RAIDS",955,-78,354,32,function() GH:StartGearCatalogScan() end)
    ui.capture=button(p,"CAPTURE",1321,-78,95,32,function()
        if GH.CaptureOpenGearSources then GH:CaptureOpenGearSources(true) end
    end)
    ui.bossBrowser=button(p,"BOSS LOOT",1420,-78,101,32,function() GH:ShowTab("Boss Loot Hunter") end)
    ui.status=font(p,"Local catalog not indexed yet",24,-118,1070,false,green)
    ui.resultCount=font(p,"0 matches",1160,-118,342,false,gold)
    local filt={{"ALL","All"},{"DUNGEONS","Dungeon"},{"RAIDS","Raid"},
        {"VENDORS","Vendor"},{"QUESTS","Quest"},{"CRAFTING","Crafted"},{"OWNED","Owned"}}
    ui.filters={}
    for i,entry in ipairs(filt) do
        local b=button(p,entry[1],17+(i-1)*133,-153,128,29,function()
            GH.gearSearchFilter=entry[2]
            GH.selectedSearchRec=nil
            ui.scroll:SetVerticalScroll(0)
            GH:RefreshGearSearch()
        end)
        b.gearMode=entry[2]
        table.insert(ui.filters,b)
    end
    ui.huntButton=button(p,"ADD SELECTED TO HUNT LIST",962,-153,263,29,function()
        if GH.selectedSearchRec then
            GH:AddHuntItem(GH.selectedSearchRec)
            GH:RefreshGearSearch()
        end
    end)
    ui.favoritesButton=button(p,"BOSS FAVORITES",1233,-153,286,29,function()
        GH:OpenBossFavorites()
    end)
    local list=panel(p,17,-192,932,350)
    ui.scroll=CreateFrame("ScrollFrame",nil,list,"UIPanelScrollFrameTemplate")
    ui.scroll:SetPoint("TOPLEFT",list,"TOPLEFT",9,-8)
    ui.scroll:SetPoint("BOTTOMRIGHT",list,"BOTTOMRIGHT",-28,8)
    ui.scrollChild=CreateFrame("Frame",nil,ui.scroll)
    ui.scrollChild:SetSize(882,1)
    ui.scroll:SetScrollChild(ui.scrollChild)
    ui.rows={}
    for i=1,9 do
        local row=CreateFrame("Button",nil,ui.scrollChild,"BackdropTemplate")
        row:SetSize(879,48);frameStyle(row,navy,rim)
        row.icon=row:CreateTexture(nil,"ARTWORK")
        row.icon:SetPoint("LEFT",row,"LEFT",5,0);row.icon:SetSize(39,39)
        row.name=font(row,"",52,-6,804,false,gold)
        row.source=font(row,"",52,-26,804,false,pale)
        row:SetScript("OnClick",function(self) GH:SelectGearSearchResult(self.record) end)
        row:SetScript("OnEnter",function(self)
            local rec=self.record
            if rec and rec.link and GameTooltip then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                local ok=pcall(GameTooltip.SetHyperlink,GameTooltip,rec.link)
                if not ok then GameTooltip:SetText(rec.name or "Item") end
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        row:Hide();ui.rows[#ui.rows+1]=row
    end
    ui.scroll:HookScript("OnVerticalScroll",function() GH:RefreshGearSearch() end)
    local details=panel(p,960,-192,565,350)
    font(details,"ITEM DETAILS / KNOWN SOURCE",12,-13,540,true,gold)
    ui.detailIcon=details:CreateTexture(nil,"ARTWORK")
    ui.detailIcon:SetPoint("TOPLEFT",details,"TOPLEFT",14,-48);ui.detailIcon:SetSize(56,56)
    ui.detailName=font(details,"Select an item",82,-52,462,true,gold)
    ui.detailName:SetHeight(42);ui.detailName:SetWordWrap(true)
    ui.description=font(details,"",17,-117,530,false,pale)
    ui.description:SetHeight(118);ui.description:SetWordWrap(true);ui.description:SetJustifyV("TOP")
    ui.map=button(details,"SHOW ENTRANCE",12,-242,174,36,function()
        local rec=GH.selectedSearchRec
        if not rec then return end
        if rec.sourceObserved and rec.sourceType=="Vendor" and
            rec.mapID and rec.mapX and rec.mapY then
            GH:SetWaypoint(rec.mapID,rec.mapX,rec.mapY,
                "Last observed: "..tostring(rec.vendorName or "Vendor"),"observed")
        elseif rec.sourceVerified then GH:GoToRecord(rec,"entrance") end
    end)
    ui.boss=button(details,"SHOW BOSS",195,-242,174,36,function()
        if GH.selectedSearchRec then GH:GoToRecord(GH.selectedSearchRec,"boss") end
    end)
    ui.guide=button(details,"OPEN GUIDE",378,-242,174,36,function()
        if GH.selectedSearchRec then GH:OpenGuide(GH.selectedSearchRec) end
    end)
    font(details,"WOWHEAD LINK (SELECT AND COPY WITH CTRL+C)",15,-288,540,false,gold)
    ui.wowheadBox=CreateFrame("EditBox",nil,details,"InputBoxTemplate")
    ui.wowheadBox:SetPoint("TOPLEFT",details,"TOPLEFT",23,-312)
    ui.wowheadBox:SetSize(519,29);ui.wowheadBox:SetAutoFocus(false)
    ui.wowheadBox:SetScript("OnEditFocusGained",function(self) self:HighlightText() end)
    ui.wowheadBox:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    p:Hide()
end
