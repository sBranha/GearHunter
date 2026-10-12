-- Gear Hunter Support Center. Keep the latest release at the top of RELEASES,
-- and add a short how-to when a future feature is introduced.
local addonName, GH = ...
local ROOT="Interface\\AddOns\\GearHunter\\Art\\Frames\\"
local COLORS={gold={1,0.82,0.34},blue={0.49,0.77,1},muted={0.73,0.83,0.94}}

-- RELEASE NOTES MAINTENANCE: Every new release must have its own entry here,
-- including what changed and instructions for using the newly added feature.
GH.supportReleases={
    {version="0.11.7", title="GearHunter.net Companion compatibility", items={
        "Added optional GearHub companion load reporting and update notices through a separate helper addon.",
        "Gear Hunter works normally without Companion, registration, or website access.",
        "Added /ghwebsite to show the official download and support address."},
        how="Download the optional Windows GearHub Companion from gearhunter.net, choose whether to share anonymous statistics, and let it install the helper. Restart WoW or /reload for the latest update notice. Type /ghwebsite to find the site. No background reporting happens from Gear Hunter itself."},
    {version="0.11.6", title="In-game Support Center", items={
        "The top-right ? now opens its own Midnight-styled help window.",
        "Added What's New, Quick Start, Feature Guides, Troubleshooting, Commands, and About pages.",
        "Added a bug-reporting page with copyable diagnostics and a release-note NEW marker."},
        how="Click ? at the top of Gear Hunter or type /gh support. Open What's New to clear the NEW marker. Use REPORT ISSUE for information on troubleshooting and sharing diagnostic details."},
    {version="0.11.5",title="Farm Session Tracker",items={"Track successful boss encounters and your own loot events across saved farming sessions."},how="Open Gear Search > Boss Loot > Farm Session Tracker, or type /gh session. Press Start Session before farming and Finish Session afterward."},
    {version="0.11.4",title="Boss and Instance Favorites",items={"Save favorite raids, dungeons and bosses. Filter the Boss Loot browser to favorites only."},how="Open Gear Search > Boss Loot and select Save Instance or Save Boss. Use /gh favorites to reopen bookmarks."},
    {version="0.11.3",title="Collection Dashboard",items={"Added a combined overview for tracked gear, appearance wishlists, alts and saved lockouts."},how="Open Hunt List > Dashboard, or type /gh collection."},
    {version="0.11.2",title="Gear Upgrade Planner",items={"Set upgrade priorities and view known upgrade tracks; inspect exact costs while at an item upgrade NPC."},how="Open My Gear > Upgrade Planner, or /gh plan. Select an item at a Blizzard upgrade NPC and refresh costs."},
    {version="0.11.1",title="Boss Loot Hunter",items={"Browse indexed raid/dungeon bosses and their loot, with hunt and map actions."},how="Open Gear Search > Boss Loot, or /gh bosses. Index the Adventure Guide to expand results."},
    {version="0.11.0",title="Transmog Layout Repair",items={"Removed overlapping shared controls from the Transmog view and improved empty results guidance."},how="Open /gh mog. Choose a category and index appearances to populate the list."},
    {version="0.10.9",title="Alt Tracker",items={"Added saved gear and boss-lockout snapshots for characters you have played."},how="Open Hunt List > Alt Tracker, or /gh alts. Switch characters to refresh their snapshots."},
    {version="0.10.8",title="Weekly Farm Tracker",items={"Added lockout and defeated-boss information reported by WoW."},how="Open Hunt List > Weekly Lockouts, or /gh weekly. Refresh lockouts for current data."},
    {version="0.10.7",title="Smart Upgrade Recommendations",items={"Rank upgrades by item-level gain and estimated source accessibility."},how="Open Smart Picks or /gh smart. Scan the Journal first; choose a ranking mode and filters."},
    {version="0.10.6",title="Farm Route Planner",items={"Group unfinished Hunt List items by known farming destination and organize your stops."},how="Open Hunt List > Plan Farm Route, or /gh route. Choose a stop and use Show Entrance or Show Boss when available."},
    {version="0.10.5",title="Hunt List",items={"Save desired equipment, mark items completed, and track progress."},how="Open Hunt List or /gh hunt. Add items from Gear Search or paste an item link."},
    {version="0.10.4",title="Transmog Hunter",items={"Browse missing/collected appearances and keep an appearance wishlist."},how="Open Transmog or /gh mog and choose Index All Categories to build your collection browser."},
    {version="0.10.3",title="Gear Source Expansion",items={"Capture observed vendor equipment, quest rewards and profession recipes."},how="Open a merchant, quest or profession window and use /gh capture. Additional sources are saved when seen in game."},
    {version="0.10.2",title="Map Source Fixes",items={"Separated known instance entrances from boss-floor navigation and improved source matching."},how="Select an indexed item and use Show Entrance or Show Boss. Unknown coordinates stay unavailable."},
    {version="0.10.1",title="Gear Search",items={"Search a local gear index by name, item ID or pasted link, including Adventure Guide loot."},how="Open Gear Search or /gh search. Index All Dungeons / Raids for broader historical loot."},
}

