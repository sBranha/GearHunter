-- Gear Hunter v0.11.5 -- Farm Session Tracker.
-- Boss defeats and player loot are separate observations; no invented drop sources.
local addonName, GH = ...
local DARK={0.018,0.034,0.067,0.99}
local NAVY={0.030,0.066,0.119,0.98}
local EDGE={0.40,0.53,0.72,1}
local GOLD={1,0.83,0.33,1}
local PALE={0.85,0.92,1,1}
local GREEN={0.35,1,0.61,1}
local WARN={1,0.65,0.36,1}
local LIMIT_RUNS=30
local LIMIT_EVENTS=300

local function style(f,back)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(unpack(back or DARK));f:SetBackdropBorderColor(unpack(EDGE))
end
local function panel(parent,x,y,w,h)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);f:SetSize(w,h);style(f)
    return f
end
local function label(parent,s,x,y,w,big,col)
    local f=parent:CreateFontString(nil,"OVERLAY",big and "GameFontNormalLarge" or "GameFontNormal")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);f:SetWidth(w)
    f:SetJustifyH("LEFT");f:SetTextColor(unpack(col or PALE));f:SetText(s or "")
    return f
end
local function button(parent,name,x,y,w,h,callback)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetSize(w,h);style(b,NAVY)
    b.caption=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
    b.caption:SetAllPoints();b.caption:SetTextColor(unpack(GOLD));b.caption:SetText(name)
    b:SetScript("OnClick",callback)
    b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(unpack(GOLD)) end)
    b:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(unpack(EDGE)) end)
    return b
end
local function now()
    if type(GetServerTime)=="function" then
        local ok,t=pcall(GetServerTime)
        if ok and type(t)=="number" and t>0 then return t end
    end
    if type(time)=="function" then
        local ok,t=pcall(time)
        if ok and type(t)=="number" then return t end
    end
    return 0
end
local function dateLabel(t)
    if type(t)~="number" or t<1 then return "Unknown time" end
    if type(date)=="function" then
        local ok,s=pcall(date,"%m/%d %H:%M",t)
        if ok and type(s)=="string" then return s end
    end
    return tostring(t)
end
local function timeLabel(t)
    if type(t)~="number" or t<1 then return "--:--" end
    if type(date)=="function" then
        local ok,s=pcall(date,"%H:%M",t)
        if ok and type(s)=="string" then return s end
    end
    return "--:--"
end
local function elapsed(s,e)
    local seconds=math.max(0,math.floor((e or now())-(s or now())))
    if seconds>=3600 then return string.format("%dh %02dm",math.floor(seconds/3600),math.floor(seconds%3600/60)) end
    return string.format("%dm",math.floor(seconds/60))
end
local function classKey()
    local guid=UnitGUID and UnitGUID("player")
    if type(guid)=="string" and guid~="" then return guid end
    local name=UnitName and UnitName("player") or "Unknown"
    local realm=GetRealmName and GetRealmName() or "Realm"
    return tostring(name).."-"..tostring(realm)
end
local function classLabel()
    local name=UnitName and UnitName("player") or "Character"
    local realm=GetRealmName and GetRealmName() or ""
    return tostring(name)..(realm~="" and (" - "..tostring(realm)) or "")
end
local function selectedRun(self)
    local data=self.farmCharacterData
    if type(data)~="table" then return nil end
    for _,s in ipairs(data.sessions or {}) do
        if s.id==self.farmSelectedRunID then return s end
    end
    return nil
end
function GH:InitFarmSessions()
    if not self.db then return end
    if type(self.db.farmSessions)~="table" then self.db.farmSessions={} end
    local key=classKey()
    if self.farmCharacterKey~=key or not self.farmCharacterData then
        self.farmCharacterKey=key
        if type(self.db.farmSessions[key])~="table" then
            self.db.farmSessions[key]={label=classLabel(),sessions={}}
        end
        self.farmCharacterData=self.db.farmSessions[key]
        self.farmSelectedRunID=nil
    end
    local data=self.farmCharacterData
    data.label=classLabel()
    if type(data.sessions)~="table" then data.sessions={} end
    -- Data is saved per character and bounded to avoid unbounded addon memory.
    while #data.sessions>LIMIT_RUNS do table.remove(data.sessions) end
    if data.activeID then
        local found=false
        for _,s in ipairs(data.sessions) do
            if s.id==data.activeID and s.finishedAt==nil then found=true;break end
        end
        if not found then data.activeID=nil end
    end
