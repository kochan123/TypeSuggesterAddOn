-- Levenshtein Distance Algorithm for spell-checking
-- Calculates the minimum edits (insertions, deletions, substitutions) needed to match words
-- Used to detect typos like "youre" -> "you're"

local Distance = {}

-- Calculate Levenshtein distance between two strings
-- Returns distance as number (0 = exact match, higher = more different)
function Distance:calculate(word1, word2)
    if not word1 or not word2 then
        return math.huge
    end

    word1 = string.lower(word1)
    word2 = string.lower(word2)

    local len1 = string.len(word1)
    local len2 = string.len(word2)

    -- Early exit for obvious cases
    if len1 == 0 then return len2 end
    if len2 == 0 then return len1 end

    -- Create matrix for dynamic programming
    local matrix = {}
    for i = 0, len1 do
        matrix[i] = {}
        matrix[i][0] = i
    end

    for j = 0, len2 do
        matrix[0][j] = j
    end

    -- Fill matrix
    for i = 1, len1 do
        for j = 1, len2 do
            local cost = (string.sub(word1, i, i) == string.sub(word2, j, j)) and 0 or 1

            matrix[i][j] = math.min(
                matrix[i-1][j] + 1,      -- deletion
                matrix[i][j-1] + 1,      -- insertion
                matrix[i-1][j-1] + cost  -- substitution
            )
        end
    end

    return matrix[len1][len2]
end

-- Check if word is likely a typo of target (within threshold)
-- threshold: max distance to consider as typo (default 2)
function Distance:isTypo(typed, target, threshold)
    threshold = threshold or 2
    return self:calculate(typed, target) <= threshold
end

-- Get similarity score (0 to 1, where 1 is identical)
-- Useful for ranking suggestions
function Distance:similarity(word1, word2)
    local distance = self:calculate(word1, word2)
    local maxLen = math.max(string.len(word1 or ""), string.len(word2 or ""))

    if maxLen == 0 then return 1 end
    return 1 - (distance / maxLen)
end

_G.Distance = Distance
return Distance
