local ADDON, GHN = ...
-- Gear Hunter Navigator 0.4.7: unified progress pages and collection layout correction; the
-- approved three-column reference. No external artwork, web requests or automation.
-- Every text object is parented to its visible panel (not behind a sibling frame).
local BASE = "Interface\\AddOns\\GearHunterNavigator\\Art\\UIIcons\\"
local SCENES = "Interface\\AddOns\\GearHunterNavigator\\Art\\Scenes\\"
local FRAMES = "Interface\\AddOns\\GearHunterNavigator\\Art\\Frames\\"
local FONT = "Fonts\\FRIZQT__.TTF"
local C = {
  gold={1,.79,.36}, white={.96,.96,.98}, silver={.82,.86,.92}, dim={.67,.75,.85},
  blue={.28,.70,1}, green={.43,.95,.55}, pink={1,.45,.94}, warn={1,.72,.36},
  bg={.018,.034,.056,.982}, panel={.029,.053,.079,.98}, deep={.016,.034,.055,.96},
  highlight={.052,.17,.31,.99}, subtle={.07,.11,.16,.99},
}
local function Color(f, rgb) f:SetTextColor(rgb[1],rgb[2],rgb[3],1) end
local function NewPanel(parent,x,y,w,h,rgb,border,name)
  local p=CreateFrame("Frame",name,parent,"BackdropTemplate")
  p:SetSize(w,h); p:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
  p:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=false,edgeSize=14,
     insets={left=3,right=3,top=3,bottom=3}})
  local b=rgb or C.panel
  p:SetBackdropColor(b[1],b[2],b[3],b[4] or 1)
  local e=border or {.42,.49,.53,.83}
  p:SetBackdropBorderColor(e[1],e[2],e[3],e[4] or 1)
  return p
end
local function Txt(parent,text,x,y,w,h,size,color,wrap)
  local t=parent:CreateFontString(nil,"OVERLAY")
  t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); t:SetSize(w,h)
  t:SetFont(FONT,size or 13,"")
  t:SetJustifyH("LEFT");t:SetJustifyV("TOP");t:SetWordWrap(wrap ~= false)
  t:SetShadowColor(0,0,0,1);t:SetShadowOffset(1,-1)
  t:SetText(text or "");Color(t,color or C.white)
  return t
end
local function Button(parent,label,x,y,w,h,callback,style)
  style=style or "blue"
  local btn=CreateFrame("Button",nil,parent)
  btn:SetSize(w,h);btn:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
  local rgb=(style=="dark") and {.065,.105,.155,.98} or
    (style=="gold" and {.30,.17,.065,.98} or {.045,.24,.46,.98})
  local hover=(style=="dark") and {.12,.23,.33,.98} or {.075,.38,.65,.99}
  btn.bg=btn:CreateTexture(nil,"BACKGROUND")
  btn.bg:SetAllPoints();btn.bg:SetColorTexture(unpack(rgb))
  local border=btn:CreateTexture(nil,"BORDER")
  border:SetColorTexture(.14,.43,.71,.68);border:SetHeight(1)
  border:SetPoint("BOTTOMLEFT",btn,"BOTTOMLEFT",2,1);border:SetPoint("BOTTOMRIGHT",btn,"BOTTOMRIGHT",-2,1)
  btn.caption=Txt(btn,label,7,-5,w-14,h-7,13,C.white,true)
  btn.caption:SetJustifyH("CENTER");btn.caption:SetJustifyV("MIDDLE")
  btn:SetScript("OnEnter",function()btn.bg:SetColorTexture(unpack(hover))end)
  btn:SetScript("OnLeave",function()btn:SetTone(btn.tone)end)
  btn:SetScript("OnClick",function()
    if callback then GHN:Safe("UI: "..tostring(label),callback) end
  end)
  function btn:SetLabel(s) self.caption:SetText(s or "") end
  function btn:SetTone(s)
    self.tone=s
    if s=="selected" then self.bg:SetColorTexture(.065,.32,.61,.99)
    elseif s=="done" then self.bg:SetColorTexture(.055,.23,.16,.99)
    else self.bg:SetColorTexture(unpack(rgb))end
  end
  return btn
end
local function Image(parent,path,x,y,w,h)
  local t=parent:CreateTexture(nil,"ARTWORK")
  t:SetSize(w,h);t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
  t:SetTexture(path)
  return t
end
-- The exact carved blue-and-gold Midnight frame used by original Gear Hunter.
-- This is a *real game texture*, not an image of the user interface. The
-- transparent center leaves all Navigator content, buttons and live data intact.
local ORIGINAL_GEAR_FRAME = "Interface\\AddOns\\GearHunterNavigator\\Art\\OriginalGearHunter\\Frames\\"
local function ApplyNavigatorMidnightFrame(screen, root)
  -- Glow behind the controls, matching the original Gear Hunter treatment.
  local halo=screen:CreateTexture(nil,"BACKGROUND",nil,-4)
  halo:SetPoint("TOPLEFT",root,"TOPLEFT",-12,12)
  halo:SetPoint("BOTTOMRIGHT",root,"BOTTOMRIGHT",12,-12)
  halo:SetTexture(ORIGINAL_GEAR_FRAME.."ReferenceBlueGlow.tga")
  halo:SetBlendMode("ADD")
  halo:SetVertexColor(0.58,0.84,1,0.62)

  -- The art must be ABOVE Navigator's panel backdrops, or its thin carved
  -- perimeter vanishes beneath them. But it stays BELOW the original Gear
  -- Hunter full-size page (parent screen level +8) when that page is open.
  local trim=CreateFrame("Frame",nil,screen)
  trim:SetAllPoints(root)
  trim:SetFrameStrata("HIGH")
  trim:SetFrameLevel((screen:GetFrameLevel() or 0)+7)
  trim:EnableMouse(false) -- decorative art must never intercept clicks
  local edge=trim:CreateTexture(nil,"OVERLAY")
  edge:SetAllPoints(trim)
  edge:SetTexture(ORIGINAL_GEAR_FRAME.."ReferenceOrnateBorder.tga")
  edge:SetVertexColor(1,1,1,1)
  -- Same soft halo pulse as the original Gear Hunter, without moving the
  -- border, model, buttons or the content layout.
  local phase=0
  trim:SetScript("OnUpdate",function(_,elapsed)
    phase=phase+(elapsed or 0)
    if phase>100000 then phase=0 end
    halo:SetAlpha(0.78+0.17*math.sin(phase*1.8))
  end)
  return trim,edge,halo
end
-- The actual high-resolution, individually painted Gear Hunter scene for the
-- player's specialization and faction. Never substitute a recolored image.
local CLASS_DEFAULT_SPEC = {
 WARRIOR=71,PALADIN=70,HUNTER=254,ROGUE=260,PRIEST=258,
 DEATHKNIGHT=251,SHAMAN=262,MAGE=62,WARLOCK=266,MONK=269,
 DRUID=102,DEMONHUNTER=577,EVOKER=1467,
}
local CLASS_FRAME = {
 DEMONHUNTER="MidnightOrnateFel.blp",WARLOCK="MidnightOrnateFel.blp",
 PRIEST="MidnightOrnateVoid.blp",MAGE="MidnightOrnateVoid.blp",
 PALADIN="MidnightOrnateHoly.blp",EVOKER="MidnightOrnateHoly.blp",
 WARRIOR="MidnightOrnateSteel.blp",DEATHKNIGHT="MidnightOrnateSteel.blp",
}
local function CurrentScene()
 local class=UnitClass and select(2,UnitClass("player")) or nil
 local faction=UnitFactionGroup and UnitFactionGroup("player") or nil
 if not class or (faction~="Alliance" and faction~="Horde")then return nil,nil,nil end
 local idx=GetSpecialization and GetSpecialization()
 local specID=idx and GetSpecializationInfo and select(1,GetSpecializationInfo(idx)) or nil
 if not specID then specID=CLASS_DEFAULT_SPEC[class] end
 if not specID then return nil,nil,nil end
 return SCENES..specID.."\\"..faction..".blp",FRAMES..(CLASS_FRAME[class] or "MidnightOrnateSteel.blp"),tostring(specID).." / "..faction
end
local TWO_PI=math.pi*2
function GHN:SetCharacterFacing(angle)
 local m=self.characterModel
 if not m or type(angle)~="number"then return end
 self.characterFacing=angle%TWO_PI
 if m.SetFacing then
   local ok=pcall(m.SetFacing,m,self.characterFacing)
   if ok then return end
 end
 if m.SetRotation then pcall(m.SetRotation,m,self.characterFacing,false)end
end
-- The podium is part of the (unchanged) painted scene. Its center is at
-- 50% horizontal and about 84% down the stage. Keep a bottom-anchored 3-D
-- viewport there; zooming must NEVER modify SetPosition's ground-height z.
local PODIUM_RATIO = .84
function GHN:PlaceCharacterAtPodium()
 local m,stage=self.characterModel,self.characterStage
 if not m or not stage then return end
 local adjustment=self.db and tonumber(self.db.characterGroundAdjustment) or 0
 adjustment=math.max(-35,math.min(35,adjustment))
 local y=stage:GetHeight()*PODIUM_RATIO+adjustment
 m:ClearAllPoints()
 m:SetSize(stage:GetWidth()-32,stage:GetHeight()*.80)
 m:SetPoint("BOTTOM",stage,"TOP",0,-y)
 -- Frame bottom is always pinned to the painted circle; this adjustment is
 -- independent of camera/model size and can be calibrated for a race if needed.
end
function GHN:ApplyCharacterCamera()
 local m=self.characterModel
 if not m then return end
 local zoom=self.db and tonumber(self.db.characterCamScale) or .95
 zoom=math.max(.70,math.min(1.70,zoom))
 if self.db then self.db.characterCamScale=zoom end
 self:PlaceCharacterAtPodium()
 -- World position z=0 is the model's floor/root; it no longer follows zoom.
 if m.SetPosition then pcall(m.SetPosition,m,0,0,0) end
 if m.SetPortraitZoom then pcall(m.SetPortraitZoom,m,0) end
 -- Scale mesh about its origin (feet) on clients with SetModelScale; otherwise
 -- change camera distance while keeping the same grounded viewport anchor.
 local meshScaled=false
 if m.SetModelScale then meshScaled=pcall(m.SetModelScale,m,1/zoom) end
 if meshScaled then
   if m.SetCamDistanceScale then pcall(m.SetCamDistanceScale,m,1) end
 elseif m.SetCamDistanceScale then
   pcall(m.SetCamDistanceScale,m,zoom)
 end
 if m.RefreshCamera then pcall(m.RefreshCamera,m) end
 if self.characterViewSettings then
   self.characterViewSettings:SetText(string.format("Size: %.0f%%   Feet anchored to podium   Alignment: %+d px",100/zoom,math.floor((self.db.characterGroundAdjustment or 0)+.5)))
 end
end
function GHN:AdjustCharacterCamera(sizeDelta,groundDelta)
 if not self.db then return end
 local size=tonumber(self.db.characterCamScale) or .95
 self.db.characterCamScale=math.max(.70,math.min(1.70,size+(sizeDelta or 0)))
 local ground=tonumber(self.db.characterGroundAdjustment) or 0
 self.db.characterGroundAdjustment=math.max(-35,math.min(35,ground+(groundDelta or 0)))
 self:ApplyCharacterCamera()
end
function GHN:RefreshCharacterStage(force)
 if not self.characterScene or not self.db then return end
 local scene,frame,desc=CurrentScene()
 if not scene then
   if self.characterStageStatus then self.characterStageStatus:SetText("Waiting for class, specialization and faction data.")end
   return
 end
 if force or self.characterScenePath~=scene then
  self.characterScenePath=scene
  self.characterScene:SetTexture(scene)
  self.characterOrnateFrame:SetTexture(frame)
  if self.characterStageStatus then self.characterStageStatus:SetText("Original high-resolution Gear Hunter scene: "..desc)end
 end
 if self.characterModel and (force or self.characterModelNeedsRefresh) then
   self.characterModelNeedsRefresh=false
   local m=self.characterModel
   -- A DressUpModel can render the unit's worn equipment. Plain PlayerModel
   -- remains a compatibility fallback for clients without DressUpModel.
   -- All calls are guarded because availability differs between WoW builds.
   if m.SetAutoDress then pcall(m.SetAutoDress,m,true) end
   local loaded=false
   if m.SetUnit then
     local ok,result=pcall(m.SetUnit,m,"player")
     loaded=ok and result~=false
   end
   if loaded then
     if m.RefreshUnit then pcall(m.RefreshUnit,m) end
     if m.Dress then pcall(m.Dress,m) end
   else
     self:Log("MODEL","Unable to display player model; equipped slot icons are still available.")
   end
   self:ApplyCharacterCamera()
   self:SetCharacterFacing(self.characterFacing or 0)
 end
 if self.RefreshCharacterEquipment then self:RefreshCharacterEquipment() end
