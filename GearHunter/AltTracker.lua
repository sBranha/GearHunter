-- Gear Hunter v0.10.9 - account-wide alt snapshots.
-- Other characters are never queried live. Snapshots update only when played.
local addonName, GH = ...
local ink={0.016,0.035,0.066,0.99}
local navy={0.031,0.067,0.115,0.99}
local border={0.43,0.56,0.74,1}
local gold={1.0,0.83,0.31,1}
local pale={0.84,0.91,1,1}
local green={0.39,1,0.65,1}
local orange={1,0.67,0.38,1}
local function style(f,color,edge)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(unpack(color or ink))
    f:SetBackdropBorderColor(unpack(edge or border))
end
local function panel(parent,x,y,w,h)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    f:SetSize(w,h);style(f);return f
end
local function label(parent,body,x,y,w,large,color)
    local f=parent:CreateFontString(nil,"OVERLAY",large and "GameFontNormalLarge" or "GameFontNormal")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    f:SetWidth(w);f:SetJustifyH("LEFT")
    f:SetTextColor(unpack(color or pale));f:SetText(body or "")
    return f
end
local function button(parent,body,x,y,w,h,cb)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetSize(w,h);style(b,navy)
    b.caption=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
    b.caption:SetAllPoints();b.caption:SetTextColor(unpack(gold));b.caption:SetText(body)
    b:SetScript("OnClick",cb)
    b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(unpack(gold)) end)
    b:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(unpack(border)) end)
    return b
end
local function safeNumber(n)
    return type(n)=="number" and (not issecretvalue or not issecretvalue(n)) and n==n and n or nil
end
local function safeString(s)
    return type(s)=="string" and (not issecretvalue or not issecretvalue(s)) and s or nil
end
local function now()
    if type(GetServerTime)=="function" then
        local ok,t=pcall(GetServerTime)
        if ok and safeNumber(t) then return t end
    end
    if type(time)=="function" then
        local ok,t=pcall(time)
        if ok and safeNumber(t) then return t end
    end
    return 0
end
local function ageLabel(timestamp)
    local n=now()
    if not safeNumber(timestamp) or n<=0 then return "LAST SEEN UNKNOWN" end
    local age=math.max(0,n-timestamp)
    if age<3600 then return "SEEN < 1H AGO" end
    if age<86400 then return "SEEN "..math.floor(age/3600).."H AGO" end
    return "SEEN "..math.floor(age/86400).."D AGO"
end
local function classSpec()
    local spec=GetSpecialization and GetSpecialization()
    if spec and GetSpecializationInfo then
        local ok,id,name=pcall(GetSpecializationInfo,spec)
        if ok then return safeNumber(id),safeString(name) end
    end
end
function GH:InitAltTracker()
    if not self.db then return end
    if type(self.db.altSnapshots)~="table" then self.db.altSnapshots={} end
    self.altTrackerMode=self.altTrackerMode or "Equipment"
