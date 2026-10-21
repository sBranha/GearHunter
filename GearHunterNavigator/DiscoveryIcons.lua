local ADDON, NAV = ...
-- These eight transparent TGA textures were extracted from the user's
-- approved Rares & Treasures screenshot (2026-10-20), NOT substitute icons.
-- Single source of truth for Navigator's preview, list, and World Map pins.
local root = "Interface\\AddOns\\GearHunterNavigator\\Art\\DiscoveryIcons\\"
NAV.discoveryIconTypes = {
  {key="Rare", label="Rares"},
  {key="Treasure", label="Treasures"},
  {key="EliteRare", label="Elite Rares"},
  {key="WorldBoss", label="World Bosses"},
  {key="Secret", label="Secrets"},
  {key="Quest", label="Quests"},
  {key="Vendor", label="Vendors"},
  {key="FlightPath", label="Flight Paths"},
}
NAV.discoveryIconTextures = {
  Rare=root.."Rare.tga", Treasure=root.."Treasure.tga",
  EliteRare=root.."EliteRare.tga", WorldBoss=root.."WorldBoss.tga",
  Secret=root.."Secret.tga", Quest=root.."Quest.tga",
  Vendor=root.."Vendor.tga", FlightPath=root.."FlightPath.tga",
}
local aliases = {
  ["rare"]="Rare",["rares"]="Rare",
  ["treasure"]="Treasure",["treasures"]="Treasure",["chest"]="Treasure",["chests"]="Treasure",
  ["eliterare"]="EliteRare",["eliterares"]="EliteRare",["elite"]="EliteRare",
  ["worldboss"]="WorldBoss",["worldbosses"]="WorldBoss",
  ["secret"]="Secret",["secrets"]="Secret",
  ["quest"]="Quest",["quests"]="Quest",
  ["vendor"]="Vendor",["vendors"]="Vendor",
  ["flightpath"]="FlightPath",["flightpaths"]="FlightPath",
}
function NAV:DiscoveryCategoryKey(category)
  if type(category)~="string" then return nil end
  return aliases[category:lower():gsub("[^%w]", "")]
end
function NAV:DiscoveryIcon(category)
  local key=self:DiscoveryCategoryKey(category)
  return (key and self.discoveryIconTextures[key]) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
function NAV:DiscoveryTypeVisible(category)
  local key=self:DiscoveryCategoryKey(category)
  return (not key) or not self.mapPinVisible or self.mapPinVisible[key] ~= false
end
NAV.mapPinVisible = NAV.mapPinVisible or {}
for _,category in ipairs(NAV.discoveryIconTypes) do
  if NAV.mapPinVisible[category.key] == nil then NAV.mapPinVisible[category.key]=true end
end
function NAV:InitializeDiscoveryFilters()
  if not self.db then return end
  self.db.discoveryPinFilters=self.db.discoveryPinFilters or {}
  for _,category in ipairs(self.discoveryIconTypes) do
    local saved=self.db.discoveryPinFilters[category.key]
    if saved~=nil then self.mapPinVisible[category.key]=(saved==true) end
  end
end
function NAV:SetDiscoveryTypeEnabled(key,visible)
  if not self.discoveryIconTextures[key] then return end
  self.mapPinVisible[key]=(visible==true)
  if self.db then
    self.db.discoveryPinFilters=self.db.discoveryPinFilters or {}
    self.db.discoveryPinFilters[key]=(visible==true)
  end
  if self.worldMapIconFilters then
    for k,b in pairs(self.worldMapIconFilters) do b:SetChecked(self.mapPinVisible[k]~=false) end
  end
  if self.navigatorMapIconFilters then
    for k,b in pairs(self.navigatorMapIconFilters) do b:SetChecked(self.mapPinVisible[k]~=false) end
  end
  if self.RefreshMapDiscoveryPins then self:RefreshMapDiscoveryPins() end
  if self.RefreshDiscoveries then self:RefreshDiscoveries() end
end
