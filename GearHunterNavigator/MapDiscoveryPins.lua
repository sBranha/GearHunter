local ADDON,NAV=...
local provider
NAV.mapPinHideVisited=false

GHNDiscoveryPinMixin=CreateFromMixins(MapCanvasPinMixin)
function GHNDiscoveryPinMixin:OnLoad()
 self:SetSize(22,22)
 self.caption=self:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
 self.caption:SetPoint("LEFT",self,"RIGHT",3,0)
 self.caption:SetShadowOffset(1,-1)
 self.caption:SetShadowColor(0,0,0,1)
end
function GHNDiscoveryPinMixin:OnAcquired(record)
 self.record=record
 self:SetPosition(record.x/100,record.y/100)
 self.Icon:SetTexture(NAV:DiscoveryIcon(record.category))
 local visited=NAV:DiscoveryVisited(record)
 self.Icon:SetVertexColor(visited and .55 or 1,visited and .55 or 1,visited and .55 or 1,visited and .65 or 1)
 self.caption:SetText(record.category=="Rare" and record.name or "")
 self.caption:SetShown(record.category=="Rare")
end
function GHNDiscoveryPinMixin:OnMouseEnter()
 if not (self.record and GameTooltip) then return end
 local r=self.record
 GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
 GameTooltip:AddLine(r.name,1,.84,.42)
 GameTooltip:AddLine((r.category or "Discovery").." | "..string.format("%.1f, %.1f",r.x,r.y),.8,.9,1)
 GameTooltip:AddLine("Known location; spawn availability is not confirmed.",.8,.8,.8,true)
 if r.source then GameTooltip:AddLine("Source: "..r.source,.7,.85,1,true) end
 GameTooltip:AddLine("Left-click: waypoint   Right-click: visited",.8,.9,.8)
 GameTooltip:Show()
end
function GHNDiscoveryPinMixin:OnMouseLeave() if GameTooltip then GameTooltip:Hide() end end
function GHNDiscoveryPinMixin:OnClick(button)
 if not self.record then return end
 if button=="RightButton" then
   NAV:ToggleDiscoveryVisited(self.record)
   NAV:RefreshMapDiscoveryPins()
   if NAV.RefreshDiscoveries then NAV:RefreshDiscoveries() end
 else NAV:SetDiscoveryWaypoint(self.record) end
end
local function getPins(id)
 local found={}
 if type(id)~="number" then return found end
 for _,r in ipairs(NAV:GetZoneDiscoveries(id)) do
  if NAV:DiscoveryTypeVisible(r.category) and (not NAV.mapPinHideVisited or not NAV:DiscoveryVisited(r)) then
   found[#found+1]=r
  end
 end
 return found
end
function NAV:RefreshMapDiscoveryPins()
 if provider and provider.GetMap and provider:GetMap() then provider:RefreshAllData() end
end
local function installFilters(map)
 if map.GHNPinFilters then return end
 local btn=CreateFrame("Button",nil,map,"UIPanelButtonTemplate")
 btn:SetSize(142,24);btn:SetPoint("TOPRIGHT",map,"TOPRIGHT",-16,-34)
 btn:SetText("Navigator Icons")
 map.GHNPinFilters=btn
 local menu=CreateFrame("Frame",nil,map,"BackdropTemplate")
 menu:SetSize(221,304);menu:SetPoint("TOPRIGHT",map,"TOPRIGHT",-10,-62)
 menu:SetFrameStrata("DIALOG")
 menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
 menu:SetBackdropColor(.025,.050,.083,.98);menu:Hide()
 NAV.worldMapIconFilters={}
 for i,t in ipairs(NAV.discoveryIconTypes) do
  local key=t.key
  local b=CreateFrame("CheckButton",nil,menu,"UICheckButtonTemplate")
  b:SetSize(23,23);b:SetPoint("TOPLEFT",menu,"TOPLEFT",9,-8-(i-1)*30)
  if b.text then b.text:SetText("") end
  b:SetChecked(NAV.mapPinVisible[key]~=false)
  local tex=menu:CreateTexture(nil,"ARTWORK")
  tex:SetSize(24,24);tex:SetPoint("LEFT",b,"RIGHT",1,0)
  tex:SetTexture(NAV.discoveryIconTextures[key])
  local label=menu:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  label:SetPoint("LEFT",tex,"RIGHT",5,0);label:SetText(t.label)
  b:SetScript("OnClick",function(w)NAV:SetDiscoveryTypeEnabled(key,w:GetChecked())end)
  NAV.worldMapIconFilters[key]=b
 end
 local hide=CreateFrame("CheckButton",nil,menu,"UICheckButtonTemplate")
 hide:SetPoint("TOPLEFT",10,-256)
 if hide.text then hide.text:SetText("Hide visited") end
 hide:SetChecked(NAV.mapPinHideVisited)
 hide:SetScript("OnClick",function(w)
   NAV.mapPinHideVisited=w:GetChecked()
   NAV.discoveryHideVisited=NAV.mapPinHideVisited
   if NAV.db then NAV.db.discoveryHideVisited=NAV.mapPinHideVisited end
   NAV:RefreshMapDiscoveryPins()
   if NAV.RefreshDiscoveries then NAV:RefreshDiscoveries() end
 end)
 btn:SetScript("OnClick",function()menu:SetShown(not menu:IsShown())end)
end
function NAV:InstallMapDiscoveryPins()
 local map=WorldMapFrame
 self:InitializeDiscoveryFilters()
 if not (map and map.AddDataProvider and MapCanvasDataProviderMixin) then return false end
 if not provider then
  provider=CreateFromMixins(MapCanvasDataProviderMixin)
  function provider:RemoveAllData()
    if self:GetMap() then self:GetMap():RemoveAllPinsByTemplate("GHNDiscoveryPinTemplate") end
  end
  function provider:OnMapChanged()self:RefreshAllData() end
  function provider:OnShow()self:RefreshAllData() end
  function provider:RefreshAllData()
    self:RemoveAllData()
    local canvas=self:GetMap()
    local id=canvas and canvas.GetMapID and canvas:GetMapID()
    if not id then return end
    for _,r in ipairs(getPins(id)) do
      local ok,err=pcall(canvas.AcquirePin,canvas,"GHNDiscoveryPinTemplate",r)
      if not ok then
        if not self.warned then self.warned=true;NAV:Log("MAP_PINS",tostring(err)) end
        break
      end
    end
  end
 end
 if not map.GHNDiscoveryProvider then
  local ok,err=pcall(map.AddDataProvider,map,provider)
  if not ok then NAV:Log("MAP_PINS",err);return false end
  map.GHNDiscoveryProvider=provider
 end
 installFilters(map)
 self:RefreshMapDiscoveryPins()
 return true
end
local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent",function(_,event,name)
 if event=="PLAYER_LOGIN" or (event=="ADDON_LOADED" and name=="Blizzard_WorldMap") then
  if C_Timer and C_Timer.After then C_Timer.After(.5,function()NAV:InstallMapDiscoveryPins()end)
  else NAV:InstallMapDiscoveryPins() end
 end
end)
