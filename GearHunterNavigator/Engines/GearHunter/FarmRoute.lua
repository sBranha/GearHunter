-- Gear Hunter v0.10.6 - Hunt List Farm Route
-- Group the player's unfinished hunt targets by KNOWN source, without claiming
-- that the game provides road routes, travel times, or unidentified boss pins.
local addonName, NAV = ...
local GH = NAV.GearEngine
local ICON_ROOT="Interface\\AddOns\\GearHunterNavigator\\Art\\UIIcons\\"
local bg={0.018,0.040,0.076,0.99}
local blue={0.036,0.079,0.139,0.99}
local edge={0.41,0.57,0.78,1}
local gold={1,0.82,0.30,1}
local soft={0.83,0.90,1,1}
local green={0.45,1,0.66,1}
local warn={1,0.67,0.37,1}
local function style(f,c,e)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(unpack(c or bg))
    f:SetBackdropBorderColor(unpack(e or edge))
end
local function panel(parent,x,y,w,h)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    f:SetSize(w,h);style(f);return f
end
local function label(parent,message,x,y,width,large,col)
    local text=parent:CreateFontString(nil,"OVERLAY",large and "GameFontNormalLarge" or "GameFontNormal")
    text:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    text:SetWidth(width);text:SetJustifyH("LEFT");text:SetTextColor(unpack(col or soft))
    text:SetText(message or "")
    return text
end
local function button(parent,message,x,y,w,h,fn)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetSize(w,h);style(b,blue)
    b.caption=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
    b.caption:SetAllPoints();b.caption:SetTextColor(unpack(gold));b.caption:SetText(message)
    b:SetScript("OnClick",fn)
    b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(unpack(gold)) end)
    b:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(unpack(edge)) end)
    return b
end
local function validLocation(mapID,x,y)
    return type(mapID)=="number" and mapID>0 and type(x)=="number" and
        type(y)=="number" and x==x and y==y and x>=0 and x<=1 and y>=0 and y<=1
end
local function sourceKey(rec)
    if type(rec)~="table" then return nil end
    if rec.sourceKey then return "o:"..tostring(rec.itemID)..":"..tostring(rec.sourceKey) end
    return table.concat({"s",tostring(rec.itemID or 0),tostring(rec.instanceID or 0),
        tostring(rec.encounterID or 0),tostring(rec.difficulty or 0)},":")
end
local function mapName(mapID)
    if C_Map and C_Map.GetMapInfo then
        local ok,info=pcall(C_Map.GetMapInfo,mapID)
        if ok and info and info.name then return info.name end
    end
    return "Map "..tostring(mapID)
end
local function getSource(gh,target)
    local sources=gh:GetHuntSources(target)
    local preferred=target.preferredSourceKey
    if preferred then
        for _,rec in ipairs(sources) do
            if sourceKey(rec)==preferred then return rec end
        end
    end
    -- Prefer an Adventure Guide instance whose exact journal ID is known;
    -- if none exists, use a merchant location saved while it was visited.
    for _,rec in ipairs(sources) do
        if rec.sourceVerified and type(rec.instanceID)=="number" and rec.instanceID>0 then
            return rec
        end
    end
    for _,rec in ipairs(sources) do
        if rec.sourceObserved and rec.sourceType=="Vendor" and
            validLocation(rec.mapID,rec.mapX,rec.mapY) then return rec end
    end
    return nil
end
local function stopKey(rec)
    if rec.sourceVerified and type(rec.instanceID)=="number" then
        return "instance:"..tostring(rec.instanceID),"Instance"
    end
    if rec.sourceObserved and rec.sourceType=="Vendor" and
        validLocation(rec.mapID,rec.mapX,rec.mapY) then
        -- Do not combine two distinct merchants just because they share a zone.
        return table.concat({"vendor",tostring(rec.mapID),tostring(rec.vendorName or "Unknown"),
            string.format("%.4f",rec.mapX),string.format("%.4f",rec.mapY)},":"),"Vendor"
    end
    return nil
end
function GH:InitFarmRoute()
    if not self.db then return end
    if type(self.db.farmRouteOrder)~="table" then self.db.farmRouteOrder={} end
    if self.farmRoutePosition==nil then self.farmRoutePosition=1 end
