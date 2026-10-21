-- Gear Hunter v0.11.3 - Collection Dashboard.
-- Summarizes actual saved targets and current-session appearance scans.
-- Never represents alt snapshots as live data or unseen appearances as collected.
local addonName, NAV = ...
local GH = NAV.GearEngine
local INK={0.018,0.035,0.068,0.99}
local NAVY={0.031,0.065,0.114,0.99}
local EDGE={0.41,0.54,0.73,1}
local GOLD={1.0,0.82,0.32,1}
local PALE={0.83,0.90,1,1}
local GREEN={0.34,1,0.62,1}
local AMBER={1,0.67,0.38,1}
local ROOT="Interface\\AddOns\\GearHunterNavigator\\Art\\UIIcons\\"
local function panel(parent,x,y,w,h)
    local p=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    p:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);p:SetSize(w,h)
    p:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    p:SetBackdropColor(unpack(INK));p:SetBackdropBorderColor(unpack(EDGE))
    return p
end
local function label(parent,body,x,y,w,large,color)
    local f=parent:CreateFontString(nil,"OVERLAY",large and "GameFontNormalLarge" or "GameFontNormal")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    f:SetWidth(w);f:SetJustifyH("LEFT")
    f:SetTextColor(unpack(color or PALE));f:SetText(body or "")
    return f
end
local function button(parent,body,x,y,w,h,action)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetSize(w,h)
    b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    b:SetBackdropColor(unpack(NAVY));b:SetBackdropBorderColor(unpack(EDGE))
    b.text=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
    b.text:SetAllPoints();b.text:SetTextColor(unpack(GOLD));b.text:SetText(body)
    b:SetScript("OnClick",action)
    b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(unpack(GOLD)) end)
    b:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(unpack(EDGE)) end)
    return b
end
local function itemID(id)
    return type(id)=="number" and id>0 and id==math.floor(id)
end
local function displayName(rec,fallback)
    if type(rec.name)=="string" and rec.name~="" then return rec.name end
    return fallback
