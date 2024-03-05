local M = {}
-- All functions not meant to be called by the user and not operating on the
-- buffers are placed under util.lua
local util = require("colorscheme-extender.util")

-- Table to hold highlights from nvim_get_hl()
M._highlights = {}

-- Module-level vars to hold text, indent, regex pattern, linewidth
M._text = nil
M._indent = nil
M._lineWidth = nil
M._pattern = nil

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
M._nsID = {
    hl = nil,
    io = nil
}

-- The extmarks for each of the input variables in the IO buffer
M._extID = {
    text = nil,
    indent = nil,
    lineWidth = nil,
    regex = nil,
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
    if M._nsID.hl == nil then
        M._nsID.hl = vim.api.nvim_create_namespace("colex-hl")
    end

    -- Move to the demo window
    vim.api.nvim_set_current_win(M._demoWinNum)

    -- Make sure the buffer is modifiable
    vim.opt_local.modifiable = true
    vim.opt_local.readonly = false

    -- Clear all namespaced objects in the buffer (should only be our namespace)
    vim.api.nvim_buf_clear_namespace(0, 0, 0, -1)

    -- Clear the demo buffer
    vim.api.nvim_buf_set_lines(M._demoBufNum, 0, -1, false, {})

    -- Set each line to be the max of lineWidth and text string length + indent
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
                M._nsID.hl,
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

    -- Clear the IO buffere
    vim.api.nvim_buf_set_lines(M._ioBufNum, 0, -1, false, {})

    -- Do initial formatting
    local bufferText = {
        "Values on lines indicated by 'i' can be edited! To confirm the",
        "changes, perform the action of leaving insert mode! Think of it as",
        "hitting OK on a form.",
        "No multi-line inputs please. They will be discarded.",
        "",
        "Display Text (in one line):",
        text,
        "----------",
        "Indent Length (between 0 and 100):",
        tostring(indent),
        "----------",
        "Line Width (positive number only):",
        tostring(lineWidth),
        "----------",
        "Vim Regex Pattern to Filter Out (matches are filtered):",
        pattern ~= nil and pattern or "",
        "----------",
        "Bookmarks:"
    }

    vim.api.nvim_buf_set_lines(M._ioBufNum, 0, #bufferText, false, bufferText)

    -- Either this is the first time the buffer is being created, and the
    -- extmarks haven't been created yet, or the extmarks need to be redone, so
    -- clear delete them
    if M._nsID.io == nil then
        M._nsID.io = vim.api.nvim_create_namespace("colex-io")
        -- Then put an extmark on each input line/field
        M._extID.text      = vim.api.nvim_buf_set_extmark(M._ioBufNum,
                                                          M._nsID.io, 6, -1,
                                                          {sign_text = "i"})
        M._extID.indent    = vim.api.nvim_buf_set_extmark(M._ioBufNum,
                                                          M._nsID.io, 9, -1,
                                                          {sign_text = "i"})
        M._extID.lineWidth = vim.api.nvim_buf_set_extmark(M._ioBufNum,
                                                          M._nsID.io, 12, -1,
                                                          {sign_text = "i"})
        M._extID.regex     = vim.api.nvim_buf_set_extmark(M._ioBufNum,
                                                          M._nsID.io, 15, -1,
                                                          {sign_text = "i"})
    else
        vim.api.nvim_buf_clear_namespace(M._ioBufNum, M._nsID.io, 0, -1)

        vim.api.nvim_buf_set_extmark(M._ioBufNum, M._nsID.io, 6, -1,
                                     {sign_text = "i", id = M._extID.text})
        vim.api.nvim_buf_set_extmark(M._ioBufNum, M._nsID.io, 9, -1,
                                     {sign_text = "i", id = M._extID.indent})
        vim.api.nvim_buf_set_extmark(M._ioBufNum, M._nsID.io, 12, -1,
                                     {sign_text = "i", id = M._extID.lineWidth})
        vim.api.nvim_buf_set_extmark(M._ioBufNum, M._nsID.io, 15, -1,
                                     {sign_text = "i", id = M._extID.regex})
    end

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

    -- Set a local keymap for getting the color codes of highlights in the demo
    -- buffer
    vim.keymap.set(
        "n",
        "K",
        function() require("colorscheme-extender").getColorUnderCursor() end,
        {silent = true, buffer = M._demoBufNum}
    )

    -- Register a callback for InsertLeave, where the IO buffer is parsed for
    -- differences.
    -- If differences are found, redraw the demo buffer.
    -- If formatting is wrong, then redraw the IO buffer.
    vim.api.nvim_create_autocmd( {"InsertLeave"},
        {
            callback = function ()
                local shouldUpdateBuffer = false
                local shouldUpdateRegex = false
                -- Check for improper formatting, which is when the extmarks
                -- are no longer in the right rows. If found, reformat the IO
                -- buffer with the last known settings.

                local textRet = vim.api.nvim_buf_get_extmark_by_id(
                    M._ioBufNum,
                    M._nsID.io,
                    M._extID.text,
                    {details = false, hl_name = false}
                )
                local indentRet = vim.api.nvim_buf_get_extmark_by_id(
                    M._ioBufNum,
                    M._nsID.io,
                    M._extID.indent,
                    {details = false, hl_name = false}
                )
                local lineWidthRet = vim.api.nvim_buf_get_extmark_by_id(
                    M._ioBufNum,
                    M._nsID.io,
                    M._extID.lineWidth,
                    {details = false, hl_name = false}
                )
                local regexRet = vim.api.nvim_buf_get_extmark_by_id(
                    M._ioBufNum,
                    M._nsID.io,
                    M._extID.regex,
                    {details = false, hl_name = false}
                )

                if textRet[1] ~= 6 then
                    M._setIOBuffer(M._text, M._indent, M._lineWidth, M._pattern)
                    return
                end

                if indentRet[1] ~= 9 then
                    M._setIOBuffer(M._text, M._indent, M._lineWidth, M._pattern)
                    return
                end

                if lineWidthRet[1] ~= 12 then
                    M._setIOBuffer(M._text, M._indent, M._lineWidth, M._pattern)
                    return
                end

                if regexRet[1] ~= 15 then
                    M._setIOBuffer(M._text, M._indent, M._lineWidth, M._pattern)
                    return
                end

                -- Getting here means that there are no multiline inputs.
                -- We can now parse each input line for setting changes
                -- Get the line for textInput
                local textIn      = vim.api.nvim_buf_get_lines(M._ioBufNum, 6,
                                                               7, true)
                local indentIn    = vim.api.nvim_buf_get_lines(M._ioBufNum, 9,
                                                               10, true)
                local lineWidthIn = vim.api.nvim_buf_get_lines(M._ioBufNum, 12,
                                                               13, true)
                local regexIn     = vim.api.nvim_buf_get_lines(M._ioBufNum, 15,
                                                               16, true)

                -- If the new input is different from the last one, then we
                -- record that a change is needed, and update the module-wide
                -- variable
                if textIn[1] ~= M._text then
                    shouldUpdateBuffer = true
                    M._text = textIn[1]
                end

                -- TODO: IMPORTANT: You can't just check one by one whether or
                -- not these variables make sense together.
                -- indent + string.len(text) <= textWidth
                -- Because of this, only after parsing all three things can we
                -- check to see if this relationship is fulfilled. If it is
                -- fulfilled, then we update the demo buffer. Otherwise we
                -- revert back to what we had before.

                -- Parse lineWidth first because indent should only be between
                -- 0 and lineWidth - len(text)

                local lineWidthNum = tonumber(lineWidthIn[1])
                -- If the user inputs invalid value (out-of-bounds or alphas),
                if lineWidthNum == nil or
                    lineWidthIn > 1000 or
                    lineWidthNum < (string.len(M._text) + 1) then

                    -- Delete the extmark on that line
                    vim.api.nvim_buf_del_extmark(M._ioBufNum, M._nsID.io,
                                                 M._extID.indent)

                    -- Set the line to the old valid indent number
                    vim.api.nvim_buf_set_lines(
                        M._ioBufNum,
                        9,
                        10,
                        false,
                        {tostring(M._indent)}
                    )

                    -- Add back the deleted extmark
                    -- This is done because the behavior for extmarks when using
                    -- set_lines is undefined
                    vim.api.nvim_buf_set_extmark(M._ioBufNum, M._nsID.io, 9, -1,
                                                 {sign_text = "i"})
                else
                    if indentNum ~= M._indent then
                        shouldUpdateBuffer = true
                        M._indent = indentNum
                    end
                end

                -- Two cases can occur:
                -- 1. The user inputs invalid. Revert back to last valid.
                -- 2. The user inputs valid. Record and update in demo buffer.
                local indentNum = tonumber(indentIn[1])
                -- If the user inputs invalid value (out-of-bounds or alphas),
                if indentNum == nil or indentNum > 100 or indentNum < 0 then
                    -- Delete the extmark on that line
                    vim.api.nvim_buf_del_extmark(M._ioBufNum, M._nsID.io,
                                                 M._extID.indent)

                    -- Set the line to the old valid indent number
                    vim.api.nvim_buf_set_lines(
                        M._ioBufNum,
                        9,
                        10,
                        false,
                        {tostring(M._indent)}
                    )

                    -- Add back the deleted extmark
                    -- This is done because the behavior for extmarks when using
                    -- set_lines is undefined
                    vim.api.nvim_buf_set_extmark(M._ioBufNum, M._nsID.io, 9, -1,
                                                 {sign_text = "i"})
                else
                    if indentNum ~= M._indent then
                        shouldUpdateBuffer = true
                        M._indent = indentNum
                    end
                end

                -- TODO: add lineWidth handling

                -- TODO: add regex updates

                if shouldUpdateBuffer then
                    print("redraw!\n")
                    M._setDemoBuffer(M._text, M._indent, M._lineWidth)
                    vim.api.nvim_set_current_win(M._ioWinNum)
                end

            end,
            buffer = M._ioBufNum,
        }
    )
end

-- On setup, create a new command for users to call
function M.setup()
    vim.api.nvim_create_user_command(
        "ColorschemeExtend",
        function () require("colorscheme-extender").start("hello", 2, 80,
                                                          "^DevIcon") end,
        {}
    )
end

return M
