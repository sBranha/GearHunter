-- Gear Hunter 0.10.8 - Weekly Farm / real character instance lockouts.
-- Uses only the active character's Blizzard saved-instance and world-boss APIs.
-- A missing saved entry does NOT prove a boss is farmable or loot-eligible.
local addonName, NAV = ...
local GH = NAV.GearEngine
local ink={0.016,0.035,0.066,0.99}
local navy={0.031,0.067,0.115,0.99}
local border={0.43,0.56,0.74,1}
local gold={1.0,0.83,0.31,1}
local pale={0.84,0.91,1,1}
local green={0.39,1,0.65,1}
local orange={1,0.67,0.38,1}
local function style(f,color,trim)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(unpack(color or ink));f:SetBackdropBorderColor(unpack(trim or border))
end
local function panel(parent,x,y,w,h)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);f:SetSize(w,h);style(f)
    return f
end
local function label(parent,message,x,y,w,large,color)
    local t=parent:CreateFontString(nil,"OVERLAY",large and "GameFontNormalLarge" or "GameFontNormal")
    t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    t:SetWidth(w);t:SetJustifyH("LEFT")
    t:SetTextColor(unpack(color or pale));t:SetText(message or "")
    return t
end
local function button(parent,message,x,y,w,h,fn)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetSize(w,h);style(b,navy)
    b.caption=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
    b.caption:SetAllPoints();b.caption:SetTextColor(unpack(gold));b.caption:SetText(message)
    b:SetScript("OnClick",fn)
    b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(unpack(gold)) end)
    b:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(unpack(border)) end)
    return b
end
local function normalized(value)
    if type(value)~="string" then return "" end
    return value:lower():gsub("[^%w]","")
end
local function availableSeconds(seconds)
    if type(seconds)~="number" or seconds<0 or seconds~=seconds then return "RESET NOT REPORTED" end
    seconds=math.floor(seconds)
    if seconds<60 then return "< 1 MIN" end
    local days=math.floor(seconds/86400)
    local hours=math.floor((seconds%86400)/3600)
    local minutes=math.floor((seconds%3600)/60)
    if days>0 then return string.format("%dD %dH",days,hours) end
    if hours>0 then return string.format("%dH %dM",hours,minutes) end
    return string.format("%dM",minutes)
end
local function safeCount(fn)
    if type(fn)~="function" then return 0 end
    local ok,num=pcall(fn)
    return ok and type(num)=="number" and num>0 and math.min(200,num) or 0
end
function GH:GetWeeklyResetRemaining()
    if C_DateAndTime and type(C_DateAndTime.GetSecondsUntilWeeklyReset)=="function" then
        local ok,n=pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
        if ok and type(n)=="number" and n>=0 then return n end
    end
    return nil
