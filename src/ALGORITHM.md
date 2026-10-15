# SpellCheck Addon - Smart Autocomplete Algorithm

## Overview

This rewritten addon implements intelligent autocomplete inspired by PredictEd and FluentTyper, using three key technologies:
1. **Damerau-Levenshtein Distance** - Typo detection with transposition handling
2. **Keyboard Proximity Weighting** - Context-aware substitution costs
3. **Frequency-Based Ranking** - Common words ranked first, plus user learning

## Architecture

### 1. Dictionary Module: `dictionary-scowl.lua`

**Source**: SCOWL (English Speller Database)
**Size**: 800+ words (from common English corpus)
**Format**: Lua table ordered by frequency

```lua
local DictionarySCOWL = {
    "the",      -- rank 1 (most common)
    "and",      -- rank 2
    "to",       -- rank 3
    ...
}
```

**Key Property**: Position in array = frequency rank
- Lower index = more common word = preferred in suggestions
- Enables simple, efficient frequency-based scoring

### 2. Distance Module: `distance.lua`

#### Damerau-Levenshtein Distance

Extends standard Levenshtein (edit distance) with **transposition** handling:

```
"teh" -> "the" = distance 1 (transposition: 'e' and 'h' swap)
```

Standard Levenshtein would count this as 2 edits (deletion + insertion).
Damerau-Levenshtein recognizes it as 1 transposition.

**Edit Operations**:
- Deletion: remove a character
- Insertion: add a character  
- Substitution: replace a character
- **Transposition: swap adjacent characters** (NEW)

**Algorithm**: Dynamic programming matrix with transposition check:

```lua
-- Standard costs
matrix[i][j] = min(
    matrix[i-1][j] + 1,      -- deletion
    matrix[i][j-1] + 1,      -- insertion
    matrix[i-1][j-1] + cost  -- substitution
)

-- NEW: Transposition check for "teh" -> "the"
if i > 1 and j > 1 and 
   word1[i] == word2[j-1] and 
   word1[i-1] == word2[j] then
    matrix[i][j] = min(matrix[i][j], matrix[i-2][j-2] + cost)
end
```

#### Keyboard Proximity Weighting

Standard Levenshtein treats all substitutions equally:
- Typing 'o' instead of 'i' = typing 'o' instead of 'q'

Reality: adjacent keys on QWERTY are easily confused.

**Solution**: QWERTY proximity map with variable costs:

```lua
KEYBOARD_PROXIMITY = {
    q = { w = 1, a = 1, s = 1, e = 1.5 },  -- adjacent = cost 1
    w = { q = 1, e = 1, ... },
    ...
}

-- If substituting 'e' -> 'w' (adjacent on keyboard)
-- cost = 1 (instead of 1)

-- If substituting 'e' -> 'a' (not adjacent)
-- cost = 2 (or not in proximity map)
```

**Cost Tiers**:
- Same character: 0.1 (no cost, essentially free)
- Adjacent keys (QWERTY): 1.0
- Diagonal keys: 1.5
- Non-adjacent: 2.0

**Effect**: "teh" matches "the" better than "see"
- t-e: same, cost 0
- e-h: adjacent on keyboard, cost 1
- h-e: adjacent, cost 1
- Total: 2 (keyboard-aware)

vs standard Levenshtein (all substitutions = 1):
- Total: 2 (same distance, but our algorithm tracks proximity)

#### Proximity Score Bonus

Beyond distance, we calculate a bonus for how well keyboard positions align:

```lua
proximityScore = sum of (10 - keyboardDistance * 5) for each character pair
```

This creates a secondary ranking factor: words with better keyboard alignment score higher.

### 3. Suggester Module: `suggester.lua`

#### Smart Scoring Algorithm

For each dictionary word vs typed text, calculate:

**Score = Base(matchType) - penalties + bonuses**

```
Score = (Match Priority) 
        - (Typo/Proximity Penalties)
        + (Frequency Bonus)
        + (Keyboard Proximity Bonus)
        + (User Learning Bonus)
```

#### Match Type Priority (Descending)

1. **Exact Match** (score 1000+)
   - "hello" == "hello" → accepted

2. **Prefix Match** (score 500-600)
   - "hel" matches "hello", "help", "hello" → autocomplete
   - Ranked by: dictionary frequency + user frequency
   - Penalty: -(length_diff * 5) so shorter words rank slightly higher
   
