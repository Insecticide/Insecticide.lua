-- ------------------------------------------------ --
-- Warning: Do not overwrite the config table in    --
--          this file! It will be overwritten       --
--          manually by the debugger.               --
-- ------------------------------------------------ --

local config = {
  address = 'localhost',
  port = 8172,
  id = '00000001'
}

---
-- @module Insecticide
--

local Cereal = require('Cereal')

-- ------------------------------------------------
-- Module
-- ------------------------------------------------

local Insecticide = {}

-- ------------------------------------------------
-- Constants
-- ------------------------------------------------

-- 'c' hook is called every time Lua calls a function.
-- 'r' hook is called every time Lua returns from a function.
-- 'l' hook is called every time Lua enters a new line of code.
local DEBUG_HOOK_MASK = 'crl'

local DEBUG_EVENTS = {
  CALL      = 'call',
  TAIL_CALL = 'tail call',
  RETURN    = 'return',
  LINE      = 'line',
  COUNT     = 'count'
}

-- 'n' selects fields name and namewhat
-- 'f' selects field func
-- 'S' selects fields source, short_src, what, and linedefined
-- 'l' selects field currentline
-- 'u' selects field nup
local GET_INFO_MASK = 'S'

-- ------------------------------------------------
-- Local Variables
-- ------------------------------------------------

local client

-- ------------------------------------------------
-- Local Functions
-- ------------------------------------------------

---
-- @tparam string event The type of event the hook receives ('call', 'tail call', 'return', 'line', 'count').
-- @tparam number line  The new line number for line events.
--
local function hook(event, line)
  if     event == DEBUG_EVENTS.CALL      then
    for i, v in pairs(debug.getinfo(2, GET_INFO_MASK)) do
      print(i, v)
    end
  elseif event == DEBUG_EVENTS.TAIL_CALL then
    print(event)
  elseif event == DEBUG_EVENTS.RETURN    then
    print(event)
  elseif event == DEBUG_EVENTS.LINE      then
    print(event, line)
  elseif event == DEBUG_EVENTS.COUNT     then
    print(event)
  end
end

local function connectToServer()
  local ok, socket = pcall(require, 'socket')

  -- Fail if socket can't be found on the user's system.
  if not ok then
    error('Required socket module not found. ' .. socket)
  end

  -- Try connecting to the server and transform the master object into a client
  -- object implicitly.
  print('Trying to connect to ' .. config.address .. ':' .. config.port .. '...')

  while not client do
    local err
    client, err = socket.connect(config.address, config.port)
    if not client then
      print('Error: ', err)
      client = nil
    end
  end

  print('Connected! Starting to send beeps and boops...')
end

-- ------------------------------------------------
-- Public Functions
-- ------------------------------------------------

function Insecticide.activate()
  connectToServer()
end

-- This is just for testing... we need to hook into the program to debug later on.
function Insecticide.start()
  if client then
    local ser = Cereal.serializeScope(4)

    local bytes, err = client:send(ser .. '\n') --Without the newline the message never ends

    if not bytes and err == 'closed' then
      print('Closing connection')
      client = nil
    elseif bytes then
      print('Message sent: ' .. bytes ..'bytes.')
    else
      print('Error sending message: ' .. err)
    end
  end
end

return Insecticide
