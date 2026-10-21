local _, GHN = ...
-- Reused from our own MapHub v0.8.0; third-party records remain MIT licensed.
-- See DATA-LICENSES.txt for credits and limitations.
-- MapHub v0.3.8 shared with GearHunter.net: curated locations only.
-- mapID values are Blizzard UI map IDs; x/y are percentages.
GHN.CuratedLocations = {
 {mapID=2395,x=40.9,y=19.5,name='Gift of the Phoenix',category='Treasure',description='Midnight Eversong Woods treasure.'},
 {mapID=2395,x=44.6,y=45.6,name='Gilded Armillary Sphere',category='Treasure',description='Midnight Eversong Woods treasure.'},
 {mapID=2395,x=48.7,y=75.5,name='Burbling Paint Pot',category='Treasure',description='Midnight Eversong Woods treasure.'},
 {mapID=2395,x=43.3,y=69.5,name='Forgotten Ink and Quill',category='Treasure',description='Midnight Eversong Woods treasure.'},
 {mapID=2395,x=52.3,y=45.4,name='Antique Nobleman\'s Signet Ring',category='Treasure',description='Midnight Eversong Woods treasure.'},
 {mapID=2395,x=40.5,y=60.8,name='Stone Vat',category='Treasure',description='Midnight Eversong Woods treasure.'},
 {mapID=2395,x=38.9,y=76.1,name='Triple-Locked Safebox',category='Treasure',description='Find all three nearby keys first. Map Hub also marks the three key locations.'},
 {mapID=2395,x=37.6,y=74.8,name='Safebox Key 1',category='Secret',description='First key for Triple-Locked Safebox.'},
 {mapID=2395,x=38.4,y=73.5,name='Safebox Key 2',category='Secret',description='Second key for Triple-Locked Safebox.'},
 {mapID=2395,x=40.2,y=75.8,name='Safebox Key 3',category='Secret',description='Third key for Triple-Locked Safebox.'},
 {mapID=2395,x=51.6,y=74.6,name='Warden of Weeds',category='Rare',description='Midnight Eversong Woods rare spawn.'},
 {mapID=2395,x=54.8,y=60.2,name='Overfester Hydra',category='Rare',description='Midnight Eversong Woods rare spawn.'},
 {mapID=2395,x=63.6,y=49.4,name='Cre\'van',category='Rare',description='Midnight Eversong Woods rare spawn.'},
 {mapID=2395,x=36.6,y=77.2,name='Lady Liminus',category='Rare',description='Midnight Eversong Woods rare spawn.'},
 {mapID=2395,x=48.8,y=88.0,name='Bad Zed',category='Rare',description='Midnight Eversong Woods rare spawn.'},
 {mapID=2395,x=56.4,y=77.6,name='Banuran',category='Rare',description='Midnight Eversong Woods rare spawn.'},
 {mapID=2395,x=42.6,y=69.2,name='Duskburn',category='Rare',description='Midnight Eversong Woods rare spawn.'},
 {mapID=2393,x=24.4,y=69.6,name='Rookery Cache',category='Treasure',description='On a floating platform above Sunwing Rookery in Silvermoon City.'},
}

