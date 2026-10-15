# Development Guide

## Architecture

```
src/
├── TypeSuggester.toc  (manifest)
├── core.lua          (init & coordination)
├── events.lua        (chat input)
├── ui.lua           (dropdown UI)
├── suggester.lua    (suggestion engine)
├── indexer.lua      (prefix indexing)
├── distance.lua     (Levenshtein distance)
└── dictionary-scowl.lua (70K words)
```

## Key Systems

### Distance Calculation
- Plain Levenshtein (cost=1 per mismatch)
- Max distance: 4 (generous for typos)
- No keyboard weights

### Prefix Indexing
- Groups 70K words by first 2 chars (~130/group)
- Strict: exact prefix match (auto-complete)
- Relaxed: all first-2-char matches (typos)
- O(1) lookup time

### Performance
- <1% CPU:
  - Prefix indexing (narrow candidate set)
  - Early exit (stop at 5 suggestions)
  - 60-second cache
  - Lazy evaluation

## Build & Release

### For version 1.0.1:

1. Edit files in `src/`
2. Update `src/TypeSuggester.toc`:
   ```
   ## Version: 1.0.1
   ```
3. Update `docs/CHANGELOG.md`
4. Zip `src/` → `releases/TypeSuggester-1.0.1.zip`
5. Upload to CurseForge
6. Update `VERSION.txt`

## Testing

- [ ] No errors on load
- [ ] Suggestions after 2+ chars
- [ ] Wheel scrolls through suggestions
- [ ] Click inserts word
- [ ] ESC closes dropdown
- [ ] Multi-word chat works
- [ ] FPS stable

## Future Work

- SavedVariables (learning)
- Multiple chat frames
- Settings panel
- Keyboard selection
- Slash commands
- User dictionary
