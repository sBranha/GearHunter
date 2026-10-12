-- Gear Hunter v0.11.2 - Gear Upgrade Planner.
-- Read-only planning. Upgrade caps use C_Item.GetItemUpgradeInfo; exact NPC
-- costs come only from the item placed in Blizzard's Item Upgrade UI.
-- Never invent upgrade costs or perform paid upgrades automatically.
local addonName, GH = ...
local dark={0.014,0.031,0.060,0.99}
local navy={0.026,0.062,0.110,0.99}
local edge={0.36,0.51,0.69,1}
local gold={1.00,0.81,0.29,1}
local white={0.82,0.91,0.99,1}
local green={0.39,1.0,0.59,1}
local orange={1.0,0.66,0.34,1}
local function style(w,bg)
    w:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    w:SetBackdropColor(unpack(bg or dark));w:SetBackdropBorderColor(unpack(edge))
end
local function panel(parent,x,y,w,h)
    local p=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    p:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);p:SetSize(w,h);style(p)
    return p
end
local function label(parent,s,x,y,w,large,color)
    local t=parent:CreateFontString(nil,"OVERLAY",large and "GameFontNormalLarge" or "GameFontNormal")
    t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);t:SetWidth(w)
    t:SetJustifyH("LEFT");t:SetTextColor(unpack(color or white));t:SetText(s or "")
    return t
end
local function button(parent,s,x,y,w,h,callback)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetSize(w,h);style(b,navy)
    b.caption=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    b.caption:SetAllPoints();b.caption:SetTextColor(unpack(gold));b.caption:SetText(s)
    b:SetScript("OnClick",callback)
    b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(unpack(gold)) end)
    b:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(unpack(edge)) end)
    return b
end
local function valid(n)
    if type(n)~="number" then return nil end
    if issecretvalue and issecretvalue(n) then return nil end
    return n==n and n~=math.huge and n~=-math.huge and n or nil
end
local function textSafe(s)
    if type(s)~="string" or (issecretvalue and issecretvalue(s)) then return nil end
    return s
end
local function playerKey()
    local id=UnitGUID and UnitGUID("player")
    if type(id)=="string" and id~="" then return id end
    return nil
end
local function upgradeKey(slot,own)
    return tostring(slot)..":"..tostring(own and own.itemID or 0)
end
function GH:InitializeUpgradePlanner()
    self.plannerSort=self.plannerSort or "Potential"
    self.plannerFilter=self.plannerFilter or "All"
    if self.db then
        if type(self.db.upgradePlans)~="table" then self.db.upgradePlans={} end
    end
end
function GH:GetUpgradePlans()
    self:InitializeUpgradePlanner()
    if not self.db then return {} end
    local id=playerKey()
    if not id then return {} end
    if type(self.db.upgradePlans[id])~="table" then self.db.upgradePlans[id]={} end
    return self.db.upgradePlans[id]
end
function GH:BuildUpgradePlanItems()
    local result={}
    for _,definition in ipairs(self.slotDefs or {}) do
        local slot=definition.id
        local own=self.equipped and self.equipped[slot]
        if own and valid(own.itemID) and own.itemID>0 then
            local up=own.upgrade
            -- Request fresh track data when the equipped item changed.
            if own.link and C_Item and C_Item.GetItemUpgradeInfo then
                local ok,res=pcall(C_Item.GetItemUpgradeInfo,own.link)
                if ok and type(res)=="table" then
                    up={current=valid(res.currentLevel),max=valid(res.maxLevel),
                        maxItemLevel=valid(res.maxItemLevel),track=textSafe(res.trackString)}
                    own.upgrade=up
                end
            end
            local base=valid(own.level) or 0
            local max=up and valid(up.maxItemLevel)
            local potential=max and base>0 and math.max(0,max-base) or nil
            local status=potential==nil and "Unknown" or potential>0 and "Upgradeable" or "At Cap"
            if self.plannerFilter=="All" or self.plannerFilter==status then
                local key=upgradeKey(slot,own)
                local plan=self:GetUpgradePlans()[key]
                result[#result+1]={slot=slot,own=own,up=up,base=base,max=max,potential=potential,
                    status=status,key=key,planned=(type(plan)=="table" and plan.starred==true),
                    target=(type(plan)=="table" and plan.target) or "NEXT"}
            end
        end
    end
    local mode=self.plannerSort
    table.sort(result,function(a,b)
        if mode=="Slot" then return a.slot<b.slot end
        if a.planned~=b.planned then return a.planned end
        if mode=="Closest" then
            if a.potential~=b.potential then
                return (a.potential or math.huge)<(b.potential or math.huge)
            end
        else
            if a.potential~=b.potential then
                return (a.potential or -1)>(b.potential or -1)
            end
        end
        return a.slot<b.slot
    end)
    return result
