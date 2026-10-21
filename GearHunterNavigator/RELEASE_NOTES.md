# Gear Hunter Navigator v0.4.7

**One unified World of Warcraft Retail addon** replacing the separate Gear Hunter and MapHub downloads for new installations.

## Included in this release

- **Original Gear Hunter design:** ornate blue-and-gold Midnight frame, centered rotatable character and equipment views, gear search, boss loot, upgrade and farming tools.
- **Upgrade finder:** class/equipment eligibility checks; show improvements of at least +1 item level. Required-level window defaults to current character level +5, with an optional +10 setting. Items with unknown requirements may be withheld.
- **Class-aware leveling:** character/quest-log-based guidance with early class tips. Not a complete algorithmically optimized leveling route.
- **Quest help:** displays active quest objectives and provides next-step assistance from those objectives.
- **Reputation:** displays available faction standings and Renown information.
- **Collections:** collected mounts and toys, search, collection filters, pagination, and Toy Box controls.
- **Mount Hunter:** searchable Mount Journal, tracking and verified/source-based mount-acquisition guidance.
- **Rares & Treasures:** documented map locations, waypoints, and the approved eight-category icons (rares, chests, elite rares, world bosses, secrets, quests, vendors and flight paths). Pins are known locations—not a live rare-spawn detector.
- **Adventure Planner:** combines available gear/mount/discovery goals; some source databases remain incomplete.
- **v0.4.7 layout fix:** Collections totals and notices no longer overlap controls and item rows.

## Install / upgrade

1. Exit World of Warcraft completely.
2. Remove only the obsolete `_retail_/Interface/AddOns/GearHunter` and `_retail_/Interface/AddOns/MapHub` folders if installed. Replace the old `GearHunterNavigator` folder.
3. Extract the **single** `GearHunterNavigator` folder from this release ZIP into `_retail_/Interface/AddOns/`.
4. Keep your `WTF` folder and SavedVariables; do not delete them.
5. Start WoW, enable **Gear Hunter Navigator**, and enter `/ghnav`.

**Upgrade note:** The new combined addon uses its own `GearHunterNavigatorDB` saved variables. Existing Gear Hunter and MapHub settings are not guaranteed to migrate automatically.

## Website information

Website: https://gearhunter.net
Source and releases: https://github.com/sBranha/GearHunter
Public distribution should list **Gear Hunter Navigator** as the single current addon. Preserve old Gear Hunter and MapHub release archives as history instead of deleting them.

## Validation

This build's gameplay capabilities were previously checked through offline Lua syntax and simulation tests. Final functionality and rendering must still be tested in a running WoW client.
