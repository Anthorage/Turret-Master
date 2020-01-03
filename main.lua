
local function create_weapon(id, ammo, cooldown, speed, damage)
  local weap = {id=id, ammo=ammo, reload=cooldown, cd=cooldown, speed=reference_dist*1.5, damage=damage}
  
  weap.quad = love.graphics.newQuad(graphic_size*(id-1), graphic_size, graphic_size, graphic_size, texture_size.w, texture_size.h)
  
  return weap
end


local function create_enemy_type(id, life, damage, speed)
  local ret = { id=id,life=life,damage=damage,speed=speed }
  
  ret.quad = love.graphics.newQuad( id*graphic_size, 0, graphic_size, graphic_size, texture_size.w, texture_size.h)
  
  return ret
end

--=====================================================

tutorial = true

local function reload()
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  
  sounds = { collect = love.audio.newSource("powerup.wav", "static") }
  sounds.laser = love.audio.newSource("laser.wav", "static")
  sounds.hurt = love.audio.newSource("hurt.wav", "static")
  sounds.explosion = love.audio.newSource("explosion.wav", "static")
  sounds.flame = love.audio.newSource("flame.wav", "static")
  sounds.railgun = love.audio.newSource("secgun.wav", "static")
  
  sounds.laser:setVolume(0.5)
  
  sidebar = {w=162, h=height}
  bottombar = {w=width-sidebar.w*2, h=118}
  area = {x=sidebar.w,y=0,w=width-sidebar.w*2,h=height-bottombar.h}
  
  texture = love.graphics.newImage("graphics.png")
  texture:setFilter("nearest", "nearest")
  texture_size = {w=texture:getWidth(), h=texture:getHeight()}
  
  enemies = {}
  bullets = {}
  crates = {}
  
  LASER = 1
  MISSILE = 2
  RAILGUN = 3
  FLAMETHROWER = 4
  
  reference_dist = 128
  graphic_size = 16
  
  score = 0
  
  score_per_enemy = 25
  score_per_crate = 50
  
  player = {shields = 15, max_shields=15, fuel=1000, max_fuel=1000, sx=16, sy=16, speed=reference_dist*1.5 }
  player.laser = create_weapon(LASER, 50, 0.075, reference_dist*1.7, 1)
  player.laser.recharge=0.3
  player.laser.rechargemax=0.25
  player.laser.max_ammo = 150
  
  player.missiles = create_weapon(MISSILE, 0, 1, reference_dist*1.5, 30)
  player.missiles.name = "MISSILE"
  
  player.railgun = create_weapon(RAILGUN, 0, 0.25, reference_dist*2, 10)
  player.railgun.name = "RAILGUN"
  
  player.flamethrower = {}
  player.x = area.x+area.w/2
  player.y = area.y+area.h-player.sy*4
  player.quad = love.graphics.newQuad(0,0,player.sx,player.sy,texture_size.w, texture_size.h)
  
  bulletquads = { player.laser.quad, player.missiles.quad, player.railgun.quad, nil }
  
  started = false
  starts_in = 5.0
  
  flamethrower_damage = 12


  levels = {time = 25.0, maxtime = 25.0, current=0, max_level = 5}

  enemy_spawn = { maxtime = 3, time = 3, mintime = 1.8, reduc=(3-1.8)/levels.max_level, level=1 }

  crate_spawn = { maxtime=4.25, time=4.25, mintime=2.8, reduc=(4.25-2.8)/levels.max_level }
  
  enemy_types = {}
  table.insert(enemy_types, create_enemy_type(1, 6, 1, reference_dist*0.75))
  table.insert(enemy_types, create_enemy_type(2, 12, 3, reference_dist*0.8))
  table.insert(enemy_types, create_enemy_type(3, 25, 8, reference_dist*0.6))
  
  
  starts_font = love.graphics.newFont(24)
  starfield = {image=love.graphics.newCanvas(area.w, area.h), scroll=area.h}
  
  love.graphics.setLineStyle("rough")
  
  love.graphics.setCanvas(starfield.image)
    for x=0, 2000 do
      love.graphics.points(love.math.random(area.w), love.math.random(area.h) )
    end
  love.graphics.setCanvas()

  love.graphics.setColor( 255, 255, 255, 255 )
  
  player.flamethrower.ps = love.graphics.newParticleSystem(texture, 72)
  player.flamethrower.ps:setParticleLifetime(1,1.8)
  player.flamethrower.ps:setSizeVariation(1)
  player.flamethrower.ps:setLinearAcceleration(-25, -60, 25, -45)
  player.flamethrower.ps:setColors(255, 255, 255, 255, 255, 255, 255, 0)
  player.flamethrower.ps:setSpeed(-5, 5)
  
  player.flamethrower.quad = love.graphics.newQuad(48, 16, 16, 16, texture_size.w, texture_size.h)
  
  player.flamethrower.ps:setQuads(player.flamethrower.quad)
  
  player.flamethrower.used = false
  
  total_crates = 3
  
  game_zoom = 3
