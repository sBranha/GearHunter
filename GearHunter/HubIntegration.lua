-- GearHunter.net website integration; all links are copied manually, never opened automatically.
local addonName, GH = ...
local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function()
    if type(GearHubBridge_RecordLoad)=="function" then
        GearHubBridge_RecordLoad("gear-hunter", tostring((GH and GH.version) or "0.11.10"))
    end
end)
SLASH_GEARHUNTERWEBSITE1="/ghwebsite"
SlashCmdList.GEARHUNTERWEBSITE=function()
    print("|cffdfbc70Gear Hunter:|r Help, releases and support: https://gearhunter.net/addon.php?slug=gear-hunter")
    print("|cff93c5fdGear Hunter:|r Open /gh support > WEBSITE & SUPPORT to copy the URL.")
end
