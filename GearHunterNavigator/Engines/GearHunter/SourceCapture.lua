-- Gear Hunter v0.10.3: additional gear origins seen in the LIVE Blizzard client.
-- An observation is NOT a claim that this is every possible item/source in WoW.
-- It only records equipment the user encounters in an open Blizzard UI.
local addonName, NAV = ...
local GH = NAV.GearEngine
local function validID(id)
    return type(id)=="number" and id>0 and id<100000000
end
local function positive(v)
    return type(v)=="number" and v>0 and v or nil
end
local function getItemID(link)
    if type(link)=="number" then return validID(link) and link or nil end
    if type(link)~="string" then return nil end
    local id=tonumber(link:match("|Hitem:(%d+):") or link:match("item:(%d+)"))
    return validID(id) and id or nil
end
local function findEquipment(link)
    local id=getItemID(link)
    if not id then return nil end
    local instant=GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant)
    local equipLoc,icon,classID
    if type(instant)=="function" then
        local ok,_,_,_,loc,ico,cls=pcall(instant,link)
        if ok then equipLoc=loc;icon=ico;classID=cls end
    end
    local name,fullLink,ilvl,reqLevel
    if type(GetItemInfo)=="function" then
        local ok,n,l,_,level,required,_,_,_,loc,ico,_,cls=pcall(GetItemInfo,link)
        if ok then
            name=n;fullLink=l;ilvl=level;reqLevel=required
            equipLoc=equipLoc or loc;icon=icon or ico;classID=classID or cls
        end
    end
    -- Do not index reagents, recipes, potions or miscellaneous junk as gear.
    if equipLoc==nil or equipLoc=="" or equipLoc=="INVTYPE_NON_EQUIP_IGNORE" then return nil end
    if classID and classID~=2 and classID~=4 then return nil end
    return {itemID=id,name=name,link=fullLink or link,icon=icon,
        level=positive(ilvl),requiredLevel=positive(reqLevel)}
end
local function record(self,item,extra)
    local gear=findEquipment(item)
    if not gear then return false end
    for k,v in pairs(extra) do gear[k]=v end
    if not gear.name and type(extra.itemName)=="string" then gear.name=extra.itemName end
    gear.sourceObserved=true
    self:RememberGearItem(gear)
    return true
end
local function vendorPosition()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return nil end
    local ok,map=pcall(C_Map.GetBestMapForUnit,"player")
    if not ok or type(map)~="number" then return nil end
    local success,pos=pcall(C_Map.GetPlayerMapPosition,map,"player")
    if not success or not pos then return nil end
    local x,y
    if type(pos.GetXY)=="function" then
        local have,px,py=pcall(pos.GetXY,pos)
        if have then x=px;y=py end
    end
    if not x and type(pos)=="table" then x=pos.x;y=pos.y end
    if type(x)=="number" and type(y)=="number" and x>0 and x<1 and y>0 and y<1 then
        return map,x,y
    end
end
function GH:CaptureMerchantGear()
    if not self.db or not (MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown()) or
        type(GetMerchantNumItems)~="function" or type(GetMerchantItemLink)~="function" then return nil end
    local name=(UnitName and (UnitName("npc") or UnitName("target"))) or "Unknown vendor"
    local map,x,y=vendorPosition()
    local ok,n=pcall(GetMerchantNumItems)
    if not ok or type(n)~="number" then return 0 end
    local count=0
    for i=1,math.min(n,300) do
        local success,link=pcall(GetMerchantItemLink,i)
        if success and link then
            local id=getItemID(link)
            local price,extendedCost,itemName
            if type(GetMerchantItemInfo)=="function" then
                local worked,n,_,cost,_,_,_,additional=pcall(GetMerchantItemInfo,i)
                if worked then itemName=n;price=cost;extendedCost=additional==true end
            end
            local sourceID=tostring(name):lower():gsub("[^%w]","_")
            if id and record(self,link,{sourceType="Vendor",vendorName=name,itemName=itemName,
                sourceKey="vendor:"..sourceID..":"..tostring(map or 0),
                mapID=map,mapX=x,mapY=y,price=price,extendedCost=extendedCost}) then
                count=count+1
            end
        end
    end
    self.gearSourceStatus="Captured "..count.." equipment listings from vendor: "..name
    return count
end
function GH:CaptureQuestRewardGear()
    if not self.db or not (QuestFrame and QuestFrame.IsShown and QuestFrame:IsShown()) then return nil end
    local questID
    if type(GetQuestID)=="function" then
        local ok,id=pcall(GetQuestID)
        if ok and validID(id) then questID=id end
    end
    local title
    if type(GetTitleText)=="function" then
        local ok,n=pcall(GetTitleText)
        if ok and type(n)=="string" and n~="" then title=n end
    end
    if not title and questID and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok,n=pcall(C_QuestLog.GetTitleForQuestID,questID)
        if ok then title=n end
    end
    if not title then return 0 end
    local count=0
    local categories={{"reward",GetNumQuestRewards},{"choice",GetNumQuestChoices}}
    for _,entry in ipairs(categories) do
        local kind,numFn=entry[1],entry[2]
        if type(numFn)=="function" and type(GetQuestItemLink)=="function" then
            local ok,n=pcall(numFn)
            if ok and type(n)=="number" then
                for i=1,math.min(n,30) do
                    local success,link=pcall(GetQuestItemLink,kind,i)
                    if success and link then
                        local label=questID or title:lower():gsub("[^%w]","_")
                        if record(self,link,{sourceType="Quest",questName=title,questID=questID,
                            sourceKey="quest:"..tostring(label)}) then count=count+1 end
                    end
                end
            end
        end
    end
    self.gearSourceStatus="Captured "..count.." equipment rewards from quest: "..title
    return count
