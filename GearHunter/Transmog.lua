-- Gear Hunter 0.10.4 - Transmog Hunter
-- Retail collection-based appearance browser, collection-state filters and
-- persistent appearance goals. No network/Wowhead queries or invented sources.
local addonName, GH = ...
local ROOT = "Interface\\AddOns\\GearHunter\\Art\\UIIcons\\"
local INK={0.020,0.040,0.078,0.99}
local NAVY={0.034,0.070,0.120,1}
local RIM={0.44,0.57,0.75,1}
local GOLD={1.0,0.82,0.30,1}
local PALE={0.82,0.89,1.0,1}
local GREEN={0.35,1.0,0.57,1}
local categories={
    {1,"Head"},{2,"Shoulders"},{3,"Back"},{4,"Chest"},{5,"Shirt"},
    {6,"Tabard"},{7,"Wrists"},{8,"Hands"},{9,"Waist"},{10,"Legs"},
    {11,"Feet"},{12,"Wands"},{13,"1H Axes"},{14,"1H Swords"},
    {15,"1H Maces"},{16,"Daggers"},{17,"Fist Weapons"},{18,"Shields"},
    {19,"Off-Hands"},{20,"2H Axes"},{21,"2H Swords"},{22,"2H Maces"},
    {23,"Staves"},{24,"Polearms"},{25,"Bows"},{26,"Guns"},
    {27,"Crossbows"},{28,"Warglaives"},{29,"Paired Weapons"},
}
local categoryNames={[0]="All Indexed"}
for _,c in ipairs(categories) do categoryNames[c[1]]=c[2] end
local function style(f,b,e)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(unpack(b or INK));f:SetBackdropBorderColor(unpack(e or RIM))
end
local function panel(parent,x,y,w,h)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);f:SetSize(w,h);style(f)
    return f
end
local function font(parent,t,x,y,w,large,color)
    local f=parent:CreateFontString(nil,"OVERLAY",large and "GameFontNormalLarge" or "GameFontNormal")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    if w then f:SetWidth(w);f:SetJustifyH("LEFT") end
    f:SetTextColor(unpack(color or PALE));f:SetText(t or "")
    return f
end
local function button(parent,t,x,y,w,h,fn)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetSize(w,h);style(b,NAVY,RIM)
    b.caption=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
    b.caption:SetAllPoints();b.caption:SetTextColor(1,0.87,0.56,1);b.caption:SetText(t)
    b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(unpack(GOLD)) end)
    b:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(unpack(RIM)) end)
    b:SetScript("OnClick",fn)
    return b
end
local function validID(n)
    return type(n)=="number" and n>0 and n<100000000
end
local function goalKey(rec)
    return tostring(rec.category)..":"..tostring(rec.visualID)
end
local function haveCollection()
    return C_TransmogCollection and type(C_TransmogCollection.GetCategoryAppearances)=="function"
        and type(C_TransmogCollection.GetAppearanceSources)=="function"
end
local function readName(id,default)
    if validID(id) and type(GetItemInfo)=="function" then
        local ok,name=pcall(GetItemInfo,id)
        if ok and type(name)=="string" and name~="" then return name end
    end
    return default
end
local function iconFor(id)
    if not validID(id) then return nil end
    if C_Item and C_Item.GetItemIconByID then
        local ok,result=pcall(C_Item.GetItemIconByID,id)
        if ok and result then return result end
    end
    if GetItemIcon then
        local ok,result=pcall(GetItemIcon,id)
        if ok and result then return result end
    end
