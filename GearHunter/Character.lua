-- Gear Hunter 0.10.0: render-style layout refresh + automatic per-character scene art + rotating paper doll
-- with stronger spec/class/race backgrounds for the character view.
local addonName, GH = ...
local NO_ICON="Interface\\AddOns\\GearHunter\\Art\\UIIcons\\item-placeholder.tga"
local charcoal={0.035,0.046,0.082,0.985}
local border={0.34,0.50,0.84,1}
local highlight={0.06,0.18,0.38,1}
local gold={1,0.82,0.34,1}
local green={0.18,0.96,0.78,1}
local muted={0.80,0.86,0.96,1}

local function paint(frame,bg,edge)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    frame:SetBackdropColor(unpack(bg or charcoal))
    frame:SetBackdropBorderColor(unpack(edge or border))
end
local function font(parent,text,fontName)
    local label=parent:CreateFontString(nil,"OVERLAY",fontName or "GameFontNormal")
    label:SetText(text or "")
    return label
end
local function clamp(v,lo,hi)
    if type(v)~="number" then return lo end
    if v<lo then return lo end
    if v>hi then return hi end
    return v
end
local function mix(a,b,t)
    return a+(b-a)*t
end
local function tint(col,m)
    return {clamp(col[1]*m,0,1),clamp(col[2]*m,0,1),clamp(col[3]*m,0,1),1}
end

GH.backgroundModes={"Auto","Class","Custom","Off"}

GH.specThemes={
    [258]={key="SHADOW_PRIEST",name="Shadow Priest",icon="Interface\\Icons\\Spell_Shadow_ShadowWordPain",primary={0.67,0.49,1.00},secondary={0.23,0.15,0.43},base={0.03,0.03,0.08},scene="void_sanctum"},
    [257]={key="HOLY_PRIEST",name="Holy Priest",icon="Interface\\Icons\\Spell_Holy_GuardianSpirit",primary={1.00,0.93,0.72},secondary={0.81,0.69,0.36},base={0.10,0.09,0.06},scene="holy_sanctum"},
    [256]={key="DISC_PRIEST",name="Discipline Priest",icon="Interface\\Icons\\Spell_Holy_PowerWordShield",primary={0.93,0.86,0.60},secondary={0.54,0.45,0.18},base={0.08,0.07,0.05},scene="holy_sanctum"},
}
GH.backgroundThemes={
    {key="PRIEST",name="Priest",icon="Interface\\Icons\\Spell_Holy_PowerWordShield",primary={0.78,0.84,1},secondary={0.34,0.35,0.62},base={0.05,0.06,0.11}},
    {key="WARRIOR",name="Warrior",icon="Interface\\Icons\\Ability_Warrior_BattleShout",primary={0.94,0.58,0.26},secondary={0.47,0.18,0.10},base={0.10,0.06,0.05}},
    {key="PALADIN",name="Paladin",icon="Interface\\Icons\\Spell_Holy_HolyBolt",primary={0.96,0.78,0.35},secondary={0.79,0.39,0.53},base={0.10,0.08,0.06}},
    {key="MAGE",name="Mage",icon="Interface\\Icons\\Spell_Frost_FrostBolt02",primary={0.43,0.82,1.00},secondary={0.16,0.35,0.73},base={0.04,0.06,0.12}},
    {key="WARLOCK",name="Warlock",icon="Interface\\Icons\\Spell_Shadow_DeathCoil",primary={0.73,0.41,0.97},secondary={0.25,0.10,0.39},base={0.08,0.04,0.11}},
    {key="HUNTER",name="Hunter",icon="Interface\\Icons\\Ability_Hunter_BeastTaming",primary={0.43,0.89,0.42},secondary={0.20,0.41,0.14},base={0.05,0.09,0.05}},
    {key="SHAMAN",name="Shaman",icon="Interface\\Icons\\Spell_Nature_Lightning",primary={0.28,0.67,1.00},secondary={0.18,0.27,0.55},base={0.05,0.07,0.11}},
    {key="DRUID",name="Druid",icon="Interface\\Icons\\Ability_Druid_Maul",primary={0.98,0.47,0.12},secondary={0.43,0.26,0.10},base={0.10,0.07,0.04}},
    {key="ROGUE",name="Rogue",icon="Interface\\Icons\\Ability_BackStab",primary={1.00,0.89,0.29},secondary={0.45,0.34,0.12},base={0.09,0.08,0.04}},
    {key="MONK",name="Monk",icon="Interface\\Icons\\ClassIcon_Monk",primary={0.14,0.91,0.58},secondary={0.08,0.36,0.24},base={0.04,0.08,0.07}},
    {key="DEATHKNIGHT",name="Death Knight",icon="Interface\\Icons\\Spell_Deathknight_ClassIcon",primary={0.86,0.16,0.22},secondary={0.31,0.05,0.07},base={0.10,0.03,0.05}},
    {key="DEMONHUNTER",name="Demon Hunter",icon="Interface\\Icons\\ClassIcon_DemonHunter",primary={0.39,0.95,0.24},secondary={0.17,0.40,0.10},base={0.05,0.09,0.04}},
    {key="EVOKER",name="Evoker",icon="Interface\\Icons\\ClassIcon_Evoker",primary={0.27,0.93,0.78},secondary={0.10,0.42,0.34},base={0.04,0.09,0.08}},
}
GH.backgroundThemeByKey={}
for _,theme in ipairs(GH.backgroundThemes) do GH.backgroundThemeByKey[theme.key]=theme end
GH.raceThemes={
    Human={name="Human",accent={0.85,0.74,0.42}},
    Orc={name="Orc",accent={0.61,0.31,0.16}},
    Dwarf={name="Dwarf",accent={0.73,0.64,0.50}},
    NightElf={name="Night Elf",accent={0.54,0.54,0.92}},
    Scourge={name="Undead",accent={0.42,0.74,0.46}},
    Tauren={name="Tauren",accent={0.80,0.58,0.34}},
    Gnome={name="Gnome",accent={0.91,0.69,0.67}},
    Troll={name="Troll",accent={0.28,0.74,0.86}},
    Goblin={name="Goblin",accent={0.61,0.86,0.24}},
    BloodElf={name="Blood Elf",accent={0.92,0.42,0.34}},
    Draenei={name="Draenei",accent={0.58,0.70,1.00}},
    Worgen={name="Worgen",accent={0.57,0.57,0.68}},
    Pandaren={name="Pandaren",accent={0.84,0.84,0.84}},
    Nightborne={name="Nightborne",accent={0.47,0.48,0.86}},
    HighmountainTauren={name="Highmountain",accent={0.71,0.58,0.31}},
    VoidElf={name="Void Elf",accent={0.55,0.36,0.97}},
    LightforgedDraenei={name="Lightforged",accent={0.94,0.82,0.48}},
    ZandalariTroll={name="Zandalari",accent={0.98,0.74,0.22}},
    KulTiran={name="Kul Tiran",accent={0.50,0.67,0.91}},
    DarkIronDwarf={name="Dark Iron",accent={0.86,0.40,0.22}},
    Vulpera={name="Vulpera",accent={0.92,0.74,0.40}},
    MagharOrc={name="Mag'har",accent={0.69,0.40,0.22}},
    Mechagnome={name="Mechagnome",accent={0.70,0.80,0.88}},
    Dracthyr={name="Dracthyr",accent={0.29,0.86,0.77}},
    EarthenDwarf={name="Earthen",accent={0.80,0.70,0.48}},
}