end
function GH:UpgradePlannerSelected()
    for _,entry in ipairs(self.upgradePlannerItems or {}) do
        if entry.key==self.upgradePlannerSelectedKey then return entry end
    end
    return (self.upgradePlannerItems or {})[1]
end
function GH:PlanUpgradePriority()
    local entry=self:UpgradePlannerSelected()
    if not entry then return end
    local plans=self:GetUpgradePlans()
    local old=plans[entry.key]
    old=type(old)=="table" and old or {target="NEXT"}
    old.starred=not (old.starred==true)
    plans[entry.key]=old
    self:RefreshUpgradePlanner()
end
function GH:PlanUpgradeTarget()
    local entry=self:UpgradePlannerSelected()
    if not entry then return end
    local plans=self:GetUpgradePlans()
    local old=plans[entry.key]
    old=type(old)=="table" and old or {starred=false}
    old.target=old.target=="MAX" and "NEXT" or "MAX"
    plans[entry.key]=old
    self:RefreshUpgradePlanner()
end
local function itemIDFromLink(link)
    if type(link)~="string" then return nil end
    return tonumber(link:match("|Hitem:(%d+):") or link:match("item:(%d+)"))
end
local function currencyBalance(id)
    if not C_CurrencyInfo or type(C_CurrencyInfo.GetCurrencyInfo)~="function" then return nil,nil end
    local ok,c=pcall(C_CurrencyInfo.GetCurrencyInfo,id)
    if ok and type(c)=="table" then
        return textSafe(c.name),valid(c.quantity)
    end
end
local function ownedItemCount(id)
    local fn=(C_Item and C_Item.GetItemCount) or GetItemCount
    if not fn then return nil end
    local ok,n=pcall(fn,id,true)
    return ok and valid(n) or nil
