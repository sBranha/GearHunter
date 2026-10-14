-- Gear Hunter 0.3.1 - Retail (Midnight). No third-party dependencies.
local addonName, GH = ...
_G.GearHunter = GH
GH.version = "0.11.10"
GH.items = {}
GH.equipped = {}
GH.slotDefs = {
    {id=1,name="Head",filter=0}, {id=2,name="Neck",filter=1},
    {id=3,name="Shoulders",filter=2}, {id=15,name="Back",filter=3},
    {id=5,name="Chest",filter=4}, {id=9,name="Wrist",filter=5},
    {id=10,name="Hands",filter=6}, {id=6,name="Waist",filter=7},
    {id=7,name="Legs",filter=8}, {id=8,name="Feet",filter=9},
    {id=11,name="Ring 1",filter=12}, {id=12,name="Ring 2",filter=12},
    {id=13,name="Trinket 1",filter=13}, {id=14,name="Trinket 2",filter=13},
    {id=16,name="Main Hand",filter=10}, {id=17,name="Off Hand",filter=11},
}
GH.slotForFilter = {[0]=1,[1]=2,[2]=3,[3]=15,[4]=5,[5]=9,[6]=10,[7]=6,
    [8]=7,[9]=8,[10]=16,[11]=17,[12]=11,[13]=13}
GH.slotNames = {}
for _, slot in ipairs(GH.slotDefs) do GH.slotNames[slot.id] = slot.name end

local function safeNumber(n)
    if type(n)=="number" and (not issecretvalue or not issecretvalue(n)) then return n end
    return nil
end
GH.SafeNumber = safeNumber
-- WoW can report nil or 0 icon textures before item data has loaded.
-- Preserve authentic Blizzard item icons where available, never fabricate loot.
GH.missingItemIcon = "Interface\\AddOns\\GearHunter\\Art\\UIIcons\\item-placeholder.tga"
function GH:GetDisplayItemIcon(rec)
    if type(rec)~="table" then return self.missingItemIcon end
    local icon=rec.icon
    if type(icon)=="number" and icon>0 then return icon end
    if type(icon)=="string" and icon~="" then return icon end
    local id=rec.itemID
    if type(id)=="number" and id>0 then
        if C_Item and type(C_Item.GetItemIconByID)=="function" then
            local ok,found=pcall(C_Item.GetItemIconByID,id)
            if ok and ((type(found)=="number" and found>0) or (type(found)=="string" and found~="")) then
                rec.icon=found
                return found
            end
        end
        if type(GetItemIcon)=="function" then
            local ok,found=pcall(GetItemIcon,id)
            if ok and ((type(found)=="number" and found>0) or (type(found)=="string" and found~="")) then
                rec.icon=found
                return found
            end
        end
    end
    return self.missingItemIcon
end
function GH:Print(message)
    print("|cffff4040Gear Hunter:|r " .. tostring(message))