-- Each character gets its OWN art preference. In 0.7.1 the global bgMode
-- persisted across alts, and Demon Hunters / Warlocks were mapped to Priest art.
function GH:GetBackgroundPrefs()
    if not self.db then return nil end
    if type(self.db.characterBackgrounds)~="table" then self.db.characterBackgrounds={} end
    local guid=UnitGUID and UnitGUID("player")
    local key=type(guid)=="string" and guid or nil
    if not key and UnitName then
        local name=UnitName("player")
        if type(name)=="string" and name~="" then
            key=name.."-"..(GetRealmName and GetRealmName() or "unknown-realm")
        end
    end
    if not key then return nil end
    if not self.db.characterBackgrounds[key] then
        self.db.characterBackgrounds[key]={bgMode="Auto",bgIntensity=3,bgCustomTheme="PRIEST"}
    end
    local p=self.db.characterBackgrounds[key]
    -- Retire older race backdrops while keeping other character settings.
    if p.bgMode=="Race" then p.bgMode="Auto" end
    -- v0.8.3 artwork repair: discard the old Character scene mode ONCE,
    -- avoiding stale Custom/Race selections left by previous builds.
    if not p.v082ArtworkMigration then
        p.bgMode="Auto"
        p.v082ArtworkMigration=true
    end
    return p
end
function GH:GetBackgroundOption(name,default)
    if name=="bgMode" or name=="bgIntensity" or name=="bgCustomTheme" then
        local prefs=self:GetBackgroundPrefs()
        if prefs then
            if prefs[name]~=nil then return prefs[name] end
            return default
        end
        -- During addon initialization the player GUID may not exist yet.
        -- Never import a former character's global Custom choice to a new alt.
        if name=="bgMode" then return "Auto" end
        if name=="bgIntensity" then return 3 end
        if name=="bgCustomTheme" then return "PRIEST" end
    end
    local options=self.db and self.db.options
    if options and options[name]~=nil then return options[name] end
    return default