end
function GH:BuildCollectionOverview()
    local s={targets={},appearances={},alts={},huntTotal=0,huntDone=0,
        mogTracked=0,mogCollectedKnown=0,mogMissingKnown=0,
        indexed=0,indexedCollected=0,indexedMissing=0,indexedCategories=0,
        altCount=0,lockoutCount=nil}
    local db=self.db or {}
    for _,rec in pairs(type(db.huntChecklist)=="table" and db.huntChecklist or {}) do
        if type(rec)=="table" and itemID(rec.itemID) then
            s.huntTotal=s.huntTotal+1
            if rec.done==true then s.huntDone=s.huntDone+1 end
            s.targets[#s.targets+1]=rec
        end
    end
    table.sort(s.targets,function(a,b)
        if (a.done==true)~=(b.done==true) then return a.done~=true end
        return tostring(a.name or a.itemID):lower()<tostring(b.name or b.itemID):lower()
    end)
    local appearances={}
    for cat,records in pairs(type(self.transmogCache)=="table" and self.transmogCache or {}) do
        if type(records)=="table" then
            s.indexedCategories=s.indexedCategories+1
            for _,rec in ipairs(records) do
                if type(rec)=="table" and type(rec.visualID)=="number" then
                    s.indexed=s.indexed+1
                    if rec.isCollected==true then s.indexedCollected=s.indexedCollected+1
                    else s.indexedMissing=s.indexedMissing+1 end
                    appearances[tostring(cat)..":"..tostring(rec.visualID)]=rec
                end
            end
        end
    end
    for key,goal in pairs(type(db.transmogGoals)=="table" and db.transmogGoals or {}) do
        if type(goal)=="table" and type(goal.visualID)=="number" then
            s.mogTracked=s.mogTracked+1
            local cat=goal.category
            local rec=appearances[tostring(cat)..":"..tostring(goal.visualID)]
            local state="Not indexed this session"
            if rec then
                if rec.isCollected==true then state="Collected";s.mogCollectedKnown=s.mogCollectedKnown+1
                else state="Missing";s.mogMissingKnown=s.mogMissingKnown+1 end
            end
            s.appearances[#s.appearances+1]={goal=goal,record=rec,state=state,key=key}
        end
    end
    table.sort(s.appearances,function(a,b)
        local order={Missing=1,["Not indexed this session"]=2,Collected=3}
        if order[a.state]~=order[b.state] then return order[a.state]<order[b.state] end
        return tostring(a.goal.name or a.goal.visualID):lower()<tostring(b.goal.name or b.goal.visualID):lower()
    end)
    if self.GetAltSnapshots then s.alts=self:GetAltSnapshots() end
    s.altCount=#s.alts
    if self.ReadWeeklyFarmData then
        local ok,lockouts=pcall(self.ReadWeeklyFarmData,self)
        if ok and type(lockouts)=="table" then s.lockoutCount=#lockouts end
    end
    return s
end
function GH:OpenDashboardHuntItem(rec)
    if not rec or not itemID(rec.itemID) then return end
    self.selectedHuntID=rec.itemID
    self.selectedHuntSource=nil
    self.huntFilter="All";self.huntQuery=""
    if self.huntUI and self.huntUI.query then self.huntUI.query:SetText("") end
    self:ShowTab("Hunt List")
    if self.huntUI and self.huntUI.scroll and self.GetHuntMatches then
        for i,record in ipairs(self:GetHuntMatches()) do
            if record.itemID==rec.itemID then
                self.huntUI.scroll:SetVerticalScroll(math.max(0,(i-2)*55))
                self:RefreshHuntChecklist()
                break
            end
        end
    end
end
function GH:OpenDashboardAppearance(entry)
    if not entry or not entry.goal then return end
    self.transmogCategory=entry.goal.category or 1
    self.transmogFilter="Tracked"
    self.transmogQuery=""
    self.selectedTransmog=entry.record
    self.transmogSourceIndex=1
    self:ShowTab("Transmog Hunter")
    if self.transmogUI then
        if self.transmogUI.search then self.transmogUI.search:SetText("") end
        if self.transmogUI.scroll then
            for i,rec in ipairs(self:GetTransmogMatches()) do
                if rec.visualID==entry.goal.visualID and rec.category==entry.goal.category then
                    self.transmogUI.scroll:SetVerticalScroll(math.max(0,(i-2)*48))
                    break
                end
            end
        end
        self:RefreshTransmogHunter()
    end
end
function GH:OpenDashboardAlt(entry)
    if not entry then return end
    self.selectedAltGUID=entry.guid
    self:ShowTab("Alt Tracker")
end
function GH:RefreshCollectionDashboard()
    local ui=self.collectionUI
    if not ui or not ui.panel:IsShown() then return end
    local stats=self:BuildCollectionOverview()
    self.collectionSummary=stats
    ui.huntValue:SetText((stats.huntTotal-stats.huntDone).." to get  /  "..stats.huntDone.." done")
    ui.huntHint:SetText(stats.huntTotal.." saved equipment targets")
    ui.mogValue:SetText(stats.mogTracked.." tracked looks")
    ui.mogHint:SetText(stats.mogMissingKnown.." missing  |  "..stats.mogCollectedKnown.." collected (indexed)")
    ui.indexValue:SetText(stats.indexedMissing.." missing / "..stats.indexed.." indexed")
    ui.indexHint:SetText(stats.indexedCategories.." of 29 categories checked this session")
    ui.altValue:SetText(stats.altCount.." character snapshots")
    ui.altHint:SetText(stats.lockoutCount and (stats.lockoutCount.." reported current lockouts") or "Current lockouts not available")
    for i,row in ipairs(ui.huntRows) do
        local rec=stats.targets[i]
        if rec then
            row.record=rec;row.icon:SetTexture(self:GetDisplayItemIcon(rec))
            row.name:SetText(displayName(rec,"Item #"..tostring(rec.itemID)))
            row.note:SetText(rec.done and "DONE - manually completed" or
                (rec.sourceVerified and ("TO GET - "..tostring(rec.instance or "verified boss")) or
                 rec.sourceObserved and "TO GET - observed source" or "TO GET - source unknown"))
            row.note:SetTextColor(unpack(rec.done and GREEN or PALE));row:Show()
        else row.record=nil;row:Hide() end
    end
    ui.huntEmpty:SetShown(#stats.targets==0)
    ui.huntMore:SetText(#stats.targets>5 and ("Showing 5 of "..#stats.targets.." saved targets") or
        "Click a target to manage it in Hunt List")
    for i,row in ipairs(ui.mogRows) do
        local entry=stats.appearances[i]
        if entry then
            row.entry=entry
            local goal=entry.goal
            local rec=entry.record
            row.icon:SetTexture(self:GetDisplayItemIcon(rec or goal))
            row.name:SetText(displayName(goal,"Appearance #"..tostring(goal.visualID)))
            row.note:SetText(entry.state)
            row.note:SetTextColor(unpack(entry.state=="Collected" and GREEN or
                entry.state=="Missing" and AMBER or PALE))
            row:Show()
        else row.entry=nil;row:Hide() end
    end
    ui.mogEmpty:SetShown(#stats.appearances==0)
    ui.mogMore:SetText(#stats.appearances>3 and ("Showing 3 of "..stats.mogTracked.." wishlist looks") or
        "Collection status updates when appearances are indexed")
    for i,row in ipairs(ui.altRows) do
        local entry=stats.alts[i]
        if entry then
            row.entry=entry
            local rec=entry.data
            row.name:SetText(tostring(rec.name or "Character").." - "..tostring(rec.realm or "Realm")..
                (entry.current and "  [CURRENT]" or ""))
            row.note:SetText("Lv "..tostring(rec.level or "?").."  |  "..tostring(rec.specName or rec.className or "")..
                "  |  iLvl "..(type(rec.itemLevel)=="number" and string.format("%.1f",rec.itemLevel) or "?")..
                "  |  last seen snapshot")
            row:Show()
        else row.entry=nil;row:Hide() end
    end
    ui.altEmpty:SetShown(#stats.alts==0)
    ui.altMore:SetText(#stats.alts>2 and ("Showing 2 of "..stats.altCount.." saved characters") or
        "Offline character information is not live")
end
function GH:CreateCollectionDashboardPanel(parent)
    local p=panel(parent,29,-150,1542,558)
    local ui={panel=p,huntRows={},mogRows={},altRows={}}
    self.collectionUI=ui
    label(p,"COLLECTION DASHBOARD",18,-13,880,true,GOLD)
    label(p,"Your gear hunts, appearance wishlist and remembered characters in one place. Only indexed appearances are counted.",18,-42,1260,false,PALE)
    button(p,"REFRESH",1354,-13,170,29,function() GH:RefreshCollectionDashboard() end)
    local cardData={
        {17,"HUNT LIST", "huntValue","huntHint"},
        {401,"TRANSMOG WISHLIST","mogValue","mogHint"},
        {785,"APPEARANCES INDEXED","indexValue","indexHint"},
        {1169,"ALT / WEEKLY PROGRESS","altValue","altHint"},
    }
    for _,entry in ipairs(cardData) do
        local box=panel(p,entry[1],-81,366,95)
        label(box,entry[2],12,-10,342,false,GOLD)
        ui[entry[3]]=label(box,"",12,-38,344,true,GREEN)
        ui[entry[4]]=label(box,"",12,-68,344,false,PALE)
    end
    local hunting=panel(p,17,-187,744,320)
    label(hunting,"HUNT LIST  /  SAVED EQUIPMENT",13,-11,620,true,GOLD)
    ui.huntMore=label(hunting,"",14,-296,700,false,PALE)
    ui.huntEmpty=label(hunting,"No gear targets yet. Add equipment through Gear Search or Hunt List.",18,-106,697,false,PALE)
    for i=1,5 do
        local row=button(hunting,"",12,-43-(i-1)*49,718,46,function(self)
            GH:OpenDashboardHuntItem(self.record)
        end)
        row.text:Hide()
        row.icon=row:CreateTexture(nil,"ARTWORK")
        row.icon:SetPoint("LEFT",row,"LEFT",7,0);row.icon:SetSize(39,39)
        row.name=label(row,"",57,-4,645,false,GOLD)
        row.note=label(row,"",57,-24,644,false,PALE)
        row:Hide();ui.huntRows[i]=row
    end
    local mog=panel(p,772,-187,753,189)
    label(mog,"TRANSMOG WISHLIST  /  SAVED APPEARANCES",13,-10,730,true,GOLD)
    ui.mogEmpty=label(mog,"No appearances tracked. Open Transmog Hunter and track a look.",16,-73,710,false,PALE)
    ui.mogMore=label(mog,"",14,-165,700,false,PALE)
    for i=1,3 do
        local row=button(mog,"",12,-37-(i-1)*40,729,38,function(self)
            GH:OpenDashboardAppearance(self.entry)
        end)
        row.text:Hide()
        row.icon=row:CreateTexture(nil,"ARTWORK")
        row.icon:SetPoint("LEFT",row,"LEFT",5,0);row.icon:SetSize(31,31)
        row.name=label(row,"",45,-4,670,false,GOLD)
        row.note=label(row,"",45,-21,660,false,PALE)
        row:Hide();ui.mogRows[i]=row
    end
    local alts=panel(p,772,-385,753,122)
    label(alts,"YOUR CHARACTERS  /  LAST SAVED",13,-8,725,true,GOLD)
    ui.altEmpty=label(alts,"No character snapshots yet. Log into each character once.",16,-54,702,false,PALE)
    ui.altMore=label(alts,"",14,-103,704,false,PALE)
    for i=1,2 do
        local row=button(alts,"",12,-31-(i-1)*35,729,33,function(self)
            GH:OpenDashboardAlt(self.entry)
        end)
        row.text:Hide()
        row.name=label(row,"",8,-2,711,false,GOLD)
        row.note=label(row,"",8,-17,711,false,PALE)
        row:Hide();ui.altRows[i]=row
    end
    local actions={
        {"OPEN HUNT LIST","Hunt List"}, {"TRANSMOG HUNTER","Transmog Hunter"},
        {"ALT TRACKER","Alt Tracker"}, {"WEEKLY FARM","Weekly Farm"},
        {"GEAR SEARCH","Gear Search"}, {"FARM ROUTE","Farm Route"},
    }
    for i,entry in ipairs(actions) do
        button(p,entry[1],17+(i-1)*254,-520,235,30,function() GH:ShowTab(entry[2]) end)
    end
    p:Hide()
end