end
local function costString(costs)
    local textLines={}
    local affordable=true
    local known=true
    for _,cc in ipairs(costs.currency or {}) do
        if valid(cc.cost) and valid(cc.currencyID) then
            local name,have=currencyBalance(cc.currencyID)
            textLines[#textLines+1]=tostring(name or ("Currency #"..cc.currencyID))..": "..cc.cost..
                (have and (" / "..have.." owned") or " / balance unknown")
            if have==nil then known=false elseif have<cc.cost then affordable=false end
        else known=false end
    end
    for _,ic in ipairs(costs.items or {}) do
        if valid(ic.cost) and valid(ic.itemID) then
            local have=ownedItemCount(ic.itemID)
            local itemName="Item #"..ic.itemID
            if GetItemInfo then
                local ok,name=pcall(GetItemInfo,ic.itemID)
                if ok and textSafe(name) then itemName=name end
            end
            textLines[#textLines+1]=itemName..": "..ic.cost..
                (have and (" / "..have.." owned") or " / balance unknown")
            if have==nil then known=false elseif have<ic.cost then affordable=false end
        else known=false end
    end
    if valid(costs.money) and costs.money>0 then
        local amount=GetCoinTextureString and GetCoinTextureString(costs.money) or (costs.money.." copper")
        textLines[#textLines+1]="Gold: "..amount
        local balance=GetMoney and valid(GetMoney())
        if not balance then known=false elseif balance<costs.money then affordable=false end
    end
    if #textLines==0 then return "No cost breakdown reported for this step.",nil end
    return table.concat(textLines,"\n"),known and affordable or nil
end
local function gatherUpgradeCosts(info,targetRank)
    local list=info.upgradeLevelInfos
    if type(list)~="table" then return nil end
    local curr=valid(info.currUpgrade)
    if curr==nil then return nil end
    local stop=targetRank=="MAX" and (valid(info.maxUpgrade) or curr) or (curr+1)
    local costs={currency={},items={},money=0}
    local steps=0
    local seen=0
    local incomplete=false
    for rank=curr+1,math.min(stop,curr+30) do
        local step
        for _,candidate in ipairs(list) do
            if type(candidate)=="table" and candidate.upgradeLevel==rank then step=candidate;break end
        end
        -- Some clients use an indexed array instead of a keyed rank table.
        if not step then incomplete=true;break end
        steps=steps+1
        local hasAny=false
        for _,cc in ipairs(step.currencyCostsToUpgrade or {}) do
            if type(cc)=="table" and valid(cc.currencyID) and valid(cc.cost) then
                local found
                for _,old in ipairs(costs.currency) do
                    if old.currencyID==cc.currencyID then found=old;break end
                end
                if found then found.cost=found.cost+cc.cost
                else costs.currency[#costs.currency+1]={currencyID=cc.currencyID,cost=cc.cost} end
                hasAny=true
            end
        end
        for _,ic in ipairs(step.itemCostsToUpgrade or {}) do
            if type(ic)=="table" and valid(ic.itemID) and valid(ic.cost) then
                local found
                for _,old in ipairs(costs.items) do
                    if old.itemID==ic.itemID then found=old;break end
                end
                if found then found.cost=found.cost+ic.cost
                else costs.items[#costs.items+1]={itemID=ic.itemID,cost=ic.cost} end
                hasAny=true
            end
        end
        if valid(step.moneyCost) and step.moneyCost>0 then costs.money=costs.money+step.moneyCost;hasAny=true end
        if step.failureMessage and type(step.failureMessage)=="string" then incomplete=true end
        if hasAny then seen=seen+1 else incomplete=true end
    end
    if steps==0 or seen~=steps or incomplete then return nil end
    return costs,steps
end
function GH:ReadUpgradeNPC()
    if not C_ItemUpgrade or not C_ItemUpgrade.GetItemUpgradeItemInfo then
        self.upgradeNPCSnapshot=nil
        return nil
    end
    local ok,info=pcall(C_ItemUpgrade.GetItemUpgradeItemInfo)
    if not ok or type(info)~="table" or not info.itemUpgradeable then
        self.upgradeNPCSnapshot=nil
        return nil
    end
    local link
    if C_ItemUpgrade.GetItemHyperlink then
        local worked,l=pcall(C_ItemUpgrade.GetItemHyperlink)
        if worked then link=textSafe(l) end
    end
    local id=itemIDFromLink(link)
    self.upgradeNPCSnapshot={info=info,link=link,itemID=id}
    return self.upgradeNPCSnapshot
end
function GH:UpgradePlannerEquipSlot()
    local entry=self:UpgradePlannerSelected()
    if not entry or not entry.own.link then return end
    if GameTooltip then
        GameTooltip:SetOwner(self.upgradePlannerUI.details,"ANCHOR_CURSOR")
        pcall(GameTooltip.SetHyperlink,GameTooltip,entry.own.link)
        GameTooltip:Show()
    end
end
function GH:RefreshUpgradePlanner()
    local ui=self.upgradePlannerUI
    if not ui or not ui.panel:IsShown() then return end
    local items=self:BuildUpgradePlanItems()
    self.upgradePlannerItems=items
    local chosen=self:UpgradePlannerSelected()
    self.upgradePlannerSelectedKey=chosen and chosen.key or nil
    local available,atCap,unknown,starred=0,0,0,0
    for _,p in ipairs(items) do
        if p.status=="Upgradeable" then available=available+1
        elseif p.status=="At Cap" then atCap=atCap+1 else unknown=unknown+1 end
        if p.planned then starred=starred+1 end
    end
    ui.summary:SetText(#items.." PIECES  |  "..available.." UPGRADEABLE  |  "..atCap.." AT CAP  |  "..unknown.." UNKNOWN  |  "..starred.." PRIORITIES")
    for _,b in ipairs(ui.filterButtons) do
        b:SetBackdropBorderColor(unpack(b.choice==self.plannerFilter and gold or edge))
    end
    for _,b in ipairs(ui.sortButtons) do
        b:SetBackdropBorderColor(unpack(b.choice==self.plannerSort and gold or edge))
    end
    ui.scrollChild:SetHeight(math.max(1,#items*42))
    local scroll=valid(ui.scroll:GetVerticalScroll()) or 0
    local first=math.floor(math.max(0,scroll)/42)+1
    for i,row in ipairs(ui.rows) do
        local index=first+i-1
        local ent=items[index]
        if ent then
            row:ClearAllPoints();row:SetPoint("TOPLEFT",ui.scrollChild,"TOPLEFT",0,-(index-1)*42)
            row.entry=ent
            row.icon:SetTexture(self:GetDisplayItemIcon(ent.own))
            local name
            if ent.own.link and GetItemInfo then
                local ok,n=pcall(GetItemInfo,ent.own.link)
                if ok then name=textSafe(n) end
            end
            row.name:SetText((ent.planned and "*  " or "")..tostring(self.slotNames[ent.slot] or "Gear").."  -  "..tostring(name or ("Item #"..ent.own.itemID)))
            row.desc:SetText("Equipped "..(ent.base>0 and ("iLvl "..ent.base) or "item level unknown")..
                (ent.max and ("   /   cap "..ent.max) or "   /   cap unknown")..
                (ent.up and ent.up.track and ("   |   "..ent.up.track) or ""))
            row.gain:SetText(ent.potential and (ent.potential>0 and ("+"..ent.potential.." POSSIBLE") or "AT CAP") or "UNKNOWN")
            row.gain:SetTextColor(unpack(ent.potential and ent.potential>0 and green or white))
            row:SetBackdropBorderColor(unpack(chosen and ent.key==chosen.key and gold or edge))
            row:Show()
        else row.entry=nil;row:Hide() end
    end
    if not chosen then
        ui.item:SetText("NO EQUIPPED GEAR")
        ui.progress:SetText("Equip an item and refresh your character gear.")
        ui.itemIcon:SetTexture(self.missingItemIcon)
        ui.ranks:SetText("")
        ui.cost:SetText("Visit an item upgrader and place an item in the upgrade window to view its real costs.")
        ui.priority:SetEnabled(false);ui.target:SetEnabled(false)
        return
    end
    ui.priority:SetEnabled(true);ui.target:SetEnabled(true)
    ui.priority.caption:SetText(chosen.planned and "REMOVE PRIORITY" or "MARK PRIORITY")
    ui.target.caption:SetText(chosen.target=="MAX" and "TARGET: MAX RANK" or "TARGET: NEXT RANK")
    local n
    if chosen.own.link and GetItemInfo then
        local ok,name=pcall(GetItemInfo,chosen.own.link);if ok then n=textSafe(name) end
    end
    ui.item:SetText(n or (self.slotNames[chosen.slot] or "Equipped gear"))
    ui.itemIcon:SetTexture(self:GetDisplayItemIcon(chosen.own))
    ui.progress:SetText("Equipped iLvl "..(chosen.base>0 and chosen.base or "?")..
        "  |  Cap "..(chosen.max or "unknown")..
        "  |  "..(chosen.potential and ("+"..chosen.potential.." potential") or "unavailable"))
    local up=chosen.up
    ui.ranks:SetText("Upgrade track: "..tostring(up and up.track or "unknown")..
        "\nRank: "..tostring(up and up.current or "?").." / "..tostring(up and up.max or "?")..
        "\nPriority: "..(chosen.planned and "SAVED" or "not saved")..
        "    |    Target: "..(chosen.target=="MAX" and "maximum available rank" or "next available rank"))
    local snap=self:ReadUpgradeNPC()
    if not snap then
        ui.cost:SetText("LIVE NPC COST PREVIEW\n\nTalk to an item upgrader, place gear in Blizzard's Upgrade window, then click REFRESH COSTS. Exact costs cannot be read from gear alone.")
        ui.costStatus:SetText("No upgrade item selected at an NPC")
        return
    end
    local info=snap.info
    local name=textSafe(info.name) or "Selected upgrade item"
    local match=snap.itemID and chosen.own.itemID and snap.itemID==chosen.own.itemID
    local unique=true
    if match then
        for _,s in ipairs(items) do
            if s.slot~=chosen.slot and s.own.itemID==snap.itemID then unique=false end
        end
    end
    local costs,steps=gatherUpgradeCosts(info,chosen.target)
    local body="UPGRADER HAS: "..name.."\n"
    if not match or not unique then
        body=body.."Select the SAME item in Gear Hunter and at the NPC to compare costs."
        ui.costStatus:SetText("NPC item differs / matching slot uncertain")
    elseif not costs then
        body=body.."No complete cost breakdown was reported for this target.\nSee Blizzard's Upgrade window for the exact price."
        ui.costStatus:SetText("Upgrade details incomplete")
    else
        local breakdown,affordable=costString(costs)
        body=body..(chosen.target=="MAX" and "ALL REMAINING RANKS" or "NEXT RANK")..
            " ("..steps.." step"..(steps==1 and "" or "s")..")\n"..breakdown
        ui.costStatus:SetText(affordable==true and "You appear to have the required resources" or
            "Resource balance or eligibility not fully confirmed")
    end
    ui.cost:SetText(body)
end
function GH:CreateUpgradePlannerPanel(parent)
    self:InitializeUpgradePlanner()
    local p=panel(parent,29,-150,1542,558)
    local ui={panel=p,rows={},filterButtons={},sortButtons={}}
    self.upgradePlannerUI=ui
    label(p,"GEAR UPGRADE PLANNER",18,-11,1000,true,gold)
    label(p,"Plan equipped-item upgrade ranks. Real caps from WoW; exact costs only when Blizzard's item upgrader reports them.",18,-41,1480,false,white)
    local function filter(txt,x,w,choice)
        local b=button(p,txt,x,-77,w,31,function()
            GH.plannerFilter=choice;GH.upgradePlannerSelectedKey=nil
            ui.scroll:SetVerticalScroll(0);GH:RefreshUpgradePlanner()
        end)
        b.choice=choice;ui.filterButtons[#ui.filterButtons+1]=b
    end
    filter("ALL EQUIPMENT",18,168,"All")
    filter("UPGRADEABLE",192,151,"Upgradeable")
    filter("AT CAP",349,111,"At Cap")
    filter("UNKNOWN",466,132,"Unknown")
    local function sort(txt,x,w,choice)
        local b=button(p,txt,x,-77,w,31,function()
            GH.plannerSort=choice;ui.scroll:SetVerticalScroll(0);GH:RefreshUpgradePlanner()
        end)
        b.choice=choice;ui.sortButtons[#ui.sortButtons+1]=b
    end
    sort("BIGGEST POTENTIAL",796,189,"Potential")
    sort("CLOSEST TO CAP",991,180,"Closest")
    sort("SLOT ORDER",1177,160,"Slot")
    button(p,"MY GEAR",1344,-77,180,31,function() GH:ShowTab("My Gear") end)
    local left=panel(p,16,-123,873,398)
    ui.summary=label(left,"Reading gear...",12,-10,846,false,green)
    ui.scroll=CreateFrame("ScrollFrame",nil,left,"UIPanelScrollFrameTemplate")
    ui.scroll:SetPoint("TOPLEFT",left,"TOPLEFT",11,-39)
    ui.scroll:SetPoint("BOTTOMRIGHT",left,"BOTTOMRIGHT",-29,9)
    ui.scrollChild=CreateFrame("Frame",nil,ui.scroll)
    ui.scrollChild:SetSize(828,1);ui.scroll:SetScrollChild(ui.scrollChild)
    for i=1,9 do
        local row=CreateFrame("Button",nil,ui.scrollChild,"BackdropTemplate")
        row:SetSize(826,40);style(row,navy)
        row.icon=row:CreateTexture(nil,"ARTWORK")
        row.icon:SetSize(32,32);row.icon:SetPoint("LEFT",row,"LEFT",5,0)
        row.name=label(row,"",43,-3,642,false,gold)
        row.desc=label(row,"",43,-22,666,false,white)
        row.gain=label(row,"",685,-12,133,false,green)
        row.gain:SetJustifyH("RIGHT")
        row:SetScript("OnClick",function(self)
            if self.entry then GH.upgradePlannerSelectedKey=self.entry.key;GH:RefreshUpgradePlanner() end
        end)
        row:SetScript("OnEnter",function(self)
            if self.entry and self.entry.own.link and GameTooltip then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                if not pcall(GameTooltip.SetHyperlink,GameTooltip,self.entry.own.link) then
                    GameTooltip:SetText("Equipped item")
                end
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        row:Hide();ui.rows[#ui.rows+1]=row
    end
    ui.scroll:HookScript("OnVerticalScroll",function() GH:RefreshUpgradePlanner() end)
    local right=panel(p,900,-123,625,398)
    ui.details=right
    label(right,"EQUIPPED ITEM / UPGRADE TARGET",13,-10,593,true,gold)
    ui.itemIcon=right:CreateTexture(nil,"ARTWORK")
    ui.itemIcon:SetPoint("TOPLEFT",right,"TOPLEFT",16,-43);ui.itemIcon:SetSize(52,52)
    ui.item=label(right,"",78,-46,524,true,gold)
    ui.progress=label(right,"",78,-78,527,false,green)
    ui.ranks=label(right,"",15,-108,590,false,white)
    ui.ranks:SetHeight(67);ui.ranks:SetWordWrap(true)
    ui.costStatus=label(right,"",15,-179,584,false,orange)
    ui.cost=label(right,"",15,-207,593,false,white)
    ui.cost:SetHeight(114);ui.cost:SetWordWrap(true)
    ui.priority=button(right,"MARK PRIORITY",13,-342,181,35,function() GH:PlanUpgradePriority() end)
    ui.target=button(right,"TARGET: NEXT RANK",202,-342,196,35,function() GH:PlanUpgradeTarget() end)
    ui.refresh=button(right,"REFRESH COSTS",406,-342,205,35,function() GH:RefreshUpgradePlanner() end)
    label(p,"Read-only planner: upgrading itself is done in Blizzard's NPC window. Prices and discounts can change; the NPC remains authoritative.",18,-532,1468,false,orange)
    p:Hide()
end
-- Blizzard's upgrade NPC events update the preview; the panel never tries to
-- place items in the merchant UI or spend the player's currency.
local watcher=CreateFrame("Frame")
for _,eventName in ipairs({"ITEM_UPGRADE_MASTER_SET_ITEM","ITEM_UPGRADE_MASTER_UPDATE", "PLAYER_EQUIPMENT_CHANGED","CURRENCY_DISPLAY_UPDATE"}) do
    pcall(watcher.RegisterEvent,watcher,eventName)
end
watcher:SetScript("OnEvent",function()
    if GH.upgradePlannerUI and GH.upgradePlannerUI.panel:IsShown() then
        GH:RefreshUpgradePlanner()
    end
end)
