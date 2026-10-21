local ADDON, GHN = ...
-- Gear Hunter Navigator class-aware leveling guidance.
-- Reads Blizzard's quest log; does not invent quest IDs, coordinates or "fastest" timings.
local CLASS_TIPS = {
  WARRIOR="Build Rage with your available attacks, spend it on your strongest abilities, and use a defensive when pressured.",
  PALADIN="Use your available Holy Power builders and finishers, heal between fights, and use protective abilities when needed.",
  HUNTER="Keep your pet active when available, attack from range, and let your pet handle enemies while you move to the next objective.",
  ROGUE="Start fights from Stealth when possible, build combo points, spend them on finishers, and use defensive tools when outnumbered.",
  PRIEST="Use your available damage spells from range; keep healing and defensive spells ready, and avoid pulling too many enemies at once.",
  DEATHKNIGHT="Build Runic Power with your available attacks, spend it with your chosen abilities, and use self-healing to sustain questing.",
  SHAMAN="Use available spell or melee attacks for your specialization and keep a healing spell ready for difficult pulls.",
  MAGE="Attack from range, use your crowd control to keep dangerous enemies away, and avoid standing in melee range.",
  MONK="Use your available energy or chi abilities in combination, and rely on mobility and healing to move between quest targets.",
  DRUID="Use your chosen form and specialization abilities; take advantage of healing and movement between quest objectives.",
  DEMONHUNTER="Use movement to reach targets, spend Fury with your available attacks, and use defensives for difficult fights.",
  EVOKER="Cast your available empowered attacks carefully, use mobility to keep distance, and heal between fights as needed.",
}
local WARLOCK_MILESTONES = {
  {5,"Fear (crowd control)"}, {6,"Curse of Weakness"}, {7,"Create Healthstone"},
  {9,"Drain Life"}, {10,"Choose a specialization; Voidwalker access"},
  {14,"Soulstone"}, {17,"Eye of Kilrogg"}, {19,"Additional demon options"},
  {23,"Felhunter"}, {29,"Command Demon"}
}
local function validText(s)
  return type(s)=="string" and s~="" and s or nil
end
local function safeCall(f,...)
  if type(f)~="function" then return nil end
  local ok,value=pcall(f,...)
  if ok then return value end
  return nil
