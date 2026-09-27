ComfyXP = ComfyXP or {}
local A = ComfyXP

local IDLE_DISPLAY_AFTER = 5
local AUTO_AFK_SECONDS = 300
local AFK_LOGOUT_SECONDS = 1800

local function Now()
    if type(GetTimePreciseSec) == "function" then
        local ok, v = pcall(GetTimePreciseSec)
        if ok and tonumber(v) then return tonumber(v) end
    end
    if type(GetTime) == "function" then
        local ok, v = pcall(GetTime)
        if ok and tonumber(v) then return tonumber(v) end
    end
    return 0
end

local function FormatClock(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    if hours > 0 then return string.format("%d:%02d:%02d", hours, minutes, secs) end
    return string.format("%02d:%02d", minutes, secs)
end

local function Compact(value)
    value = tonumber(value) or 0
    local a = math.abs(value)
    if a >= 1000000 then return string.format("%.1fm", value / 1000000) end
    if a >= 1000 then return string.format("%.1fk", value / 1000) end
    return tostring(math.floor(value + 0.5))
end

function A:ResetIdleTimer()
    self.lastActivity = Now()
    self.afkDetectedAt = nil
end

function A:GetIdleSeconds()
    return math.max(0, Now() - (self.lastActivity or Now()))
end

function A:GetAFKText()
    local now = Now()
    local idle = self:GetIdleSeconds()
    local isAFK = type(UnitIsAFK) == "function" and UnitIsAFK("player") and true or false

    if isAFK then
        if not self.afkDetectedAt then
            self.afkDetectedAt = idle >= AUTO_AFK_SECONDS
                and ((self.lastActivity or now) + AUTO_AFK_SECONDS)
                or now
        end
        local afkFor = math.max(0, now - self.afkDetectedAt)
        local logoutIn = math.max(0, AFK_LOGOUT_SECONDS - afkFor)
        return string.format("%s %s | %s ~%s", self:T("AFK"), FormatClock(afkFor), self:T("LOGOUT"), FormatClock(logoutIn))
    end

    self.afkDetectedAt = nil
    if idle < IDLE_DISPLAY_AFTER then return nil end

    local untilAFK = math.max(0, AUTO_AFK_SECONDS - idle)
    local untilLogout = math.max(0, AUTO_AFK_SECONDS + AFK_LOGOUT_SECONDS - idle)
    if untilAFK > 0 then
        return string.format("%s %s | %s %s | %s ~%s",
            self:T("IDLE"), FormatClock(idle), self:T("AFK"), FormatClock(untilAFK), self:T("LOGOUT"), FormatClock(untilLogout))
    end
    return string.format("%s %s | %s ~%s", self:T("IDLE"), FormatClock(idle), self:T("LOGOUT"), FormatClock(untilLogout))
end

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

    f.info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.info:SetJustifyH("CENTER")

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

function A:PositionInfoText()
    local f = self.xpFrame
    local c = self.db and self.db.xp
    if not f or not c then return end

    f.info:ClearAllPoints()
    if c.infoPosition == "above" then
        f.info:SetPoint("BOTTOM", f, "TOP", 0, 3)
    elseif c.infoPosition == "inside" then
        f.info:SetPoint("CENTER", f, "CENTER", 0, 0)
    else
        f.info:SetPoint("TOP", f, "BOTTOM", 0, -3)
    end
end

function A:BuildInfoText(level, xp, maxXP, rested, perHour)
    local c = self.db.xp
    local parts = {}

    if c.showLevel then parts[#parts + 1] = string.format("%s %d", self:T("LEVEL"), level or 0) end
    if c.showXPValues then parts[#parts + 1] = string.format("%s/%s", Compact(xp), Compact(maxXP)) end
    if c.showPercent then parts[#parts + 1] = string.format("%.1f%%", maxXP > 0 and (xp / maxXP) * 100 or 0) end
    if c.showRested and rested and rested > 0 then parts[#parts + 1] = self:T("RESTED") .. " " .. Compact(rested) end
    if c.showSessionXP then parts[#parts + 1] = self:T("SESSION") .. " " .. Compact(self.sessionXP or 0) end
    if c.showXPPerHour and perHour > 0 then parts[#parts + 1] = self:T("PER_HOUR") .. " " .. Compact(perHour) end
    if c.showETA and perHour > 0 then
        parts[#parts + 1] = self:T("ETA") .. " " .. string.format("%.1fh", math.max(0, maxXP - xp) / perHour)
    end
    if c.showAFKTimer then
        local afk = self:GetAFKText()
        if afk then parts[#parts + 1] = afk end
    end

    return table.concat(parts, "  |  ")
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

    local perHour = self.activeSeconds and self.activeSeconds > 5
        and ((self.sessionXP or 0) / self.activeSeconds) * 3600
        or 0

    self:PositionInfoText()
    f.info:SetText(self:BuildInfoText(level, xp, maxXP, rested, perHour))

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
    self.lastActivity = Now()
    self.lastXP = UnitXP and tonumber(UnitXP("player")) or 0
    self.lastXPMax = UnitXPMax and tonumber(UnitXPMax("player")) or 1

    self:CreateXPBar()

    if type(GetCursorPosition) == "function" then
        local x, y = GetCursorPosition()
        self._lastCursorX, self._lastCursorY = x, y
    end

    if WorldFrame and type(WorldFrame.HookScript) == "function" then
        pcall(WorldFrame.HookScript, WorldFrame, "OnMouseDown", function() A:ResetIdleTimer() end)
        pcall(WorldFrame.HookScript, WorldFrame, "OnMouseWheel", function() A:ResetIdleTimer() end)
    end

    local e = CreateFrame("Frame")
    for _, event in ipairs({
        "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "PLAYER_ENTERING_WORLD",
        "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "UNIT_SPELLCAST_SENT", "PLAYER_FLAGS_CHANGED"
    }) do
        pcall(e.RegisterEvent, e, event)
    end

    e:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
            A:OnXPUpdate()
            return
        end
        if event == "PLAYER_STARTED_MOVING" or event == "PLAYER_STOPPED_MOVING" then
            A:ResetIdleTimer()
        elseif event == "UNIT_SPELLCAST_SENT" then
            local unit = ...
            if unit == "player" then A:ResetIdleTimer() end
        end
        A:RefreshFeature()
    end)

    e:SetScript("OnUpdate", function(self, elapsed)
        self.t = (self.t or 0) + (tonumber(elapsed) or 0)
        self.cursorT = (self.cursorT or 0) + (tonumber(elapsed) or 0)

        if self.cursorT >= 0.25 then
            self.cursorT = 0
            if type(GetCursorPosition) == "function" then
                local x, y = GetCursorPosition()
                if A._lastCursorX ~= nil and (math.abs(x - A._lastCursorX) > 1 or math.abs(y - A._lastCursorY) > 1) then
                    A:ResetIdleTimer()
                end
                A._lastCursorX, A._lastCursorY = x, y
            end
        end

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
    ui.CreateCheck(page, A:T("LOCK_BAR"), 20, -90,
        function() return A.db.xp.locked end,
        function(v)
            A.db.xp.locked = v
            A:ApplyXPBarLockState()
        end)

    ui.CreateCheck(page, A:T("SHOW_LEVEL"), 20, -125,
        function() return A.db.xp.showLevel end,
        function(v) A.db.xp.showLevel = v end)
    ui.CreateCheck(page, A:T("SHOW_XP_VALUES"), 20, -160,
        function() return A.db.xp.showXPValues end,
        function(v) A.db.xp.showXPValues = v end)
    ui.CreateCheck(page, A:T("SHOW_PERCENT"), 20, -195,
        function() return A.db.xp.showPercent end,
        function(v) A.db.xp.showPercent = v end)
    ui.CreateCheck(page, A:T("SHOW_RESTED"), 20, -230,
        function() return A.db.xp.showRested end,
        function(v) A.db.xp.showRested = v end)
    ui.CreateCheck(page, A:T("SHOW_SESSION_XP"), 20, -265,
        function() return A.db.xp.showSessionXP end,
        function(v) A.db.xp.showSessionXP = v end)
    ui.CreateCheck(page, A:T("SHOW_XP_PER_HOUR"), 20, -300,
        function() return A.db.xp.showXPPerHour end,
        function(v) A.db.xp.showXPPerHour = v end)
    ui.CreateCheck(page, A:T("SHOW_ETA"), 20, -335,
        function() return A.db.xp.showETA end,
        function(v) A.db.xp.showETA = v end)
    ui.CreateCheck(page, A:T("SHOW_AFK_TIMER"), 20, -370,
        function() return A.db.xp.showAFKTimer end,
        function(v) A.db.xp.showAFKTimer = v end)

    local posLabel = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    posLabel:SetPoint("TOPLEFT", 380, -105)
    posLabel:SetText(self:T("INFO_POSITION"))
    ui.CreateDropdown(page, 365, -117, 190,
        function()
            return {
                {value = "above", text = A:T("POSITION_ABOVE")},
                {value = "inside", text = A:T("POSITION_INSIDE")},
                {value = "below", text = A:T("POSITION_BELOW")},
            }
        end,
        function() return A.db.xp.infoPosition end,
        function(v) A.db.xp.infoPosition = v end)

    ui.CreateSlider(page, A:T("WIDTH"), 280, 800, 10, 375, -220,
        function() return A.db.xp.width end,
        function(v) A.db.xp.width = math.floor(v + 0.5) end,
        function(v) return math.floor(v + 0.5) .. " px" end)

    ui.CreateSlider(page, A:T("HEIGHT"), 10, 32, 1, 375, -300,
        function() return A.db.xp.height end,
        function(v) A.db.xp.height = math.floor(v + 0.5) end,
        function(v) return math.floor(v + 0.5) .. " px" end)

    local n = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    n:SetPoint("TOPLEFT", 380, -390)
    n:SetWidth(310)
    n:SetJustifyH("LEFT")
    n:SetText(self:T("FOREVER_NOTE"))
end
