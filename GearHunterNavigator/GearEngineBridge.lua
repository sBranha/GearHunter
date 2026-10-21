local ADDON,NAV=...
local GH=NAV.GearEngine

-- Open the *authentic* Gear Hunter UI as a child of Navigator's one
-- fullscreen frame. It remains one installed addon and one launcher.
function NAV:ShowOriginalGearHunter()
  if not (self.frame and GH and GH.frame) then return end
  if self.layoutFrame then self.layoutFrame:Hide() end
  GH.frame:Show()
  GH:FitWindowToScreen()
  GH:ScanEquipped()
  GH:Refresh()
end

function NAV:HideOriginalGearHunter()
  if GH and GH.frame then GH.frame:Hide() end
  if GH and GH.supportFrame then GH.supportFrame:Hide() end
  if self.layoutFrame then self.layoutFrame:Show() end
end

function GH:ShowTab(tab)
  if not NAV.frame or not self.frame then return end
  NAV.frame:Show()
  if NAV.db and NAV.db.tab~="Gear Hunter" then NAV:Select("Gear Hunter") end
  if not self.frame:IsShown() then NAV:ShowOriginalGearHunter() end
  if self.SetTab then self:SetTab(tab or "Character") end
  if tab=="Weekly Farm" and self.RequestWeeklyFarmData then self:RequestWeeklyFarmData() end
end

function GH:Toggle()
  if NAV.frame and NAV.frame:IsShown() and NAV.db and NAV.db.tab=="Gear Hunter" then
    NAV.frame:Hide()
  else
    self:ShowTab(self.tab or "Character")
  end
end

-- Old internal navigation hooks now go to the authentic Gear Hunter view.
function NAV:OpenFullGearHunter(section)
  GH:ShowTab(section or "Character")
  return true,"Gear Hunter opened inside Navigator"
end

-- The existing self-contained MapHub data and world-map pins remain intact.
function NAV:OpenFullMapHub()
  if self.Select then self:Select("Map") end
  return true,"Navigator's integrated rare and treasure map opened"
end
function NAV:SyncMapHubVisited(r)
  if r then self:ToggleDiscoveryVisited(r) end
  if self.RefreshDiscoveries then self:RefreshDiscoveries() end
  if self.RefreshMapDiscoveryPins then self:RefreshMapDiscoveryPins() end
end
