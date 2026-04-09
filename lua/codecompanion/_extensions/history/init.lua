---@class CodeCompanion.History
---@field opts CodeCompanion.History.Opts
---@field storage CodeCompanion.History.Storage
---@field ui CodeCompanion.History.UI
---@field new fun(opts: CodeCompanion.History.Opts): CodeCompanion.History
local History = {}
local log = require("codecompanion._extensions.history.log")
local pickers = require("codecompanion._extensions.history.pickers")
local utils = require("codecompanion._extensions.history.utils")

---Monkey patch to save some extra fields in the Chat instance
---@class CodeCompanion.History.ChatArgs : CodeCompanion.ChatArgs
---@field save_id string?
---@field title string?
---@field cwd string? Current working directory when chat was saved

---@class CodeCompanion.History.Chat : CodeCompanion.Chat
---@field opts CodeCompanion.History.ChatArgs

---@type CodeCompanion.History|nil
local history_instance

---@type CodeCompanion.History.Opts
local default_opts = {
    ---A name for the chat buffer that tells that this is a auto saving chat
    default_buf_title = "[CodeCompanion] " .. " ",

    ---Keymap to open history from chat buffer (default: gh)
    keymap = "gh",
    ---Description for the history keymap (for which-key integration)
    keymap_description = "Browse saved chats",
    ---Keymap to save the current chat manually (when auto_save is disabled)
    save_chat_keymap = "sc",
    ---Description for the save chat keymap (for which-key integration)
    save_chat_keymap_description = "Save current chat",
    ---Save all chats by default (disable to save only manually using 'sc')
    auto_save = true,
    ---Valid Picker interface ("telescope", "snacks", "fzf-lua", or "default")
    ---@type CodeCompanion.History.Pickers
    picker = pickers.history,
    picker_keymaps = {
        delete = {
            n = "d",
            i = "<M-d>",
        },
    },
    ---Directory path to save the chats
    dir_to_save = vim.fn.stdpath("data") .. "/codecompanion-history",
    ---Enable detailed logging for history extension
    enable_logging = false,
    ---Filter function for browsing chats (defaults to show all chats)
    chat_filter = nil,
}

---@class CodeCompanion.History
---@param opts CodeCompanion.History.Opts
---@return CodeCompanion.History
function History.new(opts)
    local history = setmetatable({}, {
        __index = History,
    })
    history.opts = opts
    history.storage = require("codecompanion._extensions.history.storage").new(opts)
    history.ui = require("codecompanion._extensions.history.ui").new(opts, history.storage)

    -- Setup commands
    history:_create_commands()
    history:_setup_autocommands()
    history:_setup_keymaps()
    return history --[[@as CodeCompanion.History]]
end

function History:_create_commands()
    vim.api.nvim_create_user_command("CodeCompanionHistory", function()
        self.ui:open_saved_chats(self.opts.chat_filter)
    end, {
        desc = "Open saved chats",
    })
end

---Generate a simple title from the first user message
---@param chat CodeCompanion.History.Chat
---@return string
function History:_generate_simple_title(chat)
    if not chat.messages or #chat.messages == 0 then
        return "Untitled Chat"
    end

    -- Find the first user message with content
    local config = require("codecompanion.config")
    for _, msg in ipairs(chat.messages) do
        if msg.role == config.constants.USER_ROLE and msg.content and vim.trim(msg.content) ~= "" then
            local content = vim.trim(msg.content)
            -- Truncate to 50 characters and remove newlines
            if #content > 50 then
                content = content:sub(1, 47) .. "..."
            end
            content = content:gsub("\n", " ")
            return content
        end
    end

    return "Untitled Chat"
end

