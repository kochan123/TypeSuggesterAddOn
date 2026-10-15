-- Event Handlers for TypeSuggester Addon
-- Hooks into chat input and displays suggestions
-- Click to select, ESC to close

local Events = {}

local Suggester, UI = nil, nil
local lastText = ""

-- Initialize event handlers
function Events:init(suggester, ui)
    Suggester = suggester
    UI = ui
end

-- Create event frame and register handlers
function Events:setupHooks()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "ADDON_LOADED" then
            self:onAddonLoaded(...)
        elseif event == "PLAYER_ENTERING_WORLD" then
            self:onPlayerEnteringWorld()
        end
    end)

    -- Setup chat edit box hooks on a delay
    self:hookChatEditBox()
end

-- Hook into the chat edit box for typing detection
function Events:hookChatEditBox()
    if not ChatFrame1EditBox then
        -- Retry if chat frame not ready yet
        local Events_self = self
        C_Timer.After(0.5, function() Events_self:hookChatEditBox() end)
        return
    end

    local editBox = ChatFrame1EditBox
    local Events_self = self  -- Capture self for use in closures

    -- Original OnKeyDown handler
    local origKeyDown = editBox:GetScript("OnKeyDown")

    editBox:SetScript("OnKeyDown", function(_, key)
        -- Only handle ESC to close dropdown
        if UI:isVisible() and key == "ESCAPE" then
            UI:hide()
            return
        end

        -- Pass all other keys to original handler
        if origKeyDown then
            origKeyDown(editBox, key)
        end
    end)

    -- Original OnTextChanged handler
    local origTextChanged = editBox:GetScript("OnTextChanged")

    editBox:SetScript("OnTextChanged", function()
        -- Call original handler first
        if origTextChanged then
            origTextChanged(editBox)
        end

        -- Detect typing and show suggestions
        Events_self:onChatTextChanged(editBox)
    end)
end

-- Called when chat text changes
function Events:onChatTextChanged(editBox)
    local text = editBox:GetText()

    if text ~= lastText then
        lastText = text
        self:checkSuggestions(editBox, text)
    end
end

-- Check and display suggestions
function Events:checkSuggestions(editBox, text)
    if not editBox then return end

    local words = self:splitWords(text)
    if not words or #words == 0 then
        UI:hide()
        return
    end

    local lastWord = words[#words]
    if string.len(lastWord) < 2 then
        UI:hide()
        return
    end

    local suggestions = Suggester:GetSuggestions(lastWord)

    if #suggestions > 0 then
        local x, y = editBox:GetLeft(), editBox:GetBottom()
        if x and y then
            UI:show(suggestions, x, y - 5)
        end
    else
        UI:hide()
    end
end

-- Split text into words
-- Returns array of words, using space as delimiter
function Events:splitWords(text)
    if not text or text == "" then
        return {}
    end

    local words = {}
    for word in string.gmatch(text, "%S+") do
        table.insert(words, word)
    end

    return words
end

-- Called when addon loads
function Events:onAddonLoaded(addon)
    if addon == "TypeSuggester" then
        -- Addon initialized
    end
end

-- Called when player enters world
function Events:onPlayerEnteringWorld()
    -- Setup is complete
end

_G.Events = Events
return Events