end
local function knownSources(gh,rec)
    local results={}
    if not rec then return results end
    local ids={}
    if validID(rec.itemID) then ids[rec.itemID]=true end
    for _,id in ipairs(rec.sourceItemIDs or {}) do if validID(id) then ids[id]=true end end
    for _,entry in pairs(gh.gearSearchIndex or {}) do
        if type(entry)=="table" and ids[entry.itemID] and (entry.sourceVerified or entry.sourceObserved) then
            results[#results+1]=entry
        end
    end
    table.sort(results,function(a,b)
        if a.sourceVerified~=b.sourceVerified then return a.sourceVerified end
        local an=tostring(a.instance or a.vendorName or a.questName or a.recipeName or "")
        local bn=tostring(b.instance or b.vendorName or b.questName or b.recipeName or "")
        if an~=bn then return an<bn end
        return (a.itemID or 0)<(b.itemID or 0)
    end)
    return results
end
function GH:InitTransmogHunter()
    if self.db then
        if type(self.db.transmogGoals)~="table" then self.db.transmogGoals={} end
    end
    self.transmogCache=self.transmogCache or {}
    self.transmogCategory=self.transmogCategory or 1
    self.transmogFilter=self.transmogFilter or "Missing"
    self.transmogQuery=self.transmogQuery or ""
end
function GH:IsTransmogTracked(rec)
    return rec and self.db and self.db.transmogGoals and self.db.transmogGoals[goalKey(rec)]~=nil
end
function GH:ToggleTransmogGoal(rec)
    if not rec or not self.db then return end
    self:InitTransmogHunter()
    local key=goalKey(rec)
    if self.db.transmogGoals[key] then
        self.db.transmogGoals[key]=nil
        self:Print("Removed transmog target: "..tostring(rec.name))
    else
        self.db.transmogGoals[key]={category=rec.category,visualID=rec.visualID,
            itemID=rec.itemID,name=rec.name,icon=rec.icon}
        self:Print("Tracking appearance: "..tostring(rec.name))
    end
    self.transmogResultRevision=(self.transmogResultRevision or 0)+1
    self:RefreshTransmogHunter()
end
local function materializeAppearance(gh,entry,cat)
    if type(entry)~="table" or not validID(entry.visualID) then return nil end
    local info={visualID=entry.visualID,category=cat,
        isCollected=entry.isCollected==true,isHideVisual=entry.isHideVisual==true,
        isUsable=entry.isUsable~=false,sourceItemIDs={}}
    if info.isHideVisual then return nil end
    local ok,sources=pcall(C_TransmogCollection.GetAppearanceSources,entry.visualID,cat)
    if ok and type(sources)=="table" then
        local seen={};local fallback,found
        for _,src in ipairs(sources) do
            local id=src and src.itemID
            if validID(id) and not seen[id] then
                seen[id]=true
                info.sourceItemIDs[#info.sourceItemIDs+1]=id
                local name=readName(id,src.name)
                if not fallback then fallback={id=id,name=name,sourceID=src.sourceID} end
                if not found and name and name~="" then found={id=id,name=name,sourceID=src.sourceID} end
                if #info.sourceItemIDs>=80 then break end
            end
        end
        local best=found or fallback
        if best then
            info.itemID=best.id;info.sourceID=best.sourceID
            info.name=best.name
        end
    end
    info.name=info.name or ("Appearance #"..entry.visualID)
    info.icon=iconFor(info.itemID)
    if not info.icon and validID(info.sourceID) and C_TransmogCollection.GetSourceIcon then
        local success,img=pcall(C_TransmogCollection.GetSourceIcon,info.sourceID)
        if success then info.icon=img end
    end
    if not info.icon then info.icon=ROOT.."item-placeholder.tga" end
    return info
end
local worker=CreateFrame("Frame")
function GH:StartTransmogCatalogScan(all)
    self:InitTransmogHunter()
    if not haveCollection() then
        self.transmogStatus="Appearance Collection APIs unavailable in this client"
        self:RefreshTransmogHunter();return
    end
    self.transmogScan=nil
    worker:SetScript("OnUpdate",nil)
    if all then self.transmogAllIndexed=false end
    local targets={}
    if all then
        for _,c in ipairs(categories) do targets[#targets+1]=c[1] end
    else targets[1]=self.transmogCategory end
    self.transmogScan={categories=targets,index=0,list=nil,pos=1,processed=0,all=all}
    self.transmogStatus="Loading appearances from Blizzard's collection..."
    worker:SetScript("OnUpdate",function(_,elapsed)
        local job=GH.transmogScan
        if not job then worker:SetScript("OnUpdate",nil);return end
        local processed=0
        while processed<30 do
            if not job.list then
                job.index=job.index+1
                local category=job.categories[job.index]
                if not category then
                    GH.transmogStatus="Collection scan complete: "..job.processed.." appearances read"
                    if job.all then GH.transmogAllIndexed=true end
                    GH.transmogScan=nil;worker:SetScript("OnUpdate",nil)
                    GH:RefreshTransmogHunter();return
                end
                local ok,entries=pcall(C_TransmogCollection.GetCategoryAppearances,category)
                job.list=(ok and type(entries)=="table") and entries or {}
                job.currentCategory=category
                job.records={}
                job.pos=1
            end
            local entry=job.list[job.pos]
            if not entry then
                GH.transmogCache[job.currentCategory]=job.records
                GH.transmogResultRevision=(GH.transmogResultRevision or 0)+1
                job.list=nil;job.records=nil
                GH:RefreshTransmogHunter()
            else
                local rec=materializeAppearance(GH,entry,job.currentCategory)
                if rec then
                    job.records[#job.records+1]=rec
                    job.processed=job.processed+1
                end
                job.pos=job.pos+1
                processed=processed+1
            end
        end
        if job.index and job.currentCategory then
            GH.transmogStatus="Indexing "..(categoryNames[job.currentCategory] or "appearances")..
                "  |  "..job.processed.." found"
        end
    end)
    self:RefreshTransmogHunter()
end
function GH:ReloadTransmogCategory()
    if self.transmogCategory==0 then
        self:StartTransmogCatalogScan(true)
        return
    end
    if not haveCollection() then
        self.transmogStatus="Appearance Collection unavailable"
        return
    end
    self:StartTransmogCatalogScan(false)
end
function GH:SetTransmogCategory(n)
    self:InitTransmogHunter()
    local max=#categories
    if n<0 then n=max elseif n>max then n=0 end
    self.transmogCategory=n
    self.selectedTransmog=nil
    self.transmogSourceIndex=1
    if self.transmogUI and self.transmogUI.scroll then self.transmogUI.scroll:SetVerticalScroll(0) end
    if (n==0 and not self.transmogAllIndexed) or (n~=0 and not self.transmogCache[n]) then
        self:ReloadTransmogCategory()
    end
    self:RefreshTransmogHunter()
end
function GH:GetTransmogMatches()
    local token=table.concat({tostring(self.transmogCategory or 1),
        tostring(self.transmogFilter or "Missing"),tostring(self.transmogQuery or ""),
        tostring(self.transmogResultRevision or 0)},"|")
    if self.transmogResultsToken==token and self.transmogCachedResults then
        return self.transmogCachedResults
    end
    local results={}
    local search=tostring(self.transmogQuery or ""):lower():gsub("^%s+",""):gsub("%s+$","")
    local filter=self.transmogFilter or "Missing"
    local category=self.transmogCategory or 1
    local records={}
    if category==0 then
        for _,cache in pairs(self.transmogCache or {}) do
            for _,rec in ipairs(cache) do records[#records+1]=rec end
        end
    else
        records=self.transmogCache and self.transmogCache[category] or {}
    end
    local goals=self.db and self.db.transmogGoals or {}
    for _,rec in ipairs(records) do
        local key=goalKey(rec)
        local include=(filter=="All" or (filter=="Missing" and not rec.isCollected)
            or (filter=="Collected" and rec.isCollected) or (filter=="Tracked" and goals[key]))
        if include and (search=="" or tostring(rec.name or ""):lower():find(search,1,true)
                or tostring(rec.itemID or "")==search or tostring(rec.visualID)==search) then
            results[#results+1]=rec
        end
    end
    table.sort(results,function(a,b)
        if a.isCollected~=b.isCollected then return not a.isCollected end
        local aName,bName=(a.name or ""):lower(),(b.name or ""):lower()
        if aName~=bName then return aName<bName end
        return a.visualID<b.visualID
    end)
    self.transmogResultsToken=token
    self.transmogCachedResults=results
    return results
end
function GH:SelectTransmog(rec)
    self.selectedTransmog=rec;self.transmogSourceIndex=1
    self.transmogSourceCacheFor=nil
    self:RefreshTransmogHunter()
end
function GH:RefreshTransmogHunter()
    local ui=self.transmogUI
    if not ui or not ui.panel:IsShown() then return end
    self:InitTransmogHunter()
    if not self.transmogScan and (
        (self.transmogCategory==0 and not self.transmogAllIndexed) or
        (self.transmogCategory~=0 and not self.transmogCache[self.transmogCategory])) then
        self:ReloadTransmogCategory()
    end
    ui.category.caption:SetText((categoryNames[self.transmogCategory] or "Category"):upper())
    local completed=0
    for _ in pairs(self.transmogCache) do completed=completed+1 end
    ui.index.caption:SetText(self.transmogScan and "STOP INDEXING" or "INDEX ALL CATEGORIES")
    ui.status:SetText((self.transmogStatus or "Browse appearances from Blizzard's Collection")..
        "  |  Categories ready: "..completed.." / "..#categories)
    for _,b in ipairs(ui.filters) do
        local active=b.mode==(self.transmogFilter or "Missing")
        b:SetBackdropColor(active and 0.11 or 0.034,active and 0.20 or 0.070,active and 0.34 or 0.12,1)
        b:SetBackdropBorderColor(active and 1 or 0.44,active and 0.82 or 0.57,active and 0.3 or 0.75,1)
    end
    local results=self:GetTransmogMatches()
    self.transmogResults=results
    ui.resultCount:SetText(#results.." appearances")
    ui.scrollChild:SetHeight(math.max(1,#results*48))
    if ui.emptyState then
        local empty=#results==0
        ui.emptyState:SetShown(empty)
        if empty then
            if self.transmogScan then
                ui.emptyTitle:SetText("INDEXING APPEARANCES...")
                ui.emptyMessage:SetText(""..(self.transmogStatus or "Reading the collection").."\nResults will appear when this category finishes indexing.")
            elseif (self.transmogQuery or "")~="" then
                ui.emptyTitle:SetText("NO MATCHES FOUND")
                ui.emptyMessage:SetText("Clear the search, choose ALL, or try another appearance name or item ID.")
            elseif (self.transmogFilter or "Missing")=="Tracked" then
                ui.emptyTitle:SetText("NO APPEARANCES TRACKED")
                ui.emptyMessage:SetText("Select an appearance and choose TRACK APPEARANCE to add it here.")
            else
                ui.emptyTitle:SetText("NO APPEARANCES IN THIS VIEW")
                ui.emptyMessage:SetText("Choose ALL, switch categories, or click INDEX ALL CATEGORIES to expand the collection index.")
            end
        end
    end
    local start=math.floor(math.max(0,ui.scroll:GetVerticalScroll() or 0)/48)+1
    for i,row in ipairs(ui.rows) do
        local rec=results[start+i-1]
        if rec then
            row.record=rec;row:ClearAllPoints()
            row:SetPoint("TOPLEFT",ui.scrollChild,"TOPLEFT",0,-(start+i-2)*48)
            row.icon:SetTexture(rec.icon or ROOT.."item-placeholder.tga")
            row.title:SetText(rec.name)
            row.subtitle:SetText((rec.isCollected and "COLLECTED" or "MISSING")..
                (self:IsTransmogTracked(rec) and "  |  TRACKED" or "")..
                "  |  "..(categoryNames[rec.category] or ""))
            row:SetBackdropBorderColor(rec==self.selectedTransmog and 1 or 0.28,
                rec==self.selectedTransmog and 0.82 or 0.4,rec==self.selectedTransmog and 0.30 or 0.62,1)
            row:Show()
        else row.record=nil;row:Hide() end
    end
    local rec=self.selectedTransmog
    if self.transmogSourceCacheFor~=rec or self.transmogSourceCacheCount~=(self.gearSearchIndexCount or 0) then
        self.transmogKnownSources=knownSources(self,rec)
        self.transmogSourceCacheFor=rec
        self.transmogSourceCacheCount=self.gearSearchIndexCount or 0
    end
    local known=self.transmogKnownSources or {}
    local sourceIndex=self.transmogSourceIndex or 1
    if sourceIndex>#known then sourceIndex=1;self.transmogSourceIndex=1 end
    local source=known[sourceIndex]
    ui.detailIcon:SetTexture(rec and (rec.icon or ROOT.."item-placeholder.tga") or ROOT.."item-placeholder.tga")
    ui.detailName:SetText(rec and rec.name or "Choose an appearance")
    ui.track.caption:SetText(rec and self:IsTransmogTracked(rec) and "REMOVE TARGET" or "TRACK APPEARANCE")
    ui.track:SetEnabled(rec~=nil);ui.track:SetAlpha(rec and 1 or 0.4)
    ui.toSearch:SetEnabled(rec and validID(rec.itemID) or false)
    ui.toSearch:SetAlpha(rec and validID(rec.itemID) and 1 or 0.4)
    ui.sourcePrevious:SetEnabled(#known>1);ui.sourceNext:SetEnabled(#known>1)
    ui.sourcePrevious:SetAlpha(#known>1 and 1 or 0.4)
    ui.sourceNext:SetAlpha(#known>1 and 1 or 0.4)
    local canMap=source and ((source.sourceVerified and source.instanceID) or
        (source.sourceObserved and source.sourceType=="Vendor" and source.mapID and source.mapX and source.mapY))
    ui.map:SetEnabled(canMap and true or false);ui.map:SetAlpha(canMap and 1 or 0.4)
    local canBoss=source and source.sourceVerified and type(source.encounterID)=="number"
    ui.boss:SetEnabled(canBoss and true or false);ui.boss:SetAlpha(canBoss and 1 or 0.4)
    ui.map.caption:SetText(source and source.sourceType=="Vendor" and "LAST SEEN" or "SHOW ENTRANCE")
    if rec then
        local lines={rec.isCollected and "Appearance collected" or "Appearance not collected",
            "Appearance ID: "..rec.visualID,"Category: "..(categoryNames[rec.category] or "Unknown")}
        if rec.itemID then lines[#lines+1]="Example source item ID: "..rec.itemID end
        if #known>0 then
            lines[#lines+1]="KNOWN LOCALLY INDEXED SOURCE  "..sourceIndex.." / "..#known
            if source.sourceVerified then
                lines[#lines+1]="Dungeon/Raid: "..tostring(source.instance or "Unknown")
                lines[#lines+1]="Boss: "..tostring(source.encounter or "Unknown")
                if self.DescribeDifficulty then
                    lines[#lines+1]="Difficulty: "..tostring(self:DescribeDifficulty(source.difficulty,source.raid,source))
                end
            elseif source.sourceType=="Vendor" then
                lines[#lines+1]="Vendor observed: "..tostring(source.vendorName or "Unknown")
            elseif source.sourceType=="Quest" then
                lines[#lines+1]="Quest observed: "..tostring(source.questName or "Unknown")
            elseif source.sourceType=="Crafted" then
                lines[#lines+1]="Recipe observed: "..tostring(source.recipeName or "Unknown")
            end
        else
            lines[#lines+1]="No verified acquisition location in local index."
            lines[#lines+1]="Use Gear Search to inspect the item, or index journal loot."
        end
        ui.description:SetText(table.concat(lines,"\n"))
    else
        ui.description:SetText("Browse a category, choose MISSING or COLLECTED, then select an appearance.\n\nTrack appearances independently of item-level upgrade goals. Collection status comes directly from WoW.")
    end
end
function GH:CreateTransmogPanel(parent)
    self:InitTransmogHunter()
    local p=panel(parent,29,-150,1542,558)
    local ui={panel=p}
    self.transmogUI=ui
    font(p,"TRANSMOG HUNTER",18,-13,380,true,GOLD)
    button(p,"COLLECTION DASHBOARD",1250,-13,275,29,function() GH:ShowTab("Collection Dashboard") end)
    font(p,"Find missing looks, track your wishlist and locate only verified sources. No live Wowhead connection.",18,-43,1490,false,PALE)
    local search=CreateFrame("EditBox",nil,p,"InputBoxTemplate")
    search:SetPoint("TOPLEFT",p,"TOPLEFT",24,-76);search:SetSize(690,33)
    search:SetAutoFocus(false);search:SetMaxLetters(120)
    search:SetText(self.transmogQuery or "")
    local searchHint=font(p,"Search by appearance name, item ID or appearance ID",39,-85,640,false,{0.54,0.65,0.78,1})
    local function updateSearchHint()
        searchHint:SetShown((search:GetText() or "")=="" and not search:HasFocus())
    end
    search:SetScript("OnEditFocusGained",function() updateSearchHint() end)
    search:SetScript("OnEditFocusLost",function() updateSearchHint() end)
    updateSearchHint()
    search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged",function(self)
        updateSearchHint()
        GH.transmogQuery=self:GetText() or ""
        if ui.scroll then ui.scroll:SetVerticalScroll(0) end
        GH:RefreshTransmogHunter()
    end)
    ui.search=search
    button(p,"CLEAR",732,-76,100,33,function() search:SetText("");search:SetFocus() end)
    ui.index=button(p,"INDEX ALL CATEGORIES",852,-76,325,33,function()
        if GH.transmogScan then
            GH.transmogScan=nil;worker:SetScript("OnUpdate",nil)
            GH.transmogStatus="Indexing cancelled"
            GH:RefreshTransmogHunter()
        else GH:StartTransmogCatalogScan(true) end
    end)
    button(p,"REFRESH CATEGORY",1192,-76,335,33,function()
        GH.transmogCache[GH.transmogCategory]=nil
        GH.selectedTransmog=nil
        GH.transmogSourceCacheFor=nil
        if GH.transmogCategory==0 then GH.transmogAllIndexed=false end
        GH:ReloadTransmogCategory()
    end)
    ui.status=font(p,"Appearance browser ready",19,-118,1190,false,GREEN)
    ui.resultCount=font(p,"",1210,-118,310,false,GOLD)
    button(p,"<",19,-152,45,31,function() GH:SetTransmogCategory(GH.transmogCategory-1) end)
    ui.category=button(p,"HEAD",73,-152,302,31,function() GH:SetTransmogCategory(GH.transmogCategory+1) end)
    button(p,">",382,-152,45,31,function() GH:SetTransmogCategory(GH.transmogCategory+1) end)
    ui.filters={}
    for i,info in ipairs({{"MISSING","Missing"},{"COLLECTED","Collected"},{"ALL","All"},{"TRACKED","Tracked"}}) do
        local b=button(p,info[1],445+(i-1)*165,-152,155,31,function()
            GH.transmogFilter=info[2]
            ui.scroll:SetVerticalScroll(0)
            GH:RefreshTransmogHunter()
        end)
        b.mode=info[2];ui.filters[#ui.filters+1]=b
    end
    button(p,"ALL CATEGORIES",1117,-152,408,31,function() GH:SetTransmogCategory(0) end)
    local list=panel(p,17,-196,931,343)
    -- Helpful empty state when a category is still indexing, or a filter has
    -- no results. The blank list previously looked like a broken display.
    ui.emptyState=CreateFrame("Frame",nil,list)
    ui.emptyState:SetPoint("TOPLEFT",list,"TOPLEFT",18,-18)
    ui.emptyState:SetPoint("BOTTOMRIGHT",list,"BOTTOMRIGHT",-18,18)
    ui.emptyTitle=font(ui.emptyState,"LOADING APPEARANCES...",20,-88,830,true,GOLD)
    ui.emptyTitle:SetJustifyH("CENTER")
    ui.emptyMessage=font(ui.emptyState,"",20,-124,830,false,PALE)
    ui.emptyMessage:SetJustifyH("CENTER")
    ui.emptyMessage:SetHeight(85);ui.emptyMessage:SetWordWrap(true)
    ui.scroll=CreateFrame("ScrollFrame",nil,list,"UIPanelScrollFrameTemplate")
    ui.scroll:SetPoint("TOPLEFT",list,"TOPLEFT",9,-8)
    ui.scroll:SetPoint("BOTTOMRIGHT",list,"BOTTOMRIGHT",-28,8)
    ui.scrollChild=CreateFrame("Frame",nil,ui.scroll)
    ui.scrollChild:SetSize(880,1);ui.scroll:SetScrollChild(ui.scrollChild)
    ui.rows={}
    for i=1,8 do
        local row=CreateFrame("Button",nil,ui.scrollChild,"BackdropTemplate")
        row:SetSize(876,45);style(row,NAVY,RIM)
        row.icon=row:CreateTexture(nil,"ARTWORK")
        row.icon:SetPoint("LEFT",row,"LEFT",5,0);row.icon:SetSize(38,38)
        row.title=font(row,"",51,-5,814,false,GOLD)
        row.subtitle=font(row,"",51,-24,814,false,PALE)
        row:SetScript("OnClick",function(self) GH:SelectTransmog(self.record) end)
        row:SetScript("OnEnter",function(self)
            local r=self.record
            if r and validID(r.itemID) and GameTooltip then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                local ok=pcall(GameTooltip.SetHyperlink,GameTooltip,"item:"..r.itemID)
                if not ok then GameTooltip:SetText(r.name or "Appearance") end
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        row:Hide();ui.rows[#ui.rows+1]=row
    end
    ui.scroll:HookScript("OnVerticalScroll",function() GH:RefreshTransmogHunter() end)
    local details=panel(p,960,-196,565,343)
    font(details,"APPEARANCE / SOURCE",12,-12,530,true,GOLD)
    ui.detailIcon=details:CreateTexture(nil,"ARTWORK")
    ui.detailIcon:SetPoint("TOPLEFT",details,"TOPLEFT",14,-43);ui.detailIcon:SetSize(55,55)
    ui.detailName=font(details,"Choose an appearance",82,-52,450,true,GOLD)
    ui.detailName:SetHeight(41);ui.detailName:SetWordWrap(true)
    ui.description=font(details,"",17,-112,528,false,PALE)
    ui.description:SetHeight(132);ui.description:SetWordWrap(true);ui.description:SetJustifyV("TOP")
    ui.sourcePrevious=button(details,"<",12,-250,40,29,function()
        GH.transmogSourceIndex=math.max(1,(GH.transmogSourceIndex or 1)-1);GH:RefreshTransmogHunter()
    end)
    ui.sourceNext=button(details,">",58,-250,40,29,function()
        GH.transmogSourceIndex=math.min(#(GH.transmogKnownSources or {}),(GH.transmogSourceIndex or 1)+1)
        GH:RefreshTransmogHunter()
    end)
    ui.map=button(details,"SHOW ENTRANCE",108,-250,204,29,function()
        local rec=GH.transmogKnownSources and GH.transmogKnownSources[GH.transmogSourceIndex or 1]
        if not rec then return end
        if rec.sourceVerified and GH.GoToRecord then GH:GoToRecord(rec,"entrance")
        elseif rec.sourceType=="Vendor" and rec.mapID and rec.mapX and rec.mapY and GH.SetWaypoint then
            GH:SetWaypoint(rec.mapID,rec.mapX,rec.mapY,"Last observed: "..tostring(rec.vendorName or "Vendor"),"observed")
        end
    end)
    ui.track=button(details,"TRACK APPEARANCE",319,-250,235,29,function()
        if GH.selectedTransmog then GH:ToggleTransmogGoal(GH.selectedTransmog) end
    end)
    ui.boss=button(details,"SHOW BOSS",12,-290,180,33,function()
        local rec=GH.transmogKnownSources and GH.transmogKnownSources[GH.transmogSourceIndex or 1]
        if rec and rec.sourceVerified and rec.encounterID and GH.GoToRecord then
            GH:GoToRecord(rec,"boss")
        end
    end)
    ui.toSearch=button(details,"FIND ITEM IN GEAR SEARCH",198,-290,356,33,function()
        local rec=GH.selectedTransmog
        if not rec or not rec.itemID then return end
        GH.gearSearchQuery=tostring(rec.itemID)
        GH.gearSearchFilter="All"
        GH.selectedSearchRec=nil
        if GH.gearSearchUI and GH.gearSearchUI.search then
            GH.gearSearchUI.search:SetText(tostring(rec.itemID))
        end
        GH:SetTab("Gear Search")
    end)
    p:Hide()
end
local watcher=CreateFrame("Frame")
for _,name in ipairs({"TRANSMOG_COLLECTION_UPDATED","NEW_TRANSMOG_ADDED","ITEM_DATA_LOAD_RESULT"}) do
    pcall(watcher.RegisterEvent,watcher,name)
end
watcher:SetScript("OnEvent",function(_,event)
    if not GH.db then return end
    if event~="ITEM_DATA_LOAD_RESULT" then
        -- Blizzard controls collected/missing state; never persist old booleans.
        GH.transmogCache={}
        GH.selectedTransmog=nil
        GH.transmogSourceCacheFor=nil
        GH.transmogResultRevision=(GH.transmogResultRevision or 0)+1
        GH.transmogAllIndexed=false
        GH.transmogScan=nil
        worker:SetScript("OnUpdate",nil)
        GH.transmogStatus="Collection changed. Refreshing current category..."
    elseif GH.transmogScan then return end
    if GH.transmogUI and GH.transmogUI.panel:IsShown() then
        if event=="ITEM_DATA_LOAD_RESULT" then
            -- A name may arrive after a source item is initially uncached.
            for _,cache in pairs(GH.transmogCache or {}) do
                for _,r in ipairs(cache) do
                    if r.itemID and r.name=="Appearance #"..r.visualID then
                        r.name=readName(r.itemID,r.name)
                    end
                end
            end
        end
        if event=="ITEM_DATA_LOAD_RESULT" then
            GH.transmogResultRevision=(GH.transmogResultRevision or 0)+1
        end
        GH:RefreshTransmogHunter()
    end
end)
