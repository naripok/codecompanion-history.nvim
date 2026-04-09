# Title Generation Integration Plan

## Overview

Integrate codecompanion-history with codecompanion's background title generation system by:
1. Including a patched version of `chat_make_title.lua` in the codecompanion-history repo
2. Adding event firing when titles are generated
3. Listening for the event in codecompanion-history to auto-save with the generated title

## Problem Statement

Currently, codecompanion-history generates simple titles from the first user message. However, codecompanion's core plugin has a background title generation system that creates better titles via LLM. We want to use those generated titles instead.

## Solution Architecture

### Components

1. **Patched `chat_make_title.lua`** (in codecompanion-history repo)
   - Located in `codecompanion/interactions/background/chat_make_title.lua`
   - Patched version of the builtin action
   - Fires `CodeCompanionChatTitleGenerated` event after setting title
   - Allows custom prompt modification

2. **CodeCompanion Configuration**
   - Point to the action from codecompanion-history
   - Load order ensures custom version takes precedence

3. **History Extension**
   - Listen for `CodeCompanionChatTitleGenerated` event
   - Update chat title and re-save automatically
   - Fall back to simple title if background generation fails

### Data Flow

```
Chat Created
    │
    ├─→ History: Generate save_id, set default buffer title
    │
    ├─→ Background: chat_make_title action triggered (async)
    │   ├─→ LLM generates title
    │   ├─→ chat:set_title(title)
    │   └─→ utils.fire("ChatTitleGenerated", { bufnr, title })
    │
    ▼
CodeCompanionChatTitleGenerated event fires
    │
    ├─→ History Extension receives event
    │   ├─→ Get chat from bufnr
    │   ├─→ Update chat.opts.title = title
    │   ├─→ Update buffer title
    │   └─→ Re-save chat with new title
    │
    └─→ Done
```

## Implementation Details

### Step 1: Add Patched `chat_make_title.lua` to Repo

**Location:** `codecompanion/interactions/background/chat_make_title.lua`

**Content:**
```lua
local log = require("codecompanion.utils.log")
local utils = require("codecompanion.utils")

local fmt = string.format

local M = {}

---Format the messages from a chat buffer
---@param messages CodeCompanion.Chat.Messages
function M.format_messages(messages)
  local exclude_tags = {
    ["image"] = "[Image content omitted]",
    ["rules"] = "",
    ["system_prompt_from_config"] = "",
  }

  local chat_messages = {}
  for _, m in ipairs(messages or {}) do
    local tag = m._meta and m._meta.tag
    local replacement = exclude_tags[tag]

    if replacement == "" then
      goto continue
    end

    local content = replacement or m.content
    table.insert(chat_messages, fmt("## %s\n%s", m.role, content))

    ::continue::
  end
  return table.concat(chat_messages, "\n")
end

---Handle the result from the title generation request
---@param result table
---@return string|nil
function M.on_done(result)
  if not result or (result.status and result.status == "error") then
    return
  end

  local title = result and result.output and result.output.content
  if title then
    title = title:match("^%s*[\"']?(.-)[\"']?%s*$")
    return title and title ~= "" and title or nil
  end
end

---Make the request to generate a title for the chat
---@param background CodeCompanion.Background
---@param chat CodeCompanion.Chat
function M.request(background, chat)
  if chat.title and chat.title ~= "" then
    return
  end

  background:ask({
    {
      role = "system",
      content = [[You are an expert in crafting pithy titles for chatbot conversations. You are presented with a chat request, and you reply with a brief title that captures the main topic of that request. Keep your answers short and impersonal.
The title should not be wrapped in quotes or contain any sort of formatting such as Markdown or HTML syntax. It should be about 8 words or fewer.
Here are some examples of good titles:
- Git rebase question
- Installing Python packages
- Location of LinkedList implementation in codebase
- Adding tests to Neovim plugin
- React useState hook usage]],
    },
    {
      role = "user",
      content = fmt([[Please write a brief title for the following request:

%s]], M.format_messages(chat.messages)),
    },
  }, {
    method = "async",
    silent = true,
    on_done = function(result)
      local title = M.on_done(result)
      if title then
        chat:set_title(title)
        -- Fire event for history extension and other listeners
        utils.fire("ChatTitleGenerated", {
          bufnr = chat.bufnr,
          title = title,
          id = chat.id,
        })
        log:debug("[Background] Chat title generated: %s", title)
      end
    end,
    on_error = function(err)
      log:debug("[Background] Chat title generation failed: %s", err)
    end,
  })
end

return M
```

**Key Changes from Builtin:**
1. Added `utils.fire("ChatTitleGenerated", {...})` after `chat:set_title(title)`
2. Included `chat.id` in event data for better tracking
3. Customizable system prompt (can be modified as needed)

### Step 2: Update CodeCompanion Configuration

**File:** User's codecompanion config (e.g., `~/.config/nvim/lua/plugins/codecompanion/interactions/background.lua`)

**Update:**
```lua
return {
  chat = {
    callbacks = {
      ["on_ready"] = {
        actions = {
          "codecompanion._extensions.history.codecompanion.interactions.background.chat_make_title",
        },
        enabled = true,
      },
    },
    opts = {
      enabled = true,
    },
  },
}
```

