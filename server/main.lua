local socket = require('socket')

local server
local address, port = '*', 8172

local client

function love.load()
  server = socket.bind(address, port)
end

function love.update()
  if not client then
    local i, p = server:getsockname()
    print('Awaiting connection for ' .. i .. ':' .. p .. '...')

    local err
    client, err = server:accept()
    client:settimeout(0)
    print(client, err)
  end

  if client then
    local msg, err = client:receive()

    if not msg and err == 'closed' then
      --Conection closed
      client = nil
    elseif msg then
      print(msg, err)
    end
  end
end

function love.keypressed()
  client:send('INIT\n')
end
