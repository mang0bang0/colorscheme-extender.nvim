local M = {}

-- Function that constructs a demo line in the buffer
-- entry is the string of each entry, indent is an integer that's the number of
-- spaces before the text, and entriesPerLine is the number of entries on this
-- line
function M._constructLine(entry, indent, numOfEntriesInLine)
    local lineText = ""

    -- First add the indents in the beginning
    for _ = 1, indent do
        lineText = lineText .. " "
    end

    -- Then add the entries after
    for i = 1, numOfEntriesInLine do
        lineText = lineText .. entry
        if i < numOfEntriesInLine then
            lineText = lineText .. " "
        end
    end

    return lineText
end

-- Function to convert RRGGBB into a table of HSV
-- Takes RRGGBB (hex now represented as decimal)
-- Returns nil if nil is passed in, otherwise a table that looks like:
-- {h = h, s = s, v = v}
function M._RGBToHSV(rrggbb)
    -- If nothing is passed in, return nothing.
    -- This is used because the function that calls this one can pass in nil
    -- values and expects nil in return
    if rrggbb == nil then
        return nil
    end

    local r = math.floor(rrggbb / 65536)
    rrggbb = rrggbb - r * 65536
    local g = math.floor(rrggbb / 256)
    rrggbb = rrggbb - g * 256
    local b = rrggbb

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

    return {h = h, s = s, v = v}
end

-- Function to find the fg and bg HSV of a highlight group
-- Parameter is a highlight group table
-- Returns a table that looks like this:
--[[
    {
        fg = {h = h, s = s, v = v},
        bg = {h = h, s = s, v = v}
    }
    Note that fg or bg can be equal to nil
--]]
function M._getHSV(color)
    -- Get separate HSV values as a table. Can be nil if say colors.bg doesn't
    -- exist
    local fgHSV = M._RGBToHSV(color.fg)
    local bgHSV = M._RGBToHSV(color.bg)

    return {fg = fgHSV, bg = bgHSV}
end

-- Compares two HSV values one and two
-- Returns "<", "=", or ">"
function M._compareHSV(one, two)
    -- If the two H values are different, then we just compare
    if one.h < two.h then
        return "<"
    elseif one.h > two.h then
        return ">"
    -- Otherwise if H are the same, we compare the S values
    else
        if one.s < two.s then
            return "<"
        elseif one.s > two.s then
            return ">"
        else
            if one.v < two.v then
                return "<"
            elseif one.v > two.v then
                return ">"
            else
                return "="
            end
        end
    end
end

-- Function that compares two color entries in the color table.
-- Takes two color table entires, returns true if the first color is
-- lower on the HSV scale
function M._HSVSort(one, two)
    -- These two variables have this structure:
    --[[
    {
        fg = { h = h, s = s, v = v },
        bg = { h = h, s = s, v = v }
    }
    ]]--
    -- Note that fg or bg can equal nil if this highlight group doesn't have fg
    -- or bg defined

    local oneHSV = M._getHSV(one)
    local twoHSV = M._getHSV(two)
    local compResult

    -- If bg exists, we compare it first
    if oneHSV.bg then
        compResult = M._compareHSV(oneHSV.bg, twoHSV.bg)

        if compResult == "<" then
            return true
        elseif compResult == ">" then
            return false
        -- If the bgs are the same, check if fg is defined. If it is, then
        -- compare the fgs, otherwise return name order (needed for Lua) so that
        -- going one way is true, going the other way has to be false, even if
        -- they're the same and doesn't matter. This assumes all highlight
        -- groups have different names (not unreasonable)
        else
            if oneHSV.fg then
                compResult = M._compareHSV(oneHSV.fg, twoHSV.fg)

                if compResult == "<" then
                    return true
                elseif compResult == ">" then
                    return false
                else
                    return one.name < two.name
                end
            else
                return one.name < two.name
            end
        end
    -- Otherwise we compare bg or fg, whichever exists
    else
        compResult = M._compareHSV(oneHSV.fg, twoHSV.fg)

        if compResult == "<"  then
            return true
        elseif compResult == ">" then
            return false
        else
            return one.name < two.name
        end
    end
end

function M._removeDuplicates(tab)
    local prev = tab[#tab]
    local first = true

    for i = #tab, 1, -1 do
        if not first then
            if prev.fg == tab[i].fg and prev.bg == tab[i].bg then
                table.remove(tab, i)
            else
                prev = tab[i]
            end
        end

        first = false
    end

end

-- Fills out a colors table, filtering out highlights with names that match
-- the vim regex pattern
-- Returns all the highlights from vim.api.nvim_get_hl(), and a color table
-- containing the fg table, bg table, and fgbg table
function M._getHighlights(pattern)
    -- Get a table of the highlights of the current colorscheme
    local highlights = vim.api.nvim_get_hl(0, {})
    local colors = {{}, {}, {}}

    -- Three tables would be used for the three kinds of highlights: fg only, bg
    -- only, and fg and background. The reason is because the user is probably
    -- only looking for one of these three types. It doesn't make sense to mix
    -- them when displaying in our buffer.

    -- Construct the three tables from the global highlight table, checking if
    -- the user provided regex matches. If there is a match, it is not added!
    -- Note that it does not completely remove that color, it only excludes
    -- highlight groups with that name
    for k,v in pairs(highlights) do
        if not (pattern and vim.regex(pattern):match_str(k)) then
            if v.fg and v.bg then
                table.insert(colors[3], {name = k, fg = v.fg, bg = v.bg})
            elseif v.fg then
                table.insert(colors[1], {name = k, fg = v.fg})
            elseif v.bg then
                table.insert(colors[2], {name = k, bg = v.bg})
            end
        else
            print("Filtered " .. k .. "\n")
        end
    end

    -- Sort the three tables based on HSV
    table.sort(colors[1], M._HSVSort)
    table.sort(colors[2], M._HSVSort)
    table.sort(colors[3], M._HSVSort)

    -- Remove duplicate entriers for the three tables
    M._removeDuplicates(colors[1])
    M._removeDuplicates(colors[2])
    M._removeDuplicates(colors[3])

    return highlights, colors
end

return M