end
function GH:InitDatabase()
    if type(GearHunterDB) ~= "table" then GearHunterDB = {} end
    self.db = GearHunterDB
    if type(self.db.goals) ~= "table" then self.db.goals = {} end
    if type(self.db.options) ~= "table" then self.db.options = {} end
    if not self.db.options.migrated031 then
        -- Old saved Raid-only filter often made every item appear to share
        -- one source. Begin this corrected build with All Sources selected.
        self.db.options.sourceFilter="All"
        self.db.options.migrated031=true
    end
    if self.db.options.sourceFilter ~= "Raid" and self.db.options.sourceFilter ~= "Mythic+" then self.db.options.sourceFilter="All" end
    if not self.db.options.raidDifficulty then self.db.options.raidDifficulty = 16 end
    if not self.db.options.keystoneLevel then self.db.options.keystoneLevel = 10 end
    -- Upgrade older v0.1.x installs (which defaulted to HEROIC raid and no M+ key).
    -- This version starts on top-end targets, while letting users lower them later.
    if not self.db.options.migrated020 then
        self.db.options.raidDifficulty=16
        self.db.options.keystoneLevel=10
        self.db.options.migrated020=true
    end
    -- Background reset once on the first 0.8.0 launch, so prior Custom choices
    -- cannot lock another character to outdated artwork. Subsequent manual
    -- preferences are respected per character.
    if not self.db.options.sceneMigration080 then
        if type(self.db.characterBackgrounds)=="table" then
            for _,pref in pairs(self.db.characterBackgrounds) do
                if type(pref)=="table" then pref.bgMode="Auto" end
            end
        end
        self.db.options.sceneMigration080=true
    end
    -- v0.11.9: migrate all obsolete Race backgrounds to HD Auto scenes.
    -- Preserve Custom, Class, Off, intensity, equipment, and other settings.
    if not self.db.options.sceneMigration0119 then
        if type(self.db.characterBackgrounds)=="table" then
            for _,pref in pairs(self.db.characterBackgrounds) do
                if type(pref)=="table" and pref.bgMode=="Race" then pref.bgMode="Auto" end
            end
        end
        if self.db.options.bgMode=="Race" then self.db.options.bgMode="Auto" end
        self.db.options.sceneMigration0119=true
    end
    if type(self.db.pins) ~= "table" then self.db.pins = {} end
    if type(self.db.instancePins) ~= "table" then self.db.instancePins = {} end
    -- Tonight limits only affect the Tonight view, never the all-upgrades list.
    self.db.options.tonightKey = tonumber(self.db.options.tonightKey) or 6
    if self.db.options.tonightKey < 2 or self.db.options.tonightKey > 10 then self.db.options.tonightKey=6 end
    self.db.options.tonightRaid = tonumber(self.db.options.tonightRaid) or 15
    if not ({[17]=true,[14]=true,[15]=true,[16]=true})[self.db.options.tonightRaid] then
        self.db.options.tonightRaid=15
    end
    self.db.options.bgMode = ({Auto=true,Class=true,Custom=true,Off=true})[tostring(self.db.options.bgMode)] and self.db.options.bgMode or "Auto"
    self.db.options.bgCustomTheme = tostring(self.db.options.bgCustomTheme or "PRIEST")
    self.db.options.bgIntensity = tonumber(self.db.options.bgIntensity) or 2
    if self.db.options.bgIntensity < 1 or self.db.options.bgIntensity > 3 then self.db.options.bgIntensity=2 end
    -- First launch of the artwork-backed release: enable the new scene in Auto
    -- mode so a saved older theme cannot leave a previous blank/flat backdrop.
    if not self.db.options.migrated070 then
        self.db.options.bgMode="Auto"
        self.db.options.bgIntensity=3
        self.db.options.migrated070=true
    end
    -- Art choices now live in characterBackgrounds[GUID]. Older global choices
    -- are intentionally not inherited by every other character.
    if type(self.db.characterBackgrounds)~="table" then self.db.characterBackgrounds={} end
    if self.InitializeGearIndex then self:InitializeGearIndex() end
    if self.InitBossLootHunter then self:InitBossLootHunter() end
    if self.InitTransmogHunter then self:InitTransmogHunter() end
    if self.InitHuntChecklist then self:InitHuntChecklist() end
    if self.InitFarmRoute then self:InitFarmRoute() end
    if self.InitializeSmartPicks then self:InitializeSmartPicks() end
    if self.InitializeUpgradePlanner then self:InitializeUpgradePlanner() end
    if self.InitAltTracker then self:InitAltTracker() end
    if self.InitFarmSessions then self:InitFarmSessions() end
    -- Collection Dashboard uses the existing saved records; no extra migration is required.
    -- Old manually saved pins never recorded which validated source they belonged
    -- to. Keep them in saved variables, but the navigator will not blindly reuse
    -- them to send the player to an unrelated dungeon.
end
-- The character level and the maximum supported player level are read from
-- the client each time; there is no hardcoded 80/90/100 ceiling.
function GH:GetCharacterLevel()
    local level=UnitLevel and UnitLevel("player")
    return safeNumber(level) or 1
end
function GH:GetCurrentLevelCap()
    -- Try whichever level-cap function the current Retail API exposes.
    for _,fn in ipairs({GetMaxPlayerLevel or GetMaxLevelForPlayerExpansion,
                        GetMaxLevelForPlayerExpansion or GetMaxPlayerLevel}) do
        if type(fn)=="function" then
            local ok,n=pcall(fn)
            if ok and safeNumber(n) and n>=10 then return n end
        end
    end
    if type(GetMaxLevelForExpansion)=="function" and type(GetExpansionLevel)=="function" then
        local okExp,exp=pcall(GetExpansionLevel)
        if okExp and type(exp)=="number" then
            local ok,n=pcall(GetMaxLevelForExpansion,exp)
            if ok and safeNumber(n) and n>=10 then return n end
        end
    end
    if safeNumber(MAX_PLAYER_LEVEL) and MAX_PLAYER_LEVEL>=10 then return MAX_PLAYER_LEVEL end
    -- Midnight's live fallback only; a future expansion API takes priority.
    return 90
