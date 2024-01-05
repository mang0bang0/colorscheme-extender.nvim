local M = {}
local util = require("colorscheme-extender.util")

-- Table to hold highlights from nvim_get_hl()
M._highlights = {}

-- Tables to hold colors. Value is the RRGGBB value
M._fgColors = {}
M._bgColors = {}
M._fgBgColors = {}

-- Testing functions to see as we go
function M.start()
    -- Get a table of the highlights of the current colorscheme
    M._highlights = vim.api.nvim_get_hl(0, {name = nil, id = nil, link = false})

    -- Three tables would be used for the three kinds of highlights: fg only, bg
    -- only, and fg and background. The reason is because the user is probably
    -- only looking for one of these three types. It doesn't make sense to mix
    -- them when displaying in our buffer.

    -- Construct the three tables from the global highlight table
    for k,v in pairs(M._highlights) do
        if v.fg and v.bg then
            table.insert(M._fgBgColors, {name = k, fg = v.fg, bg = v.bg})
        elseif v.fg then
            table.insert(M._fgColors, {name = k, fg = v.fg})
        elseif v.bg then
            table.insert(M._bgColors, {name = k, bg = v.bg})
        end
    end

    -- Sort the three tables based on HSV
    table.sort(M._fgColors, util.HSVSort)
    table.sort(M._bgColors, util.HSVSort)
    table.sort(M._fgBgColors, util.HSVSort)

    -- Remove duplicate entriers for the three tables
    util.removeDuplicates(M._fgColors)
    util.removeDuplicates(M._bgColors)
    util.removeDuplicates(M._fgBgColors)

    -- print(#M._fgColors .. " " .. vim.inspect(M._fgColors))
    -- print(#M._bgColors .. " " .. vim.inspect(M._bgColors))
    -- print(#M._fgBgColors .. " " .. vim.inspect(M._fgBgColors))

    -- Create a new tab page to work with
    vim.cmd.tabnew()

    -- Put some text in it
    vim.api.nvim_buf_set_lines(0, 0, 1, false, {"abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz"})
    vim.api.nvim_buf_set_lines(0, 1, 2, false, {"abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz"})
    vim.api.nvim_buf_set_lines(0, 2, 3, false, {"abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz"})

    -- Set highlights on the spaces
    for i,v in ipairs(M._fgColors) do
        vim.api.nvim_buf_add_highlight(0, -1, v.name, 0, i, i + 1)
    end

    -- Set highlights on the spaces
    for i,v in ipairs(M._bgColors) do
        vim.api.nvim_buf_add_highlight(0, -1, v.name, 1, i, i + 1)
    end

    for i,v in ipairs(M._fgBgColors) do
        vim.api.nvim_buf_add_highlight(0, -1, v.name, 2, i, i + 1)
    end
end

-- On setup, create a new command for users to call
function M.setup()
    vim.api.nvim_create_user_command(
        "ColorschemeExtend",
        function () require("colorscheme-extender").start() end,
        {}
    )
end

return M
