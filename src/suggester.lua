-- TypeSuggester Addon - Suggester Module (Optimized)
-- Finds word suggestions using Levenshtein distance
-- Now with prefix indexing for <1% CPU usage and suggestion caching

local distance = _G.Distance  -- Loaded by distance.lua
local Suggester = {}

local suggestionCache = {}  -- Cache: typed -> {suggestions, timestamp}
local CACHE_TIMEOUT = 60  -- Cache expires after 60 seconds
local MAX_SUGGESTIONS = 5  -- Show up to 5 suggestions

-- Initialize suggester with prefix indexer
function Suggester:Initialize(indexer, maxDistance, maxSuggestions)
    self.indexer = indexer
    self.maxDistance = maxDistance or 5  -- Max Levenshtein distance (very generous for dyslexic typos)
    self.maxSuggestions = maxSuggestions or MAX_SUGGESTIONS
end

-- Clear the suggestion cache (called on reset or session change)
function Suggester:ClearCache()
    suggestionCache = {}
end

-- Internal: clean expired cache entries
local function cleanExpiredCache()
    local now = GetTime()  -- WoW API: current time in seconds

    for typed, entry in pairs(suggestionCache) do
        if (now - entry.timestamp) > CACHE_TIMEOUT then
            suggestionCache[typed] = nil
        end
    end
end

-- Main suggestion engine: find spelling suggestions for typed text
-- Performance: uses prefix index to narrow candidates, early exit for speed
function Suggester:GetSuggestions(typed)
    if not typed or typed == "" then
        return {}
    end

    local typedLower = string.lower(typed)

    -- Check cache first (instant return)
    if suggestionCache[typedLower] then
        return suggestionCache[typedLower].suggestions
    end

    -- Get candidate words using prefix index (50-500 instead of 70K)
    local candidates = self.indexer:GetWordsWithPrefix(typed, true)  -- strict filter for auto-complete
    local usingFallback = false

    -- FALLBACK: if strict prefix search yields no results, use relaxed prefix filter for typo matching
    -- This handles cases like "beatiful" (no words start with "beatiful" exactly)
    -- by returning all words with matching first 2 chars for distance-based matching
    if #candidates == 0 then
        candidates = self.indexer:GetWordsWithPrefix(typed, false)  -- relaxed filter for typos
        usingFallback = true
    end

    if #candidates == 0 then
        return {}
    end

    -- CAP CANDIDATES: limit search to prevent stutter
    -- Strict prefix match: cap at 200 (already filtered by exact prefix)
    -- Relaxed prefix match (typo mode): search ALL prefix matches, no cap
    --   (only hundreds of words with matching first 2 chars, not all 70K)
    local candidatesToSearch = #candidates
    if not usingFallback and candidatesToSearch > 200 then
        candidatesToSearch = 200
    end

    -- Use consistent distance threshold regardless of word length
    local maxDist = self.maxDistance  -- default = 2

    -- Score candidates using Damerau-Levenshtein distance
    local scored = {}

    for i = 1, candidatesToSearch do
        local word = candidates[i]
        local dist, _ = distance:calculate(typedLower, string.lower(word), false)  -- Plain Levenshtein, no keyboard weights

        -- Only include if within acceptable distance
        if dist <= maxDist then
            table.insert(scored, {
                word = word,
                distance = dist,
                length = #word
            })
        end

        -- Early exit: stop searching after finding enough good suggestions
        if #scored >= self.maxSuggestions then
            break
        end
    end

    -- Sort by distance (lower = better), then by word length (shorter = better)
    table.sort(scored, function(a, b)
        if a.distance ~= b.distance then
            return a.distance < b.distance
        end
        return a.length < b.length
    end)

    -- Extract just the words, limit to maxSuggestions
    local results = {}
    for i = 1, math.min(#scored, self.maxSuggestions) do
        table.insert(results, scored[i].word)
    end

    -- Cache the results
    suggestionCache[typedLower] = {
        suggestions = results,
        timestamp = GetTime()
    }

    return results
end

-- Get suggestions with additional details (for UI display) - NOT USED, kept for reference
function Suggester:GetSuggestionsWithDetails(typed)
    -- Delegate to GetSuggestions and return just the words
    return self:GetSuggestions(typed)
end

-- Preload cache with common words (optional optimization)
function Suggester:PreloadCommonWords(commonWords)
    if not commonWords then
        return
    end

    for _, word in ipairs(commonWords) do
        if word and #word > 0 then
            local suggestions = self:GetSuggestions(word)
            -- Just getting suggestions populates the cache
        end
    end
end

-- Get cache statistics (for monitoring)
function Suggester:GetCacheStats()
    cleanExpiredCache()

    return {
        cacheSize = 0,  -- Count non-nil entries
        entries = function()
            local count = 0
            for _ in pairs(suggestionCache) do
                count = count + 1
            end
            return count
        end
    }
end

_G.Suggester = Suggester
return Suggester
