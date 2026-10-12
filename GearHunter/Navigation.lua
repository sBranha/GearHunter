-- Gear Hunter v0.10.3: exact source navigation. No guessed item coordinates.
-- All automatic locations are matched by journal instance ID or encounter ID.
local addonName, GH = ...
local finder = CreateFrame("Frame")
local entranceIndex, bossIndex = {}, {}
local function validCoords(x,y)
    return type(x)=="number" and type(y)=="number" and
        x==x and y==y and x>=0 and x<=1 and y>=0 and y<=1
end
local function posXY(pos)
    if not pos or not pos.GetXY then return nil,nil end
    local ok,x,y=pcall(pos.GetXY,pos)
    if ok and validCoords(x,y) then return x,y end
    return nil,nil
end
local function bossKey(rec)
    return tostring(rec.instanceID or 0)..":"..tostring(rec.encounterID or 0)
end
local function recordValid(rec)
    return type(rec)=="table" and rec.sourceVerified==true and
        type(rec.instanceID)=="number" and rec.instanceID>0
end
local function zoneName(mapID)
    if C_Map and C_Map.GetMapInfo then
        local ok,info=pcall(C_Map.GetMapInfo,mapID)
        if ok and info and info.name then return info.name end
    end
    return "map "..tostring(mapID)
end
function GH:NavigationStatus(message)
    self.navStatus=message
    self:Print(message)
    if self.RefreshGearSearch then self:RefreshGearSearch() end
    if self.Refresh then self:Refresh() end
end

-- A map-canvas pin persists at its precise map coordinate even on dungeon
-- floors, where the Blizzard user-waypoint API generally refuses a waypoint.
-- The pin is cosmetic, not a claim that navigation to a boss is possible.
_G.GearHunterSourceMapPinMixin = _G.GearHunterSourceMapPinMixin or
    (CreateFromMixins and MapCanvasPinMixin and CreateFromMixins(MapCanvasPinMixin) or {})
function GearHunterSourceMapPinMixin:OnLoad()
    if self.UseFrameLevelType then self:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST") end
end
function GearHunterSourceMapPinMixin:OnAcquired(x,y,label)
    self.locationLabel=label
    self:SetSize(30,30)
    if self.SetPosition then self:SetPosition(x,y) end
end
function GearHunterSourceMapPinMixin:OnMouseEnter()
    if GameTooltip then
        GameTooltip:SetOwner(self,"ANCHOR_CURSOR")
        GameTooltip:SetText(self.locationLabel or "Gear Hunter source",1,0.82,0.32)
        GameTooltip:Show()
    end
end
function GearHunterSourceMapPinMixin:OnMouseLeave()
    if GameTooltip then GameTooltip:Hide() end
end
local pinProvider
function GH:EnsureSourceMapProvider()
    if pinProvider then return true end
    if not (WorldMapFrame and WorldMapFrame.AddDataProvider and
        MapCanvasDataProviderMixin and CreateFromMixins) then return false end
    local provider=CreateFromMixins(MapCanvasDataProviderMixin)
    function provider:RemoveAllData()
        if self:GetMap() then self:GetMap():RemoveAllPinsByTemplate("GearHunterSourceMapPinTemplate") end
    end
    function provider:RefreshAllData()
        self:RemoveAllData()
        local target=GH.activeMapPin
        if target and self:GetMap() and self:GetMap():GetMapID()==target.mapID then
            pcall(function()
                self:GetMap():AcquirePin("GearHunterSourceMapPinTemplate",target.x,target.y,target.label)
            end)
        end
    end
    local ok=pcall(WorldMapFrame.AddDataProvider,WorldMapFrame,provider)
    if ok then pinProvider=provider end
    return ok
