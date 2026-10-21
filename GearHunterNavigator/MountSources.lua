local ADDON, GHN = ...
-- Gear Hunter original mount acquisition instructions. Blizzard's Mount Journal
-- is the catalog; these curated entries enrich it. No third-party addon data.
-- A guide having steps does NOT mean a verified waypoint exists.
local function Detailed(title,kind,source,requirements,region,steps,tips)
  return {title=title,kind=kind,source=source,requirements=requirements,
    mapName=region,verified=true,steps=steps,tips=tips,
    stepTitles={"Prepare","Travel","Find the target","Complete the activity","Confirm the reward"}}
end
local guides=GHN.Guides or {}
if guides["ashes of al'ar"] then
  local ashes=guides["ashes of al'ar"]
  ashes.kind="Raid drop"
  ashes.verified=true
  ashes.requirements="Outland > Netherstorm > The Eye (Tempest Keep). Defeat Kael'thas Sunstrider. Rare drop, not guaranteed; the raid has a lockout."
end
guides["invincible"]=Detailed("Invincible","Raid drop",
  "The Lich King — Icecrown Citadel, 25-player Heroic difficulty.",
  "Travel to Icecrown in Northrend. Use 25-player Heroic Icecrown Citadel. The Lich King is the final encounter; a lockout limits attempts.",
  "Icecrown, Northrend",{
  "Check your raid difficulty and the current lockout.",
  "Travel to Icecrown Citadel in Icecrown, Northrend.",
  "Enter the raid on 25-player Heroic and clear toward the Lich King.",
  "Defeat the Lich King on the required difficulty.",
  "Loot the boss; check the Mount Journal for Invincible."
},{
  "The rare mount is associated with the heroic 25-player Lich King encounter, not every raid difficulty.",
  "Icecrown Citadel is the large fortress at the center of Icecrown. This guide does not claim a tested entrance coordinate.",
  "Follow the raid progression. If blocked, check uncleared encounters and raid locks.",
  "Defeat the Lich King; the mount is not a guaranteed drop.",
  "If unsuccessful, try another eligible lockout."
})
guides["mimiron's head"]=Detailed("Mimiron's Head","Raid drop",
  "Yogg-Saron — Ulduar, with zero Keeper helpers (Alone in the Darkness).",
  "In Ulduar in Storm Peaks, face Yogg-Saron without any Keepers assisting. This is a rare drop; difficulty and encounter settings matter.",
  "Storm Peaks, Northrend",{
  "Check Ulduar's lockout and plan a zero-Keeper attempt.",
  "Go to Ulduar in the Storm Peaks, Northrend.",
  "Progress through the raid without activating Keeper assistance for Yogg-Saron.",
  "Defeat Yogg-Saron with no Keeper helpers.",
  "Loot and check whether Mimiron's Head entered your collection."
},{
  "The special no-Keeper condition matters. Do not assume a normal Yogg-Saron kill qualifies.",
  "Ulduar is a raid in the northern Storm Peaks. Use the zone map for the entrance.",
  "If a Keeper is assisting, check your setup before the final encounter.",
  "The mount is a chance-based reward for the zero-Keeper encounter.",
  "Use the Mount Journal to confirm collection; a completed kill doesn't guarantee it."
})
guides["raven lord"]=Detailed("Raven Lord","Dungeon drop",
  "Anzu — Sethekk Halls (Heroic), Auchindoun, Terokkar Forest.",
  "Set dungeon difficulty to Heroic before entering Sethekk Halls in Auchindoun. Anzu is present for eligible characters without the historical druid-only summon requirement.",
  "Terokkar Forest, Outland",{
  "Set dungeon difficulty to Heroic and check your lockout.",
  "Go to Auchindoun in Terokkar Forest, Outland.",
  "Enter Sethekk Halls on Heroic and find Anzu.",
  "Defeat Anzu and loot the encounter.",
  "Check the journal for the Raven Lord mount; repeat another day if needed."
},{
  "Normal Sethekk Halls is not the intended mount farm. Select Heroic before entering.",
  "Auchindoun is in the Bone Wastes of Terokkar Forest. Choose the Sethekk Halls entrance.",
  "Look for Anzu inside the dungeon. Historical summon instructions are obsolete on Retail.",
  "This is a rare chance drop, not an achievement or vendor purchase.",
  "If the mount is missing, another eligible Heroic run may be needed."
})
guides["onyxian drake"]=Detailed("Onyxian Drake","Raid drop",
  "Onyxia — Onyxia's Lair, Dustwallow Marsh.",
  "Travel to Onyxia's Lair in Dustwallow Marsh, Kalimdor. Defeat and loot Onyxia. Rare raid drop, limited by lockout.",
  "Dustwallow Marsh, Kalimdor",{
  "Check your Onyxia's Lair raid lockout.",
  "Travel to Dustwallow Marsh in Kalimdor.",
  "Find and enter Onyxia's Lair.",
  "Defeat Onyxia and loot the boss.",
  "Check for the Onyxian Drake in your Mount Journal."
},{
  "The Onyxian Drake comes from Onyxia's Lair, not a random open-world dragon.",
  "Look in the Wyrmbog area of southern Dustwallow Marsh for the raid entrance.",
  "Onyxia is the target encounter inside the lair.",
  "The mount is not guaranteed. Check the encounter loot and lockout.",
  "Return on another eligible lockout if unsuccessful."
})
guides["fiery warhorse"]=Detailed("Fiery Warhorse","Raid drop",
  "Attumen the Huntsman — original Karazhan, Deadwind Pass.",
  "The Fiery Warhorse is from Attumen in the original Karazhan raid. Newer Return to Karazhan dungeon rewards are different.",
  "Deadwind Pass, Eastern Kingdoms",{
  "Check the original Karazhan raid lockout.",
  "Travel to Deadwind Pass and reach the Karazhan tower.",
  "Enter original Karazhan, not Return to Karazhan.",
  "Defeat Attumen the Huntsman and loot his encounter.",
  "Check whether Fiery Warhorse was collected."
},{
  "The two Karazhan instances have different loot. This farm uses the original raid.",
  "Find Karazhan tower in Deadwind Pass in the Eastern Kingdoms.",
  "Attumen is encountered near the stables early in the original raid.",
  "It is a rare drop; a single clear does not guarantee the mount.",
  "Check collection status after looting and retry after an eligible reset."
})
guides["vitreous stone drake"]=Detailed("Vitreous Stone Drake","Dungeon drop",
  "Slabhide — The Stonecore, Deepholm.",
  "The Stonecore is a Cataclysm dungeon in Deepholm. Slabhide is the mount-dropping boss. Check current difficulty options and reset limits in-game.",
  "Deepholm",{
  "Check your dungeon difficulty and reset limits.",
  "Travel to Deepholm and locate the Stonecore entrance.",
  "Enter the Stonecore and progress to Slabhide.",
  "Defeat Slabhide and loot the boss.",
  "Check whether Vitreous Stone Drake was learned."
},{
  "The named drop source is Slabhide, not the final boss.",
  "The Stonecore entrance sits in the Temple of Earth region of Deepholm.",
  "Follow the dungeon path until you reach Slabhide.",
  "A rare drop is not guaranteed; check your eligibility and reset rules.",
  "Use the Mount Journal to verify collection."
})
GHN.Guides=guides

