-- TypeSuggester Addon - Core Module (Optimized)
-- Manages addon initialization and coordinates indexer + suggester + UI

local TypeSuggesterCore = {}
local isInitialized = false

-- Module references (loaded by other files, accessed via _G)
local Distance
local DictionarySCOWL
local PrefixIndex
local Suggester
local UI
local Events

-- CRITICAL: Initialize on ADDON_LOADED event (WoW Forever pattern)
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" and addon == "TypeSuggester" then
        -- Get modules from globals (now that all files have loaded)
        Distance = _G.Distance
        DictionarySCOWL = _G.DictionarySCOWL
        PrefixIndex = _G.PrefixIndex
        Suggester = _G.Suggester
        UI = _G.UI
        Events = _G.Events

        -- Call Initialize
        TypeSuggesterCore:Initialize()
    end
end)

-- Initialize the addon (called when ADDON_LOADED fires)
function TypeSuggesterCore:Initialize()
    if isInitialized then
        return
    end

    -- Verify all modules loaded
    if not DictionarySCOWL or not PrefixIndex or not Suggester or not UI or not Events then
        return false
    end

    -- Step 1: Build prefix index from 70K SCOWL dictionary
    local indexInitOk = PrefixIndex:Initialize(DictionarySCOWL)
    if not indexInitOk then
        return false
    end

    -- Step 2: Initialize suggester with indexer
    -- maxDistance = 4 (generous for typos: plain Levenshtein, no keyboard weights)
    -- maxSuggestions = 5 (show up to 5 suggestions)
    Suggester:Initialize(PrefixIndex, 4, 5)

    -- Step 3: Create UI frame with selection callback
    local onSelectCallback = function(word)
        local editBox = ChatFrame1EditBox
        if editBox then
            -- Get current text and split into words
            local text = editBox:GetText()
            local words = {}
            for w in string.gmatch(text, "%S+") do
                table.insert(words, w)
            end

            if #words > 0 then
                -- Remove last word and replace with suggestion
                words[#words] = word
                local newText = table.concat(words, " ")
                editBox:SetText(newText)
            else
                editBox:Insert(word)
            end

            -- CRITICAL: Blur editbox so RETURN doesn't send, then refocus
            editBox:ClearFocus()
            C_Timer.After(0, function() editBox:SetFocus() end)
        end
    end
    UI:create(UIParent, onSelectCallback)

    -- Step 4: Initialize and setup event handlers
    Events:init(Suggester, UI)
    Events:setupHooks()

    isInitialized = true
    return true
end

-- Get suggestions for typed text
-- This is called on every keystroke
function TypeSuggesterCore:GetSuggestions(typed)
    if not isInitialized then
        return {}
    end

    return Suggester:GetSuggestions(typed)
end

-- Get suggestions with details (for UI rendering)
function TypeSuggesterCore:GetSuggestionsWithDetails(typed)
    if not isInitialized then
        return {}
    end

    return Suggester:GetSuggestionsWithDetails(typed)
end

-- Clear suggestion cache (called on user-initiated reset or new session)
function TypeSuggesterCore:ClearCache()
    Suggester:ClearCache()
end

-- Reset addon state (called on logout or session end)
function TypeSuggesterCore:Reset()
    isInitialized = false
    Suggester:ClearCache()
    UI:Hide()
end

-- Get performance metrics (for monitoring/debugging)
function TypeSuggesterCore:GetPerformanceMetrics()
    return {
        isInitialized = isInitialized,
        indexStats = PrefixIndex:GetStats(),
        cacheStats = Suggester:GetCacheStats(),
        performanceMetrics = performanceMetrics
    }
end

-- Monitor performance and log if CPU spikes
-- Call this periodically (e.g., every 5 seconds) to track performance
function TypeSuggesterCore:MonitorPerformance()
    local now = GetTime()

    if (now - lastPerformanceCheck) < 5 then
        return  -- Only check every 5 seconds
    end

    lastPerformanceCheck = now

    -- In a real implementation, you'd track:
    -- - Keystrokes per second
    -- - Average CPU per keystroke (via profiling)
    -- - Cache hit rate

    -- For now, just check cache stats
    local cacheStats = Suggester:GetCacheStats()
    if cacheStats then
        -- Calculate cache effectiveness
        -- (In practice, you'd track hits vs misses)
    end
end

return TypeSuggesterCore