end
function GH:OpenMap(mapID)
    if InCombatLockdown and InCombatLockdown() then
        self:NavigationStatus("Open the map after combat to see this source.")
        return false
    end
    local opened=false
    if C_Map and C_Map.OpenWorldMap then
        opened=pcall(C_Map.OpenWorldMap,mapID)
    end
    if not opened and ToggleWorldMap then
        if not WorldMapFrame or not WorldMapFrame.IsShown or not WorldMapFrame:IsShown() then
            opened=pcall(ToggleWorldMap)
        else opened=true end
    end
    if WorldMapFrame and WorldMapFrame.SetMapID and mapID then
        local ok=pcall(WorldMapFrame.SetMapID,WorldMapFrame,mapID)
        opened=opened or ok
    end
    self:EnsureSourceMapProvider()
    if pinProvider then pcall(pinProvider.RefreshAllData,pinProvider) end
    if opened and self.frame then self.frame:Hide() end
    return opened
end
function GH:SetWaypoint(mapID,x,y,label,kind)
    if type(mapID)~="number" or not validCoords(x,y) then
        self:NavigationStatus("This source has no verified map coordinates.")
        return false
    end
    -- Replace previous pin: locations are record-specific, not a permanent
    -- zone-wide marker that can be misapplied to the next search result.
    self.activeMapPin={mapID=mapID,x=x,y=y,label=label,kind=kind}
    local native=false
    if C_Map and C_Map.SetUserWaypoint and UiMapPoint and
        UiMapPoint.CreateFromCoordinates then
        local can=true
        if C_Map.CanSetUserWaypointOnMap then
            local ok,allowed=pcall(C_Map.CanSetUserWaypointOnMap,mapID)
            can=ok and allowed==true
        end
        if can then
            local ok,placed=pcall(function()
                return C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID,x,y))
            end)
            native=ok and placed==true
            if native then self.lastGearHunterWaypoint={mapID=mapID,x=x,y=y} end
            if native and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                pcall(C_SuperTrack.SetSuperTrackedUserWaypoint,true)
            end
        end
    end
    local opened=self:OpenMap(mapID)
    if opened then
        self:NavigationStatus((kind=="boss" and "BOSS" or kind=="manual" and "SAVED ENTRANCE" or kind=="observed" and "LAST SEEN VENDOR" or "ENTRANCE")..
            " - "..tostring(label or "Source").." - "..zoneName(mapID)..
            string.format(" (%.1f, %.1f)",x*100,y*100)..
            (native and " - waypoint tracked." or " - location marked on map when supported."))
    else
        self:NavigationStatus("Found "..tostring(label or "source").." on "..zoneName(mapID)..
            ", but WoW could not open its map. Try again out of combat.")
    end
    return opened
end
function GH:OpenGuide(rec)
    if not recordValid(rec) then
        self:Print("No verified Journal source for this item.");return
    end
    if self.scanRunning or self.gearCatalogRunning then
        self:Print("Wait for Gear Hunter indexing/scanning to finish before opening the Adventure Guide.")
        return
    end
    if not self:InitializeJournal() then self:Print("Adventure Guide unavailable.");return end
    if EncounterJournal_OpenJournal then
        self:SafeCallback("Adventure Guide",EncounterJournal_OpenJournal,
            rec.difficulty,rec.instanceID,rec.encounterID,nil,nil,rec.itemID,rec.tier)
    else self:Print("Press Shift+J to open the Adventure Guide: "..(rec.instance or "")) end
end
-- Manual pins are optional user corrections, NOT proof of Blizzard location.
-- v0.10.1 saved a pin per item or entire instance without the boss ID; those
-- legacy saved pins cannot silently replace matched boss coordinates.
function GH:SavePlayerPin(rec)
    rec=rec or self.selected
    if not recordValid(rec) or not rec.itemID then
        self:Print("Select a verified source before saving an entrance.");return
    end
    local mapID=C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos=mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID,"player")
    local x,y=posXY(pos)
    if not x then self:Print("Your current map position is unavailable.");return end
    local key=tostring(rec.instanceID)
    self.db.sourceEntrancePins=self.db.sourceEntrancePins or {}
    self.db.sourceEntrancePins[key]={mapID=mapID,x=x,y=y,sourceInstanceID=rec.instanceID,
        version=3,manual=true}
    self:Print("Saved a PERSONAL entrance pin for "..tostring(rec.instance or "instance")..
        ". Blizzard's official entrance, when available, takes priority.")
