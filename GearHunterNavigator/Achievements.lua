local _,GHN=...
-- Uses the WoW client achievement APIs; no external network or manual imports.
local function text(parent,content,x,y,w,h,size)
  local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
  f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);f:SetSize(w,h)
  f:SetJustifyH("LEFT");f:SetJustifyV("TOP")
  if size then f:SetFont("Fonts\\FRIZQT__.TTF",size) end
  f:SetText(content or "");return f
end
local function button(parent,label,x,y,w,h,click)
  local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
  b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetSize(w,h);b:SetText(label)
  b:SetScript("OnClick",click);return b
end
local function scan()
  local entries,seen={},{}
  if type(GetCategoryList)~="function" or type(GetCategoryNumAchievements)~="function" then return entries,false end
  local ok,categories=pcall(GetCategoryList)
  if not ok or type(categories)~="table" then return entries,false end
  for _,category in ipairs(categories) do
    local name=type(GetCategoryInfo)=="function" and GetCategoryInfo(category) or tostring(category)
    local okCount,count=pcall(GetCategoryNumAchievements,category)
    count=okCount and tonumber(count) or 0
    for index=1,count do
      local okEntry,id=pcall(GetAchievementInfo,category,index)
      if okEntry and type(id)=="number" and not seen[id] then
        seen[id]=true
        local okDetail,aid,title,points,completed,month,day,year,description,flags,icon=pcall(GetAchievementInfo,id)
        if not okDetail then aid=nil end
        if aid and title and title~="" then
          entries[#entries+1]={id=id,name=title,points=points or 0,done=completed==true,
            date=(completed and month and day and year) and string.format("%02d/%02d/%04d",month,day,year) or nil,
            description=description or "",category=name or "Achievements",icon=icon}
        end
      end
    end
  end
  table.sort(entries,function(a,b)return a.name:lower()<b.name:lower() end)
  return entries,true
end
function GHN:CreateAchievementsPage()
  local parent=self.pages and self.pages["Achievements"]
  if not parent then return end
  local p=CreateFrame("Frame",nil,parent,"BackdropTemplate")
  p:SetPoint("TOPLEFT",parent,"TOPLEFT",14,-44);p:SetSize(1073,570)
  p:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
  p:SetBackdropColor(.015,.04,.07,.97)
  text(p,"YOUR WORLD OF WARCRAFT ACHIEVEMENTS",18,-15,920,30,20)
  text(p,"Search the achievements loaded by your WoW client. Earned and incomplete results are marked.",20,-52,990,27,13)
  local view={page=1,filter="All",category="All",selected=nil,records=nil,results={}}
  self.achievementView=view
  local search=CreateFrame("EditBox",nil,p,"InputBoxTemplate")
  search:SetPoint("TOPLEFT",p,"TOPLEFT",25,-94);search:SetSize(390,28)
  search:SetAutoFocus(false);search:SetMaxLetters(90)
  view.search=search
  view.categoryButton=button(p,"ALL CATEGORIES",857,-94,192,30,function()
    local options=view.categories or {"All"}
    local nextIndex=1
    for i,name in ipairs(options) do if name==view.category then nextIndex=i%#options+1;break end end
    view.category=options[nextIndex]
    view.categoryButton:SetText(view.category=="All" and "ALL CATEGORIES" or view.category:sub(1,22))
    view.page=1;GHN:RefreshAchievements()
  end)
  view.summary=text(p,"Loading achievements...",22,-135,1015,24,13)
  view.rows={}
  local detail=CreateFrame("Frame",nil,p,"BackdropTemplate")
  detail:SetPoint("TOPLEFT",p,"TOPLEFT",656,-163);detail:SetSize(398,332)
  detail:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
  detail:SetBackdropColor(.035,.07,.11,.97)
  view.detail=text(detail,"Select an achievement to see details.",14,-15,366,298,13)
  for i=1,10 do
    local index=i
    local b=button(p,"",20,-166-(i-1)*31,625,29,function()
      view.selected=view.rows[index].record
      GHN:RefreshAchievements()
    end)
    view.rows[i]=b
  end
  view.notice=text(p,"",20,-484,1020,25,12)
  button(p,"PREVIOUS",20,-517,135,32,function()view.page=view.page-1;GHN:RefreshAchievements()end)
  button(p,"NEXT",165,-517,135,32,function()view.page=view.page+1;GHN:RefreshAchievements()end)
  button(p,"TRACK ACHIEVEMENT",315,-517,208,32,function()
    if not view.selected then return end
    if type(AddTrackedAchievement)=="function" then
      local ok=pcall(AddTrackedAchievement,view.selected.id)
      view.notice:SetText(ok and "Achievement tracking requested." or "WoW did not allow tracking this achievement.")
    else view.notice:SetText("Achievement tracking is not available in this WoW client.") end
  end)
  button(p,"OPEN BLIZZARD ACHIEVEMENTS",537,-517,294,32,function()
    if InCombatLockdown and InCombatLockdown() then view.notice:SetText("Open Blizzard achievements outside combat.");return end
    if GHN.frame then GHN.frame:Hide() end
    if type(ToggleAchievementFrame)=="function" then
      ToggleAchievementFrame()
    elseif type(AchievementFrame_ToggleAchievementFrame)=="function" then
      AchievementFrame_ToggleAchievementFrame()
    else
      if GHN.frame then GHN.frame:Show() end
      view.notice:SetText("Open the WoW achievements window with its normal keybind.")
    end
  end)
  button(p,"REFRESH",848,-517,200,32,function()view.records=nil;GHN:RefreshAchievements()end)
  search:SetScript("OnTextChanged",function()
    view.page=1
    if GHN.db and GHN.db.tab=="Achievements" then GHN:RefreshAchievements() end
  end)
  view.filterButton=button(p,"ALL",685,-94,160,30,function()
    view.filter=view.filter=="All" and "Earned" or view.filter=="Earned" and "Incomplete" or "All"
    view.filterButton:SetText(string.upper(view.filter))
    view.page=1;GHN:RefreshAchievements()
  end)
  local listener=CreateFrame("Frame")
  for _,eventName in ipairs({"ACHIEVEMENT_EARNED","CRITERIA_UPDATE","ACHIEVEMENT_UPDATE","PLAYER_ENTERING_WORLD"}) do listener:RegisterEvent(eventName) end
  listener:SetScript("OnEvent",function()
    view.records=nil
    if GHN.db and GHN.db.tab=="Achievements" and GHN.frame and GHN.frame:IsShown() then GHN:RefreshAchievements() end
  end)
  view.eventListener=listener