end
function GH:IsLevelingCharacter()
    local cap=self:GetCurrentLevelCap()
    return not cap or self:GetCharacterLevel()<cap
end
function GH:GetRequiredItemLevel(item)
    if not item then return nil end
    local getter=(C_Item and C_Item.GetItemInfo) or GetItemInfo
    if type(getter)~="function" then return nil end
    local ok,_,_,_,_,minLevel=pcall(getter,item)
    if ok and safeNumber(minLevel) then return minLevel end
    return nil
end
function GH:CanShowForLevel(rec)
    if not rec then return false end
    local playerLevel=self:GetCharacterLevel()
    if rec.requiredLevel and rec.requiredLevel>playerLevel then return false end
    -- Never sell max-level Mythic+ or raid loot to a new/low level character.
    if self:IsLevelingCharacter() and (rec.mythicPlus or rec.raid) then return false end
    if self:IsLevelingCharacter() and not rec.fromBag and not rec.requiredLevel then
        return false -- we can't verify that this reward is equipable at this level
    end
    return true
end

local EQUIP_LOCATION_TO_FILTER={
    INVTYPE_HEAD=0,INVTYPE_NECK=1,INVTYPE_SHOULDER=2,
    INVTYPE_CLOAK=3,INVTYPE_CHEST=4,INVTYPE_ROBE=4,
    INVTYPE_WRIST=5,INVTYPE_HAND=6,INVTYPE_WAIST=7,
    INVTYPE_LEGS=8,INVTYPE_FEET=9,
    INVTYPE_WEAPONMAINHAND=10,INVTYPE_2HWEAPON=10,
    INVTYPE_WEAPON=10,INVTYPE_RANGED=10,INVTYPE_RANGEDRIGHT=10,
    INVTYPE_THROWN=10,INVTYPE_SHIELD=11,INVTYPE_HOLDABLE=11,
    INVTYPE_WEAPONOFFHAND=11,INVTYPE_FINGER=12,INVTYPE_TRINKET=13,
}
function GH:ScanBagUpgrades()
    self.bagUpgrades={}
    if not C_Container or not C_Container.GetContainerNumSlots
        or not C_Container.GetContainerItemLink then return end
    for bag=0,4 do
        local ok,count=pcall(C_Container.GetContainerNumSlots,bag)
        if ok and type(count)=="number" then
            for index=1,count do
                local linkOk,link=pcall(C_Container.GetContainerItemLink,bag,index)
                if linkOk and type(link)=="string" then
                    local itemInfo=(C_Item and C_Item.GetItemInfo) or GetItemInfo
                    if type(itemInfo)=="function" then
                        local infoOk,name,_,_,_,minLevel,_,_,_,equipLoc,icon=pcall(itemInfo,link)
                        local filter=infoOk and EQUIP_LOCATION_TO_FILTER[equipLoc] or nil
                        local wearable=true
                        if C_Item and C_Item.IsEquippableItem then
                            local okEquip,yes=pcall(C_Item.IsEquippableItem,link)
                            wearable=okEquip and yes
                        end
                        if filter and wearable and (not safeNumber(minLevel) or minLevel<=self:GetCharacterLevel()) then
                            local ilvl
                            if C_Item and C_Item.GetDetailedItemLevelInfo then
                                local levelOk,n=pcall(C_Item.GetDetailedItemLevelInfo,link)
                                if levelOk then ilvl=safeNumber(n) end
                            end
                            local itemID
                            if GetItemInfoInstant then
                                local idOk,id=pcall(GetItemInfoInstant,link)
                                if idOk then itemID=id end
                            end
                            if itemID and ilvl then
                                self.bagUpgrades[#self.bagUpgrades+1]={
                                    itemID=itemID,name=name or ("Item "..itemID),link=link,
                                    icon=icon,level=ilvl,requiredLevel=safeNumber(minLevel),filter=filter,
                                    instance="In your bags",fromBag=true,sourceVerified=false,
                                    bag=bag,bagSlot=index,levelSource="Inventory item level",
                                }
                            end
                        end
                    end
                end
            end
        end
    end
end

