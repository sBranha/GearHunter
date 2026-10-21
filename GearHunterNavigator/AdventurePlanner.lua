local ADDON,GHN=...
-- Independent deterministic multi-goal recommendations; no game automation.
local prior=GHN.GetSmartRecommendation
function GHN:GetAdventureChoices()
  local c=self:GetCharacterSummary()
  local p=self:Profile()
  local result={}
  local function offer(kind,title,why,tab,target)
    result[#result+1]={kind=kind,title=title,why=why,tab=tab,target=target}
  end
  -- For very low-level characters, the best automatic recommendation should
  -- be the current class leveling objective, not an unrelated tracked mount.
  if c.level < 10 and self.GetLevelingPlan then
    local lp=self:GetLevelingPlan(c)
    if lp then offer("Leveling",lp.title,lp.firstStep.." "..lp.combat,"Leveling") end
  end
  -- Respect a specifically tracked mount goal without pretending it is available today.
  local id=p and (p.activeMountID or self.db.mountID)
  if id and C_MountJournal and C_MountJournal.GetMountInfoByID then
    local ok,name,_,_,_,_,_,_,_,_,_,owned=pcall(C_MountJournal.GetMountInfoByID,id)
    if ok and name and not owned then
      local mount={id=id,name=name}
      local g=self:GetMountGuide(name,mount)
      if g then
        local progress=self:GuideSteps(g)
        local step
        for i,entry in ipairs(g.steps or {}) do if not progress[i] then step=entry;break end end
        offer("Mounts","Continue mount: "..name,
          step and ("Next: "..step.." | Source: "..(g.source or "Journal")) or
          "Checklist complete; check loot and collection status. Completion does not guarantee a drop.","Mounts")
      end
    end
  end
  local gear=self.journalScan and self.journalScan.results and self.journalScan.results[1]
  if not gear then gear=self.gearScan and self.gearScan.results and self.gearScan.results[1] end
  if not gear and self.FindObservedGearUpgrades then
    -- Observed vendors/quests/crafting supplement—not replace—the Encounter Journal.
    local observed=self:FindObservedGearUpgrades("","All")
    gear=observed and observed[1]
  end
  local tracked=p and p.gearTarget
  local targetLevel=tracked and (tracked.requiredLevel or (tracked.itemID and self:GetRequiredGearLevel(tracked.itemID)))
  local eligibleTarget=tracked and self:ClassifyGearLevel(targetLevel)
  if tracked and eligibleTarget then
    offer("Gear","Tracked upgrade: "..tostring(tracked.name or "Item"),
      "Source: "..tostring(tracked.source or "Check Encounter Journal")..". Required level "..tostring(targetLevel)..". Verify difficulty and stats.","Gear")
  elseif gear then
    offer("Gear","Potential gear upgrade: "..tostring(gear.name),
      "Item-level comparison suggests +"..tostring(gear.delta or "?")..". "..self:GearLevelResultLabel(gear)..". Inspect all requirements; not guaranteed Best in Slot.","Gear")
  else
    offer("Gear","Look for new equipment upgrades",
      "Scan bags or Blizzard's Encounter Journal to identify compatible loot for your specialization. No complete live loot index is assumed.","Gear")
  end
  local r=self:BestLocalDiscovery()
  if r then
    local zone=self:DiscoveryMapName(r.mapID)
    offer("Rares","Explore "..zone..": "..r.name,
      (r.category or "Discovery").." possible location: ("..string.format("%.1f, %.1f",r.x,r.y).."). Known location, not a confirmed live spawn. Open Map to navigate.","Map")
  end
  if c.level >= 10 then
    local lp=self.GetLevelingPlan and self:GetLevelingPlan(c)
    offer("Leveling",lp and lp.title or "Review level-appropriate activities",
      lp and (lp.firstStep.." "..lp.combat) or "Review your available campaigns, quests, and dungeons.","Leveling")
  end
  return result
end
local priorRecommendation=GHN.GetSmartRecommendation
function GHN:GetSmartRecommendation()
  if not self:IsLearningEnabled() then return nil end
  local p=self:Profile()
  local focus=p and p.priority or "Auto"
  local all=self:GetAdventureChoices()
  local selected
  if focus~="Auto" then
    for _,a in ipairs(all) do if a.kind==focus then selected=a;break end end
  end
  selected=selected or all[1]
  self.adventureSelected=selected
  if selected then return selected.title,selected.why end
  if priorRecommendation then return priorRecommendation(self) end
end
function GHN:OpenAdventureChoice(a)
  a=a or self.adventureSelected
  if a and a.tab=="Map" then self.discoverySelected=a.target end
  if a then self:Select(a.tab) end
end
