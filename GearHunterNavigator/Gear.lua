local ADDON, GHN = ...
-- Conservative, entirely in-game bag comparison. The scanner never equips,
-- moves, vendors or changes an item, and never estimates remote loot tables.
local EQUIP = {
  {1,"Head",{INVTYPE_HEAD=true}},
  {2,"Neck",{INVTYPE_NECK=true}},
  {3,"Shoulder",{INVTYPE_SHOULDER=true}},
  {5,"Chest",{INVTYPE_CHEST=true,INVTYPE_ROBE=true}},
  {6,"Waist",{INVTYPE_WAIST=true}},
  {7,"Legs",{INVTYPE_LEGS=true}},
  {8,"Feet",{INVTYPE_FEET=true}},
  {9,"Wrist",{INVTYPE_WRIST=true}},
  {10,"Hands",{INVTYPE_HAND=true}},
  {11,"Ring 1",{INVTYPE_FINGER=true}},
  {12,"Ring 2",{INVTYPE_FINGER=true}},
  {13,"Trinket 1",{INVTYPE_TRINKET=true}},
  {14,"Trinket 2",{INVTYPE_TRINKET=true}},
  {15,"Back",{INVTYPE_CLOAK=true}},
  {16,"Main Hand",{INVTYPE_WEAPON=true,INVTYPE_WEAPONMAINHAND=true,INVTYPE_2HWEAPON=true,INVTYPE_RANGED=true,INVTYPE_RANGEDRIGHT=true}},
  {17,"Off Hand",{INVTYPE_WEAPON=true,INVTYPE_WEAPONOFFHAND=true,INVTYPE_SHIELD=true,INVTYPE_HOLDABLE=true}},
}
local function SafeCall(fn,...)
  if type(fn)~="function" then return nil end
  local ok,value=pcall(fn,...)
  if ok and (not issecretvalue or not issecretvalue(value)) then return value end
  return nil
end
-- WoW client versions expose these functions either as globals or through C_Item.
-- Treat missing cache records as unknown: never turn an unreadable item into
-- an upgrade or into a guaranteed unusable item.
local function ItemAPI(globalFn,member)
  if type(globalFn)=="function" then return globalFn end
  return C_Item and type(C_Item[member])=="function" and C_Item[member] or nil
end
local function ItemLevel(link)
  local n=SafeCall(GetDetailedItemLevelInfo,link)
  if (type(n)~="number" or n<=0) and C_Item then
    n=SafeCall(C_Item.GetDetailedItemLevelInfo,link)
  end
  if type(n)=="number" and n>0 and n<100000 then return n end
end
local function ItemType(link)
  local id,loc,classID,subclassID
  local fn=ItemAPI(GetItemInfoInstant,"GetItemInfoInstant")
  if fn then
    local ok,a,b,c,d,e,f,g=pcall(fn,link)
    -- GetItemInfoInstant: itemID,itemType,itemSubType,equipLoc,icon,classID,subClassID.
    if ok then id,loc,classID,subclassID=a,d,f,g end
  end
  if (type(loc)~="string" or loc=="") and C_Item and
      type(C_Item.GetItemInfoInstant)=="function" and fn~=C_Item.GetItemInfoInstant then
    local ok,a,b,c,d,e,f,g=pcall(C_Item.GetItemInfoInstant,link)
    if ok then id,loc,classID,subclassID=a,d,f,g end
  end
  if type(loc)~="string" or loc=="" then
    local full=ItemAPI(GetItemInfo,"GetItemInfo")
    if full then
      local ok,_,_,_,_,_,_,_,_,equiploc,_,_,cls,subcls=pcall(full,link)
      if ok then loc=equiploc;classID=cls;subclassID=subcls end
    end
  end
  if issecretvalue then
    local ok,secret=pcall(issecretvalue,loc)
    if ok and secret then return nil,nil,nil,id end
  end
  return loc,classID,subclassID,id
end
local function CanWear(link)
  local usable=ItemAPI(IsUsableItem,"IsUsableItem")
  if usable then
    local ok,result=pcall(usable,link)
    if ok and result==false then return false end
  end
  local equip=ItemAPI(IsEquippableItem,"IsEquippableItem")
  if equip then
    local ok,result=pcall(equip,link)
    if ok and result==false then return false end
  end
  return true
end
-- WoW's C_Item/GetItemInfoInstant reports class 4 for armor and subclasses
-- 1 cloth, 2 leather, 3 mail, 4 plate. Every playable class gets a check;
-- jewelry, cloaks, off-hands, and trinkets are not armor proficiency tests.
local ARMOR_SUBCLASS={WARRIOR=4,PALADIN=4,DEATHKNIGHT=4,
  HUNTER=3,SHAMAN=3,EVOKER=3,
  ROGUE=2,DRUID=2,MONK=2,DEMONHUNTER=2,
  MAGE=1,PRIEST=1,WARLOCK=1}
