-- Gear Hunter v0.11.4: Favorites inside Boss Loot Hunter. All boss-to-item sources use the
-- validated Encounter Journal catalog; no static/fabricated loot tables.
local addonName, NAV = ...
local GH = NAV.GearEngine
local DARK={0.015,0.035,0.062,0.99}
local BLUE={0.028,0.066,0.112,0.99}
local EDGE={0.38,0.53,0.69,1}
local GOLD={1,0.82,0.30,1}
local PALE={0.79,0.89,1,1}
local GREEN={0.33,1,0.53,1}
local ROW_HEIGHT={instance=37,boss=39,loot=48}
local function style(f,bg,border)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(unpack(bg or DARK))
    f:SetBackdropBorderColor(unpack(border or EDGE))
end
local function box(parent,x,y,w,h)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    f:SetSize(w,h);style(f)
    return f
end
local function text(parent,message,x,y,w,color,large)
    local font=parent:CreateFontString(nil,"OVERLAY",large and "GameFontNormalLarge" or "GameFontNormal")
    font:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    if w then font:SetWidth(w);font:SetJustifyH("LEFT") end
    font:SetTextColor(unpack(color or PALE));font:SetText(message or "")
    return font
end
local function action(parent,title,x,y,w,h,callback)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetSize(w,h)
    style(b,BLUE,EDGE)
    b.caption=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    b.caption:SetAllPoints();b.caption:SetText(title)
    b.caption:SetTextColor(1,0.85,0.48,1)
    b:SetScript("OnClick",callback)
    b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(unpack(GOLD)) end)
    b:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(unpack(EDGE)) end)
    return b
end
local function valid(rec)
    return type(rec)=="table" and rec.sourceVerified==true
        and type(rec.instanceID)=="number" and rec.instanceID>0
        and type(rec.encounterID)=="number" and rec.encounterID>0
        and type(rec.itemID)=="number" and rec.itemID>0
end
local function str(v) return type(v)=="string" and v or "" end
local function byName(a,b)
    local na=str(a.name):lower();local nb=str(b.name):lower()
    if na~=nb then return na<nb end
    return (a.id or 0)<(b.id or 0)