end
local function manualEntrance(self,rec)
    local db=self.db
    local pin=db and db.sourceEntrancePins and db.sourceEntrancePins[tostring(rec.instanceID)]
    if type(pin)=="table" and pin.version==3 and pin.manual==true and
        pin.sourceInstanceID==rec.instanceID and type(pin.mapID)=="number" and
        validCoords(pin.x,pin.y) then return pin end
    return nil
end
local function collectMaps(rec)
    local maps,seen={},{}
    local function add(id)
        if type(id)=="number" and id>0 and not seen[id] then
            seen[id]=true;maps[#maps+1]=id
        end
    end
    local function descendants(root)
        if not (C_Map and C_Map.GetMapChildrenInfo) or not root then return end
        local ok,children=pcall(C_Map.GetMapChildrenInfo,root,nil,true)
        if ok and type(children)=="table" then
            for _,info in ipairs(children) do
                -- Dungeon floors (4), Micro (5) and zone maps (3) are all
                -- possible journal boss/entrance hosts. Do not filter them out.
                add(info.mapID)
            end
        end
    end
    if EJ_GetInstanceInfo and rec and rec.instanceID then
        local ok,_,_,_,_,_,_,areaMap=pcall(EJ_GetInstanceInfo,rec.instanceID)
        if ok and type(areaMap)=="number" and areaMap>0 then
            add(areaMap);descendants(areaMap)
        end
    end
    local id=C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    for _=1,12 do
        if not id or seen[id] then break end
        add(id)
        local ok,info=pcall(C_Map.GetMapInfo,id)
        id=ok and info and info.parentMapID or nil
    end
    -- 946 is the cosmic root, 947 Azeroth. Include ALL discovered descendants
    -- so a boss on a dungeon floor or an old-expansion entrance is not missed.
    for _,root in ipairs({946,947}) do add(root);descendants(root) end
    return maps
end
local function readBossOnMap(mapID,rec)
    if type(rec.encounterID)~="number" then return nil end
    local api=C_EncounterJournal and C_EncounterJournal.GetEncountersOnMap
    if api then
        local ok,list=pcall(api,mapID)
        if ok and type(list)=="table" then
            for _,boss in ipairs(list) do
                if boss.encounterID==rec.encounterID and validCoords(boss.mapX,boss.mapY) then
                    return {mapID=mapID,x=boss.mapX,y=boss.mapY,encounterID=rec.encounterID,
                        instanceID=rec.instanceID}
                end
            end
        end
    end
    -- Older instance maps still expose exact Journal boss pins here.
    if EJ_GetMapEncounter then
        for i=1,60 do
            local ok,x,y,instanceID,_,_,encounterID=pcall(EJ_GetMapEncounter,mapID,i,true)
            if not ok or not x then break end
            if instanceID==rec.instanceID and encounterID==rec.encounterID and validCoords(x,y) then
                return {mapID=mapID,x=x,y=y,encounterID=rec.encounterID,instanceID=rec.instanceID}
            end
        end
    end
    return nil
end
local function readEntrancesOnMap(mapID)
    local api=C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap
    if not api then return end
    local ok,list=pcall(api,mapID)
    if not ok or type(list)~="table" then return end
    for _,entry in ipairs(list) do
        local journalID=entry.journalInstanceID
        if type(journalID)=="number" and journalID>0 then
            local x,y=posXY(entry.position)
            if x then
                -- Exact Blizzard journal instance ID, never substring matching.
                entranceIndex[journalID]={mapID=mapID,x=x,y=y,instanceID=journalID}
            end
        end
    end
end
function GH:CancelMapSearch()
    self.mapSearch=nil
    finder:SetScript("OnUpdate",nil)
end
function GH:ClearSourceMapMarker()
    self.activeMapPin=nil
    if pinProvider then pcall(pinProvider.RefreshAllData,pinProvider) end
    local previous=self.lastGearHunterWaypoint
    self.lastGearHunterWaypoint=nil
    if previous and C_Map and C_Map.GetUserWaypoint and C_Map.ClearUserWaypoint then
        local ok,current=pcall(C_Map.GetUserWaypoint)
        if ok and type(current)=="table" and current.uiMapID==previous.mapID then
            local x,y=posXY(current.position)
            if x and math.abs(x-previous.x)<0.0001 and math.abs(y-previous.y)<0.0001 then
                pcall(C_Map.ClearUserWaypoint)
            end
        end
    end
end
local function resultFor(self,rec,kind)
    if kind=="boss" then
        local found=bossIndex[bossKey(rec)]
        if found and found.instanceID==rec.instanceID and found.encounterID==rec.encounterID then
            return found,rec.encounter or rec.name or "Boss", "boss"
        end
    else
        local found=entranceIndex[rec.instanceID]
        if found and found.instanceID==rec.instanceID then
            return found,(rec.instance or "Instance").." entrance","entrance"
        end
    end
    return nil
end
local function navigate(self,rec,kind)
    local found,label,source=resultFor(self,rec,kind)
    if found then self:SetWaypoint(found.mapID,found.x,found.y,label,source);return true end
    return false
end
function GH:GoToRecord(rec,kind)
    self:CancelMapSearch()
    self:ClearSourceMapMarker()
    if not recordValid(rec) then
        self:NavigationStatus("No verified source available for this item. Index the Adventure Guide first.")
        return false
    end
    kind=(kind=="boss") and "boss" or "entrance"
    if kind=="boss" and type(rec.encounterID)~="number" then
        self:NavigationStatus("This item has no confirmed boss. Use SHOW ENTRANCE or OPEN GUIDE.")
        return false
    end
    if navigate(self,rec,kind) then return true end
    self.mapSearch={rec=rec,kind=kind,maps=collectMaps(rec),position=1}
    self:NavigationStatus("Locating "..(kind=="boss" and "boss "..(rec.encounter or "") or
        "entrance for "..(rec.instance or "source")).." using Blizzard maps...")
    finder:SetScript("OnUpdate",function()
        local job=GH.mapSearch
        if not job then finder:SetScript("OnUpdate",nil);return end
        for _=1,24 do
            local mapID=job.maps[job.position]
            if not mapID then
                GH:CancelMapSearch()
                if navigate(GH,job.rec,job.kind) then return end
                if job.kind=="entrance" then
                    local manual=manualEntrance(GH,job.rec)
                    if manual then
                        GH:SetWaypoint(manual.mapID,manual.x,manual.y,
                            (job.rec.instance or "Instance").." - your saved entrance","manual")
                        return
                    end
                end
                GH:NavigationStatus((job.kind=="boss" and
                    "Blizzard has no boss coordinates for this encounter." or
                    "Blizzard has no entrance coordinates for this instance.")..
                    " Use OPEN GUIDE; no guessed map pin was placed.")
                return
            end
            job.position=job.position+1
            if job.kind=="boss" then
                local result=readBossOnMap(mapID,job.rec)
                if result then
                    bossIndex[bossKey(job.rec)]=result
                    GH:CancelMapSearch()
                    GH:SetWaypoint(result.mapID,result.x,result.y,
                        (job.rec.encounter or job.rec.name or "Boss"),"boss")
                    return
                end
            else
                readEntrancesOnMap(mapID)
                if navigate(GH,job.rec,"entrance") then
                    GH:CancelMapSearch()
                    return
                end
            end
        end
    end)
    return true
end