local PROTECTED_ARMOR={INVTYPE_HEAD=true,INVTYPE_SHOULDER=true,
  INVTYPE_CHEST=true,INVTYPE_ROBE=true,INVTYPE_WAIST=true,
  INVTYPE_LEGS=true,INVTYPE_FEET=true,INVTYPE_WRIST=true,INVTYPE_HAND=true}
local function IsCompatibleArmor(classToken,equipLoc,classID,subclassID)
  local required=ARMOR_SUBCLASS[classToken]
  if required and classID==4 and PROTECTED_ARMOR[equipLoc]
    and type(subclassID)=="number" and subclassID>0 and subclassID<=4 then
    return subclassID==required
  end
  return true
end
-- Only the game client owns remote loot/item records. On a missing cache
-- record, ask Blizzard to load it and retry after data-ready events.
local function RequestMissingBagItem(link, requested)
  local id=type(link)=="string" and tonumber(link:match("item:(%d+)")) or nil
  if not id or requested[id] then return end
  requested[id]=true
  if C_Item and type(C_Item.RequestLoadItemDataByID)=="function" then
    pcall(C_Item.RequestLoadItemDataByID,id)
  elseif type(GetItemInfo)=="function" then pcall(GetItemInfo,id) end
end
-- Try the retail container API first, but a bad/unavailable API must not
-- silently turn a character's inventory into an empty bag.
local function GetBagLink(bag,slot)
  local link=C_Container and SafeCall(C_Container.GetContainerItemLink,bag,slot)
  if type(link)~= "string" then link=SafeCall(GetContainerItemLink,bag,slot) end
  if type(link)~= "string" and C_Container then
    local info=SafeCall(C_Container.GetContainerItemInfo,bag,slot)
    if type(info)=="table" then
      link=info.hyperlink or info.itemLink
    end
  end
  return type(link)=="string" and link or nil
end
local function BagSlots(bag)
  local n=C_Container and SafeCall(C_Container.GetContainerNumSlots,bag)
  if type(n)~="number" then n=SafeCall(GetContainerNumSlots,bag) end
  if type(n)=="number" and n>=0 and n<=200 then return n,true end
  return 0,false
end
function GHN:ScanBagUpgrades()
  local scan={results={},checked=0,unknown=0,skipped=0,slots=0,
    bagsRead=0,bagsUnavailable=0,itemsSeen=0,equipmentSeen=0,unsupported=0,
    unusable=0,notHigher=0,unknownEquipped=0,bagCount=0,requests=0,
    tooHighLevel=0,comingSoon=0,equipNow=0,unknownRequired=0}
  local classToken=SafeCall(function() local _,token=UnitClass("player"); return token end)
  local equipped={}
  for _,slot in ipairs(EQUIP) do
    local link=SafeCall(GetInventoryItemLink,"player",slot[1])
    equipped[slot[1]]={link=link,level=link and ItemLevel(link) or nil}
  end
  local maxBags=type(NUM_BAG_SLOTS)=="number" and NUM_BAG_SLOTS or 4
  maxBags=math.max(0,math.min(maxBags,6))
  scan.bagCount=maxBags+1
  local seen={}
  local pendingRequests={}
  for bag=0,maxBags do
    local slots,available=BagSlots(bag)
    if available then scan.bagsRead=scan.bagsRead+1 else scan.bagsUnavailable=scan.bagsUnavailable+1 end
    scan.slots=scan.slots+slots
    for slot=1,slots do
      local link=GetBagLink(bag,slot)
      if link then
        scan.itemsSeen=scan.itemsSeen+1
        local equipLoc,classID,subclassID=ItemType(link)
        local matchesSlot=false
        if type(equipLoc)=="string" then
          for _,info in ipairs(EQUIP) do
            if info[3][equipLoc] then matchesSlot=true;break end
          end
        end
        if not matchesSlot then
          if type(equipLoc)~="string" then
            scan.unknown=scan.unknown+1 -- Item data not cached yet.
            RequestMissingBagItem(link,pendingRequests)
          else
            -- This includes potions, materials and unsupported equipment types.
            scan.unsupported=scan.unsupported+1
          end
        else
          scan.equipmentSeen=scan.equipmentSeen+1
          local req=self:GetRequiredGearLevel(link)
          local levelGroup,levelReason=self:ClassifyGearLevel(req)
          if levelReason=="too-high-level" then
            scan.tooHighLevel=scan.tooHighLevel+1
          elseif not levelGroup then
            scan.unknown=scan.unknown+1
            scan.unknownRequired=scan.unknownRequired+1
            RequestMissingBagItem(link,pendingRequests)
          elseif not IsCompatibleArmor(classToken,equipLoc,classID,subclassID) or
              (levelGroup=="now" and not CanWear(link)) then
            scan.unusable=scan.unusable+1
          else
            local ilvl=ItemLevel(link)
            if not ilvl then
              scan.unknown=scan.unknown+1
              RequestMissingBagItem(link,pendingRequests)
            else
              scan.checked=scan.checked+1
              local target,oldLevel,oldLink
              local unresolved=false
              -- Rings and trinkets compare against the lower of their two slots.
              -- Never call an unknown equipped item level zero by mistake.
              for _,info in ipairs(EQUIP) do
                if info[3][equipLoc] then
                  local current=equipped[info[1]]
                  if current.link and not current.level then
                    unresolved=true
                  else
                    local baseline=current.level or 0
                    if ilvl>baseline and (not oldLevel or baseline<oldLevel) then
                      target=info;oldLevel=baseline;oldLink=current.link
                    end
                  end
                end
              end
              if target then
                local key=bag..":"..slot
                if not seen[key] then
                  seen[key]=true
                  local name=link:match("%[(.-)%]") or "Bag item"
                  scan.results[#scan.results+1]={
                    link=link,name=name,ilvl=ilvl,oldIlvl=oldLevel,delta=ilvl-oldLevel,
                    oldLink=oldLink,slotName=target[2],slotID=target[1],bag=bag,bagSlot=slot,
                    equipLoc=equipLoc,requiredLevel=req,levelGroup=levelGroup,
                    needsEligibilityCheck=levelGroup=="soon",
                  }
                  if levelGroup=="now" then scan.equipNow=scan.equipNow+1
                  else scan.comingSoon=scan.comingSoon+1 end
                end
              elseif unresolved then
                scan.unknownEquipped=scan.unknownEquipped+1
              else
                scan.notHigher=scan.notHigher+1
              end
            end
          end
        end
      end
    end
  end
  table.sort(scan.results,function(a,b)
    if a.levelGroup~=b.levelGroup then return a.levelGroup=="now" end
    if a.delta==b.delta then return a.name<b.name end
    return a.delta>b.delta
  end)
  for _ in pairs(pendingRequests) do scan.requests=scan.requests+1 end
  self.gearScan=scan
  self.gearScanDirty=false
  self.gearScanTime=date and date("%H:%M:%S") or "now"
  return scan