end

--=====================================================

local function set_shields(shields)
  player.shields = math.min(shields, player.max_shields)

  return player.shields
end


local function set_fuel(fuel)
  player.fuel = math.max(0, math.min(fuel, player.max_fuel))

  return player.fuel
end


local function set_ammo(weap, ammo)
  weap.ammo = math.max(0, math.min(ammo, weap.max_ammo or ammo))

  return weap.ammo
end

--=====================================================

function create_crate()
  local crate = { id = love.math.random(total_crates+1), x=area.x+graphic_size*2 + love.math.random(area.w-graphic_size*4), y=area.y }
  crate.quad = love.graphics.newQuad((crate.id-1)*graphic_size, 32, graphic_size, graphic_size, texture_size.w, texture_size.h)
  
  table.insert(crates, crate)
  
  --print(crate.id)
  
  return crate
end


function create_bullet(bid, x, y, speed, damage, playerbullet)
  local bullet = { id=bid, x=x, y=y, speed=speed, fromplayer = playerbullet, damage=damage }
  table.insert(bullets, bullet)
  
  if playerbullet then
    bullet.speed = -bullet.speed
  end
  
  return bullet
end


function create_enemy()
  local id = love.math.random(enemy_spawn.level)
  local enemytype = enemy_types[id]
  local enemy = { id=id, x=area.x+player.sx*2+love.math.random(area.w-player.sx*4), y=area.y }
  local gps = graphic_size
  
  enemy.quad = enemytype.quad --love.graphics.newQuad(gps * (love.math.random(2)),0,gps,gps,texture_size.w,texture_size.h)
  
  enemy.damage = enemytype.damage or 1
  enemy.life = enemytype.life or 6
  enemy.speed = enemytype.speed or reference_dist * 0.75
  
  table.insert(enemies, enemy)
  return enemy
end

local function spawn_crate(dt)
  crate_spawn.time = crate_spawn.time - dt

  if crate_spawn.time <= 0 then
    crate_spawn.time = crate_spawn.maxtime
    create_crate()
  end
end

local function spawn_enemies(dt)
  enemy_spawn.time = enemy_spawn.time - dt
  
  if enemy_spawn.time <= 0 then
    enemy_spawn.time = enemy_spawn.maxtime
    create_enemy()
  end
end

--=====================================================
     
