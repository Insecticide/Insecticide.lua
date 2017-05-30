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

-- These are the commands the client can receive from the server.
local DEBUG_COMMANDS = {
  INIT = 'INIT',
  STEPIN = 'STEPIN',
  GETSTACK = 'GETSTACK',
  GETVARIABLES = 'GETVARIABLES'
}

-- ------------------------------------------------
-- Local Variables
-- ------------------------------------------------

local client

-- ------------------------------------------------
-- Local Functions
-- ------------------------------------------------

local function send(txt)
  local bytes, err = client:send(txt) --Without the newline the message never ends

  if not bytes and err == 'closed' then
    print('Closing connection')
    client = nil
  elseif bytes then
    print('Message sent: ' .. bytes ..'bytes.')
  else
    print('Error sending message: ' .. err)
  end
end

---
-- This function will wait for a message from the server with instructions on
-- how to proceed.
--
local function receive()
  local msg, err
  while true do
    msg, err = client:receive()
    print(msg, err)

    -- TODO Error handling.
    if msg then
      break
    end
  end
  return msg
end

---
-- @tparam string event The type of event the hook receives ('call', 'tail call', 'return', 'line', 'count').
-- @tparam number line  The new line number for line events.
--
local function hook(event, line)
  local msg = receive()
  print('Instructions received: ' .. msg)

  if msg == DEBUG_COMMANDS.INIT then
    local path = debug.getinfo(1, "S").source
    path = Cereal.sanitizeString(path)

    send(string.format('OK,%s,%s\n', config.id, path))
  end

  if event == DEBUG_EVENTS.CALL then
    local ser = Cereal.serializeScope(4)
    send(ser .. '\n')
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

---
-- Tries to require the lua-socket module and connect to a server with the
-- given address and port number.
-- @tparam string address The ip address to connect to.
-- @tparam number port    The port number to connect to.
-- @treturn client        The TCP client object connected to the server.
--
local function connectToServer(address, port)
  local ok, socket = pcall(require, 'socket')

  -- Fail if socket can't be found on the user's system.
  if not ok then
    error('Required socket module not found. ' .. socket)
  end

  print('Trying to connect to ' .. address .. ':' .. port .. '...')

  local tclient
  while not tclient do
    local err
    tclient, err = socket.connect(address, port)
    if not tclient then
      print('Error: ', err)
      tclient = nil
    end
  end

  print('Connected! Starting to send beeps and boops...')
  return tclient
end

-- ------------------------------------------------
-- Public Functions
-- ------------------------------------------------

function Insecticide.activate()
  client = connectToServer(config.address, config.port)
end

-- This is just for testing... we need to hook into the program to debug later on.
function Insecticide.start()
  if not client then
    print('No active client found. Aborting...')
    return
  end

  debug.sethook(hook, DEBUG_HOOK_MASK)
end

return Insecticide
