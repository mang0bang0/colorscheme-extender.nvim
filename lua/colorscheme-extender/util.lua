local M = {}

-- Function to convert the RRGGBB value returned by nvim API to separate R, G, B
-- Takes RRGGBB (hex now represented as decimal)
function M.getRGB(rgb)
    local r = math.floor(rgb / 65536)
    rgb = rgb - r * 65536
    local g = math.floor(rgb / 256)
    rgb = rgb - g * 256
    local b = rgb

    return r, g, b
end

-- Function to Convert sRGB to HSV
-- Takes the decimal of RRGGBB as an argument
function M.RGBToHSV(rgb)
    -- Get separate R, G, and B values
    local r, g, b = M.getRGB(rgb)

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

-- Function that compares two RGB values based on which has the smaller HSV
-- Takes two RRGGBB values, returns true if the first is smaller in HSV than
-- the second
function M.HSVCompare(one, two)
    local oneH, oneS, oneV
    local twoH, twoS, twoV

    if one["fg"] then
        oneH, oneS, oneV = M.RGBToHSV(one["fg"])
        twoH, twoS, twoV = M.RGBToHSV(two["fg"])
    else
        oneH, oneS, oneV = M.RGBToHSV(one["bg"])
        twoH, twoS, twoV = M.RGBToHSV(two["bg"])
    end

    if oneH < twoH then
        return true
    elseif oneH > twoH then
        return false
    else
        if oneS < twoS then
            return true
        elseif oneS > twoS then
            return false
        else
            if oneV < twoV then
                return true
            else
                return false
            end
        end
    end
end

function M.removeDuplicates(tab)
    print("--------------")

    local prev = tab[#tab]
    local first = true

    for i=#tab, 1, -1 do
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

return M
