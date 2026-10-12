-- Optional GearHunter.net Companion integration. Gear Hunter works without this file's companion.
-- WoW addons cannot make HTTP requests. Version notices are handled by GearHubBridge.
local f=CreateFrame('Frame')
f:RegisterEvent('PLAYER_LOGIN')
f:SetScript('OnEvent',function()
    if type(GearHubBridge_RecordLoad)=='function' then GearHubBridge_RecordLoad('gear-hunter','0.11.7') end
end)
SLASH_GEARHUNTERWEBSITE1='/ghwebsite'
SlashCmdList.GEARHUNTERWEBSITE=function() print('|cffdfbc70Gear Hunter:|r Updates and support: https://gearhunter.net/addon.php?slug=gear-hunter') end