end

-- Journal loot is *not owned*. Evaluate only reliable, equippable +1 or better
-- candidates against real worn slots. Missing data stays unranked, not assumed.
function GHN:EvaluateExternalLoot(link)
  if type(link)~="string" then return nil,"uncached-link" end
  local loc,classID,subclassID=ItemType(link)
  if type(loc)~="string" then return nil,"uncached-type" end
  -- A cached non-equipment record is different from gear that the class
  -- cannot equip. Both are distinct from a pending, uncached record.
  if loc=="" then return nil,"notEquipment" end
  local candidateSlot=false
  for _,slot in ipairs(EQUIP) do
    if slot[3][loc] then candidateSlot=true;break end
  end
  if not candidateSlot then return nil,"unsupportedSlot" end
  local token=SafeCall(function()local _,t=UnitClass("player");return t end)
  if not IsCompatibleArmor(token,loc,classID,subclassID) then return nil,"armorMismatch" end
  local required=self:GetRequiredGearLevel(link)
  local levelGroup,levelReason=self:ClassifyGearLevel(required)
  if not levelGroup then return nil,levelReason end
  -- Encounter Journal links are unowned loot. IsUsableItem is the "use now"
  -- predicate and rejects many pieces of equipment that are perfectly valid
  -- future gear targets. Never use it to filter remote loot.
  -- IsEquippableItem can still be inconclusive for a preview or a future
  -- requirement; flag those items for review instead of silently excluding.
  local equipFn=ItemAPI(IsEquippableItem,"IsEquippableItem")
  local equipStatus
  if type(equipFn)=="function" then
    local ok,result=pcall(equipFn,link)
    if ok and (not issecretvalue or not issecretvalue(result)) then
      if result==true or result==1 then equipStatus=true
      elseif result==false then equipStatus=false end
    end
  end
  local level=ItemLevel(link)
  if not level then return nil,"uncached-level" end
  local selected,oldLevel,oldLink
  local missingWorn=false
  for _,slot in ipairs(EQUIP) do
    if slot[3][loc] then
      local worn=SafeCall(GetInventoryItemLink,"player",slot[1])
      local wornLevel=worn and ItemLevel(worn) or 0
      if worn and not wornLevel then
        missingWorn=true
      elseif level>wornLevel and (not oldLevel or wornLevel<oldLevel) then
        selected=slot;oldLevel=wornLevel;oldLink=worn
      end
    end
  end
  if not selected then return nil,missingWorn and "uncached-equipped" or "notHigher" end
  return {link=link,name=link:match("%[(.-)%]") or "Journal loot",ilvl=level,
    oldIlvl=oldLevel,delta=level-oldLevel,oldLink=oldLink,slotName=selected[2],slotID=selected[1],
    requiredLevel=required,levelGroup=levelGroup,
    needsEligibilityCheck=equipStatus~=true or levelGroup=="soon",
    eligibilityNote=levelGroup=="soon" and ("Coming soon at character level "..required..". Check class/spec and other requirements before farming.") or
      (equipStatus==false and "WoW did not confirm that you can equip this journal item. Check class, level and other requirements before farming." or
      (equipStatus==nil and "Equippability was not confirmed for this journal preview. Check the item's requirements in the Adventure Guide." or
      "Potential item-level gain; verify stats, specialization, difficulty and access before farming."))}
end
