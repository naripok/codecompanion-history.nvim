# CodeCompanion History Extension

[![Neovim](https://img.shields.io/badge/Neovim-57A143?style=flat-square&logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-2C2D72?style=flat-square&logo=lua&logoColor=white)](https://www.lua.org)
[![Tests](https://github.com/ravitemer/codecompanion-history.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/ravitemer/codecompanion-history.nvim/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](./CONTRIBUTING.md)

A lightweight history management extension for [codecompanion.nvim](https://codecompanion.olimorris.dev/) that enables saving, browsing and restoring chat sessions.

## ✨ Features

- 💾 **Automatic chat saving**: Chats are automatically saved on each message
- 🎯 **Smart title generation**: Choose between simple titles (from first message) or LLM-generated titles (optional)
- 📚 **Browse saved chats**: Multiple picker interfaces (telescope, snacks, fzf-lua, default)
- ⚡ **Restore chats**: Full restoration of messages, context, tools, and settings
- 🔍 **Project-aware filtering**: Filter chats by workspace/project context
- 🗑️ **Delete chats**: Remove old chats from history

The following CodeCompanion features are preserved when saving and restoring chats:

| Feature | Status | Notes |
|---------|--------|-------|
| System Prompts | ✅ | System prompt used in the chat |
| Messages History | ✅ | All messages |
| Images | ✅ | Restores images as base64 strings |
| LLM Adapter | ✅ | The specific adapter used for the chat |
| LLM Settings | ✅ | Model, temperature and other adapter settings |
| Tools | ✅ | Tool schemas and their system prompts |
| Tool Outputs | ✅ | Tool execution results |
| Variables | ✅ | Variables used in the chat |
| References | ✅ | Code snippets and command outputs added via slash commands |
| Pinned References | ✅ | Pinned references |
| Watchers | ⚠ | Saved but requires original buffer context to resume watching |

When restoring a chat:
1. The complete message history is recreated
2. All tools and references are reinitialized
3. Original LLM settings and adapter are restored
4. Previous system prompts are preserved

> **Note**: While watched buffer states are saved, they require the original buffer context to resume watching functionality.

> [!NOTE]
> As this is an extension that deeply integrates with CodeCompanion's internal APIs, occasional compatibility issues may arise when CodeCompanion updates. If you encounter any bugs or unexpected behavior, please [raise an issue](https://github.com/ravitemer/codecompanion-history.nvim/issues) to help us maintain compatibility.

## 📋 Requirements

- Neovim >= 0.8.0
- [codecompanion.nvim](https://codecompanion.olimorris.dev/)
- [snacks.nvim](https://github.com/folke/snacks.nvim) (optional, for enhanced picker)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional, for enhanced picker)
- [fzf-lua](https://github.com/ibhagwan/fzf-lua) (optional, for enhanced picker)

## 📦 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

### First install the plugin

```lua
{
    "olimorris/codecompanion.nvim",
    dependencies = {
        --other plugins
        "ravitemer/codecompanion-history.nvim"
    }
}
```

### Add history extension to CodeCompanion config

```lua
require("codecompanion").setup({
    extensions = {
        history = {
            enabled = true,
            opts = {
                -- Keymap to open history from chat buffer (default: gh)
                keymap = "gh",
                -- Keymap to save the current chat manually (when auto_save is disabled)
                save_chat_keymap = "sc",
                -- Save all chats by default (disable to save only manually using 'sc')
                auto_save = true,
                -- Picker interface (auto resolved to a valid picker)
                picker = "telescope", --- ("telescope", "snacks", "fzf-lua", or "default") 
                -- Optional filter function to control which chats are shown when browsing
                chat_filter = nil, -- function(chat_data) return boolean end
                -- Customize picker keymaps (optional)
                picker_keymaps = {
                    delete = { n = "d", i = "<M-d>" },
                },
                -- Directory path to save the chats
                dir_to_save = vim.fn.stdpath("data") .. "/codecompanion-history",
                -- Enable detailed logging for history extension
                enable_logging = false,
            }
        }
    }
})
```

## 🛠️ Usage

#### 🎯 Commands

- `:CodeCompanionHistory` - Open the history browser

#### ⌨️ Chat Buffer Keymaps

- `gh` - Open history browser (customizable via `opts.keymap`)
- `sc` - Save current chat manually (customizable via `opts.save_chat_keymap`)

#### 📚 History Browser

The history browser shows all your saved chats with:
- Title (from first user message, truncated to 50 characters)
- Relative timestamps
- Preview of chat contents

Actions in history browser:
- `<CR>` - Open selected chat
- Normal mode:
  - `d` - Delete selected chat(s)
- Insert mode:
  - `<M-d>` (Alt+d) - Delete selected chat(s)

## Title Generation

The extension supports two title generation modes:

### Simple Title Generation (Default)

Titles are automatically generated from the first user message in the chat:
- Extracts the first user message with content
- Truncates to 50 characters
- Replaces newlines with spaces
- Falls back to "Untitled Chat" if no user message found

No API calls are made for title generation, making it instant and reliable.

### LLM-Based Title Generation (Optional)

For better, more descriptive titles, you can enable LLM-based title generation. This uses CodeCompanion's background task system to generate pithy, context-aware titles via your configured LLM.

**Benefits:**
- More accurate and descriptive titles
- Captures the essence of the conversation
- Handles multi-turn conversations better

**Requirements:**
- An LLM adapter configured for background tasks
- Enable the feature in your CodeCompanion config (see below)

**Enable LLM-Based Title Generation:**

Add this to your CodeCompanion configuration:

```lua
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
    extensions = {
        history = {
            enabled = true,
            opts = {
                -- your history options
            }
        }
    }
})
```

**How it works:**
1. When a new chat is created, the background title generation is triggered asynchronously
2. The LLM analyzes the conversation and generates a concise title (8 words or fewer)
3. The generated title is automatically saved and displayed
4. If LLM title generation fails, the extension falls back to simple title generation

**Note:** This is optional. Without enabling it, the history extension will use simple title generation from the first user message.

#### 🏢 Project-Aware Chat Filtering

The extension supports flexible chat filtering to help you focus on relevant conversations:

**Configurable Filtering:**
```lua
chat_filter = function(chat_data)
    return chat_data.cwd == vim.fn.getcwd()
end

-- Recent chats only (last 7 days)
chat_filter = function(chat_data)
    local seven_days_ago = os.time() - (7 * 24 * 60 * 60)
    return chat_data.updated_at >= seven_days_ago
end
```

**Chat Index Data Structure:**
Each chat index entry (used in filtering) includes the following information:
```lua
-- ChatIndexData - lightweight metadata used for browsing and filtering
{
    save_id = "1672531200",                 -- Unique chat identifier
    title = "Debug API endpoint",           -- Chat title (from first user message)
    cwd = "/home/user/my-project",          -- Working directory when saved
    project_root = "/home/user/my-project", -- Detected project root
    adapter = "openai",                     -- LLM adapter used
    model = "gpt-4",                        -- Model name
    updated_at = 1672531200,                -- Unix timestamp of last update
}
```

#### 🔧 API

The history extension exports the following functions that can be accessed via `require("codecompanion").extensions.history`:

```lua
-- Chat Management
get_location(): string?                           -- Get storage location

-- Save a chat to storage (uses last chat if none provided) 
save_chat(chat?: CodeCompanion.Chat)

-- Browse chats with custom filter function
browse_chats(filter_fn?: function(ChatIndexData): boolean)

-- Get metadata for all saved chats with optional filtering
get_chats(filter_fn?: function(ChatIndexData): boolean): table<string, ChatIndexData>

-- Load a specific chat by its save_id
load_chat(save_id: string): ChatData?

-- Delete a chat by its save_id
delete_chat(save_id: string): boolean
```

Example usage:
```lua
local history = require("codecompanion").extensions.history

-- Browse chats with project filter
history.browse_chats(function(chat_data)
    return chat_data.project_root == utils.find_project_root()
end)

-- Get all saved chats metadata
local chats = history.get_chats()

-- Load a specific chat
local chat_data = history.load_chat("some_save_id")

-- Delete a chat
history.delete_chat("some_save_id")
```

## ⚙️ How It Works

```mermaid
graph TD
    subgraph CodeCompanion Core Lifecycle
        A[CodeCompanionChatCreated Event] --> B{Chat Submitted};
        B --> C[Auto-Save Chat];
        C --> D{Has Title?};
        D -- No --> E[Generate Simple Title];
        E --> F[Update Buffer Title];
        B --> G[CodeCompanionChatCleared Event];
    end

    subgraph LLM Title Generation Optional
        H[Background Task Triggered] --> I{LLM Generates Title};
        I -- Success --> J[CodeCompanionChatTitleGenerated Event];
        J --> K[Update Chat Title];
        K --> L[Re-Save Chat];
        L --> F;
        I -- Fail/Disabled --> E;
    end

    subgraph Extension Integration
        A -- Extension Hooks --> M[Init & Setup];
        M --> N[Generate save_id];
        N --> O[Set Buffer Title];
        
        B -- Extension Hooks --> P[Save Chat State];
        P --> D;
        
        G -- Extension Hooks --> Q[Reset Chat State];
        Q --> R[Generate New save_id];
        R --> O;
    end

    subgraph User History Interaction
        S[User Action - gh / :CodeCompanionHistory] --> T{History Browser};
        T -- Restore --> U[Load Chat State from Storage];
        U --> A;
        T -- Delete --> V[Remove from Storage];
    end
```

Here's what's happening in simple terms:

1. When you create a new chat, our extension:
   - Generates a unique save_id (Unix timestamp)
   - Sets the initial buffer title

2. As you chat:
   - Each submitted message triggers automatic saving
   - If the chat doesn't have a title, it generates a simple one from the first user message
   - If LLM-based title generation is enabled, a background task will generate a better title
   - The generated title automatically updates and re-saves the chat
   - All your messages, tools, and references are safely stored

3. When you clear a chat:
   - The chat state is reset
   - A new save_id is generated for the fresh chat

4. Any time you want to look at old chats:
   - Use `gh` or the command to open the history browser
   - Pick any chat to restore it completely
   - Or remove ones you don't need anymore

<details>
    <summary>Technical details</summary>

The extension integrates with CodeCompanion through a robust event-driven architecture:

1. **Initialization and Storage Management**:
   - Uses a dedicated Storage class to manage chat persistence in `{data_path}/codecompanion-history/`
   - Maintains an index.json for metadata and individual JSON files for each chat
   - Implements file I/O operations with error handling

2. **Chat Lifecycle Integration**:
   - Hooks into `CodeCompanionChatCreated` event to:
     - Generate unique save_id (Unix timestamp)
     - Set initial buffer title with sparkle icon (✨)

   - Monitors `CodeCompanionChatSubmitted` events to:
     - Persist complete chat state including messages, tools, schemas, and references
     - Generate simple title from first user message if no title exists
     - Update buffer title

   - Listens for `CodeCompanionChatTitleGenerated` events (LLM-based titles):
     - Updates chat title with LLM-generated title
     - Re-saves chat with new title
     - Falls back to simple title generation if LLM generation fails

3. **Title Generation**:
   - **Simple Mode **(default) Extracts first user message with content, truncates to 50 characters, replaces newlines with spaces
   - **LLM Mode **(optional) Uses background task system to generate context-aware titles via configured LLM
   - No API calls required for simple mode - instant generation
   - LLM mode provides more accurate, descriptive titles for multi-turn conversations

4. **State Management**:
   - Preserves complete chat context including:
     - Message history with role-based organization
     - Tool states and schemas
     - Reference management
     - Adapter configurations
     - Custom settings

5. **UI Components**:
   - Implements multiple picker interfaces (telescope/snacks/default)
   - Provides real-time preview generation with markdown formatting
   - Supports justified text layout for buffer titles
   - Handles window/buffer lifecycle management

6. **Data Flow**:
   - Chat data follows a structured schema (ChatData)
   - Implements proper serialization/deserialization
   - Maintains backward compatibility with existing chats
   - Provides error handling for corrupt or missing data

</details>

## 🔮 Future Roadmap

### Upcoming Features
- [ ] Chat search functionality
- [ ] Chat tagging and categorization
- [ ] Export chats to markdown

## 🔌 Related Extensions

- [MCP Hub](https://codecompanion.olimorris.dev/extensions/mcphub.html) extension

## 🙏 Acknowledgements

Special thanks to:
- [Oli Morris](https://github.com/olimorris) for creating the amazing [CodeCompanion.nvim](https://codecompanion.olimorris.dev) plugin - a highly configurable and powerful coding assistant for Neovim.

## 📄 License

MIT
