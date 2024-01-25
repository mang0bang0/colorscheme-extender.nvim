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

-- Sets the demo buffer with indents and text highlighted with all
-- unique highlights in the colorscheme
function M._setDemoBuffer(text, indent)
    -- Create a namespace for our highlights and record its nsid
    M._nsid = vim.api.nvim_create_namespace("colorscheme-extender")

    -- Move to the demo window
    vim.api.nvim_set_current_win(M._demoWinNum)

    -- Make sure the buffer is modifiable
    vim.opt_local.modifiable = true
    vim.opt_local.readonly = false

    -- Clear all namespaced objects in the buffer (should only be our namespace)
    vim.api.nvim_buf_clear_namespace(0, 0, 0, -1)

    -- Clear the demo buffer
    vim.api.nvim_buf_set_lines(M._demoBufNum, 0, -1, false, {})

    -- Set each line to be the max of 80 and text string length + indent
    -- TODO: is there a space after the text line if the string is like 100
    -- chars long and there's only 1 each line
    -- local lineWidth = 0
    local lineWidth = 80

    -- Leave space for indents
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

        -- Add highlights using extmarks
        for i,val in ipairs(colors) do
            vim.api.nvim_buf_set_extmark(
                M._demoBufNum,
                M._nsid,
                math.floor((i - 1) / entriesPerLine + startingLineIndex),
                indent + (i - 1) % entriesPerLine * (string.len(text) + 1),
                {
                    end_col = indent + (i - 1) % entriesPerLine *
                              (string.len(text) + 1) + string.len(text),
                    hl_group = val.name
                }
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

function M.getColorUnderCursor()
    -- TODO: Check we're in the right window

    -- Get the row and col pos of the cursor
    local row, col = vim.api.nvim_win_get_cursor(M._demoWinNum)


    -- Get only the extmarks of the word underneath
    local inspect = vim.inspect_pos(M._demoBufNum, row, col,
                                    {
                                        syntax = false,
                                        treesitter = false,
                                        extmarks = true,
                                        semantic_tokens = false
                                    })

    -- Check if the extmarks table is empty with next() (table would not be nil)
    -- If it is empty, then it means there are no extmakrs (whitespace)
    if next(inspect.extmarks) ~= nil then
        local highlight = inspect.extmarks[1].opts.hl_group
        local pString = "hl_group name: " .. highlight .. " "

        if M._highlights[highlight].fg ~= nil then
            pString = pString .. string.format("fg: #%X",
                                               M._highlights[highlight].fg)

            pString = pString .. " "
        end


        if M._highlights[highlight].bg ~= nil then
            pString = pString .. string.format("bg: #%X",
                                           M._highlights[highlight].bg)
        end

        print(pString)
    else
        print("No highlight!")
    end

    -- TODO: Open up a floating window? Or use Ex line?
end

function M._setIOBuffer()
    -- Move to the IO window
    vim.api.nvim_set_current_win(M._ioWinNum)

end

-- Testing functions to see as we go
function M.start(text, indent, pattern)
    -- Get and categorize all the highlight groups
    M._getHighlights(pattern)

    -- Create plugin tab and record the buf and win numbers opened
    M._createTab()

    -- Add the texts and highlights to the tab
    M._setDemoBuffer(text, indent)

    -- Set a local keymap for getting the color codes of higihlights in the demo
    -- buffer
    vim.keymap.set(
        "n",
        "K",
        function() require("colorscheme-extender").getColorUnderCursor() end,
        {
            silent = true,
            buffer = M._demoBufNum
        }
    )
end

-- On setup, create a new command for users to call
function M.setup()
    vim.api.nvim_create_user_command(
        "ColorschemeExtend",
        function () require("colorscheme-extender").start("hello", 2,
                                                          "^DevIcon") end,
        {}
    )
end

return M
