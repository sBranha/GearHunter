## Gear Hunter v0.11.9 — Clean HD Character Backgrounds

This update retires the first-generation character-screen artwork.

- Removed 21 obsolete TGA backgrounds and eliminated the Race background mode that could still select them.
- All characters with the retired Race preference automatically switch to Auto. Other preferences and saved gear remain unchanged.
- When no valid scene is selected, the previous texture is cleared so it cannot linger.
- Kept 80 high-resolution Alliance/Horde specialization scenes and all existing class previews, icons and Midnight frames.
- Kept compact BLP2 artwork compression for a smaller ZIP.

### Installation (important)
1. Exit World of Warcraft completely.
2. Delete **only** the old `_retail_/Interface/AddOns/GearHunter` folder before installing. Otherwise the older image files may remain.
3. Extract the new `GearHunter-v0.11.9.zip` into `_retail_/Interface/AddOns/`.
4. Restart WoW and open `/gh`, then Character. Change Theme Mode between Auto, Class, Custom or Off.
5. Do **not** delete the `WTF` folder; it contains your saved character settings.

The build checks file presence and package integrity, but appearance in the WoW client still needs in-game confirmation. If artwork still appears doubled, send a screenshot and your character class, faction, specialization and Theme Mode.