-- Retail Elwynn Forest (UiMapID 37); coordinates checked against Warcraft Wiki.
local elwynn = {
 {id='elwynn:morgaine',mapID=37,x=31.0,y=65.6,name='Morgaine the Sly',category='Rare',description='Inside a house at Mirror Lake Orchard.',source='Warcraft Wiki / mapped location',url='https://warcraft.wiki.gg/wiki/Morgaine_the_Sly'},
 {id='elwynn:mother_fang',mapID=37,x=62.1,y=48.0,name='Mother Fang',category='Rare',description='In Jasperlode Mine; entrance and underground position can differ.',source='Warcraft Wiki / mapped location',url='https://warcraft.wiki.gg/wiki/Mother_Fang'},
 {id='elwynn:narg',mapID=37,x=38.0,y=83.6,name='Narg the Taskmaster',category='Rare',description='Wanders outside Fargodeep Mine.',source='Warcraft Wiki / mapped location',url='https://warcraft.wiki.gg/wiki/Narg_the_Taskmaster'},
 {id='elwynn:thuros',mapID=37,x=50.6,y=80.6,name='Thuros Lightfingers',category='Rare',description='At the bandit camp northeast of Jerod\'s Landing.',source='Warcraft Wiki / mapped location',url='https://warcraft.wiki.gg/wiki/Thuros_Lightfingers'},
 {id='elwynn:fedfennel',mapID=37,x=68.1,y=44.9,name='Fedfennel',category='Rare',description='Patrols the gnoll camps near Stone Cairn Lake; position approximate.',source='Warcraft Wiki / mapped location',url='https://warcraft.wiki.gg/wiki/Fedfennel'},
 {id='elwynn:gruff',mapID=37,x=26.2,y=90.4,name='Gruff Swiftbite',category='Rare',description='Gnoll camp south of Westbrook Garrison.',source='Warcraft Wiki / mapped location',url='https://warcraft.wiki.gg/wiki/Gruff_Swiftbite'},
 {id='elwynn:lamepaw',mapID=37,x=52.0,y=62.0,name='Lamepaw the Whimperer',category='Rare',description='At the small wolf den north of Crystal Lake.',source='Warcraft Wiki / mapped location',url='https://warcraft.wiki.gg/wiki/Lamepaw_the_Whimperer'},
 {id='elwynn:snoot',mapID=37,x=69.6,y=79.6,name='Snoot the Rooter',category='Rare',description='Rare boar at Brackwell Pumpkin Patch.',source='Warcraft Wiki / mapped location',url='https://warcraft.wiki.gg/wiki/Snoot_the_Rooter'},
 {id='elwynn:terrapis',mapID=37,x=53.8,y=87.4,name='Terrapis',category='Rare',description='Rare turtle patrols the southern riverbank.',source='Warcraft Wiki / mapped location',url='https://warcraft.wiki.gg/wiki/Terrapis'},
 {id='elwynn:tarantis',mapID=37,x=66.6,y=63.2,name='Tarantis',category='Rare',description='Rare spider north of Tower of Azora.',source='Warcraft Wiki / mapped location',url='https://warcraft.wiki.gg/wiki/Tarantis'},
 {id='elwynn:gug',mapID=37,x=47.0,y=32.0,name='Gug Fatcandle',category='Rare',description='Echo Ridge Mine entrance, Northshire; approximate position from historical location reference.',source='Warcraft Wiki / historical approximate location',url='https://warcraft.wiki.gg/wiki/Gug_Fatcandle'},
 {id='elwynn:grizzled',mapID=37,x=27.4,y=67.6,name='Grizzled Ben',category='Rare',description='Rare bear near Mirror Lake Orchard.',source='Warcraft Wiki / mapped location',url='https://warcraft.wiki.gg/wiki/Grizzled_Ben'},
 {id='elwynn:bushtail',mapID=37,x=83.0,y=84.0,name='Bushtail',category='Rare',description='Rare fox wandering south of Ridgepoint Tower.',source='Warcraft Wiki / mapped location',url='https://warcraft.wiki.gg/wiki/Bushtail'},
}
for _, record in ipairs(elwynn) do GHN.CuratedLocations[#GHN.CuratedLocations + 1] = record end

-- 2026-10-14: Midnight Isle of Quel'Danas (UiMapID 2424).
-- Spawn coordinates verified against public community records; this is data, not live detection.
-- https://github.com/ATTWoWAddon/AllTheThings/blob/master/.contrib/.db/standard/02%20-%20Outdoor%20Zones/16%20Quel'Thalas/Isle%20of%20Quel'Danas/Rares.lua
-- The Midnight version is intentionally NOT the original Burning Crusade map 122.
local queldanas = {
 {id='midnight:queldanas:dripping-shadow',mapID=2424,x=37.0,y=38.4,name='Dripping Shadow',category='Rare',npcID=239864,questID=95010,
  description='Rare in the Sunwell / Parhelion Plaza area. May be unavailable or phased depending on story progress; known spawn point, not a live spawn alert.',
  source='Verified Midnight location',url='https://warcraft.wiki.gg/wiki/Dripping_Shadow'},
 {id='midnight:queldanas:tarhu-ransacker',mapID=2424,x=55.5,y=28.7,name='Tarhu the Ransacker',category='Rare',npcID=252465,questID=95011,
  description='Rare near the Sunwell area. Long respawn is reported; availability may depend on story phase. This pin marks a known location, not an active spawn.',
  source='Verified Midnight location',url='https://www.wowhead.com/npc=252465/tarhu-the-ransacker'},
 -- One documented rare battle-pet sighting (collectible; it is NOT an NPC rare-spawn icon).
 {id='midnight:queldanas:wrathful-wyrm-pet',mapID=2424,x=49.2,y=22.4,name='Wrathful Wyrm (battle pet)',category='Collectible',
  description='One player-documented sighting of the collectible battle pet. Several spawn locations exist; location may vary.',
  source='Reported collectible location',url='https://www.wowhead.com/npc=250573/wrathful-wyrm'},
 {id='midnight:queldanas:parhelion-plaza',mapID=2424,x=47.74,y=41.58,name='Parhelion Plaza (delve)',category='Discovery',
  description='Delve entrance is downstairs inside the building; not a rare enemy.',
  source='Method delve entrance guide',url='https://www.method.gg/guides/parhelion-plaza-delve-guide'},
}
for _,record in ipairs(queldanas) do GHN.CuratedLocations[#GHN.CuratedLocations+1]=record end
