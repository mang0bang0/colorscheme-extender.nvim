local M = {}
local util = require("colorscheme-extender.util")

-- Table to hold highlights from nvim_get_hl()
M._highlights = {}

-- Table to hold colors. Key is the RGB
M._colors = {}

-- Testing functions to see as we go
function M.start()
    -- Create a new tab page to work with
    -- vim.cmd.tabnew()

    -- Get a table of the current highlights
    M._highlights = vim.api.nvim_get_hl(0, {})

    -- Test the RGB
    local r, g, b
    r, g, b = util.getRGB(vim.inspect(M._highlights.Comment.fg))
    print(r)
    print(g)
    print(b)

    local h, s, v
    h, s, v = util.RGBToHSV(vim.inspect(M._highlights.Comment.fg))

    print(h)
    print(s)
    print(v)

    -- Sort
    -- M._colors = table.sort()
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
