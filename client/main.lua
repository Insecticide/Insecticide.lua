local Insecticide = require('Insecticide')

function love.load()
  Insecticide.activate()

  love.window.close()
end

function love.update()
  Insecticide.start()
end
