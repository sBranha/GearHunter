# Gear Hunter Navigator

**Current public addon: Gear Hunter Navigator v0.4.7**, a single World of Warcraft Retail addon combining the original Gear Hunter equipment tools, known MapHub discoveries, and Navigator’s guides.

**[Download Gear Hunter Navigator v0.4.7](https://github.com/sBranha/GearHunter/releases/download/navigator-v0.4.7/GearHunterNavigator-v0.4.7.zip)** · [Release notes](https://github.com/sBranha/GearHunter/releases/tag/navigator-v0.4.7) · [Official website](https://gearhunter.net/)

## Included features

- Original Gear Hunter interface and art, equipped gear, dungeon/raid loot, and upgrade planning.
- Level-aware upgrade results, showing +1 item-level improvements, with a default +5 and optional +10 required-level window.
- Class-aware leveling help, quest objectives, reputation and Renown where exposed by WoW.
- Searchable Mount Journal, mount guides, collected mounts and toys.
- Known rare, treasure, world boss, secret, vendor and flight-path locations with custom map icons. Pins do not guarantee live spawns.
- Adventure Planner, Support Center, and ornate Midnight-style character interface.

**Install:** Exit WoW. Remove old `GearHunter` and `MapHub` addon directories and replace your previous `GearHunterNavigator` folder with the `GearHunterNavigator` directory from the ZIP under `World of Warcraft/_retail_/Interface/AddOns/`. Keep your `WTF` folder. Open in-game with `/ghnav`. No separate addons are required.

## Publishing and source

This repository contains `GearHunterNavigator/` and an automated `publish-navigator.yml` GitHub Actions workflow. Releases use the tag scheme `navigator-vX.Y.Z`, include the complete one-folder ZIP, and generate a SHA-256 checksum. The release build reuses the Gear Hunter artwork already in this repository's history and generates optimized WoW BLP textures. The successful v0.4.7 release was built by [GitHub Actions](https://github.com/sBranha/GearHunter/actions).

**Website update package:** [GearHunter.net v2.0.38 unified Navigator updater ZIP](https://github.com/sBranha/GearHunter/raw/refs/heads/main/website-updates/GearHunter-Website-UPDATE-v2.0.38-UNIFIED-NAVIGATOR.zip). It is for the GearHunter.net admin Website Updater and is separate from the WoW addon ZIP. The site update must be installed on DreamHost before its public pages change.

## Archived standalone addons

The earlier [Gear Hunter standalone releases](https://github.com/sBranha/GearHunter/releases) remain here, and [MapHub standalone releases](https://github.com/sBranha/MapHub/releases) remain in their original repository for historical reference. They are no longer the recommended current installation.

Gear Hunter Navigator is free. No CurseForge dependency or in-game donation solicitation.