end
local recipeWorker=CreateFrame("Frame")
local function stopRecipeWorker()
    recipeWorker:SetScript("OnUpdate",nil)
    GH.recipeCaptureJob=nil
end
function GH:CaptureProfessionGear(force)
    local api=C_TradeSkillUI
    if not self.db or not api or type(api.GetAllRecipeIDs)~="function" then return nil end
    if not (ProfessionsFrame and ProfessionsFrame.IsShown and ProfessionsFrame:IsShown()) and
       not (TradeSkillFrame and TradeSkillFrame.IsShown and TradeSkillFrame:IsShown()) then return nil end
    local ok,ids=pcall(api.GetAllRecipeIDs)
    if not ok or type(ids)~="table" then return 0 end
    local displayName="Profession"
    if type(api.GetTradeSkillDisplayName)=="function" then
        local good,n=pcall(api.GetTradeSkillDisplayName)
        if good and type(n)=="string" and n~="" then displayName=n end
    end
    local signature=displayName..":"..#ids..":"..tostring(ids[1] or 0)..":"..tostring(ids[#ids] or 0)
    if self.recipeCaptureSignature==signature and not force then return 0 end
    self.recipeCaptureSignature=signature
    stopRecipeWorker()
    self.recipeCaptureJob={ids=ids,index=1,count=0,profession=displayName,elapsed=0}
    recipeWorker:SetScript("OnUpdate",function(_,elapsed)
        local job=GH.recipeCaptureJob
        if not job then stopRecipeWorker();return end
        job.elapsed=job.elapsed+elapsed
        if job.elapsed<0.06 then return end
        job.elapsed=0
        for _=1,45 do
            local id=job.ids[job.index]
            job.index=job.index+1
            if not id then
                GH.gearSourceStatus="Captured "..job.count.." crafted equipment recipes ("..job.profession..")"
                stopRecipeWorker()
                if GH.RefreshGearSearch then GH:RefreshGearSearch() end
                return
            end
            local link,recipeName,learned
            if type(api.GetRecipeItemLink)=="function" then
                local ok,l=pcall(api.GetRecipeItemLink,id)
                if ok then link=l end
            end
            if type(api.GetRecipeInfo)=="function" then
                local ok,info=pcall(api.GetRecipeInfo,id)
                if ok and type(info)=="table" then recipeName=info.name;learned=info.learned==true end
            end
            if not link and type(api.GetRecipeSchematic)=="function" then
                local ok,schematic=pcall(api.GetRecipeSchematic,id,false)
                if ok and type(schematic)=="table" and validID(schematic.outputItemID) then
                    link="item:"..schematic.outputItemID
                end
            end
            if link and record(GH,link,{sourceType="Crafted",recipeName=recipeName,
                recipeID=id,profession=job.profession,recipeLearned=learned,
                sourceKey="recipe:"..id}) then job.count=job.count+1 end
        end
    end)
    return #ids
end
function GH:CaptureOpenGearSources(verbose)
    if not self.db then return end
    local captured=false
    local n=self:CaptureMerchantGear()
    if n~=nil then captured=true end
    n=self:CaptureQuestRewardGear()
    if n~=nil then captured=true end
    n=self:CaptureProfessionGear(true)
    if n~=nil then captured=true end
    if verbose then
        if captured then self:Print(self.gearSourceStatus or "Source capture started.")
        else self:Print("Open a vendor, quest reward, or profession window first; then capture its equipment.") end
    end
    if self.RefreshGearSearch then self:RefreshGearSearch() end
end
local observer=CreateFrame("Frame")
for _,event in ipairs({"MERCHANT_SHOW","MERCHANT_UPDATE","QUEST_COMPLETE","QUEST_ITEM_UPDATE",
    "TRADE_SKILL_SHOW","TRADE_SKILL_LIST_UPDATE","TRADE_SKILL_CLOSE", "GET_ITEM_INFO_RECEIVED"}) do
    pcall(observer.RegisterEvent,observer,event)
end
observer:SetScript("OnEvent",function(_,event,itemID,success)
    if not GH.db then return end
    if event=="GET_ITEM_INFO_RECEIVED" then
        if success and GH.gearPendingNames and GH.gearPendingNames[itemID] and
            type(GetItemInfo)=="function" then
            local ok,name,link,_,level,required,_,_,_,_,icon=pcall(GetItemInfo,itemID)
            if ok and type(name)=="string" then
                for _,rec in pairs(GH.gearSearchIndex or {}) do
                    if rec.itemID==itemID then
                        if type(rec.name)~="string" or rec.name:match("^Item #%d+$") then
                            rec.name=name
                        end
                        rec.link=link or rec.link
                        rec.icon=icon or rec.icon
                        rec.level=rec.level or level
                        rec.requiredLevel=rec.requiredLevel or required
                    end
                end
                GH.gearPendingNames[itemID]=nil
                if GH.RefreshGearSearch then GH:RefreshGearSearch() end
            end
        end
        return
    end
    if event=="TRADE_SKILL_CLOSE" then
        stopRecipeWorker()
        GH.recipeCaptureSignature=nil
    elseif event=="MERCHANT_SHOW" or event=="MERCHANT_UPDATE" then
        GH:CaptureMerchantGear()
    elseif event=="QUEST_COMPLETE" or event=="QUEST_ITEM_UPDATE" then
        GH:CaptureQuestRewardGear()
    elseif event=="TRADE_SKILL_SHOW" or event=="TRADE_SKILL_LIST_UPDATE" then
        GH:CaptureProfessionGear(false)
    else return end
    if GH.RefreshGearSearch then GH:RefreshGearSearch() end
end)
