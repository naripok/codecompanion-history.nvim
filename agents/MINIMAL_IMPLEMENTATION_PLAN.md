# codecompanion-history: Minimal Implementation Plan

## ✅ Implementation Complete

The simplification has been successfully implemented. The plugin now provides only core functionality:
1. ✅ Auto-save conversations with simple titles (from first user message)
2. ✅ Picker to browse and select saved conversations
3. ✅ Open selected conversations from history

## Additional Simplification: Removed LLM Title Generation

The plugin no longer uses LLM-based title generation. Instead:
- Titles are generated from the first user message (truncated to 50 characters)
- No API calls are made for title generation
- Faster and more reliable title display

## Changes Made

### Files Removed
- ✅ `summary_generator.lua` - Summary generation functionality
- ✅ `vectorcode.lua` - VectorCode memory integration
- ✅ `title_generator.lua` - LLM-based title generation

### Files Simplified
- ✅ `types.lua` - Removed summary, memory, and title generation types
- ✅ `storage.lua` - Removed summary storage, chat duplication, renaming, expiration, and last chat retrieval
- ✅ `ui.lua` - Removed summary browsing, chat renaming, duplication, and title_generator dependency
- ✅ `init.lua` - Removed summary commands, vectorcode setup, title generation, continue_last_chat, and delete_on_clearing_chat

### Tests Updated
- ✅ Removed `test_summary.lua`
- ✅ Simplified `test_storage.lua` - Removed duplicate and summary tests
- ✅ Simplified `test_title_generator.lua` - Removed refresh tests
- ✅ Updated `test_providers.lua` - Removed summary config reference

## Core Features Retained

### 1. Chat Saving
- Auto-save on chat submission
- Manual save option via keymap
- Stores: messages, settings, adapter, title, save_id, timestamp, context_items

### 2. Title Generation
- Simple title from first user message (truncated to 50 characters)
- No LLM API calls
- Falls back to "Untitled Chat" if no user message found
- Stores title in chat metadata

### 3. History Picker
- Browse saved chats by title
- Filter/search functionality (provided by picker)
- Preview chat content
- Select to open chat
- Delete chats (with confirmation)

### 4. Chat Loading
- Restore full conversation with messages
- Restore adapter and settings
- Handle missing adapters gracefully
- Restore context items

## Minimal Configuration

```lua
{
  -- Keymap to open history picker from chat buffer
  keymap = "gh",
  
  -- Description for which-key integration
  keymap_description = "Browse saved chats",
  
  -- Automatically save chats on each message
  auto_save = true,
  
  -- Picker to use: "telescope", "fzf-lua", "snacks", or "default"
  picker = "default",
  
  -- Directory to save chats
  dir_to_save = vim.fn.stdpath("data") .. "/codecompanion-history",
  
  -- Enable debug logging
  enable_logging = false,
  
  -- Optional: filter chats when browsing
  chat_filter = nil,
}
```

## Backward Compatibility

### Migration Strategy
1. **Existing chats**: Keep reading old format, write new simplified format
2. **Summary files**: Left untouched (or can be manually deleted)
3. **Index format**: Supports both old and new index formats during read
4. **Gradual migration**: Old chats automatically updated to new format on next save

### Fields Preserved for Compatibility
- `context_items` / `refs` (supports both)
- `title_refresh_count` (read but don't use)
- Old chat format with all fields

## File Size Reduction

- **Files removed**: 4 (`summary_generator.lua`, `vectorcode.lua`, `title_generator.lua`, `test_summary.lua`, `test_title_generator.lua`)
- **Files significantly reduced**: 4 (`init.lua`, `storage.lua`, `ui.lua`, `types.lua`)
- **Total lines after simplification**: ~1954 (core) + ~1051 (tests) = ~3005
- **Target reduction**: ~55-60% of original codebase

## Testing Checklist

- [x] Code compiles without errors
- [x] Auto-save works on chat submission
- [x] Simple title generation from first user message
- [x] History picker shows all saved chats
- [x] Can select and open saved chat
- [x] Chat restores with all messages
- [x] Can delete chats from picker
- [x] Existing chats load correctly (backward compatibility)
- [x] Missing adapters handled gracefully
- [x] No errors from removed features
- [x] Configuration options work correctly

## Implementation Phases Completed

1. ✅ **Phase 1**: Simplified types (`types.lua`)
2. ✅ **Phase 2**: Removed summary generator (`summary_generator.lua`)
3. ✅ **Phase 3**: Removed vectorcode (`vectorcode.lua`)
4. ✅ **Phase 4**: Simplified storage (`storage.lua`)
5. ✅ **Phase 5**: Removed title generator (`title_generator.lua`)
6. ✅ **Phase 6**: Simplified UI (`ui.lua`)
7. ✅ **Phase 7**: Simplified main init (`init.lua`)
8. ✅ **Phase 8**: Updated picker initialization (no changes needed)
9. ✅ **Phase 9**: Updated tests
10. ✅ **Phase 10**: Documentation update

## Next Steps for Users

1. **Existing users**: Your existing chats and summaries will remain intact
2. **Summary files**: Can be manually deleted if no longer needed
3. **VectorCode**: If you were using the memory tool, you'll need an alternative solution
4. **Configuration**: Update your config to remove deprecated options:
   - `summary.*`
   - `memory.*`
   - `title_generation_opts.*` (no longer used - titles are auto-generated from first message)
   - `auto_generate_title` (no longer used)
   - `continue_last_chat`
   - `delete_on_clearing_chat`
   - `expiration_days`
   - `picker_keymaps.rename`
   - `picker_keymaps.duplicate`
