-- Offline simulated WoW API checks for SmartNavigation.lua.
SlashCmdList={}
UIParent={}
function CreateFrame()
  local o={}
  function o:RegisterEvent() end
  function o:SetScript(_,fn) self.script=fn end
  return o
end
local NAV={db={},profile={}}
function NAV:Profile() return self.profile end
function NAV:CurrentDiscoveryMapID() return 123 end
function NAV:DiscoveryMapName() return "Test Zone" end
function NAV:GetZoneDiscoveries() return {
  {mapID=123,name="Far rare",category="Rare",x=89,y=90},
  {mapID=123,name="Near chest",category="Treasure",x=21,y=21}}
end
function NAV:DiscoveryTypeVisible() return true end
function NAV:DiscoveryVisited() return false end
function NAV:ReadActiveQuests() return self.quests or {} end
function NAV:QuestHelp(quest) return "Next: "..quest.name end
function NAV:GetMountGuide(name)
  return {title=name,steps={"Visit zone","Kill boss","Check journal"},
    tips={"Zone info","Boss info"},verified=true,mapID=123,x=.3,y=.4}
end
function NAV:GuideSteps() return self.completedSteps or {} end
function NAV:SetGuideStep(_,i) self.completedSteps[i]=true end
function NAV:Safe(_,fn) return pcall(fn) end
C_Map={GetPlayerMapPosition=function() return {GetXY=function()return .2,.2 end} end}
C_SuperTrack={GetSuperTrackedQuestID=function()return 9 end}
C_MountJournal={
 GetMountInfoByID=function() return "Ashes of Al'ar",nil,1,nil,nil,2,nil,nil,nil,nil,false end,
 GetMountInfoExtraByID=function() return nil,"Mount description","Tempest Keep" end
}
assert(loadfile("GearHunterNavigator/SmartNavigation.lua"))("GearHunterNavigator",NAV)
local s=NAV:SmartLocalSummary()
assert(s.zone=="Test Zone" and s.count==2 and s.nearest.name=="Near chest")
assert(NAV:SmartGoal(s).kind=="Discovery")
NAV.db.smartTrackerMode="Quest"
NAV.quests={{id=9,name="Collect herbs",objectives={}}}
assert(NAV:SmartGoal(s).kind=="Quest")
NAV.db.smartTrackerMode="Gear"
NAV.profile.gearTarget={name="Helm",source="Example raid"}
local g=NAV:SmartGoal(s)
assert(g.kind=="Gear" and g.instruction:find("Example raid"))
NAV.db.smartTrackerMode="Mount"
NAV.profile.activeMountID=77;NAV.completedSteps={}
g=NAV:SmartGoal(s)
assert(g.kind=="Mount" and g.step==1 and g.instruction:find("Visit zone"))
NAV.completedSteps[1]=true
g=NAV:SmartGoal(s)
assert(g.step==2 and g.instruction:find("Kill boss"))
NAV.db.smartTrackerMode="Auto"
assert(NAV:SmartGoal(s).kind=="Mount")
NAV.profile.activeMountID=nil;NAV.db.mountID=nil
assert(NAV:SmartGoal(s).kind=="Quest")
NAV.db.smartTrackerEnabled=true
NAV:ToggleSmartTracker()
assert(NAV.db.smartTrackerEnabled==false)
NAV:ToggleSmartTracker()
assert(NAV.db.smartTrackerEnabled==true)
print("Smart Navigation offline tests passed")