end
local function currentSources(self)
    local src={}
    -- The saved local index survives logout. Session records are merged in,
    -- but each item + boss + difficulty is displayed only once.
    for _,rec in pairs(self.gearSearchIndex or {}) do
        if valid(rec) then src[#src+1]=rec end
    end
    for _,rec in ipairs(self.items or {}) do
        if valid(rec) then src[#src+1]=rec end
    end
    return src
end
function GH:InitBossLootHunter()
    if not self.db then return end
    if type(self.db.bossLootInstances)~="table" then self.db.bossLootInstances={} end
    if type(self.db.bossLootBosses)~="table" then self.db.bossLootBosses={} end
    self.bossLootType=self.bossLootType or "All"
    self.bossLootLootFilter=self.bossLootLootFilter or "All"
    self.bossLootTier=self.bossLootTier or 0
    self.bossLootQuery=self.bossLootQuery or ""
    -- Favorites belong to the account, not to the currently played character.
    -- Each record retains the ID and the display name so bookmarks survive
    -- even when the Adventure Guide cache has not been indexed this session.
    if type(self.db.bossLootFavorites)~="table" then self.db.bossLootFavorites={} end
    local favorites=self.db.bossLootFavorites
    if type(favorites.instances)~="table" then favorites.instances={} end
    if type(favorites.bosses)~="table" then favorites.bosses={} end
    if type(self.bossLootFavoritesOnly)~="boolean" then self.bossLootFavoritesOnly=false end
end
local function bossFavoriteKey(instanceID,encounterID)
    return tostring(instanceID)..":"..tostring(encounterID)
end
function GH:IsFavoriteInstance(instanceID)
    if not self.db then return false end
    self:InitBossLootHunter()
    return instanceID~=nil and self.db.bossLootFavorites.instances[tostring(instanceID)]~=nil
end
function GH:IsFavoriteBoss(instanceID,encounterID)
    if not self.db then return false end
    self:InitBossLootHunter()
    return instanceID~=nil and encounterID~=nil and
        self.db.bossLootFavorites.bosses[bossFavoriteKey(instanceID,encounterID)]~=nil
end
function GH:ToggleFavoriteInstance(instanceID)
    if type(instanceID)~="number" or instanceID<=0 or not self.db then return false end
    self:InitBossLootHunter()
    local key=tostring(instanceID)
    local items=self.db.bossLootFavorites.instances
    if items[key] then items[key]=nil;return false end
    local matched
    for _,rec in ipairs(self:GetBossLootInstances()) do
        if rec.id==instanceID then matched=rec;break end
    end
    -- No phantom favorite can be created without a known instance record.
    if not matched then matched=self.db.bossLootInstances[key] end
    if not matched then return false end
    items[key]={instanceID=instanceID,name=matched.name,
        raid=matched.raid==true,tier=matched.tier}
    return true
end
function GH:ToggleFavoriteBoss(instanceID,encounterID)
    if type(instanceID)~="number" or instanceID<=0 or
       type(encounterID)~="number" or encounterID<=0 or not self.db then return false end
    self:InitBossLootHunter()
    local key=bossFavoriteKey(instanceID,encounterID)
    local saved=self.db.bossLootFavorites.bosses
    if saved[key] then saved[key]=nil;return false end
    local boss
    for _,rec in ipairs(self:GetBossLootBosses(instanceID)) do
        if rec.id==encounterID then boss=rec;break end
    end
    if not boss then return false end
    local inst=self.db.bossLootInstances[tostring(instanceID)]
    saved[key]={instanceID=instanceID,encounterID=encounterID,name=boss.name,
        instanceName=inst and inst.name or ""}
    return true
end
function GH:GetBossFavoriteCount()
    if not self.db then return 0,0 end
    self:InitBossLootHunter()
    local ni,nb=0,0
    for _ in pairs(self.db.bossLootFavorites.instances) do ni=ni+1 end
    for _ in pairs(self.db.bossLootFavorites.bosses) do nb=nb+1 end
    return ni,nb
end
function GH:OpenBossFavorites()
    self:InitBossLootHunter()
    self.bossLootFavoritesOnly=true
    self.bossLootQuery=""
    self.bossLootTier=0
    self.bossLootType="All"
    self.bossLootInstance=nil;self.bossLootEncounter=nil;self.bossLootItemID=nil
    if self.bossLootUI and self.bossLootUI.search then self.bossLootUI.search:SetText("") end
    self:ShowTab("Boss Loot Hunter")
end
-- Called ONLY after the catalog scanner verifies the selected Journal table.
-- Journal encounter IDs are cross-checked against the exact instance ID.
function GH:RememberBossLootInstance(job)
    if not self.db or type(job)~="table" or type(job.instanceID)~="number" then return end
    self:InitBossLootHunter()
    local id=job.instanceID
    self.db.bossLootInstances[tostring(id)]={instanceID=id,name=job.name,
        raid=job.raid==true,tier=job.tier,verifiedFrom="Adventure Guide"}
    if type(EJ_GetEncounterInfoByIndex)~="function" then return end
    for i=1,80 do
        local ok,name,_,encID=pcall(EJ_GetEncounterInfoByIndex,i,id)
        if not ok or not name or not encID then break end
        if type(encID)=="number" and encID>0 and type(name)=="string" and name~="" then
            local belongs=false
            if type(EJ_GetEncounterInfo)=="function" then
                local validCall,_,_,foundID,_,_,owner=pcall(EJ_GetEncounterInfo,encID)
                belongs=validCall and foundID==encID and owner==id
            end
            if belongs then
                local key=tostring(id)..":"..tostring(encID)
                self.db.bossLootBosses[key]={instanceID=id,encounterID=encID,
                    name=name,order=i}
            end
        end
    end
end
function GH:GetBossLootInstances()
    self:InitBossLootHunter()
    local byID={}
    local function include(instanceID,name,raid,tier)
        if type(instanceID)~="number" or instanceID<=0 then return end
        local rec=byID[instanceID]
        if not rec then
            rec={id=instanceID,name=name or ("Instance "..instanceID),
                raid=raid==true,tier=tier,bossCount=0,lootCount=0}
            byID[instanceID]=rec
        end
        if name and name~="" and (not rec.name or rec.name:match("^Instance %d+$")) then rec.name=name end
        if tier then rec.tier=tier end
        if raid~=nil then rec.raid=raid==true end
        return rec
    end
    for _,inst in pairs(self.db.bossLootInstances) do
        if type(inst)=="table" then include(inst.instanceID,inst.name,inst.raid,inst.tier) end
    end
    -- Include remembered favorites even before a fresh journal re-index.
    for _,inst in pairs(self.db.bossLootFavorites.instances) do
        if type(inst)=="table" then include(inst.instanceID,inst.name,inst.raid,inst.tier) end
    end
    for _,boss in pairs(self.db.bossLootFavorites.bosses) do
        if type(boss)=="table" then
            local remembered=self.db.bossLootInstances[tostring(boss.instanceID)]
            include(boss.instanceID,(remembered and remembered.name) or boss.instanceName,
                remembered and remembered.raid,remembered and remembered.tier)
        end
    end
    local seen={}
    for _,source in ipairs(currentSources(self)) do
        local inst=include(source.instanceID,source.instance,source.raid,source.tier)
        local key=source.instanceID..":"..source.encounterID..":"..source.itemID..":"..tostring(source.difficulty or 0)
        if inst and not seen[key] then inst.lootCount=inst.lootCount+1;seen[key]=true end
    end
    local out,mode,query={},self.bossLootType or "All",str(self.bossLootQuery):lower()
    for _,inst in pairs(byID) do
        if (mode=="All" or (mode=="Raid" and inst.raid) or (mode=="Dungeon" and not inst.raid))
            and (self.bossLootTier==0 or inst.tier==self.bossLootTier)
            and (query=="" or str(inst.name):lower():find(query,1,true)) then
            local favorited=self:IsFavoriteInstance(inst.id)
            local bossFavorited=false
            for _,boss in pairs(self.db.bossLootFavorites.bosses) do
                if type(boss)=="table" and boss.instanceID==inst.id then bossFavorited=true;break end
            end
            if not self.bossLootFavoritesOnly or favorited or bossFavorited then
                inst.favorite=favorited
                inst.hasFavoriteBoss=bossFavorited
                out[#out+1]=inst
            end
        end
    end
    table.sort(out,function(a,b)
        if self.bossLootFavoritesOnly and a.favorite~=b.favorite then return a.favorite end
        return byName(a,b)
    end)
    return out
end
function GH:GetBossLootBosses(instanceID)
    if not instanceID then return {} end
    local bosses,seen={},{}
    local function add(encounterID,name,order)
        if type(encounterID)~="number" or encounterID<=0 then return end
        if not seen[encounterID] then
            seen[encounterID]={id=encounterID,name=name or ("Boss "..encounterID),
                order=order or 999,lootCount=0}
            bosses[#bosses+1]=seen[encounterID]
        elseif name and str(seen[encounterID].name):match("^Boss %d+$") then
            seen[encounterID].name=name
        end
    end
    for _,boss in pairs(self.db.bossLootBosses or {}) do
        if type(boss)=="table" and boss.instanceID==instanceID then
            add(boss.encounterID,boss.name,boss.order)
        end
    end
    for _,boss in pairs(self.db.bossLootFavorites.bosses) do
        if type(boss)=="table" and boss.instanceID==instanceID then
            add(boss.encounterID,boss.name)
        end
    end
    local found={}
    for _,rec in ipairs(currentSources(self)) do
        if rec.instanceID==instanceID then
            add(rec.encounterID,rec.encounter)
            local key=rec.encounterID..":"..rec.itemID..":"..tostring(rec.difficulty or 0)
            if not found[key] then
                found[key]=true
                seen[rec.encounterID].lootCount=seen[rec.encounterID].lootCount+1
            end
        end
    end
    local favoriteInstance=self:IsFavoriteInstance(instanceID)
    if self.bossLootFavoritesOnly and not favoriteInstance then
        local only={}
        for _,rec in ipairs(bosses) do
            if self:IsFavoriteBoss(instanceID,rec.id) then only[#only+1]=rec end
        end
        bosses=only
    end
    for _,rec in ipairs(bosses) do
        rec.favorite=self:IsFavoriteBoss(instanceID,rec.id)
    end
    table.sort(bosses,function(a,b)
        if self.bossLootFavoritesOnly and a.favorite~=b.favorite then return a.favorite end
        if a.order~=b.order then return a.order<b.order end
        return byName(a,b)
    end)
    return bosses
end
-- Only report appearance status when the Transmog Hunter collection has
-- actually indexed that item. A missing entry is NOT proof of missing transmog.
function GH:BossLootAppearanceState(itemID)
    if type(itemID)~="number" then return nil end
    local rev=self.transmogResultRevision or 0
    if self.bossLootAppearanceRevision~=rev then
        local byItem={}
        for _,category in pairs(self.transmogCache or {}) do
            if type(category)=="table" then
                for _,appearance in ipairs(category) do
                    if type(appearance)=="table" then
                        for _,id in ipairs(appearance.sourceItemIDs or {}) do
                            if type(id)=="number" then
                                if appearance.isCollected then
                                    if not byItem[id] then byItem[id]="Collected" end
                                else byItem[id]="Missing" end
                            end
                        end
                    end
                end
            end
        end
        self.bossLootAppearanceByItem=byItem
        self.bossLootAppearanceRevision=rev
    end
    return self.bossLootAppearanceByItem and self.bossLootAppearanceByItem[itemID] or nil
end
function GH:GetBossLootItems(instanceID,encounterID)
    local out,seen={},{}
    if not encounterID then return out end
    for _,rec in ipairs(currentSources(self)) do
        if rec.instanceID==instanceID and rec.encounterID==encounterID
            and self:IsWithinGearLevelRange(rec) then
            local key=rec.itemID..":"..tostring(rec.difficulty or 0)
            if not seen[key] then
                seen[key]=rec;out[#out+1]=rec
            elseif (rec.level or 0)>(seen[key].level or 0) then
                for i,old in ipairs(out) do if old==seen[key] then out[i]=rec;break end end
                seen[key]=rec
            end
        end
    end
    local filter=self.bossLootLootFilter or "All"
    if filter~="All" then
        local matches={}
        for _,rec in ipairs(out) do
            local keep=(filter=="Upgrades" and (self:Gain(rec) or 0)>0 and
                self:CanShowForLevel(rec)) or
                (filter=="Hunt List" and self:IsHuntTracked(rec.itemID)) or
                (filter=="Missing Looks" and self:BossLootAppearanceState(rec.itemID)=="Missing")
            if keep then matches[#matches+1]=rec end
        end
        out=matches
    end
    table.sort(out,function(a,b)
        if (a.level or 0)~=(b.level or 0) then return (a.level or 0)>(b.level or 0) end
        if str(a.name)~=str(b.name) then return str(a.name)<str(b.name) end
        return (a.itemID or 0)<(b.itemID or 0)
    end)
    return out
end
local function makeList(parent,x,y,w,h,rowH,visible,onClick)
    local holder=box(parent,x,y,w,h)
    local scroll=CreateFrame("ScrollFrame",nil,holder,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",holder,"TOPLEFT",6,-5)
    scroll:SetPoint("BOTTOMRIGHT",holder,"BOTTOMRIGHT",-28,5)
    local content=CreateFrame("Frame",nil,scroll)
    content:SetSize(w-38,1);scroll:SetScrollChild(content)
    local list={scroll=scroll,content=content,rows={},rowH=rowH}
    for i=1,visible do
        local row=CreateFrame("Button",nil,content,"BackdropTemplate")
        row:SetSize(w-42,rowH-3)
        style(row,BLUE,EDGE)
        row.icon=row:CreateTexture(nil,"ARTWORK")
        row.icon:SetSize(28,28);row.icon:SetPoint("LEFT",row,"LEFT",4,0)
        row.icon:Hide()
        row.name=text(row,"",8,-6,w-65,GOLD)
        row.subtitle=text(row,"",8,-21,w-65,PALE)
        row.name:SetFontObject(GameFontNormalSmall)
        row.subtitle:SetFontObject(GameFontNormalSmall)
        row:SetScript("OnClick",function(self) if self.record then onClick(self.record) end end)
        row:SetScript("OnEnter",function(self)
            if self.record then
                self:SetBackdropBorderColor(unpack(GOLD))
                if self.record.itemID and self.record.link and GameTooltip then
                    GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                    local ok=pcall(GameTooltip.SetHyperlink,GameTooltip,self.record.link)
                    if not ok then GameTooltip:SetText(self.record.name or "Item") end
                    GameTooltip:Show()
                end
            end
        end)
        row:SetScript("OnLeave",function(self)
            self:SetBackdropBorderColor(unpack(EDGE))
            if GameTooltip then GameTooltip:Hide() end
        end)
        row:Hide();list.rows[#list.rows+1]=row
    end
    return list
end
local function drawList(list,records,selected,isItem,gh)
    list.content:SetHeight(math.max(1,#records*list.rowH))
    local first=math.floor((list.scroll:GetVerticalScroll() or 0)/list.rowH)
    for i,row in ipairs(list.rows) do
        local pos=first+i
        local rec=records[pos]
        if rec then
            row.record=rec
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT",list.content,"TOPLEFT",0,-(pos-1)*list.rowH)
            if rec.id==selected or (isItem and rec.itemID==selected) then
                row:SetBackdropBorderColor(unpack(GOLD))
            else row:SetBackdropBorderColor(unpack(EDGE)) end
            if isItem then
                row.icon:Show();row.icon:SetTexture(gh:GetDisplayItemIcon(rec))
                row.name:ClearAllPoints();row.name:SetPoint("TOPLEFT",row,"TOPLEFT",37,-5)
                row.subtitle:ClearAllPoints();row.subtitle:SetPoint("TOPLEFT",row,"TOPLEFT",37,-22)
                local gain=gh:Gain(rec)
                row.name:SetText(str(rec.name)~="" and rec.name or ("Item "..rec.itemID))
                local indicator=(gain and gain>0 and ("  |cff55ff77+"..gain.."|r") or "")
                local appearance=gh:BossLootAppearanceState(rec.itemID)
                local look=appearance=="Missing" and "  |cffd8a6ffMISSING LOOK|r" or
                    (appearance=="Collected" and "  |cff66ffaaLOOK SAVED|r" or "")
                row.subtitle:SetText((rec.level and "iLvl "..rec.level or "Item level unknown")..indicator..look..
                    "  /  "..gh:DescribeDifficulty(rec.difficulty,rec.raid,rec))
            else
                row.icon:Hide()
                row.name:ClearAllPoints();row.name:SetPoint("TOPLEFT",row,"TOPLEFT",8,-5)
                row.subtitle:ClearAllPoints();row.subtitle:SetPoint("TOPLEFT",row,"TOPLEFT",8,-21)
                local prefix=(rec.favorite and "|cffffd65a[STAR] |r" or
                    (rec.hasFavoriteBoss and "|cffb5d9ff[*] |r" or ""))
                row.name:SetText(prefix..(rec.name or "Unknown"))
                row.subtitle:SetText((rec.lootCount or 0).." indexed loot entries")
            end
            row:Show()
        else row.record=nil;row:Hide() end
    end
end
function GH:RefreshBossLootHunter()
    local ui=self.bossLootUI
    if not ui or not ui.panel:IsShown() then return end
    self:InitBossLootHunter()
    self:IndexKnownGear()
    local instances=self:GetBossLootInstances()
    local selectedInstance
    for _,r in ipairs(instances) do if r.id==self.bossLootInstance then selectedInstance=r;break end end
    if not selectedInstance then
        selectedInstance=instances[1]
        self.bossLootInstance=selectedInstance and selectedInstance.id or nil
        self.bossLootEncounter=nil;self.bossLootItem=nil
    end
    local bosses=self:GetBossLootBosses(self.bossLootInstance)
    local selectedBoss
    for _,b in ipairs(bosses) do if b.id==self.bossLootEncounter then selectedBoss=b;break end end
    if not selectedBoss then
        selectedBoss=bosses[1];self.bossLootEncounter=selectedBoss and selectedBoss.id or nil
        self.bossLootItem=nil
    end
    local items=self:GetBossLootItems(self.bossLootInstance,self.bossLootEncounter)
    local selectedItem
    for _,r in ipairs(items) do
        if r.itemID==self.bossLootItemID and r.difficulty==self.bossLootItemDifficulty then
            selectedItem=r;break
        end
    end
    if not selectedItem then
        selectedItem=items[1]
        self.bossLootItemID=selectedItem and selectedItem.itemID or nil
        self.bossLootItemDifficulty=selectedItem and selectedItem.difficulty or nil
    end
    local favoritesInstances,favoritesBosses=self:GetBossFavoriteCount()
    ui.favorites.caption:SetText(self.bossLootFavoritesOnly and "SHOW ALL" or
        ("FAVORITES ("..(favoritesInstances+favoritesBosses)..")"))
    ui.favoriteInstance.caption:SetText(self:IsFavoriteInstance(self.bossLootInstance) and "REMOVE INSTANCE STAR" or "SAVE INSTANCE")
    ui.favoriteBoss.caption:SetText(self:IsFavoriteBoss(self.bossLootInstance,self.bossLootEncounter) and "REMOVE BOSS STAR" or "SAVE BOSS")
    ui.favoriteInstance:SetEnabled(selectedInstance~=nil)
    ui.favoriteInstance:SetAlpha(selectedInstance and 1 or 0.4)
    ui.favoriteBoss:SetEnabled(selectedBoss~=nil)
    ui.favoriteBoss:SetAlpha(selectedBoss and 1 or 0.4)
    ui.type.caption:SetText("TYPE: "..string.upper(self.bossLootType or "All"))
    ui.lootFilter.caption:SetText("LOOT: "..string.upper(self.bossLootLootFilter or "All"))
    local tiers={0};local known={}
    for _,r in pairs(self.db.bossLootInstances or {}) do
        if type(r)=="table" and type(r.tier)=="number" then known[r.tier]=true end
    end
    for _,r in ipairs(currentSources(self)) do if type(r.tier)=="number" then known[r.tier]=true end end
    for tier in pairs(known) do tiers[#tiers+1]=tier end
    table.sort(tiers)
    local tierTitle="JOURNAL TIER "..tostring(self.bossLootTier)
    if self.bossLootTier~=0 and type(EJ_GetTierInfo)=="function" then
        local ok,name=pcall(EJ_GetTierInfo,self.bossLootTier)
        if ok and type(name)=="string" and name~="" then tierTitle=name end
    end
    ui.tier.caption:SetText(self.bossLootTier==0 and "ALL EXPANSIONS" or tierTitle)
    ui.availableTiers=tiers
    ui.index.caption:SetText(self.gearCatalogRunning and "STOP INDEXING" or "INDEX ADVENTURE GUIDE")
    ui.status:SetText(self.gearCatalogRunning and (self.gearCatalogStatus or "Indexing...") or
        (""..#instances.." instances  /  "..#bosses.." bosses  /  "..#items.." loot entries"))
    ui.selection:SetText(selectedInstance and ((selectedInstance.raid and "RAID" or "DUNGEON")..
        "  /  "..selectedInstance.name.."  /  "..(selectedBoss and selectedBoss.name or "Select a boss")) or
        (self.bossLootFavoritesOnly and
            "No saved favorites found. Switch to SHOW ALL and bookmark a dungeon, raid, or boss." or
            "Index the Adventure Guide to discover dungeon and raid bosses."))
    drawList(ui.instances,instances,self.bossLootInstance,false,self)
    drawList(ui.bosses,bosses,self.bossLootEncounter,false,self)
    drawList(ui.loot,items,self.bossLootItemID,true,self)
    if selectedItem then
        ui.itemIcon:SetTexture(self:GetDisplayItemIcon(selectedItem))
        ui.itemIcon:Show()
        ui.itemName:SetText(selectedItem.name or ("Item "..selectedItem.itemID))
        local gain=self:Gain(selectedItem)
        ui.description:SetText("Boss: "..tostring(selectedItem.encounter or "Unknown")..
            "\nInstance: "..tostring(selectedItem.instance or "Unknown")..
            "\nDifficulty: "..self:DescribeDifficulty(selectedItem.difficulty,selectedItem.raid,selectedItem)..
            "\nKnown item level: "..tostring(selectedItem.level or "not cached")..
            "\n"..(gain and gain>0 and ("Potential iLvl improvement: +"..gain) or "No confirmed item-level improvement")..
            "\n"..(self:IsHuntTracked(selectedItem.itemID) and "On your Hunt List" or "Not on your Hunt List")..
            "\n"..(self:BossLootAppearanceState(selectedItem.itemID) and
                ("Indexed appearance: "..self:BossLootAppearanceState(selectedItem.itemID)) or
                "Appearance not indexed (check Transmog Hunter)")..
            "\nVerified against this Encounter Journal boss.")
    else
        local filtered=(self.bossLootLootFilter or "All")~="All"
        ui.itemIcon:Hide()
        ui.itemName:SetText(selectedBoss and (filtered and "No loot matches this filter" or
            "No indexed equipment for this boss") or "Choose a boss")
        ui.description:SetText(selectedBoss and (filtered and
            "Switch LOOT back to ALL to see the complete indexed boss loot list.\n\nAn empty filter is not proof that the boss drops nothing." or
            "This boss has no verified gear in your saved index yet.\n\nIndex the Adventure Guide to discover its equipment. Empty results do not mean this boss drops nothing.") or
            "Choose a raid or dungeon and a boss to see its indexed equipment.")
    end
    ui.selectedItem=selectedItem
    for _,btn in ipairs({ui.hunt,ui.map,ui.bossMap,ui.guide}) do
        btn:SetEnabled(selectedItem~=nil)
        btn:SetAlpha(selectedItem and 1 or 0.36)
    end
    ui.hunt.caption:SetText(selectedItem and (self:IsHuntTracked(selectedItem.itemID) and "ON HUNT LIST - UPDATE" or "ADD TO HUNT LIST") or "SELECT AN ITEM FIRST")
    ui.empty:SetText(self.bossLootFavoritesOnly and
        "No saved favorites match these filters. Choose SHOW ALL, then save a dungeon, raid, or boss." or
        "No bosses indexed yet. Click INDEX ADVENTURE GUIDE to collect verified boss and loot data.")
    ui.empty:SetShown(#instances==0)
end
function GH:CreateBossLootPanel(parent)
    local p=box(parent,29,-150,1542,558)
    local ui={panel=p};self.bossLootUI=ui
    text(p,"BOSS LOOT HUNTER",16,-11,800,GOLD,true)
    action(p,"FARM SESSION TRACKER",1253,-9,271,31,function() GH:ShowTab("Farm Session") end)
    text(p,"Browse actual Adventure Guide bosses and the equipment Gear Hunter has verified for each.",16,-42,1460,PALE)
    ui.back=action(p,"BACK TO GEAR SEARCH",14,-77,178,32,function() GH:ShowTab("Gear Search") end)
    ui.tier=action(p,"ALL EXPANSIONS",201,-77,196,32,function()
        local opts=ui.availableTiers or {0};local n=1
        for i,value in ipairs(opts) do if value==GH.bossLootTier then n=i;break end end
        GH.bossLootTier=opts[(n%#opts)+1];GH.bossLootInstance=nil
        ui.instances.scroll:SetVerticalScroll(0);GH:RefreshBossLootHunter()
    end)
    ui.type=action(p,"TYPE: ALL",405,-77,142,32,function()
        local options={"All","Raid","Dungeon"};local i=1
        for k,v in ipairs(options) do if v==GH.bossLootType then i=k;break end end
        GH.bossLootType=options[(i%3)+1];GH.bossLootInstance=nil
        ui.instances.scroll:SetVerticalScroll(0);GH:RefreshBossLootHunter()
    end)
    text(p,"SEARCH INSTANCE",570,-59,320,GOLD)
    local search=CreateFrame("EditBox",nil,p,"InputBoxTemplate")
    search:SetPoint("TOPLEFT",p,"TOPLEFT",566,-78);search:SetSize(384,30)
    search:SetAutoFocus(false);search:SetMaxLetters(90)
    search:SetText(self.bossLootQuery or "")
    search:SetScript("OnTextChanged",function(self)
        GH.bossLootQuery=self:GetText() or "";GH.bossLootInstance=nil
        if ui.instances then ui.instances.scroll:SetVerticalScroll(0);GH:RefreshBossLootHunter() end
    end)
    search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    ui.search=search
    action(p,"CLEAR",963,-77,100,32,function() search:SetText("") end)
    ui.index=action(p,"INDEX ADVENTURE GUIDE",1075,-77,451,32,function() GH:StartGearCatalogScan();GH:RefreshBossLootHunter() end)
    ui.status=text(p,"",16,-117,495,GREEN)
    if ui.status.SetWordWrap then ui.status:SetWordWrap(false) end
    ui.favoriteInstance=action(p,"SAVE INSTANCE",521,-111,180,28,function()
        if GH.bossLootInstance then
            GH:ToggleFavoriteInstance(GH.bossLootInstance)
            GH:RefreshBossLootHunter()
        end
    end)
    ui.favoriteBoss=action(p,"SAVE BOSS",709,-111,180,28,function()
        if GH.bossLootInstance and GH.bossLootEncounter then
            GH:ToggleFavoriteBoss(GH.bossLootInstance,GH.bossLootEncounter)
            GH:RefreshBossLootHunter()
        end
    end)
    ui.favorites=action(p,"FAVORITES",898,-111,288,28,function()
        GH.bossLootFavoritesOnly=not GH.bossLootFavoritesOnly
        GH.bossLootInstance=nil;GH.bossLootEncounter=nil;GH.bossLootItemID=nil
        ui.instances.scroll:SetVerticalScroll(0)
        ui.bosses.scroll:SetVerticalScroll(0)
        GH:RefreshBossLootHunter()
    end)
    ui.lootFilter=action(p,"LOOT: ALL",1197,-111,329,28,function()
        local opts={"All","Upgrades","Hunt List","Missing Looks"};local i=1
        for n,mode in ipairs(opts) do if mode==GH.bossLootLootFilter then i=n;break end end
        GH.bossLootLootFilter=opts[(i%#opts)+1]
        ui.loot.scroll:SetVerticalScroll(0);GH:RefreshBossLootHunter()
    end)
    ui.selection=text(p,"",15,-140,1490,GOLD)
    text(p,"DUNGEONS & RAIDS",21,-165,290,GOLD)
    text(p,"BOSSES",335,-165,270,GOLD)
    text(p,"VERIFIED EQUIPMENT DROPS",631,-165,470,GOLD)
    text(p,"SELECTED LOOT / SOURCE",1132,-165,385,GOLD)
    ui.instances=makeList(p,14,-186,305,354,ROW_HEIGHT.instance,9,function(rec)
        GH.bossLootInstance=rec.id;GH.bossLootEncounter=nil;GH.bossLootItemID=nil
        ui.bosses.scroll:SetVerticalScroll(0);ui.loot.scroll:SetVerticalScroll(0)
        GH:RefreshBossLootHunter()
    end)
    ui.bosses=makeList(p,327,-186,286,354,ROW_HEIGHT.boss,8,function(rec)
        GH.bossLootEncounter=rec.id;GH.bossLootItemID=nil
        ui.loot.scroll:SetVerticalScroll(0);GH:RefreshBossLootHunter()
    end)
    ui.loot=makeList(p,621,-186,495,354,ROW_HEIGHT.loot,7,function(rec)
        GH.bossLootItemID=rec.itemID;GH.bossLootItemDifficulty=rec.difficulty
        GH:RefreshBossLootHunter()
    end)
    local detail=box(p,1124,-186,404,354)
    ui.itemIcon=detail:CreateTexture(nil,"ARTWORK")
    ui.itemIcon:SetPoint("TOPLEFT",detail,"TOPLEFT",12,-15);ui.itemIcon:SetSize(48,48)
    ui.itemName=text(detail,"Choose an item",72,-17,317,GOLD,true)
    ui.itemName:SetHeight(45);ui.itemName:SetWordWrap(true)
    ui.description=text(detail,"",13,-79,378,PALE)
    ui.description:SetHeight(188);ui.description:SetWordWrap(true);ui.description:SetJustifyV("TOP")
    ui.hunt=action(detail,"ADD TO HUNT LIST",12,-277,181,31,function()
        if ui.selectedItem then GH:AddHuntItem(ui.selectedItem);GH:RefreshBossLootHunter() end
    end)
    ui.guide=action(detail,"OPEN GUIDE",204,-277,188,31,function()
        if ui.selectedItem then GH:OpenGuide(ui.selectedItem) end
    end)
    ui.map=action(detail,"SHOW ENTRANCE",12,-314,181,31,function()
        if ui.selectedItem then GH:GoToRecord(ui.selectedItem,"entrance") end
    end)
    ui.bossMap=action(detail,"SHOW BOSS",204,-314,188,31,function()
        if ui.selectedItem then GH:GoToRecord(ui.selectedItem,"boss") end
    end)
    ui.empty=text(p,"No bosses indexed yet. Click INDEX ADVENTURE GUIDE to collect verified boss and loot data.",29,-250,1050,PALE)
    ui.empty:SetWordWrap(true)
    ui.instances.scroll:HookScript("OnVerticalScroll",function() GH:RefreshBossLootHunter() end)
    ui.bosses.scroll:HookScript("OnVerticalScroll",function() GH:RefreshBossLootHunter() end)
    ui.loot.scroll:HookScript("OnVerticalScroll",function() GH:RefreshBossLootHunter() end)
    p:Hide()
end