end
function GH:ReadWeeklyFarmData()
    local saves={}
    for i=1,safeCount(GetNumSavedInstances) do
        if type(GetSavedInstanceInfo)=="function" then
            local ok,name,lockID,reset,difficulty,locked,extended,_,isRaid,_,diffName,numEncounters,progress,__,instanceMapID=
                pcall(GetSavedInstanceInfo,i)
            if ok and type(name)=="string" and name~="" and locked==true then
                local v={name=name,id=lockID,reset=reset,difficulty=difficulty,
                    difficultyName=diffName,extended=extended==true,
                    isRaid=isRaid==true,kind=isRaid and "Raid" or "Dungeon",
                    numEncounters=tonumber(numEncounters) or 0,
                    progress=tonumber(progress) or 0,instanceMapID=instanceMapID,
                    encounters={},index=i}
                for j=1,math.min(tonumber(numEncounters) or 0,80) do
                    if type(GetSavedInstanceEncounterInfo)=="function" then
                        local bossOK,bossName,_,killed=pcall(GetSavedInstanceEncounterInfo,i,j)
                        if bossOK and type(bossName)=="string" and bossName~="" then
                            v.encounters[#v.encounters+1]={name=bossName,killed=killed==true}
                        end
                    end
                end
                v.key="save:"..normalized(name)..":"..tostring(difficulty or 0)..":"..tostring(lockID or 0)
                saves[#saves+1]=v
            end
        end
    end
    for i=1,safeCount(GetNumSavedWorldBosses) do
        if type(GetSavedWorldBossInfo)=="function" then
            local ok,name,id,reset=pcall(GetSavedWorldBossInfo,i)
            if ok and type(name)=="string" and name~="" then
                saves[#saves+1]={name=name,id=id,reset=reset,kind="World Boss",isWorldBoss=true,
                    key="world:"..tostring(id or normalized(name)),encounters={{name=name,killed=true}},progress=1,numEncounters=1}
            end
        end
    end
    table.sort(saves,function(a,b)
        if a.kind~=b.kind then return a.kind<b.kind end
        if a.name~=b.name then return a.name<b.name end
        return tostring(a.difficultyName or "")<tostring(b.difficultyName or "")
    end)
    self.weeklyFarmSaves=saves
    return saves
end
function GH:RequestWeeklyFarmData()
    if type(RequestRaidInfo)=="function" then
        self.weeklyFarmWaiting=true
        local ok=pcall(RequestRaidInfo)
        if not ok then self.weeklyFarmWaiting=false end
    else
        self.weeklyFarmWaiting=false
    end
    self:ReadWeeklyFarmData()
    if self.RefreshWeeklyFarm then self:RefreshWeeklyFarm() end
end
function GH:GetWeeklyFarmMatches(save)
    local matches={}
    if not save or not self.db or type(self.db.huntChecklist)~="table" or not self.GetHuntSources then
        return matches
    end
    for _,target in pairs(self.db.huntChecklist) do
        if type(target)=="table" and not target.done and type(target.itemID)=="number" then
            for _,source in ipairs(self:GetHuntSources(target) or {}) do
                local matchesInstance=source.sourceVerified==true and
                    normalized(source.instance)==normalized(save.name) and
                    (type(source.difficulty)~="number" or type(save.difficulty)~="number" or
                        source.difficulty==save.difficulty)
                if save.isWorldBoss then
                    matchesInstance=normalized(source.encounter)==normalized(save.name) and
                        source.sourceVerified==true
                end
                if matchesInstance then
                    local bossState="UNKNOWN BOSS STATUS"
                    if save.isWorldBoss then bossState="DEFEATED ON THIS CHARACTER"
                    elseif type(source.encounter)=="string" and source.encounter~="" then
                        for _,boss in ipairs(save.encounters or {}) do
                            if normalized(boss.name)==normalized(source.encounter) then
                                bossState=boss.killed and "BOSS DEFEATED" or "BOSS NOT MARKED KILLED"
                                break
                            end
                        end
                    end
                    matches[#matches+1]={target=target,source=source,bossState=bossState}
                    break -- one instance match per item, not one row for each loot difficulty
                end
            end
        end
    end
    table.sort(matches,function(a,b) return (a.target.name or "")<(b.target.name or "") end)
    return matches
end
local function sourceForMap(gh,save)
    for _,item in ipairs(gh:GetWeeklyFarmMatches(save)) do
        if item.source.sourceVerified==true and type(item.source.instanceID)=="number" then
            return item.source
        end
    end
    return nil
end
local function matchesFilter(save,filter)
    if filter=="Raids" then return save.kind=="Raid" end
    if filter=="Dungeons" then return save.kind=="Dungeon" end
    if filter=="World Bosses" then return save.kind=="World Boss" end
    return true
end
function GH:RefreshWeeklyFarm()
    local ui=self.weeklyUI
    if not ui or not ui.panel:IsShown() then return end
    local all=self:ReadWeeklyFarmData()
    local saves={}
    for _,save in ipairs(all) do
        if matchesFilter(save,self.weeklyFarmFilter or "All") then saves[#saves+1]=save end
    end
    local reset=self:GetWeeklyResetRemaining()
    local player=UnitName and UnitName("player") or "Current character"
    ui.summary:SetText((player or "Current character").."  |  "..#all.." ACTIVE SAVED LOCKOUTS"..
        "  |  WEEKLY RESET IN "..availableSeconds(reset))
    ui.status:SetText(self.weeklyFarmWaiting and "REQUESTING FRESH LOCKOUT DATA FROM BLIZZARD..." or
        (#all==0 and "NO ACTIVE SAVED LOCKOUTS REPORTED; THIS DOES NOT CONFIRM LOOT ELIGIBILITY." or
            "LIVE CHARACTER SAVED-INSTANCE DATA  |  DUNGEON RESET RULES CAN DIFFER"))
    for _,filter in ipairs(ui.filters) do
        filter.button:SetBackdropBorderColor(unpack(filter.name==(self.weeklyFarmFilter or "All") and gold or border))
    end
    local selected
    for _,save in ipairs(saves) do
        if save.key==self.weeklyFarmSelectedKey then selected=save;break end
    end
    if not selected and #saves>0 then selected=saves[1];self.weeklyFarmSelectedKey=selected.key end
    if #saves==0 then self.weeklyFarmSelectedKey=nil end
    ui.listChild:SetHeight(math.max(1,#saves*53))
    local first=math.floor(math.max(0,ui.listScroll:GetVerticalScroll() or 0)/53)+1
    for i,row in ipairs(ui.rows) do
        local entry=saves[first+i-1]
        if entry then
            local pos=first+i-1
            row:ClearAllPoints();row:SetPoint("TOPLEFT",ui.listChild,"TOPLEFT",0,-(pos-1)*53)
            row.entry=entry
            row.title:SetText(entry.name.."  |  "..(entry.difficultyName or entry.kind))
            local value=entry.isWorldBoss and "WORLD BOSS DEFEATED" or
                (tostring(entry.progress or 0).." / "..tostring(entry.numEncounters or 0).." BOSSES")
            row.note:SetText(value.."  |  RESETS IN "..availableSeconds(entry.reset)..(entry.extended and "  |  EXTENDED" or ""))
            row:SetBackdropBorderColor(unpack(entry==selected and gold or border))
            row:Show()
        else row.entry=nil;row:Hide() end
    end
    if not selected then
        ui.detailName:SetText("NO SAVED INSTANCE SELECTED")
        ui.detailInfo:SetText("WoW does not report an active save matching this filter.\nUse REFRESH LOCKOUTS after entering or completing an instance.")
    else
        ui.detailName:SetText(selected.name:upper().."  |  "..(selected.difficultyName or selected.kind))
        ui.detailInfo:SetText((selected.isWorldBoss and "WORLD BOSS LOOT LOCKOUT" or "BOSSES ON THIS DIFFICULTY")..
            "  |  RESETS IN "..availableSeconds(selected.reset))
    end
    ui.encounterChild:SetHeight(math.max(1,(selected and #selected.encounters or 0)*36))
    local firstBoss=math.floor(math.max(0,ui.encounterScroll:GetVerticalScroll() or 0)/36)+1
    for i,row in ipairs(ui.bossRows) do
        local boss=selected and selected.encounters[firstBoss+i-1]
        if boss then
            row:ClearAllPoints();row:SetPoint("TOPLEFT",ui.encounterChild,"TOPLEFT",0,-(firstBoss+i-2)*36)
            row.name:SetText((boss.killed and "|cffff7777DEFEATED|r  " or "|cff70ffa0NOT DEFEATED|r  ")..boss.name)
            row:Show()
        else row:Hide() end
    end
    local targets=selected and self:GetWeeklyFarmMatches(selected) or {}
    ui.targetsTitle:SetText(#targets.." UNFINISHED HUNT LIST TARGET(S) LINKED TO THIS SAVE")
    for i,row in ipairs(ui.targets) do
        local item=targets[i]
        if item then
            row:SetText((item.target.name or ("Item #"..tostring(item.target.itemID))).."  |  "..item.bossState)
            row:Show()
        else row:Hide() end
    end
    ui.targetsMore:SetText(#targets>3 and ("...AND "..(#targets-3).." MORE; SEE HUNT LIST") or
        "Boss status does not guarantee loot eligibility or a specific drop.")
    local rec=selected and sourceForMap(self,selected)
    ui.entrance:SetEnabled(rec~=nil)
    ui.entrance:SetAlpha(rec and 1 or 0.45)
    ui.guide:SetEnabled(rec~=nil)
    ui.guide:SetAlpha(rec and 1 or 0.45)
end
function GH:CreateWeeklyFarmPanel(parent)
    local p=panel(parent,29,-150,1542,558)
    local ui={panel=p,filters={},rows={},bossRows={},targets={}}
    self.weeklyUI=ui
    label(p,"WEEKLY FARM TRACKER  /  INSTANCE LOCKOUTS",17,-13,1090,true,gold)
    label(p,"Real saved boss kills and reset timers for THIS CHARACTER. Unlisted sources are unknown, not confirmed available.",18,-43,1440,false,pale)
    ui.summary=label(p,"CURRENT CHARACTER | CHECKING LOCKOUTS",18,-77,1140,true,green)
    button(p,"REFRESH LOCKOUTS",1168,-71,352,34,function() GH:RequestWeeklyFarmData() end)
    ui.status=label(p,"",18,-113,1450,false,orange)
    local left=panel(p,16,-145,732,381)
    label(left,"SAVED RAIDS / DUNGEONS / WORLD BOSSES",11,-9,670,true,gold)
    for i,config in ipairs({{"ALL","All"},{"RAIDS","Raids"},{"DUNGEONS","Dungeons"},{"WORLD BOSSES","World Bosses"}}) do
        local b=button(left,config[1],12+(i-1)*177,-40,170,30,function()
            GH.weeklyFarmFilter=config[2]
            GH.weeklyFarmSelectedKey=nil
            ui.listScroll:SetVerticalScroll(0)
            GH:RefreshWeeklyFarm()
        end)
        ui.filters[#ui.filters+1]={button=b,name=config[2]}
    end
    ui.listScroll=CreateFrame("ScrollFrame",nil,left,"UIPanelScrollFrameTemplate")
    ui.listScroll:SetPoint("TOPLEFT",left,"TOPLEFT",10,-81)
    ui.listScroll:SetPoint("BOTTOMRIGHT",left,"BOTTOMRIGHT",-26,9)
    ui.listChild=CreateFrame("Frame",nil,ui.listScroll)
    ui.listChild:SetSize(688,1);ui.listScroll:SetScrollChild(ui.listChild)
    for i=1,6 do
        local row=CreateFrame("Button",nil,ui.listChild,"BackdropTemplate")
        row:SetSize(681,50);style(row,navy)
        row.title=label(row,"",9,-5,655,false,gold)
        row.note=label(row,"",9,-27,655,false,pale)
        row:SetScript("OnClick",function(self)
            if self.entry then
                GH.weeklyFarmSelectedKey=self.entry.key
                ui.encounterScroll:SetVerticalScroll(0)
                GH:RefreshWeeklyFarm()
            end
        end)
        row:Hide();ui.rows[#ui.rows+1]=row
    end
    ui.listScroll:HookScript("OnVerticalScroll",function() GH:RefreshWeeklyFarm() end)
    local right=panel(p,758,-145,768,381)
    ui.detailName=label(right,"SELECT A LOCKOUT",12,-10,742,true,gold)
    ui.detailInfo=label(right,"",12,-38,735,false,pale)
    ui.detailInfo:SetHeight(38);ui.detailInfo:SetWordWrap(true)
    ui.encounterScroll=CreateFrame("ScrollFrame",nil,right,"UIPanelScrollFrameTemplate")
    ui.encounterScroll:SetPoint("TOPLEFT",right,"TOPLEFT",12,-81)
    ui.encounterScroll:SetSize(740,159)
    ui.encounterChild=CreateFrame("Frame",nil,ui.encounterScroll)
    ui.encounterChild:SetSize(710,1);ui.encounterScroll:SetScrollChild(ui.encounterChild)
    for i=1,5 do
        local r=CreateFrame("Frame",nil,ui.encounterChild,"BackdropTemplate")
        r:SetSize(705,33);style(r,navy)
        r.name=label(r,"",10,-7,684,false,pale)
        r:Hide();ui.bossRows[#ui.bossRows+1]=r
    end
    ui.encounterScroll:HookScript("OnVerticalScroll",function() GH:RefreshWeeklyFarm() end)
    ui.targetsTitle=label(right,"0 HUNT TARGETS LINKED TO THIS SAVE",12,-249,725,false,gold)
    for i=1,3 do
        local r=label(right,"",14,-270-(i-1)*24,725,false,pale)
        ui.targets[#ui.targets+1]=r
    end
    ui.targetsMore=label(right,"",14,-346,725,false,orange)
    button(p,"BACK TO HUNT LIST",16,-536,190,32,function() GH:ShowTab("Hunt List") end)
    button(p,"FARM ROUTE",214,-536,172,32,function() GH:ShowTab("Farm Route") end)
    button(p,"ALT TRACKER",394,-536,180,32,function() GH:ShowTab("Alt Tracker") end)
    ui.entrance=button(p,"SHOW SOURCE ENTRANCE",948,-536,280,32,function()
        local selected
        for _,v in ipairs(GH.weeklyFarmSaves or {}) do
            if v.key==GH.weeklyFarmSelectedKey then selected=v;break end
        end
        local rec=selected and sourceForMap(GH,selected)
        if rec then GH:GoToRecord(rec,"entrance") end
    end)
    ui.guide=button(p,"OPEN ADVENTURE GUIDE",1238,-536,288,32,function()
        local selected
        for _,v in ipairs(GH.weeklyFarmSaves or {}) do
            if v.key==GH.weeklyFarmSelectedKey then selected=v;break end
        end
        local rec=selected and sourceForMap(GH,selected)
        if rec then GH:OpenGuide(rec) end
    end)
    p:Hide()
end
local watcher=CreateFrame("Frame")
watcher:RegisterEvent("UPDATE_INSTANCE_INFO")
watcher:SetScript("OnEvent",function()
    if not GH.weeklyUI or not GH.weeklyUI.panel:IsShown() then return end
    GH.weeklyFarmWaiting=false
    GH:RefreshWeeklyFarm()
end)
