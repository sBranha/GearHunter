local addonName, GH = ...
local getThemeAccent
local GH_ICON_ROOT = "Interface\\AddOns\\GearHunter\\Art\\UIIcons\\"
local T={bg={0.012,0.027,0.050,0.99},panel={0.018,0.039,0.068,0.985},
    dark={0.022,0.050,0.092,0.99},red={0.65,0.035,0.056,1},red2={0.40,0.045,0.075,1},
    gold={1.00,0.81,0.29,1},grey={0.76,0.84,0.94,1},green={0.20,1.00,0.40,1},
    border={0.43,0.52,0.59,1}}
local function backdrop(frame,color,border)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    frame:SetBackdropColor(unpack(color or T.panel))
    frame:SetBackdropBorderColor(unpack(border or T.border))
end
local function panel(parent,x,y,w,h,color)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    f:SetSize(w,h);backdrop(f,color or T.panel)
    return f
end
local function label(parent,body,x,y,size,color,width,justify)
    local font=parent:CreateFontString(nil,"OVERLAY",size=="large" and "GameFontNormalLarge" or "GameFontNormal")
    font:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    if width then font:SetWidth(width);font:SetJustifyH(justify or "LEFT") end
    if color then font:SetTextColor(unpack(color)) end
    font:SetText(body or "")
    return font
end
local function button(parent,text,x,y,w,h,onClick,col)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    b:SetSize(w,h)
    backdrop(b,col or T.dark)
    local lbl=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
    lbl:SetAllPoints();lbl:SetJustifyH("CENTER");lbl:SetText(text)
    lbl:SetTextColor(1,1,1)
    b.text=lbl
    b:SetScript("OnEnter",function(self)
        self:SetBackdropBorderColor(unpack(T.gold))
        self:SetBackdropColor(0.08,0.18,0.38,1)
    end)
    b:SetScript("OnLeave",function(self)
        self:SetBackdropBorderColor(unpack(T.border))
        self:SetBackdropColor(unpack(col or T.dark))
    end)
    b:SetScript("OnClick",onClick)
    return b
end
local function itemTooltip(frame,rec)
    if not rec or not rec.link then return end
    GameTooltip:SetOwner(frame,"ANCHOR_RIGHT")
    local ok=pcall(GameTooltip.SetHyperlink,GameTooltip,rec.link)
    if not ok then GameTooltip:SetText(rec.name or "Item") end
    GameTooltip:Show()
    if GameTooltip_ShowCompareItem then pcall(GameTooltip_ShowCompareItem, GameTooltip) end
end
function GH:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self.frame:Hide()
    else
        self.frame:Show();self:ScanEquipped();self:Refresh()
        if not self.scanRunning and not self.firstScanStarted then
            self.firstScanStarted=true
            self:StartJournalScan()
        end
    end
end
function GH:SetTab(tab)
    self.tab=tab
    if self.CancelMapSearch then self:CancelMapSearch() end
    self.selected=nil;self.navStatus=nil
    self:Refresh()
end
function GH:ShowTab(tab)
    if not self.frame then return end
    if not self.frame:IsShown() then self.frame:Show();self:ScanEquipped() end
    self:SetTab(tab)
    if tab=="Weekly Farm" and self.RequestWeeklyFarmData then self:RequestWeeklyFarmData() end
    if tab~="Boss Loot Hunter" and tab~="Gear Search" and tab~="Transmog Hunter" and tab~="Hunt List" and tab~="Farm Route" and tab~="Weekly Farm" and tab~="Alt Tracker" and tab~="Collection Dashboard" and tab~="Farm Session" and not self.scanRunning and not self.firstScanStarted then
        self.firstScanStarted=true
        self:StartJournalScan()
    end
end
function GH:SelectItem(rec)
    if self.CancelMapSearch then self:CancelMapSearch() end
    self.selected=rec
    self.navStatus=nil
    self:Refresh()
