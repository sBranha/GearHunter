-- Gear Hunter v0.10.6 - Persistent Gear Hunting Checklist
-- Saved gear targets are account-wide; possession indicators inspect this character only.
-- Done is a manual choice: finding an owned item never silently completes a goal.
local addonName, NAV = ...
local GH = NAV.GearEngine
local ICON_ROOT="Interface\\AddOns\\GearHunterNavigator\\Art\\UIIcons\\"
local ink={0.020,0.040,0.078,0.99}
local navy={0.034,0.070,0.120,1}
local rim={0.44,0.57,0.75,1}
local gold={1,0.82,0.30,1}
local pale={0.82,0.89,1,1}
local green={0.35,1,0.57,1}
local function style(f,b,e)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(unpack(b or ink));f:SetBackdropBorderColor(unpack(e or rim))
end
local function panel(parent,x,y,w,h)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);f:SetSize(w,h);style(f);return f
end
local function label(parent,s,x,y,w,large,color)
    local f=parent:CreateFontString(nil,"OVERLAY",large and "GameFontNormalLarge" or "GameFontNormal")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    if w then f:SetWidth(w);f:SetJustifyH("LEFT") end
    f:SetTextColor(unpack(color or pale));f:SetText(s or "")
    return f
end
local function button(parent,s,x,y,w,h,fn)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetSize(w,h);style(b,navy,rim)
    b.caption=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
    b.caption:SetAllPoints();b.caption:SetTextColor(1,0.87,0.56,1);b.caption:SetText(s)
    b:SetScript("OnClick",fn)
    b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(unpack(gold)) end)
    b:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(unpack(rim)) end)
    return b
end
local function validID(id)
    return type(id)=="number" and id>0 and id<20000000 and id==math.floor(id)
end
local function idFromText(text)
    text=tostring(text or "")
    local raw=text:match("|Hitem:(%d+)") or text:match("item:(%d+)") or
        text:match("^%s*(%d+)%s*$")
    local id=raw and tonumber(raw)
    return validID(id) and id or nil
end
local function sourceKey(rec)
    if not rec then return "" end
    if rec.sourceKey then return "o:"..rec.itemID..":"..rec.sourceKey end
    return table.concat({"s",tostring(rec.itemID or 0),tostring(rec.instanceID or 0),
        tostring(rec.encounterID or 0),tostring(rec.difficulty or 0)},":")
end
local function safeRecord(rec)
    if type(rec)~="table" or not validID(tonumber(rec.itemID)) then return nil end
    local id=tonumber(rec.itemID)
    return {itemID=id,name=type(rec.name)=="string" and rec.name or ("Item #"..id),
        icon=rec.icon,link=type(rec.link)=="string" and rec.link or ("item:"..id),
        instance=rec.instance,instanceID=rec.instanceID,encounter=rec.encounter,
        encounterID=rec.encounterID,difficulty=rec.difficulty,raid=rec.raid,
        sourceVerified=rec.sourceVerified==true,sourceObserved=rec.sourceObserved==true,
        sourceType=rec.sourceType,sourceKey=rec.sourceKey,
        vendorName=rec.vendorName,questName=rec.questName,recipeName=rec.recipeName,
        mapID=rec.mapID,mapX=rec.mapX,mapY=rec.mapY}
end
function GH:InitHuntChecklist()
    if not self.db then return end
    if type(self.db.huntChecklist)~="table" then self.db.huntChecklist={} end
    if not self.db.options.huntListMigration105 then
        -- Keep every old TRACK AS GOAL entry. We deduplicate by ITEM because
        -- a checklist tracks the desired equipment, not individual difficulties.
        for _,rec in pairs(self.db.goals or {}) do
            if type(rec)=="table" and validID(rec.itemID) then
                local k=tostring(rec.itemID)
                if not self.db.huntChecklist[k] then
                    local saved=safeRecord(rec)
                    if saved then saved.done=false;self.db.huntChecklist[k]=saved end
                end
            end
        end
        self.db.options.huntListMigration105=true
    end
    self.huntFilter=self.huntFilter or "All"
    self.huntQuery=self.huntQuery or ""
end
function GH:IsHuntTracked(id)
    return self.db and type(self.db.huntChecklist)=="table" and
        self.db.huntChecklist[tostring(tonumber(id) or 0)]~=nil
