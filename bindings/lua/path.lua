
-- This is a bit of a duplicate of the lib/path.lua module, but we keep it here to keep flecs_wrapper 
-- self-contained and not depend on external lua modules
local M = {}

function M.path_dir()
    local src = debug.getinfo(2, "S").source
    local path = src:sub(1, 1) == "@" and src:sub(2) or "app"
    return path:match("^(.*[/\\])") or "./"
end

function M.normalize_path(path)
    if not path or path == "" then
        return ""
    end

    local original = path
    path = path:gsub("\\", "/")
    path = path:gsub("/+", "/")

    local prefix = ""
    if path:match("^//") then
        prefix = "//"
        path = path:sub(3)
    else
        local drive = path:match("^(%a:)/")
        if drive then
            prefix = drive .. "/"
            path = path:sub(#prefix + 1)
        elseif path:sub(1, 1) == "/" then
            prefix = "/"
            path = path:sub(2)
        end
    end

    local parts = {}
    for part in path:gmatch("[^/]+") do
        if part == "." then
            -- skip
        elseif part == ".." then
            if #parts > 0 and parts[#parts] ~= ".." then
                table.remove(parts)
            elseif prefix == "" then
                parts[#parts + 1] = part
            end
        else
            parts[#parts + 1] = part
        end
    end

    local normalized = prefix .. table.concat(parts, "/")
    local wants_trailing = original:match("[/\\]$") ~= nil
    if wants_trailing and normalized ~= "" and normalized:sub(-1) ~= "/" then
        normalized = normalized .. "/"
    end
    if normalized == "" then
        return prefix ~= "" and prefix or "."
    end
    return normalized
end

return M