end
local function renderDetail(self)
    local d=self.detail
    local rec=self.selected or (self.tab=="Character" and self.featuredUpgrade)
    local isGear=rec and rec.isEquipped
    d.ownIcon:Hide();d.ownButton:Hide();d.ownName:SetText("")
    d.mapButton.text:SetText("SHOW ON WORLD MAP")
    d.guideButton.text:SetText("OPEN ADVENTURE GUIDE")
    if self.tab=="Settings" then
        d.title:SetText("DATA AND LIMITS")
        d.name:SetText("Gear Hunter settings")
        d.ilevel:SetText("Level-aware equipment / v0.11.9")
        d.icon:SetTexture(GH_ICON_ROOT.."settings.tga")
        d.descr:SetText("Data from your equipped gear and Blizzard's Encounter Journal.\n\nTonight is a difficulty preference, not eligibility or guaranteed loot.\n\nBest Item Level is not simulated Best in Slot.\n\nOnly verified sources can open map pins.")
    elseif not rec then
        d.title:SetText(self.tab=="Character" and "YOUR EQUIPMENT" or "CHOOSE YOUR NEXT TARGET")
        d.name:SetText(self.tab=="Character" and "Choose a gear slot" or "Find. Upgrade. Navigate.")
        d.ilevel:SetText(self.tab=="Character" and "Hover to preview upgrades" or "Even +1 counts")
        d.icon:SetTexture(GH_ICON_ROOT.."item-placeholder.tga")
        d.descr:SetText(self.tab=="Character" and
            "This shows your own character and the equipment you have on.\n\nHover a slot for its current item and a shortlist of verified upgrade sources.\n\nClick the slot to see EVERY scanned upgrade at least +1 item level higher, then choose an item to see its source and map waypoint." or
            self.tab=="My Gear" and
            "Select your equipped item to see its upgrade track and maximum possible item level, when Blizzard provides that data.\n\nTo see an exact currency cost, use the in-game item-upgrade vendor." or
            self.tab=="Tonight" and
            "Choose the highest Mythic+ key and raid difficulty you plan to run above the list.\n\nTargets here use verified loot sources at or below those limits. Click a target to navigate to its source." or
            "Scan the Adventure Guide. Choose an item and see its verified dungeon or raid source.\n\nThe Upgrade Route tab groups targets by destination.")
    elseif isGear then
        local upgrade=rec.upgrade
        d.title:SetText("YOUR EQUIPPED ITEM")
        d.name:SetText(rec.name or "Equipped item")
        d.ilevel:SetText("Equipped iLvl "..tostring(rec.level or "?"))
        d.icon:SetTexture(self:GetDisplayItemIcon(rec))
        local desc="SLOT: "..tostring(self.slotNames[rec.equippedSlot] or "Unknown").."\n"
        if upgrade and upgrade.maxItemLevel then
            local extra=upgrade.maxItemLevel-(rec.level or 0)
            desc=desc.."Upgrade cap: iLvl "..upgrade.maxItemLevel..
                (extra>0 and (" (up to +"..extra..")") or " (at cap)").."\n"
            if upgrade.current and upgrade.max then
                desc=desc.."Rank: "..upgrade.current.." / "..upgrade.max.."\n"
            end
            if upgrade.track and upgrade.track~="" then desc=desc.."Track: "..upgrade.track.."\n" end
        else
            desc=desc.."Upgrade track: unavailable from game API.\n"
        end
        desc=desc.."\nUpgrade currency costs are confirmed only at an item upgrader NPC.\n\nHover this item in the list to inspect its stats."
        d.descr:SetText(desc)
    else
        local gain=self:Gain(rec)
        local slot=self:EffectiveSlot(rec)
        local own=slot and self.equipped[slot]
        local wornName
        if own and own.link and GetItemInfo then
            local ok,n=pcall(GetItemInfo,own.link)
            if ok then wornName=n end
        end
        if own and own.itemID then
            d.ownIcon:SetTexture(self:GetDisplayItemIcon(own))
            d.ownIcon:Show();d.ownButton:Show()
            d.ownName:SetText("WEARING: "..(wornName or "equipped item").."\niLvl "..tostring(own.level or "?"))
        else
            d.ownName:SetText("Current slot: Empty / unknown")
        end
        d.title:SetText(self.tab=="Progress" and "TRACKED ITEM" or "ITEM AND VERIFIED SOURCE")
        d.name:SetText(rec.name or ("Item "..tostring(rec.itemID)))
        d.ilevel:SetText("iLvl "..tostring(rec.level or "?").."   |   "..
            (gain and ((gain>0 and "+" or "")..gain.." item levels") or "No comparison"))
        d.icon:SetTexture(self:GetDisplayItemIcon(rec))
        local status,where=self:HasItem(rec.itemID,rec.level)
        local source="SOURCE: "..(rec.fromBag and "In your bags" or rec.sourceVerified and (rec.instance or "Unknown") or "UNVERIFIED - rescan").."\n"
        if rec.fromBag then
            source=source.."You already own this item. Open your bags to equip it.\n"
                .."Check its class, armor, and weapon requirements before using."
        elseif not rec.sourceVerified then
            source=source.."Saved goal predates source verification. Please scan again."
        else
            source=source..self:DescribeDifficulty(rec.difficulty,rec.raid,rec).."\n"
            if self:IsLevelingCharacter() then
                source=source.."Item-level requirement checked; dungeon access and scaling vary.\n"
            end
            if rec.mythicPlus then
                source=source.."Random end-of-dungeon chest.\n"
                    .."Minimum key for level: +"..tostring(rec.keystoneLevel or "?").."\n"
            else
                source=source..(rec.encounter and ("Boss: "..rec.encounter.."\n") or "Boss not listed\n")
            end
            source=source..(status and ("|cff65ff7a"..where.."|r") or "Not yet acquired")
        end
        d.descr:SetText(source)
    end
    local validTarget=rec and rec.itemID and not isGear and rec.sourceVerified and not rec.fromBag
    for _,b in ipairs({d.mapButton,d.guideButton,d.goalButton,d.pinButton}) do
        if validTarget then b:Enable();b:SetAlpha(1)
        else b:Disable();b:SetAlpha(0.4) end
    end
    if rec and not isGear then d.goalButton:Enable();d.goalButton:SetAlpha(1) end
    d.goalButton.text:SetText(rec and not isGear and self:HasGoal(rec) and "REMOVE GOAL" or "TRACK AS GOAL")
    if isGear then
        d.mapButton.text:SetText("MAP - SELECT AN UPGRADE")
        d.guideButton.text:SetText("COSTS: VISIT ITEM UPGRADER")
    end
    if d.mapHelp then
        d.mapHelp:SetText(self.navStatus or (isGear and
            "Upgrade caps come from WoW. Precise costs require the item upgrader NPC." or
            rec and rec.fromBag and "Already in bags - open inventory to equip. No map waypoint needed." or
            rec and not rec.sourceVerified and "Unverified source. Rescan before navigating." or
            "Map pins use verified entrances or nearby bosses. Mark Here saves a manual source pin."))
    end
end

-- Virtual scrolling: 12 reusable row frames for any number of results.
-- Previous builds silently stopped rendering after 90 / 250 items.
function GH:DrawVisibleRows()
    if not self.scroll or not self.scrollChild then return end
    local records=self.visibleRecords or {}
    local offset=self.scroll.GetVerticalScroll and self.scroll:GetVerticalScroll() or 0
    if type(offset)~="number" then offset=0 end
    local start=math.floor(math.max(0,offset)/59)+1
    for i=1,12 do
        local r=self.rows[i]
        local index=start+i-1
        local rec=records[index]
        if rec then
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT",self.scrollChild,"TOPLEFT",0,-(index-1)*59)
            r.record=rec
            r:Show()
            local chosen=self.selected and self.selected.itemID==rec.itemID
                and self.selected.instanceID==rec.instanceID
                and self.selected.difficulty==rec.difficulty
                and self.selected.keystoneLevel==rec.keystoneLevel
            backdrop(r,chosen and T.red2 or T.dark,chosen and T.gold or T.border)
            r.icon:SetTexture(self:GetDisplayItemIcon(rec))
            r.name:SetText(rec.name or ("Item "..tostring(rec.itemID)))
            local descr=(rec.instance or "Unknown source").."  |  "..self:DescribeDifficulty(rec.difficulty,rec.raid,rec)
            if self.tab=="My Gear" then
                local info=rec.upgrade
                descr=info and info.maxItemLevel and ("Maximum possible iLvl "..info.maxItemLevel..
                    (info.track and ("  |  "..info.track) or "")) or "Upgrade track unavailable"
            elseif self.tab=="Upgrade Route" then
                descr=(rec.instance or "Unknown source").."  |  "..(self.routeCounts[rec.instance or ""] or 1).." targets here"
            end
            if rec.fromBag then descr="IN YOUR BAGS - ready to inspect"
            elseif not rec.sourceVerified then descr="UNVERIFIED SOURCE - rescan or re-track" end
            r.desc:SetText(descr)
            local gain=self:Gain(rec)
            if self.tab=="My Gear" then
                local max=rec.upgrade and rec.upgrade.maxItemLevel
                local available=max and rec.level and max>rec.level and max-rec.level or 0
                r.gain:SetText(available>0 and ("UP TO +"..available) or "iLvl "..tostring(rec.level or "?"))
                r.gain:SetTextColor(available>0 and 0.3 or 0.75,available>0 and 0.95 or 0.75,0.3)
            elseif self.tab=="Progress" then
                r.gain:SetText(rec.acquired and "ACQUIRED" or "TRACKING")
                r.gain:SetTextColor(rec.acquired and 0.3 or 1,rec.acquired and 1 or 0.74,0.3)
            else
                r.gain:SetText(gain and ("+"..gain.." iLvl") or "iLvl ?")
                r.gain:SetTextColor(gain and gain>0 and 0.3 or 1,gain and gain>0 and 0.95 or 0.72,0.3)
            end
        else
            r.record=nil
            r:Hide()
        end
    end
