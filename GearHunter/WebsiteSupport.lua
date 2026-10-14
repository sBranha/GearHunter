-- Gear Hunter v0.11.10 website/help shortcut. No in-game donation solicitations.
local addonName, GH = ...
if not GH then return end
if type(GH.supportReleases)=="table" then
    local found=false
    for _,e in ipairs(GH.supportReleases) do if e.version=="0.11.10" then found=true end end
    if not found then
        table.insert(GH.supportReleases,1,{version="0.11.10",title="Website & Support and WoW 12.1.5 compatibility",
          items={"Updated the WoW Retail interface to 120105.","Added a selectable official help, downloads and reporting URL.","No internet access or donation prompt is required inside WoW."},
          how="Click ? > WEBSITE & SUPPORT; click SELECT WEBSITE LINK, press Ctrl+C, then paste into your browser. Or type /ghwebsite."})
    end
end
local url="https://gearhunter.net/addon.php?slug=gear-hunter"
local body=table.concat({"WEBSITE & SUPPORT","","Gear Hunter downloads, setup help, latest releases, bug reports and feature guides are on our official website.","","WEB ADDRESS:",url,"","HOW TO USE","1. Click SELECT WEBSITE LINK below.","2. Press Ctrl+C to copy the address.","3. Open a browser outside World of Warcraft and paste the URL.","","Alternative: type /ghwebsite in chat.","","The addon does not open a browser, make HTTP requests or send bug reports automatically."},"\n")
local oldCreate,oldShow=GH.CreateSupportCenter,GH.ShowSupportPage
if type(oldCreate)=="function" and type(oldShow)=="function" then
    function GH:ShowSupportPage(page)
        oldShow(self,page)
        if self.websiteLinkPanel then self.websiteLinkPanel:SetShown(page=="WEB") end
        if page=="WEB" and self.supportFrame and self.supportBody then
            self.supportHeading:SetText("WEBSITE & SUPPORT")
            self.supportBody:SetText(body)
            self.supportContent:SetHeight(math.max(455,(self.supportBody:GetStringHeight() or 400)+45))
            self.supportScroll:ClearAllPoints()
            self.supportScroll:SetPoint("TOPLEFT",self.supportContentPanel,"TOPLEFT",17,-53)
            self.supportScroll:SetPoint("BOTTOMRIGHT",self.supportContentPanel,"BOTTOMRIGHT",-38,134)
            self.supportScroll:SetVerticalScroll(0)
        end
    end
    function GH:CreateSupportCenter(...)
        oldCreate(self,...)
        if not self.supportFrame or self.websiteButton or not self.supportNavButtons or not self.supportNavButtons[1] then return end
        local sidebar=self.supportNavButtons[1]:GetParent()
        local index=#self.supportNavButtons+1
        local b=CreateFrame("Button",nil,sidebar,"BackdropTemplate")
        b:SetSize(206,45)
        b:SetPoint("TOPLEFT",sidebar,"TOPLEFT",10,-13-(index-1)*56)
        b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        b:SetBackdropColor(.027,.072,.124,1)
        b:SetBackdropBorderColor(.34,.56,.73,1)
        local label=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
        label:SetPoint("LEFT",b,"LEFT",13,0)
        label:SetText("WEBSITE & SUPPORT")
        label:SetTextColor(.94,.95,.99)
        b:SetScript("OnClick",function() GH:ShowSupportPage("WEB") end)
        b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(1,.83,.32,1) end)
        b:SetScript("OnLeave",function(self) if GH.supportPage~="WEB" then self:SetBackdropBorderColor(.34,.56,.73,1) end end)
        b.page="WEB"
        table.insert(self.supportNavButtons,b)
        self.websiteButton=b
        local panel=CreateFrame("Frame",nil,self.supportContentPanel,"BackdropTemplate")
        panel:SetPoint("BOTTOMLEFT",self.supportContentPanel,"BOTTOMLEFT",8,8)
        panel:SetSize(780,118)
        panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        panel:SetBackdropColor(.025,.066,.115,1)
        panel:SetBackdropBorderColor(.44,.63,.77,1)
        local title=panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        title:SetPoint("TOPLEFT",panel,"TOPLEFT",12,-9)
        title:SetText("OFFICIAL GEAR HUNTER WEBSITE")
        local field=CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
        field:SetPoint("TOPLEFT",panel,"TOPLEFT",15,-36)
        field:SetSize(728,28)
        field:SetAutoFocus(false)
        field:SetMaxLetters(200)
        field:SetText(url)
        field:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
        local button=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT",panel,"TOPLEFT",13,-76)
        button:SetSize(197,28)
        button:SetText("SELECT WEBSITE LINK")
        button:SetScript("OnClick",function() field:SetText(url);field:SetFocus();field:HighlightText() end)
        local note=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        note:SetPoint("LEFT",button,"RIGHT",12,0)
        note:SetText("Press Ctrl+C to copy")
        self.websiteLinkPanel=panel
        panel:Hide()
    end
end
