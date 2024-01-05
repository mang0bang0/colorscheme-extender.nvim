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
    M._highlights = vim.api.nvim_get_hl(0, {})

    -- Three tables would be used for the three kinds of highlights: fg only, bg
    -- only, and fg and background. The reason is because the user is probably
    -- only looking for one of these three types. It doesn't make sense to mix
    -- them when displaying in our buffer.

    -- Indices for the three tables created
    local fgi, bgi, fgBgi = 1, 1, 1

    -- Construct the three tables from the global highlight table
    for k,v in pairs(M._highlights) do
        if v.fg and v.bg then
            M._fgBgColors[fgBgi] = {["name"] = k, ["fg"] = v.fg, ["bg"] = v.bg}
            fgBgi = fgBgi + 1
        elseif v.fg then
            M._fgColors[fgi] = {["name"] = k, ["fg"] = v.fg}
            fgi = fgi + 1
        elseif v.bg then
            M._bgColors[bgi] = {["name"] = k, ["bg"] = v.bg}
            bgi = bgi + 1
        end
    end

    -- Sort the three tables based on HSV
    table.sort(M._fgColors, util.HSVCompare)
    table.sort(M._bgColors, util.HSVCompare)
    table.sort(M._fgBgColors, util.HSVCompare)

    -- Remove duplicate entriers for the three tables
    util.removeDuplicates(M._fgColors)
    util.removeDuplicates(M._bgColors)
    util.removeDuplicates(M._fgBgColors)

    -- print(vim.inspect(M._fgColors))
    -- print(vim.inspect(M._bgColors))
    print(vim.inspect(M._fgBgColors))
    -- First create a namespace just for our highlight group so we can group
    -- them easily nvim_create_namespace()
    -- Then add all the highlights we have from our three tables with
    -- nvim_set_hl()
    -- Finally, add the highlights with nvim_buf_add_highlight()

    -- Create a new tab page to work with
    -- vim.cmd.tabnew()

    -- Put some text in it

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