end
function GH:GetActiveFarmSession()
    local data=self.farmCharacterData
    if type(data)~="table" or not data.activeID then return nil end
    for _,s in ipairs(data.sessions or {}) do
        if s.id==data.activeID and not s.finishedAt then return s end
    end
    return nil
end
function GH:StartFarmSession()
    self:InitFarmSessions()
    if self:GetActiveFarmSession() then
        self:Print("A farm session is already running.")
        return false
    end
    local data=self.farmCharacterData
    if not data then return false end
    local started=now()
    data.serial=(tonumber(data.serial) or 0)+1
    local s={id=tostring(started).."-"..tostring(data.serial),startedAt=started,
        label=classLabel(),events={},bossCount=0,lootCount=0}
    table.insert(data.sessions,1,s)
    while #data.sessions>LIMIT_RUNS do table.remove(data.sessions) end
    data.activeID=s.id
    self.farmSelectedRunID=s.id;self.farmSelectedEventIndex=nil
    self.farmRunPage=1;self.farmEventPage=1
    self:Print("Farm tracking started. Boss kills and loot will be recorded separately.")
    if self.Refresh then self:Refresh() end
    return true
end
function GH:StopFarmSession(silent)
    local s=self:GetActiveFarmSession()
    if not s then
        if not silent then self:Print("No farm session is running.") end
        return false
    end
    s.finishedAt=now()
    self.farmCharacterData.activeID=nil
    if not silent then self:Print("Farm session finished: "..tostring(s.bossCount or 0).." kills, "..tostring(s.lootCount or 0).." loot events.") end
    if not silent and self.Refresh and self.frame and self.frame:IsShown() then self:Refresh() end
    return true
end
function GH:RecordFarmEvent(rec)
    local s=self:GetActiveFarmSession()
    if not s or type(rec)~="table" then return false end
    s.events=s.events or {}
    if #s.events>=LIMIT_EVENTS then
        s.overflow=(s.overflow or 0)+1
        return false
    end
    rec.when=now()
    s.events[#s.events+1]=rec
    if rec.kind=="Boss" then s.bossCount=(s.bossCount or 0)+1
    elseif rec.kind=="Loot" then s.lootCount=(s.lootCount or 0)+1 end
    if self.farmUI and self.farmUI.panel:IsShown() and self.farmSelectedRunID==s.id then
        self:RefreshFarmSessions()
    end
    return true
end
function GH:FarmEncounterEnd(id,name,difficulty,groupSize,success)
    if success~=1 or type(id)~="number" or type(name)~="string" or name=="" then return end
    local instanceName,_,_,_,_,_,_,instanceMapID
    if type(GetInstanceInfo)=="function" then
        local ok,a,_,_,_,_,_,_,b=pcall(GetInstanceInfo)
        if ok then instanceName=a;instanceMapID=b end
    end
    self:RecordFarmEvent({kind="Boss",name=name,encounterID=id,
        instance=type(instanceName)=="string" and instanceName or nil,
        instanceMapID=type(instanceMapID)=="number" and instanceMapID or nil,
        difficulty=type(difficulty)=="number" and difficulty or nil})
end
local function templatePattern(format)
    if type(format)~="string" or format=="" then return nil end
    local escaped=format:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])","%%%1")
    -- The localized Blizzard strings identify self-loot; other players' loot
    -- cannot qualify even if the message contains a valid item link.
    escaped=escaped:gsub("%%%%s",".-"):gsub("%%%%d","%%d+")
    return "^"..escaped.."$"
end
local function isSelfLoot(message)
    for _,f in ipairs({LOOT_ITEM_SELF,LOOT_ITEM_SELF_MULTIPLE,
        LOOT_ITEM_CREATED_SELF,LOOT_ITEM_CREATED_SELF_MULTIPLE,
        LOOT_ITEM_PUSHED_SELF,LOOT_ITEM_PUSHED_SELF_MULTIPLE}) do
        local pattern=templatePattern(f)
        if pattern and message:match(pattern) then return true end
    end
    return false
