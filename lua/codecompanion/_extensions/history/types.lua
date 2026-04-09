---@meta CodeCompanion.Extension

---@alias CodeCompanion.History.Pickers "telescope" | "snacks" | "fzf-lua" |  "default"

---@class CodeCompanion.History.Opts
---@field default_buf_title? string A name for the chat buffer that tells that this is an auto saving chat
---@field keymap? string | table Keymap to open saved chats from the chat buffer
---@field keymap_description? string Description for the history keymap (for which-key integration)
---@field picker? CodeCompanion.History.Pickers Picker to use (telescope, etc.)
---@field enable_logging? boolean Enable logging for history extension
---@field auto_save? boolean Automatically save the chat whenever it is updated
---@field save_chat_keymap? string | table Keymap to save the current chat
---@field save_chat_keymap_description? string Description for the save chat keymap (for which-key integration)
---@field picker_keymaps? {delete?: table}
---@field chat_filter? fun(chat_data: CodeCompanion.History.ChatIndexData): boolean Filter function for browsing chats

---@class CodeCompanion.History.ChatMessage
---@field role string
---@field content string
---@field tool_calls table
---@field opts? {visible?: boolean, tag?: string}

---@class CodeCompanion.History.ChatData
---@field save_id string
---@field title? string
---@field messages CodeCompanion.History.ChatMessage[]
---@field updated_at number
---@field settings table
---@field adapter string
---@field refs? table -- Deprecated: for backward compatibility with old chats
---@field context_items? table -- New: replaces refs
---@field schemas? table
---@field in_use? table
---@field name? string
---@field cycle number
---@field title_refresh_count? number -- Deprecated: kept for backward compatibility
---@field cwd string Current working directory when chat was saved
---@field project_root string Project root directory when chat was saved

---@class CodeCompanion.History.ChatIndexData
---@field title string
---@field updated_at number
---@field save_id string
---@field model string
---@field adapter string
---@field cwd string Current working directory when chat was saved
---@field project_root string Project root directory when chat was saved

---@class CodeCompanion.History.UIHandlers
---@field on_preview fun(chat_data: CodeCompanion.History.EntryItem): string[]
---@field on_delete fun(chat_data: CodeCompanion.History.EntryItem|CodeCompanion.History.EntryItem[]): nil
---@field on_select fun(chat_data: CodeCompanion.History.EntryItem): nil
---@field on_open fun(): nil

---@class CodeCompanion.History.EntryItem : CodeCompanion.History.ChatIndexData
---@field name string Display name for the item

---@class CodeCompanion.History.BufferInfo
---@field bufnr number
---@field name string
---@field filename string
---@field is_visible boolean
---@field is_modified boolean
---@field is_loaded boolean
---@field lastused number
---@field windows number[]
---@field winnr number
---@field cursor_pos? number[]
---@field line_count number

---@class CodeCompanion.History.EditorInfo
---@field last_active CodeCompanion.History.BufferInfo|nil
---@field buffers CodeCompanion.History.BufferInfo[]

---@class CodeCompanion.History.TitleGeneratedEvent
---@field bufnr number Buffer number
---@field title string Generated title
---@field id number Chat ID