local function text(parent,s,font)
    local t=parent:CreateFontString(nil,"OVERLAY",font or "GameFontNormal")
    t:SetText(s or "")
    return t
end
local function paint(frame,r,g,b,a,edge)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    frame:SetBackdropColor(r,g,b,a)
    if edge then frame:SetBackdropBorderColor(unpack(edge)) end
end
local function makeButton(parent,title,x,y,w,h,cb)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetSize(w,h);b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    paint(b,0.027,0.072,0.124,1,{0.34,0.56,0.73,1})
    b.text=text(b,title,"GameFontNormal")
    b.text:SetAllPoints(b);b.text:SetJustifyH("CENTER")
    b.text:SetTextColor(0.94,0.95,0.99)
    b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(1,0.83,0.32,1) end)
    b:SetScript("OnLeave",function(self)
        self:SetBackdropBorderColor(0.34,0.56,0.73,1)
    end)
    b:SetScript("OnClick",cb)
    return b
end
function GH:GetSupportDiagnostics()
    local cl=UnitClass and (select(2,UnitClass("player"))) or "Unknown"
    local level=UnitLevel and UnitLevel("player") or "?"
    return "Gear Hunter v"..tostring(self.version).." | WoW interface: 120100 | Class: "..tostring(cl).." | Level: "..tostring(level).." | Scan: "..tostring(self.journalStatus or "not started")
