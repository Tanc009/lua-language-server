local buildName   = require 'core.hover.name'
local buildArg    = require 'core.hover.arg'
local buildReturn = require 'core.hover.return'
local buildTable  = require 'core.hover.table'
local vm          = require 'vm'
local util        = require 'utility'
local guide       = require 'parser.guide'
local lang        = require 'language'

local function asFunction(source, oop)
    local name = buildName(source, oop)
    local arg  = buildArg(source, oop)
    local rtn  = buildReturn(source)
    local lines = {}
    lines[1] = ('function %s(%s)'):format(name, arg)
    lines[2] = rtn
    return table.concat(lines, '\n')
end

local function asValue(source, title)
    local name    = buildName(source)
    local infers  = vm.getInfers(source)
    local type    = vm.getInferType(source)
    local class   = vm.getClass(source)
    local literal = vm.getInferLiteral(source)
    local cont
    if vm.hasInferType(source, 'table') then
        cont = buildTable(source)
    end
    local pack = {}
    pack[#pack+1] = title
    pack[#pack+1] = name .. ':'
    if cont then
        type = nil
    end
    if class then
        pack[#pack+1] = class
    else
        pack[#pack+1] = type
    end
    if literal then
        pack[#pack+1] = '='
        pack[#pack+1] = literal
    end
    if cont then
        pack[#pack+1] = cont
    end
    return table.concat(pack, ' ')
end

local function asLocal(source)
    return asValue(source, 'local')
end

local function asGlobal(source)
    return asValue(source, 'global')
end

local function asLibrary(source)
    return asValue(source, 'global')
end

local function isGlobalField(source)
    if source.type == 'field'
    or source.type == 'method' then
        source = source.parent
    end
    if source.type == 'setfield'
    or source.type == 'getfield'
    or source.type == 'setmethod'
    or source.type == 'getmethod' then
        local node = source.node
        if node.type == 'setglobal'
        or node.type == 'getglobal' then
            return true
        end
        return isGlobalField(node)
    elseif source.type == 'tablefield' then
        local parent = source.parent
        if parent.type == 'setglobal'
        or parent.type == 'getglobal' then
            return true
        end
        return isGlobalField(parent)
    else
        return false
    end
end

local function asField(source)
    if isGlobalField(source) then
        return asGlobal(source)
    end
    return asValue(source, 'field')
end

local function asString(source)
    local str = source[1]
    if type(str) ~= 'string' then
        return ''
    end
    local len = #str
    local charLen = util.utf8Len(str, 1, -1)
    if len == charLen then
        return lang.script('HOVER_STRING_BYTES', len)
    else
        return lang.script('HOVER_STRING_CHARACTERS', len, charLen)
    end
end

return function (source, oop)
    if source.type == 'function' then
        return asFunction(source, oop)
    elseif source.type == 'local'
    or     source.type == 'getlocal'
    or     source.type == 'setlocal' then
        return asLocal(source)
    elseif source.type == 'setglobal'
    or     source.type == 'getglobal' then
        return asGlobal(source)
    elseif source.type == 'getfield'
    or     source.type == 'setfield'
    or     source.type == 'getmethod'
    or     source.type == 'setmethod'
    or     source.type == 'tablefield'
    or     source.type == 'field'
    or     source.type == 'method' then
        return asField(source)
    elseif source.type == 'string' then
        return asString(source)
    elseif source.type == 'library' then
        return asLibrary(source)
    end
end
