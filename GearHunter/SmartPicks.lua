-- Gear Hunter v0.10.7: transparent, level-aware upgrade recommendations.
-- Data comes ONLY from the current character's scanned Encounter Journal loot
-- and live bag/equipment APIs. No DPS simulation, invented drop rates, or
-- speculative boss coordinates. The score is explicitly a sorting heuristic.
local addonName, GH = ...
local ink={0.016,0.035,0.066,0.99}
local navy={0.031,0.067,0.115,0.99}
local edge={0.43,0.56,0.74,1}
local gold={1.0,0.83,0.31,1}
local pale={0.83,0.91,1,1}
local green={0.39,1.0,0.65,1}
local amber={1,0.70,0.38,1}
local function style(f,color,trim)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(unpack(color or ink));f:SetBackdropBorderColor(unpack(trim or edge))
end
local function panel(parent,x,y,w,h)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);f:SetSize(w,h);style(f)
    return f
end
local function label(parent,s,x,y,width,big,col)
    local f=parent:CreateFontString(nil,"OVERLAY",big and "GameFontNormalLarge" or "GameFontNormal")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    f:SetWidth(width);f:SetJustifyH("LEFT");f:SetTextColor(unpack(col or pale));f:SetText(s or "")
    return f
end
local function button(parent,s,x,y,w,h,fn)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetSize(w,h);style(b,navy)
    b.caption=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    b.caption:SetAllPoints();b.caption:SetTextColor(unpack(gold));b.caption:SetText(s)
    b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(unpack(gold)) end)
    b:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(unpack(edge)) end)
    b:SetScript("OnClick",fn)
    return b
end
local function number(v)
    return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge and v
end
local function tier(rec)
    if rec.fromBag then return 5, "IN YOUR BAGS" end
    if not rec.sourceVerified then return 0, "UNVERIFIED" end
    if rec.raid then
        local difficulty=tonumber(rec.difficulty)
        if difficulty==17 then return 3,"RAID FINDER" end
        if difficulty==14 then return 2,"NORMAL RAID" end
        if difficulty==15 then return 1,"HEROIC RAID" end
        if difficulty==16 then return 1,"MYTHIC RAID" end
        return 1,"RAID" -- Access still depends on group and lockout.
    end
    if rec.mythicPlus then return 2,"MYTHIC+ DUNGEON" end
    return 4,"DUNGEON"
end
local function sourceFilterMatches(rec,filter)
    if filter=="Bags" then return rec.fromBag==true end
    if filter=="Dungeon" then return not rec.fromBag and rec.sourceVerified and not rec.raid end
    if filter=="Raid" then return rec.raid==true and rec.sourceVerified==true end
    return true
end
local function key(rec,slot)
    return table.concat({tostring(rec.itemID or 0),tostring(slot or 0),
        tostring(rec.instanceID or 0),tostring(rec.encounterID or 0),
        tostring(rec.difficulty or 0),tostring(rec.keystoneLevel or 0),
        rec.fromBag and "bag" or "source"},":")
end
local function describe(gh,rec)
    if rec.fromBag then return "Already in your bags - no farm trip needed" end
    if rec.sourceVerified then
        local mode=gh.DescribeDifficulty and gh:DescribeDifficulty(rec.difficulty,rec.raid,rec) or ""
        return tostring(rec.instance or "Known instance").."  |  "..tostring(mode)..
            (rec.encounter and ("  |  "..rec.encounter) or "")
    end
    return "Unknown source; not ranked"
end
function GH:InitializeSmartPicks()
    self.smartMode=self.smartMode or "Balanced"
    self.smartSourceFilter=self.smartSourceFilter or "All"
    self.smartSlotFilter=self.smartSlotFilter or 0
    if self.smartTopPerSlot==nil then self.smartTopPerSlot=true end
