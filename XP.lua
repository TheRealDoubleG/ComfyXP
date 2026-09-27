ComfyXP = ComfyXP or {}
local A = ComfyXP

function A:CreateXPBar()
    if self.xpFrame then return end

    local f = CreateFrame("StatusBar", "ComfyXPBar", UIParent, "BackdropTemplate")
    f:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
    })
    f:SetBackdropColor(0.02, 0.02, 0.03, 0.82)
    f:SetStatusBarColor(0.15, 0.45, 0.95, 0.95)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("CENTER")

    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.sub:SetPoint("TOP", f, "BOTTOM", 0, -2)

    f:SetScript("OnDragStart", function(self)
        if not A.db or not A.db.xp or A.db.xp.locked then return end
        A.draggingXPBar = true
        self:StartMoving()
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        A.draggingXPBar = false

        local fx, fy = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if fx and fy and ux and uy then
            A.db.xp.point = "CENTER"
            A.db.xp.relativePoint = "CENTER"
            A.db.xp.x = fx - ux
            A.db.xp.y = fy - uy
        end
        A:RefreshFeature()
    end)

    self.xpFrame = f
end

function A:ApplyXPBarLockState()
    if not self.xpFrame or not self.db or not self.db.xp then return end
    local unlocked = not self.db.xp.locked
    self.xpFrame:EnableMouse(unlocked)
    if unlocked then
        self.xpFrame:SetBackdropBorderColor(1.00, 0.82, 0.00, 0.85)
    else
        self.xpFrame:SetBackdropBorderColor(0.55, 0.45, 0.20, 1)
    end
end

function A:RefreshFeature()
    self:CreateXPBar()

    local f = self.xpFrame
    local c = self.db and self.db.xp
    if not c or not self.db.enabled then
        f:Hide()
        return
    end

    local level = UnitLevel and tonumber(UnitLevel("player")) or 0
    local xp = UnitXP and tonumber(UnitXP("player")) or 0
    local maxXP = UnitXPMax and tonumber(UnitXPMax("player")) or 1
    if not maxXP or maxXP <= 0 then maxXP = 1 end
    local rested = GetXPExhaustion and tonumber(GetXPExhaustion()) or 0

    -- Do not re-anchor the bar while the user is dragging it. The old behavior
    -- refreshed once per second and snapped the frame back underneath the mouse.
    if not self.draggingXPBar then
        f:ClearAllPoints()
        f:SetPoint(
            c.point or "BOTTOM",
            UIParent,
            c.relativePoint or c.point or "BOTTOM",
            tonumber(c.x) or 0,
            tonumber(c.y) or 52
        )
    end

    f:SetSize(tonumber(c.width) or 520, tonumber(c.height) or 18)
    f:SetMinMaxValues(0, maxXP)
    f:SetValue(xp)
    f.text:SetText(string.format("Lv %d  %d / %d  (%.1f%%)", level or 0, xp or 0, maxXP, (xp / maxXP) * 100))

    local sub = {}
    if c.showRested and rested and rested > 0 then
        sub[#sub + 1] = self:T("RESTED") .. ": " .. rested
    end

    local perHour = self.activeSeconds and self.activeSeconds > 5
        and ((self.sessionXP or 0) / self.activeSeconds) * 3600
        or 0

    if c.showSubline then
        sub[#sub + 1] = self:T("SESSION") .. ": " .. tostring(self.sessionXP or 0)
        if perHour > 0 then
            sub[#sub + 1] = self:T("PER_HOUR") .. ": " .. math.floor(perHour + 0.5)
            sub[#sub + 1] = self:T("ETA") .. ": " .. string.format("%.1f h", math.max(0, maxXP - xp) / perHour)
        end
    end

    f.sub:SetText(table.concat(sub, "  |  "))
    self:ApplyXPBarLockState()
    f:Show()
end

function A:OnXPUpdate()
    local xp = UnitXP and tonumber(UnitXP("player")) or 0
    local maxXP = UnitXPMax and tonumber(UnitXPMax("player")) or 1

    if self.lastXP and self.lastXPMax then
        local delta = xp - self.lastXP
        if delta < 0 then delta = (self.lastXPMax - self.lastXP) + xp end
        if delta > 0 then self.sessionXP = (self.sessionXP or 0) + delta end
    end

    self.lastXP = xp
    self.lastXPMax = maxXP
    self:RefreshFeature()
end

function A:InitializeFeature()
    self.sessionXP = 0
    self.activeSeconds = 0
    self.draggingXPBar = false
    self.lastXP = UnitXP and tonumber(UnitXP("player")) or 0
    self.lastXPMax = UnitXPMax and tonumber(UnitXPMax("player")) or 1

    self:CreateXPBar()

    local e = CreateFrame("Frame")
    for _, event in ipairs({"PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "PLAYER_ENTERING_WORLD"}) do
        pcall(e.RegisterEvent, e, event)
    end

    e:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
            A:OnXPUpdate()
        else
            A:RefreshFeature()
        end
    end)

    e:SetScript("OnUpdate", function(self, elapsed)
        self.t = (self.t or 0) + (tonumber(elapsed) or 0)
        if self.t >= 1 then
            local step = self.t
            self.t = 0
            local afk = type(UnitIsAFK) == "function" and UnitIsAFK("player")
            if not afk then A.activeSeconds = (A.activeSeconds or 0) + step end
            A:RefreshFeature()
        end
    end)
end

function A:BuildGeneralOptions(page, ui)
    ui.CreateCheck(page, A:T("LOCK_BAR"), 20, -95,
        function() return A.db.xp.locked end,
        function(v)
            A.db.xp.locked = v
            A:ApplyXPBarLockState()
        end)

    ui.CreateCheck(page, A:T("SHOW_RESTED"), 20, -130,
        function() return A.db.xp.showRested end,
        function(v) A.db.xp.showRested = v end)

    ui.CreateCheck(page, A:T("SHOW_SUBLINE"), 20, -165,
        function() return A.db.xp.showSubline end,
        function(v) A.db.xp.showSubline = v end)

    ui.CreateSlider(page, A:T("WIDTH"), 280, 800, 10, 35, -235,
        function() return A.db.xp.width end,
        function(v) A.db.xp.width = math.floor(v + 0.5) end,
        function(v) return math.floor(v + 0.5) .. " px" end)

    ui.CreateSlider(page, A:T("HEIGHT"), 10, 32, 1, 35, -305,
        function() return A.db.xp.height end,
        function(v) A.db.xp.height = math.floor(v + 0.5) end,
        function(v) return math.floor(v + 0.5) .. " px" end)

    local n = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    n:SetPoint("TOPLEFT", 20, -395)
    n:SetWidth(680)
    n:SetJustifyH("LEFT")
    n:SetText(self:T("FOREVER_NOTE"))
end