end
function GH:BuildFarmRoute()
    self:InitFarmRoute()
    local grouped,stops={},{}
    local missing,total=0,0
    for _,target in pairs(self.db and self.db.huntChecklist or {}) do
        if type(target)=="table" and type(target.itemID)=="number" and not target.done then
            total=total+1
            local rec=getSource(self,target)
            local key,kind
            if rec then key,kind=stopKey(rec) end
            if not key then missing=missing+1
            else
                local stop=grouped[key]
                if not stop then
                    stop={key=key,kind=kind,source=rec,items={},id=rec.instanceID,
                        title=(kind=="Instance" and (rec.instance or "Dungeon / raid") or
                            (rec.vendorName or "Observed vendor")),
                        mapID=rec.mapID,mapX=rec.mapX,mapY=rec.mapY}
                    grouped[key]=stop;stops[#stops+1]=stop
                end
                stop.items[#stop.items+1]={target=target,source=rec}
            end
        end
    end
    for _,stop in ipairs(stops) do
        table.sort(stop.items,function(a,b)
            local an=(a.target.name or ""):lower()
            local bn=(b.target.name or ""):lower()
            return an==bn and a.target.itemID<b.target.itemID or an<bn
        end)
    end
    -- Stable initial order, then the player's saved manual route ordering.
    table.sort(stops,function(a,b)
        local an=(a.title or ""):lower();local bn=(b.title or ""):lower()
        return an==bn and a.key<b.key or an<bn
    end)
    local index={}
    for i,key in ipairs(self.db and self.db.farmRouteOrder or {}) do
        if type(key)=="string" and not index[key] then index[key]=i end
    end
    table.sort(stops,function(a,b)
        local ia,ib=index[a.key],index[b.key]
        if ia and ib then return ia<ib end
        if ia then return true end
        if ib then return false end
        local an=(a.title or ""):lower();local bn=(b.title or ""):lower()
        return an==bn and a.key<b.key or an<bn
    end)
    self.farmRouteStops=stops
    self.farmRouteMissing=missing
    self.farmRouteTotal=total
    return stops,missing,total
end
function GH:SelectFarmStop(key)
    self.farmRouteSelectedKey=key
    self.farmRouteSelectedItemID=nil
    self.farmRouteItemPage=1
    if self.RefreshFarmRoute then self:RefreshFarmRoute() end
end
function GH:MoveFarmStop(delta)
    local stops=self:BuildFarmRoute()
    local pos
    for i,stop in ipairs(stops) do
        if stop.key==self.farmRouteSelectedKey then pos=i;break end
    end
    if not pos then return end
    local nextIndex=pos+delta
    if nextIndex<1 or nextIndex>#stops then return end
    stops[pos],stops[nextIndex]=stops[nextIndex],stops[pos]
    self.db.farmRouteOrder={}
    for _,stop in ipairs(stops) do
        self.db.farmRouteOrder[#self.db.farmRouteOrder+1]=stop.key
    end
    self.farmRoutePosition=nextIndex
    self:RefreshFarmRoute()
end
function GH:NextFarmStop()
    local stops=self:BuildFarmRoute()
    if #stops==0 then return end
    local i=0
    for index,stop in ipairs(stops) do
        if stop.key==self.farmRouteSelectedKey then i=index;break end
    end
    local nextIndex=(i % #stops)+1
    self.farmRoutePosition=nextIndex
    self.farmRouteSelectedKey=stops[nextIndex].key
    self.farmRouteSelectedItemID=nil
    self.farmRouteItemPage=1
    self:RefreshFarmRoute()
end
function GH:FarmRouteSelected()
    local stops=self.farmRouteStops or {}
    for i,stop in ipairs(stops) do
        if stop.key==self.farmRouteSelectedKey then return stop,i end
    end
    return nil,nil
end
function GH:FarmRouteItem()
    local stop=self:FarmRouteSelected()
    if not stop then return nil end
    for _,item in ipairs(stop.items) do
        if item.target.itemID==self.farmRouteSelectedItemID then return item end
    end
    return stop.items[1]
end
function GH:NavigateFarmStop()
    local stop=self:FarmRouteSelected()
    if not stop then self:Print("Select a farm route destination.");return end
    if stop.kind=="Instance" then
        self:GoToRecord(stop.source,"entrance")
    elseif stop.kind=="Vendor" then
        self:SetWaypoint(stop.mapID,stop.mapX,stop.mapY,
            "Last observed: "..stop.title,"observed")
    end
end
function GH:NavigateFarmBoss()
    local item=self:FarmRouteItem()
    if item and item.source.sourceVerified and type(item.source.encounterID)=="number" then
        self:GoToRecord(item.source,"boss")
    else self:Print("No verified boss linked to that item. Try SHOW ENTRANCE.") end
end
function GH:RefreshFarmRoute()
    local ui=self.farmRouteUI
    if not ui or not ui.panel:IsShown() then return end
    local stops,missing,total=self:BuildFarmRoute()
    local selected,index=self:FarmRouteSelected()
    if not selected and #stops>0 then
        selected=stops[1];index=1;self.farmRouteSelectedKey=selected.key
        self.farmRouteSelectedItemID=nil
    end
    local routeCount=total-missing
    ui.summary:SetText(#stops.." DESTINATIONS  |  "..routeCount.." TARGETS WITH KNOWN SOURCES  |  "..missing.." NEED SOURCES")
    ui.scrollChild:SetHeight(math.max(1,#stops*68))
    local first=math.floor(math.max(0,ui.scroll:GetVerticalScroll() or 0)/68)+1
    for i,row in ipairs(ui.stops) do
        local stop=stops[first+i-1]
        if stop then
            local order=first+i-1
            row:ClearAllPoints();row:SetPoint("TOPLEFT",ui.scrollChild,"TOPLEFT",0,-(order-1)*68)
            row.entry=stop
            row.heading:SetText(string.format("%02d   %s",order,stop.title))
            row.note:SetText(stop.kind=="Vendor" and
                (#stop.items.." item(s)  |  Last seen in "..mapName(stop.mapID).." - not verified") or
                (#stop.items.." item(s)  |  Journal dungeon / raid - exact entrance when available"))
            row:SetBackdropBorderColor(unpack(selected==stop and gold or edge))
            row:Show()
        else row.entry=nil;row:Hide() end
    end
    for _,entry in ipairs({{ui.up,index~=nil and index>1},
            {ui.down,index~=nil and index<#stops},{ui.next,#stops>0},
            {ui.entrance,selected~=nil},{ui.boss,false},{ui.guide,false}}) do
        if entry[2] then entry[1]:Enable();entry[1]:SetAlpha(1)
        else entry[1]:Disable();entry[1]:SetAlpha(0.42) end
    end
    if selected then
        ui.stopTitle:SetText(string.format("STOP %d OF %d   -   %s",index,#stops,selected.title))
        ui.stopInfo:SetText(selected.kind=="Vendor" and
            ("Vendor: "..selected.title.." | "..mapName(selected.mapID).."\nLocation recorded when visiting. Merchant may have moved.") or
            "Dungeon / raid source. SHOW ENTRANCE uses an exact Blizzard instance ID.\nSHOW BOSS uses the selected item's verified encounter, if mapped.")
        ui.entrance.caption:SetText(selected.kind=="Vendor" and "LAST SEEN VENDOR" or "SHOW ENTRANCE")
    else
        ui.stopTitle:SetText("NO ROUTABLE TARGETS YET")
        ui.stopInfo:SetText("Add gear to HUNT LIST and index sources in GEAR SEARCH.\nNo coordinates will be invented for missing sources.")
        ui.entrance.caption:SetText("SHOW ENTRANCE")
    end
    local maxPage=selected and math.max(1,math.ceil(#selected.items/5)) or 1
    self.farmRouteItemPage=math.max(1,math.min(maxPage,self.farmRouteItemPage or 1))
    local page=self.farmRouteItemPage
    if ui.prevItems then
        ui.prevItems:SetEnabled(page>1)
        ui.prevItems:SetAlpha(page>1 and 1 or 0.4)
        ui.nextItems:SetEnabled(page<maxPage)
        ui.nextItems:SetAlpha(page<maxPage and 1 or 0.4)
    end
    local chosen=self:FarmRouteItem()
    if selected and chosen then
        local visible=false
        for i=(page-1)*5+1,math.min(page*5,#selected.items) do
            if selected.items[i]==chosen then visible=true;break end
        end
        if not visible then chosen=selected.items[(page-1)*5+1] end
    end
    if chosen then self.farmRouteSelectedItemID=chosen.target.itemID end
    for i,row in ipairs(ui.items) do
        local item=selected and selected.items[(page-1)*5+i]
        if item then
            row.item=item
            row.caption:SetText((item.target.name or ("Item #"..item.target.itemID))..
                (item.source.encounter and ("  |  "..item.source.encounter) or ""))
            row:SetBackdropBorderColor(unpack(chosen==item and gold or edge))
            row:Show()
        else row.item=nil;row:Hide() end
    end
    ui.itemCount:SetText(selected and (#selected.items.." TARGET(S) AT THIS STOP"..
        (#selected.items>5 and (" - PAGE "..page.." / "..maxPage) or "")) or "SELECT A DESTINATION")
    ui.boss:SetEnabled(chosen and chosen.source.sourceVerified and
        type(chosen.source.encounterID)=="number" and selected.kind=="Instance" or false)
    ui.boss:SetAlpha(ui.boss:IsEnabled() and 1 or 0.42)
    ui.guide:SetEnabled(chosen and chosen.source.sourceVerified==true and selected.kind=="Instance" or false)
    ui.guide:SetAlpha(ui.guide:IsEnabled() and 1 or 0.42)
    ui.notes:SetText(missing>0 and
        (missing.." unfinished item(s) lack a usable location. Check their sources in Hunt List / Gear Search.") or
        "All unfinished hunt targets have a recorded destination. Route order is manual, not travel-time optimized.")
end
function GH:CreateFarmRoutePanel(parent)
    local p=panel(parent,29,-150,1542,558)
    local ui={panel=p};self.farmRouteUI=ui
    label(p,"FARM ROUTE - MULTI-ITEM HUNT PLANNER",18,-12,1060,true,gold)
    label(p,"Groups unfinished Hunt List items by verified instance or last-seen vendor. You control the stop order.",18,-41,1420,false,soft)
    ui.summary=label(p,"0 DESTINATIONS",18,-76,850,true,green)
    button(p,"WEEKLY LOCKOUTS",1165,-70,170,34,function() GH:ShowTab("Weekly Farm") end)
    button(p,"HUNT LIST",1343,-70,175,34,function() GH:ShowTab("Hunt List") end)
    local left=panel(p,16,-119,863,411)
    label(left,"PLANNED DESTINATIONS",11,-9,520,true,gold)
    ui.scroll=CreateFrame("ScrollFrame",nil,left,"UIPanelScrollFrameTemplate")
    ui.scroll:SetPoint("TOPLEFT",left,"TOPLEFT",9,-37)
    ui.scroll:SetPoint("BOTTOMRIGHT",left,"BOTTOMRIGHT",-29,8)
    ui.scrollChild=CreateFrame("Frame",nil,ui.scroll)
    ui.scrollChild:SetSize(813,1);ui.scroll:SetScrollChild(ui.scrollChild)
    ui.stops={}
    for i=1,6 do
        local row=CreateFrame("Button",nil,ui.scrollChild,"BackdropTemplate")
        row:SetSize(810,65);style(row,blue)
        row.heading=label(row,"",11,-8,775,true,gold)
        row.note=label(row,"",11,-35,780,false,soft)
        row:SetScript("OnClick",function(self) if self.entry then GH:SelectFarmStop(self.entry.key) end end)
        row:Hide();ui.stops[#ui.stops+1]=row
    end
    ui.scroll:HookScript("OnVerticalScroll",function() GH:RefreshFarmRoute() end)
    local right=panel(p,892,-119,633,411)
    ui.stopTitle=label(right,"SELECT A STOP",12,-12,600,true,gold)
    ui.stopInfo=label(right,"",12,-51,605,false,soft)
    ui.stopInfo:SetHeight(52);ui.stopInfo:SetWordWrap(true)
    ui.itemCount=label(right,"TARGETS",12,-119,424,false,gold)
    ui.prevItems=button(right,"<",530,-111,39,26,function()
        GH.farmRouteItemPage=math.max(1,(GH.farmRouteItemPage or 1)-1)
        GH.farmRouteSelectedItemID=nil
        GH:RefreshFarmRoute()
    end)
    ui.nextItems=button(right,">",574,-111,43,26,function()
        GH.farmRouteItemPage=(GH.farmRouteItemPage or 1)+1
        GH.farmRouteSelectedItemID=nil
        GH:RefreshFarmRoute()
    end)
    ui.items={}
    for i=1,5 do
        local item=button(right,"",12,-144-(i-1)*39,605,35,function(self)
            if self.item then GH.farmRouteSelectedItemID=self.item.target.itemID;GH:RefreshFarmRoute() end
        end)
        item.caption:ClearAllPoints();item.caption:SetPoint("LEFT",item,"LEFT",10,0)
        item.caption:SetWidth(585);item.caption:SetJustifyH("LEFT")
        ui.items[#ui.items+1]=item
    end
    ui.entrance=button(right,"SHOW ENTRANCE",12,-346,200,38,function() GH:NavigateFarmStop() end)
    ui.boss=button(right,"SHOW BOSS",216,-346,194,38,function() GH:NavigateFarmBoss() end)
    ui.guide=button(right,"OPEN GUIDE",414,-346,204,38,function()
        local item=GH:FarmRouteItem();if item then GH:OpenGuide(item.source) end
    end)
    ui.up=button(p,"MOVE UP",20,-535,162,35,function() GH:MoveFarmStop(-1) end)
    ui.down=button(p,"MOVE DOWN",191,-535,162,35,function() GH:MoveFarmStop(1) end)
    ui.next=button(p,"NEXT STOP",362,-535,182,35,function() GH:NextFarmStop() end)
    ui.notes=label(p,"",560,-535,947,false,warn)
    ui.notes:SetHeight(39);ui.notes:SetWordWrap(true)
    p:Hide()
end