function GH:ScanEquipped()
    wipe(self.equipped)
    for _, slot in ipairs(self.slotDefs) do
        local id = slot.id
        local link = GetInventoryItemLink("player", id)
        local itemID = GetInventoryItemID("player", id)
        local icon = GetInventoryItemTexture("player", id)
        local level
        -- ItemLocation returns the level of the ACTUALLY EQUIPPED item, including
        -- purchased upgrades; comparing against the item's base ID loses upgrades.
        if link and ItemLocation and ItemLocation.CreateFromEquipmentSlot
            and C_Item and C_Item.GetCurrentItemLevel then
            local ok, n = pcall(function()
                local location=ItemLocation:CreateFromEquipmentSlot(id)
                return C_Item.GetCurrentItemLevel(location)
            end)
            if ok then level=safeNumber(n) end
        end
        if not level and link and C_Item and C_Item.GetDetailedItemLevelInfo then
            local ok, n=pcall(C_Item.GetDetailedItemLevelInfo,link)
            if ok then level=safeNumber(n) end
        end
        -- Blizzard's upgrade-track API works on owned/equipped items without
        -- having to guess costs or visit a specific upgrader NPC.
        local upgrade
        if link and C_Item and C_Item.GetItemUpgradeInfo then
            local ok,info=pcall(C_Item.GetItemUpgradeInfo,link)
            if ok and type(info)=="table" then
                upgrade={current= safeNumber(info.currentLevel),
                    max= safeNumber(info.maxLevel),
                    maxItemLevel= safeNumber(info.maxItemLevel),
                    track=type(info.trackString)=="string" and info.trackString or nil}
            end
        end
        self.equipped[id] = {link=link, itemID=itemID, icon=icon, level=level or 0,
            upgrade=upgrade}
    end
    -- A gear/equipment event is the only reason to reload the character model.
    -- Otherwise its rotation would reset whenever the journal or UI refreshes.
    self.characterModelNeedsRefresh=true
    self:ScanBagUpgrades()
    if self.IndexKnownGear then self:IndexKnownGear() end
    if self.CaptureAltSnapshot then self:CaptureAltSnapshot(false) end
    if self.RefreshCharacterPanel then self:RefreshCharacterPanel() end
    if self.Refresh then self:Refresh() end
end
function GH:EffectiveSlot(rec)
    if rec and rec.compareSlot then return rec.compareSlot end
    if rec and rec.equippedSlot then return rec.equippedSlot end
    local f = rec.filter
    if f == 12 then
        local a,b=self.equipped[11],self.equipped[12]
        return (a and b and a.level > b.level) and 12 or 11
    elseif f == 13 then
        local a,b=self.equipped[13],self.equipped[14]
        return (a and b and a.level > b.level) and 14 or 13
    end
    return self.slotForFilter[f]
end
function GH:Gain(rec)
    if not rec or not rec.level then return nil end
    if rec.isEquipped then return 0 end
    local slot = self:EffectiveSlot(rec)
    if not slot then return nil end
    local own = self.equipped[slot]
    if own and own.itemID and (not own.level or own.level<=0) then return nil end
    return rec.level - ((own and own.level) or 0)
end
function GH:HasItem(itemID,requiredLevel)
    if not itemID then return false end
    local function matchesLevel(level)
        return not requiredLevel or (type(level)=="number" and level>=requiredLevel)
    end
    for _, slot in ipairs(self.slotDefs) do
        local own=self.equipped[slot.id]
        if own and own.itemID==itemID and matchesLevel(own.level) then
            return true, "Equipped (target level met)"
        end
    end
    if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemID then
        for bag=0,4 do
            local ok,count=pcall(C_Container.GetContainerNumSlots,bag)
            if ok and type(count)=="number" then
                for index=1,count do
                    local success,id=pcall(C_Container.GetContainerItemID,bag,index)
                    if success and id==itemID then
                        if not requiredLevel then return true,"In bags" end
                        local itemLink
                        if C_Container.GetContainerItemLink then
                            local linkOk,link=pcall(C_Container.GetContainerItemLink,bag,index)
                            if linkOk then itemLink=link end
                        end
                        if itemLink and C_Item and C_Item.GetDetailedItemLevelInfo then
                            local levelOk,level=pcall(C_Item.GetDetailedItemLevelInfo,itemLink)
                            if levelOk and matchesLevel(safeNumber(level)) then
                                return true,"In bags (target level met)"
                            end
                        end
                    end
                end
            end
        end
    end
    return false,"Not acquired at target item level"
