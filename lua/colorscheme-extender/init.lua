local M = {}
local util = require("colorscheme-extender.util")

-- Table to hold highlights from nvim_get_hl()
M._highlights = {}

-- Tables to hold colors. Value is the RRGGBB value
-- Index 1 is fg, 2 is bg, 3 is fgbg
M._colors = {{}, {}, {}}

-- This holds the buffer number of the demo buffer
M._bufNum = 0

-- Function that constructs a demo line in the buffer
-- entry is the string of each entry, indent is an integer that's the number of
-- spaces before the text, and entriesPerLine is the number of entries on this
-- line
function M._constructLine(entry, indent, entriesPerLine)
    local lineText = ""

    -- First add the indents in the beginning
    for _ = 1, indent do
        lineText = lineText .. " "
    end

    -- Then add the entries after
    for i = 1, entriesPerLine do
        lineText = lineText .. entry
        if i < entriesPerLine then
            lineText = lineText .. " "
        end
    end

    return lineText
end

function M._populateBuffer(entry, indent)
    -- Make sure the buffer is modifiable
    vim.opt_local.modifiable = true

    -- Clear the buffer
    vim.api.nvim_buf_set_lines(M._bufNum, 0, -1, false, {})

    -- Set each line to be 80 chars wide
    local lineWidth = 80

    -- -5 so that we have some space on the very left
    local entriesPerLine = math.floor((lineWidth + 1 - indent) / (string.len(entry) + 1))
    local startingLineIndex = 0

    -- For each table, fg, bg, and fgBg
    for _,colors in ipairs(M._colors) do
        -- Get number of lines, and handle if there's a partial line in the end
        -- Add 1 because we want empty lines between fg, bg, fgBg
        local numOfLines = math.floor(#colors / entriesPerLine) + 1
        local partial = false

        if #colors % entriesPerLine > 0 then
            partial = true
            numOfLines = numOfLines + 1
        end

        -- Construct the text of a full line
        local lineText = M._constructLine(entry, indent, entriesPerLine)

        -- Populate an array with the guarenteed full lines
        local lines = {}

        -- "- 2" because numOfLines includes the not guarenteed full line and an
        -- empty line
        for _ = 1, numOfLines - 2 do
            table.insert(lines, lineText)
        end

        -- If there's a partial line, construct it
        if partial then
            lineText = M._constructLine(entry, indent, #colors % entriesPerLine)
        end

        -- Add the last line
        table.insert(lines, lineText)

        -- Then add an empty line
        table.insert(lines, "")

        -- Set the buffer
        vim.api.nvim_buf_set_lines(
            M._bufNum,
            startingLineIndex,
            startingLineIndex + numOfLines,
            false,
            lines
        )

        -- Add highlights
        for i,val in ipairs(colors) do
            -- TODO: arithmetic need
            vim.api.nvim_buf_add_highlight(
                M._bufNum,
                -1,
                val.name,
                math.floor((i - 1) / entriesPerLine + startingLineIndex),
                indent + (i - 1) % entriesPerLine * (string.len(entry) + 1),
                indent + (i - 1) % entriesPerLine * (string.len(entry) + 1) +
                    string.len(entry)
            )
        end

        startingLineIndex = startingLineIndex + numOfLines
    end

    -- Set the buffer to no longer be modifiable
    vim.opt_local.modifiable = false
end

-- Testing functions to see as we go
function M.start(text, indent)
    -- Get a table of the highlights of the current colorscheme
    M._highlights = vim.api.nvim_get_hl(0, {})

    -- Three tables would be used for the three kinds of highlights: fg only, bg
    -- only, and fg and background. The reason is because the user is probably
    -- only looking for one of these three types. It doesn't make sense to mix
    -- them when displaying in our buffer.

    -- Construct the three tables from the global highlight table
    for k,v in pairs(M._highlights) do
        if v.fg and v.bg then
            table.insert(M._colors[3], {name = k, fg = v.fg, bg = v.bg})
        elseif v.fg then
            table.insert(M._colors[1], {name = k, fg = v.fg})
        elseif v.bg then
            table.insert(M._colors[2], {name = k, bg = v.bg})
        end
    end

    -- Sort the three tables based on HSV
    table.sort(M._colors[1], util.HSVSort)
    table.sort(M._colors[2], util.HSVSort)
    table.sort(M._colors[3], util.HSVSort)

    -- Remove duplicate entriers for the three tables
    util.removeDuplicates(M._colors[1])
    util.removeDuplicates(M._colors[2])
    util.removeDuplicates(M._colors[3])

    -- Create a new tab page to work with
    vim.cmd.tabnew()

    -- Get the buffer number of the demo buffer
    M._bufNum = vim.api.nvim_get_current_buf()

    -- Add the texts and highlights to the tab
    M._populateBuffer(text, indent)
end

-- On setup, create a new command for users to call
function M.setup()
    vim.api.nvim_create_user_command(
        "ColorschemeExtend",
        function () require("colorscheme-extender").start("x", 1) end,
        {}
    )
end

return M