end
-- True equipped inventory paper-doll icons (not sample/imaginary upgrades).
-- Kept separate from the 3D model so links, tooltips and slots remain useful
-- even on WoW clients that cannot currently draw the 3D worn appearance.
local PAPER_DOLL_SLOTS={
 {1,"Head"},{2,"Neck"},{3,"Shoulders"},{15,"Back"},
 {5,"Chest"},{9,"Wrists"},{10,"Hands"},{6,"Waist"},
 {7,"Legs"},{8,"Feet"},{11,"Ring 1"},{12,"Ring 2"},
 {13,"Trinket 1"},{14,"Trinket 2"},{16,"Main Hand"},{17,"Off Hand"},
}
function GHN:RefreshCharacterEquipment()
 if not self.characterEquipmentSlots then return end
 local equipped=0
 for _,b in ipairs(self.characterEquipmentSlots) do
   local icon=nil
   if GetInventoryItemTexture then
     local ok,value=pcall(GetInventoryItemTexture,"player",b.slotID)
     if ok then icon=value end
   end
   if icon then
     equipped=equipped+1
     b.icon:SetTexture(icon)
     b.icon:SetDesaturated(false)
     b.icon:SetAlpha(1)
     b.slotMarker:Hide()
   else
     b.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
     b.icon:SetDesaturated(true)
     b.icon:SetAlpha(.34)
     b.slotMarker:Show()
   end
 end
 if self.characterGearSummary then
   self.characterGearSummary:SetText("Equipped slots: "..equipped.." / "..#self.characterEquipmentSlots.."   |   Hover a slot for its item")
 end
end
local function Count(t)
  local n=0
  for _ in pairs(t or {})do n=n+1 end
  return n
end
local function GetMount(id)
  if not id or not(C_MountJournal and C_MountJournal.GetMountInfoByID)then return nil end
  GHN.mountCache=GHN.mountCache or {}
  if GHN.mountCache[id] then return GHN.mountCache[id] end
  local ok,name,_,icon,_,_,sourceType,_,_,_,_,collected=pcall(C_MountJournal.GetMountInfoByID,id)
  if not ok or not name then return nil end
  local description,source
  if C_MountJournal.GetMountInfoExtraByID then
    local good,_,desc,src=pcall(C_MountJournal.GetMountInfoExtraByID,id)
    if good then description=desc;source=src end
  end
  local m={id=id,name=name,icon=icon,collected=collected==true,description=description,source=source,sourceType=sourceType}
  GHN.mountCache[id]=m
  return m
end
local function MountSource(m)
  return GHN:MountSourceText(m)
end
local function FallbackSteps(m)
  if not m then return {} end
  return {
    "Read "..m.name.." in the Mount Journal.",
    "Review journal source: "..MountSource(m):sub(1,66),
    "Check required unlocks, access, and character eligibility.",
    "Follow the source using in-game quests, journals or maps.",
    "Check the Mount Journal to verify collection."
  }
end
local function PickAshes()
  if not (C_MountJournal and C_MountJournal.GetMountIDs) then return nil end
  local ok,ids=pcall(C_MountJournal.GetMountIDs)
  if not ok or type(ids)~="table" then return nil end
  for _,id in ipairs(ids)do
    local m=GetMount(id)
    if m and m.name:lower()=="ashes of al'ar" then return id end
  end
end

-- Render a real, stitched Blizzard map tile preview when the client exposes art.
-- Any failure leaves a truthful placeholder and an always-available native map button.
function GHN:ShowMapPreview(mapID,x,y)
  if not self.mapCanvas then return end
  self.mapTiles=self.mapTiles or {}
  for _,tile in ipairs(self.mapTiles) do tile:Hide() end
  if self.mapPin then self.mapPin:Hide() end
  if self.mapHint then self.mapHint:SetText("Loading zone map artwork...") end
  if not (mapID and C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then
    if self.mapHint then self.mapHint:SetText("Map artwork API unavailable.") end
    return
  end
  local function draw(id)
    local ok,layers=pcall(C_Map.GetMapArtLayers,id)
    if not ok or type(layers)~="table" then return false end
    for i,layer in ipairs(layers) do
      local width,height=tonumber(layer.layerWidth),tonumber(layer.layerHeight)
      local tw,th=tonumber(layer.tileWidth),tonumber(layer.tileHeight)
      if width and height and tw and th and width>0 and height>0 and tw>0 and th>0 then
        local cols,rows=math.ceil(width/tw),math.ceil(height/th)
        if cols>0 and rows>0 and cols*rows<=160 then
          for _,index in ipairs({i-1,i}) do
            local good,files=pcall(C_Map.GetMapArtLayerTextures,id,index)
            if good and type(files)=="table" then
              local count=0
              for j=1,cols*rows do
                local file=files[j]
                if (type(file)=="number" and file>0) or (type(file)=="string" and file~="") then count=count+1 end
              end
              if count>0 then
                for j=1,cols*rows do
                  local file=files[j]
                  if (type(file)=="number" and file>0) or (type(file)=="string" and file~="") then
                    local tile=self.mapTiles[j]
                    if not tile then tile=self.mapCanvas:CreateTexture(nil,"BACKGROUND",nil,1);self.mapTiles[j]=tile end
                    local col,row=(j-1)%cols,math.floor((j-1)/cols)
                    local edgeW=math.min(tw,width-col*tw)
                    local edgeH=math.min(th,height-row*th)
                    tile:ClearAllPoints()
                    tile:SetPoint("TOPLEFT",self.mapCanvas,"TOPLEFT",col*tw/width*342,-row*th/height*194)
                    tile:SetSize(edgeW/width*342+.2,edgeH/height*194+.2)
                    tile:SetTexCoord(0,edgeW/tw,0,edgeH/th)
                    tile:SetTexture(file)
                    tile:Show()
                  end
                end
                if self.mapHint then self.mapHint:SetText("") end
                return true
              end
            end
          end
        end
      end
    end
    return false
  end
  local current=mapID
  for _=1,5 do
    if draw(current) then
      if current==mapID and self.mapPin and x and y and x>=0 and x<=1 and y>=0 and y<=1 then
        self.mapPin:ClearAllPoints()
        self.mapPin:SetPoint("CENTER",self.mapCanvas,"TOPLEFT",342*x,-194*y)
        self.mapPin:Show()
      end
      return
    end
    if not C_Map.GetMapInfo then break end
    local ok,info=pcall(C_Map.GetMapInfo,current)
    if not ok or not info or not info.parentMapID or info.parentMapID==0 or info.parentMapID==current then break end
    current=info.parentMapID
  end
  if self.mapHint then self.mapHint:SetText("Map art unavailable for zone "..tostring(mapID)..". Open WoW map below.") end
end
function GHN:SelectedGuide()
  self.currentMount=GetMount(self.db and self.db.mountID)
  self.currentGuide=self.currentMount and self:GetMountGuide(self.currentMount.name,self.currentMount) or nil
  return self.currentMount,self.currentGuide
end
function GHN:NextGuideStep()
  local g=self.currentGuide
  if not g then return 1 end
  local done=self:GuideSteps(g)
  for i=1,#g.steps do if not done[i]then return i end end
  return #g.steps
end
function GHN:Select(tab)
  if not self.db then return end
  if not self.pages[tab]then tab="Mounts" end
  if tab~="Gear Hunter" then self.lastNonGearTab=tab end
  if tab=="Leveling" then self.levelMapKey=nil end
  if self.db.tab=="Leveling" and tab~="Leveling" then self.lastPreviewMap=nil end
  if self.db.tab=="Gear" and tab~="Gear" then self.lastPreviewMap=nil end
  self.db.tab=tab
  if self.mainCenter and self.mainRight then
    self.mainCenter:SetWidth((tab=="Character" or tab=="Gear Hunter" or tab=="Quests" or tab=="Reputation" or tab=="Collections") and 1102 or 716)
    self.mainRight:SetShown(tab~="Character" and tab~="Gear Hunter" and tab~="Quests" and tab~="Reputation" and tab~="Collections")
  end
  for name,p in pairs(self.pages)do if name==tab then p:Show()else p:Hide()end end
  if self.navigatorDiscoveryLegend then self.navigatorDiscoveryLegend:SetShown(tab=="Map") end
  if self.levelCoachPanel then self.levelCoachPanel:SetShown(tab=="Leveling") end
  if self.mapWaypointButton then self.mapWaypointButton:SetShown(tab~="Leveling") end
  if self.mapOpenButton and self.mapLocation then
    self.mapOpenButton:ClearAllPoints()
    self.mapOpenButton:SetPoint("TOPLEFT",self.mapLocation:GetParent(),"TOPLEFT",tab=="Leveling" and 11 or 181,-24)
    self.mapOpenButton:SetWidth(tab=="Leveling" and 330 or 159)
  end
  if tab=="Gear Hunter" then
    if self.ShowOriginalGearHunter then self:ShowOriginalGearHunter() end
  else
    if self.HideOriginalGearHunter then self:HideOriginalGearHunter() end
  end
  if tab=="Character"then
    self.characterModelNeedsRefresh=true
    self:RefreshCharacterStage(true)
  end
  for name,b in pairs(self.nav)do b:SetTone(name==tab and "selected" or nil)end
  if self.sectionTitle then self.sectionTitle:SetText(tab)end
  self:Refresh()
end
function GHN:OpenChooser()
  self.chooser:SetShown(not self.chooser:IsShown())
  if self.chooser:IsShown()then self.searchBox:SetFocus();self:RefreshChooser()end
end
function GHN:RefreshChooser()
  if not self.chooser or not self.chooser:IsShown()then return end
  local q=(self.searchBox:GetText() or ""):lower():match("^%s*(.-)%s*$")
  local onlyMissing=self.chooserMissingOnly==true
  local onlyCurated=self.chooserGuidesOnly==true
  local all,complete={},0
  if C_MountJournal and C_MountJournal.GetMountIDs then
    local ok,ids=pcall(C_MountJournal.GetMountIDs)
    if ok and type(ids)=="table"then
      complete=#ids
      for _,id in ipairs(ids)do
        local m=GetMount(id)
        if m and (not onlyMissing or not m.collected) then
          local curated=self.Guides[(m.name or ""):lower()]~=nil
          if not onlyCurated or curated then
            local entry=curated and self.Guides[m.name:lower()] or nil
            local extra=entry and ((entry.source or "").." "..(entry.mapName or "").." "..(entry.requirements or "")) or ""
            local searchData=(m.name.." "..MountSource(m).." "..(m.description or "").." "..self:MountSourceGroup(m).." "..extra):lower()
            if q=="" or searchData:find(q,1,true) then all[#all+1]=m end
          end
        end
      end
    end
  end
  table.sort(all,function(a,b)
    -- Missing mounts first for a collection goal; alphabetic within each group.
    if a.collected~=b.collected then return not a.collected end
    return a.name:lower()<b.name:lower()
  end)
  self.mountResults=all
  local perPage=#self.chooserRows
  local pages=math.max(1,math.ceil(#all/perPage))
  self.chooserPage=math.min(math.max(1,self.chooserPage or 1),pages)
  self.chooserCount:SetText(string.format("%d matches / %d journal IDs  |  page %d/%d",#all,complete,self.chooserPage,pages))
  for i,b in ipairs(self.chooserRows)do
    local m=all[(self.chooserPage-1)*perPage+i]
    b.mountID=m and m.id or nil
    if m then
      local kind=self:MountSourceGroup(m)
      local short=m.name
      if #short>38 then short=short:sub(1,35).."..." end
      b:SetLabel((m.collected and "[OWNED]  " or "[MISSING] ")..short.."  ("..kind..")")
    else
      b:SetLabel("")
    end
    b:SetShown(m~=nil)
  end
end
function GHN:PickMount(id)
  local m=GetMount(id)
  if not m then return end
  self:ChooseMount(id,m.name)
  self:CheckCollectedGoal()
  self.chooser:Hide()
  self.selectedStep=nil
  self.guideTab="Steps"
  self:Select("Mounts")
end
function GHN:UpdateGuideTabs()
  for key,b in pairs(self.guideTabs or {})do b:SetTone((self.guideTab or "Steps")==key and "selected" or nil)end
  if not self.mountBodies then return end
  for key,p in pairs(self.mountBodies)do p:SetShown(key==(self.guideTab or "Steps"))end
end
function GHN:ShowHelp()
  local m,g=self:SelectedGuide()
  if not m then
    self.helpAnswer:SetText("Choose a mount first to get source-specific help.")
    return
  end
  local source=MountSource(m)
  local choice=self.helpIssue or 1
  local step=math.max(1,math.min(self.selectedStep or self:NextGuideStep(),#g.steps))
  local msg
  if choice==1 then
    if g.mapID and g.mapName then
      msg=m.name..": "..(g.tips[3] or g.tips[2] or source)
    else
      msg=m.name..": "..(g.tips[2] or "Review the source in the Mount Journal.").." No verified entrance waypoint is available."
    end
  elseif choice==2 then
    msg=m.name..": "..(g.mapName and ("Destination region: "..g.mapName..". ") or "")..(g.tips[2] or source).." Use routes that your character has unlocked."
  elseif choice==3 then
    msg=m.name..": "..(g.tips[step] or "Check access, eligibility, and required objectives.")
  else
    msg=m.collected and (m.name.." is already collected, according to your Mount Journal.") or
      (m.name..": Source: "..source..". If chance-based, a successful attempt does not guarantee a mount. Check your journal and lockout.")
  end
  self.helpAnswer:SetText(msg)
end
function GHN:RenderGear()
  if not self.gearLines then return end
  local slots={{1,"Head"},{2,"Neck"},{3,"Shoulder"},{5,"Chest"},{6,"Waist"},{7,"Legs"},{8,"Feet"},
               {9,"Wrist"},{10,"Hands"},{11,"Ring 1"},{12,"Ring 2"},{13,"Trinket 1"},{14,"Trinket 2"},
               {15,"Back"},{16,"Main Hand"},{17,"Off Hand"}}
  for i,slot in ipairs(slots)do
    local label=slot[2].."  -  Empty"
    local ok,link=pcall(function()return GetInventoryItemLink and GetInventoryItemLink("player",slot[1])end)
    if ok and type(link)=="string"then
      local name=link:match("%[(.-)%]") or "Equipped item"
      local ilevel
      if GetDetailedItemLevelInfo then local yes,n=pcall(GetDetailedItemLevelInfo,link);if yes and type(n)=="number"then ilevel=n end end
      -- A two-line slot display leaves more width for real item names.
      if #name>38 then name=name:sub(1,37).."..."end
      label=slot[2].."  |  "..(ilevel and ("iLvl "..ilevel) or "Equipped").."\n"..name
    else
      label=slot[2].."  |  Empty"
    end
    if self.gearTooltips and self.gearTooltips[i] then self.gearTooltips[i].slotID=slot[1] end
    self.gearLines[i]:SetText(label)
  end
end

-- Gear upgrades are possible item-level improvements from bags the character
-- already owns. A +1 iLvl candidate is included, but is never called BiS.
function GHN:SetGearView(view)
  self.gearView=view=="Equipped" and "Equipped" or "Upgrades"
  if self.gearEquippedPane then self.gearEquippedPane:SetShown(self.gearView=="Equipped") end
  if self.gearUpgradesPane then self.gearUpgradesPane:SetShown(self.gearView=="Upgrades") end
  if self.gearShowEquipped then self.gearShowEquipped:SetTone(self.gearView=="Equipped" and "selected" or nil)end
  if self.gearShowUpgrades then self.gearShowUpgrades:SetTone(self.gearView=="Upgrades" and "selected" or nil)end
  if self.gearTierButton then self.gearTierButton:SetShown(self.gearView=="Upgrades" and self.gearSource=="journal") end
  if self.gearKindButton then self.gearKindButton:SetShown(self.gearView=="Upgrades" and self.gearSource=="journal") end
  if self.gearDifficultyButton then self.gearDifficultyButton:SetShown(self.gearView=="Upgrades" and self.gearSource=="journal") end
  self:Refresh()
end
function GHN:RenderGearUpgrades()
  if not self.gearUpgradeRows then return end
  local journal=self.gearSource=="journal"
  if not journal and (not self.gearScan or self.gearScanDirty) then self:ScanBagUpgrades() end
  local data=journal and self.journalScan or self.gearScan
  if not data then return end
  local n=#data.results
  local pages=math.max(1,math.ceil(n/6))
  self.gearUpgradePage=math.min(math.max(1,self.gearUpgradePage or 1),pages)
  if journal then
    self.gearScanSummary:SetText(string.format("%s | %d leads | %d/%d sources | %d drops | %d unknown | page %d/%d",
      data.busy and "SCANNING" or (data.status=="" and "READY" or "COMPLETE"),
      n,data.instancesScanned or 0,#(data.instances or {}),data.lootRead or 0,data.unknown or 0,self.gearUpgradePage,pages))
  else
    self.gearScanSummary:SetText(string.format("%d bag upgrades | %d checked | %d bag items | %d need data | %d/%d",
      n,data.checked,data.itemsSeen,data.unknown or 0,self.gearUpgradePage,pages))
  end
  if self.gearTierButton and journal then
    local tierName=data.tierName or select(2,self:GetGearJournalTier()) or "Latest"
    if #tierName>18 then tierName=tierName:sub(1,17).."..." end
    self.gearTierButton:SetLabel("EXP: "..tierName.." >")
    self.gearKindButton:SetLabel("SOURCE: "..(self.gearJournalKind or "All").." >")
    if self.gearDifficultyButton then
      self.gearDifficultyButton:SetLabel("DIFF: "..(data.difficultyMode or "Normal").." >")
    end
  end
  -- The selected item belongs to ONE scan snapshot. A new scan must never
  -- leave its old details visible, even while loot is arriving asynchronously.
  local current=self.gearSelectedData==data and self.gearSelected or nil
  self.gearSelected=nil
  if current then
    for _,entry in ipairs(data.results)do
      if journal then
        if entry.link==current.link and entry.source==current.source then self.gearSelected=entry;break end
      elseif entry.link==current.link and entry.bag==current.bag and entry.bagSlot==current.bagSlot then
        self.gearSelected=entry;break
      end
    end
  end
  if not self.gearSelected then self.gearSelectedData=nil end
  -- No automatic first-item selection: show a neutral 'select a result' state.
  -- This prevents page one from showing details for an unrelated old item.
  for i,row in ipairs(self.gearUpgradeRows) do
    local entry=data.results[(self.gearUpgradePage-1)*6+i]
    row.item=entry
    row:SetShown(entry~=nil)
    if entry then
      local short=entry.name
      if #short>37 then short=short:sub(1,34).."..." end
      local profile=self.Profile and self:Profile()
      local target=profile and profile.gearTarget
      local tracked=journal and target and
        target.itemID==entry.itemID and target.source==entry.source
      local levelTag=self:GearLevelResultLabel(entry)
      row:SetLabel(string.format("%s%s  +%d iLvl  %s  |  %s",tracked and "* " or "",levelTag,entry.delta,entry.slotName,short))
      row:SetTone(entry==self.gearSelected and "selected" or nil)
    end
  end
  if journal then
    if n==0 then
      local missing=data.unknown or 0
      if data.busy then
        self.gearNoResults:SetText(string.format("Scanning journal and loading item data: %d unknown. Results may appear after WoW returns details.",missing))
      else
        self.gearNoResults:SetText(string.format("No +1 item-level leads within your level +5 in this journal tier. %d too high, %d missing data. Try another expansion or difficulty.",
          data.tooHighLevel or 0,missing))
      end
    else
      self.gearNoResults:SetText(string.format("%d leads: %d equip now, %d coming within 5 levels. %d blocked above window, %d unknown; check eligibility.",
        n,data.equipNow or 0,data.comingSoon or 0,data.tooHighLevel or 0,data.unknown or 0))
    end
  elseif n==0 then
    local reason
    if data.bagsUnavailable>0 and data.bagsRead==0 then
      reason="Bag APIs unavailable. Your items were NOT checked; see Diagnostics."
    elseif data.itemsSeen==0 then
      reason=string.format("No items detected in %d scanned bag slots. Open your bags and scan again.",data.slots)
    elseif data.equipmentSeen==0 then
      reason=string.format("Found %d bag items, but no comparable gear (non-gear: %d). Use FIND DUNGEON/RAID GEAR to discover drops.",data.itemsSeen,data.unsupported)
    elseif data.checked==0 then
      reason=string.format("Found %d gear items but no usable comparisons yet. Wrong armor/unusable: %d; waiting for item data: %d. Try FIND DUNGEON/RAID GEAR.",data.equipmentSeen,data.unusable,data.unknown)
    elseif data.unknown>0 or data.unknownEquipped>0 then
      reason=string.format("No higher-level gear among %d compared. Missing levels: %d bag / %d worn.",data.checked,data.unknown,data.unknownEquipped)
    else
      reason=string.format("Compared %d bag gear items: no +1 upgrades in your level window. %d too high; use FIND DUNGEON/RAID GEAR.",data.checked,data.tooHighLevel or 0)
    end
    if data.bagsUnavailable>0 and data.bagsRead>0 then reason=reason.." Some bags unavailable." end
    self.gearNoResults:SetText(reason)
  else
    self.gearNoResults:SetText(string.format("%d bag upgrades: %d equip now, %d coming soon (max +5 levels). %d higher-level items excluded.",
      n,data.equipNow or 0,data.comingSoon or 0,data.tooHighLevel or 0))
  end
  local e=self.gearSelected
  if self.gearFocusName then
    self.gearFocusName:SetText(e and e.name or (journal and "No verified raid/dungeon upgrade selected" or "No bag upgrade selected"))
    self.gearFocusStats:SetText(e and string.format("%s: %s to %d (+%d iLvl) | %s",e.slotName,
      e.oldIlvl==0 and "Empty" or tostring(e.oldIlvl),e.ilvl,e.delta,self:GearLevelResultLabel(e)) or
      (journal and (data.status or "Scan the game journal to find sources.") or
        string.format("Bag items: %d | Compared: %d",data.itemsSeen,data.checked)))
    if journal then
      self.gearFocusSource:SetText(e and
        (e.kind..": "..e.source..". Difficulty ID: "..tostring(e.difficulty or "unknown")..". "..(e.needsEligibilityCheck and "CHECK item requirements." or "Review stats and access before farming.").." Drop not guaranteed.") or
        ("Expansion: "..tostring(data.tierName or "not scanned")..". "..(data.status or "Choose an expansion and scan.")))
    else
      self.gearFocusSource:SetText(e and
        string.format("Already owned: bag %d, slot %d. Hover for stats.",e.bag,e.bagSlot) or
        string.format("Scanned %d bags (%d inaccessible), %d slots. Non-gear: %d; unusable: %d; unknown levels: %d.",
          data.bagsRead,data.bagsUnavailable,data.slots,data.unsupported,data.unusable,data.unknown))
    end
  end
  if self.gearOpenSource then self.gearOpenSource:SetShown(journal and e~=nil) end
  if self.gearTrackTarget then self.gearTrackTarget:SetShown(journal and e~=nil) end
  -- A map action is offered ONLY when WoW confirms the precise entrance POI.
  local entrance=journal and e and self.FindGearEntrance and self:FindGearEntrance(e)
  if self.gearEntranceButton then self.gearEntranceButton:SetShown(entrance~=nil) end
  if self.gearTrackedTarget then
    local profile=self.Profile and self:Profile()
    local target=profile and profile.gearTarget
    if target then
      local short=target.name or "Unknown"
      if #short>40 then short=short:sub(1,37).."..." end
      self.gearTrackedTarget:SetText("TRACKED: "..short.." | "..tostring(target.source or "Source unknown"))
    else
      self.gearTrackedTarget:SetText("No dungeon/raid gear target saved")
    end
  end
  if self.db.tab=="Gear" and self.mapHint then
    if journal then
      self.mapLocation:SetText(e and (e.kind.."  |  "..e.source) or "Journal sources  |  No destination selected")
      self.mapHint:SetText(entrance and
        ("WoW discovered an entrance for this source. Click SHOW ENTRANCE below to open the map.") or
        "WoW has not supplied a verified entrance for this source. Use OPEN SOURCE for boss and loot details.")
    else
      self.mapLocation:SetText("In your bags  |  No map destination")
      self.mapHint:SetText("Bag upgrades are already owned. Source routes are not necessary for items in your bags.")
    end
  end
end
function GHN:RenderGearContext()
  if not self.gearContext then return end
  local active=self.db.tab=="Gear"
  self.gearContext:SetShown(active)
  -- Gear detail must replace the entire mount Help panel, not just cover it.
  -- Otherwise children of the Help panel can render over the Gear labels.
  if self.helpPanel then self.helpPanel:SetShown(not active and self.db.tab~="Leveling") end
  if self.levelCoachPanel then self.levelCoachPanel:SetShown(self.db.tab=="Leveling") end
  if active and self.issueMenu then self.issueMenu:Hide() end
  self.mapWaypointButton:SetShown(not active)
  self.mapOpenButton:SetShown(not active)
  if active then
    self.mapTitle:SetText("Gear: Upgrade Finder")
    self:ShowMapPreview(nil)
    if self.gearSource=="journal" then
      local e=self.gearSelected
      self.mapLocation:SetText(e and (e.kind.."  |  "..e.source) or "Journal sources  |  No destination selected")
      local verified=e and self.FindGearEntrance and self:FindGearEntrance(e)
      self.mapHint:SetText(verified and
        "Verified entrance available through WoW. Click SHOW ENTRANCE ON MAP below." or
        "Encounter Journal confirms the loot source; a discovered entrance map pin is not available for this source.")
    else
      self.mapLocation:SetText("In your bags  |  No map destination")
      self.mapHint:SetText("Bag upgrades are already owned. Select a candidate to see its bag slot.")
    end
    self.lastPreviewMap=nil
  end
end

function GHN:RenderMount()
  local m,g=self:SelectedGuide()
  if not m and not self.db.mountID then
    local id=PickAshes()
    if id then self.db.mountID=id;m,g=self:SelectedGuide()end
  end
  local newMountID=m and m.id or false
  if self.helpMountID ~= newMountID then
    self.helpMountID=newMountID
    self.helpIssue=1
    self.selectedStep=nil
    if self.issueMenu then self.issueMenu:Hide() end
    if self.issueButton then self.issueButton:SetLabel("CHOOSE A HELP TOPIC  v") end
    if self.helpAnswer then self.helpAnswer:SetText(m and
      ("Help for "..m.name..". Choose a topic and press GET HELP. Source: "..MountSource(m)) or
      "Choose a mount and a help topic to get started.") end
  end
  self.heroName:SetText(m and m.name or "Choose a mount")
  self.heroName:SetTextColor(unpack(m and C.pink or C.gold))
  self.heroSource:SetText(m and ("Source: "..(g and g.source or MountSource(m))) or "Search your Mount Journal to start")
  local quality=g and (g.verified and "Detailed guide" or "Journal-based plan") or ""
  self.heroMeta:SetText(m and ((m.collected and "COLLECTED" or "NOT COLLECTED").."  |  "..quality.."  |  "..(g.kind or "Mount")) or "Track any mount from your journal")
  self.heroDescription:SetText(m and (m.description or "Use the source and saved checklist to plan this hunt.") or "Find a mount by name, source, or activity.")
  self.heroIcon:SetTexture((m and m.icon) or (BASE.."map.tga"))
  self.trackButton:SetLabel(m and "CHANGE MOUNT" or "CHOOSE MOUNT")
  local guideDone=g and self:GuideSteps(g) or {}
  local steps=g and g.steps or FallbackSteps(m)
  if not self.selectedStep or not steps[self.selectedStep] then
    self.selectedStep=g and self:NextGuideStep() or 1
  end
  for i,b in ipairs(self.stepRows)do
    local step=steps[i]
    b:SetShown(step~=nil)
    if step then
      local state=g and guideDone[i] and "DONE" or tostring(i)
      b:SetLabel(state.."   "..step)
      b:SetTone(g and guideDone[i] and "done" or (i==self.selectedStep and "selected" or nil))
    end
  end
  local item=steps[self.selectedStep]
  self.stepTitle:SetText(g and ("Step "..self.selectedStep..": "..(g.stepTitles and g.stepTitles[self.selectedStep] or "Your next objective")) or "Choose a mount")
  self.stepDetails:SetText(g and (g.tips[self.selectedStep] or item or "") or "Choose a mount to view guidance.")
  self.detailStep:SetText(item or "No step selected")
  self.completeButton:SetShown(g~=nil)
  self.completeButton:SetLabel(g and guideDone[self.selectedStep] and "REOPEN STEP" or "MARK COMPLETE")
  self:UpdateGuideTabs()
  local notice=(g and g.verified) and "Detailed mount guide. Waypoints are shown only when verified." or
    "Source-derived planning checklist. Exact routes and prerequisites must be verified in game."
  self.requirements:SetText(m and ((g.requirements or "Check prerequisites in the Mount Journal.").."\n\nMount Journal source: "..MountSource(m).."\n\n"..notice) or "Select a mount to view requirements.")
  self.relatedItems:SetText(m and
    ("Mount: "..m.name.."\nAcquisition: "..(g.kind or "Journal source").."\nSource: "..MountSource(m)..
     (g.verified and "\nDetailed guide source: "..g.source or "").."\n\nYou can log attempts and save progress for this character. Check the journal for the actual collection state.") or
    "Choose a mount to see its acquisition source.")
  local hasWaypoint=g and g.mapID and g.mapName and g.x and g.y
  local loc=g and g.mapName or "No verified destination region"
  self.mapDetails:SetText(m and (("Destination region: "..loc)..
    (hasWaypoint and ("\nVerified waypoint: "..string.format("%.1f, %.1f",g.x*100,g.y*100)) or "\nNo verified entrance coordinate for this mount.")..
    "\n\n"..(g.verified and (g.source or MountSource(m)) or ("Journal source: "..MountSource(m)))..
    "\n\nUse OPEN WORLD MAP to view the game's map. SET DESTINATION is available only for verified waypoints.") or "Choose a mount to view map information.")
  self.mountStatus:SetText(m and (quality.."  |  "..(m.collected and "Already owned" or "Still missing").."  |  Checkboxes saved per character") or "Select a mount from the in-game catalog.")
  self:RefreshMapCard(m,g)
end
function GHN:RefreshMapCard(m,g)
  local hasWaypoint=g and g.mapID and g.mapName and g.x and g.y
  self.mapTitle:SetText(hasWaypoint and ("Map: "..g.mapName) or
    (m and (g and g.mapName and ("Region: "..g.mapName) or "Map: "..m.name) or "Map: Choose a mount"))
  self.mapLocation:SetText(hasWaypoint and (g.mapName.."  |  "..string.format("%.1f, %.1f",g.x*100,g.y*100)) or
    (m and "No verified waypoint for this mount" or "Select a mount to start"))
  local key=hasWaypoint and (tostring(g.mapID)..":"..tostring(g.x)..":"..tostring(g.y)) or "none"
  if self.lastPreviewMap~=key then
    self.lastPreviewMap=key
    self:ShowMapPreview(hasWaypoint and g.mapID,hasWaypoint and g.x,hasWaypoint and g.y)
  end
  if m and not hasWaypoint and self.mapHint then
    self.mapHint:SetText("Source found in your journal; an exact destination has not been verified for this mount. Use OPEN MAP to explore.")
  end
end
function GHN:GetLevelingAdvice(c)
  local plan=self.GetLevelingPlan and self:GetLevelingPlan(c)
  return plan and plan.firstStep or "Your current leveling objective is unavailable. Open your quest log."
end
function GHN:RefreshLevelingContext(plan)
  if not plan or not self.db or self.db.tab~="Leveling" then return end
  if self.mapTitle then self.mapTitle:SetText("Leveling Map: "..tostring(plan.zone)) end
  if self.mapLocation then self.mapLocation:SetText(plan.zone.." | use in-game quest markers") end
  if self.mapWaypointButton then self.mapWaypointButton:Hide() end
  if self.mapOpenButton then
    self.mapOpenButton:ClearAllPoints()
    self.mapOpenButton:SetPoint("TOPLEFT",self.mapLocation:GetParent(),"TOPLEFT",11,-24)
    self.mapOpenButton:SetWidth(330)
  end
  local id=C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local mapKey="level:"..tostring(id or "none")
  if self.levelMapKey~=mapKey then
    self.levelMapKey=mapKey
    self:ShowMapPreview(id)
  end
  if self.mapHint and not id then self.mapHint:SetText("Open WoW's map to see your quest markers.") end
  if self.levelCoachPanel then self.levelCoachPanel:Show() end
  if self.levelCoachHeader then self.levelCoachHeader:SetText(plan.class.." | Level "..plan.level) end
  if self.levelCoachNext then self.levelCoachNext:SetText(plan.title) end
  if self.levelCoachWhy then self.levelCoachWhy:SetText(plan.reason.."\n\nNo fabricated quest waypoints or fastest-route promises.") end
end
function GHN:Refresh()
  if not self.frame or not self.db or self._refreshInProgress then return end
  self._refreshInProgress=true
  local ok,c=pcall(function()return self:GetCharacterSummary()end)
  if ok and c then
    self.character:SetText(c.name.."   |   "..c.class.." / "..c.spec.."   |   "..c.faction.."   |   Level "..c.level.."   |   Equipped iLvl "..string.format("%.1f",c.ilevel))
    local now,maximum=self:GetGearLevelWindow()
    self.gearLevel:SetText("Level "..tostring(now or c.level).." | Required level up to "..tostring(maximum or "?").." | iLvl "..string.format("%.1f",c.ilevel))
    if self.gearRangeButton then self.gearRangeButton:SetLabel("RANGE +"..self:GetGearAheadLevels()) end
    self.levelHeader:SetText("Level "..c.level.." "..c.class.."   |   "..c.zone)
    if self.characterStageSummary then
      self.characterStageSummary:SetText(c.name.."  |  "..c.class.." / "..c.spec.."\n"..c.faction.."  |  Level "..c.level.."\nEquipped item level: "..string.format("%.1f",c.ilevel))
    end
  end
  if self.db.tab=="Character"then
    self:Safe("Character artwork and model",function()self:RefreshCharacterStage()end)
  end
  if self.db.tab=="Mounts" or self.db.tab=="Help Me (Stuck)" then
    self:Safe("Redesigned mount display",function()self:RenderMount()end)
  end
  self:Safe("Redesigned equipment",function()self:RenderGear()end)
  if self.db.tab=="Gear" then
    self:Safe("Bag upgrade scan",function()self:RenderGearUpgrades()end)
  end
  self:Safe("Gear context",function()self:RenderGearContext()end)
  self:Safe("Recommendation",function()
    local title,why=self:GetRecommendation()
    self.recTitle:SetText(title or "Choose a goal to get started")
    self.recWhy:SetText(why or "Navigator will recommend the next verified step.")
    local plan=self.GetLevelingPlan and self:GetLevelingPlan(c)
    if plan then
      self.levelNext:SetText("DO NEXT: "..plan.title)
      self.levelAdvice:SetText(plan.firstStep.."\n\nROUTE: "..plan.route)
      self.levelCombat:SetText(plan.combat)
      self.levelMilestone:SetText(plan.milestone)
      self:RefreshLevelingContext(plan)
    else
      self.levelAdvice:SetText("Leveling information is unavailable. Check your quest log.")
    end
    if self.adventurePreviewButtons then
      local suggestions=self:GetAdventureChoices()
      self.adventurePreviewList=suggestions
      for i,b in ipairs(self.adventurePreviewButtons) do
        local item=suggestions[i]
        if item then
          local title=(item.kind..": "..item.title)
          if #title>75 then title=title:sub(1,72).."..." end
          b:SetLabel(title);b:Show()
        else b:Hide() end
      end
    end
  end)
  self:Safe("Intelligence display",function()
    local s=self:GetIntelligenceSummary()
    self.intStatus:SetText(s.enabled and "Learning enabled" or "Learning paused")
    self.intSummary:SetText(string.format("Saved goals: %d     Attempts: %d     Recorded arrivals: %d",s.goals,s.attempts,s.routes))
    self.intPriority:SetText("Selected priority: "..s.priority)
    self.intRecent:SetText(s.last and s.last.message or "No learning history recorded yet.")
    self.pauseButton:SetLabel(s.enabled and "PAUSE LEARNING" or "RESUME LEARNING")
  end)
  self:Safe("Diagnostics display",function()
    local entries=self.db.diagnostic or {}
    for i,t in ipairs(self.diagnosticRows)do
      local e=entries[i];t:SetText(e and ((e.at or "").."   ["..(e.kind or "INFO").."]  "..(e.message or ""))or "")
    end
  end)
  if self.db.tab=="Map" then self:Safe("MapHub explorer",function()self:RefreshDiscoveries()end) end
  if self.db.tab=="Quests" or self.db.tab=="Reputation" or self.db.tab=="Collections" then
    self:Safe("Quest/Reputation/Collections",function()self:RefreshProgressPage()end)
  end
  if self.db.tab=="Gear Hunter" and self.GearEngine and self.GearEngine.frame and self.GearEngine.frame:IsShown() then self:Safe("Original Gear Hunter",function() self.GearEngine:Refresh() end) end
  self._refreshInProgress=false
end

function GHN:UpdateDiscoveryZone(force)
  if not self.db or self.db.tab~="Map" then return end
  local id=self:CurrentDiscoveryMapID()
  if id~=self.discoveryDisplayedMapID then
    self.discoveryDisplayedMapID=id
    self.discoverySelected=nil
    self.discoveryPage=1
    self:RefreshDiscoveries()
  elseif force then self:RefreshDiscoveries() end
end

-- v0.3.6: self-contained zone explorer powered by the existing MapHub database.
function GHN:RefreshDiscoveries()
  if not self.discoveryRows or not self.db or self.db.tab~="Map" then return end
  local mapID=self:CurrentDiscoveryMapID()
  self.discoveryDisplayedMapID=mapID
  local name=self:DiscoveryMapName(mapID)
  local all=self:GetZoneDiscoveries(mapID)
  local list=self:FilteredDiscoveries(mapID)
  self.discoveryZone:SetText(name.."  |  Known discovery locations")
  local rare,treasure,secret=0,0,0
  for _,r in ipairs(all) do
    if r.category=="Rare" then rare=rare+1
    elseif r.category=="Treasure" then treasure=treasure+1
    elseif r.category=="Secret" then secret=secret+1 end
  end
  local pages=math.max(1,math.ceil(#list/#self.discoveryRows))
  self.discoveryPage=math.max(1,math.min(pages,self.discoveryPage or 1))
  self.discoverySummary:SetText(("%d rare points  |  %d treasures  |  %d secrets  |  page %d/%d"):format(rare,treasure,secret,self.discoveryPage,pages))
  for key,b in pairs(self.discoveryCategoryButtons or {}) do b:SetTone((self.discoveryCategory or "All")==key and "selected" or nil) end
  if self.navigatorMapIconFilters then
    for key,b in pairs(self.navigatorMapIconFilters) do b:SetChecked(self.mapPinVisible[key]~=false) end
  end
  if self.discoveryHideVisited==nil and self.db then self.discoveryHideVisited=self.db.discoveryHideVisited==true end
  self.discoveryVisitedButton:SetLabel(self.discoveryHideVisited and "HIDE VISITED: ON" or "HIDE VISITED: OFF")
  for i,b in ipairs(self.discoveryRows) do
    local r=list[(self.discoveryPage-1)*#self.discoveryRows+i]
    b.record=r
    if r then
      local marker=self:DiscoveryVisited(r) and "[VISITED] " or ""
      local prefix=({Rare="RARE",Treasure="CHEST",Chest="CHEST",EliteRare="ELITE",WorldBoss="BOSS",Secret="SECRET",Quest="QUEST",Vendor="VENDOR",FlightPath="FLIGHT"})[self:DiscoveryCategoryKey(r.category) or r.category] or (r.category or "DISCOVERY"):upper()
      local label=("%s  %s%s    (%.1f, %.1f)"):format(prefix,marker,r.name,r.x,r.y)
      if #label>78 then label=label:sub(1,75).."..." end
      b:SetLabel(label);b:Show()
      if b.discoveryIcon then b.discoveryIcon:SetTexture(self:DiscoveryIcon(r.category)) end
      b:SetTone(self.discoverySelected and self:DiscoveryKey(r)==self:DiscoveryKey(self.discoverySelected) and "selected" or nil)
    else b:Hide()end
  end
  self.discoveryInfo:SetText(self.discoverySelected and
    ((self.discoverySelected.name or "Discovery").." | Source: "..(self.discoverySelected.source or "Our MapHub records")..". These are known locations, not live spawns.") or
    (#all==0 and "No bundled records for this map. This does not mean the zone contains no rares or treasures." or
     "Select a location to see its map marker and create a waypoint. Mark visited manually; unverified completion remains unknown."))
  self.discoveryMarkButton:SetLabel(self.discoverySelected and (self:DiscoveryVisited(self.discoverySelected) and "UNMARK VISITED" or "MARK VISITED") or "MARK VISITED")
  self.mapTitle:SetText(name.."  |  Discovery Map")
  self.mapLocation:SetText(self.discoverySelected and (self.discoverySelected.name.." ("..string.format("%.1f, %.1f",self.discoverySelected.x,self.discoverySelected.y)..")") or
    "Current zone: "..name)
  self:ShowMapPreview(mapID,self.discoverySelected and self.discoverySelected.mapID==mapID and self.discoverySelected.x/100 or nil,
      self.discoverySelected and self.discoverySelected.mapID==mapID and self.discoverySelected.y/100 or nil)
  if self.discoveryMapPins then
    for _,b in ipairs(self.discoveryMapPins) do b:Hide() end
  else self.discoveryMapPins={} end
  -- Plot up to 45 filtered map pins on the native map preview; does not alter WorldMapFrame.
  for i=1,math.min(#list,160) do
    local r=list[i]
    local btn=self.discoveryMapPins[i]
    if not btn then
      btn=CreateFrame("Button",nil,self.mapCanvas)
      btn:SetSize(11,11)
      local icon=btn:CreateTexture(nil,"OVERLAY")
      icon:SetAllPoints();btn.discoveryIcon=icon
      local rim=btn:CreateTexture(nil,"BACKGROUND")
      rim:SetPoint("TOPLEFT",btn,"TOPLEFT",-2,2)
      rim:SetPoint("BOTTOMRIGHT",btn,"BOTTOMRIGHT",2,-2)
      rim:SetColorTexture(1,.78,.22,.85)
      btn.selectedRim=rim
      btn:SetScript("OnEnter",function(b)
        if not b.record or not GameTooltip then return end
        GameTooltip:SetOwner(b,"ANCHOR_RIGHT")
        GameTooltip:AddLine(b.record.name,1,.84,.35)
        GameTooltip:AddLine(string.format("%.1f, %.1f — known %s location",b.record.x,b.record.y,b.record.category),1,1,1)
        GameTooltip:Show()
      end)
      btn:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide()end end)
      btn:SetScript("OnClick",function(b)
        if b.record then
          GHN.discoverySelected=b.record
          GHN:RefreshDiscoveries()
          local ok,msg=GHN:SetDiscoveryWaypoint(b.record)
          if not ok and GHN.discoveryInfo then GHN.discoveryInfo:SetText(msg) end
        end
      end)
      self.discoveryMapPins[i]=btn
    end
    btn.record=r;btn:ClearAllPoints()
    btn:SetPoint("CENTER",self.mapCanvas,"TOPLEFT",r.x/100*342,-r.y/100*194)
    local selected=self.discoverySelected and self:DiscoveryKey(r)==self:DiscoveryKey(self.discoverySelected)
    btn:SetSize(selected and 26 or 20,selected and 26 or 20)
    btn.discoveryIcon:SetTexture(self:DiscoveryIcon(r.category))
    btn.discoveryIcon:SetVertexColor(1,1,1,self:DiscoveryVisited(r) and .53 or 1)
    btn.selectedRim:SetShown(selected and true or false)
    btn:Show()
  end
  if #all==0 and self.discoveryInfo then self.discoveryInfo:SetText("No verified bundled rare or treasure records for this zone yet; map artwork can still be viewed.") end
end
-- Display only candidates that Navigator's five-level policy and actual
-- equipped comparison have accepted. Unknown item metadata stays unranked.
function GHN:RefreshSourceCatalog()
  if not self.sourceRows or not self.db or self.db.tab~="Gear Hunter" then return end
  if self._refreshingSources then return end
  self._refreshingSources=true
  local good,err=pcall(function()
    local results,stats=self:FindObservedGearUpgrades(self.sourceSearchText,self.sourceFilter)
    self.sourceResults=results
    local total=math.max(1,math.ceil(#results/#self.sourceRows))
    self.sourcePage=math.min(math.max(1,self.sourcePage or 1),total)
    local now,max=self:GetGearLevelWindow()
    self.sourceSummary:SetText(("%d observed items | %d verified +1 upgrades | %d pending item data | Level %s to %s"):
      format(stats.observed,#results,stats.unknown,tostring(now or "?"),tostring(max or "?")))
    self.sourceStatus:SetText(self.sourceLastStatus or "Sources are learned when you open vendors, quest rewards or profession windows.")
    for key,b in pairs(self.sourceFilterButtons or {}) do b:SetTone((self.sourceFilter or "All")==key and "selected" or nil)end
    for i,b in ipairs(self.sourceRows) do
      local rec=results[((self.sourcePage-1)*#self.sourceRows)+i]
      b.record=rec
      if rec then
        local source=rec.sourceType or "Source"
        local nowLabel=rec.levelGroup=="soon" and ("SOON Lv"..tostring(rec.requiredLevel)) or "NOW"
        b:SetLabel(("%s  +%d iLvl | %s | %s  [%s]"):format(nowLabel,rec.delta,rec.name or "Item",source,rec.sourceName or "Observed"))
        b:Show()
        b:SetTone(self.sourceSelected==rec and "selected" or nil)
      else b:Hide() end
    end
    local r=self.sourceSelected
    if r then
      self.sourceDetail:SetText(("%s | +%d item levels | Required level %s\nSource: %s | %s\n%s"):
        format(r.name or "Item",r.delta or 0,tostring(r.requiredLevel or "?"),
          tostring(r.sourceType or "?"),tostring(r.sourceName or "Unknown"),
          r.sourceType=="Vendor" and (r.mapID and "Observed vendor map ID "..r.mapID or "Vendor location unrecorded") or
          (r.sourceType=="Quest" and "Quest must be independently available to this character." or
          "Check profession requirements and materials.")))
    else
      self.sourceDetail:SetText("Choose an observed upgrade to see its source. For complete Gear Hunter features, open the built-in classic Gear Hunter screens below.")
    end
  end)
  self._refreshingSources=false
  if not good then self:Log("SOURCES",tostring(err)) end
end

-- Three independent Blizzard-data pages. No navigation to Mounts from Quests.
function GHN:CreateProgressPage(tab,title,subtitle)
 local parent=self.pages[tab]
 local card=NewPanel(parent,13,-42,1074,569,C.deep,{.29,.46,.59,.91})
 Txt(card,title,19,-17,1032,32,21,C.gold)
 Txt(card,subtitle,21,-54,1030,43,13,C.white)
 self.progressPages=self.progressPages or {}
 local view={tab=tab,page=1,search="",selected=nil,entries={}}
 self.progressPages[tab]=view
 local input=CreateFrame("EditBox",nil,card,"InputBoxTemplate")
 input:SetSize(412,28);input:SetPoint("TOPLEFT",card,"TOPLEFT",27,-103)
 input:SetAutoFocus(false);input:SetMaxLetters(80)
 -- Keep the search hint inside the input, but don't let it cover typed text.
 -- This also makes an otherwise empty dark search box recognizable.
 local searchHint=Txt(card,tab=="Collections" and "Search mounts and toys..." or
   (tab=="Quests" and "Search active quests..." or "Search factions..."),
   35,-109,360,18,12,C.dim,false)
 local function UpdateSearchHint()
   searchHint:SetShown((input:GetText() or "")=="" and not input:HasFocus())
 end
 input:SetScript("OnTextChanged",function(e)
   view.search=e:GetText() or "";view.page=1
   UpdateSearchHint()
   if GHN.db and GHN.db.tab==tab then GHN:RefreshProgressPage() end
 end)
 input:SetScript("OnEditFocusGained",UpdateSearchHint)
 input:SetScript("OnEditFocusLost",UpdateSearchHint)
 UpdateSearchHint()
 view.searchInput=input
 -- Separate summary row: the former top-right summary overlapped the
 -- MOUNTS/TOYS and COLLECTED ONLY buttons in the Collections tab.
 view.summary=Txt(card,"Loading...",21,-140,1029,19,12,C.gold,false)
 view.rows={}
 -- Ten entries leave room for a real notice strip BELOW the final row.
 -- Previously the 11th row covered the notice at y=-484.
 for i=1,10 do
   local button=Button(card,"",19,-166-(i-1)*31,633,29,function()
     local entry=view.rows[i].entry
     if entry then view.selected=entry;view.questHelp=nil;GHN:RefreshProgressPage() end
   end,"dark")
   button.caption:ClearAllPoints()
   button.caption:SetPoint("TOPLEFT",button,"TOPLEFT",36,-4)
   button.caption:SetSize(590,23);button.caption:SetJustifyH("LEFT")
   button.caption:SetFont(FONT,12,"")
   button.icon=button:CreateTexture(nil,"ARTWORK")
   button.icon:SetSize(21,21);button.icon:SetPoint("LEFT",button,"LEFT",8,0)
   view.rows[i]=button
 end
 local detailCard=NewPanel(card,665,-164,393,337,C.panel,{.37,.48,.61,1})
 view.detail=Txt(detailCard,"Choose a row to see details.",17,-17,357,300,13,C.white)
 -- Notice occupies its own strip between the list and bottom buttons.
 view.notice=Txt(card,"",21,-482,626,22,11,C.warn)
 Button(card,"PREVIOUS",20,-516,137,31,function()
   view.page=math.max(1,view.page-1);GHN:RefreshProgressPage()
 end,"dark")
 Button(card,"NEXT",169,-516,137,31,function()
   view.page=view.page+1;GHN:RefreshProgressPage()
 end,"dark")
 if tab=="Quests" then
   Button(card,"HELP WITH THIS QUEST",321,-516,331,31,function()
     view.questHelp=GHN:QuestHelp(view.selected)
     GHN:RefreshProgressPage()
   end)
   Button(card,"TRACK QUEST",674,-511,178,35,function()
     local ok,msg=GHN:TrackActiveQuest(view.selected and view.selected.id)
     view.notice:SetText(msg);GHN:RefreshProgressPage()
   end)
   Button(card,"OPEN QUEST LOG",865,-511,181,35,function()
     if InCombatLockdown and InCombatLockdown() then view.notice:SetText("Open quest log outside combat.");return end
     if GHN.frame then GHN.frame:Hide() end
     if ToggleQuestLog then ToggleQuestLog()
     elseif QuestMapFrame and QuestMapFrame.Show then QuestMapFrame:Show()
     else view.notice:SetText("Use WoW's quest-log hotkey to open your log.");if GHN.frame then GHN.frame:Show()end end
   end)
 elseif tab=="Reputation" then
   Button(card,"EXPAND GROUPS",674,-511,178,35,function()
     local ok,msg=GHN:ExpandReputationGroups()
     view.notice:SetText(msg);GHN:RefreshProgressPage()
   end)
   Button(card,"REFRESH",865,-511,181,35,function()GHN:RefreshProgressPage()end)
 elseif tab=="Collections" then
   view.kind="Mounts";view.collectedOnly=true
   Button(card,"SHOW ALL TOYS IN BLIZZARD LIST",321,-516,330,31,function()
     if C_ToyBoxInfo and C_ToyBoxInfo.SetDefaultFilters then
       pcall(C_ToyBoxInfo.SetDefaultFilters)
       if C_ToyBox and C_ToyBox.SetFilterString then pcall(C_ToyBox.SetFilterString,"") end
       view.kind="Toys";view.kindButton:SetLabel("TOYS")
       view.page=1;view.selected=nil;GHN:RefreshProgressPage()
     else view.notice:SetText("Toy Box filter reset is not available on this client.") end
   end,"dark")
   view.kindButton=Button(card,"MOUNTS",676,-102,177,32,function()
     view.kind=view.kind=="Mounts" and "Toys" or "Mounts"
     view.kindButton:SetLabel(view.kind:upper())
     view.selected=nil;view.page=1;GHN:RefreshProgressPage()
   end)
   view.collectedButton=Button(card,"COLLECTED ONLY",865,-102,180,32,function()
     view.collectedOnly=not view.collectedOnly
     view.collectedButton:SetLabel(view.collectedOnly and "COLLECTED ONLY" or "ALL ITEMS")
     view.page=1;view.selected=nil;GHN:RefreshProgressPage()
   end)
   Button(card,"REFRESH COLLECTION",674,-511,372,35,function()GHN:RefreshProgressPage()end)
 end
end
local function ClipLine(text,max)
 text=tostring(text or "")
 if #text>max then return text:sub(1,max-3).."..." end
 return text
end
function GHN:RefreshProgressPage()
 if not self.db or not self.progressPages then return end
 local tab=self.db.tab
 local view=self.progressPages[tab]
 if not view then return end
 local entries,info
 local collectionLearned,collectionTotal
 if tab=="Quests" then entries,info=self:ReadActiveQuests(view.search)
 elseif tab=="Reputation" then entries,info=self:ReadReputations(view.search)
 else
   local learned,total,notice
   entries,learned,total,notice=self:ReadCollectionItems(view.kind,view.collectedOnly,view.search)
   info=notice
   collectionLearned,collectionTotal=learned,total
 end
 entries=entries or {}
 view.entries=entries
 if tab~="Collections" then view.summary:SetText(""..#entries.." shown  |  Search or select a record") end
 if info then view.notice:SetText(info) elseif view.notice:GetText()=="" or tab~="Quests" then view.notice:SetText("") end
 local limit=#view.rows
 local pages=math.max(1,math.ceil(#entries/limit))
 view.page=math.max(1,math.min(view.page or 1,pages))
 if tab=="Collections" then
   -- All three figures refer to the items currently available from WoW's journal filters.
   view.summary:SetText(string.format("%s: %d / %d owned in current journal filters  |  %d matching  |  Page %d/%d",
     view.kind,collectionLearned or 0,collectionTotal or 0,#entries,view.page,pages))
 end
 if view.selected then
   local found=false
   for _,r in ipairs(entries) do if r.id==view.selected.id then view.selected=r;found=true;break end end
   if not found then view.selected=nil end
 end
 if not view.selected and entries[1] then view.selected=entries[1] end
 for i,b in ipairs(view.rows) do
   local r=entries[(view.page-1)*limit+i]
   b.entry=r
   if r then
     local label
     if tab=="Quests" then
       label=(r.complete and "READY  " or "ACTIVE  ").."["..tostring(r.level or "?").."] "..r.name
     elseif tab=="Reputation" then
       label=r.name.."  |  "..r.label..(r.accountWide and " (Warband)" or "")
     else label=(r.collected and "OWNED  " or "MISSING  ")..r.name end
     b:SetLabel(ClipLine(label,79))
     b.icon:SetTexture(r.icon or (tab=="Quests" and BASE.."route.tga" or tab=="Reputation" and BASE.."check.tga" or BASE.."farm.tga"))
     b:SetTone(view.selected==r and "selected" or nil);b:Show()
   else b:Hide() end
 end
 local selected=view.selected
 if not selected then
   view.detail:SetText(#entries==0 and (tab=="Quests" and "Your quest log has no matching active quests. Accept a quest and reopen this tab." or
       tab=="Reputation" and "No factions are visible for that search. Expand collapsed groups or check your Reputation tab." or
       "No matching mounts or toys. Switch the collection filter, or change your Toy Box filters.") or "Select an entry.")
   return
 end
 if tab=="Quests" then
   local lines={selected.name,"Quest ID: "..selected.id.."  |  Suggested level: "..tostring(selected.level),
      selected.complete and "READY TO TURN IN" or "ACTIVE QUEST", ""}
   if #selected.objectives>0 then
     lines[#lines+1]="OBJECTIVES:"
     for _,obj in ipairs(selected.objectives) do
       local desc=ClipLine(obj.text or "Quest objective",83)
       local count=""
       if type(obj.numFulfilled)=="number" and type(obj.numRequired)=="number" and obj.numRequired>0 then
         count=" ("..obj.numFulfilled.."/"..obj.numRequired..")"
       end
       lines[#lines+1]=(obj.finished and "[Done] " or "[ ] ")..desc..count
     end
   else lines[#lines+1]="Quest objectives are not currently cached by WoW."
   end
   lines[#lines+1]="";lines[#lines+1]=view.questHelp or "Select HELP WITH THIS QUEST for your next objective."
   view.detail:SetText(table.concat(lines,"\n"))
 elseif tab=="Reputation" then
   local lines={selected.name,"Standing: "..selected.label,
      selected.accountWide and "Warband reputation" or "Character reputation",""}
   if selected.high>selected.low then
     local progress=math.max(0,selected.current-selected.low)
     lines[#lines+1]="Progress: "..progress.." / "..(selected.high-selected.low)
   else lines[#lines+1]="This standing has no conventional progress bar." end
   if selected.watched then lines[#lines+1]="Watched faction" end
   lines[#lines+1]="";lines[#lines+1]=ClipLine(selected.description,300)
   view.detail:SetText(table.concat(lines,"\n"))
 else
   view.detail:SetText(selected.name.."\n\n"..selected.kind.." ID: "..tostring(selected.id).."\n"..
      (selected.collected and "Collected in your journal" or "Not collected").."\n\n"..
      (selected.kind=="Mount" and "Use the Mount Hunter tab for source details and acquisition steps." or
       "This entry is read from your WoW Toy Box. You can manage and use your toys in Blizzard's Collections interface."))
 end
end

function GHN:CreateUI()
  if self.frame then return end
  if not self.db then return end
  -- Full-screen background. Content uses a uniform zoomed coordinate space,
  -- so text and button hit areas stay aligned at every screen resolution.
  -- A named UISpecialFrame integrates with WoW's normal Escape-to-close behavior.
  -- No keyboard hooks or secure/protected character actions are required.
  local screen=NewPanel(UIParent,0,0,1322,756,C.bg,{.71,.57,.28,1},"GearHunterNavigatorFullscreenFrame")
  screen:ClearAllPoints();screen:SetAllPoints(UIParent)
  screen:SetFrameStrata("HIGH");screen:SetToplevel(true)
  screen:EnableMouse(true)
  local root=CreateFrame("Frame",nil,screen)
  root:SetSize(1322,756)
  root:SetPoint("CENTER",screen,"CENTER",0,0)
  local function Resize()
    if not (screen and root and UIParent)then return end
    local w=UIParent:GetWidth() or 1322;local h=UIParent:GetHeight() or 756
    if w<=0 or h<=0 then return end
    root:SetScale(math.min(w/1322,h/756))
  end
  screen:SetScript("OnShow",Resize)
  screen:SetScript("OnSizeChanged",Resize)
  Resize()
  self.frame=screen
  if self.GearEngine then self.GearEngine.frame=screen end
  -- Blizzard closes visible UISpecialFrames when Escape is pressed. Use the
  -- backdrop frame (not the scaled content child) so the entire UI closes.
  if type(UISpecialFrames)=="table" then
    local registered=false
    for _,frameName in ipairs(UISpecialFrames) do
      if frameName=="GearHunterNavigatorFullscreenFrame" then registered=true; break end
    end
    if not registered then table.insert(UISpecialFrames,"GearHunterNavigatorFullscreenFrame") end
  end
  self.layoutFrame=root
  self.navigatorMidnightTrim,self.navigatorMidnightEdge,self.navigatorMidnightGlow = ApplyNavigatorMidnightFrame(screen,root)
  -- Shift only the header text away from the ornate top edge. Panels and
  -- their button hit areas retain all of their original coordinates.
  Image(root,BASE.."shield.tga",68,-27,42,42)
  Txt(root,"Gear Hunter Navigator",140,-23,520,36,28,C.gold)
  Txt(root,"Gear Hunter Navigator  |  Your Intelligent WoW Assistant",140,-56,520,22,13,C.white)
  self.character=Txt(root,"",695,-35,570,30,12,C.silver)
  Button(root,"X",1259,-27,35,30,function()screen:Hide()end,"gold")
  local nav=NewPanel(root,13,-86,186,651,C.deep,{.25,.38,.51,.95})
  local center=NewPanel(root,209,-86,716,651,C.panel,{.34,.46,.57,.88})
  local right=CreateFrame("Frame",nil,root);right:SetSize(377,651);right:SetPoint("TOPLEFT",root,"TOPLEFT",933,-86)
  self.nav={};self.pages={};self.mainCenter=center;self.mainRight=right
  local tabs={{"Dashboard","best"},{"Character","character"},{"Leveling","level-up"},{"Gear","upgrades"},{"Gear Hunter","search"},{"Mounts","farm"},
       {"Quests","route"},{"Dungeons & Raids","shield"},{"Reputation","check"},{"Collections","item-placeholder"},
       {"Achievements","sparkle"},{"Map","map"},{"Help Me (Stuck)","search"},{"Intelligence","progress"},{"Diagnostics","settings"}}
  for i,row in ipairs(tabs)do
    local tab,key=row[1],row[2];local yy=-10-(i-1)*42
    local b=Button(nav,"",10,yy,165,41,function()GHN:Select(tab)end,"dark")
    Image(b,BASE..key..".tga",10,-8,23,23)
    b.caption:ClearAllPoints();b.caption:SetPoint("TOPLEFT",b,"TOPLEFT",39,-7);b.caption:SetSize(120,27)
    b.caption:SetJustifyH("LEFT");b.caption:SetText(tab)
    self.nav[tab]=b
    local p=CreateFrame("Frame",nil,center)
    p:SetAllPoints(center);p:Hide();self.pages[tab]=p
  end
  self.sectionTitle=Txt(center,"Mounts",14,-7,330,27,17,C.gold)
  -- A persistent mount detail view with multi-tab guide content.
  do
    local p=self.pages.Mounts
    local hero=NewPanel(p,12,-40,692,124,C.deep,{.31,.42,.57,1})
    self.heroIcon=Image(hero,BASE.."farm.tga",12,-13,75,75)
    self.heroName=Txt(hero,"Choose a mount",101,-11,424,29,22,C.pink)
    self.heroSource=Txt(hero,"",101,-43,530,22,13,C.white)
    self.heroMeta=Txt(hero,"",101,-66,515,21,12,C.green)
    self.heroDescription=Txt(hero,"",101,-89,569,27,12,C.silver)
    self.trackButton=Button(hero,"CHOOSE MOUNT",544,-13,134,32,function()GHN:OpenChooser()end)
    local tabNames={{"Requirements","Requirements"},{"Step-by-Step Guide","Steps"},{"Map & Locations","Map"},{"Related Items","Related"}}
    self.guideTabs={};self.mountBodies={}
    local x=12
    for _,tab in ipairs(tabNames)do
      local width=(tab[2]=="Steps")and 175 or (tab[2]=="Map" and 151 or 144)
      local button=Button(p,tab[1],x,-179,width-5,34,function()GHN.guideTab=tab[2];GHN:UpdateGuideTabs()end,"dark")
      self.guideTabs[tab[2]]=button;x=x+width
      local container=CreateFrame("Frame",nil,p)
      container:SetSize(692,367);container:SetPoint("TOPLEFT",p,"TOPLEFT",12,-220)
      self.mountBodies[tab[2]]=container;container:Hide()
    end
    local steps=self.mountBodies.Steps
    local stepCard=NewPanel(steps,0,0,355,364,C.deep,{.29,.48,.57,.8})
    Txt(stepCard,"YOUR MOUNT JOURNEY",14,-12,322,22,14,C.gold)
    self.stepRows={}
    for i=1,5 do
      local index=i
      local row=Button(stepCard,"",12,-44-(i-1)*52,330,46,function()
        GHN.selectedStep=index;GHN:RenderMount()
      end,"dark")
      row.caption:SetFont(FONT,12,"");row.caption:SetJustifyH("LEFT")
      self.stepRows[i]=row
    end
    local details=NewPanel(steps,366,0,326,364,C.deep,{.31,.48,.59,.87})
    Txt(details,"STEP DETAILS",15,-12,276,22,14,C.gold)
    self.stepTitle=Txt(details,"",15,-47,294,57,16,C.white)
    local iconBox=NewPanel(details,14,-118,297,102,C.subtle,{.27,.38,.55,.95})
    Image(iconBox,BASE.."route.tga",16,-22,58,58)
    self.detailStep=Txt(iconBox,"",90,-13,186,76,13,C.white)
    self.stepDetails=Txt(details,"",15,-233,297,84,12,C.silver)
    self.completeButton=Button(details,"MARK COMPLETE",17,-320,287,32,function()
      if GHN.currentGuide then
        local previous=GHN.selectedStep
        GHN:SetGuideStep(GHN.currentGuide,previous)
        local done=GHN:GuideSteps(GHN.currentGuide)
        if done[previous] then
          for step=1,#GHN.currentGuide.steps do
            if not done[step] then GHN.selectedStep=step;break end
          end
        end
        GHN:RenderMount()
      end
    end)
    local reqCard=NewPanel(self.mountBodies.Requirements,0,0,692,364,C.deep)
    Txt(reqCard,"REQUIREMENTS & PREREQUISITES",20,-17,620,29,18,C.gold)
    self.requirements=Txt(reqCard,"",21,-64,632,270,15,C.white)
    local mapCard=NewPanel(self.mountBodies.Map,0,0,692,364,C.deep)
    Txt(mapCard,"MAP & LOCATIONS",19,-18,620,29,18,C.gold)
    self.mapDetails=Txt(mapCard,"",21,-68,647,190,16,C.white)
    Button(mapCard,"SET DESTINATION WAYPOINT",20,-285,314,44,function()GHN:SetWaypointWithMessage()end)
    Button(mapCard,"OPEN WORLD MAP",352,-285,313,44,function()GHN:OpenNativeMap()end)
    local relatedCard=NewPanel(self.mountBodies.Related,0,0,692,364,C.deep)
    Txt(relatedCard,"RELATED ITEMS & SOURCES",19,-18,620,29,18,C.gold)
    self.relatedItems=Txt(relatedCard,"",20,-65,650,250,16,C.white)
    self.mountStatus=Txt(p,"",16,-578,663,24,12,C.dim)
    Button(p,"CHOOSE ANOTHER MOUNT",15,-611,240,30,function()GHN:OpenChooser()end,"dark")
    Button(p,"LOG ATTEMPT",271,-611,172,30,function()
      if GHN.currentGuide and GHN:RecordMountAttempt(GHN.currentGuide)then GHN.feedback:SetText("Mount attempt saved for your character.");GHN:Refresh()
      else GHN.feedback:SetText("Select a verified mount guide and enable learning first.")end
    end,"dark")
    self.feedback=Txt(p,"",455,-612,220,30,12,C.green)
  end
  -- Always-visible right column: real WoW map preview + contextual Help Me.
  do
    local top=NewPanel(right,0,0,377,317,C.deep,{.45,.49,.59,1})
    self.mapTitle=Txt(top,"Map",13,-10,325,25,17,C.white)
    local canvas=NewPanel(top,12,-43,352,210,{.038,.068,.101,1},{.36,.45,.56,.9})
    local area=CreateFrame("Frame",nil,canvas);area:SetSize(342,194);area:SetPoint("TOPLEFT",canvas,"TOPLEFT",5,-7)
    area:SetClipsChildren(true)
    self.mapCanvas=area;self.mapTiles={}
    self.mapHint=Txt(canvas,"Native world map preview",16,-65,310,91,14,C.silver)
    -- The eight approved icon styles are an actual clickable legend in-game,
    -- not a preview image. This legend is visible only on the Map page.
    local legend=CreateFrame("Frame",nil,area,"BackdropTemplate")
    legend:SetSize(133,187)
    legend:SetPoint("TOPRIGHT",area,"TOPRIGHT",-2,-3)
    legend:SetFrameLevel(area:GetFrameLevel()+18)
    legend:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=9})
    legend:SetBackdropColor(.025,.044,.078,.95)
    self.navigatorDiscoveryLegend=legend
    self.navigatorMapIconFilters={}
    for i,t in ipairs(self.discoveryIconTypes) do
      local key=t.key
      local check=CreateFrame("CheckButton",nil,legend,"UICheckButtonTemplate")
      check:SetSize(19,19)
      check:SetPoint("TOPLEFT",legend,"TOPLEFT",4,-5-(i-1)*22)
      if check.text then check.text:SetText("") end
      check:SetChecked(self.mapPinVisible[key]~=false)
      local icon=legend:CreateTexture(nil,"OVERLAY")
      icon:SetSize(19,19);icon:SetPoint("LEFT",check,"RIGHT",0,0)
      icon:SetTexture(self.discoveryIconTextures[key])
      local label=legend:CreateFontString(nil,"OVERLAY")
      label:SetFont(FONT,10,"")
      label:SetPoint("LEFT",icon,"RIGHT",3,0)
      label:SetText(t.label)
      label:SetTextColor(.95,.96,1)
      check:SetScript("OnClick",function(b)GHN:SetDiscoveryTypeEnabled(key,b:GetChecked())end)
      self.navigatorMapIconFilters[key]=check
    end
    legend:Hide()
    self.mapPin=Image(area,BASE.."map.tga",0,0,24,24);self.mapPin:Hide()
    local shade=NewPanel(top,12,-259,352,47,C.subtle,{.26,.41,.56,.9})
    self.mapLocation=Txt(shade,"",12,-7,333,19,13,C.gold)
    self.mapWaypointButton=Button(shade,"SET WAYPOINT",11,-24,154,20,function()GHN:SetWaypointWithMessage()end)
    self.mapOpenButton=Button(shade,"OPEN MAP",181,-24,159,20,function()GHN:OpenNativeMap()end)
    local help=NewPanel(right,0,-324,377,327,C.deep,{.42,.47,.59,.98})
    self.helpPanel=help
    Image(help,BASE.."search.tga",12,-10,29,29)
    Txt(help,"Help Me (Stuck)",46,-11,310,28,19,C.gold)
    Txt(help,"What are you having trouble with?",16,-53,339,23,13,C.white)
    self.helpIssue=1
    local choices={"Find the source / entrance","How do I travel there?","I am stuck on a step","Why was it not awarded?"}
    self.issueButton=Button(help,"CHOOSE A HELP TOPIC  v",16,-83,345,34,function()
      GHN.issueMenu:SetShown(not GHN.issueMenu:IsShown())
    end,"dark")
    Button(help,"GET HELP",190,-129,170,33,function()if GHN.issueMenu then GHN.issueMenu:Hide()end; GHN:ShowHelp()end)
    local notice=NewPanel(help,13,-176,351,138,C.subtle,{.24,.36,.46,.88})
    Txt(notice,"POSSIBLE SOLUTION",13,-13,317,24,14,C.gold)
    self.helpAnswer=Txt(notice,"Select a problem, then click Get Help. I can suggest verified steps without automating your character.",13,-43,319,83,13,C.white)
    -- The menu overlays the answer without cycling choices unexpectedly.
    local menu=NewPanel(help,16,-119,345,134,C.deep,{.45,.56,.70,1})
    menu:SetFrameLevel(help:GetFrameLevel()+20)
    menu:EnableMouse(true)
    self.issueMenu=menu;menu:Hide()
    for i,label in ipairs(choices) do
      local index=i
      Button(menu,label,5,-4-(i-1)*32,334,30,function()
        GHN.helpIssue=index
        GHN.issueButton:SetLabel(label.."  v")
        menu:Hide()
        GHN.helpAnswer:SetText("Press GET HELP for advice on this issue.")
      end,"dark")
    end
  end
  -- Class/quest coach is shown in the right column only for Leveling.
  do
    local info=NewPanel(right,0,-324,377,327,C.deep,{.42,.47,.59,.98})
    self.levelCoachPanel=info;info:Hide()
    Txt(info,"CLASS LEVELING COACH",15,-17,344,30,19,C.gold)
    self.levelCoachHeader=Txt(info,"",17,-54,335,30,16,C.blue)
    Txt(info,"RECOMMENDED OBJECTIVE",17,-96,333,23,14,C.gold)
    self.levelCoachNext=Txt(info,"",17,-124,333,61,15,C.white)
    Txt(info,"WHY THIS ROUTE",17,-204,333,25,14,C.gold)
    self.levelCoachWhy=Txt(info,"",17,-236,333,78,12,C.silver)
  end
  -- Contextual gear detail panel replaces mount-only help while reviewing gear.
  do
    local info=NewPanel(right,0,-324,377,327,C.deep,{.42,.47,.59,.98})
    self.gearContext=info;info:Hide()
    Txt(info,"Potential Gear Upgrade",18,-17,341,31,19,C.gold)
    self.gearTrackedTarget=Txt(info,"No dungeon/raid gear target saved",17,-54,340,38,12,C.blue)
    self.gearFocusName=Txt(info,"",17,-100,340,47,17,C.white)
    self.gearFocusStats=Txt(info,"",17,-151,340,34,14,C.green)
    self.gearFocusSource=Txt(info,"",17,-184,340,51,12,C.silver)
    self.gearEntranceButton=Button(info,"SHOW VERIFIED ENTRANCE ON MAP",17,-238,343,30,function()
      local ok,msg=GHN:OpenGearEntrance()
      if not ok then GHN:Log("GEAR MAP",msg or "No verified entrance") end
    end,"dark")
    self.gearEntranceButton:Hide()
    self.gearOpenSource=Button(info,"OPEN SOURCE IN ADVENTURE GUIDE",17,-274,343,32,function()
      local ok,msg=GHN:OpenGearSource()
      if not ok then GHN:Log("JOURNAL",msg or "Could not open source") end
    end,"gold")
    self.gearOpenSource:Hide()
  end
  -- Mount chooser overlay: selected journal mounts appear in the actual hero card.
  do
    local pop=NewPanel(root,330,-124,524,514,{.018,.039,.067,1},{.70,.56,.31,1})
    pop:SetFrameLevel(root:GetFrameLevel()+35)
    self.chooser=pop;pop:Hide()
    Txt(pop,"Find a mount",18,-17,370,30,22,C.gold)
    Button(pop,"CLOSE",434,-12,75,30,function()pop:Hide()end,"dark")
    Txt(pop,"Search by mount name, boss, zone or journal source",18,-53,485,24,13,C.silver)
    local search=CreateFrame("EditBox",nil,pop,"InputBoxTemplate")
    search:SetSize(462,27);search:SetPoint("TOPLEFT",pop,"TOPLEFT",25,-88)
    search:SetAutoFocus(false);search:SetTextInsets(8,8,0,0)
    search:SetScript("OnEscapePressed",function(s)s:ClearFocus();pop:Hide()end)
    search:SetScript("OnTextChanged",function()GHN.chooserPage=1;GHN:RefreshChooser()end)
    self.searchBox=search
    self.chooserMissingOnly=true
    self.chooserGuidesOnly=false
    self.missingToggle=Button(pop,"MISSING ONLY",18,-124,235,26,function()
      GHN.chooserMissingOnly=not GHN.chooserMissingOnly
      GHN.chooserPage=1
      GHN.missingToggle:SetTone(GHN.chooserMissingOnly and "selected" or nil)
      GHN:RefreshChooser()
    end,"dark")
    self.missingToggle:SetTone("selected")
    self.guidesToggle=Button(pop,"ALL SOURCES",265,-124,239,26,function()
      GHN.chooserGuidesOnly=not GHN.chooserGuidesOnly
      GHN.chooserPage=1
      GHN.guidesToggle:SetLabel(GHN.chooserGuidesOnly and "DETAILED GUIDES" or "ALL SOURCES")
      GHN.guidesToggle:SetTone(GHN.chooserGuidesOnly and "selected" or nil)
      GHN:RefreshChooser()
    end,"dark")
    self.chooserCount=Txt(pop,"",22,-154,450,20,12,C.gold)
    self.chooserRows={}
    for i=1,7 do
      local row=Button(pop,"",18,-183-(i-1)*39,486,35,function()
        local b=GHN.chooserRows[i]
        if b.mountID then GHN:PickMount(b.mountID)end
      end,"dark")
      row.caption:SetJustifyH("LEFT");row.caption:SetFont(FONT,13,"")
      self.chooserRows[i]=row
    end
    Button(pop,"PREVIOUS",18,-464,188,30,function()GHN.chooserPage=math.max(1,(GHN.chooserPage or 1)-1);GHN:RefreshChooser()end,"dark")
    Button(pop,"NEXT",312,-464,191,30,function()GHN.chooserPage=(GHN.chooserPage or 1)+1;GHN:RefreshChooser()end,"dark")
  end
  -- Supporting pages all use high-contrast, child-parented cards.
  local function PageCard(tab,title,subtitle)
    local p=self.pages[tab]
    local card=NewPanel(p,13,-42,689,569,C.deep,{.29,.46,.59,.91})
    Txt(card,title,20,-20,644,33,21,C.gold)
    Txt(card,subtitle,21,-60,641,52,14,C.white)
    return card,p
  end
  -- Character stage: the revised 1024x1024 spec/faction painting surrounds
  -- an actual 3-D player model. A separate, transparent 2048x1024 Gear Hunter
  -- Midnight frame decorates the stage. No artwork is baked into the model.
  do
    local page=self.pages.Character
    self.characterStage=NewPanel(page,17,-37,611,602,C.deep,{.58,.53,.29,1})
    self.characterScene=Image(self.characterStage,BASE.."shield.tga",5,-5,601,592)
    self.characterScene:SetTexCoord(0,1,0,1)
    self.characterModelNeedsRefresh=true
    local ok,model=pcall(CreateFrame,"DressUpModel",nil,self.characterStage)
    if not ok or not model then ok,model=pcall(CreateFrame,"PlayerModel",nil,self.characterStage) end
    if ok and model then
      -- Fixed scene podium; PlaceCharacterAtPodium anchors model's bottom
      -- independently of size. The separate paper-doll remains untouched.
      model:SetSize(579,481)
      model:SetPoint("BOTTOM",self.characterStage,"TOP",0,-(602*.84))
      model:EnableMouse(true)
      self.characterModel=model
      model:SetScript("OnMouseDown",function(m,button)
        if button~="LeftButton"then return end
        local x=GetCursorPosition and GetCursorPosition()
        if type(x)~="number"then return end
        m._lastX=x
        m._dragging=true
      end)
      model:SetScript("OnMouseUp",function(m) m._dragging=false;m._lastX=nil end)
      model:SetScript("OnHide",function(m)m._dragging=false;m._lastX=nil end)
      model:SetScript("OnUpdate",function(m)
        if not m._dragging then return end
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton")then m._dragging=false;return end
        local x=GetCursorPosition and GetCursorPosition()
        if type(x)~="number"then return end
        local dx=x-(m._lastX or x);m._lastX=x
        if dx~=0 then GHN:SetCharacterFacing((GHN.characterFacing or 0)+dx*.012)end
      end)
    else
      Txt(self.characterStage,"Live model unavailable on this game client.",31,-270,550,42,16,C.warn)
    end
    -- Art-only overlay; positioned above the model but no mouse input.
    local over=CreateFrame("Frame",nil,self.characterStage)
    over:SetAllPoints(self.characterStage)
    over:SetFrameLevel((model and model.GetFrameLevel and model:GetFrameLevel() or self.characterStage:GetFrameLevel())+2)
    self.characterOrnateFrame=Image(over,BASE.."shield.tga",0,0,611,602)
    self.characterOrnateFrame:SetTexCoord(0,1,0,1)
    self.characterViewLabel=Txt(over,"FEET ANCHORED TO PLATFORM | DRAG TO ROTATE",79,-560,456,23,12,C.gold)
    -- Slots flank the model, like the original Gear Hunter paper doll. Their
    -- parent is above the decorative frame to avoid the old mouse/visual bleed.
    self.characterEquipmentSlots={}
    local slotLayer=CreateFrame("Frame",nil,self.characterStage)
    slotLayer:SetAllPoints(self.characterStage)
    slotLayer:SetFrameLevel(over:GetFrameLevel()+3)
    self.characterEquipmentLayer=slotLayer
    for i,entry in ipairs(PAPER_DOLL_SLOTS) do
      local side=math.floor((i-1)/8)
      local row=(i-1)%8
      local x=side==0 and 14 or 548
      local y=-69-row*58
      local b=CreateFrame("Button",nil,slotLayer)
      b:SetSize(49,49)
      b:SetPoint("TOPLEFT",slotLayer,"TOPLEFT",x,y)
      b.slotID=entry[1]
      b.slotName=entry[2]
      local bg=b:CreateTexture(nil,"BACKGROUND")
      bg:SetAllPoints(b);bg:SetColorTexture(.025,.045,.075,.96)
      local edge=b:CreateTexture(nil,"BORDER")
      edge:SetAllPoints(b)
      edge:SetColorTexture(.55,.40,.18,.5)
      edge:SetPoint("TOPLEFT",b,"TOPLEFT",0,0)
      b.icon=b:CreateTexture(nil,"ARTWORK")
      b.icon:SetPoint("TOPLEFT",b,"TOPLEFT",4,-4)
      b.icon:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",-4,4)
      b.slotMarker=Txt(b,tostring(i),12,-16,27,20,12,C.dim)
      b.slotMarker:SetJustifyH("CENTER")
      b:SetScript("OnEnter",function(button)
        if not GameTooltip then return end
        GameTooltip:SetOwner(button,"ANCHOR_RIGHT")
        local shown=false
        local hasLink=false
        if GetInventoryItemLink and GameTooltip.SetInventoryItem then
          local good,link=pcall(GetInventoryItemLink,"player",button.slotID)
          hasLink=good and link~=nil
          if hasLink then
            local worked=pcall(GameTooltip.SetInventoryItem,GameTooltip,"player",button.slotID)
            shown=worked
          end
        end
        if not shown then GameTooltip:SetText(button.slotName..(hasLink and " (details unavailable)" or " (empty)")) end
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide()end end)
      b:SetScript("OnClick",function()
        GHN:Select("Gear")
        GHN:SetGearView("Equipped")
      end)
      self.characterEquipmentSlots[#self.characterEquipmentSlots+1]=b
    end
    local details=NewPanel(page,641,-37,440,602,C.deep,{.60,.51,.29,1})
    Txt(details,"YOUR GEAR HUNTER CHARACTER",19,-20,401,31,21,C.gold)
    self.characterStageStatus=Txt(details,"Loading your class scene...",20,-72,403,48,14,C.white)
    self.characterStageSummary=Txt(details,"",20,-138,395,94,17,C.silver)
    Txt(details,"CHARACTER SIZE / FLOOR ANCHOR",18,-248,410,29,16,C.gold)
    self.characterViewSettings=Txt(details,"",21,-281,395,40,13,C.white)
    Button(details,"LARGER",21,-332,190,38,function()GHN:AdjustCharacterCamera(-.08,0)end)
    Button(details,"SMALLER",228,-332,190,38,function()GHN:AdjustCharacterCamera(.08,0)end,"dark")
    Button(details,"FEET UP 8PX",21,-382,190,38,function()GHN:AdjustCharacterCamera(0,-8)end,"dark")
    Button(details,"FEET DOWN 8PX",228,-382,190,38,function()GHN:AdjustCharacterCamera(0,8)end,"dark")
    Button(details,"RESET VIEW",21,-439,397,36,function()
       GHN.db.characterCamScale=.95;GHN.db.characterGroundAdjustment=0;GHN.db.characterHeightOffset=nil
       GHN:SetCharacterFacing(0);GHN:ApplyCharacterCamera()
    end,"gold")
    Button(details,"REFRESH WORN GEAR",21,-486,397,34,function()
      GHN.characterModelNeedsRefresh=true
      GHN:RefreshCharacterStage(true)
    end,"gold")
    self.characterGearSummary=Txt(details,"Equipped gear: loading...",21,-530,398,25,13,C.white)
    Txt(details,"Your current character, equipped icons and appearance. Drag to rotate; no items are equipped or changed.",21,-558,394,43,12,C.silver)
  end
  do
    local card=PageCard("Dashboard","What's My Best Move?","Navigator uses your saved goals and available game information to suggest a next step.")
    local rec=NewPanel(card,18,-129,653,186,C.subtle,{.25,.49,.77,.94})
    self.recTitle=Txt(rec,"",18,-19,600,53,19,C.white)
    self.recWhy=Txt(rec,"",18,-91,602,82,14,C.silver)
    Button(card,"DO SUGGESTED ACTIVITY",18,-350,201,44,function()GHN:OpenAdventureChoice()end)
    Button(card,"DISCOVER NEARBY",237,-350,201,44,function()GHN:Select("Map")end)
    Button(card,"REFRESH",453,-350,216,44,function()GHN:Refresh()end)
    self.adventurePreviewButtons={}
    for i=1,3 do
      local idx=i
      local b=Button(card,"",20,-431-(i-1)*41,647,36,function()
        GHN:OpenAdventureChoice(GHN.adventurePreviewList and GHN.adventurePreviewList[idx])
      end,"dark")
      b.caption:SetJustifyH("LEFT")
      b.caption:SetFont(FONT,12,"")
      self.adventurePreviewButtons[i]=b
    end
  end
  do
    local card=PageCard("Leveling","Your Class Leveling Guide","Recommended next steps use your class, level, zone and active quests. No automated movement or unverified fastest-route claims.")
    self.levelHeader=Txt(card,"",22,-125,624,34,19,C.blue)
    self.levelNext=Txt(card,"",22,-171,632,55,17,C.green)
    self.levelAdvice=Txt(card,"",22,-238,632,103,14,C.white)
    self.levelCombat=Txt(card,"",22,-352,632,87,14,C.silver)
    self.levelMilestone=Txt(card,"",22,-454,632,36,13,C.gold)
    Button(card,"WHAT'S MY BEST MOVE?",22,-507,250,38,function()
      local plan=GHN:GetLevelingPlan(GHN:GetCharacterSummary())
      if plan and plan.quest then
        local ok,msg=GHN:OpenLevelingQuestLog()
        if not ok and GHN.levelCoachWhy then GHN.levelCoachWhy:SetText(msg) end
      else
        GHN:OpenNativeMap() -- Explore actual in-game quest markers, not fictional waypoints.
      end
    end)
    Button(card,"OPEN QUEST LOG",282,-507,177,38,function()
      local ok,msg=GHN:OpenLevelingQuestLog()
      if not ok and GHN.levelCoachWhy then GHN.levelCoachWhy:SetText(msg) end
    end,"dark")
    Button(card,"FIND GEAR",469,-507,177,38,function()GHN:Select("Gear")end,"gold")
  end
  do
    local card=PageCard("Gear","Find Gear Upgrades","Shows equipment with a required character level within your +5 (or optional +10) range. +1 iLvl counts. Sources are not guaranteed drops.")
    self.gearLevel=Txt(card,"",22,-116,486,25,15,C.blue)
    self.gearRangeButton=Button(card,"RANGE +5",520,-108,145,29,function()
      GHN:ToggleGearAheadLevels()
    end,"dark")
    self.gearView="Upgrades"
    self.gearSource="bags"
    self.gearShowUpgrades=Button(card,"POTENTIAL UPGRADES",20,-149,207,34,function()GHN:SetGearView("Upgrades")end)
    self.gearShowEquipped=Button(card,"EQUIPPED ITEMS",241,-149,184,34,function()GHN:SetGearView("Equipped")end,"dark")
    self.gearScanBags=Button(card,"SCAN BAGS",440,-149,226,34,function()
      GHN.gearSource="bags";GHN.gearScanDirty=true;GHN.gearUpgradePage=1;GHN.gearSelected=nil
      GHN:SetGearView("Upgrades")
    end,"gold")
    self.gearFindJournal=Button(card,"FIND DUNGEON/RAID GEAR (JOURNAL)",20,-190,646,31,function()
      GHN.gearSource="journal";GHN.gearUpgradePage=1;GHN.gearSelected=nil
      GHN:ScanJournalUpgrades()
      GHN:SetGearView("Upgrades")
    end,"gold")
    self.gearTierButton=Button(card,"EXP: LATEST >",20,-226,270,28,function()
      GHN.gearSource="journal";GHN.gearUpgradePage=1;GHN.gearSelected=nil
      GHN:CycleGearJournalTier()
    end,"dark")
    self.gearKindButton=Button(card,"SOURCE: ALL >",300,-226,174,28,function()
      GHN.gearSource="journal";GHN.gearUpgradePage=1;GHN.gearSelected=nil
      GHN:CycleGearJournalType()
    end,"dark")
    self.gearDifficultyButton=Button(card,"DIFF: NORMAL >",484,-226,182,28,function()
      GHN.gearSource="journal";GHN.gearUpgradePage=1;GHN.gearSelected=nil
      GHN:CycleGearJournalDifficulty()
    end,"dark")
    self.gearTierButton:Hide();self.gearKindButton:Hide();self.gearDifficultyButton:Hide()
    local equipPane=CreateFrame("Frame",nil,card)
    equipPane:SetAllPoints(card);self.gearEquippedPane=equipPane
    self.gearLines={};self.gearTooltips={}
    for i=1,16 do
      local col=math.floor((i-1)/8);local row=(i-1)%8
      local slotFrame=CreateFrame("Frame",nil,equipPane)
      slotFrame:SetPoint("TOPLEFT",card,"TOPLEFT",22+col*324,-246-row*39)
      slotFrame:SetSize(315,40);slotFrame:EnableMouse(true)
      slotFrame:SetScript("OnEnter",function(f)
        if not (GameTooltip and GetInventoryItemLink and f.slotID) then return end
        local ok,link=pcall(GetInventoryItemLink,"player",f.slotID)
        if not ok or not link then return end
        GameTooltip:SetOwner(f,"ANCHOR_RIGHT")
        local shown=pcall(function()GameTooltip:SetInventoryItem("player",f.slotID)end)
        if shown then GameTooltip:Show() end
      end)
      slotFrame:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide()end end)
      self.gearLines[i]=Txt(slotFrame,"",1,-1,309,39,12,C.white)
      self.gearTooltips[i]=slotFrame
    end
    local upgrades=CreateFrame("Frame",nil,card);upgrades:SetAllPoints(card)
    self.gearUpgradesPane=upgrades
    self.gearScanSummary=Txt(upgrades,"Scan bags or find dungeon/raid gear",22,-258,641,24,13,C.green)
    self.gearUpgradeRows={}
    for i=1,6 do
      local row=Button(upgrades,"",19,-286-(i-1)*36,647,33,function()
        local r=GHN.gearUpgradeRows[i]
        if r.item then
          GHN.gearSelected=r.item
          GHN.gearSelectedData=GHN.gearSource=="journal" and GHN.journalScan or GHN.gearScan
          GHN:RenderGearUpgrades()
        end
      end,"dark")
      row.caption:SetJustifyH("LEFT");row.caption:SetFont(FONT,13,"")
      row:SetScript("OnEnter",function(b)
        b.bg:SetColorTexture(.12,.23,.33,.98)
        if b.item and GameTooltip then
          GameTooltip:SetOwner(b,"ANCHOR_RIGHT")
          if pcall(function()GameTooltip:SetHyperlink(b.item.link)end) then GameTooltip:Show() end
        end
      end)
      row:SetScript("OnLeave",function(b)
        b:SetTone(b.tone)
        if GameTooltip then GameTooltip:Hide() end
      end)
      self.gearUpgradeRows[i]=row
    end
    self.gearNoResults=Txt(upgrades,"",20,-504,638,31,12,C.silver)
    Button(upgrades,"PREV",21,-539,105,27,function()
      GHN.gearUpgradePage=math.max(1,(GHN.gearUpgradePage or 1)-1);GHN:RenderGearUpgrades()
    end,"dark")
    Button(upgrades,"NEXT",562,-539,105,27,function()
      GHN.gearUpgradePage=(GHN.gearUpgradePage or 1)+1;GHN:RenderGearUpgrades()
    end,"dark")
    self.gearTrackTarget=Button(upgrades,"TRACK SELECTED GEAR",143,-539,400,27,function()
      local ok,msg=GHN:TrackGearTarget()
      if not ok and msg then GHN:Log("GEAR",msg) end
      GHN:RenderGearUpgrades()
    end,"gold")
    self.gearUpgradesPane:Show();self.gearEquippedPane:Hide()
    -- The top controls are persistent across both content panes. Parent them
    -- above the panes so equipped rows and journal controls never overlap.
    local actions=CreateFrame("Frame",nil,card)
    actions:SetSize(689,262)
    actions:SetPoint("TOPLEFT",card,"TOPLEFT",0,0)
    actions:SetFrameLevel(card:GetFrameLevel()+12)
    for _,btn in ipairs({self.gearShowUpgrades,self.gearShowEquipped,self.gearScanBags,self.gearFindJournal,self.gearTierButton,self.gearKindButton,self.gearDifficultyButton})do
      btn:SetParent(actions)
    end
    self.gearShowUpgrades:SetTone("selected")
  end
  do
    -- The complete original Gear Hunter tools are REAL children of this page.
    -- They do not create a new addon frame or depend on the GearHunter addon.
    -- Original Gear Hunter has its own faithful full-frame child of Navigator.
    -- This placeholder page is never used as an imitation of that layout.
  end
  do
    local card=PageCard("Map","Rare & Treasure Explorer","Known MapHub rare spawns, treasures and secrets. Pins are possibilities, not live detections.")
    self.discoveryZone=Txt(card,"Loading your zone...",22,-111,641,27,18,C.gold)
    self.discoverySummary=Txt(card,"",22,-143,645,22,13,C.silver)
    local input=CreateFrame("EditBox",nil,card,"InputBoxTemplate")
    input:SetSize(393,27);input:SetPoint("TOPLEFT",card,"TOPLEFT",27,-172)
    input:SetAutoFocus(false);input:SetMaxLetters(70)
    input:SetScript("OnTextChanged",function(f)
      GHN.discoveryQuery=f:GetText() or "";GHN.discoveryPage=1;GHN:RefreshDiscoveries()
    end)
    self.discoverySearch=input
    Button(card,"CLEAR SEARCH",450,-171,213,28,function()
      GHN.discoverySearch:SetText("");GHN.discoverySearch:ClearFocus()
    end,"dark")
    self.discoveryCategoryButtons={}
    for i,key in ipairs({"All","Rare","Treasure","Secret"}) do
      local chosen=key
      local b=Button(card,key=="All" and "ALL LOCATIONS" or key:upper(),19+(i-1)*164,-206,155,28,function()
        GHN.discoveryCategory=chosen;GHN.discoveryPage=1;GHN:RefreshDiscoveries()
      end,"dark")
      if key~="All" then
        local icon=b:CreateTexture(nil,"OVERLAY")
        icon:SetSize(23,23);icon:SetPoint("LEFT",b,"LEFT",8,0)
        icon:SetTexture(self:DiscoveryIcon(key))
        b.caption:ClearAllPoints();b.caption:SetPoint("TOPLEFT",b,"TOPLEFT",34,-5)
        b.caption:SetSize(119,21)
      end
      self.discoveryCategoryButtons[key]=b
    end
    self.discoveryRows={}
    for i=1,8 do
      local b=Button(card,"",19,-233-(i-1)*32,647,30,function()
        local r=GHN.discoveryRows[i].record
        if r then GHN.discoverySelected=r;GHN:RefreshDiscoveries()end
      end,"dark")
      b.caption:SetJustifyH("LEFT");b.caption:SetFont(FONT,12,"")
      b.caption:ClearAllPoints();b.caption:SetPoint("TOPLEFT",b,"TOPLEFT",33,-5)
      b.caption:SetSize(607,24)
      b.discoveryIcon=b:CreateTexture(nil,"OVERLAY")
      b.discoveryIcon:SetSize(24,24);b.discoveryIcon:SetPoint("LEFT",b,"LEFT",6,0)
      b:SetScript("OnEnter",function(f)
        if not f.record or not GameTooltip then return end
        GameTooltip:SetOwner(f,"ANCHOR_RIGHT")
        GameTooltip:AddLine(f.record.name,1,.8,.4)
        GameTooltip:AddLine(string.format("Map: %s   Coordinates %.1f, %.1f",GHN:DiscoveryMapName(f.record.mapID),f.record.x,f.record.y),1,1,1)
        GameTooltip:AddLine(f.record.description or "Known map location, not a live spawn notification.",.75,.83,.94,true)
        GameTooltip:AddLine("Source: "..(f.record.source or "Our MapHub records"),.66,.78,.88,true)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave",function(f)f:SetTone(f.tone);if GameTooltip then GameTooltip:Hide()end end)
      self.discoveryRows[i]=b
    end
    Button(card,"< PREV",19,-494,139,28,function()GHN.discoveryPage=math.max(1,(GHN.discoveryPage or 1)-1);GHN:RefreshDiscoveries()end,"dark")
    Button(card,"NEXT >",167,-494,139,28,function()GHN.discoveryPage=(GHN.discoveryPage or 1)+1;GHN:RefreshDiscoveries()end,"dark")
    self.discoveryVisitedButton=Button(card,"HIDE VISITED: OFF",317,-494,180,28,function()
      GHN.discoveryHideVisited=not GHN.discoveryHideVisited;if GHN.db then GHN.db.discoveryHideVisited=GHN.discoveryHideVisited end;GHN.discoveryPage=1;GHN:RefreshDiscoveries()
    end,"dark")
    self.discoveryMarkButton=Button(card,"MARK VISITED",503,-494,163,28,function()
      if GHN.discoverySelected then GHN:ToggleDiscoveryVisited(GHN.discoverySelected);GHN:RefreshDiscoveries()end
    end,"gold")
    self.discoveryInfo=Txt(card,"",22,-530,638,30,12,C.silver)
    Button(card,"OPEN FULL WORLD MAP WITH RARE / TREASURE PINS",22,-550,643,27,function()
      local ok,msg=GHN:OpenFullMapHub()
      if not ok then GHN.discoveryInfo:SetText(msg)end
    end,"gold")
  end
  do
    local card=PageCard("Intelligence","Navigator Intelligence","Local learning: saved goals, completed steps, logged attempts and measured waypoint arrivals.")
    self.intStatus=Txt(card,"",23,-116,627,28,19,C.green)
    self.intSummary=Txt(card,"",23,-160,625,55,15,C.white)
    self.intPriority=Txt(card,"",23,-221,620,36,15,C.gold)
    self.intRecent=Txt(card,"",23,-269,632,57,14,C.silver)
    for i,label in ipairs({"Auto","Mounts","Gear","Rares","Leveling"})do
      Button(card,label,20+(i-1)*134,-356,127,40,function()GHN:SetPriority(label);GHN:Refresh()end)
    end
    self.pauseButton=Button(card,"PAUSE LEARNING",22,-415,234,42,function()GHN:ToggleLearning();GHN:Refresh()end)
    self.resetArmed=false
    self.resetButton=Button(card,"CLEAR MY HISTORY",286,-415,259,42,function()
      if not GHN.resetArmed then GHN.resetArmed=true;GHN.resetHint:SetText("Click CLEAR MY HISTORY again to confirm.")
      else GHN.resetArmed=false;GHN:ResetMyLearning();GHN.resetHint:SetText("Your character's learning history has been cleared.");GHN:Refresh()end
    end,"dark")
    self.resetHint=Txt(card,"",23,-479,625,42,14,C.warn)
  end
  do
    local card=PageCard("Diagnostics","Navigator Diagnostics","Recent addon-local events. Diagnostics cannot read game crashes or protected memory.")
    self.diagnosticRows={}
    for i=1,8 do self.diagnosticRows[i]=Txt(card,"",18,-118-(i-1)*44,651,39,12,C.white)end
    Button(card,"TEST LOGGING",20,-485,219,35,function()GHN:Log("TEST","Navigator 0.3.9 diagnostics working");GHN:Refresh()end)
    Button(card,"CLEAR LOG",256,-485,216,35,function()if GHN.db then wipe(GHN.db.diagnostic)end;GHN:Refresh()end,"dark")
  end
  do
    local card=PageCard("Help Me (Stuck)","Help Me (Stuck)","Use the help selector on the right. Answers are based on the selected verified guide.")
    Txt(card,"Find any mount using the Mount Journal search. Detailed acquisition steps are included for several rare mounts. Other mounts receive a labeled source-based planning checklist.\n\nSelect your mount, choose a step, and use Help Me on the right for context. Exact map waypoints are only available where verified.",22,-140,630,230,17,C.white)
    Button(card,"SEARCH MOUNTS",22,-417,295,42,function()GHN:Select("Mounts");GHN:OpenChooser()end)
  end
  -- Live journal pages: every section has its own source and controls.
  for _,entry in ipairs({
    {"Quests","Active Quest Guide","Your actual quest log and unfinished objectives. Track a quest or open the Blizzard log."},
    {"Reputation","Your Reputations","Reputation standings and Renown reported by your character's WoW client."},
    {"Collections","Mounts & Toys","Search owned mounts and toys. Change the display to include uncollected items."},
  }) do
    self:CreateProgressPage(entry[1],entry[2],entry[3])
  end
  local placeholder={
    ["Dungeons & Raids"]={"Raids and Dungeons","Use Gear Hunter's Boss Loot page for current encounters and known loot."},
    ["Achievements"]={"Achievements","Achievement goals and progress are not yet integrated."},
  }
  for tab,info in pairs(placeholder)do
    local card=PageCard(tab,info[1],info[2])
    Txt(card,"This section has not been populated with verified objectives yet.",24,-172,623,115,16,C.silver)
    Button(card,tab=="Dungeons & Raids" and "OPEN BOSS LOOT HUNTER" or "OPEN ADVENTURE PLANNER",22,-379,320,41,function()
      if tab=="Dungeons & Raids" then GHN:Select("Gear Hunter") else GHN:Select("Dashboard") end
    end)
  end
  -- Keep existing selections and character history. First launch of the new UI
  -- showcases the approved mount-guide layout, instead of the old blank dashboard.
  if self.db.layoutVersion ~= 2 then
    self.db.layoutVersion=2
    self.db.tab="Mounts"
  end
  if self.GearEngine and self.GearEngine.CreateUI then
    self:Safe("Create Original Gear Hunter",function()self.GearEngine:CreateUI()end)
  end
  screen:Hide()
  self:Select(self.db.tab or "Mounts")
end
function GHN:SetWaypointWithMessage()
  if self.db and self.db.tab=="Leveling" then
    if self.levelCoachWhy then self.levelCoachWhy:SetText("Leveling guide has no verified quest coordinates. Open WoW map for active quest markers.") end
    return
  end
  if self.db and self.db.tab=="Map" then
    local ok,msg=self:SetDiscoveryWaypoint(self.discoverySelected)
    if self.discoveryInfo then self.discoveryInfo:SetText(msg)end
    return
  end
  local _,g=self:SelectedGuide()
  if not g or not (g.mapID and g.x and g.y) then self.helpAnswer:SetText("There is no verified waypoint for this mount yet. Its journal source and steps remain available.");return end
  local _,msg=self:TakeMeThere(g)
  self.helpAnswer:SetText(msg or "Waypoint action completed.")
end
function GHN:OpenNativeMap()
  if InCombatLockdown and InCombatLockdown() then
    self.helpAnswer:SetText("Map action unavailable while in combat.")
    return
  end
  local _,g=self:SelectedGuide()
  if self.db and self.db.tab~="Mounts" and self.db.tab~="Help Me (Stuck)" then g=nil end
  local wasShown=self.frame and self.frame:IsShown()
  if wasShown then self.frame:Hide() end
  local opened=false
  if g and g.mapID and g.x and g.y and OpenWorldMap then
    opened=pcall(OpenWorldMap,g.mapID)
  elseif ToggleWorldMap then
    opened=pcall(ToggleWorldMap)
  elseif OpenWorldMap then
    opened=pcall(OpenWorldMap)
  end
  -- Only treat a visible Blizzard map as a successful open.
  if opened and WorldMapFrame and WorldMapFrame.IsShown and not WorldMapFrame:IsShown() then
    opened=false
  end
  if not opened then
    if wasShown then self.frame:Show() end
    self.helpAnswer:SetText("World Map could not be opened. Try the normal WoW map key.")
    return
  end
  if wasShown and WorldMapFrame and WorldMapFrame.HookScript then
    self.restoreAfterWorldMap=true
    if not self.mapCloseHookInstalled then
      self.mapCloseHookInstalled=true
      WorldMapFrame:HookScript("OnHide",function()
        if GHN.restoreAfterWorldMap then
          GHN.restoreAfterWorldMap=false
          if GHN.frame and not GHN.frame:IsShown() then GHN.frame:Show() end
        end
      end)
    end
  end
  -- If WoW doesn't expose WorldMapFrame, /ghnav reopens Navigator.
end
