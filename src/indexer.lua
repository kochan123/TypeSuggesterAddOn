-- SpellCheck Addon - Prefix Indexer Module
-- Builds and maintains a prefix-based index for fast word lookups
-- Reduces search space from 70K words to 100-500 per query

local PrefixIndex = {}
local prefixMap = {}  -- Map: first 2 chars -> array of words
local fullDictionary = {}  -- Fallback: complete word list

-- Initialize the prefix index from a word dictionary
-- Expected: dictionary as array of words
function PrefixIndex:Initialize(dictionary)
    if not dictionary or #dictionary == 0 then
        return false
    end

    fullDictionary = dictionary
    prefixMap = {}

    -- Build prefix index: group words by first 2 characters
    for _, word in ipairs(dictionary) do
        if word and #word > 0 then
            -- Get prefix (first 2 chars, or full word if shorter)
            local prefix = string.lower(string.sub(word, 1, 2))

            if not prefixMap[prefix] then
                prefixMap[prefix] = {}
            end

            table.insert(prefixMap[prefix], word)
        end
    end

    return true
end

-- Get all words starting with the given prefix
-- Returns: array of matching words (typically 50-500 words instead of 70K)
function PrefixIndex:GetWordsWithPrefix(typed)
    if not typed or typed == "" then
        return fullDictionary or {}
    end

    typed = string.lower(typed)

    if #typed < 1 then
        return fullDictionary or {}
    end

    -- Get the first 2 characters as the index key
    local indexPrefix = string.sub(typed, 1, 2)
    local candidates = prefixMap[indexPrefix] or {}

    -- Further filter: words must start with the full typed prefix
    local results = {}
    for _, word in ipairs(candidates) do
        local wordLower = string.lower(word)
        if string.sub(wordLower, 1, #typed) == typed then
            table.insert(results, word)
        end
    end

    return results
end

-- Fallback: get all words (for empty input)
function PrefixIndex:GetAllWords()
    return fullDictionary or {}
end

-- Get dictionary statistics (for debugging/monitoring)
function PrefixIndex:GetStats()
    local totalWords = #fullDictionary
    local prefixCount = 0
    local avgWordsPerPrefix = 0

    for _ in pairs(prefixMap) do
        prefixCount = prefixCount + 1
    end

    if prefixCount > 0 then
        avgWordsPerPrefix = math.floor(totalWords / prefixCount)
    end

    return {
        totalWords = totalWords,
        prefixCount = prefixCount,
        avgWordsPerPrefix = avgWordsPerPrefix
    }
end

_G.PrefixIndex = PrefixIndex
return PrefixIndex
