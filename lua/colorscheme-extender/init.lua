local M = {}
local util = require("colorscheme-extender.util")

-- Table to hold highlights from nvim_get_hl()
M._highlights = {}

-- Tables to hold colors. Value is the RRGGBB value
-- Index 1 is fg, 2 is bg, 3 is fgbg. Only indices and not keys are used for
-- table traversal
M._colors = {{}, {}, {}}

-- The buffer and window number of the demo buffer
M._demoBufNum = 0
M._demoWinNum = 0
-- The buffer and window number of the I/O buffer
M._ioBufNum = 0
M._ioWinNum = 0
-- The namespace ID of the extmarks used for highlighting in the demo
-- buffer
M._nsid = 0

-- Fills out the M._colors table, filtering out highlights with names that match
-- the vim regex pattern
function M._getHighlights(pattern)
    -- Get a table of the highlights of the current colorscheme
    M._highlights = vim.api.nvim_get_hl(0, {})

    -- Three tables would be used for the three kinds of highlights: fg only, bg
    -- only, and fg and background. The reason is because the user is probably
    -- only looking for one of these three types. It doesn't make sense to mix
    -- them when displaying in our buffer.

    -- Construct the three tables from the global highlight table, checking if
    -- the user provided regex matches. If there is a match, it is not added!
    -- Note that it does not completely remove that color, it only excludes
    -- highlight groups with that name
    for k,v in pairs(M._highlights) do
        if not (pattern and vim.regex(pattern):match_str(k)) then
            if v.fg and v.bg then
                table.insert(M._colors[3], {name = k, fg = v.fg, bg = v.bg})
            elseif v.fg then
                table.insert(M._colors[1], {name = k, fg = v.fg})
            elseif v.bg then
                table.insert(M._colors[2], {name = k, bg = v.bg})
            end
        else
            print("Filtered " .. k .. "\n")
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

end

function M._setDemoBuffer(text, indent)
    -- Move to the demo window
    vim.api.nvim_set_current_win(M._demoWinNum)

    -- Make sure the buffer is modifiable
    vim.opt_local.modifiable = true
    vim.opt_local.readonly = false

    -- Clear the highlights in the demo buffer
    vim.api.nvim_buf_clear_namespace(0, 0, 0, -1)

    -- Clear the demo buffer
    vim.api.nvim_buf_set_lines(M._demoBufNum, 0, -1, false, {})

    -- Set each line to be 80 chars wide
    local lineWidth = 80

    -- -5 so that we have some space on the very left
    local entriesPerLine = math.floor((lineWidth + 1 - indent) /
                                      (string.len(text) + 1))
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
        local lineText = util._constructLine(text, indent, entriesPerLine)

        -- Populate an array with the guarenteed full lines
        local lines = {}

        -- "- 2" because numOfLines includes the not guarenteed full line and an
        -- empty line
        for _ = 1, numOfLines - 2 do
            table.insert(lines, lineText)
        end

        -- If there's a partial line, construct it
        if partial then
            lineText = util._constructLine(text, indent,
                                           #colors % entriesPerLine)
        end

        -- Add the last line
        table.insert(lines, lineText)

        -- Then add an empty line
        table.insert(lines, "")

        -- Set the buffer
        vim.api.nvim_buf_set_lines(
            M._demoBufNum,
            startingLineIndex,
            startingLineIndex + numOfLines,
            false,
            lines
        )

        -- Add highlights
        for i,val in ipairs(colors) do
            vim.api.nvim_buf_add_highlight(
                M._demoBufNum,
                -1,
                val.name,
                math.floor((i - 1) / entriesPerLine + startingLineIndex),
                indent + (i - 1) % entriesPerLine * (string.len(text) + 1),
                indent + (i - 1) % entriesPerLine * (string.len(text) + 1) +
                    string.len(text)
            )
        end

        startingLineIndex = startingLineIndex + numOfLines
    end

    -- Set the buffer to no longer be modifiable
    vim.opt_local.modifiable = false
    vim.opt_local.readonly = true
end

function M._createTab()
    -- Create a new tab page to work with
    vim.cmd.tabnew()

    -- Get the buffer number of the demo buffer
    M._demoBufNum = vim.api.nvim_get_current_buf()
    M._demoWinNum = vim.api.nvim_get_current_win()

    -- Open a vertically split window for I/O
    vim.cmd.vnew()

    -- Get the buffer number of the I/O buffer
    M._ioBufNum = vim.api.nvim_get_current_buf()
    M._ioWinNum = vim.api.nvim_get_current_win()

end

-- Testing functions to see as we go
function M.start(text, indent, pattern)
    -- Get and categorize all the highlight groups
    M._getHighlights(pattern)

    -- Create plugin tab
    M._createTab()

    -- Add the texts and highlights to the tab
    M._setDemoBuffer(text, indent)
end

function M.getColorUnderCursor()

end

-- On setup, create a new command for users to call
-- TODO: add support for multpile regex
function M.setup()
    vim.api.nvim_create_user_command(
        "ColorschemeExtend",
        function () require("colorscheme-extender").start("hello", 2,
                                                          "^DevIcon") end,
        {}
    )
end

return M