function History:_setup_autocommands()
    local group = vim.api.nvim_create_augroup("CodeCompanionHistory", { clear = true })

    vim.api.nvim_create_autocmd("User", {
        pattern = "CodeCompanionChatCreated",
        group = group,
        callback = vim.schedule_wrap(function(opts)
            log:trace("Chat created event received")
            local chat_module = require("codecompanion.interactions.chat")
            local bufnr = opts.data.bufnr
            local chat = chat_module.buf_get_chat(bufnr) --[[@as CodeCompanion.History.Chat]]

            -- Set initial buffer title
            if chat.opts.title then
                log:trace("Setting existing chat title: %s", chat.opts.title)
                self.ui:update_chat_title(chat)
            else
                -- Set title to indicate this is an auto-saving chat
                self.ui:update_chat_title(chat)
            end

            -- Check if custom save_id exists, else generate
            if not chat.opts.save_id then
                chat.opts.save_id = tostring(os.time())
                log:trace("Generated new save_id: %s", chat.opts.save_id)
            end
        end),
    })

    vim.api.nvim_create_autocmd("User", {
        pattern = "CodeCompanionChatSubmitted",
        group = group,
        callback = vim.schedule_wrap(function(opts)
            log:trace("Chat submitted event received")
            local chat_module = require("codecompanion.interactions.chat")
            local bufnr = opts.data.bufnr
            local chat = chat_module.buf_get_chat(bufnr) --[[@as CodeCompanion.History.Chat]]
            if not chat then
                return
            end

            -- Generate simple title if not already set
            if not chat.opts.title then
                chat.opts.title = self:_generate_simple_title(chat)
                self.ui:update_chat_title(chat)
            end

            if self.opts.auto_save then
                self.storage:save_chat(chat)
            end
        end),
    })

    vim.api.nvim_create_autocmd("User", {
        pattern = "CodeCompanionChatCleared",
        group = group,
        callback = vim.schedule_wrap(function(opts)
            log:trace("Chat cleared event received")

            local chat_module = require("codecompanion.interactions.chat")
            local bufnr = opts.data.bufnr
            local chat = chat_module.buf_get_chat(bufnr) --[[@as CodeCompanion.History.Chat]]
            if not chat then
                return
            end

            -- Reset chat state
            chat.opts.title = nil
            chat.opts.save_id = tostring(os.time())
            log:trace("Generated new save_id after clear: %s", chat.opts.save_id)

            -- Update title
            self.ui:update_chat_title(chat)
        end),
    })
end

function History:_setup_keymaps()
    local function form_modes(v)
        if type(v) == "string" then
            return {
                n = v,
            }
        end
        return v
    end

    local keymaps = {
        ["Saved Chats"] = {
            modes = form_modes(self.opts.keymap),
            description = self.opts.keymap_description,
            callback = function(_)
                self.ui:open_saved_chats(self.opts.chat_filter)
            end,
        },
        ["Save Current Chat"] = {
            modes = form_modes(self.opts.save_chat_keymap),
            description = self.opts.save_chat_keymap_description,
            callback = function(chat)
                if not chat then
                    return
                end
                self.storage:save_chat(chat)
                log:debug("Saved current chat")
            end,
        },
    }

    local cc_config = require("codecompanion.config")
    -- Add all keymaps to codecompanion
    for name, keymap in pairs(keymaps) do
        cc_config.interactions.chat.keymaps[name] = keymap
    end
end

---@type CodeCompanion.Extension
return {
    ---@param opts CodeCompanion.History.Opts
    setup = function(opts)
        if not history_instance then
            -- Initialize logging first
            opts = vim.tbl_deep_extend("force", default_opts, opts or {})
            log.setup_logging(opts.enable_logging)
            history_instance = History.new(opts)
            log:debug("History extension setup successfully")
        end
    end,
    exports = {
        ---Get the base path of the storage
        ---@return string?
        get_location = function()
            if not history_instance then
                return
            end
            return history_instance.storage:get_location()
        end,
        ---Save a chat to storage falling back to the last chat if none is provided
        ---@param chat? CodeCompanion.History.Chat
        save_chat = function(chat)
            if not history_instance then
                return
            end
            history_instance.storage:save_chat(chat)
        end,

        ---Browse chats with custom filter function
        ---@param filter_fn? fun(chat_data: CodeCompanion.History.ChatIndexData): boolean Optional filter function
        browse_chats = function(filter_fn)
            if not history_instance then
                return
            end
            history_instance.ui:open_saved_chats(filter_fn)
        end,

        --- Loads chats metadata from the index with optional filtering
        ---@param filter_fn? fun(chat_data: CodeCompanion.History.ChatIndexData): boolean Optional filter function
        ---@return table<string, CodeCompanion.History.ChatIndexData>
        get_chats = function(filter_fn)
            if not history_instance then
                return {}
            end
            return history_instance.storage:get_chats(filter_fn)
        end,

        --- Load a specific chat
        ---@param save_id string ID from chat.opts.save_id to retrieve the chat
        ---@return CodeCompanion.History.ChatData?
        load_chat = function(save_id)
            if not history_instance then
                return
            end
            return history_instance.storage:load_chat(save_id)
        end,

        ---Delete a chat
        ---@param save_id string ID from chat.opts.save_id to delete the chat
        ---@return boolean
        delete_chat = function(save_id)
            if not history_instance then
                return false
            end
            return history_instance.storage:delete_chat(save_id)
        end,
    },
    --for testing
    History = History,
}
