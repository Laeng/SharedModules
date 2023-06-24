-- Imported from: https://runescape.wiki/w/Module:Paramtest

--[[
{{Helper module
|name=Paramtest
|fname1 = is_empty(arg)
|ftype1 = String
|fuse1 = Returns true if arg is not defined or contains only whitespace
|fname2 = has_content(arg)
|ftype2 = String
|fuse2 = Returns true if arg exists and does not only contain whitespace
|fname3 = default_to(arg1,arg2)
|ftype3 = String, Any value
|fuse3 = If arg1 exists and does not only contain whitespace, the function returns arg1, otherwise returns arg2
|fname4 = defaults{ {arg1,arg2},...}
|ftype4 = {String, Any value}...
|fuse4 = Does the same as <code>default_to()</code> run over every table passed; for technical reasons, all <code>nil</code> are replaced with <code>false</code>
}}
--]]
--
-- Tests basic properties of parameters
--

local p = {}

--
-- Tests if the parameter is empty, all white space, or undefined
--

function p.is_empty(arg)
    return not string.find(arg or '', '%S')
end

--
-- Returns the parameter if it has any content, the default (2nd param)
--

function p.default_to(arg, default)
    if string.find(arg or '', '%S') then
        return arg
    else
        return default
    end
end

--
-- Returns a list of paramaters if it has any content, or the default
--
function p.defaults(...)
    local ret = {}
    for i, v in ipairs(...) do
        if string.find(v[1] or '', '%S') then
            table.insert(ret,v[1])
        else
            -- or false, because nil is removed
            table.insert(ret,v[2] or false)
        end
    end
    return unpack(ret)
end

--
-- Tests if the parameter has content
-- The same as !is_empty, but this is more readily clear
--

function p.has_content(arg)
    return string.find(arg or '', '%S')
end

--
-- uppercases first letter
--

function p.ucfirst(arg)
    if not arg or arg:len() == 0 then
        return nil
    elseif arg:len() == 1 then
        return arg:upper()
    else
        return arg:sub(1,1):upper() .. arg:sub(2)
    end
end

--
-- uppercases first letter, lowercases everything else
--

function p.ucflc(arg)
    if not arg or arg:len() == 0 then
        return nil
    elseif arg:len() == 1 then
        return arg:upper()
    else
        return arg:sub(1,1):upper() .. arg:sub(2):lower()
    end
end

return p