end
function GH:FarmChatLoot(message)
    if type(message)~="string" or (issecretvalue and issecretvalue(message)) then return end
    if not self:GetActiveFarmSession() or not message:find("|Hitem:",1,true) then return end
    if not isSelfLoot(message) then return end
    local id=tonumber(message:match("|Hitem:(%d+)"))
    if not id or id<1 then return end
    local link=message:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)") or
        message:match("(|Hitem:.-|h%[.-%]|h)")
    local name=link and link:match("%[(.-)%]") or nil
    if (not name or name=="") and C_Item and type(C_Item.GetItemNameByID)=="function" then
        local ok,ret=pcall(C_Item.GetItemNameByID,id)
        if ok then name=ret end
    end
    self:RecordFarmEvent({kind="Loot",itemID=id,name=name or ("Item "..id),link=link})
end
function GH:GetFarmSessionCounts()
    local s=self:GetActiveFarmSession()
    return s and (s.bossCount or 0) or 0,s and (s.lootCount or 0) or 0
end
function GH:FindFarmEventSource(ev)
    if type(ev)~="table" or not ev.itemID then return nil end
    for _,r in pairs(self.gearSearchIndex or {}) do
        if type(r)=="table" and r.itemID==ev.itemID and (r.sourceVerified or r.sourceObserved) then
            return r
        end
    end
    return nil