end
local function setBackgroundOption(self,name,value)
    local p=self:GetBackgroundPrefs()
    if p then p[name]=value end
    if self.UpdateCharacterBackground then self:UpdateCharacterBackground() end
    if self.Refresh then self:Refresh() end
end
function GH:SelectAutomaticBackground()
    setBackgroundOption(self,"bgMode","Auto")
end
function GH:CycleBackgroundMode()
    local current=self:GetBackgroundOption("bgMode","Auto")
    for i,v in ipairs(self.backgroundModes) do
        if v==current then
            setBackgroundOption(self,"bgMode",self.backgroundModes[(i % #self.backgroundModes)+1])
            return
        end
    end
    setBackgroundOption(self,"bgMode","Auto")
end
function GH:CycleCustomBackgroundTheme()
    local current=self:GetBackgroundOption("bgCustomTheme","PRIEST")
    for i,v in ipairs(self.backgroundThemes) do
        if v.key==current then
            setBackgroundOption(self,"bgCustomTheme",self.backgroundThemes[(i % #self.backgroundThemes)+1].key)
            return
        end
    end
    setBackgroundOption(self,"bgCustomTheme",self.backgroundThemes[1].key)
end
function GH:CycleBackgroundIntensity()
    local current=tonumber(self:GetBackgroundOption("bgIntensity",3)) or 3
    setBackgroundOption(self,"bgIntensity",(current % 3)+1)
end

-- Every supported specialization has two ACTUAL, independently rendered scene
-- textures. The UI simply chooses a file: it never uses faction color tinting.
local ART_ROOT = "Interface\\AddOns\\GearHunter\\Art\\Scenes\\"
local SPEC_CLASS = {
    -- WARRIOR
    [71]="WARRIOR",[72]="WARRIOR",[73]="WARRIOR",
    -- PALADIN
    [65]="PALADIN",[66]="PALADIN",[70]="PALADIN",
    -- HUNTER
    [253]="HUNTER",[254]="HUNTER",[255]="HUNTER",
    -- ROGUE
    [259]="ROGUE",[260]="ROGUE",[261]="ROGUE",
    -- PRIEST
    [256]="PRIEST",[257]="PRIEST",[258]="PRIEST",
    -- DEATHKNIGHT
    [250]="DEATHKNIGHT",[251]="DEATHKNIGHT",[252]="DEATHKNIGHT",
    -- SHAMAN
    [262]="SHAMAN",[263]="SHAMAN",[264]="SHAMAN",
    -- MAGE
    [62]="MAGE",[63]="MAGE",[64]="MAGE",
    -- WARLOCK
    [265]="WARLOCK",[266]="WARLOCK",[267]="WARLOCK",
    -- MONK
    [268]="MONK",[269]="MONK",[270]="MONK",
    -- DRUID
    [102]="DRUID",[103]="DRUID",[104]="DRUID",[105]="DRUID",
    -- DEMONHUNTER
    [577]="DEMONHUNTER",[581]="DEMONHUNTER",[1480]="DEMONHUNTER",
    -- EVOKER
    [1467]="EVOKER",[1468]="EVOKER",[1473]="EVOKER",
}
local CLASS_DEFAULT_SPEC = {
    WARRIOR=71,
    PALADIN=70,
    HUNTER=254,
    ROGUE=260,
    PRIEST=258,
    DEATHKNIGHT=251,
    SHAMAN=262,
    MAGE=62,
    WARLOCK=266,
    MONK=269,
    DRUID=102,
    DEMONHUNTER=577,
    EVOKER=1467,
}
function GH:GetCharacterScene()
    local mode=self:GetBackgroundOption("bgMode","Auto")
    if mode=="Off" then return nil,"disabled" end
    local class=UnitClass and select(2,UnitClass("player")) or nil
    local specIndex=GetSpecialization and GetSpecialization()
    local specID=specIndex and GetSpecializationInfo and select(1,GetSpecializationInfo(specIndex)) or nil
    local race=UnitRace and select(2,UnitRace("player")) or nil
    local faction=UnitFactionGroup and UnitFactionGroup("player") or nil
    -- Do not silently label an uninitialized Horde/Alliance character as the
    -- opposite faction during login. Re-evaluate on login + spec change.
    if not class or (faction~="Alliance" and faction~="Horde") then
        return nil,"waiting for player / faction",class,specID,race,faction
    end
    local targetClass=(self.tab=="Character" and self.previewClass) or class
    if mode=="Custom" and not self.previewClass then
        targetClass=self:GetBackgroundOption("bgCustomTheme",class)
    end
    local requestedID=(mode=="Auto" and specID and not self.previewClass) and specID or nil
    if not requestedID or SPEC_CLASS[requestedID]~=targetClass then
        requestedID=CLASS_DEFAULT_SPEC[targetClass]
    end
    -- Never use a Priest default for an unknown class; show no art until the
    -- game supplies a valid class, then load the correct art immediately.
    if not requestedID then
        return nil,"no scene for class",class,specID,race,faction
    end
    local file=tostring(requestedID).."/"..faction..".tga"
    return ART_ROOT..file,file,class,specID,race,faction,requestedID
end
function GH:UpdateCharacterBackground()
    local bg=self.characterBackground
    if not bg or not bg.scene then return end
    local image,file,class,specID,race,faction,selectedID=self:GetCharacterScene()
    if not image then
        bg.scene:Hide()
        bg.scene:SetTexture(nil) -- never retain an old scene after switching modes
        bg.currentScene=nil
        if self.characterModelBack then
            self.characterModelBack:SetBackdropColor(0.025,0.025,0.035,1)
        end
        return
    end
    if bg.currentScene~=image then
        bg.scene:SetTexture(image)
        bg.currentScene=image
    end
    bg.scene:Show()
    local value=tonumber(self:GetBackgroundOption("bgIntensity",3)) or 3
    local brightness=({[1]=0.72,[2]=0.88,[3]=1.00})[value] or 1
    bg.scene:SetVertexColor(brightness,brightness,brightness,1)
    if self.characterModelBack then
        self.characterModelBack:SetBackdropColor(0.025,0.02,0.045,1)
    end
    if self.sceneIndicator then
        local specName=""
        local s=GetSpecialization and GetSpecialization()
        if s and GetSpecializationInfo then specName=select(2,GetSpecializationInfo(s)) or "" end
        self.sceneIndicator:SetText(self.previewClass and ("PREVIEW  /  "..self.previewClass.."  /  "..faction:upper()) or
            (faction:upper().."  /  "..specName:upper().."  /  "..tostring(selectedID or "?")))
    end
    if self.UpdateOrnateFrame then self:UpdateOrnateFrame() end
end

-- Always compare to the exact clicked equipment slot, including individual
-- finger/trinket slots. The tooltip intentionally ignores the global source
-- filter: a hidden Raid-only filter must not hide legitimate upgrades.
-- Rotation state belongs to the addon, not the model widget: SetUnit may
-- replace a character model when equipment changes, so the saved angle is
-- reapplied rather than snapping back to the front every time loot updates.
local FULL_TURN=math.pi*2
local DRAG_SPEED=0.012 -- radians per physical mouse pixel
function GH:SetCharacterFacing(angle)
    if type(angle)~="number" or angle~=angle then return false end
    self.characterFacing=angle % FULL_TURN
    local model=self.characterModel
    if not model then return false end
    -- SimpleModel:SetFacing is available on Retail PlayerModel; SetRotation is
    -- a fallback for clients implementing CharacterModelBase rotation instead.
    if model.SetFacing then
        local ok=pcall(model.SetFacing,model,self.characterFacing)
        if ok then return true end
    end
    if model.SetRotation then
        return pcall(model.SetRotation,model,self.characterFacing,false)
    end
    return false
end
function GH:RotateCharacter(delta)
    self:SetCharacterFacing((self.characterFacing or 0)+(delta or 0))
end
function GH:ResetCharacterFacing()
    self:SetCharacterFacing(0)
end
function GH:ApplyCharacterModelView()
    local model=self.characterModel
    if not model then return end
    -- Keep the character visually centered on the stage floor so tall races
    -- and bulky armor sets do not clip into the top of the scenic window.
    if model.SetCamDistanceScale then pcall(model.SetCamDistanceScale,model,1.28) end
    if model.SetPortraitZoom then pcall(model.SetPortraitZoom,model,0) end
    if model.SetPosition then pcall(model.SetPosition,model,0,0,-0.05) end
    if model.RefreshCamera then pcall(model.RefreshCamera,model) end
end
local function stopModelDrag(model)
    model.gearHunterDragging=false
    model.gearHunterLastX=nil
    model:SetScript("OnUpdate",nil)
end
function GH:EnableCharacterRotation(model)
    if not model then return end
    model:EnableMouse(true)
    model:SetScript("OnMouseDown",function(self,button)
        if button~="LeftButton" then return end
        local x=GetCursorPosition and GetCursorPosition()
        if type(x)~="number" then return end
        self.gearHunterLastX=x
        self.gearHunterDragging=true
        self:SetScript("OnUpdate",function(active)
            if not active.gearHunterDragging then return end
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                stopModelDrag(active)
                return
            end
            local currentX=GetCursorPosition and GetCursorPosition()
            if type(currentX)~="number" then return end
            local dx=currentX-(active.gearHunterLastX or currentX)
            active.gearHunterLastX=currentX
            if dx~=0 then GH:RotateCharacter(dx*DRAG_SPEED) end
        end)
    end)
    model:SetScript("OnMouseUp",function(self,button)
        if button=="LeftButton" then stopModelDrag(self) end
    end)
    model:SetScript("OnHide",stopModelDrag)
end

function GH:GetSlotUpgradeList(slotID)
    if not slotID or not self.GetVisibleItems then return {} end
    return self:GetVisibleItems("Upgrades",slotID,true)
end
function GH:OpenSlotUpgrades(slotID)
    if not slotID then return end
    self.slot=slotID
    self.selected=nil
    if self.db and self.db.options then self.db.options.sourceFilter="All" end
    self:ShowTab("Upgrades")
end
function GH:ShowEquipmentUpgradeTooltip(owner,slotID,keepOriginal)
    if not GameTooltip or not slotID then return end
    local hasInventoryItem=GetInventoryItemLink and GetInventoryItemLink("player",slotID)
    if not keepOriginal or not GameTooltip:IsShown() then
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
        if hasInventoryItem and GameTooltip.SetInventoryItem then
            local ok=pcall(GameTooltip.SetInventoryItem,GameTooltip,"player",slotID)
            if not ok then GameTooltip:SetText(self.slotNames[slotID] or "Equipment") end
        else
            GameTooltip:SetText(self.slotNames[slotID] or "Empty slot")
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("GEAR HUNTER - UPGRADES",unpack(gold))
    local own=self.equipped[slotID]
    if own and own.level and own.level>0 then
        GameTooltip:AddLine("Equipped item level: "..tostring(own.level),unpack(muted))
    end
    if self.scanRunning then
        GameTooltip:AddLine("Loot scan in progress. Results may change.",1,0.8,0.3,true)
    end
    local list=self:GetSlotUpgradeList(slotID)
    if #list==0 then
        GameTooltip:AddLine("No known usable upgrades in scanned sources or your bags.",1,0.72,0.5,true)
        GameTooltip:AddLine("Use Scan Journal to refresh sources.",unpack(muted))
    else
        local max=math.min(5,#list)
        for i=1,max do
            local rec=list[i]
            local gain=self:Gain(rec)
            local name=rec.name or ("Item "..tostring(rec.itemID or "?"))
            GameTooltip:AddDoubleLine((gain and "+"..gain.." " or "")..name,
                "iLvl "..tostring(rec.level or "?"),0.4,1,0.5,1,0.78,0.32)
            local location=rec.instance or "Unknown source"
            local mode=self.DescribeDifficulty and self:DescribeDifficulty(rec.difficulty,rec.raid,rec) or ""
            GameTooltip:AddLine("    "..location.." - "..mode,unpack(muted))
        end
        if #list>max then GameTooltip:AddLine("...and "..(#list-max).." more upgrades",1,0.8,0.4) end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(keepOriginal and "Click the nearby GH button for the full list" or
        "Click this slot for the complete upgrade list",1,0.82,0.43,true)
    GameTooltip:Show()
end

local arrangement={
    {1,2,3,15,5,9,10,6},
    {7,8,11,12,13,14,16,17},
}
function GH:CreateCharacterPanel(main)
    local panel=CreateFrame("Frame",nil,main,"BackdropTemplate")
    panel:SetPoint("TOPLEFT",main,"TOPLEFT",29,-150)
    panel:SetSize(1167,512)
    paint(panel,{0.014,0.028,0.049,0.99},{0.48,0.46,0.28,1})
    self.characterPanel=panel
    local side=CreateFrame("Frame",nil,panel,"BackdropTemplate")
    side:SetPoint("TOPLEFT",panel,"TOPLEFT",0,0)
    side:SetSize(245,512)
    paint(side,{0.018,0.036,0.066,0.99},{0.7,0.54,0.23,1})
    self.classPreviewButtons={}
    -- 13 class scene previews, NOT alternate player equipment or characters.
    for i,info in ipairs(GH.classListForPreview or {}) do end
    local data={
      {"WARRIOR","Warrior","Fury","Interface\\Icons\\Ability_Warrior_BattleShout"},
      {"PALADIN","Paladin","Holy","Interface\\Icons\\Spell_Holy_HolyBolt"},
      {"ROGUE","Rogue","Outlaw","Interface\\Icons\\Ability_BackStab"},
      {"MAGE","Mage","Fire","Interface\\Icons\\Spell_Fire_FireBall02"},
      {"WARLOCK","Warlock","Demonology","Interface\\Icons\\Spell_Shadow_DeathCoil"},
      {"HUNTER","Hunter","Beast Mastery","Interface\\Icons\\Ability_Hunter_BeastTaming"},
      {"PRIEST","Priest","Shadow","Interface\\Icons\\Spell_Holy_PowerWordShield"},
      {"DEMONHUNTER","Demon Hunter","Vengeance","Interface\\Icons\\ClassIcon_DemonHunter"},
      {"MONK","Monk","Windwalker","Interface\\Icons\\ClassIcon_Monk"},
      {"DRUID","Druid","Balance","Interface\\Icons\\Ability_Druid_Maul"},
      {"SHAMAN","Shaman","Enhancement","Interface\\Icons\\Spell_Nature_Lightning"},
      {"DEATHKNIGHT","Death Knight","Frost","Interface\\Icons\\Spell_Deathknight_ClassIcon"},
      {"EVOKER","Evoker","Devastation","Interface\\Icons\\ClassIcon_Evoker"},
    }
    for i,entry in ipairs(data) do
        local b=CreateFrame("Button",nil,side,"BackdropTemplate")
        b:SetPoint("TOPLEFT",side,"TOPLEFT",6,-4-(i-1)*39)
        b:SetSize(233,37)
        paint(b,{0.018,0.038,0.072,0.98},{0.35,0.49,0.62,1})
        local ico=b:CreateTexture(nil,"ARTWORK")
        ico:SetPoint("LEFT",b,"LEFT",7,0);ico:SetSize(30,30);ico:SetTexture(entry[4])
        local name=font(b,entry[2],"GameFontNormal")
        name:SetPoint("TOPLEFT",b,"TOPLEFT",45,-2);name:SetWidth(178);name:SetJustifyH("LEFT")
        name:SetTextColor(1,0.84,0.29,1)
        b.subtitle=font(b,entry[3],"GameFontNormalSmall")
        b.subtitle:SetPoint("TOPLEFT",b,"TOPLEFT",45,-19)
        b.subtitle:SetWidth(178);b.subtitle:SetJustifyH("LEFT")
        b.subtitle:SetTextColor(0.53,0.86,1.0,1)
        b.classKey=entry[1];b.specLabel=entry[3]
        b:SetScript("OnClick",function() GH:PreviewClassScene(entry[1]) end)
        b:SetScript("OnEnter",function() GameTooltip:SetOwner(b,"ANCHOR_RIGHT");GameTooltip:SetText("Preview "..entry[2].." background");GameTooltip:AddLine("Your live player and equipment stay unchanged.",1,1,1);GameTooltip:Show() end)
        b:SetScript("OnLeave",function() GameTooltip:Hide();GH:RefreshClassStage(select(2,UnitClass("player")),"",GH:GetCharacterLevel()) end)
        self.classPreviewButtons[#self.classPreviewButtons+1]=b
    end
    -- Large scenic rotating live player model, just like the approved render.
    local modelBack=CreateFrame("Frame",nil,panel,"BackdropTemplate")
    modelBack:SetPoint("TOPLEFT",panel,"TOPLEFT",252,-1)
    modelBack:SetSize(650,510)
    paint(modelBack,{0.03,0.048,0.073,0.99},{0.7,0.54,0.23,1})
    self.characterModelBack=modelBack
    local bg={}
    bg.scene=modelBack:CreateTexture(nil,"BACKGROUND",nil,1)
    bg.scene:SetPoint("TOPLEFT",modelBack,"TOPLEFT",2,-2)
    bg.scene:SetPoint("BOTTOMRIGHT",modelBack,"BOTTOMRIGHT",-2,2)
    bg.scene:SetTexCoord(0,1,0,1)
    self.characterBackground=bg
    local ok,model=pcall(CreateFrame,"PlayerModel",nil,modelBack)
    if ok and model then
        model:SetPoint("TOPLEFT",modelBack,"TOPLEFT",14,-14)
        model:SetPoint("BOTTOMRIGHT",modelBack,"BOTTOMRIGHT",-14,46)
        self.characterModel=model
        self.characterModelNeedsRefresh=true
        self.characterFacing=self.characterFacing or 0
        self:EnableCharacterRotation(model)
        if model.SetUnit then pcall(model.SetUnit,model,"player") end
        self:ApplyCharacterModelView()
        self:SetCharacterFacing(self.characterFacing)
    else
        local msg=font(modelBack,"Character model unavailable. Equipment selection still works.","GameFontNormal")
        msg:SetPoint("CENTER",modelBack,"CENTER")
    end
    local over=CreateFrame("Frame",nil,modelBack)
    over:SetAllPoints(modelBack)
    over:SetFrameLevel((model and model.GetFrameLevel and model:GetFrameLevel() or modelBack:GetFrameLevel())+4)
    self.sceneIndicator=font(over,"","GameFontNormalSmall")
    self.sceneIndicator:SetPoint("TOPRIGHT",over,"TOPRIGHT",-11,-9)
    self.sceneIndicator:SetWidth(320);self.sceneIndicator:SetJustifyH("RIGHT")
    self.sceneIndicator:SetTextColor(0.94,0.92,0.72,1)
    self.scenePreviewNotice=font(over,"LIVE CHARACTER - DRAG TO ROTATE","GameFontNormalSmall")
    self.scenePreviewNotice:SetPoint("BOTTOMLEFT",over,"BOTTOMLEFT",10,10)
    self.scenePreviewNotice:SetWidth(440);self.scenePreviewNotice:SetJustifyH("LEFT")
    self.scenePreviewNotice:SetTextColor(1,0.80,0.36,1)
    self.characterName=self.scenePreviewNotice
    local function viewButton(t,x,w,cb)
        local b=CreateFrame("Button",nil,modelBack,"BackdropTemplate")
        b:SetPoint("BOTTOMRIGHT",modelBack,"BOTTOMRIGHT",x,8)
        b:SetSize(w,32)
        paint(b,{0.012,0.035,0.067,0.99},{0.58,0.75,0.95,1})
        b:SetFrameLevel((model and model.GetFrameLevel and model:GetFrameLevel() or modelBack:GetFrameLevel())+5)
        local txt=font(b,t,"GameFontNormal")
        txt:SetAllPoints();txt:SetJustifyH("CENTER");txt:SetTextColor(1,1,1,1)
        b:SetScript("OnClick",cb)
        return b
    end
    self.rotateLeftButton=viewButton("<",-175,38,function() GH:RotateCharacter(-math.pi/8) end)
    self.rotateRightButton=viewButton(">",-133,38,function() GH:RotateCharacter(math.pi/8) end)
    self.resetViewButton=viewButton("RESET",-8,120,function() GH:ResetCharacterFacing() end)

    -- Sixteen equipped slots next to the model; no mock numbers or icons.
    self.characterSlots={}
    for i,info in ipairs(GH.slotDefs) do
        local id=info.id
        local row=CreateFrame("Button",nil,panel,"BackdropTemplate")
        row:SetPoint("TOPLEFT",panel,"TOPLEFT",908,-2-(i-1)*31.7)
        row:SetSize(254,31)
        paint(row,{0.018,0.045,0.074,0.99},{0.37,0.50,0.63,1})
        row.slotID=id
        row.icon=row:CreateTexture(nil,"ARTWORK")
        row.icon:SetSize(28,28);row.icon:SetPoint("RIGHT",row,"RIGHT",-4,0)
        row.upgradeIcon=row:CreateTexture(nil,"ARTWORK")
        row.upgradeIcon:SetSize(28,28);row.upgradeIcon:SetPoint("LEFT",row,"LEFT",5,0)
        row.upgradeArrow=row:CreateTexture(nil,"OVERLAY")
        row.upgradeArrow:SetTexture("Interface\\AddOns\\GearHunter\\Art\\UIIcons\\upgrade-arrow.tga")
        row.upgradeArrow:SetSize(14,14)
        row.upgradeArrow:SetPoint("TOPRIGHT",row.upgradeIcon,"TOPRIGHT",3,3)
        row.upgradeArrow:Hide()
        row.title=font(row,info.name,"GameFontNormalSmall")
        row.title:SetPoint("TOPLEFT",row,"TOPLEFT",40,-2)
        row.title:SetWidth(172);row.title:SetJustifyH("LEFT")
        row.title:SetTextColor(1,0.84,0.30,1)
        row.info=font(row,"","GameFontNormalSmall")
        row.info:SetPoint("TOPLEFT",row,"TOPLEFT",40,-16)
        row.info:SetWidth(172);row.info:SetJustifyH("LEFT")
        row.info:SetTextColor(0.22,1.0,0.48,1)
        row:SetScript("OnEnter",function(self)
            self:SetBackdropBorderColor(1,0.83,0.31,1)
            GH:ShowEquipmentUpgradeTooltip(self,self.slotID,false)
        end)
        row:SetScript("OnLeave",function(self)
            self:SetBackdropBorderColor(0.37,0.50,0.63,1)
            GameTooltip:Hide()
        end)
        row:SetScript("OnClick",function(self) GH:OpenSlotUpgrades(self.slotID) end)
        table.insert(self.characterSlots,row)
    end
    panel:Hide()
end
function GH:RefreshCharacterPanel()
    if not self.characterSlots then return end
    for _,button in ipairs(self.characterSlots) do
        local worn=self.equipped[button.slotID]
        button.icon:SetTexture(self:GetDisplayItemIcon(worn))
        local ownLevel=worn and worn.level and worn.level>0 and worn.level or nil
        local candidates=self:GetSlotUpgradeList(button.slotID)
        local first=candidates[1]
        local gain=first and self:Gain(first)
        local hasUpgrade=first and type(gain)=="number" and gain>=1
        if button.upgradeIcon then
            if hasUpgrade then
                button.upgradeIcon:SetTexture(self:GetDisplayItemIcon(first))
                button.upgradeIcon:Show()
            else
                button.upgradeIcon:Hide()
            end
        end
        if button.upgradeArrow then button.upgradeArrow:SetShown(not not hasUpgrade) end
        local levelLabel=ownLevel and "iLvl "..ownLevel or "Empty"
        if gain and gain>=1 then
            button.info:SetText(levelLabel.."  |cFF55FF77+"..gain.."|r")
        else
            button.info:SetText(levelLabel)
        end
    end
    -- scenePreviewNotice is set in RefreshClassStage so preview text is preserved.
    -- Loot scans call Refresh frequently. Only reload the 3D model when gear
    -- actually changed; every reload restores the player's chosen facing.
    if self.characterModel and self.characterPanel:IsShown() and self.characterModelNeedsRefresh then
        if self.characterModel.SetUnit then
            pcall(self.characterModel.SetUnit,self.characterModel,"player")
        end
        self:ApplyCharacterModelView()
        self.characterModelNeedsRefresh=false
        self:SetCharacterFacing(self.characterFacing or 0)
    end
    self:UpdateCharacterBackground()
end

local nativeSlotNames={
    [1]="CharacterHeadSlot", [2]="CharacterNeckSlot",[3]="CharacterShoulderSlot",
    [15]="CharacterBackSlot", [5]="CharacterChestSlot",[9]="CharacterWristSlot",
    [10]="CharacterHandsSlot", [6]="CharacterWaistSlot",[7]="CharacterLegsSlot",
    [8]="CharacterFeetSlot", [11]="CharacterFinger0Slot",[12]="CharacterFinger1Slot",
    [13]="CharacterTrinket0Slot",[14]="CharacterTrinket1Slot",
    [16]="CharacterMainHandSlot",[17]="CharacterSecondaryHandSlot",
}
function GH:AttachPaperDoll()
    for slotID,name in pairs(nativeSlotNames) do
        local original=_G[name]
        if original and not (self.nativeSlotHooked and self.nativeSlotHooked[name]) and original.HookScript then
            self.nativeSlotHooked=self.nativeSlotHooked or {}
            self.nativeSlotHooked[name]=true
            original:HookScript("OnEnter",function(self)
                if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then
                    GH:ShowEquipmentUpgradeTooltip(self,slotID,true)
                end
            end)
            local small=CreateFrame("Button",nil,original,"BackdropTemplate")
            small:SetSize(23,22)
            local rightColumn=slotID==7 or slotID==8 or slotID==11 or slotID==12
                or slotID==13 or slotID==14 or slotID==16 or slotID==17
            if rightColumn then small:SetPoint("RIGHT",original,"LEFT",-1,0)
            else small:SetPoint("LEFT",original,"RIGHT",1,0) end
            small:SetFrameLevel(original:GetFrameLevel()+5)
            paint(small,{0.4,0.05,0.06,0.95},gold)
            local text=font(small,"GH","GameFontNormalSmall")
            text:SetAllPoints();text:SetJustifyH("CENTER")
            text:SetTextColor(1,1,1)
            small:SetScript("OnEnter",function(self)
                GH:ShowEquipmentUpgradeTooltip(self,slotID,false)
            end)
            small:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
            small:SetScript("OnClick",function() GH:OpenSlotUpgrades(slotID) end)
        end
    end
end
local nativeWatcher=CreateFrame("Frame")
nativeWatcher:RegisterEvent("PLAYER_LOGIN")
nativeWatcher:RegisterEvent("ADDON_LOADED")
nativeWatcher:SetScript("OnEvent",function(_,event,loaded)
    if event=="PLAYER_LOGIN" or loaded=="Blizzard_CharacterUI" then
        GH:AttachPaperDoll()
        if CharacterFrame and not GH.characterFrameHooked and CharacterFrame.HookScript then
            GH.characterFrameHooked=true
            CharacterFrame:HookScript("OnShow",function()
                GH:AttachPaperDoll()
                if GH.db then GH:ScanEquipped() end
            end)
        end
    end
end)