end
function GH:GoalKey(rec)
    if not rec or not rec.itemID then return nil end
    return tostring(rec.itemID)..":"..tostring(rec.instanceID or 0)..":"..
        tostring(rec.difficulty or 0)..":"..tostring(rec.keystoneLevel or 0)
end
function GH:HasGoal(rec)
    local key=self:GoalKey(rec)
    return key and self.db and self.db.goals and
        (self.db.goals[key] ~= nil or self.db.goals[rec.itemID] ~= nil)
end
function GH:GetEquippedRecords(slotID)
    local result={}
    for _,slot in ipairs(self.slotDefs) do
        if not slotID or slotID==0 or slot.id==slotID then
            local own=self.equipped[slot.id]
            if own and own.itemID then
                local name
                if GetItemInfo and own.link then
                    local ok,itemName=pcall(GetItemInfo,own.link)
                    if ok then name=itemName end
                end
                result[#result+1]={isEquipped=true,equippedSlot=slot.id,
                    itemID=own.itemID,name=name or (slot.name.." (equipped)"),
                    link=own.link,icon=own.icon,level=own.level,
                    upgrade=own.upgrade}
            end
        end
    end
    return result
end
function GH:SetGoal(rec)
    if not rec or not rec.itemID or rec.isEquipped then return end
    local key=self:GoalKey(rec)
    if self.db.goals[key] or self.db.goals[rec.itemID] then
        self.db.goals[key]=nil
        self.db.goals[rec.itemID]=nil -- legacy 0.3 goals
        self:Print("Removed goal: " .. (rec.name or rec.itemID))
    else
        self.db.goals[key] = {
            itemID=rec.itemID,
            name=rec.name, icon=rec.icon, link=rec.link,
            instance=rec.instance, encounter=rec.encounter,
            instanceID=rec.instanceID, encounterID=rec.encounterID,
            difficulty=rec.difficulty, level=rec.level,
            tier=rec.tier, raid=rec.raid, mythicPlus=rec.mythicPlus,
            keystoneLevel=rec.keystoneLevel, levelSource=rec.levelSource,
            filter=rec.filter, sourceVerified=rec.sourceVerified,
        }
        if self.AddHuntItem then self:AddHuntItem(rec,true) end
        self:Print("Tracking (also added to Hunt List): " .. (rec.name or rec.itemID))
    end
    self:Refresh()
end
function GH:SafeCallback(context, func, ...)
    local ok, result = pcall(func, ...)
    if not ok then self:Print(context .. " unavailable: " .. tostring(result)) end
    return ok, result
end
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
-- Spec events can arrive after login and after the gear scanner's first refresh.
for _,eventName in ipairs({"PLAYER_TALENT_UPDATE","ACTIVE_TALENT_GROUP_CHANGED"}) do
    pcall(eventFrame.RegisterEvent,eventFrame,eventName)
end
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event=="ADDON_LOADED" then
        if ... ~= addonName then return end
        GH:InitDatabase()
        GH:CreateUI()
        GH:Print("v"..GH.version.." loaded. Type |cffffffff/gh|r to open.")
    elseif GH.db then
        if event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_EQUIPMENT_CHANGED"
            or event=="PLAYER_LEVEL_UP"
            or event=="PLAYER_SPECIALIZATION_CHANGED"
            or event=="PLAYER_TALENT_UPDATE"
            or event=="ACTIVE_TALENT_GROUP_CHANGED" then
            GH:ScanEquipped()
            if event=="PLAYER_ENTERING_WORLD" and type(RequestRaidInfo)=="function" then
                pcall(RequestRaidInfo) -- refresh saved instance info for this character
            end
            if GH.UpdateCharacterBackground then GH:UpdateCharacterBackground() end
            if event=="PLAYER_LEVEL_UP" or event=="PLAYER_SPECIALIZATION_CHANGED" then
                if GH.scanRunning then GH:CancelJournalScan() end
                if GH.firstScanStarted then GH:StartJournalScan() end
            end
        elseif event=="BAG_UPDATE_DELAYED" then
            GH:ScanBagUpgrades()
            if GH.IndexKnownGear then GH:IndexKnownGear() end
            if GH.Refresh and GH.frame and GH.frame:IsShown() then GH:Refresh() end
        elseif GH.Refresh and GH.frame and GH.frame:IsShown() then
            GH:Refresh()
        end
    end
