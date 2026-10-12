## What's new in Gear Hunter v0.11.8

**Much smaller download; all the familiar Gear Hunter features are retained.**

- Compressed 109 large artistic textures into the native World of Warcraft BLP2/DXT5 format.
- Kept 48 small artwork files (including icons and small showcase pieces) in their original TGA format.
- The download is expected to be about 50 MB instead of 240.7 MB, based on a locally tested equivalent build.
- No gear features, saved character data, or optional Companion functions were intentionally removed.

### How to install or upgrade
1. Fully exit World of Warcraft.
2. Delete only the old `_retail_/Interface/AddOns/GearHunter` folder, so unused legacy textures do not remain.
3. Extract the new ZIP into `_retail_/Interface/AddOns/`. The result should be an `AddOns/GearHunter` directory.
4. Start the game. Open Gear Hunter with `/gh`; the `?` button shows the full in-game release history.
5. Keep your `WTF` folder: it stores saved addon settings and should not be deleted.

The optional Windows GearHub Companion remains optional. If you encounter a missing background or frame artwork, please report your character class/specialization, faction, and a screenshot through gearhunter.net.

Build note: this release uses forced RGBA input to ensure consistent DXT5 artwork encoding on Linux GitHub runners.