end
function GH:RefreshFarmSessions()
    local ui=self.farmUI
    if not ui or not ui.panel:IsShown() then return end
    self:InitFarmSessions()
    local sessions=self.farmCharacterData and self.farmCharacterData.sessions or {}
    if not selectedRun(self) then self.farmSelectedRunID=sessions[1] and sessions[1].id or nil end
    local current=selectedRun(self)
    local active=self:GetActiveFarmSession()
    ui.state:SetText(active and ("RECORDING  /  "..elapsed(active.startedAt).."  /  "..
        (active.bossCount or 0).." bosses  /  "..(active.lootCount or 0).." loot events") or
        "No session running. Press START SESSION before you begin farming.")
    ui.toggle.caption:SetText(active and "FINISH SESSION" or "START SESSION")
    ui.summary:SetText(""..#sessions.." saved runs  /  Current character: "..(self.farmCharacterData.label or "Unknown"))
    self.farmRunPage=math.max(1,math.min(self.farmRunPage or 1,math.max(1,math.ceil(#sessions/#ui.runRows))))
    ui.runPage:SetText("RUNS  "..self.farmRunPage.." / "..math.max(1,math.ceil(#sessions/#ui.runRows)))
    for i,row in ipairs(ui.runRows) do
        local s=sessions[(self.farmRunPage-1)*#ui.runRows+i]
        if s then
            row.record=s
            row.caption:SetText((s.id==self.farmCharacterData.activeID and "|cff66ff88LIVE  |r" or "")..dateLabel(s.startedAt))
            row.note:SetText((s.bossCount or 0).." bosses   /   "..(s.lootCount or 0).." loot  /  "..elapsed(s.startedAt,s.finishedAt))
            row:SetBackdropBorderColor(unpack(s.id==self.farmSelectedRunID and GOLD or EDGE))
            row:Show()
        else row.record=nil;row:Hide() end
    end
    local events=current and current.events or {}
    local size=#events
    self.farmEventPage=math.max(1,math.min(self.farmEventPage or 1,math.max(1,math.ceil(size/#ui.eventRows))))
    ui.eventPage:SetText("EVENTS  "..self.farmEventPage.." / "..math.max(1,math.ceil(size/#ui.eventRows)))
    ui.runDetail:SetText(current and ("SESSION  /  "..dateLabel(current.startedAt)..
        (current.finishedAt and "  /  FINISHED" or "  /  RECORDING").."  /  "..
        (current.bossCount or 0).." bosses  +  "..(current.lootCount or 0).." loot events") or
        "No sessions recorded yet.")
    for i,row in ipairs(ui.eventRows) do
        local index=size-((self.farmEventPage-1)*#ui.eventRows+i-1)
        local e=events[index]
        if e then
            row.record=e;row.eventIndex=index
            row.caption:SetText("["..timeLabel(e.when).."]  "..(e.kind=="Boss" and "BOSS  " or "LOOT  ")..
                tostring(e.name or "Unknown"))
            row.note:SetText(e.kind=="Boss" and (e.instance or "Instance unknown") or
                ("Item #"..tostring(e.itemID or "?").."  /  Logged as player loot, not a verified boss drop"))
            row:SetBackdropBorderColor(unpack(self.farmSelectedEventIndex==index and GOLD or EDGE))
            row:Show()
        else row.record=nil;row:Hide() end
    end
    local e=current and current.events and current.events[self.farmSelectedEventIndex or -1] or nil
    ui.selectedEvent=e
    ui.eventTitle:SetText(e and (e.kind.."  /  "..tostring(e.name or "Unknown")) or "Choose a recorded event")
    ui.detail:SetText(not e and "Boss kills appear when WoW reports a successful encounter.\n\nLoot entries come from your own loot chat messages.\n\nGear Hunter doesn't assume that a looted item came from the last boss you defeated." or
        ("Recorded: "..dateLabel(e.when).."\n\n"..
        (e.kind=="Boss" and ("Encounter: "..tostring(e.name).."\nInstance: "..tostring(e.instance or "Not reported")..
            "\nDifficulty ID: "..tostring(e.difficulty or "Unknown").."\n\nThis is a confirmed kill, not proof of loot eligibility.") or
            ("Item ID: "..tostring(e.itemID).."\n\nThe item was reported in your loot messages.\nIts specific drop source is NOT inferred from this session."))))
    ui.search:SetEnabled(e~=nil and e.itemID~=nil)
    ui.search:SetAlpha(e and e.itemID and 1 or 0.38)
    ui.hunt:SetEnabled(e~=nil and e.itemID~=nil)
    ui.hunt:SetAlpha(e and e.itemID and 1 or 0.38)
    ui.empty:SetShown(size==0)
end
function GH:CreateFarmSessionPanel(parent)
    local p=panel(parent,29,-150,1542,558)
    local ui={panel=p};self.farmUI=ui
    label(p,"FARM SESSION TRACKER",18,-12,900,true,GOLD)
    label(p,"Record your boss kills and personal loot while you farm. No guessed drops or locations.",18,-43,1420,false,PALE)
    ui.toggle=button(p,"START SESSION",17,-77,230,37,function()
        if GH:GetActiveFarmSession() then GH:StopFarmSession() else GH:StartFarmSession() end
        GH:RefreshFarmSessions()
    end)
    button(p,"BOSS LOOT HUNTER",257,-77,234,37,function() GH:ShowTab("Boss Loot Hunter") end)
    button(p,"HUNT LIST",501,-77,180,37,function() GH:ShowTab("Hunt List") end)
    button(p,"WEEKLY FARM",691,-77,195,37,function() GH:ShowTab("Weekly Farm") end)
    ui.state=label(p,"",905,-82,620,false,GREEN)
    ui.summary=label(p,"",17,-123,650,false,PALE)
    ui.runDetail=label(p,"",382,-123,1144,false,GOLD)
    local left=panel(p,15,-151,352,355)
    label(left,"SAVED RUNS",10,-9,315,true,GOLD)
    ui.runRows={}
    for i=1,7 do
        local row=button(left,"",9,-40-(i-1)*40,332,37,function(b)
            if not b.record then return end
            GH.farmSelectedRunID=b.record.id;GH.farmSelectedEventIndex=nil;GH.farmEventPage=1
            GH:RefreshFarmSessions()
        end)
        row.caption:ClearAllPoints();row.caption:SetPoint("TOPLEFT",row,"TOPLEFT",8,-3)
        row.caption:SetWidth(313);row.caption:SetJustifyH("LEFT");row.caption:SetWordWrap(false)
        row.note=label(row,"",8,-20,313,false,PALE)
        row.note:SetFontObject("GameFontNormalSmall");row.note:SetWordWrap(false)
        ui.runRows[i]=row
    end
    local mid=panel(p,377,-151,715,355)
    label(mid,"RECORDED EVENTS (NEWEST FIRST)",10,-9,690,true,GOLD)
    ui.eventRows={}
    for i=1,7 do
        local row=button(mid,"",9,-40-(i-1)*40,695,37,function(b)
            GH.farmSelectedEventIndex=b.eventIndex
            GH:RefreshFarmSessions()
        end)
        row.caption:ClearAllPoints();row.caption:SetPoint("TOPLEFT",row,"TOPLEFT",8,-3)
        row.caption:SetWidth(677);row.caption:SetJustifyH("LEFT");row.caption:SetWordWrap(false)
        row.note=label(row,"",8,-20,675,false,PALE)
        row.note:SetFontObject("GameFontNormalSmall");row.note:SetWordWrap(false)
        ui.eventRows[i]=row
    end
    ui.empty=label(mid,"Start a session to log boss kills and self-looted items.",15,-120,680,false,WARN)
    local right=panel(p,1102,-151,425,355)
    label(right,"EVENT DETAILS",12,-9,396,true,GOLD)
    ui.eventTitle=label(right,"Choose a recorded event",12,-46,390,true,GREEN)
    ui.eventTitle:SetHeight(49);ui.eventTitle:SetWordWrap(true)
    ui.detail=label(right,"",12,-105,390,false,PALE)
    ui.detail:SetHeight(208);ui.detail:SetJustifyV("TOP");ui.detail:SetWordWrap(true)
    ui.runPrev=button(p,"PREV RUNS",18,-513,127,30,function()
        GH.farmRunPage=math.max(1,(GH.farmRunPage or 1)-1);GH:RefreshFarmSessions()
    end)
    ui.runPage=label(p,"RUNS 1/1",153,-517,105,false,GOLD)
    ui.runNext=button(p,"NEXT RUNS",264,-513,112,30,function()
        GH.farmRunPage=(GH.farmRunPage or 1)+1;GH:RefreshFarmSessions()
    end)
    button(p,"PREV EVENTS",389,-513,144,30,function()
        GH.farmEventPage=math.max(1,(GH.farmEventPage or 1)-1);GH:RefreshFarmSessions()
    end)
    ui.eventPage=label(p,"EVENTS 1/1",542,-517,113,false,GOLD)
    button(p,"NEXT EVENTS",668,-513,144,30,function()
        GH.farmEventPage=(GH.farmEventPage or 1)+1;GH:RefreshFarmSessions()
    end)
    ui.search=button(p,"FIND ITEM SOURCE",1112,-513,196,30,function()
        local e=ui.selectedEvent
        if not e or not e.itemID then return end
        GH.gearSearchQuery=tostring(e.itemID)
        if GH.gearSearchUI and GH.gearSearchUI.search then
            GH.gearSearchUI.search:SetText(GH.gearSearchQuery)
        end
        GH:ShowTab("Gear Search")
    end)
    ui.hunt=button(p,"ADD TO HUNT LIST",1317,-513,197,30,function()
        local e=ui.selectedEvent
        if not e or not e.itemID then return end
        if GH.FindHuntRecord and GH.AddHuntItem then
            local rec=GH:FindHuntRecord(tostring(e.itemID))
            if rec then GH:AddHuntItem(rec) end
        end
    end)
    -- Keep the displayed elapsed time current even during quiet farming.
    p:SetScript("OnUpdate",function(self,delta)
        self.farmRefreshTimer=(self.farmRefreshTimer or 0)+(delta or 0)
        if self.farmRefreshTimer>=10 then
            self.farmRefreshTimer=0
            if GH:GetActiveFarmSession() then GH:RefreshFarmSessions() end
        end
    end)
    p:Hide()
end
-- Event listeners start logging only when a session is explicitly active.
local watcher=CreateFrame("Frame")
watcher:RegisterEvent("ENCOUNTER_END")
watcher:RegisterEvent("CHAT_MSG_LOOT")
watcher:RegisterEvent("PLAYER_LOGOUT")
watcher:SetScript("OnEvent",function(_,event,...)
    if not GH.db then return end
    if event=="PLAYER_LOGOUT" then GH:StopFarmSession(true)
    elseif event=="ENCOUNTER_END" then GH:FarmEncounterEnd(...)
    elseif event=="CHAT_MSG_LOOT" then GH:FarmChatLoot(...) end
end)