end)
SLASH_GEARHUNTER1 = "/gh"
SLASH_GEARHUNTER2 = "/gearhunter"
SlashCmdList.GEARHUNTER = function(input)
    input = string.lower(strtrim(input or ""))
    if input == "scan" then GH:StartJournalScan()
    elseif input == "support" or input == "help" then GH:OpenSupportCenter("HOME")
    elseif input == "whatsnew" or input == "changelog" or input == "updates" then GH:OpenSupportCenter("NEWS")
    elseif input == "report" or input == "issue" then GH:OpenSupportCenter("SUPPORT")
    elseif input == "tonight" then GH:ShowTab("Tonight")
    elseif input == "gear" then GH:ShowTab("My Gear")
    elseif input == "search" or input == "find" then GH:ShowTab("Gear Search")
    elseif input == "bosses" or input == "boss" or input == "loot" then GH:ShowTab("Boss Loot Hunter")
    elseif input == "favorites" or input == "favs" or input == "bookmarks" then GH:OpenBossFavorites()
    elseif input == "session" or input == "farmlog" or input == "log" then GH:ShowTab("Farm Session")
    elseif input == "farmstart" then GH:StartFarmSession(); GH:ShowTab("Farm Session")
    elseif input == "farmstop" then GH:StopFarmSession(); GH:ShowTab("Farm Session")
    elseif input == "catalog" or input == "index" then GH:ShowTab("Gear Search");GH:StartGearCatalogScan()
    elseif input == "capture" then GH:ShowTab("Gear Search");GH:CaptureOpenGearSources(true)
    elseif input == "mog" or input == "transmog" then GH:ShowTab("Transmog Hunter")
    elseif input == "hunt" or input == "checklist" or input == "progress" then GH:ShowTab("Hunt List")
    elseif input == "route" or input == "farmroute" then GH:ShowTab("Farm Route")
    elseif input == "smart" or input == "picks" or input == "recommend" then GH:ShowTab("Smart Picks")
    elseif input == "plan" or input == "upgradeplan" or input == "planner" then GH:ShowTab("Upgrade Planner")
    elseif input == "weekly" or input == "lockouts" then GH:ShowTab("Weekly Farm")
    elseif input == "alts" or input == "alt" or input == "characters" then GH:ShowTab("Alt Tracker")
    elseif input == "collection" or input == "collections" or input == "dashboard" then GH:ShowTab("Collection Dashboard")
    elseif input == "bags" then GH:ScanBagUpgrades();GH:ShowTab("Upgrades")
    elseif input == "auto" then GH:SelectAutomaticBackground();GH:Print("Automatic class/spec background enabled for this character.")
    elseif input == "scene" then
        local path,file,class,specID,race,faction=GH:GetCharacterScene()
        GH:Print("Artwork "..tostring(file).." | class "..tostring(class).." | spec "..tostring(specID).." | faction "..tostring(faction).." | mode "..tostring(GH:GetBackgroundOption("bgMode","Auto")))
    elseif input == "character" or input == "char" then GH:ShowTab("Character")

    elseif input == "status" then
        GH:Print("v"..GH.version.." | "..tostring(#GH.items).." source options | "..(GH.journalStatus or "not scanned"))
        local upgrades=GH:GetVisibleItems("Upgrades",0)
        GH:Print(#upgrades.." higher-item-level results with current source filter ("..(GH.db.options.sourceFilter or "All")..")")
        GH:Print("Source checks: "..tostring(GH.sourceAccepted or 0).." valid rows, "..tostring(GH.sourceRejected or 0).." mismatched/unverified rows ignored")
    elseif input == "sources" then
        GH:Print("Verified loot sources (each comes from boss-to-instance ID match):")
        local counts={};local labels={}
        for _,record in ipairs(GH.items) do
            local id=record.instanceID
            counts[id]=(counts[id] or 0)+1;labels[id]=record.instance
        end
        local ids={};for id in pairs(counts) do ids[#ids+1]=id end
        table.sort(ids)
        if #ids==0 then GH:Print("No verified sources loaded. Run /gh scan.") end
        for _,id in ipairs(ids) do
            GH:Print(tostring(labels[id]).." (journal "..id.."): "..counts[id].." reward entries")
        end
    elseif input == "pin" then GH:SavePlayerPin()
    elseif input == "reset" then GH.frame:ClearAllPoints(); GH.frame:SetPoint("CENTER"); GH:Print("Window centered")
    else GH:Toggle() end
end
function GearHunter_OnAddonCompartmentClick() GH:Toggle() end