end
function GH:CaptureAltSnapshot(includeLockouts)
    if not self.db then return false end
    self:InitAltTracker()
    local guid=UnitGUID and safeString(UnitGUID("player"))
    local name=UnitName and safeString(UnitName("player"))
    if not guid or guid=="" or not name or name=="" then return false end
    local old=self.db.altSnapshots[guid]
    if type(old)~="table" then old={} end
    local realm=(GetRealmName and safeString(GetRealmName())) or "Unknown Realm"
    local className,classToken
    if UnitClass then className,classToken=UnitClass("player") end
    local specID,specName=classSpec()
    local avg
    if GetAverageItemLevel then
        local ok,_,equippedAverage=pcall(GetAverageItemLevel)
        if ok then avg=safeNumber(equippedAverage) end
    end
    old.name=name;old.realm=realm;old.guid=guid
    old.class=safeString(classToken) or "UNKNOWN"
    old.className=safeString(className) or "Unknown"
    old.level=self.GetCharacterLevel and self:GetCharacterLevel() or 1
    old.faction=(UnitFactionGroup and safeString(UnitFactionGroup("player"))) or "Unknown"
    old.specID=specID;old.specName=specName or "Unknown"
    old.itemLevel=avg or old.itemLevel
    old.lastSeen=now()
    old.equipment={}
    local count=0
    for _,slot in ipairs(self.slotDefs or {}) do
        local own=self.equipped and self.equipped[slot.id]
        if type(own)=="table" and safeNumber(own.itemID) then
            local entry={slot=slot.id,itemID=own.itemID,level=safeNumber(own.level),icon=own.icon}
            if type(own.link)=="string" and (not issecretvalue or not issecretvalue(own.link)) then
                entry.link=own.link
            end
            old.equipment[tostring(slot.id)]=entry
            count=count+1
        end
    end
    old.equippedCount=count
    if includeLockouts and self.ReadWeeklyFarmData then
        local saves=self:ReadWeeklyFarmData()
        local entries={}
        local captured=now()
        for _,save in ipairs(saves or {}) do
            if #entries>=70 then break end
            local remaining=safeNumber(save.reset)
            local bosses={}
            for _,boss in ipairs(save.encounters or {}) do
                if #bosses>=40 then break end
                bosses[#bosses+1]={name=safeString(boss.name) or "Boss",killed=boss.killed==true}
            end
            entries[#entries+1]={name=safeString(save.name) or "Instance",kind=save.kind,
                difficultyName=safeString(save.difficultyName),
                progress=safeNumber(save.progress) or 0,
                numEncounters=safeNumber(save.numEncounters) or 0,
                resetAt=remaining and (captured+remaining) or nil,
                encounters=bosses}
        end
        old.lockouts=entries
        old.lockoutsCapturedAt=captured
    end
    self.db.altSnapshots[guid]=old
    self.currentAltGUID=guid
    if self.altUI and self.altUI.panel:IsShown() then self:RefreshAltTracker() end
    return true
end
function GH:GetAltSnapshots()
    local result={}
    if not self.db or type(self.db.altSnapshots)~="table" then return result end
    local current=UnitGUID and safeString(UnitGUID("player"))
    for guid,entry in pairs(self.db.altSnapshots) do
        if type(guid)=="string" and type(entry)=="table" and type(entry.name)=="string" then
            result[#result+1]={guid=guid,data=entry,current=guid==current}
        end
    end
    table.sort(result,function(a,b)
        if a.current~=b.current then return a.current end
        if a.data.lastSeen~=b.data.lastSeen then return (a.data.lastSeen or 0)>(b.data.lastSeen or 0) end
        return a.data.name<b.data.name
    end)
    return result
end
function GH:RefreshAltTracker()
    local ui=self.altUI
    if not ui or not ui.panel:IsShown() then return end
    local alts=self:GetAltSnapshots()
    ui.summary:SetText(#alts.." CHARACTER SNAPSHOT(S) ON THIS WOW ACCOUNT  |  DATA UPDATES WHEN YOU PLAY EACH CHARACTER")
    local selected
    for _,v in ipairs(alts) do if v.guid==self.selectedAltGUID then selected=v;break end end
    if not selected then selected=alts[1] end
    self.selectedAltGUID=selected and selected.guid or nil
    ui.listChild:SetHeight(math.max(1,#alts*55))
    local offset=math.floor(math.max(0,ui.listScroll:GetVerticalScroll() or 0)/55)+1
    for i,row in ipairs(ui.rows) do
        local v=alts[offset+i-1]
        if v then
            local pos=offset+i-1
            row:ClearAllPoints();row:SetPoint("TOPLEFT",ui.listChild,"TOPLEFT",0,-(pos-1)*55)
            row.entry=v
            row.title:SetText(v.data.name.." - "..(v.data.realm or "Unknown Realm")..(v.current and "  [YOU]" or ""))
            row.note:SetText("Lv "..tostring(v.data.level or "?").."  |  "..(v.data.specName or "").." "..(v.data.className or "").."  |  "..ageLabel(v.data.lastSeen))
            row:SetBackdropBorderColor(unpack(selected and v.guid==selected.guid and gold or border))
            row:Show()
        else row.entry=nil;row:Hide() end
    end
    for _,btn in ipairs(ui.modeButtons) do
        btn.button:SetBackdropBorderColor(unpack(self.altTrackerMode==btn.mode and gold or border))
    end
    ui.equipView:SetShown(self.altTrackerMode=="Equipment")
    ui.lockView:SetShown(self.altTrackerMode=="Lockouts")
    if not selected then
        ui.detailName:SetText("NO CHARACTER SNAPSHOTS YET")
        ui.detailInfo:SetText("Log in to a character to save its gear. Other characters appear after you log into them with Gear Hunter enabled.")
        ui.equipCaption:SetText("")
        ui.lockCaption:SetText("")
        for _,row in ipairs(ui.gearRows) do row:Hide() end
        for _,row in ipairs(ui.lockRows) do row:Hide() end
        return
    end
    local rec=selected.data
    ui.detailName:SetText((rec.name or "Character"):upper().."  |  "..(rec.realm or "").."  |  "..(rec.faction or ""))
    ui.detailInfo:SetText("Lv "..tostring(rec.level or "?").."  |  "..(rec.specName or "").." "..(rec.className or "")..
        "  |  Equipped iLvl "..(rec.itemLevel and string.format("%.1f",rec.itemLevel) or "?")..
        "  |  "..ageLabel(rec.lastSeen))
    ui.equipCaption:SetText("SAVED EQUIPMENT  |  "..tostring(rec.equippedCount or 0).." SLOTS  |  NOT LIVE ON OTHER CHARACTERS")
    for i,row in ipairs(ui.gearRows) do
        local slot=self.slotDefs[i]
        local entry=slot and type(rec.equipment)=="table" and rec.equipment[tostring(slot.id)]
        if slot then
            row:Show()
            row.name:SetText(slot.name..": "..(entry and ("Item #"..tostring(entry.itemID)) or "Empty at last scan"))
            row.level:SetText(entry and ("iLvl "..tostring(entry.level or "?")) or "-")
            if entry and entry.itemID and GetItemInfo then
                local ok,name=pcall(GetItemInfo,entry.itemID)
                if ok and type(name)=="string" then row.name:SetText(slot.name..": "..name) end
            end
            row.entry=entry
            row.icon:SetTexture(entry and (entry.icon or self.missingItemIcon) or self.missingItemIcon)
        else row:Hide() end
    end
    local lockouts={}
    local stamp=now()
    for _,save in ipairs(rec.lockouts or {}) do
        if type(save)=="table" then
            if not safeNumber(save.resetAt) or save.resetAt>stamp then lockouts[#lockouts+1]=save end
        end
    end
    ui.lockCaption:SetText(#lockouts.." SAVED LOCKOUT SNAPSHOTS (UNKNOWN RESETS MAY BE STALE)  |  "..
        (rec.lockoutsCapturedAt and ageLabel(rec.lockoutsCapturedAt) or "NOT SCANNED"))
    ui.lockChild:SetHeight(math.max(1,#lockouts*43))
    local first=math.floor(math.max(0,ui.lockScroll:GetVerticalScroll() or 0)/43)+1
    for i,row in ipairs(ui.lockRows) do
        local save=lockouts[first+i-1]
        if save then
            local pos=first+i-1
            row:ClearAllPoints();row:SetPoint("TOPLEFT",ui.lockChild,"TOPLEFT",0,-(pos-1)*43)
            row.name:SetText((save.name or "Instance").."  |  "..(save.difficultyName or save.kind or ""))
            local reset=save.resetAt and ("  |  RESET IN "..math.max(0,math.floor((save.resetAt-stamp)/3600)).."H") or "  |  RESET UNKNOWN"
            row.info:SetText(tostring(save.progress or 0).." / "..tostring(save.numEncounters or 0).." BOSSES"..reset)
            row:Show()
        else row:Hide() end
    end
end
function GH:CreateAltTrackerPanel(parent)
    local p=panel(parent,29,-150,1542,558)
    local ui={panel=p,rows={},gearRows={},lockRows={},modeButtons={}}
    self.altUI=ui
    label(p,"ALT TRACKER  /  ACCOUNT-WIDE CHARACTER OVERVIEW",17,-13,1100,true,gold)
    label(p,"Compare gear and remembered lockouts across characters. Snapshots are saved when each character is played.",18,-43,1440,false,pale)
    ui.summary=label(p,"",18,-77,1470,false,green)
    local left=panel(p,16,-115,527,404)
    label(left,"YOUR CHARACTERS",11,-10,480,true,gold)
    ui.listScroll=CreateFrame("ScrollFrame",nil,left,"UIPanelScrollFrameTemplate")
    ui.listScroll:SetPoint("TOPLEFT",left,"TOPLEFT",10,-45)
    ui.listScroll:SetPoint("BOTTOMRIGHT",left,"BOTTOMRIGHT",-26,10)
    ui.listChild=CreateFrame("Frame",nil,ui.listScroll)
    ui.listChild:SetSize(479,1);ui.listScroll:SetScrollChild(ui.listChild)
    for i=1,7 do
        local row=CreateFrame("Button",nil,ui.listChild,"BackdropTemplate")
        row:SetSize(474,52);style(row,navy)
        row.title=label(row,"",9,-5,452,false,gold)
        row.note=label(row,"",9,-29,452,false,pale)
        row:SetScript("OnClick",function(self)
            if self.entry then GH.selectedAltGUID=self.entry.guid;ui.lockScroll:SetVerticalScroll(0);GH:RefreshAltTracker() end
        end)
        row:Hide();ui.rows[#ui.rows+1]=row
    end
    ui.listScroll:HookScript("OnVerticalScroll",function() GH:RefreshAltTracker() end)
    local right=panel(p,554,-115,971,404)
    ui.detailName=label(right,"SELECT A CHARACTER",12,-9,940,true,gold)
    ui.detailInfo=label(right,"",12,-35,939,false,pale)
    for i,mode in ipairs({"Equipment","Lockouts"}) do
        local b=button(right,mode:upper(),12+(i-1)*168,-65,158,30,function()
            GH.altTrackerMode=mode
            GH:RefreshAltTracker()
        end)
        ui.modeButtons[#ui.modeButtons+1]={button=b,mode=mode}
    end
    ui.equipView=CreateFrame("Frame",nil,right)
    ui.equipView:SetPoint("TOPLEFT",right,"TOPLEFT",8,-105);ui.equipView:SetSize(952,289)
    ui.equipCaption=label(ui.equipView,"",4,-3,924,false,orange)
    for i=1,16 do
        local row=CreateFrame("Frame",nil,ui.equipView,"BackdropTemplate")
        local col=math.floor((i-1)/8)
        local line=(i-1)%8
        row:SetPoint("TOPLEFT",ui.equipView,"TOPLEFT",4+col*472,-30-line*32)
        row:SetSize(462,30);style(row,navy)
        row.icon=row:CreateTexture(nil,"ARTWORK")
        row.icon:SetPoint("LEFT",row,"LEFT",5,0);row.icon:SetSize(23,23)
        row.name=label(row,"",34,-6,343,false,pale)
        row.level=label(row,"",380,-6,77,false,green)
        ui.gearRows[i]=row
    end
    ui.lockView=CreateFrame("Frame",nil,right)
    ui.lockView:SetPoint("TOPLEFT",right,"TOPLEFT",8,-105);ui.lockView:SetSize(952,289)
    ui.lockCaption=label(ui.lockView,"",5,-3,920,false,orange)
    ui.lockScroll=CreateFrame("ScrollFrame",nil,ui.lockView,"UIPanelScrollFrameTemplate")
    ui.lockScroll:SetPoint("TOPLEFT",ui.lockView,"TOPLEFT",5,-30)
    ui.lockScroll:SetPoint("BOTTOMRIGHT",ui.lockView,"BOTTOMRIGHT",-25,5)
    ui.lockChild=CreateFrame("Frame",nil,ui.lockScroll)
    ui.lockChild:SetSize(917,1);ui.lockScroll:SetScrollChild(ui.lockChild)
    for i=1,6 do
        local row=CreateFrame("Frame",nil,ui.lockChild,"BackdropTemplate")
        row:SetSize(911,41);style(row,navy)
        row.name=label(row,"",9,-4,890,false,gold)
        row.info=label(row,"",9,-22,890,false,pale)
        row:Hide();ui.lockRows[i]=row
    end
    ui.lockScroll:HookScript("OnVerticalScroll",function() GH:RefreshAltTracker() end)
    button(p,"REFRESH THIS CHARACTER",16,-530,291,32,function()
        GH:ScanEquipped()
        if GH.RequestWeeklyFarmData then GH:RequestWeeklyFarmData() end
        GH:CaptureAltSnapshot(true)
        GH:RefreshAltTracker()
    end)
    button(p,"HUNT LIST",322,-530,182,32,function() GH:ShowTab("Hunt List") end)
    button(p,"WEEKLY LOCKOUTS",516,-530,205,32,function() GH:ShowTab("Weekly Farm") end)
    button(p,"COLLECTION DASHBOARD",732,-530,246,32,function() GH:ShowTab("Collection Dashboard") end)
    label(p,"Other character data is last seen, not live.",994,-539,530,false,orange)
    p:Hide()
end
local watch=CreateFrame("Frame")
watch:RegisterEvent("UPDATE_INSTANCE_INFO")
watch:SetScript("OnEvent",function()
    if not GH.db then return end
    GH:CaptureAltSnapshot(true)
end)