local function Plain(s)
  s=tostring(s or "")
  s=s:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
  s=s:gsub("|H[^|]+|h([^|]*)|h","%1")
  return s
end
function GHN:MountSourceText(m)
  if not m then return "No mount selected" end
  local s=Plain(m.source)
  if s~="" then return s end
  return "The Mount Journal does not expose a source description for this entry."
end
function GHN:MountSourceGroup(m)
  if not m then return "Other" end
  local existing=guides[(m.name or ""):lower()]
  if existing and existing.kind then
    if existing.kind:find("Raid") then return "Raid" end
    if existing.kind:find("Dungeon") then return "Dungeon" end
  end
  local src=self:MountSourceText(m):lower()
  if src:find("achievement") then return "Achievement" end
  if src:find("reputation") or src:find("vendor") or src:find("purchase") or src:find("trader") then return "Vendor" end
  if src:find("quest") then return "Quest" end
  if src:find("raid") then return "Raid" end
  if src:find("dungeon") then return "Dungeon" end
  if src:find("profession") or src:find("craft") then return "Profession" end
  if src:find("drop") then return "Drop" end
  return "Other"
end

-- Generic guides are assembled from Blizzard-provided source text, and are
-- deliberately labeled as planning checklists rather than verified directions.
function GHN:GetMountGuide(name,m)
  local curated=guides[(name or ""):lower()]
  if curated then return curated end
  if not m then return nil end
  local source=self:MountSourceText(m)
  local group=self:MountSourceGroup(m)
  local action,tip,req
  if group=="Achievement" then
    action="Open the named achievement and review its remaining criteria."
    tip="Use the in-game Achievement panel to track each outstanding criterion."
    req="Achievement criteria and account eligibility depend on the current game."
  elseif group=="Vendor" then
    action="Find the listed vendor or faction and verify requirements/currency."
    tip="The journal may not include exact coordinates. Check vendor location using the world map and available game information."
    req="Reputation, currency and other purchase conditions must be confirmed in-game."
  elseif group=="Quest" then
    action="Find the named quest or questline in your active or completed quests."
    tip="Follow the quest log and map markers. Progress varies by character and prerequisites."
    req="Confirm story progress, quest availability, and any prerequisites in your quest log."
  elseif group=="Raid" or group=="Dungeon" or group=="Drop" then
    action="Identify the named boss or source and the correct instance or activity."
    tip="Confirm the target, difficulty and loot eligibility in the game's Adventure Guide when available."
    req="Check level, difficulty, boss access, and the relevant lockout or reset limits."
  elseif group=="Profession" then
    action="Find the recipe or profession method and required materials."
    tip="Consult your profession journal for skill, recipes and required reagents."
    req="Check profession, recipe and material requirements in the game."
  else
    action="Identify the mount's acquisition activity from the Mount Journal."
    tip="The game does not expose a step-by-step route for every mount. Source details here are not independently verified."
    req="Requirements must be confirmed in-game; this mount may have special or unavailable acquisition rules."
  end
  local steps={
    "Read the Mount Journal source for "..m.name..".",
    action,
    "Confirm the needed access, travel and eligibility.",
    "Complete the required activity and claim its reward.",
    "Check the Mount Journal to confirm collection."
  }
  return {title=m.name,kind=group,source=source,verified=false,
    requirements=req,steps=steps,
    stepTitles={"Check the source","Find the activity","Check requirements","Attempt the reward","Confirm collection"},
    tips={"Journal source: "..source,tip,
      req,"The journal describes the source, but a precise verified route is not installed for this mount.",
      "Checklist completion is not proof of owning the mount; rely on the journal's collected flag."}}
end
