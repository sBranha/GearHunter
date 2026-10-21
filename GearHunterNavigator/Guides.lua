local ADDON, GHN = ...
-- Audited retail example: mount source, boss, instance and zone.
-- Coordinates are normalized Netherstorm map coordinates; verify map ID at runtime.
GHN.Guides = {
  ["ashes of al'ar"] = {
    title = "Ashes of Al'ar",
    source = "Kael'thas Sunstrider, The Eye (Tempest Keep), Netherstorm, Outland. Rare raid drop; repeat on later lockouts if unsuccessful.",
    mapID = 109, mapName = "Netherstorm", x = .737, y = .638,
    steps = {
      "Reach Outland and prepare for travel.",
      "Travel across Netherstorm to Tempest Keep.",
      "Find the main fortress and enter The Eye raid.",
      "Fight your way to Kael'thas Sunstrider and defeat him.",
      "Loot Kael'thas; check the mount journal for Ashes of Al'ar."
    },
    stepTitles = {
      "Reach Outland", "Travel to Tempest Keep", "Enter The Eye",
      "Defeat Kael'thas", "Check the rare drop"
    },
    tips = {
      "Reach Outland via a portal or another unlocked route. From there, travel toward Netherstorm.",
      "Fly to eastern Netherstorm. Find the large floating Tempest Keep near 73.7, 63.8.",
      "Approach the main fortress archway. The smaller floating buildings are separate dungeons.",
      "Fight through The Eye toward Kael'thas Sunstrider. If blocked, check earlier encounters.",
      "Loot Kael'thas. The mount is a rare drop; try a later eligible lockout if it does not appear."
    }
  }
}
function GHN:GetMountGuide(name)
  return self.Guides[(name or ""):lower()]
end
