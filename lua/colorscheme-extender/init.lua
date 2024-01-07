local M = {}
local util = require("colorscheme-extender.util")

-- Table to hold highlights from nvim_get_hl()
M._highlights = {}

-- Tables to hold colors. Value is the RRGGBB value
M._fgColors = {}
M._bgColors = {}
M._fgBgColors = {}

function M._populateTab(entry)
    -- Create a new tab page to work with
    vim.cmd.tabnew()

    -- TODO: Gonna be more robust handling here when things get too narrow
    -- Set each line to be 80 chars wide
    local lineWidth = 80

    -- Add a space to the end of text for separation
    entry = " " .. entry

    -- -5 so that we have some space on the very left
    local entriesPerLine = math.floor((lineWidth - 5) / string.len(entry))

    -- Get number of lines, and handle if there's a partial line in the end
    local numOfLines = math.floor(#M._fgColors / entriesPerLine)
    local partial = false
    if #M._fgColors % entriesPerLine > 0 then
        partial = true
        numOfLines = numOfLines + 1
    end

    -- Construct the text of a full line, with 5 spaces before
    local lineText = "     "

    for j = 1, entriesPerLine do
        lineText = lineText .. entry
    end

    -- Populate an array with the guarenteed full lines
    local lines = {}

    for i = 0, numOfLines - 2 do
        table.insert(lines, lineText)
    end

    -- If there's a partial line, construct it
    if partial then
        -- Construct a partial line and set it
        lineText = "     "
        for i = 1, #M._fgColors % entriesPerLine do
            lineText = lineText .. entry
        end
    end

    -- Add the last line
    table.insert(lines, lineText)

    -- Set the buffer
    vim.api.nvim_buf_set_lines(0, 0, numOfLines, false, lines)

    -- Add highlights
    for i,v in ipairs(M._fgColors) do
        vim.api.nvim_buf_add_highlight(
            0, -1, v.name,
            math.floor((i - 1) / entriesPerLine),
            6 + (i - 1) % entriesPerLine * string.len(entry),
            6 + (i - 1) % entriesPerLine * string.len(entry)+ string.len(entry)
        )
    end

    --[[
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
    ]]--

    -- Set the buffer to no longer be modifiable
end

function M._setHighlights(text)

end

-- Testing functions to see as we go
function M.start(text)
    -- Get a table of the highlights of the current colorscheme
    M._highlights = vim.api.nvim_get_hl(0, {})

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

    M._populateTab(text)
end

-- On setup, create a new command for users to call
function M.setup()
    vim.api.nvim_create_user_command(
        "ColorschemeExtend",
        function () require("colorscheme-extender").start("xxx") end,
        {}
    )
end

return M
