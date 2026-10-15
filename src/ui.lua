-- Dropdown UI Frame for SpellCheck Addon
-- Displays suggestions in a dropdown similar to Windows 11 autocomplete
-- Handles keyboard navigation and selection

local UI = {}

local frame = nil
local buttons = {}
local selectedIndex = 0
local onSelectCallback = nil

-- Create the dropdown UI frame
-- parent: parent frame (usually chat box)
-- onSelect: callback function(selectedWord) when user selects
function UI:create(parent, onSelect)
    if frame then
        self:destroy()
    end

    onSelectCallback = onSelect
    selectedIndex = 0

    -- Main dropdown container frame
    frame = CreateFrame("Frame", "SpellCheckDropdown", parent, "BackdropTemplate")
    frame:SetSize(200, 100)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)  -- Dark background
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)  -- Gray border

    -- Enable mouse wheel scrolling to navigate suggestions
    frame:EnableMouseWheel(true)
    local UI_self = self
    frame:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            UI_self:navigate("up")
        else
            UI_self:navigate("down")
        end
        return true  -- Consume wheel event so it doesn't zoom/scroll game
    end)

    -- Hide by default
    frame:Hide()

    return frame
end

-- Destroy the dropdown frame
function UI:destroy()
    if frame then
        frame:Hide()
        frame = nil
        buttons = {}
        selectedIndex = 0
    end
end

-- Show suggestions in dropdown
-- suggestions: array of words to display
-- positionX, positionY: where to position dropdown (chat box coordinates)
function UI:show(suggestions, positionX, positionY)
    if not frame then
        return
    end

    -- Clear old buttons
    for _, btn in ipairs(buttons) do
        btn:Hide()
        btn = nil
    end
    buttons = {}
    selectedIndex = 0

    if not suggestions or #suggestions == 0 then
        frame:Hide()
        return
    end

    -- Calculate frame size based on suggestion count
    local itemHeight = 20
    local frameHeight = math.min(#suggestions * itemHeight + 8, 150)
    frame:SetHeight(frameHeight)
    frame:SetWidth(220)

    -- Position relative to chat edit box (bottom-right, aligned with chat input)
    frame:ClearAllPoints()
    local chatBox = ChatFrame1EditBox
    if chatBox then
        -- Position to the right of chat box, bottom-aligned
        frame:SetPoint("BOTTOMLEFT", chatBox, "BOTTOMRIGHT", 5, 0)
    else
        -- Fallback to fixed position if chat box not found
        positionX = positionX or 100
        positionY = positionY or -100
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", positionX, positionY)
    end

    -- Create button for each suggestion
    for i, word in ipairs(suggestions) do
        local btn = self:createSuggestionButton(i, word)
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -(4 + (i-1) * itemHeight))
        table.insert(buttons, btn)
    end

    -- Auto-select first suggestion
    if #buttons > 0 then
        self:selectButton(1)
    end

    frame:Show()
end

-- Create a single suggestion button
function UI:createSuggestionButton(index, word)
    local btn = CreateFrame("Button", "SpellCheckSuggestion" .. index, frame, "BackdropTemplate")
    btn:SetSize(210, 18)
    btn:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background"
    })
    btn:SetBackdropColor(0.15, 0.15, 0.15, 0)  -- Transparent background

    -- Text label
    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts/FRIZQT__.TTF", 12)
    text:SetTextColor(0.8, 0.8, 0.8, 1)  -- Light gray text
    text:SetPoint("LEFT", btn, "LEFT", 4, 0)
    text:SetText(word)
    text:SetJustifyH("LEFT")
    btn.text = text
    btn.word = word

    -- Mouse hover effect
    btn:SetScript("OnEnter", function()
        self:selectButton(index)
    end)

    -- Click to select
    btn:SetScript("OnClick", function()
        self:selectSuggestion(word)
    end)

    return btn
end

-- Select a button by index (highlight it)
function UI:selectButton(index)
    -- Unhighlight previous
    if selectedIndex > 0 and buttons[selectedIndex] then
        buttons[selectedIndex]:SetBackdropColor(0.15, 0.15, 0.15, 0)
    end

    -- Highlight new
    if buttons[index] then
        buttons[index]:SetBackdropColor(0.3, 0.5, 1, 0.3)  -- Light blue highlight
        selectedIndex = index
    end
end

-- Navigate suggestions with arrow keys
-- direction: "up" or "down"
function UI:navigate(direction)
    if #buttons == 0 then return end

    local newIndex = selectedIndex

    if direction == "down" then
        newIndex = selectedIndex + 1
        if newIndex > #buttons then newIndex = 1 end
    elseif direction == "up" then
        newIndex = selectedIndex - 1
        if newIndex < 1 then newIndex = #buttons end
    end

    self:selectButton(newIndex)
end

-- Select current highlighted suggestion
function UI:selectCurrent()
    if selectedIndex > 0 and buttons[selectedIndex] then
        self:selectSuggestion(buttons[selectedIndex].word)
    end
end

-- Handle suggestion selection
function UI:selectSuggestion(word)
    if onSelectCallback then
        onSelectCallback(word)
    end
    self:hide()
end

-- Hide the dropdown
function UI:hide()
    if frame then
        frame:Hide()
    end
end

-- Check if dropdown is visible
function UI:isVisible()
    return frame and frame:IsVisible()
end

-- Set position relative to chat box
function UI:setPosition(x, y)
    if frame then
        frame:SetPoint("TOPLEFT", x, y)
    end
end

_G.UI = UI
return UI