function update_weapons(dt)
  local flameconsumption = 50

  player.flamethrower.used = false
  player.flamethrower.ps:update(dt)
  
  if player.laser.cd >= 0 then
    player.laser.cd = player.laser.cd - dt
  end
  
  if player.weapon and player.weapon.cd >= 0 then
    player.weapon.cd = player.weapon.cd - dt
  end
  
  if love.keyboard.isDown("z") and player.laser.ammo > 0 then
    if player.laser.cd <= 0 then
      love.audio.play(sounds.laser)
      create_bullet(LASER, player.x, player.y-player.sy, player.laser.speed, player.laser.damage, true)
      set_ammo(player.laser, player.laser.ammo - 1)
      player.laser.cd = player.laser.reload
    end
  elseif love.keyboard.isDown("x") and player.weapon and player.weapon.ammo > 0 then
    if player.weapon.cd <= 0 then
      create_bullet(player.weapon.id, player.x, player.y-player.sy, player.weapon.speed, player.weapon.damage, true)
      set_ammo(player.weapon, player.weapon.ammo - 1)
      player.weapon.cd = player.weapon.reload
      
      if player.weapon.id == RAILGUN then
        love.audio.play(sounds.railgun)
      elseif player.weapon.id == MISSILE then
        love.audio.play(sounds.flame)
      end
    end
  elseif love.keyboard.isDown("c") and player.fuel-flameconsumption*dt >= 0 then
    player.flamethrower.used = true
  end
  
  if player.flamethrower.used then
    player.flamethrower.ps:setEmissionRate(36)
    set_fuel(player.fuel - flameconsumption*dt)
    --love.audio.play(sounds.flame)
    sounds.flame:play()
    
    for _, ene in ipairs(enemies) do
      local rx, ry = player.x-player.sx*2, player.y-player.sy*(game_zoom+2)
      local rx2, ry2 = player.x+player.sy*2, player.y-player.sy
      
      if ene.x > rx and ene.y > ry and ene.x < rx2 and ene.y < ry2 then
        ene.life = ene.life - flamethrower_damage*dt
      end
    end
    
  else
    player.flamethrower.ps:setEmissionRate(0)
  end
  
  if player.laser.recharge <= 0 then
    player.laser.recharge = player.laser.rechargemax
    set_ammo(player.laser, player.laser.ammo + 1)
  else
    player.laser.recharge = player.laser.recharge - dt
  end
  
end

--=====================================================

local function get_distance(x1,y1,x2,y2)
  return math.abs(x2-x1)+math.abs(y2-y1)
end

--=====================================================

local function move_player(x, y, fuel)
  local zoom = 3
  local adx = (player.sx/2) * zoom
  local ady = (player.sx/2) * zoom
  
  if player.fuel >= fuel then
    
    if player.x+x-adx > area.x and player.x+x+adx < area.x+area.w then
      player.x = player.x + x
    end
    
    if player.y+y-ady > area.y and player.y+y+ady < area.y+area.h then
      player.y = player.y + y
    end
    
    set_fuel(player.fuel-fuel)
  end
end


local function movement(dt)
  local speed = player.speed --reference_dist*1.5
  local fuellost = 50*dt
    
  local mx = nil
  local my = nil
  
  if love.keyboard.isDown("space", "v") then
    speed = speed * 1.5
    fuellost = fuellost*1.5
  end

  starfield.scroll = (starfield.scroll - 30*dt)

  if starfield.scroll <= 0 then
    starfield.scroll = area.h
  end
  
  if love.keyboard.isDown("up") then
    my = -speed*dt
  elseif love.keyboard.isDown("down") then
    my = speed*dt
  end
  
  if love.keyboard.isDown("left") then
    mx = -speed*dt
  elseif love.keyboard.isDown("right") then
    mx = speed*dt
  end

  if mx or my then
    if mx and my then
      mx = mx * 0.7
      my = my * 0.7
      fuellost = fuellost * 1.4
    end
    move_player(mx or 0, my or 0, fuellost)
  end
end

--=====================================================

local function collect_crate(crate)
  love.audio.play(sounds.collect)
  score = score + score_per_crate
  
  if crate.id == LASER then
    --player.laser.ammo = player.laser.ammo + 50
    set_ammo(player.laser, player.laser.ammo+40)
  elseif crate.id == MISSILE then
    local ammo = 2
    
    if player.weapon and player.weapon.id == MISSILE then
      ammo = player.weapon.ammo+1
    else
      player.weapon = player.missiles
      player.weapon.cd = 0
    end
    
    set_ammo(player.weapon, ammo)
  elseif crate.id == RAILGUN then
    local ammo = 5
    
    if player.weapon and player.weapon.id == RAILGUN then
      ammo = player.weapon.ammo+4
    else
      player.weapon = player.railgun
      player.weapon.cd = 0
    end
    
    
    set_ammo(player.weapon, ammo)
  elseif crate.id == FLAMETHROWER then
    set_fuel(player.fuel + 150)
  end
  