end
local function formatReleases()
    local parts={"WHAT'S NEW / UPDATE HISTORY", "Every release lists its changes and how to use the new feature.",""}
    for _,r in ipairs(GH.supportReleases) do
        parts[#parts+1]="v"..r.version.."  -  "..r.title
        for _,change in ipairs(r.items or {}) do parts[#parts+1]="  *  "..change end
        if r.how then parts[#parts+1]="HOW TO USE: "..r.how end
        parts[#parts+1]=""
    end
    return table.concat(parts,"\n")
end
local PAGES={
    {"HOME","HOME"},
    {"WHAT'S NEW","NEWS"},
    {"QUICK START","START"},
    {"FEATURE GUIDES","GUIDES"},
    {"TROUBLESHOOT","TROUBLE"},
    {"COMMANDS","COMMANDS"},
    {"REPORT ISSUE","SUPPORT"},
    {"ABOUT","ABOUT"},
}
local BODY={
    HOME=table.concat({
        "WELCOME TO GEAR HUNTER SUPPORT", "", 
        "This help window stays separate from the main Gear Hunter screen. Choose any topic on the left to view instructions without losing your place.","",
        "NEW IN THIS VERSION", "v0.11.7: optional website update notices through GearHub Companion. Existing addon features remain available without Companion.","",
        "START HERE", "1. Click QUICK START for your first gear scan.","2. Click WHAT'S NEW to see exactly what was added and how to use it.",
        "3. Click FEATURE GUIDES for all of Gear Hunter's major tools.",
        "4. If an item or map source is missing, check TROUBLESHOOT.","",
        "Information comes from WoW APIs, indexed Adventure Guide loot, and sources you've encountered. Gear Hunter cannot fetch Wowhead live inside the game."
    },"\n"),
    START=table.concat({
        "QUICK START - 5 MINUTES", "",
        "1. OPEN GEAR HUNTER", "Click its minimap button or type /gh. Click CHARACTER to view your live 3D character and equipped gear.","",
        "2. SCAN THE JOURNAL", "Press SCAN JOURNAL. The addon checks loot available to your character from supported Adventure Guide sources. Large scans can take time.","",
        "3. FIND BETTER GEAR", "Choose UPGRADES or SMART PICKS. Gear Hunter compares supported loot against your actual equipped item levels. It does not simulate best-in-slot damage or healing.","",
        "4. SEARCH ANY INDEXED GEAR", "Open GEAR SEARCH. Type a full or partial item name, an item ID, or paste an item link. Use INDEX ALL DUNGEONS / RAIDS to broaden the stored loot catalog.","",
        "5. CHOOSE A LOCATION", "Use Show Entrance or Show Boss when a reliable source is available. Unverified places are deliberately not pinned.","",
        "6. BUILD A HUNT LIST", "Add interesting items to HUNT LIST, mark them complete when you wish, and use PLAN FARM ROUTE to group stops.","",
        "7. EXPLORE TRANSMOG", "Go to TRANSMOG, choose a category and index appearances. Missing/Collected uses WoW's collection information where available."
    },"\n"),
    GUIDES=table.concat({
        "GEAR HUNTER FEATURE GUIDES", "",
        "CHARACTER & EQUIPMENT", "Open CHARACTER or /gh character. Drag the live player to rotate it. Click an equipment slot to see known upgrades.","",
        "UPGRADES & SMART PICKS", "Run SCAN JOURNAL. UPGRADES shows items higher than your equipped gear; SMART PICKS ranks known candidates. Neither guarantees a drop or best-in-slot stats.","",
        "MY GEAR & UPGRADE PLANNER", "Open MY GEAR, then the planner, or type /gh plan. Choose upgrade targets and priorities. For exact currency costs, visit an item-upgrade NPC and use Refresh Costs with an item selected.","",
        "GEAR SEARCH", "Open /gh search. Search the saved item index or scan Adventure Guide dungeons and raids. Vendor, quest, and crafting sources are captured when their game windows are open; use /gh capture.","",
        "BOSS LOOT & FAVORITES", "Open /gh bosses. Choose an indexed instance and boss to inspect loot. Favorite them with Save Instance / Save Boss and reopen with /gh favorites.","",
        "TRANSMOG HUNTER", "Open /gh mog. Index categories, browse missing or collected appearances, and keep a wishlist. Collection results depend on WoW data.","",
        "HUNT LIST & FARM ROUTE", "Open /gh hunt. Add desired gear, check off completed items, then open Plan Farm Route or /gh route. Routes group known stops; they do not calculate travel times.","",
        "WEEKLY FARM & ALTS", "Open /gh weekly to view lockouts reported for this character. Open /gh alts for the last saved gear and boss-progress snapshots of your other characters.","",
        "COLLECTION DASHBOARD", "Open /gh collection for your gear goals, appearance wishlist and last-seen alt information.","",
        "FARM SESSIONS", "Open /gh session. Start Session before farming; Finish Session afterward. The tracker records successful encounter events and your own loot events separately.","",
        "MAP NAVIGATION", "Show Entrance and Show Boss only work when the game or saved source data supplies a reliable location. LAST SEEN on vendors is a remembered observation, not a guarantee.","",
        "WHAT'S NEW", "Read each version's feature-specific instructions under What's New."
    },"\n"),
    TROUBLE=table.concat({
        "TROUBLESHOOTING", "",
        "NO GEAR APPEARS", "Click Scan Journal. Check source filters, your character level, and whether the item is available in the Blizzard Adventure Guide. For a broad search, use Gear Search > Index All Dungeons / Raids.","",
        "TRANSMOG RESULTS ARE EMPTY", "Select a category and index the collection. The UI can take time to populate the local appearance cache. Not every appearance is exposed to an addon.","",
        "MAP PIN IS MISSING OR WRONG", "Check that the item's dungeon, difficulty, boss and source match the Adventure Guide. Show Entrance and Show Boss have different purposes. Do not assume an unknown destination is accurate.","",
        "BOSS OR VENDOR HAS NO KNOWN SOURCE", "Visit the source in game or scan an Adventure Guide entry. Gear Hunter cannot connect to Wowhead in real time from inside WoW.","",
        "ALTS OR LOCKOUTS LOOK OUTDATED", "Log onto each character to update snapshots. Press Refresh Lockouts for the current character; saved lockouts are not a live check of offline characters.","",
        "ICONS OR ART LOOK OUTDATED", "Exit WoW fully before installing updates. Extract into _retail_/Interface/AddOns and allow overwriting. If files were renamed between versions, remove only the old GearHunter addon folder first; do NOT delete your WTF saved settings.","",
        "REPORT A PROBLEM", "Include your Gear Hunter version, the tab that fails, steps to reproduce it, and a screenshot if available. For addon errors, turn on WoW Lua error reporting or use an error-capturing addon. Gear Hunter does not automatically transmit diagnostics."
    },"\n"),
    COMMANDS=table.concat({
        "CHAT COMMANDS", "",
        "/gh                     Open Gear Hunter", "/gh support          Open this Support Center", "/gh whatsnew        Open release notes", "/gh report              Report an addon issue",
        "/gh character       Live character and equipment", "/gh scan               Scan Adventure Guide loot", "/gh gear                Equipped items", "/gh smart              Smart Picks", "/gh plan                Upgrade Planner",
        "/gh search             Gear Search", "/gh catalog           Index the broader Adventure Guide", "/gh capture           Capture open vendor, quest or profession sources",
        "/gh bosses           Boss Loot Hunter", "/gh favorites        Saved bosses and instances", "/gh mog               Transmog Hunter", "/gh hunt               Hunt List", "/gh route              Farm Route",
        "/gh weekly           Saved lockouts", "/gh alts                 Saved character snapshots", "/gh collection       Collection Dashboard", "/gh session          Farm Session Tracker",
        "/gh farmstart       Begin a farming session", "/gh farmstop        Finish a farming session", "/gh status             Scan and source status", "/gh scene              Character scene information", "/gh auto                Automatic scene background",
        "", "Most tools also have buttons on the main Gear Hunter interface."
    },"\n"),
    SUPPORT=table.concat({
        "REPORT AN ISSUE OR ASK FOR HELP", "",
        "If Gear Hunter behaves incorrectly, record which screen was open and what happened.","",
        "1. CHECK THE VERSION", "Look at the version shown on Gear Hunter's main window. The About page also provides copyable diagnostics.","",
        "2. RECORD WHAT HAPPENED", "Include the feature, the item or encounter, steps to reproduce, expected result, and actual result.","",
        "3. INCLUDE A SCREENSHOT", "A screenshot makes UI overlaps, disappearing icons, and misplaced pins much easier to investigate.","",
        "4. CHECK LUA ERRORS", "If possible, enable WoW Lua error reporting or use a trusted error-viewing addon and include the error text.","",
        "5. COPY THE REPORT DETAILS", "Use SELECT DIAGNOSTICS below, press Ctrl+C, and include the text with your report.","",
        "Gear Hunter does not automatically transmit bug reports or personal information."
    },"\n"),
    ABOUT=table.concat({
        "ABOUT GEAR HUNTER", "", "A community-oriented World of Warcraft gear and collection companion.","",
        "Gear Hunter is a fan-made addon. Not affiliated with, endorsed by, or sponsored by Blizzard Entertainment or Wowhead.","",
        "Gear data is subject to the game's available interfaces, item caches, and Adventure Guide coverage. Gear Hunter never claims to access Wowhead live inside WoW.","",
        "SUPPORT & UPDATES", "Release notes and guides are shipped with each addon ZIP. When the version changes, the top-right ? shows NEW until you view What's New.","",
        "LOCAL DATA", "Saved goals, snapshots, and bookmarks live in the WoW GearHunterDB saved variables. Uninstalling the addon folder does not normally remove your WoW WTF settings.","",
        "DIAGNOSTICS", "For a support report, use the selectable details field below and press Ctrl+C."
    },"\n"),
}
local function currentBody(page)
    if page=="NEWS" then return formatReleases() end
    return BODY[page] or BODY.HOME
end
local function scaleToScreen(frame)
    if not UIParent then return end
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    if not w or not h or w<=0 or h<=0 then return end
    frame:SetScale(math.min(1.14,(w-65)/1080,(h-65)/740))
    frame:ClearAllPoints()
    frame:SetPoint("CENTER",UIParent,"CENTER",0,0)
end
function GH:UpdateSupportNewBadge()
    local viewed=self.db and self.db.options and self.db.options.supportSeenVersion
    if self.supportNewBadge then self.supportNewBadge:SetShown(viewed~=self.version) end
end
function GH:ShowSupportPage(page)
    self.supportPage=page or self.supportPage or "HOME"
    if not self.supportFrame then return end
    local f=self.supportFrame
    for _,b in ipairs(self.supportNavButtons or {}) do
        local selected=b.page==self.supportPage
        b:SetBackdropColor(selected and 0.14 or 0.027,selected and 0.15 or 0.072,selected and 0.21 or 0.124,1)
        b:SetBackdropBorderColor(selected and 1 or 0.34,selected and 0.83 or 0.56,selected and 0.32 or 0.73,1)
    end
    local headings={HOME="SUPPORT CENTER",NEWS="WHAT'S NEW",START="GETTING STARTED",GUIDES="FEATURE GUIDES",TROUBLE="TROUBLESHOOTING",COMMANDS="SLASH COMMANDS",SUPPORT="REPORT AN ISSUE",ABOUT="ABOUT GEAR HUNTER"}
    self.supportHeading:SetText(headings[self.supportPage] or "SUPPORT CENTER")
    local showReport=self.supportPage=="SUPPORT" or self.supportPage=="ABOUT"
    self.supportLinkArea:SetShown(showReport)
    self.supportDiagnosticControls:SetShown(showReport)
    if showReport then self.supportDiagnosticText:SetText(self:GetSupportDiagnostics()) end
    -- Keep the report detail field below the help text on Report/About pages.
    self.supportScroll:ClearAllPoints()
    self.supportScroll:SetPoint("TOPLEFT",self.supportContentPanel,"TOPLEFT",17,-53)
    self.supportScroll:SetPoint("BOTTOMRIGHT",self.supportContentPanel,"BOTTOMRIGHT",-38,showReport and 146 or 21)
    self.supportBody:SetText(currentBody(self.supportPage))
    local bodyHeight=self.supportBody:GetStringHeight() or 400
    self.supportContent:SetHeight(math.max(bodyHeight+45,455))
    self.supportScroll:SetVerticalScroll(0)
    if self.supportPage=="NEWS" then
        if self.db and self.db.options then self.db.options.supportSeenVersion=self.version end
        self:UpdateSupportNewBadge()
    end
end
function GH:OpenSupportCenter(page)
    if not self.supportFrame then self:CreateSupportCenter() end
    if not self.supportFrame then return end
    scaleToScreen(self.supportFrame)
    self.supportFrame:Show()
    self:ShowSupportPage(page or "HOME")
end
function GH:ToggleSupportCenter()
    if self.supportFrame and self.supportFrame:IsShown() then self.supportFrame:Hide()
    else self:OpenSupportCenter("HOME") end
end
function GH:CreateSupportCenter()
    if self.supportFrame then return end
    local f=CreateFrame("Frame","GearHunterSupportCenterFrame",UIParent,"BackdropTemplate")
    f:SetSize(1080,740)
    f:SetPoint("CENTER",UIParent,"CENTER")
    f:SetFrameStrata("DIALOG");f:SetFrameLevel(40)
    f:SetClampedToScreen(true);f:SetMovable(false);f:EnableMouse(true)
    paint(f,0.012,0.030,0.057,0.99,{0.85,0.67,0.27,1})
    local glow=f:CreateTexture(nil,"BACKGROUND",nil,-3)
    glow:SetTexture(ROOT.."ReferenceBlueGlow.tga")
    glow:SetPoint("TOPLEFT",f,"TOPLEFT",-14,14)
    glow:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",14,-14)
    glow:SetBlendMode("ADD");glow:SetVertexColor(0.40,0.65,1,0.78)
    local crest=f:CreateTexture(nil,"ARTWORK")
    crest:SetTexture(ROOT.."MidnightCorner.tga")
    crest:SetSize(75,75);crest:SetPoint("TOPLEFT",f,"TOPLEFT",5,-1)
    local heading=text(f,"GEAR HUNTER  |  SUPPORT CENTER","GameFontNormalLarge")
    heading:SetPoint("TOPLEFT",f,"TOPLEFT",90,-24)
    heading:SetTextColor(unpack(COLORS.gold));heading:SetWidth(750)
    self.supportVersion=text(f,"v"..tostring(self.version),"GameFontNormalSmall")
    self.supportVersion:SetPoint("TOPLEFT",f,"TOPLEFT",94,-49)
    self.supportVersion:SetTextColor(unpack(COLORS.blue))
    makeButton(f,"X",1024,-22,35,32,function() f:Hide() end)
    local divider=f:CreateTexture(nil,"ARTWORK")
    divider:SetColorTexture(0.88,0.68,0.26,0.92)
    divider:SetPoint("TOPLEFT",f,"TOPLEFT",23,-89);divider:SetSize(1033,2)
    local nav=CreateFrame("Frame",nil,f,"BackdropTemplate")
    nav:SetPoint("TOPLEFT",f,"TOPLEFT",21,-106);nav:SetSize(226,607)
    paint(nav,0.016,0.041,0.075,0.98,{0.35,0.49,0.72,1})
    self.supportNavButtons={}
    for i,entry in ipairs(PAGES) do
        local b=makeButton(nav,entry[1],10,-13-(i-1)*56,206,47,function() GH:ShowSupportPage(entry[2]) end)
        b.page=entry[2]
        b.text:SetJustifyH("LEFT")
        b.text:ClearAllPoints();b.text:SetPoint("LEFT",b,"LEFT",13,0)
        self.supportNavButtons[#self.supportNavButtons+1]=b
    end
    local navFooter=text(nav,"Find  |  Upgrade  |  Navigate","GameFontNormalSmall")
    navFooter:SetPoint("BOTTOM",nav,"BOTTOM",0,18)
    navFooter:SetTextColor(unpack(COLORS.blue))
    local content=CreateFrame("Frame",nil,f,"BackdropTemplate")
    content:SetPoint("TOPLEFT",f,"TOPLEFT",260,-106)
    content:SetSize(796,607)
    paint(content,0.018,0.041,0.076,0.97,{0.46,0.51,0.55,1})
    self.supportContentPanel=content
    self.supportHeading=text(content,"SUPPORT CENTER","GameFontNormalLarge")
    self.supportHeading:SetPoint("TOPLEFT",content,"TOPLEFT",19,-13)
    self.supportHeading:SetTextColor(unpack(COLORS.gold))
    local scroll=CreateFrame("ScrollFrame","GearHunterSupportTextScroll",content,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",content,"TOPLEFT",17,-53)
    scroll:SetPoint("BOTTOMRIGHT",content,"BOTTOMRIGHT",-38,21)
    scroll:EnableMouseWheel(true)
    local child=CreateFrame("Frame",nil,scroll)
    child:SetWidth(716);child:SetHeight(500)
    scroll:SetScrollChild(child)
    local body=text(child,"","GameFontHighlight")
    body:SetPoint("TOPLEFT",child,"TOPLEFT",1,-8)
    body:SetWidth(706);body:SetJustifyH("LEFT");body:SetJustifyV("TOP")
    body:SetWordWrap(true);body:SetTextColor(0.88,0.93,0.99,1)
    self.supportScroll=scroll
    self.supportContent=child
    self.supportBody=body
    local linkArea=CreateFrame("Frame",nil,content,"BackdropTemplate")
    linkArea:SetPoint("BOTTOMLEFT",content,"BOTTOMLEFT",8,8)
    linkArea:SetSize(780,118)
    paint(linkArea,0.025,0.066,0.115,1,{0.44,0.63,0.77,1})
    linkArea:Hide()
    self.supportLinkArea=linkArea
    -- Report details are selectable, but never transmitted by the addon.
    local diagnostic=CreateFrame("Frame",nil,linkArea)
    diagnostic:SetAllPoints(linkArea);self.supportDiagnosticControls=diagnostic
    local dl=text(diagnostic,"SELECTABLE REPORT DETAILS","GameFontNormalSmall")
    dl:SetPoint("TOPLEFT",diagnostic,"TOPLEFT",10,-10);dl:SetTextColor(unpack(COLORS.gold))
    local dfield=CreateFrame("EditBox",nil,diagnostic,"InputBoxTemplate")
    dfield:SetPoint("TOPLEFT",diagnostic,"TOPLEFT",15,-36);dfield:SetSize(725,28)
    dfield:SetAutoFocus(false);dfield:SetMaxLetters(650)
    dfield:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    self.supportDiagnosticText=dfield
    makeButton(diagnostic,"SELECT DIAGNOSTICS",12,-76,215,29,function()
        dfield:SetText(GH:GetSupportDiagnostics());dfield:SetFocus();dfield:HighlightText()
    end)
    local extra=text(diagnostic,"Ctrl+C to copy; paste into a bug report.","GameFontNormalSmall")
    extra:SetPoint("TOPLEFT",diagnostic,"TOPLEFT",250,-84)
    extra:SetTextColor(unpack(COLORS.blue))
    self.supportFrame=f
    if UISpecialFrames then table.insert(UISpecialFrames,"GearHunterSupportCenterFrame") end
    local watch=CreateFrame("Frame",nil,UIParent)
    watch:RegisterEvent("DISPLAY_SIZE_CHANGED");watch:RegisterEvent("UI_SCALE_CHANGED")
    watch:SetScript("OnEvent",function() if f:IsShown() then scaleToScreen(f) end end)
    f:Hide()
    self:ShowSupportPage("HOME")
end
