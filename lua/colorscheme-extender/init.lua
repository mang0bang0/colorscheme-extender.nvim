local M = {}
-- All functions not meant to be called by the user and not operating on the
-- buffers are placed under util.lua
local util = require("colorscheme-extender.util")

-- Table to hold highlights from nvim_get_hl()
M._highlights = {}

-- Module-level vars to hold text, indent, regex pattern, linewidth
M._text = nil
M._indent = nil
M._pattern = nil
M._lineWidth = nil

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
-- The namespace ID used by the plugin in a table
M._nsid = {
    hl = nil,
    io = nil
}

-- TOOD: Set filetype of the demo buffer and IO buffer
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

-- Sets the demo buffer with indents and text highlighted with all
-- unique highlights in the colorscheme
function M._setDemoBuffer(text, indent, lineWidth)
    -- Create a namespace for our highlights and record its nsid
    M._nsid.hl = vim.api.nvim_create_namespace("colex-hl")

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

        -- Populate an array with the lines of text in demo buffer
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
                M._nsid.hl,
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

    -- Add instructions at the bottom
    local instructions = {
        "Press K (shift+k) to see the name and color code of the highlight",
        "under your cursor"
    }

    vim.api.nvim_buf_set_lines(
        M._demoBufNum,
        startingLineIndex,
        startingLineIndex + #instructions,
        false,
        instructions
    )

    -- Set the buffer to no longer be modifiable
    vim.opt_local.modifiable = false
    vim.opt_local.readonly = true
end

-- TODO: Use extmarks to keep track of text changes

-- NOTE: Is it better to have a keybind that acts like an apply button compared
-- to hot reloading by observing real-time changes?

-- NOTE: Or we can track changes only on InsertLeave, and if someone pasted
-- text, then they will have to enter and leave insert mode as kind of a way to
-- "apply" their changes

-- NOTE: see set_lines() for how to delete lines

-- TODO: Move text, indent, pattern, and the like to global, because we need to
-- use a callback function, which would need global vars

-- TODO: Floating windows that show generated code
function M._setIOBuffer(text, indent, lineWidth, pattern)
    -- Move to the IO window
    vim.api.nvim_set_current_win(M._ioWinNum)

    -- Do initial formatting
    local bufferText = {
        "Display Text (in one line):",
        text,
        "----------",
        "Indent Length (positive number only):",
        tostring(indent),
        "----------",
        "Line Width (positive number only):",
        tostring(lineWidth),
        "----------",
        "Vim Regex Pattern to Filter Out:",
        pattern ~= nil and pattern or "",
        "----------",
        "Bookmarks:"
    }

    vim.api.nvim_buf_set_lines(
        M._ioBufNum,
        0,
        #bufferText,
        false,
        bufferText
    )

    -- Set extmarks for each of the input fields
    -- First create a namespace for each so we can differentiate
    M._nsid.io = vim.api.nvim_create_namespace("colex-io")
    -- Then put an extmark on each input line

    -- NOTE: THIS FOLLOWING PARAGRAPH SHOULD BE IN A DIFFERENT FUNCTION
    -- After every insert leave, we check the position of all the extmarks in IO
    -- buffer to make sure that they stay on the correct lines, meaning that the
    -- user didn't add multi-line inputs, which are forbidden
    -- If it's good, then we proceed, otherwise we restore the IO buffer to the
    -- most recent state (refilling the text, indent, etc.)

    -- TODO: for bookmarking fgbg, pick either only fg, only bg, and both?

end

-- Get the name and colorcode of the extmark highlight of the character under
-- the cursor.
-- NOTE: Only works on extmarks!
function M.getColorUnderCursor()
    -- Technically the function is only called through a buffer-local binding,
    -- so this will only activate if the user calls it on their own. It's fine,
    -- but they probably won't get a lot of useful information, as this only
    -- works on extmarks and not treesitter
    if vim.api.nvim_get_current_win() ~= M._demoWinNum then
        print("You are not in the demo buffer!")
    end

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

    -- Check if the extmarks table is empty with next() (empty table isn't nil)
    -- If it is empty, then it means there are no extmarks (whitespace)
    if next(inspect.extmarks) ~= nil then
        local highlight = inspect.extmarks[1].opts.hl_group
        local pString = "hl_group name: " .. highlight

        if M._highlights[highlight].fg ~= nil then
            pString = pString .. ", " ..
                      string.format("fg: #%X",
                                    M._highlights[highlight].fg)
        end

        if M._highlights[highlight].bg ~= nil then
            pString = pString .. ", " ..
                      string.format("bg: #%X",
                                    M._highlights[highlight].bg)
        end

        print(pString)
    else
        print("No highlight!")
    end

    -- TODO: Open up a floating window? Or use Ex line?
end

-- Testing functions to see as we go
function M.start(text, indent, lineWidth, pattern)
    -- Store settings into module-level variables
    M._text = text
    M._indent = indent
    M._lineWidth = lineWidth
    M._pattern = pattern

    -- Get and categorize all the highlight groups
    M._highlights, M._colors = util._getHighlights(pattern)

    -- Create plugin tab and record the buf and win numbers opened
    M._createTab()

    -- Add the texts and highlights to the tab
    M._setDemoBuffer(text, indent, lineWidth)

    -- Set up the UI in the IO buffer
    M._setIOBuffer(text, indent, lineWidth, pattern)

    -- Set a local keymap for getting the color codes of higihlights in the demo
    -- buffer
    vim.keymap.set(
        "n",
        "K",
        function() require("colorscheme-extender").getColorUnderCursor() end,
        {silent = true, buffer = M._demoBufNum}
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