end


function update_game(dt)
  player.fuel = math.min(player.fuel + 25 * dt, player.max_fuel)
  
  movement(dt)
  
  update_weapons(dt)
  
  spawn_enemies(dt)
  
  spawn_crate(dt)
  
  if player.weapon and player.weapon.ammo <= 0 then
    player.weapon = nil
  end

  
  for i = #crates, 1, -1 do
    local crate = crates[i]
    
    crate.y = crate.y + reference_dist*dt
    
    if get_distance(crate.x, crate.y, player.x, player.y) < player.sx*game_zoom then
      collect_crate(crate)
      table.remove(crates, i)
    end
    
  end
  
  for i = #bullets, 1, -1 do
    local crashed = false
    
    local bull = bullets[i]
    bull.y = bull.y + bull.speed*dt
    
    for _, ene in ipairs(enemies) do
      if get_distance(ene.x, ene.y, bull.x, bull.y) <= graphic_size then
        crashed = true
        
        ene.life = ene.life - bull.damage
        
        break
      end
    end
    
    if bull.y > area.h or bull.y < 0 or crashed then
      table.remove(bullets, i)
      
      if bull.id == MISSILE then
        love.audio.play(sounds.explosion)
      end
      
    end
  end
  
  for i = #enemies, 1, -1 do
    local ene = enemies[i]
    local touchesplayer = get_distance(ene.x, ene.y, player.x, player.y) <= player.sx*2
    ene.y = ene.y + ene.speed * dt
    local dead = false
    
    if touchesplayer then
      love.audio.play(sounds.hurt)
      dead=true
    elseif ene.life <= 0 then
      score = score + score_per_enemy
      dead = true
    elseif ene.y >= area.h then
      dead = true
    end

    if dead then
      table.remove(enemies, i)
      if ene.life > 0 then
        player.shields = player.shields - ene.damage
      end
    end
  end
  

  if levels.time <= 0 then
    levels.time = levels.maxtime
    levels.current = levels.current + 1

    enemy_spawn.maxtime = enemy_spawn.maxtime - enemy_spawn.reduc
    crate_spawn.maxtime = crate_spawn.maxtime - crate_spawn.reduc

    if levels.current == 3 then
      enemy_spawn.level = 2
    elseif levels.current == 5 then
      enemy_spawn.level = 3
    end

  elseif levels.current < levels.max_level then
    levels.time = levels.time - dt
  end

end

function love.update(dt)
  if started then
    
    update_game(dt)
    
    if player.shields <= 0 then
      reload()
    end
  else
    if not tutorial then
      starts_in = starts_in - dt
      
      if starts_in <= 0 then
        started = true
      end
    else
      if love.keyboard.isDown("space") then
        started=true
        tutorial = false
      end

    end
  end
end

--=====================================================


function draw_ui(x,y,w,h)
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local default_font = love.graphics.getFont()
  
  -- FILLING
  love.graphics.setColor(128, 0, 128, 255)
  local shieldhei = sidebar.h * (player.shields/player.max_shields)
  local fuelhei = sidebar.h * (player.fuel/player.max_fuel)
  love.graphics.rectangle("fill", 0, sidebar.h-shieldhei, sidebar.w, shieldhei)
  love.graphics.setColor(128, 128, 0, 255)
  love.graphics.rectangle("fill", width-sidebar.w, sidebar.h-fuelhei, sidebar.w, fuelhei)
  
  love.graphics.setColor(255, 255, 255, 255)
  
  -- UI
  love.graphics.rectangle("line", 0, 0, sidebar.w, sidebar.h)
  
  love.graphics.rectangle("line", width-sidebar.w, 0, sidebar.w, sidebar.h)
  
  love.graphics.rectangle("line", area.x, area.y, area.w, area.h)
  love.graphics.rectangle("line", area.x, area.y+area.h, bottombar.w/2, bottombar.h)
  love.graphics.rectangle("line", area.x + bottombar.w/2, area.y+area.h, bottombar.w/2, bottombar.h)
  
  -- Primary weapon
  local lasertext = "LASER: "..player.laser.ammo
  local yweap = area.y+area.h+bottombar.h/2
  love.graphics.setFont(starts_font)
  love.graphics.print(lasertext,area.x+bottombar.w/4,yweap,0,1,1,starts_font:getWidth(lasertext)/2,starts_font:getHeight()/2)
  
  if player.weapon then
    local weaptext = player.weapon.name..":" ..player.weapon.ammo
    love.graphics.print(weaptext,area.x+bottombar.w*0.75,yweap,0,1,1,starts_font:getWidth(weaptext)/2,starts_font:getHeight()/2)
  else
    local weaptext = "NONE"
    love.graphics.print(weaptext,area.x+bottombar.w*0.75,yweap,0,1,1,starts_font:getWidth(weaptext)/2,starts_font:getHeight()/2)
  end
  
  love.graphics.setFont(default_font)