end
function GHN:RefreshAchievements()
  local view=self.achievementView
  if not view then return end
  if not view.records then
    local ok,records,available=pcall(scan)
    view.records=ok and records or {}
    view.available=ok and available
    local categories,seenCategories={"All"},{}
    for _,r in ipairs(view.records) do
      if r.category and not seenCategories[r.category] then seenCategories[r.category]=true;categories[#categories+1]=r.category end
    end
    table.sort(categories,function(a,b)
      if a=="All" then return true elseif b=="All" then return false end
      return a:lower()<b:lower()
    end)
    view.categories=categories
  end
  local query=(view.search:GetText() or ""):lower():match("^%s*(.-)%s*$")
  local earned,results=0,{}
  for _,r in ipairs(view.records) do
    if r.done then earned=earned+1 end
    if (view.filter=="All" or (view.filter=="Earned")==r.done) and
       (view.category=="All" or view.category==r.category) and
       (query=="" or r.name:lower():find(query,1,true) or tostring(r.id):find(query,1,true)) then
      results[#results+1]=r
    end
  end
  local total=#view.records
  local pages=math.max(1,math.ceil(#results/10))
  view.page=math.max(1,math.min(view.page,pages))
  view.summary:SetText(string.format("Earned: %d  |  Incomplete: %d  |  Total loaded: %d  |  Matches: %d  |  Page %d/%d",
    earned,total-earned,total,#results,view.page,pages))
  if not view.available then
    view.notice:SetText("WoW achievement APIs are unavailable. Try opening Blizzard's Achievements window.")
  else view.notice:SetText("Showing the achievements currently available from your logged-in WoW client.") end
  for i,b in ipairs(view.rows) do
    local r=results[(view.page-1)*10+i]
    b.record=r
    if r then
      local label=(r.done and "[EARNED]  " or "[INCOMPLETE]  ")..r.name
      if #label>79 then label=label:sub(1,76).."..." end
      b:SetText(label);b:Show()
    else b:Hide() end
  end
  if view.selected then
    local r=view.selected
    local lines={r.name,"Achievement ID: "..r.id,"Category: "..tostring(r.category),
      r.done and ("EARNED"..(r.date and " on "..r.date or "")) or "NOT YET EARNED",
      "Points: "..tostring(r.points),"",r.description,""}
    if type(GetAchievementNumCriteria)=="function" and type(GetAchievementCriteriaInfo)=="function" then
      local n=tonumber(GetAchievementNumCriteria(r.id)) or 0
      if n>0 then
        lines[#lines+1]="OBJECTIVES:"
        for i=1,math.min(n,9) do
          local okCriteria,desc,_,done,quantity,required=pcall(GetAchievementCriteriaInfo,r.id,i)
          if okCriteria and desc then
            lines[#lines+1]=(done and "[Done] " or "[ ] ")..tostring(desc):sub(1,49)..
              (type(quantity)=="number" and type(required)=="number" and required>1 and (" ("..quantity.."/"..required..")") or "")
          end
        end
        if n>9 then lines[#lines+1]="Additional criteria: "..(n-9).." (view in Blizzard's window)" end
      end
    end
    view.detail:SetText(table.concat(lines,"\n"))
  else
    view.detail:SetText("Select an achievement to see completion, description, and criteria.")
  end
end