end
-- Never claim a quest is the "fastest" based only on the log. Prefer an
-- already-completed turn-in, then zone matches, then level-appropriate quests.
function GHN:RecommendedLevelingQuest(c)
  local level=tonumber(c and c.level) or 1
  local candidates={}
  local here=safeCall(C_Map and C_Map.GetBestMapForUnit,"player")
  if C_QuestLog and type(C_QuestLog.GetNumQuestLogEntries)=="function" and type(C_QuestLog.GetInfo)=="function" then
    local count=math.min(250,tonumber(safeCall(C_QuestLog.GetNumQuestLogEntries)) or 0)
    for i=1,count do
      local q=safeCall(C_QuestLog.GetInfo,i)
      if type(q)=="table" and not q.isHeader and validText(q.title) and tonumber(q.questID) then
        local ql=tonumber(q.level)
        -- Only recommend quests within the same five-level forward window.
        if ql and ql<=level+5 then
          local complete=q.isComplete==true
          local zone=safeCall(C_QuestLog.GetQuestZoneID,q.questID)
          local score=(complete and 30 or 0) + (here and zone==here and 18 or 0)
          if ql then score=score+math.max(0,7-math.abs(ql-level)) end
          if q.isHidden then score=score-20 end
          candidates[#candidates+1]={id=q.questID,title=q.title,level=ql,complete=complete,score=score}
        end
      end
    end
  elseif type(GetNumQuestLogEntries)=="function" and type(GetQuestLogTitle)=="function" then
    local count=math.min(250,tonumber(safeCall(GetNumQuestLogEntries)) or 0)
    for i=1,count do
      local ok,title,ql,_,isHeader,_,isComplete=pcall(GetQuestLogTitle,i)
      if ok and validText(title) and not isHeader and (tonumber(ql) and tonumber(ql)<=level+5) then
        candidates[#candidates+1]={title=title,level=tonumber(ql),complete=isComplete==true,score=isComplete and 30 or 0}
      end
    end
  end
  table.sort(candidates,function(a,b)
    if a.score~=b.score then return a.score>b.score end
    return (a.title or "")<(b.title or "")
  end)
  return candidates[1]
end
local function stage(c)
  local level=tonumber(c.level) or 1
  if level<10 then
    if c.faction=="Alliance" and (c.zone or ""):find("Stormwind",1,true) then
      return "At level "..level..", Stormwind is mainly a hub. Continue your starter quest chain; if none is active, seek level-appropriate quests in nearby Elwynn Forest. Don't travel to a high-level zone for XP.",
        "STARTER QUESTS (1-10)","At this level, a nearby, active starter quest chain is a safer recommendation than an unverified fastest route."
    elseif c.faction=="Horde" and (c.zone or ""):find("Orgrimmar",1,true) then
      return "Continue your starter chain; if you have no active quests, head to a nearby starter quest area appropriate for your race. Avoid high-level zones.",
        "STARTER QUESTS (1-10)","Finish your current starting-zone storyline before choosing another expansion."
    end
    return "Finish your current Exile's Reach or racial starter quest chain. Pick up nearby quests, complete objectives together, and turn them in before traveling away.",
      "STARTER QUESTS (1-10)","Your starting experience introduces the class and is designed for your level."
  elseif level<70 then
    return "Follow the Dragonflight campaign or your active level-scaled Chromie Time quest chain. Keep nearby side quests if they overlap; queue for dungeons when eligible and useful.",
      "CAMPAIGN LEVELING (10-70)","Dragonflight is the guided default path for new players. Existing characters may have other accessible timelines."
  elseif level<80 then
    return "Follow the accelerated The War Within story/recap, starting with the available introductory campaign. Use level-appropriate quests in Khaz Algar if you have access.",
      "THE WAR WITHIN (70-80)","The story recap bridges Dragonflight to Midnight for new players."
  elseif level<90 then
    return "Follow the Midnight level-up campaign, beginning with its introductory quests. Add nearby quests and unlocked dungeons when you need more experience.",
      "MIDNIGHT (80-90)","Progress through available campaign chapters; no unverified coordinates or fastest-route claims."
  end
  return "You are at the current level cap. Switch to Gear, collections, or the endgame activities available to your character.",
    "MAX LEVEL (90)","There is no further standard leveling route at level 90."
end
local function warlock(c)
  local level=tonumber(c.level) or 1
  local spec=(c.spec or ""):lower()
  if level<5 then
    return "WARLOCK COMBAT: Keep your Imp summoned if learned. Cast Corruption (if learned), then Shadow Bolt while your demon attacks. Use Unending Resolve when under pressure if available. Pull one enemy at a time.",
      "Next: Fear at level 5. Then Healthstone at 7, Drain Life at 9, and a specialization at 10."
  end
  local combat
  if level<10 then
    combat="WARLOCK COMBAT: Let your available demon assist. Apply Corruption, use Shadow Bolt for damage, and use Fear to create space if learned. At level 7, make Healthstones when available."
  elseif spec:find("affliction",1,true) then
    combat="AFFLICTION: Keep your learned damage-over-time spells active (such as Agony and Corruption), and use your available filler spells while moving toward the next objective."
  elseif spec:find("demonology",1,true) then
    combat="DEMONOLOGY: Keep your strongest available demon summoned, build Soul Shards with learned abilities, and spend them on your available demon-summoning attacks."
  elseif spec:find("destruction",1,true) then
    combat="DESTRUCTION: Keep your learned burning effects on targets, build Soul Shards with your available casts, and spend them on stronger damaging spells when learned."
  else
    combat="WARLOCK COMBAT: Keep a demon summoned, apply learned damage-over-time effects, and use your main ranged spells. Choose a specialization in the Talents window if you have not selected one."
  end
  local nextMilestone
  for _,milestone in ipairs(WARLOCK_MILESTONES) do
    if level<milestone[1] then nextMilestone="Next at level "..milestone[1]..": "..milestone[2];break end
  end
  if not nextMilestone then nextMilestone="Review newly unlocked Warlock and specialization talents each level." end
  if level>=10 and spec:find("not selected",1,true) then
    nextMilestone="Choose Affliction, Demonology, or Destruction in Talents; all can level, and Demonology is a good pet-focused solo option."
  end
  return combat,nextMilestone
end
function GHN:GetLevelingPlan(c)
  if not c then return nil end
  local route,stageName,reason=stage(c)
  local quest=self:RecommendedLevelingQuest(c)
  local classKey=(c.class or ""):upper():gsub("%s+","")
  local combat,milestone
  if classKey=="WARLOCK" then
    combat,milestone=warlock(c)
  else
    combat=(c.class or "CLASS"):upper().." COMBAT: "..(CLASS_TIPS[classKey] or "Use your current class abilities, defensive tools and talents while completing appropriate quests.")
    milestone=tonumber(c.level)<10 and "At level 10, review your specialization choices in the Talents window." or
      "Review specialization talents as you level. Open Gear for equipment upgrades within the five-level limit."
  end
  local nextTitle,firstStep=stageName,route
  if quest then
    nextTitle=(quest.complete and "TURN IN: " or "ACTIVE QUEST: ")..quest.title
    firstStep=(quest.complete and "Your quest log marks this quest complete. Turn it in for its reward and XP." or
      "Open your quest log, follow the listed objective, and turn in this quest. Do related objectives in the same area before traveling elsewhere.")
  end
  return {title=nextTitle,route=route,reason=reason,firstStep=firstStep,quest=quest,
    combat=combat,milestone=milestone,stage=stageName,
    class=(c.class or "Adventurer"),zone=(c.zone or "Unknown"),level=tonumber(c.level) or 1}
end
function GHN:OpenLevelingQuestLog()
  if InCombatLockdown and InCombatLockdown() then return false,"Open your quest log after combat." end
  local plan=self:GetLevelingPlan(self:GetCharacterSummary())
  if plan and plan.quest and plan.quest.id and C_QuestLog and type(C_QuestLog.SetSelectedQuest)=="function" then
    pcall(C_QuestLog.SetSelectedQuest,plan.quest.id)
  end
  local wasShown=self.frame and self.frame:IsShown()
  if wasShown then self.frame:Hide() end
  local open=false
  if type(ToggleQuestLog)=="function" then open=pcall(ToggleQuestLog) end
  if not open and type(ShowUIPanel)=="function" and QuestLogFrame then
    open=pcall(ShowUIPanel,QuestLogFrame)
  end
  if not open and wasShown then self.frame:Show() end
  return open,open and "Quest log opened." or "Quest log unavailable; try the game's normal quest log key."
end
