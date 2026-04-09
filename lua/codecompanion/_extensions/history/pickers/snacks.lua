---@class CodeCompanion.History.SnacksPicker : CodeCompanion.History.DefaultPicker
local SnacksPicker = setmetatable({}, {
    __index = require("codecompanion._extensions.history.pickers.default"),
})
SnacksPicker.__index = SnacksPicker

function SnacksPicker:browse()
    require("snacks.picker").pick({
        title = self.config.title,
        items = self.config.items,
        main = { file = false, float = true },
        format = function(item)
            return { { self:format_entry(item) } }
        end,
        transform = function(item)
            item.file = self:get_item_id(item)
            item.text = self:get_item_title(item)
            return item
        end,
        preview = function(ctx)
            local item = ctx.item
            local lines = self.config.handlers.on_preview(item)
            if not lines then
                return
            end

            local buf_id = ctx.preview:scratch()
            vim.bo[buf_id].filetype = "markdown"
            vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
        end,
        confirm = function(picker, _)
            local items = picker:selected({ fallback = true })
            if items then
                picker:close()
                vim.iter(items):each(function(item)
                    self.config.handlers.on_select(item)
                end)
            end
        end,
        actions = {
            delete_item = function(picker)
                local selections = picker:selected({ fallback = true })
                if #selections == 0 then
                    return
                end
                picker:close()
                self.config.handlers.on_delete(selections)
            end,
        },

        win = {
            input = {
                keys = {
                    [self.config.keymaps.delete.n] = { "delete_item", mode = "n" },
                    [self.config.keymaps.delete.i] = { "delete_item", mode = "i" },
                },
            },
            list = {
                keys = {
                    [self.config.keymaps.delete.n] = { "delete_item", mode = "n" },
                    [self.config.keymaps.delete.i] = { "delete_item", mode = "i" },
                },
            },
        },
    })
end

return SnacksPicker
