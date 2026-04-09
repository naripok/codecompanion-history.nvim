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
            content = fmt(
                [[Please write a brief title for the following request:

%s]],
                M.format_messages(chat.messages)
            ),
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