end
function GH:AddHuntItem(rec,silent)
    if not self.db then return false end
    self:InitHuntChecklist()
    local safe=safeRecord(rec)
    if not safe then
        if not silent then self:Print("Choose a valid piece of equipment to track.") end
        return false
    end
    local k=tostring(safe.itemID)
    local old=self.db.huntChecklist[k]
    if old then
        -- Preserve completion and a deliberately selected farming source.
        safe.done=old.done==true
        safe.completedAt=old.completedAt
        safe.preferredSourceKey=old.preferredSourceKey
        if safe.name:match("^Item #%d+$") and old.name then safe.name=old.name end
        if not safe.sourceVerified and not safe.sourceObserved and
            (old.sourceVerified or old.sourceObserved) then
            for field,value in pairs(old) do
                if safe[field]==nil then safe[field]=value end
            end
        end
    else safe.done=false end
    self.db.huntChecklist[k]=safe
    self.selectedHuntID=safe.itemID
    self.selectedHuntSource=nil
    if not silent then
        self:Print((old and "Updated hunt target: " or "Added to hunt list: ")..safe.name)
        if self.Refresh then self:Refresh() end
    end
    return true
end
function GH:RemoveHuntItem(id)
    if not self.db then return end
    local k=tostring(tonumber(id) or 0)
    self.db.huntChecklist[k]=nil
    if tostring(self.selectedHuntID or "")==k then self.selectedHuntID=nil end
    self.selectedHuntSource=nil
    if self.Refresh then self:Refresh() end
end
function GH:ToggleHuntDone(id)
    if not self.db or not self.db.huntChecklist then return end
    local rec=self.db.huntChecklist[tostring(tonumber(id) or 0)]
    if not rec then return end
    rec.done=not (rec.done==true)
    rec.completedAt=rec.done and ((GetServerTime and GetServerTime()) or (time and time())) or nil
    if self.Refresh then self:Refresh() end
end
function GH:HuntOwned(id)
    if not validID(id) then return false end
    for _,item in pairs(self.equipped or {}) do
        if type(item)=="table" and item.itemID==id then return true end
    end
    local fn=GetItemCount
    if type(fn)=="function" then
        local ok,n=pcall(fn,id,true)
        if ok and type(n)=="number" and n>0 then return true end
    end
    return false
end
function GH:FindHuntRecord(query)
    local id=idFromText(query)
    if id then
        for _,v in pairs(self.gearSearchIndex or {}) do
            if type(v)=="table" and v.itemID==id and (v.sourceVerified or v.sourceObserved) then
                return v
            end
        end
        local name,link,icon
        if GetItemInfo then
            local ok,n,l,_,_,_,_,_,_,_,ic=pcall(GetItemInfo,id)
            if ok then name=n;link=l;icon=ic end
        end
        if not name and C_Item and C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID,id)
        end
        return {itemID=id,name=name or ("Item #"..id),link=link or ("item:"..id),icon=icon}
    end
    local term=tostring(query or ""):lower():gsub("^%s+",""):gsub("%s+$","")
    if term=="" then return nil,"Type an item name, item ID, or paste an item link." end
    if self.IndexKnownGear then self:IndexKnownGear() end
    local exact,partial={},{}
    local seen={}
    for _,v in pairs(self.gearSearchIndex or {}) do
        if type(v)=="table" and validID(v.itemID) and type(v.name)=="string" then
            local s=v.name:lower()
            if not seen[v.itemID] then
                if s==term then exact[v.itemID]=v
                elseif s:find(term,1,true) then partial[v.itemID]=v end
                seen[v.itemID]=true
            elseif s==term then exact[v.itemID]=v end
        end
    end
    local function unique(t)
        local count,rec=0,nil
        for _,v in pairs(t) do count=count+1;rec=v end
        return count,rec
    end
    local n,rec=unique(exact)
    if n==1 then return rec end
    if n>1 then return nil,"Several items have this exact name. Paste an item link or ID." end
    n,rec=unique(partial)
    if n==1 then return rec end
    if n>1 then return nil,"Several matching items. Use Gear Search to select the exact one." end
    return nil,"Not in the local gear index. Enter an item ID/link or index the Adventure Guide."