end
function GH:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    local class=select(1,UnitClass("player")) or "Character"
    local specName=""
    local spec=GetSpecialization and GetSpecialization()
    if spec and GetSpecializationInfo then specName=select(2,GetSpecializationInfo(spec)) or "" end
    local average=GetAverageItemLevel and select(2,GetAverageItemLevel())
    local ilvl=self.SafeNumber(average)
    local faction=UnitFactionGroup and UnitFactionGroup("player") or "Unknown"
    local level=self:GetCharacterLevel()
    local cap=self:GetCurrentLevelCap()
    local mode=(cap and level>=cap) and "ENDGAME" or "LEVELING"
    local headerTop=(UnitName("player") or "Player").."  |  Level "..level.."  |  "..specName.." "..class
    local headerSub=(ilvl and ("iLvl "..string.format("%.1f",ilvl)) or "iLvl ?").."  |  "..faction.."  |  Gear Hunter v"..self.version
    if self.infoTop and self.infoSub then
        self.infoTop:SetText(headerTop)
        self.infoSub:SetText(headerSub)
    elseif self.info then
        self.info:SetText(headerTop.."  |  "..headerSub)
    end
    if self.UpdateOrnateFrame then self:UpdateOrnateFrame() end
    if self.RefreshClassStage then
        local classToken=UnitClass and select(2,UnitClass("player")) or class
        self:RefreshClassStage(classToken,specName,level)
    end
    if self.detail and self.detail.levelTitle then
        local capLevel=cap or 90
        self.detail.levelTitle:SetText(mode=="ENDGAME" and "ENDGAME MODE" or "LEVELING MODE")
        self.detail.levelNote:SetText(mode=="ENDGAME" and
            "You are at the current level cap. Showing verified endgame sources." or
            ("Level "..level.." of "..capLevel..". Showing level-appropriate known upgrades."))
        self.detail.levelBar:SetMinMaxValues(1,math.max(2,capLevel))
        self.detail.levelBar:SetValue(level)
        self.detail.levelBarText:SetText("Level "..level.."    /    "..capLevel)
    end
    if self.sourcePreviewRows then
        local picks=self.GetVisibleItems and self:GetVisibleItems("Upgrades",0,true) or {}
        local used={}
        local shown=0
        self.featuredUpgrade=nil
        for _,rec in ipairs(picks) do
            if rec.sourceVerified and not rec.fromBag and rec.instance and rec.level and not used[rec.itemID] then
                shown=shown+1
                if shown==1 then self.featuredUpgrade=rec end
                used[rec.itemID]=true
                local row=self.sourcePreviewRows[shown]
                if row then
                    row.record=rec
                    row.text:SetText((rec.instance or "Verified source").."  |  iLvl "..tostring(rec.level))
                    row:Show()
                end
                if shown>=3 then break end
            end
        end
        for i=shown+1,#self.sourcePreviewRows do
            local row=self.sourcePreviewRows[i]
            row.record=nil
            row.text:SetText(i==1 and "Scan to discover verified upgrades" or "")
            row:SetShown(i==1 and shown==0)
        end
    end
    if self.showcaseCards and self.showcaseFaction~=faction then
        local sourceFaction=(faction=="Horde") and "Horde" or "Alliance"
        self.showcaseFaction=faction
        for _,card in ipairs(self.showcaseCards) do
            card.picture:SetTexture("Interface\\AddOns\\GearHunter\\Art\\Showcase\\"..sourceFaction.."\\"..card.class..".tga")
        end
    end
    self.footer:SetText((self.journalStatus or "Ready to scan").."  |  Level "..level.." checks")
    self.scanButton.text:SetText(self.scanRunning and "STOP SCAN" or "SCAN JOURNAL")
    local selectedFill,selectedEdge=getThemeAccent()
    for _,tab in ipairs(self.tabs) do
        backdrop(tab,(tab.which==self.tab or (((self.tab=="Farm Route" or self.tab=="Weekly Farm" or self.tab=="Alt Tracker" or self.tab=="Collection Dashboard") and tab.which=="Hunt List") or (self.tab=="Boss Loot Hunter" and tab.which=="Gear Search") or (self.tab=="Upgrade Planner" and tab.which=="My Gear"))) and selectedFill or T.dark,
            (tab.which==self.tab or (((self.tab=="Farm Route" or self.tab=="Weekly Farm" or self.tab=="Alt Tracker" or self.tab=="Collection Dashboard") and tab.which=="Hunt List") or (self.tab=="Boss Loot Hunter" and tab.which=="Gear Search") or (self.tab=="Upgrade Planner" and tab.which=="My Gear"))) and selectedEdge or T.border)
        if tab.activeGlow then tab.activeGlow:SetShown(tab.which==self.tab or (((self.tab=="Farm Route" or self.tab=="Weekly Farm" or self.tab=="Alt Tracker" or self.tab=="Collection Dashboard") and tab.which=="Hunt List") or (self.tab=="Boss Loot Hunter" and tab.which=="Gear Search") or (self.tab=="Upgrade Planner" and tab.which=="My Gear"))) end
    end
    if self.plannerLaunchButton then self.plannerLaunchButton:SetShown(self.tab=="My Gear") end
    for _,b in ipairs(self.sourceButtons or {}) do
        b:SetShown(self.tab~="My Gear")
        backdrop(b,self.db.options.sourceFilter==b.which and T.red2 or T.dark,
            self.db.options.sourceFilter==b.which and T.gold or T.border)
    end
    for _,s in ipairs(self.slotButtons) do
        backdrop(s,s.id==self.slot and T.red2 or T.dark,s.id==self.slot and T.gold or T.border)
        local worn=self.equipped[s.id]
        if s.info then s.info:SetText(worn and worn.level and worn.level>0 and tostring(worn.level) or "-") end
    end
    for _,b in ipairs(self.tonightButtons or {}) do b:SetShown(self.tab=="Tonight") end
    if self.tonightButtons then
        self.tonightButtons[1].text:SetText("Max key planned: +"..tostring(self.db.options.tonightKey or 6))
        local raidNames={[17]="Raid Finder",[14]="Normal",[15]="Heroic",[16]="Mythic"}
        self.tonightButtons[2].text:SetText("Max raid planned: "..(raidNames[self.db.options.tonightRaid] or "Heroic"))
    end
    if self.bgModeButton then
        self.bgModeButton.text:SetText("Theme Mode: "..tostring(self:GetBackgroundOption("bgMode","Auto")))
        local labels={[1]="Subtle",[2]="Medium",[3]="Strong"}
        self.bgIntensityButton.text:SetText("Glow: "..(labels[self:GetBackgroundOption("bgIntensity",3)] or "Strong"))
        local custom=self:GetBackgroundOption("bgCustomTheme","PRIEST")
        if GH.backgroundThemeByKey and GH.backgroundThemeByKey[custom] then
            self.bgCustomButton.text:SetText("Custom Theme: "..GH.backgroundThemeByKey[custom].name)
        else
            self.bgCustomButton.text:SetText("Custom Theme: Priest")
        end
        self.bgCustomButton:SetAlpha((self:GetBackgroundOption("bgMode","Auto")=="Custom") and 1 or 0.65)
    end
    local isSettings=self.tab=="Settings"
    local isCharacter=self.tab=="Character"
    local isGearSearch=self.tab=="Gear Search"
    local isBossLoot=self.tab=="Boss Loot Hunter"
    local isTransmog=self.tab=="Transmog Hunter"
    local isChecklist=self.tab=="Hunt List"
    local isFarmRoute=self.tab=="Farm Route"
    local isSmartPicks=self.tab=="Smart Picks"
    local isUpgradePlanner=self.tab=="Upgrade Planner"
    local isWeeklyFarm=self.tab=="Weekly Farm"
    local isAltTracker=self.tab=="Alt Tracker"
    local isCollection=self.tab=="Collection Dashboard"
    local isFarmSession=self.tab=="Farm Session"
    self.slotPanel:SetShown(not isSettings and not isCharacter and not isGearSearch and not isBossLoot and not isTransmog and not isChecklist and not isFarmRoute and not isSmartPicks and not isUpgradePlanner and not isWeeklyFarm and not isAltTracker and not isCollection and not isFarmSession)
    self.settingsPanel:SetShown(isSettings)
    if self.middlePanel then self.middlePanel:SetShown(not isCharacter and not isGearSearch and not isBossLoot and not isTransmog and not isChecklist and not isFarmRoute and not isSmartPicks and not isUpgradePlanner and not isWeeklyFarm and not isAltTracker and not isCollection and not isFarmSession) end
    if self.characterPanel then self.characterPanel:SetShown(isCharacter) end
    if self.detailFrame then self.detailFrame:SetShown(not isGearSearch and not isBossLoot and not isTransmog and not isChecklist and not isFarmRoute and not isSmartPicks and not isUpgradePlanner and not isWeeklyFarm and not isAltTracker and not isCollection and not isFarmSession) end
    if self.gearSearchUI then self.gearSearchUI.panel:SetShown(isGearSearch) end
    if self.bossLootUI then self.bossLootUI.panel:SetShown(isBossLoot) end
    if self.transmogUI then self.transmogUI.panel:SetShown(isTransmog) end
    if self.huntUI then self.huntUI.panel:SetShown(isChecklist) end
    if self.farmRouteUI then self.farmRouteUI.panel:SetShown(isFarmRoute) end
    if self.smartUI then self.smartUI.panel:SetShown(isSmartPicks) end
    if self.upgradePlannerUI then self.upgradePlannerUI.panel:SetShown(isUpgradePlanner) end
    if self.weeklyUI then self.weeklyUI.panel:SetShown(isWeeklyFarm) end
    if self.altUI then self.altUI.panel:SetShown(isAltTracker) end
    if self.collectionUI then self.collectionUI.panel:SetShown(isCollection) end
    if self.farmUI then self.farmUI.panel:SetShown(isFarmSession) end
    -- 0.11.0: The shared scan strip belongs to the compact equipment pages.
    -- Full-width workspaces extend to y=-708; leaving the strip visible at
    -- y=-670 causes it to cover their scroll lists and action buttons.
    -- Set visibility on every refresh, including early-return tab branches.
    if self.toolPanel then
        self.toolPanel:SetShown(not (isGearSearch or isBossLoot or isTransmog or isChecklist
            or isFarmRoute or isSmartPicks or isUpgradePlanner or isWeeklyFarm or isAltTracker or isCollection or isFarmSession))
    end
    if isFarmSession then
        if self.RefreshFarmSessions then self:RefreshFarmSessions() end
        return
    end
    if isCollection then
        if self.RefreshCollectionDashboard then self:RefreshCollectionDashboard() end
        return
    end
    if isBossLoot then
        if self.RefreshBossLootHunter then self:RefreshBossLootHunter() end
        return
    end
    if isAltTracker then
        if self.RefreshAltTracker then self:RefreshAltTracker() end
        return
    end
    if isWeeklyFarm then
        if self.RefreshWeeklyFarm then self:RefreshWeeklyFarm() end
        return
    end
    if isSmartPicks then
        if self.RefreshSmartPicks then self:RefreshSmartPicks() end
        return
    end
    if isUpgradePlanner then
        if self.RefreshUpgradePlanner then self:RefreshUpgradePlanner() end
        return
    end
    if isFarmRoute then
        if self.RefreshFarmRoute then self:RefreshFarmRoute() end
        return
    end
    if isChecklist then
        if self.RefreshHuntChecklist then self:RefreshHuntChecklist() end
        return
    end
    if isTransmog then
        if self.RefreshTransmogHunter then self:RefreshTransmogHunter() end
        return
    end
    if isGearSearch then
        if self.RefreshGearSearch then self:RefreshGearSearch() end
        return
    end
    self.listTitle:SetText(self.tab=="Progress" and "TRACKED GEAR" or
        self.tab=="Best in Slot" and "HIGHEST KNOWN ITEM LEVEL" or
        self.tab=="What to Farm" and "BEST TARGET PER SLOT" or
        self.tab=="Tonight" and "LEVELING / TONIGHT GUIDE" or
        self.tab=="My Gear" and "YOUR EQUIPPED GEAR / UPGRADE CAPS" or
        self.tab=="Character" and "CLICK YOUR EQUIPMENT FOR UPGRADES" or
        self.tab=="Upgrade Route" and "FARM TARGETS BY DESTINATION" or
        isSettings and "DATA SOURCES / LIMITATIONS" or "ALL KNOWN +1 OR GREATER")
    local records=isSettings and {} or self:GetVisibleItems(self.tab,self.slot)
    self.visibleRecords=records
    self.routeCounts={}
    if self.tab=="Upgrade Route" then
        for _,rec in ipairs(records) do
            local k=rec.instance or ""
            self.routeCounts[k]=(self.routeCounts[k] or 0)+1
        end
    end
    self.helpText:SetShown(isSettings or #records==0)
    self.scrollChild:SetHeight(math.max(1,#records*59))
    local oldTab,oldSlot,oldSource=self.lastTab,self.lastSlot,self.lastSource
    self.lastTab,self.lastSlot,self.lastSource=self.tab,self.slot,self.db.options.sourceFilter
    if oldTab~=self.tab or oldSlot~=self.slot or oldSource~=self.db.options.sourceFilter then
        self.scroll:SetVerticalScroll(0)
    end
    self.listCount:SetText(isSettings and "Settings" or (#records.." results"))
    if isSettings then
        self.helpText:SetText("DATA SOURCES\n\n* Equipped item levels and upgrade-track caps: WoW equipment/item APIs\n* Verified raid and dungeon loot: Adventure Guide\n* Leveling mode: normal dungeons and owned bag items\n* Required-level checks: item data, when available\n* Mythic+ reward brackets: bundled level reference\n* Map pins: real entrance data or manually saved positions\n\nTONIGHT limits source difficulty only; it cannot tell if you have a key, group or lockout.\n\nCrafting, delve, vendor and Great Vault loot are not yet part of the automatic finder. Upgrade costs require speaking to an upgrader.\n\nHigher item level is NOT the same as simulated Best in Slot.\n\nGear Search indexes items seen on your character plus optional full Adventure Guide dungeon/raid loot. Wowhead lookups cannot be performed live inside WoW.")
    elseif #records==0 then
        if self.scanRunning then
            self.helpText:SetText("Scanning the Adventure Guide...\n\nJournal dungeons are checked while leveling; at max level seasonal rewards are checked.")
        elseif #self.items==0 then
            self.helpText:SetText("No loot scanned yet.\n\nClick SCAN JOURNAL below. Gear Hunter will read the Encounter Journal for your class and specialization.")
        else
            self.helpText:SetText(self.tab=="Tonight" and
                "No verified upgrades at or below your planned difficulties.\n\nRaise the maximum planned keystone / raid level or change source filter." or
                self.tab=="My Gear" and "No equipped gear was found. Try /gh gear after logging into a character." or
                "No known +1 or higher usable gear from the scanned sources or bags.\n\nSwitch to ALL SOURCES or choose a different equipment slot.\n\nAdditional crafted, delve, vendor and Great Vault gear is not yet in this scanner.")
        end
    end
    if self.RefreshCharacterPanel and isCharacter then self:RefreshCharacterPanel() end
    if not isCharacter then self:DrawVisibleRows() end
    renderDetail(self)
end
-- Authentic carved metal frame art is a single transparent ornamental
-- texture. It is drawn in the parent BORDER layer, underneath all working UI
-- controls, and changes its magical accent to match the current specialization.
-- An independent bloom sits OUTSIDE the carved metal frame. Unlike the
-- old stretched strip texture it has a transparent middle and a feathered
-- perimeter; the user's current class chooses the accent color.
local function applyMidnightFrame(frame)
    local halo=frame:CreateTexture(nil,"BACKGROUND",nil,-4)
    halo:SetPoint("TOPLEFT",frame,"TOPLEFT",-22,22)
    halo:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",22,-22)
    halo:SetTexture("Interface\\AddOns\\GearHunter\\Art\\Frames\\ReferenceBlueGlow.tga")
    halo:SetBlendMode("ADD")
    halo:SetVertexColor(0.58,0.84,1.0,0.88)
    GH.outerFrameAura=halo
    local edge=frame:CreateTexture(nil,"BORDER",nil,0)
    edge:SetAllPoints(frame)
    edge:SetTexture("Interface\\AddOns\\GearHunter\\Art\\Frames\\ReferenceOrnateBorder.tga")
    GH.outerFrameArt=edge
    -- Faint pulse: no motion of UI text or equipment panels.
    local elapsed=0
    frame:HookScript("OnUpdate",function(_,dt)
        elapsed=elapsed+(dt or 0)
        if elapsed>100000 then elapsed=0 end
        halo:SetAlpha(0.78+0.17*math.sin(elapsed*1.8))
    end)
end
function GH:UpdateOrnateFrame()
    -- The approved blue/gold Midnight frame remains consistent for all specs.
    if self.outerFrameAura then self.outerFrameAura:SetVertexColor(0.52,0.81,1.00,0.92) end
end
local GEAR_WINDOW_WIDTH, GEAR_WINDOW_HEIGHT=1600,900
function GH:FitWindowToScreen()
    local frame=self.frame
    if not frame or not UIParent then return end
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    if not w or not h or w<=0 or h<=0 then return end
    local scale=math.min((w-24)/GEAR_WINDOW_WIDTH,(h-24)/GEAR_WINDOW_HEIGHT)
    -- No minimum scale that would force clipping on small game windows.
    if scale<0.18 then scale=0.18 end
    frame:SetScale(scale)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER",UIParent,"CENTER",0,0)
end
getThemeAccent = function()
    return {0.06,0.20,0.45,0.99},{0.24,0.78,1.00,1}
end

-- Every panel is an actual WoW frame. The approved concept image is NOT a
-- screenshot overlay: item levels, models, scan results and action buttons remain live.
local CLASS_PREVIEWS={
 {"WARRIOR","Warrior","Fury",72,"Interface\\Icons\\Ability_Warrior_BattleShout","Arms | Fury | Protection"},
 {"PALADIN","Paladin","Holy",65,"Interface\\Icons\\Spell_Holy_HolyBolt","Holy | Protection | Retribution"},
 {"ROGUE","Rogue","Outlaw",260,"Interface\\Icons\\Ability_BackStab","Assassination | Outlaw | Subtlety"},
 {"MAGE","Mage","Fire",63,"Interface\\Icons\\Spell_Fire_FireBall02","Arcane | Fire | Frost"},
 {"WARLOCK","Warlock","Demonology",266,"Interface\\Icons\\Spell_Shadow_DeathCoil","Affliction | Demonology | Destruction"},
 {"HUNTER","Hunter","Beast Mastery",253,"Interface\\Icons\\Ability_Hunter_BeastTaming","Beast Mastery | Marksmanship | Survival"},
 {"PRIEST","Priest","Shadow",258,"Interface\\Icons\\Spell_Holy_PowerWordShield","Discipline | Holy | Shadow"},
 {"DEMONHUNTER","Demon Hunter","Vengeance",581,"Interface\\Icons\\ClassIcon_DemonHunter","Havoc | Vengeance | Devourer"},
 {"MONK","Monk","Windwalker",269,"Interface\\Icons\\ClassIcon_Monk","Brewmaster | Mistweaver | Windwalker"},
 {"DRUID","Druid","Balance",102,"Interface\\Icons\\Ability_Druid_Maul","Balance | Feral | Guardian | Restoration"},
 {"SHAMAN","Shaman","Enhancement",263,"Interface\\Icons\\Spell_Nature_Lightning","Elemental | Enhancement | Restoration"},
 {"DEATHKNIGHT","Death Knight","Frost",251,"Interface\\Icons\\Spell_Deathknight_ClassIcon","Blood | Frost | Unholy"},
 {"EVOKER","Evoker","Devastation",1467,"Interface\\Icons\\ClassIcon_Evoker","Devastation | Preservation | Augmentation"},
}
function GH:PreviewClassScene(class)
    local actual=UnitClass and select(2,UnitClass("player")) or nil
    -- All class buttons are live previews; only the player's equipped items
    -- and 3D model are shown, never invented characters or stats.
    self.previewClass=(class~=actual) and class or nil
    if self.tab~="Character" then self.tab="Character";self.selected=nil end
    if self.UpdateCharacterBackground then self:UpdateCharacterBackground() end
    if self.Refresh then self:Refresh() end
end
function GH:RefreshClassStage(playerClass,playerSpec,level)
    local selectedClass=self.previewClass or playerClass
    for _,b in ipairs(self.classPreviewButtons or {}) do
        local isChosen=b.classKey==selectedClass
        backdrop(b,isChosen and {0.15,0.115,0.032,0.98} or T.dark,
            isChosen and T.gold or T.border)
        b.subtitle:SetText(b.classKey==playerClass and ("Lv "..level.."  "..playerSpec) or
            (b.specLabel.."  •  PREVIEW"))
    end
    for _,b in ipairs(self.showcaseCards or {}) do
        if b.frame then
            b.frame:SetBackdropBorderColor(unpack(b.class==selectedClass and T.gold or T.border))
        end
    end
    if self.scenePreviewNotice then
        self.scenePreviewNotice:SetText(self.previewClass and
            ("PREVIEW: "..selectedClass.." environment | Live model and gear are yours") or
            "LIVE CHARACTER  •  DRAG TO ROTATE")
    end
end
local function addBrightButtonGlow(btn)
    local t=btn:CreateTexture(nil,"BACKGROUND",nil,-1)
    t:SetPoint("TOPLEFT",btn,"TOPLEFT",-7,6)
    t:SetPoint("BOTTOMRIGHT",btn,"BOTTOMRIGHT",7,-6)
    t:SetTexture("Interface\\AddOns\\GearHunter\\Art\\Frames\\MidnightButtonHalo.tga")
    t:SetBlendMode("ADD")
    t:SetVertexColor(0.22,0.64,1.0,0.68)
    return t
end
local function goldFrame(parent,x,y,w,h)
    local f=panel(parent,x,y,w,h,T.panel)
    f:SetBackdropBorderColor(0.58,0.45,0.19,1)
    return f
end
function GH:CreateUI()
    local f=CreateFrame("Frame","GearHunterMainFrame",UIParent,"BackdropTemplate")
    f:SetSize(GEAR_WINDOW_WIDTH,GEAR_WINDOW_HEIGHT)
    f:SetPoint("CENTER",UIParent,"CENTER",0,0)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(false)
    f:EnableMouse(true)
    backdrop(f,T.bg,T.border)
    applyMidnightFrame(f)
    self.frame=f
    local shade=CreateFrame("Frame","GearHunterScreenShade",UIParent)
    shade:SetAllPoints(UIParent)
    shade:SetFrameStrata("MEDIUM")
    shade:EnableMouse(true)
    local tint=shade:CreateTexture(nil,"BACKGROUND")
    tint:SetAllPoints(shade)
    tint:SetColorTexture(0,0.008,0.019,0.72)
    shade:Hide()
    self.screenShade=shade
    f:HookScript("OnShow",function() GH:FitWindowToScreen();shade:Show() end)
    f:HookScript("OnHide",function() shade:Hide() end)
    local watcher=CreateFrame("Frame",nil,UIParent)
    watcher:RegisterEvent("UI_SCALE_CHANGED")
    watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    watcher:SetScript("OnEvent",function() GH:FitWindowToScreen() end)
    self.windowScaleWatcher=watcher
    self:FitWindowToScreen()
    if UISpecialFrames then table.insert(UISpecialFrames,"GearHunterMainFrame") end

    local logo=f:CreateTexture(nil,"ARTWORK")
    logo:SetTexture("Interface\\AddOns\\GearHunter\\Art\\Frames\\MidnightCorner.tga")
    logo:SetSize(94,84)
    logo:SetPoint("TOPLEFT",f,"TOPLEFT",37,-9)
    self.brandCrest=logo
    self.brandTitle=label(f,"GEAR HUNTER",140,-19,"large",T.gold,340)
    self.brandTitle:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",31,"OUTLINE")
    self.versionTitle=label(f,"v"..self.version,485,-32,"normal",T.gold,80)
    local slogan=label(f,"F I N D    •    U P G R A D E    •    N A V I G A T E",142,-61,"normal",T.grey,420)
    self.infoTop=label(f,"",629,-27,"normal",{1,1,1,1},790,"RIGHT")
    self.infoSub=label(f,"",629,-53,"normal",T.gold,790,"RIGHT")
    self.helpButton=button(f,"?",1460,-29,43,43,function()
        GH:ToggleSupportCenter()
    end,{0.015,0.049,0.092,1})
    local newBadge=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    newBadge:SetPoint("BOTTOM",self.helpButton,"TOP",0,1)
    newBadge:SetText("NEW")
    newBadge:SetTextColor(0.24,1,0.50,1)
    self.supportNewBadge=newBadge
    self:UpdateSupportNewBadge()
    self.closeButton=button(f,"X",1512,-29,44,43,function() f:Hide() end,{0.38,0.025,0.040,1})
    addBrightButtonGlow(self.helpButton)
    addBrightButtonGlow(self.closeButton)

    self.tabs={}
    local names={"Character","Upgrades","Smart Picks","Best in Slot","Tonight","What to Farm","Upgrade Route","My Gear","Hunt List","Gear Search","Transmog Hunter","Settings"}
    local namesShown={"CHARACTER","UPGRADES","SMART PICKS","BEST IN SLOT","TONIGHT","WHAT TO FARM","UPG ROUTE","MY GEAR","HUNT LIST","GEAR SEARCH","TRANSMOG","SETTINGS"}
    local tabIcons={"character","upgrades","sparkle","best","tonight","farm","route","gear","progress","search","gear","settings"}
    for i,name in ipairs(names) do
        local x=31+(i-1)*128
        local b=button(f,namesShown[i],x,-94,126,43,function()
            GH.previewClass=nil;GH:SetTab(name)
        end,T.dark)
        b.which=name
        local tx=b:CreateTexture(nil,"ARTWORK")
        tx:SetTexture(GH_ICON_ROOT..tabIcons[i]..".tga");tx:SetSize(20,20);tx:SetPoint("LEFT",b,"LEFT",8,0)
        b.text:SetFontObject(GameFontNormalSmall)
        b.text:ClearAllPoints();b.text:SetPoint("LEFT",b,"LEFT",29,0)
        b.text:SetPoint("RIGHT",b,"RIGHT",-2,0)
        b.activeGlow=addBrightButtonGlow(b)
        table.insert(self.tabs,b)
    end
    self.tab="Character";self.slot=0

    -- Middle list and filters for the other eight functional tabs.
    self.slotPanel=panel(f,30,-150,246,558,T.panel)
    label(self.slotPanel,"EQUIPMENT SLOTS",13,-10,"normal",T.gold,212)
    self.slotButtons={}
    local all=button(self.slotPanel,"ALL SLOTS",10,-33,226,29,function() GH.slot=0;GH:Refresh() end)
    all.id=0;all.info=label(all,"",192,-5,"normal",T.grey,18,"RIGHT");all.info:Hide()
    table.insert(self.slotButtons,all)
    for i,e in ipairs(self.slotDefs) do
        local y=33+i*29
        local b=button(self.slotPanel,e.name,10,-y,226,27,function() GH.slot=e.id;GH:Refresh() end)
        b.id=e.id
        b.text:ClearAllPoints();b.text:SetPoint("LEFT",b,"LEFT",9,0);b.text:SetWidth(155);b.text:SetJustifyH("LEFT")
        b.info=label(b,"-",0,0,"normal",T.gold,50,"RIGHT")
        b.info:ClearAllPoints();b.info:SetPoint("RIGHT",b,"RIGHT",-8,0)
        table.insert(self.slotButtons,b)
    end
    self.settingsPanel=panel(f,30,-150,246,558,T.panel)
    label(self.settingsPanel,"GEAR HUNTER SETTINGS",12,-11,"normal",T.gold,224)
    label(self.settingsPanel,"Data is from WoW equipment APIs and the Encounter Journal. Sources and eligibility depend on the character's level and game access.",12,-49,"normal",T.grey,221)
    button(self.settingsPanel,"FIT TO SCREEN",12,-190,222,31,function() GH:FitWindowToScreen() end)
    label(self.settingsPanel,"BACKGROUND",12,-238,"normal",T.gold,220)
    self.bgModeButton=button(self.settingsPanel,"Theme Mode: Auto",12,-267,222,31,function() GH:CycleBackgroundMode() end)
    self.bgCustomButton=button(self.settingsPanel,"Custom Theme",12,-308,222,31,function() GH:CycleCustomBackgroundTheme() end)
    self.bgIntensityButton=button(self.settingsPanel,"Glow: Strong",12,-349,222,31,function() GH:CycleBackgroundIntensity() end)
    label(self.settingsPanel,"Click a class on the Character tab to preview its scene. Your 3D character and equipped items always remain your own.",12,-403,"normal",T.grey,221)

    local mid=panel(f,284,-150,912,558,T.panel)
    self.middlePanel=mid
    self.listTitle=label(mid,"UPGRADES",15,-13,"large",T.gold,580)
    self.listCount=label(mid,"0 results",759,-17,"normal",T.grey,140,"RIGHT")
    self.scroll=CreateFrame("ScrollFrame",nil,mid,"UIPanelScrollFrameTemplate")
    self.scroll:SetPoint("TOPLEFT",mid,"TOPLEFT",15,-114)
    self.scroll:SetPoint("BOTTOMRIGHT",mid,"BOTTOMRIGHT",-31,12)
    self.scrollChild=CreateFrame("Frame",nil,self.scroll)
    self.scrollChild:SetWidth(854);self.scrollChild:SetHeight(1)
    self.scroll:SetScrollChild(self.scrollChild)
    self.rows={}
    self.helpText=label(mid,"",16,-129,"normal",T.grey,842)
    self.sourceButtons={}
    local filters={{"ALL SOURCES","All"},{"RAIDS","Raid"},{"MYTHIC+","Mythic+"}}
    for i,v in ipairs(filters) do
        local b=button(mid,v[1],15+(i-1)*295,-43,283,29,function()
            GH.db.options.sourceFilter=v[2];GH:SelectItem(nil)
        end)
        b.which=v[2];table.insert(self.sourceButtons,b)
    end
    -- Prominent entry from My Gear, without adding a 13th cramped top tab.
    self.plannerLaunchButton=button(mid,"OPEN GEAR UPGRADE PLANNER",15,-43,863,44,function() GH:ShowTab("Upgrade Planner") end,{0.04,0.16,0.33,1})
    self.plannerLaunchButton:Hide()
    local keys={2,4,5,6,8,10}
    local ranks={17,14,15,16}
    self.tonightButtons={}
    self.tonightButtons[1]=button(mid,"Max key planned: +6",15,-80,425,29,function()
        local current=GH.db.options.tonightKey
        for i,v in ipairs(keys) do if v==current then GH.db.options.tonightKey=keys[(i%#keys)+1];break end end
        GH:SelectItem(nil)
    end)
    self.tonightButtons[2]=button(mid,"Max raid planned: Heroic",453,-80,425,29,function()
        local current=GH.db.options.tonightRaid
        for i,v in ipairs(ranks) do if v==current then GH.db.options.tonightRaid=ranks[(i%#ranks)+1];break end end
        GH:SelectItem(nil)
    end)
    self.helpText:Hide()
    for i=1,12 do
        local r=CreateFrame("Button",nil,self.scrollChild,"BackdropTemplate")
        r:SetSize(850,55);backdrop(r,T.dark)
        r.icon=r:CreateTexture(nil,"ARTWORK");r.icon:SetSize(40,40);r.icon:SetPoint("LEFT",9,0)
        r.name=label(r,"",56,-7,"normal",T.gold,560)
        r.desc=label(r,"",56,-26,"normal",T.grey,700)
        r.gain=label(r,"",730,-8,"normal",T.green,112,"RIGHT")
        r:SetScript("OnClick",function(row) GH:SelectItem(row.record) end)
        r:SetScript("OnEnter",function(row) itemTooltip(row,row.record) end)
        r:SetScript("OnLeave",function() GameTooltip:Hide() end)
        r:Hide();table.insert(self.rows,r)
    end
    self.scroll:HookScript("OnVerticalScroll",function() GH:DrawVisibleRows() end)

    -- Live upgrade card, mode/progress and clickable verified source shortlist.
    local dframe=goldFrame(f,1206,-150,365,558)
    self.detailFrame=dframe
    self.detail={}
    local d=self.detail
    d.title=label(dframe,"YOUR EQUIPMENT",14,-12,"large",T.gold,335)
    d.icon=dframe:CreateTexture(nil,"ARTWORK")
    d.icon:SetPoint("TOPLEFT",dframe,"TOPLEFT",17,-42);d.icon:SetSize(53,53)
    d.name=label(dframe,"Choose a gear slot",79,-45,"normal",{0.42,1.00,0.36,1},268)
    d.name:SetHeight(36);d.name:SetWordWrap(true)
    d.ilevel=label(dframe,"",79,-84,"normal",T.gold,268)
    local sep=dframe:CreateTexture(nil,"ARTWORK");sep:SetColorTexture(0.8,0.65,0.23,0.85)
    sep:SetSize(331,1);sep:SetPoint("TOPLEFT",dframe,"TOPLEFT",17,-111)
    d.ownIcon=dframe:CreateTexture(nil,"ARTWORK")
    d.ownIcon:SetSize(25,25);d.ownIcon:SetPoint("TOPLEFT",dframe,"TOPLEFT",16,-116)
    d.ownButton=CreateFrame("Button",nil,dframe)
    d.ownButton:SetPoint("TOPLEFT",dframe,"TOPLEFT",16,-116);d.ownButton:SetSize(25,25)
    d.ownButton:SetScript("OnEnter",function(self)
        local sel=GH.selected or GH.featuredUpgrade
        local slot=sel and GH:EffectiveSlot(sel)
        local item=slot and GH.equipped[slot]
        if item and item.link then itemTooltip(self,item) end
    end)
    d.ownButton:SetScript("OnLeave",function() GameTooltip:Hide() end)
    d.ownName=label(dframe,"",46,-118,"normal",T.grey,299)
    d.ownName:SetHeight(27);d.ownName:SetWordWrap(true)
    d.descr=label(dframe,"",17,-150,"normal",T.grey,328)
    d.descr:SetHeight(55);d.descr:SetWordWrap(true);d.descr:SetJustifyV("TOP")
    local descrHover=CreateFrame("Button",nil,dframe)
    descrHover:SetPoint("TOPLEFT",dframe,"TOPLEFT",17,-150)
    descrHover:SetSize(327,58)
    descrHover:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:SetText(d.descr:GetText() or "No item selected",1,1,1,true)
        GameTooltip:Show()
    end)
    descrHover:SetScript("OnLeave",function() GameTooltip:Hide() end)

    local leveling=goldFrame(dframe,10,-215,345,108)
    d.levelTitle=label(leveling,"LEVELING MODE",39,-10,"normal",T.gold,291)
    local arrow=leveling:CreateTexture(nil,"ARTWORK")
    arrow:SetTexture(GH_ICON_ROOT.."level-up.tga")
    arrow:SetPoint("TOPLEFT",leveling,"TOPLEFT",8,-8);arrow:SetSize(24,24)
    d.levelNote=label(leveling,"",11,-40,"normal",T.grey,322)
    d.levelBar=CreateFrame("StatusBar",nil,leveling)
    d.levelBar:SetPoint("TOPLEFT",leveling,"TOPLEFT",12,-83)
    d.levelBar:SetSize(322,14)
    d.levelBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    d.levelBar:SetStatusBarColor(0.91,0.69,0.12,1)
    d.levelBarText=label(leveling,"",11,-66,"normal",T.gold,322)
    local sourceBox=goldFrame(dframe,10,-331,345,102)
    label(sourceBox,"NEXT VERIFIED UPGRADE SOURCES",11,-8,"normal",T.gold,322)
    self.sourcePreviewRows={}
    for i=1,3 do
        local row=button(sourceBox,"",8,-26-(i-1)*24,329,22,function(self)
            if self.record then GH:SelectItem(self.record) end
        end)
        row.text:ClearAllPoints();row.text:SetPoint("LEFT",row,"LEFT",7,0)
        row.text:SetWidth(316);row.text:SetJustifyH("LEFT")
        row:Hide();table.insert(self.sourcePreviewRows,row)
    end
    d.mapButton=button(dframe,"SHOW ON WORLD MAP",11,-445,343,29,function()
        if not GH.selected and GH.featuredUpgrade then GH:SelectItem(GH.featuredUpgrade) end
        GH:GoToRecord(GH.selected or GH.featuredUpgrade)
    end,{0.48,0.045,0.06,1})
    d.guideButton=button(dframe,"OPEN ADVENTURE GUIDE",11,-479,343,27,function() GH:OpenGuide(GH.selected or GH.featuredUpgrade) end)
    d.goalButton=button(dframe,"TRACK AS GOAL",11,-511,164,29,function() GH:SetGoal(GH.selected or GH.featuredUpgrade) end)
    d.pinButton=button(dframe,"SAVE ENTRANCE",187,-511,167,29,function() GH:SavePlayerPin(GH.selected or GH.featuredUpgrade) end)
    d.mapHelp=label(dframe,"Map pins use verified sources. Mark Here saves a manual location.",13,-544,"normal",T.grey,339)
    d.mapHelp:SetWordWrap(false)

    -- Character's live 3D model, sidebar preview and equipment column.
    if self.CreateCharacterPanel then self:CreateCharacterPanel(f) end
    if self.CreateGearSearchPanel then self:CreateGearSearchPanel(f) end
    if self.CreateBossLootPanel then self:CreateBossLootPanel(f) end
    if self.CreateTransmogPanel then self:CreateTransmogPanel(f) end
    if self.CreateHuntChecklistPanel then self:CreateHuntChecklistPanel(f) end
    if self.CreateFarmRoutePanel then self:CreateFarmRoutePanel(f) end
    if self.CreateSmartPicksPanel then self:CreateSmartPicksPanel(f) end
    if self.CreateUpgradePlannerPanel then self:CreateUpgradePlannerPanel(f) end
    if self.CreateWeeklyFarmPanel then self:CreateWeeklyFarmPanel(f) end
    if self.CreateAltTrackerPanel then self:CreateAltTrackerPanel(f) end
    if self.CreateCollectionDashboardPanel then self:CreateCollectionDashboardPanel(f) end
    if self.CreateFarmSessionPanel then self:CreateFarmSessionPanel(f) end

    -- Beneath stage: scan button + real-time, unobstructed status line.
    local tool=goldFrame(f,284,-670,912,41)
    self.toolPanel=tool
    self.scanButton=button(tool,"SCAN JOURNAL",9,-4,214,33,function()
        if GH.scanRunning then GH:CancelJournalScan() else GH:StartJournalScan() end
    end,{0.05,0.22,0.54,1})
    addBrightButtonGlow(self.scanButton)
    self.allGearButton=button(tool,"SHOW ALL GEAR",230,-4,168,33,function()
        GH.previewClass=nil;GH.slot=0;GH.tab="Upgrades";GH:Refresh()
    end)
    label(tool,"SCAN STATUS",409,-7,"normal",T.gold,92)
    self.footer=label(tool,"Ready to scan",505,-7,"normal",{0.87,0.93,1.0,1},395)
    self.footer:SetWordWrap(false)
    -- complete status available on hover, not hidden behind PlayerModel
    tool:EnableMouse(true)
    tool:SetScript("OnEnter",function()
        if GameTooltip then GameTooltip:SetOwner(tool,"ANCHOR_TOP");GameTooltip:SetText(GH.journalStatus or "Ready to scan");GameTooltip:Show() end
    end)
    tool:SetScript("OnLeave",function() GameTooltip:Hide() end)

    -- True bottom showcase: 7 + 6 individually clickable image cards,
    -- with no text baked into the frame texture.
    local showcase=goldFrame(f,29,-721,1167,155)
    self.showcasePanel=showcase
    label(showcase,"ALL CLASSES & SPECIALIZATIONS  •  CLICK TO PREVIEW",10,-6,"normal",T.gold,1122)
    self.showcaseCards={}
    local presentation={"WARRIOR","PALADIN","ROGUE","HUNTER","PRIEST","DEMONHUNTER","MAGE","MONK","DRUID","SHAMAN","DEATHKNIGHT","WARLOCK","EVOKER"}
    for i,class in ipairs(presentation) do
        local config
        for _,c in ipairs(CLASS_PREVIEWS) do if c[1]==class then config=c;break end end
        if config then
            local row=(i<=7) and 0 or 1
            local col=(i<=7) and i-1 or i-8
            local x=8+col*165+(row==1 and 83 or 0)
            local y=-26-row*62
            local card=CreateFrame("Button",nil,showcase,"BackdropTemplate")
            card:SetPoint("TOPLEFT",showcase,"TOPLEFT",x,y);card:SetSize(158,60)
            backdrop(card,T.dark,T.border)
            local picture=card:CreateTexture(nil,"ARTWORK")
            picture:SetPoint("TOPLEFT",card,"TOPLEFT",2,-2);picture:SetSize(154,40)
            local classText=label(card,config[2]:upper(),3,-42,"normal",T.gold,152,"CENTER")
            classText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10,"OUTLINE")
            card:SetScript("OnClick",function() GH:PreviewClassScene(class) end)
            card:SetScript("OnEnter",function(self)
                self:SetBackdropBorderColor(1,0.83,0.32,1)
                GameTooltip:SetOwner(self,"ANCHOR_TOP")
                GameTooltip:SetText(config[2].." scene preview")
                GameTooltip:AddLine(config[6],0.8,0.9,1)
                GameTooltip:AddLine("Your character and equipment remain unchanged",0.8,0.9,1)
                GameTooltip:Show()
            end)
            card:SetScript("OnLeave",function() GameTooltip:Hide();GH:RefreshClassStage(select(2,UnitClass("player")),"",GH:GetCharacterLevel()) end)
            table.insert(self.showcaseCards,{frame=card,picture=picture,class=class})
        end
    end
    local benefits=goldFrame(f,1206,-721,365,155)
    label(benefits,"THE RIGHT GEAR AT EVERY LEVEL",12,-8,"normal",T.gold,338)
    local benefitsList={"Level-aware upgrades and endgame","Automatic class / spec / faction scenes","Best known gear from verified sources","World map and goal tracking","Real-time scan progress"}
    for i,txt in ipairs(benefitsList) do
        local ic=benefits:CreateTexture(nil,"ARTWORK")
        local benefitIcon={"level-up","sparkle","shield","map","scan"}
        ic:SetTexture(GH_ICON_ROOT..benefitIcon[i]..".tga")
        ic:SetPoint("TOPLEFT",benefits,"TOPLEFT",13,-27-(i-1)*23);ic:SetSize(17,17)
        label(benefits,txt,36,-28-(i-1)*23,"normal",T.grey,311)
    end
    f:Hide()
    local mini=CreateFrame("Button","GearHunterMinimapButton",Minimap)
    mini:SetSize(30,30);mini:SetPoint("TOPLEFT",Minimap,"TOPLEFT",-6,6)
    mini:SetFrameStrata("MEDIUM")
    local icon=mini:CreateTexture(nil,"ARTWORK");icon:SetAllPoints()
    icon:SetTexture(GH_ICON_ROOT.."map.tga")
    mini:SetScript("OnClick",function() GH:Toggle() end)
    mini:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:SetText("Gear Hunter v"..GH.version)
        GameTooltip:AddLine("Click to open | /gh",1,1,1);GameTooltip:Show()
    end)
    mini:SetScript("OnLeave",function() GameTooltip:Hide() end)
    self:ScanEquipped()
end