end
function GH:BuildSmartPicks()
    self:InitializeSmartPicks()
    -- Use the same +1, class/spec Journal-filtered and level-checked records
    -- as the existing Upgrades tab, but include all raid/dungeon source filters.
    local pool=self.GetVisibleItems and self:GetVisibleItems("Upgrades",self.smartSlotFilter,true) or {}
    local scored={}
    local mode=self.smartMode or "Balanced"
    for _,rec in ipairs(pool) do
        if type(rec)=="table" and number(rec.level) and type(rec.itemID)=="number" and
            (rec.fromBag or rec.sourceVerified) and sourceFilterMatches(rec,self.smartSourceFilter) then
            local gain=self:Gain(rec)
            local slot=self:EffectiveSlot(rec)
            if number(gain) and gain>=1 and slot then
                local access,source=tier(rec)
                local accessPoints=({[1]=25,[2]=65,[3]=105,[4]=145,[5]=240})[access] or 0
                -- Source convenience is a manually defined CATEGORY ranking,
                -- not an observed probability or an eligibility guarantee.
                local score
                if mode=="Biggest Gain" then score=gain*1000+accessPoints
                elseif mode=="Source Ease" then score=accessPoints*1000+math.min(gain,999)
                else score=gain*8+accessPoints end
                scored[#scored+1]={record=rec,gain=gain,slot=slot,
                    ease=access,source=source,accessPoints=accessPoints,score=score,
                    key=key(rec,slot)}
            end
        end
    end
    table.sort(scored,function(a,b)
        if a.score~=b.score then return a.score>b.score end
        if a.gain~=b.gain then return a.gain>b.gain end
        if a.slot~=b.slot then return a.slot<b.slot end
        return a.key<b.key
    end)
    local result={}
    local seen,perSlot={},{}
    for _,pick in ipairs(scored) do
        -- Avoid the same item repeated across LFR/Normal/Heroic/Mythic
        -- or different encounters taking every recommendation row.
        local distinct=tostring(pick.slot)..":"..tostring(pick.record.itemID)
        if not seen[distinct] and (not self.smartTopPerSlot or (perSlot[pick.slot] or 0)<3) then
            seen[distinct]=true
            perSlot[pick.slot]=(perSlot[pick.slot] or 0)+1
            result[#result+1]=pick
        end
    end
    return result,#scored
end
function GH:SmartPickSelected()
    for _,entry in ipairs(self.smartPicks or {}) do
        if entry.key==self.smartSelectedKey then return entry end
    end
    return (self.smartPicks or {})[1]
end
function GH:SmartPickGoToUpgrade()
    local pick=self:SmartPickSelected()
    if not pick then return end
    if self.db and self.db.options then self.db.options.sourceFilter="All" end
    self.slot=pick.slot
    self:ShowTab("Upgrades")
    self:SelectItem(pick.record)
end
function GH:SmartPickTrack()
    local pick=self:SmartPickSelected()
    if pick and self.AddHuntItem then self:AddHuntItem(pick.record) end
end
function GH:SmartPickMap()
    local pick=self:SmartPickSelected()
    if pick and pick.record.sourceVerified and not pick.record.fromBag then
        self:GoToRecord(pick.record)
    end
end
function GH:RefreshSmartPicks()
    local ui=self.smartUI
    if not ui or not ui.panel:IsShown() then return end
    local picks,total=self:BuildSmartPicks()
    self.smartPicks=picks
    local current=self:SmartPickSelected()
    self.smartSelectedKey=current and current.key or nil
    local count=#picks
    local slots={}
    for _,pick in ipairs(picks) do slots[pick.slot]=true end
    local nslots=0;for _ in pairs(slots) do nslots=nslots+1 end
    ui.count:SetText(count.." PICKS  |  "..total.." ELIGIBLE SOURCE OPTIONS  |  "..nslots.." GEAR SLOTS")
    ui.slotButton.caption:SetText("SLOT: "..(self.smartSlotFilter==0 and "ALL" or
        tostring(self.slotNames[self.smartSlotFilter] or "OTHER")))
    ui.limitButton.caption:SetText(self.smartTopPerSlot and "TOP 3 / SLOT" or "SHOW ALL")
    for _,b in ipairs(ui.filters) do
        local active=(b.group=="mode" and self.smartMode==b.value) or
            (b.group=="source" and self.smartSourceFilter==b.value)
        b:SetBackdropBorderColor(unpack(active and gold or edge))
    end
    ui.scrollChild:SetHeight(math.max(1,count*44))
    local scroll=ui.scroll:GetVerticalScroll() or 0
    if type(scroll)~="number" then scroll=0 end
    local first=math.floor(math.max(0,scroll)/44)+1
    for i,row in ipairs(ui.rows) do
        local idx=first+i-1
        local pick=picks[idx]
        if pick then
            local rec=pick.record
            row:ClearAllPoints();row:SetPoint("TOPLEFT",ui.scrollChild,"TOPLEFT",0,-(idx-1)*44)
            row.pick=pick
            row.icon:SetTexture(self:GetDisplayItemIcon(rec))
            row.name:SetText((rec.name or ("Item "..rec.itemID)).."  |  "..(self.slotNames[pick.slot] or "Gear"))
            row.desc:SetText("+"..tostring(pick.gain).." iLvl   |   "..pick.source.."   |   "..(rec.instance or "Owned"))
            row.score:SetText("+"..pick.gain.."  /  "..pick.score)
            row:SetBackdropBorderColor(unpack(current and current.key==pick.key and gold or edge))
            row:Show()
        else row.pick=nil;row:Hide() end
    end
    if current then
        local rec=current.record
        local own=self.equipped and self.equipped[current.slot]
        ui.itemTitle:SetText(rec.name or ("Item #"..rec.itemID))
        ui.itemIcon:SetTexture(self:GetDisplayItemIcon(rec))
        ui.itemLevel:SetText("iLvl "..tostring(rec.level or "?").."   |   +"..current.gain.." over "..
            tostring(own and own.level or 0).." in "..tostring(self.slotNames[current.slot] or "slot"))
        ui.source:SetText(describe(self,rec))
        ui.score:SetText("SORT SCORE: "..current.score.."\n\nGain: +"..current.gain..
            " item levels\nSource group: "..current.source.."\nSource estimate: "..current.accessPoints.."\n\n"..
            "Sorting only; not DPS, drop odds, key access, or lockout verification.")
        ui.map:SetEnabled(rec.sourceVerified==true and not rec.fromBag)
        ui.map:SetAlpha(ui.map:IsEnabled() and 1 or 0.4)
        ui.track.caption:SetText(self.IsHuntTracked and self:IsHuntTracked(rec.itemID) and
            "UPDATE HUNT LIST" or "ADD TO HUNT LIST")
    else
        ui.itemTitle:SetText("NO KNOWN UPGRADES")
        ui.itemIcon:SetTexture(self.missingItemIcon)
        ui.itemLevel:SetText("")
        ui.source:SetText("Scan Journal, or check your bags. Change the source / slot filters if needed.")
        ui.score:SetText("Only the current character's +1 item-level upgrades with known sources are ranked.")
        ui.map:SetEnabled(false);ui.map:SetAlpha(0.4)
        ui.track.caption:SetText("ADD TO HUNT LIST")
    end
    for _,b in ipairs({ui.track,ui.open}) do
        b:SetEnabled(current~=nil);b:SetAlpha(current and 1 or 0.4)
    end
end
function GH:CreateSmartPicksPanel(parent)
    self:InitializeSmartPicks()
    local p=panel(parent,29,-150,1542,558)
    local ui={panel=p,filters={},rows={}}
    self.smartUI=ui
    label(p,"SMART PICKS - PERSONALIZED GEAR RECOMMENDATIONS",18,-11,1110,true,gold)
    label(p,"Real gear +1 or higher. Transparent iLvl/source sorting; not simulated DPS or guaranteed loot.",18,-40,1470,false,pale)
    local function filter(text,x,w,group,value)
        local b=button(p,text,x,-78,w,31,function()
            if group=="mode" then GH.smartMode=value
            else GH.smartSourceFilter=value end
            GH.smartSelectedKey=nil
            if ui.scroll then ui.scroll:SetVerticalScroll(0) end
            GH:RefreshSmartPicks()
        end)
        b.group=group;b.value=value
        ui.filters[#ui.filters+1]=b
    end
    filter("BALANCED",18,162,"mode","Balanced")
    filter("BIGGEST GAIN",185,146,"mode","Biggest Gain")
    filter("SOURCE EASE",336,155,"mode","Source Ease")
    filter("ALL SOURCES",510,146,"source","All")
    filter("IN BAGS",661,108,"source","Bags")
    filter("DUNGEONS",774,126,"source","Dungeon")
    filter("RAIDS",905,88,"source","Raid")
    ui.slotButton=button(p,"SLOT: ALL",1003,-78,210,31,function()
        local current=GH.smartSlotFilter or 0
        local nextID=0
        if current==0 then nextID=GH.slotDefs[1].id
        else
            for i,info in ipairs(GH.slotDefs) do
                if info.id==current then nextID=GH.slotDefs[i+1] and GH.slotDefs[i+1].id or 0;break end
            end
        end
        GH.smartSlotFilter=nextID;GH.smartSelectedKey=nil
        ui.scroll:SetVerticalScroll(0);GH:RefreshSmartPicks()
    end)
    ui.limitButton=button(p,"TOP 3 / SLOT",1218,-78,302,31,function()
        GH.smartTopPerSlot=not GH.smartTopPerSlot
        GH.smartSelectedKey=nil;ui.scroll:SetVerticalScroll(0);GH:RefreshSmartPicks()
    end)
    local left=panel(p,16,-122,957,392)
    ui.count=label(left,"0 PICKS",10,-8,916,false,green)
    ui.scroll=CreateFrame("ScrollFrame",nil,left,"UIPanelScrollFrameTemplate")
    ui.scroll:SetPoint("TOPLEFT",left,"TOPLEFT",10,-33)
    ui.scroll:SetPoint("BOTTOMRIGHT",left,"BOTTOMRIGHT",-29,9)
    ui.scrollChild=CreateFrame("Frame",nil,ui.scroll)
    ui.scrollChild:SetSize(908,1);ui.scroll:SetScrollChild(ui.scrollChild)
    for i=1,9 do
        local row=CreateFrame("Button",nil,ui.scrollChild,"BackdropTemplate")
        row:SetSize(907,42);style(row,navy)
        row.icon=row:CreateTexture(nil,"ARTWORK")
        row.icon:SetPoint("LEFT",row,"LEFT",5,0);row.icon:SetSize(33,33)
        row.name=label(row,"",45,-4,625,false,gold)
        row.desc=label(row,"",45,-22,735,false,pale)
        row.score=label(row,"",754,-9,142,false,green)
        row.score:SetJustifyH("RIGHT")
        row:SetScript("OnClick",function(self)
            if self.pick then GH.smartSelectedKey=self.pick.key;GH:RefreshSmartPicks() end
        end)
        row:SetScript("OnEnter",function(self)
            local rec=self.pick and self.pick.record
            if rec and rec.link and GameTooltip then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                if not pcall(GameTooltip.SetHyperlink,GameTooltip,rec.link) then
                    GameTooltip:SetText(rec.name or "Gear")
                end
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        row:Hide();ui.rows[#ui.rows+1]=row
    end
    ui.scroll:HookScript("OnVerticalScroll",function() GH:RefreshSmartPicks() end)
    local right=panel(p,984,-122,542,392)
    label(right,"RECOMMENDED ITEM",13,-10,510,true,gold)
    ui.itemIcon=right:CreateTexture(nil,"ARTWORK")
    ui.itemIcon:SetPoint("TOPLEFT",right,"TOPLEFT",14,-47);ui.itemIcon:SetSize(53,53)
    ui.itemTitle=label(right,"",78,-47,449,true,gold)
    ui.itemTitle:SetHeight(43);ui.itemTitle:SetWordWrap(true)
    ui.itemLevel=label(right,"",78,-93,450,false,green)
    label(right,"KNOWN SOURCE",14,-129,510,false,gold)
    ui.source=label(right,"",14,-151,507,false,pale)
    ui.source:SetHeight(55);ui.source:SetWordWrap(true)
    ui.score=label(right,"",14,-219,507,false,pale)
    ui.score:SetHeight(150);ui.score:SetWordWrap(true)
    ui.map=button(right,"SHOW SOURCE MAP",14,-338,164,36,function() GH:SmartPickMap() end)
    ui.track=button(right,"ADD TO HUNT LIST",185,-338,166,36,function() GH:SmartPickTrack() end)
    ui.open=button(right,"SEE UPGRADES",358,-338,167,36,function() GH:SmartPickGoToUpgrade() end)
    ui.notes=label(p,"Ranking uses scanned journal loot + your bags. Source ease is a rough category estimate, not travel time or drop chance.",18,-529,1325,false,amber)
    button(p,"SCAN JOURNAL",1360,-524,158,31,function()
        if GH.scanRunning then GH:CancelJournalScan() else GH:StartJournalScan() end
    end)
    p:Hide()
end