end
function GH:GetHuntMatches()
    self:InitHuntChecklist()
    local output={}
    local q=(self.huntQuery or ""):lower()
    local filter=self.huntFilter or "All"
    for _,rec in pairs(self.db.huntChecklist or {}) do
        if type(rec)=="table" and validID(rec.itemID) and
            (filter=="All" or (filter=="Done" and rec.done) or
             (filter=="To Get" and not rec.done)) and
            (q=="" or tostring(rec.name or ""):lower():find(q,1,true) or
            tostring(rec.itemID):find(q,1,true)) then output[#output+1]=rec end
    end
    table.sort(output,function(a,b)
        if (a.done==true)~=(b.done==true) then return a.done~=true end
        return (a.name or ""):lower()<(b.name or ""):lower()
    end)
    return output
end
function GH:GetHuntSources(rec)
    local output,seen={},{}
    if not rec then return output end
    local function add(v)
        if type(v)~="table" or v.itemID~=rec.itemID or
            not (v.sourceVerified or v.sourceObserved) then return end
        local key=sourceKey(v)
        if seen[key] then return end
        seen[key]=true;output[#output+1]=v
    end
    for _,v in pairs(self.gearSearchIndex or {}) do add(v) end
    -- A migrated legacy goal may omit the saved difficulty. Prefer the
    -- current catalog's fuller boss entry instead of duplicating it.
    local covered=false
    if rec.sourceVerified then
        for _,entry in ipairs(output) do
            if entry.sourceVerified and entry.instanceID==rec.instanceID and
                entry.encounterID==rec.encounterID and
                (not rec.difficulty or entry.difficulty==rec.difficulty) then
                covered=true;break
            end
        end
    end
    if not covered then add(rec) end
    table.sort(output,function(a,b)
        if (a.sourceVerified==true)~=(b.sourceVerified==true) then return a.sourceVerified==true end
        return tostring(a.instance or a.vendorName or a.questName or a.recipeName or "")<
               tostring(b.instance or b.vendorName or b.questName or b.recipeName or "")
    end)
    return output
end
local function sourceTitle(gh,rec)
    if rec.sourceVerified then
        local where=rec.encounter or rec.instance or "Dungeon / raid"
        return where.." - "..tostring(rec.instance or "")
    end
    if rec.sourceObserved then
        return tostring(rec.sourceType or "Seen")..": "..
            tostring(rec.vendorName or rec.questName or rec.recipeName or "observed in game")
    end
    return "Acquisition location not known"
end
function GH:RefreshHuntChecklist()
    local ui=self.huntUI
    if not ui or not ui.panel:IsShown() then return end
    self:InitHuntChecklist()
    local list=self:GetHuntMatches()
    local done,total=0,0
    for _,rec in pairs(self.db.huntChecklist) do
        if type(rec)=="table" and validID(rec.itemID) then
            total=total+1
            if rec.done then done=done+1 end
        end
    end
    ui.status:SetText(done.." / "..total.." completed   |   "..(#list).." shown")
    for _,b in ipairs(ui.filters) do
        b:SetBackdropBorderColor(unpack(b.which==self.huntFilter and gold or rim))
    end
    ui.scrollChild:SetHeight(math.max(1,#list*55))
    local start=math.floor(math.max(0,ui.scroll:GetVerticalScroll() or 0)/55)+1
    for i,row in ipairs(ui.rows) do
        local rec=list[start+i-1]
        if rec then
            row:ClearAllPoints();row:SetPoint("TOPLEFT",ui.scrollChild,"TOPLEFT",0,-(start+i-2)*55)
            row.entry=rec;row.icon:SetTexture(self:GetDisplayItemIcon(rec))
            row.name:SetText(rec.name or ("Item #"..rec.itemID))
            row.subtitle:SetText(rec.done and "COMPLETED" or
                (self:HuntOwned(rec.itemID) and "OWNED ON THIS CHARACTER - not marked done" or
                (rec.sourceVerified and (rec.instance or "Verified source") or
                rec.sourceObserved and "Known from an in-game source" or "Source not indexed")))
            row.subtitle:SetTextColor(unpack(rec.done and green or pale))
            row.tick:SetChecked(rec.done==true)
            row:SetBackdropBorderColor(unpack(self.selectedHuntID==rec.itemID and gold or rim))
            row:Show()
        else row.entry=nil;row:Hide() end
    end
    local current=self.selectedHuntID and self.db.huntChecklist[tostring(self.selectedHuntID)] or nil
    ui.icon:SetTexture(current and self:GetDisplayItemIcon(current) or ICON_ROOT.."item-placeholder.tga")
    ui.name:SetText(current and (current.name or ("Item #"..current.itemID)) or "Select an item")
    local sources=self:GetHuntSources(current)
    local chosen=current and self.selectedHuntSource or nil
    if chosen and (not current or chosen.itemID~=current.itemID) then chosen=nil end
    if not chosen then
        for _,s in ipairs(sources) do
            if current.preferredSourceKey and sourceKey(s)==current.preferredSourceKey then chosen=s;break end
        end
    end
    if not chosen then chosen=sources[1] end
    self.selectedHuntSource=chosen
    for i,row in ipairs(ui.sources) do
        local src=sources[i]
        if src then
            row.entry=src
            row.caption:SetText(sourceTitle(self,src))
            row:SetBackdropBorderColor(unpack(src==chosen and gold or rim))
            row:Show()
        else row.entry=nil;row:Hide() end
    end
    ui.sourceCount:SetText(#sources==0 and "No verified source recorded for this item." or
        ("KNOWN SOURCES ("..#sources..") - "..(#sources>3 and "first 3 shown; see Gear Search" or "select a destination")))
    ui.description:SetText(current and
        ((current.done and "DONE - manually checked off." or "Still hunting this item.")..
        (self:HuntOwned(current.itemID) and "  Owned on this character." or "")..
        "\nItem ID: "..current.itemID..". Gear Search may know additional sources.") or
        "Select a saved item, or add one by name, item ID, or item link.")
    local verified=chosen and chosen.sourceVerified and type(chosen.instanceID)=="number"
    local vendor=chosen and chosen.sourceObserved and chosen.sourceType=="Vendor" and
        type(chosen.mapID)=="number" and type(chosen.mapX)=="number" and type(chosen.mapY)=="number"
    ui.map.caption:SetText(vendor and "LAST SEEN" or "SHOW ENTRANCE")
    for _,v in ipairs({{ui.map,verified or vendor},{ui.boss,verified and type(chosen.encounterID)=="number"},
        {ui.guide,verified},{ui.complete,current~=nil},{ui.remove,current~=nil},{ui.searchSources,current~=nil}}) do
        if v[2] then v[1]:Enable();v[1]:SetAlpha(1) else v[1]:Disable();v[1]:SetAlpha(0.38) end
    end
    ui.complete.caption:SetText(current and current.done and "MARK TO GET" or "MARK DONE")
end
function GH:CreateHuntChecklistPanel(parent)
    local p=panel(parent,29,-150,1542,558)
    self.huntUI={panel=p}
    local ui=self.huntUI
    label(p,"GEAR HUNTING CHECKLIST",18,-13,625,true,gold)
    label(p,"Save multiple items, choose known farming locations and check them off as you obtain them.",18,-42,1280,false,pale)
    local add=CreateFrame("EditBox",nil,p,"InputBoxTemplate")
    add:SetPoint("TOPLEFT",p,"TOPLEFT",26,-78);add:SetSize(660,32)
    add:SetAutoFocus(false);add:SetMaxLetters(255)
    add:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    ui.add=add
    local function addInput()
        local rec,why=GH:FindHuntRecord(add:GetText())
        if rec then
            GH:AddHuntItem(rec)
            add:SetText("");add:ClearFocus()
        else GH:Print(why or "Item not found. Try a link or an item ID.") end
    end
    add:SetScript("OnEnterPressed",addInput)
    button(p,"ADD ITEM",705,-78,154,32,addInput)
    ui.status=label(p,"0 / 0 completed",972,-83,535,true,green)
    ui.filters={}
    for i,entry in ipairs({{"ALL","All"},{"TO GET","To Get"},{"DONE","Done"}}) do
        local b=button(p,entry[1],18+(i-1)*141,-124,133,31,function()
            GH.huntFilter=entry[2];ui.scroll:SetVerticalScroll(0);GH:RefreshHuntChecklist()
        end)
        b.which=entry[2];ui.filters[#ui.filters+1]=b
    end
    button(p,"PLAN FARM ROUTE",861,-124,224,31,function() GH:ShowTab("Farm Route") end)
    button(p,"WEEKLY LOCKOUTS",1097,-124,224,31,function() GH:ShowTab("Weekly Farm") end)
    button(p,"DASHBOARD",1333,-124,190,31,function() GH:ShowTab("Collection Dashboard") end)
    label(p,"FILTER LIST",448,-128,128,false,gold)
    local filter=CreateFrame("EditBox",nil,p,"InputBoxTemplate")
    filter:SetPoint("TOPLEFT",p,"TOPLEFT",573,-124);filter:SetSize(280,27)
    filter:SetAutoFocus(false)
    filter:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    filter:SetScript("OnTextChanged",function(self)
        GH.huntQuery=self:GetText() or "";ui.scroll:SetVerticalScroll(0);GH:RefreshHuntChecklist()
    end)
    ui.query=filter
    local listPanel=panel(p,17,-170,934,370)
    ui.scroll=CreateFrame("ScrollFrame",nil,listPanel,"UIPanelScrollFrameTemplate")
    ui.scroll:SetPoint("TOPLEFT",listPanel,"TOPLEFT",8,-8)
    ui.scroll:SetPoint("BOTTOMRIGHT",listPanel,"BOTTOMRIGHT",-27,8)
    ui.scrollChild=CreateFrame("Frame",nil,ui.scroll)
    ui.scrollChild:SetSize(890,1)
    ui.scroll:SetScrollChild(ui.scrollChild)
    ui.rows={}
    for i=1,9 do
        local row=CreateFrame("Button",nil,ui.scrollChild,"BackdropTemplate")
        row:SetSize(885,53);style(row,navy,rim)
        row.icon=row:CreateTexture(nil,"ARTWORK")
        row.icon:SetPoint("LEFT",row,"LEFT",5,0);row.icon:SetSize(43,43)
        row.name=label(row,"",58,-5,720,false,gold)
        row.subtitle=label(row,"",58,-29,720,false,pale)
        row.tick=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
        row.tick:SetSize(31,31);row.tick:SetPoint("RIGHT",row,"RIGHT",-10,0)
        row.tick:SetScript("OnClick",function(self)
            if row.entry then GH:ToggleHuntDone(row.entry.itemID) end
        end)
        row:SetScript("OnClick",function(self)
            if self.entry then GH.selectedHuntID=self.entry.itemID;GH.selectedHuntSource=nil;GH:RefreshHuntChecklist() end
        end)
        row:SetScript("OnEnter",function(self)
            if self.entry and self.entry.link and GameTooltip then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                if not pcall(GameTooltip.SetHyperlink,GameTooltip,self.entry.link) then
                    GameTooltip:SetText(self.entry.name or "Equipment")
                end
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        row:Hide();ui.rows[#ui.rows+1]=row
    end
    ui.scroll:HookScript("OnVerticalScroll",function() GH:RefreshHuntChecklist() end)
    local details=panel(p,961,-170,565,370)
    label(details,"SELECTED GEAR / FARMING ROUTE",12,-13,532,true,gold)
    ui.icon=details:CreateTexture(nil,"ARTWORK")
    ui.icon:SetPoint("TOPLEFT",details,"TOPLEFT",12,-46);ui.icon:SetSize(49,49)
    ui.name=label(details,"Select an item",75,-50,478,true,gold)
    ui.name:SetHeight(44);ui.name:SetWordWrap(true)
    ui.description=label(details,"",16,-104,528,false,pale)
    ui.description:SetHeight(49);ui.description:SetWordWrap(true)
    ui.sourceCount=label(details,"KNOWN SOURCES",14,-161,532,false,gold)
    ui.sources={}
    for i=1,3 do
        local row=button(details,"",12,-184-(i-1)*28,540,26,function(self)
            if self.entry then
                GH.selectedHuntSource=self.entry
                local saved=GH.db.huntChecklist[tostring(GH.selectedHuntID)]
                if saved then saved.preferredSourceKey=sourceKey(self.entry) end
                GH:RefreshHuntChecklist()
            end
        end)
        row.caption:ClearAllPoints();row.caption:SetPoint("LEFT",row,"LEFT",8,0)
        row.caption:SetWidth(525);row.caption:SetJustifyH("LEFT")
        ui.sources[#ui.sources+1]=row
    end
    ui.map=button(details,"SHOW ENTRANCE",10,-276,175,33,function()
        local s=GH.selectedHuntSource
        if not s then return end
        if s.sourceVerified then GH:GoToRecord(s,"entrance")
        elseif s.sourceType=="Vendor" and s.mapID and s.mapX and s.mapY then
            GH:SetWaypoint(s.mapID,s.mapX,s.mapY,"Last observed: "..tostring(s.vendorName or "Vendor"),"observed") end
    end)
    ui.boss=button(details,"SHOW BOSS",195,-276,174,33,function()
        if GH.selectedHuntSource then GH:GoToRecord(GH.selectedHuntSource,"boss") end
    end)
    ui.guide=button(details,"OPEN GUIDE",379,-276,175,33,function()
        if GH.selectedHuntSource then GH:OpenGuide(GH.selectedHuntSource) end
    end)
    ui.complete=button(details,"MARK DONE",10,-326,174,33,function()
        if GH.selectedHuntID then GH:ToggleHuntDone(GH.selectedHuntID) end
    end)
    ui.searchSources=button(details,"GEAR SEARCH",194,-326,175,33,function()
        local rec=GH.db.huntChecklist[tostring(GH.selectedHuntID)]
        if not rec then return end
        GH.gearSearchQuery=tostring(rec.itemID)
        GH:ShowTab("Gear Search")
        if GH.gearSearchUI and GH.gearSearchUI.search then
            GH.gearSearchUI.search:SetText(GH.gearSearchQuery)
        end
    end)
    ui.remove=button(details,"REMOVE ITEM",379,-326,175,33,function()
        if GH.selectedHuntID then GH:RemoveHuntItem(GH.selectedHuntID) end
    end)
    p:Hide()
end
