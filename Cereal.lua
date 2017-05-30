---
-- Cereal serializes the Lua environment based on a specific protocol.
--    (1) There are four reference identifiers:
--      G - global
--      L - local
--      U - upvalue
--      A - argument
--    (2) The key value pairs for each reference are written between grave accents(``).
--    (3) Keys and values are marked by a prefix of one of the following types:
--      S@ - string
--      N@ - number
--      F@ - function
--      U@ - nil / undefined
--      D@ - userdata
--      T@ - table
--      M@ - metatable
--      B@ - boolean
--
--    Example
--      Lua:    bar = { hello = 'world' }
--      Cereal: G`S@bar=T@foo`foo`S@hello=S@world`
--
-- @module Cereal
--

-- ------------------------------------------------
-- Module
-- ------------------------------------------------

local Cereal = {}

-- ------------------------------------------------
-- Constants
-- ------------------------------------------------

local SCOPE_IDENTIFIERS = {
  GLOBAL   = 'G',
  LOCAL    = 'L',
  UPVALUE  = 'U',
  ARGUMENT = 'A',
}

local TYPE_IDENTIFIERS = {
  ['string'  ] = 'S',
  ['number'  ] = 'N',
  ['function'] = 'F',
  ['nil'     ] = 'U',
  ['userdata'] = 'D',
  ['table'   ] = 'T',
  ['boolean' ] = 'B',
  ['thread'  ] = 'C'
}

local KEY_VALUE_PAIR = '%s@%s=%s@%s,'
local ID_TABLE = '%s`%s`'

-- ------------------------------------------------
-- Local Functions
-- ------------------------------------------------

local function asciicode(c)
  return ('$%.2X'):format(c:byte())
end

local function sanitizeString(str)
    return str:gsub('[@`=,%$]', asciicode):gsub('[^\32-\126]', asciicode)
end

local getmeta = debug.getmetatable or getmetatable
local setmeta = debug.setmetatable or setmetatable

local function superToString(obj)
  local oldmeta = getmeta(obj)
  setmeta(obj, nil)
  local result = tostring(obj)
  setmeta(obj, oldmeta)
  return result
end

local serializeTable

local function serializeValue(value, state)
  local typ = type(value)
  if typ == 'table' then
    local identifier

    if state.ids[value] then
      --Use cached identifier
      identifier = state.ids[value]
    else
      --Use hash as identifier
      identifier = sanitizeString(superToString(value))
      state.ids[value] = identifier
    end

    if not state.tables[identifier] then
      state.tables[identifier] = true -- For cyclic tables
      state.tables[identifier] = serializeTable(value, state)
    end

    return TYPE_IDENTIFIERS[typ], identifier
  else
    local vtype = TYPE_IDENTIFIERS[typ] or sanitizeString(typ)
    local vrepr = sanitizeString(tostring(value))

    return vtype, vrepr
  end
end

serializeTable = function(tab, state)
  local tString = ''

  local meta = getmeta(tab)
  if meta then
    local typ, repr = serializeValue(meta, state)
    tString = tString .. KEY_VALUE_PAIR:format('M', 'META', typ, repr)
  end

  for key, val in next, tab do -- Ignores __pairs metamethod
    local ktype, krepr = serializeValue(key, state)
    local vtype, vrepr = serializeValue(val, state)

    tString = tString .. KEY_VALUE_PAIR:format(ktype, krepr, vtype, vrepr)
  end

  return tString
end

local function checkState(state)
  if type(state) ~= 'table' then
    return { ids = {}, tables = {} }
  else
    if type(state.ids) ~= 'table' then
      state.ids = {} -- It could error here
    end
    if type(state.tables) ~= 'table' then
      state.tables = {} -- It could error here
    end

    return state
  end
end

local function getLocals(level)
  local locals = {}
  local i = 1

  while true do
    local name, value = debug.getlocal(level, i)

    if not name then break end

    if string.sub(name, 1, 1) ~= '(' then
      locals[name] = value
    end

    i = i + 1
  end

  return locals
end

local function getArguments(level)
  local arguments = {}
  local i = 1

  while true do
    local name, value = debug.getlocal(level, -i) -- negative indexes

    -- 'not name' should be enough, but LuaJIT 2.0.0 incorrectly reports '(*temporary)' names here
    if not name or name ~= '(*vararg)' then break end

    arguments[name:gsub('%)$',' '..i..')')] = value
    i = i + 1
  end

  return arguments
end

local function getUpvalues(level)
  local upvalues = {}
  local i = 1
  local func = debug.getinfo(level, 'f').func

  while func do -- check for func as it may be nil for tail calls
    local name, value = debug.getupvalue(func, i)

    if not name then break end

    upvalues[name] = value
    i = i + 1
  end

  return upvalues
end

-- ------------------------------------------------
-- Public Functions
-- ------------------------------------------------
function Cereal.serialize(t, name, state)
  if type(name) == 'table' then
    state = name
  end

  state = checkState(state)

  if type(name) == 'string' then
    state.ids[t] = name
  end

  serializeValue(t, state)

  local serialized = ''

  for i, v in pairs(state.tables) do
    serialized = serialized .. string.format(ID_TABLE,i,v)
  end

  return serialized
end

function Cereal.serializeScope(level, state)
  local scope = {
    -- [SCOPE_IDENTIFIERS.GLOBAL  ] = _G, -- Don't serialize Global variables (yet?)
    [SCOPE_IDENTIFIERS.LOCAL   ] = getLocals(level),
    [SCOPE_IDENTIFIERS.ARGUMENT] = getArguments(level),
    [SCOPE_IDENTIFIERS.UPVALUE ] = getUpvalues(level),
  }

  local serialized

  for k, v in pairs(scope) do
    serialized, state = Cereal.serialize(v, k, state)
  end

  return serialized, state
end

return Cereal