**Explanation:**
- Points to the patched version in the codecompanion-history extension
- Path: `codecompanion._extensions.history.codecompanion.interactions.background.chat_make_title`
- The `resolve` function in `callbacks.lua` will load it from the extension's module path
- Users need to add this to their codecompanion config to enable the feature

### Step 3: Update History Extension

**File:** `lua/codecompanion/_extensions/history/init.lua`

**Add Event Listener:**

In `_setup_autocommands()`, add:

```lua
vim.api.nvim_create_autocmd("User", {
    pattern = "CodeCompanionChatTitleGenerated",
    group = group,
    callback = vim.schedule_wrap(function(opts)
        log:trace("Chat title generated event received for bufnr: %s", opts.data.bufnr)
        
        local chat_module = require("codecompanion.interactions.chat")
        local chat = chat_module.buf_get_chat(opts.data.bufnr) --[[@as CodeCompanion.History.Chat]]
        
        if not chat then
            return log:trace("No chat found for bufnr: %s", opts.data.bufnr)
        end
        
        local new_title = opts.data.title
        if not new_title or new_title == "" then
            return log:trace("Empty title received, skipping")
        end
        
        -- Check if title actually changed
        if chat.opts.title == new_title then
            return log:trace("Title unchanged, skipping save")
        end
        
        log:trace("Updating chat title from '%s' to '%s'", chat.opts.title or "nil", new_title)
        
        -- Update chat title
        chat.opts.title = new_title
        
        -- Update buffer title
        self.ui:update_chat_title(chat)
        
        -- Re-save chat with new title
        if self.opts.auto_save then
            self.storage:save_chat(chat)
            log:debug("Chat re-saved with new title: %s", new_title)
        end
    end),
})
```

**Keep Existing Fallback:**

The existing `ChatSubmitted` handler should remain as a fallback:
- If background title generation fails or is disabled
- Simple title generation from first message still works

### Step 4: Update Types (Optional)

**File:** `lua/codecompanion/_extensions/history/types.lua`

Add event data type (for documentation):
```lua
---@class CodeCompanion.History.TitleGeneratedEvent
---@field bufnr number Buffer number
---@field title string Generated title
---@field id number Chat ID
```

## Testing Checklist

- [ ] Patched `chat_make_title.lua` loads without errors from extension path
- [ ] Background title generation still works
- [ ] `CodeCompanionChatTitleGenerated` event fires when title is set
- [ ] History extension receives the event
- [ ] Chat title is updated in history extension
- [ ] Chat is re-saved with new title
- [ ] Buffer title displays correctly
- [ ] Fallback to simple title works if background generation fails
- [ ] No errors when title generation is disabled
- [ ] Multiple rapid title changes handled correctly
- [ ] User can enable feature by adding config line

## User Enablement

To enable LLM-based title generation, users need to add this to their codecompanion config:

```lua
-- In codecompanion setup
require("codecompanion").setup({
    interactions = {
        background = {
            chat = {
                callbacks = {
                    ["on_ready"] = {
                        actions = {
                            "codecompanion._extensions.history.codecompanion.interactions.background.chat_make_title",
                        },
                        enabled = true,
                    },
                },
                opts = {
                    enabled = true,
                },
            },
        },
    },
})
```

**Note:** This is optional. Without it, the history extension will use simple title generation from the first user message.

## Edge Cases Handled

1. **Title generation fails:** Falls back to simple title on next submission
2. **Title already set:** No redundant save
3. **Empty title:** Ignored, no update
4. **Chat not found:** Logged and ignored
5. **Multiple title changes:** Each triggers re-save (can be debounced if needed)

## Benefits

✅ **Better titles:** Uses LLM-generated titles instead of simple truncation  
✅ **Event-driven:** Clean separation, no polling or race conditions  
✅ **Customizable:** Can modify title generation prompt in the extension  
✅ **Centralized:** All related code in one repo (codecompanion-history)  
✅ **Immediate:** Title saved as soon as it's generated  
✅ **Fallback:** Simple title generation still works as backup  
✅ **Easy to enable:** Users just need to add one line to their config  

## Migration Notes

- Existing saved chats are unaffected
- New chats will use background-generated titles
- Old chats re-opened and re-saved will keep their existing titles
- No data migration needed

## Future Enhancements

1. **Debounce rapid title changes:** If title changes multiple times quickly, only save the last one
2. **Title change notification:** Notify user when title is updated
3. **Custom title formatting:** Add `format_title` callback option in history extension
4. **Title generation metrics:** Track success/failure rates

## Files Modified

1. **New:** `codecompanion/interactions/background/chat_make_title.lua` (in codecompanion-history repo)
2. **Modified:** `lua/codecompanion/_extensions/history/init.lua` (add event listener)
3. **User Config:** User's codecompanion background config (to enable the feature)

## Rollback Plan

If issues arise:
1. Remove the action from codecompanion config (revert to default)
2. History extension will fall back to simple title generation
3. No data loss, just different title generation method

## Documentation Updates

Update README.md to include:
1. **New section:** "LLM-Based Title Generation" explaining the optional feature
2. **Configuration example:** How to enable it
3. **Benefits:** Better titles vs simple titles
4. **Requirements:** Needs an LLM adapter configured for background tasks