3. **Typo/Correction** (score 200-300)
   - "teh" -> "the" (transposition)
   - "wrld" -> "world" (deletion)
   - "recieve" -> "receive" (substitution)
   - Threshold: 2 edits for short words (<5 chars), 3 for longer
   - Ranked by: distance + keyboard proximity + user frequency

4. **Fuzzy Match** (score 100-150, fallback)
   - "hlo" appears in "hello"
   - Very low priority
   - Only used if no prefix/typo matches

#### Scoring Details

**Prefix Match Example**:
```lua
Input: "hel"
Dictionary: ["the", "hello", "helpful", "help"]

Scores:
"hello":    500 - (5-3)*5 + freq_bonus(2) + user(0) = 497
"help":     500 - (4-3)*5 + freq_bonus(3) + user(5) = 508  ← WINNER
"helpful":  500 - (7-3)*5 + freq_bonus(4) + user(0) = 480
"the":      0 (no prefix match)

Result: ["help", "hello", "helpful"]
```

**Typo Match Example**:
```lua
Input: "teh"  (common typo for "the")
Dictionary: ["the", "them", "then", "these"]

Distances (Damerau-Levenshtein):
"the":   1 (transposition)     → score 300 - 20 + kb_bonus + user = ~280+
"them":  2 (1 transposition + 1 sub)  → score 300 - 40 + kb_bonus = ~260+
"then":  2 (1 transposition + 1 sub)  → score 300 - 40 + kb_bonus = ~260+
"these": 3 (exceeds threshold)        → no match

Result: ["the", "them", "then"]
```

### 4. Learning System: `core.lua`

#### User Frequency Tracking

**SavedVariables stores**:
```lua
SpellCheckDB = {
    userFrequency = {
        ["hello"] = 15,     -- typed "hello" 15 times
        ["world"] = 8,
        ["wow"] = 42,       -- used frequently in WoW
    },
    correctionHistory = {
        ["teh"] = { ["the"] = 5 },      -- typed "teh", corrected to "the" 5 times
        ["wrld"] = { ["world"] = 3 },   -- typed "wrld", accepted "world" 3 times
    }
}
```

#### Learning in Action

When scoring suggestions, personal frequency is weighted heavily:

```lua
score = base_score 
    + (userFrequency[word] * 50)  -- User's personal words: huge boost
    - (distance * 20)              -- Closer typos rank higher
    + (keyboardProximity * 2)
```

**Effect**:
- First time user types "hello": ranked normally
- After typing "hello" 5 times: ranked much higher in future
- If user frequently corrects "teh" -> "the": learns this pattern
- Next time user types "teh": "the" is top suggestion

#### Learning Persistence

Learning data survives addon reloads via SavedVariables:
- Per-character per-realm storage (WoW's built-in player-specific save)
- Automatic sync when addon unloads
- Never lost unless explicitly cleared with `/spellcheck learning reset`

## Improvements Over Previous Version

### Before (Levenshtein Only)
- "youre" -> "you're" (edit distance 1)
- "teh" vs "the" treated as 2 edits (delete 'e', insert 'h' → 'he')
- No keyboard context: 'e' → 'w' = 'e' → 'a'
- No learning: every session starts fresh
- Small hardcoded dictionary (2K words)

### After (Damerau-Levenshtein + Proximity + Learning + SCOWL)
- "teh" → "the" correctly identified as 1 transposition
- "youre" → "you're" gets keyboard proximity bonus if keys are close
- Keyboard-aware: adjacent key substitutions have lower cost
- Learns user patterns: "wow" becomes #1 suggestion after frequent use
- 800+ frequency-ranked words (planned for 70K+)
- Handles real typing patterns: double letters, common finger slips

## Performance Characteristics

- **Complexity**: O(n*m*k) where n=typed length, m=dictionary word length, k=dictionary size
- **Optimization**: Early exit for exact matches, prefix-only scanning when possible
- **Memory**: Dictionary cached in memory, learning data grows with user vocabulary

## Debug Output

Enable with `/spellcheck status`:
```
SpellCheck Status:
  Dictionary: 800 words
  User Known Words: 42
  Total Words Typed: 1543
  Total Corrections: 87
```

## Future Enhancements

1. **Expand to 70K+ words** from full SCOWL database
2. **Context awareness**: track WoW-specific terms per class/specialization
3. **Spell-checking mode**: show suggestions for misspelled words in chat
4. **Machine learning**: build n-gram models of user typing patterns
5. **Multilingual support**: add other language dictionaries
