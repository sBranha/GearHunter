local ADDON,GHN=...
-- Original factual guide summaries. No coordinates are invented and no other addon code is copied.
local guides=GHN.Guides or {}
local function add(name,kind,source,zone,checklist)
  guides[name:lower()]={title=name,kind=kind,source=source,mapName=zone,verified=true,
    requirements=source.." Verify current eligibility and lockout in your Adventure Guide.",
    steps=checklist,stepTitles={"Check access","Travel","Find source","Attempt","Confirm"},
    tips={source,"Travel to "..zone.." and verify the entrance or route on the world map.",
    "Confirm requirements, difficulty, and phase before attempting.",
    "A successful attempt does not guarantee a chance-based reward.",
    "The Mount Journal shows whether you actually collected this mount."}}
end
add("Time-Lost Proto-Drake","Outdoor rare","Rare spawn in the Storm Peaks; shares spawn ecology with Vyragosa. Long, unpredictable wait; no live detection is possible without a visible NPC.","The Storm Peaks, Northrend",{
 "Read the Mount Journal and prepare for a rare spawn search.","Go to the Storm Peaks in Northrend.","Search known flight paths and watch for the actual NPC; mapped paths are not live alerts.","Defeat and loot the Time-Lost Proto-Drake if it appears.","Check whether the mount was added to your collection."})
add("Azure Drake","Raid drop","Malygos in the Eye of Eternity raid, Coldarra, Borean Tundra.","Borean Tundra, Northrend",{
 "Check The Eye of Eternity lockout and character eligibility.","Travel to Coldarra in Borean Tundra.","Enter The Eye of Eternity raid and locate Malygos.","Defeat Malygos and check the reward.","Confirm collection in Mount Journal."})
add("Blue Drake","Raid drop","Malygos in The Eye of Eternity; verify available difficulty and drop table in-game.","Borean Tundra, Northrend",{
 "Check the raid loot and lockout.","Travel to Coldarra in Borean Tundra.","Enter The Eye of Eternity and reach Malygos.","Defeat the encounter and check the reward.","Confirm mount in the journal."})
add("Drake of the North Wind","Dungeon drop","Altairus in The Vortex Pinnacle, Uldum, Cataclysm.","Uldum, Kalimdor",{
 "Check dungeon eligibility and reset limits.","Travel to the Vortex Pinnacle entrance in Uldum.","Enter the dungeon and reach Altairus.","Defeat Altairus and check its loot.","Confirm mount collection in the journal."})
add("Astral Cloud Serpent","Raid drop","Elegon in Mogu'shan Vaults raid, Kun-Lai Summit.","Kun-Lai Summit, Pandaria",{
 "Check the raid lockout and available difficulty.","Travel to Mogu'shan Vaults in Kun-Lai Summit.","Progress to the Elegon encounter.","Defeat Elegon and check loot.","Confirm in the Mount Journal."})
add("Experiment 12-B","Raid drop","Ultraxion encounter in Dragon Soul raid, Caverns of Time, Tanaris.","Tanaris, Kalimdor",{
 "Check your Dragon Soul lockout.","Go to Caverns of Time in Tanaris and enter Dragon Soul.","Progress to the Ultraxion encounter.","Defeat Ultraxion and check available loot.","Confirm collection or return on a later lockout."})
add("Heavenly Onyx Cloud Serpent","World boss drop","Sha of Anger world boss in Kun-Lai Summit; chance-based reward and eligibility rules apply.","Kun-Lai Summit, Pandaria",{
 "Check whether the world boss reward is eligible.","Travel to Kun-Lai Summit, Pandaria.","Find the Sha of Anger world boss when present.","Defeat the boss and check the eligible reward.","Confirm mount in your collection."})
add("Midnight","Dungeon drop","Attumen the Huntsman in Return to Karazhan (Legion dungeon), not the original Karazhan raid.","Deadwind Pass, Eastern Kingdoms",{
 "Check Return to Karazhan access and dungeon reset limits.","Travel to Karazhan in Deadwind Pass.","Enter the Return to Karazhan dungeon, not the original raid.","Find and defeat Attumen the Huntsman.","Check the Mount Journal for Midnight."})
GHN.Guides=guides
