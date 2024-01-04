local M = {}

-- Table to hold highlights from nvim_get_hl()
M._highlights = {}

-- Table to hold colors. Key is the RGB
M._colors = {}

-- Function to convert the RRGGBB value returned by nvim API to separate R, G, B
-- Takes RRGGBB (hex now represented as decimal)
local function getRGB(rgb)
    -- Get the individual r, g, and b values
    local r = math.floor(rgb / 65536)
    rgb = rgb - r * 65536
    local g = math.floor(rgb / 256)
    rgb = rgb - g * 256
    local b = rgb

    return r, g, b
end

-- Function to Convert sRGB to Oklab
-- Takes the decimal of RRGGBB as an argument
local function RGBToHSV(rgb)
    -- Get separate R, G, and B values
    local r, g, b = getRGB(rgb)

    -- Change from [0, 255] to [0, 1]
    r = r / 255
    g = g / 255
    b = b / 255

    local h, s, v

    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local chroma = max - min

    if chroma == 0 then
        h = 0
    elseif max == r then
        h = 60 * ((g - b) / chroma % 6)
    elseif max == g then
        h = 60 * ((b - r) / chroma + 2)
    elseif max == b then
        h = 60 * ((r - g) / chroma + 4)
    end

    if max == 0 then
        s = 0
    else
        s = chroma / max
    end

    v = max

    return h, s, v
end

-- Testing functions to see as we go
function M.start()
    -- Create a new tab page to work with
    -- vim.cmd.tabnew()

    -- Get a table of the current highlights
    M._highlights = vim.api.nvim_get_hl(0, {})

    -- Test the RGB
    local r, g, b
    r, g, b = getRGB(vim.inspect(M._highlights.Comment.fg))
    print(r)
    print(g)
    print(b)

    local h, s, v
    h, s, v = RGBToHSV(vim.inspect(M._highlights.Comment.fg))

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