end


function draw_game()
  local fscroll = math.floor(starfield.scroll)
  local quad1 = love.graphics.newQuad(0, fscroll, area.w, area.h-fscroll, area.w, area.h)
  local quad2 = love.graphics.newQuad(0, 0, area.w, fscroll, area.w, area.h)
  
  local default_font = love.graphics.getFont()
  
  local sctext = "Score " .. score
  
  love.graphics.draw(starfield.image, quad1, area.x, area.y)
  love.graphics.draw(starfield.image, quad2, area.x, area.y+area.h-fscroll)
  
  love.graphics.draw(texture,player.quad,player.x,player.y,0,game_zoom,game_zoom,8,8)
  
  for _, cra in ipairs(crates) do
    love.graphics.draw(texture, cra.quad, cra.x, cra.y, 0, game_zoom, game_zoom, 8, 8)
  end
  
  for _, ene in ipairs(enemies) do
    love.graphics.draw(texture, ene.quad, ene.x, ene.y, 3.1416, game_zoom, game_zoom, 8, 8)
  end
  
  for _, bull in ipairs(bullets) do
    local angle = bull.speed>0 and 3.14 or 0
    love.graphics.draw(texture, bulletquads[bull.id], bull.x, bull.y, angle, game_zoom, game_zoom, 8, 8)
  end
  
  love.graphics.draw(player.flamethrower.ps, player.x + 30, player.y-player.sy*1.5, 0, 2, 2)

  love.graphics.setFont(starts_font)
  love.graphics.print(sctext, area.x+area.w/2, area.y, 0, 1, 1, starts_font:getWidth(sctext)/2, 0)
  love.graphics.setFont(default_font)
end


function love.draw()
  local default_font = love.graphics.getFont()
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  
  love.graphics.setLineStyle("rough")

  draw_ui()

  if not started then
    local px = area.x+area.w/2
    local py = area.y+area.h/5
    local text = "GAME STARTS IN " .. math.floor(starts_in+1)
    
    love.graphics.setFont(starts_font)
    if not tutorial then
      love.graphics.print(text, px, py, 0, 1, 1, starts_font:getWidth(text)/2, starts_font:getHeight()/2)
    end
      text = "Laser [Z]\nSecondary Weapon [X]\nFlamethrower [hold C]\nTurbo Speed [hold V / SPACEBAR]\nMove [ARROW KEYS]\n"..
      "Health to the left, Fuel to the right, Ammo in the lower part of the screen.\n"..
      "If enemies touch you or get through the line you will be damaged."
      if tutorial then
        text = text .. "\nPRESS SPACEBAR TO START"
      end
      love.graphics.printf(text, area.x, area.y+area.h/3, area.w, "center")
    love.graphics.setFont(default_font)
  else
    love.graphics.setScissor(area.x, area.y, area.w, area.h)
    
    draw_game()
    
    love.graphics.setScissor()
  end
  
end

--=====================================================

function love.load(arg)
  love.mouse.setVisible(false)
  reload()
end
