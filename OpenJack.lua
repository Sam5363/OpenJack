local component = require("component")
local event = require("event")
local term = require("term")
local gpu = component.gpu
local computer = require("computer")

local w, h = gpu.getResolution()
if w < 80 or h < 25 then
  term.clear()
  print("This game requires at least 80x25 resolution.")
  return
end

local colors = {
  bg = 0x2C2C2C, fg = 0xDDDDDD, border = 0xFFFFFF,
  value = 0xFFFF44, red = 0xFF4444, black = 0xFFFFFF,
  button = 0x007ACC, win = 0x00FF00, lose = 0xFF0000,
  bar = 0x00FFFF
}

local suits = {"♠", "♥", "♦", "♣"}
local ranks = {"A","2","3","4","5","6","7","8","9","10","J","Q","K"}
local budget, currentBet = 200, 0

local function beep(f, d) computer.beep(f or 1000, d or 0.05) end

local function clear() gpu.setBackground(colors.bg) gpu.setForeground(colors.fg) gpu.fill(1,1,w,h," ") end

local function cardValue(c)
  if c.rank == "A" then return 11
  elseif c.rank == "K" or c.rank == "Q" or c.rank == "J" then return 10
  else return tonumber(c.rank) end
end

local function handValue(hand)
  local total, aces = 0, 0
  for _, c in ipairs(hand) do
    total = total + cardValue(c)
    if c.rank == "A" then aces = aces + 1 end
  end
  while total > 21 and aces > 0 do total = total - 10 aces = aces - 1 end
  return total
end

local function drawCard(x, y, c)
  local isRed = c.suit == "♥" or c.suit == "♦"
  gpu.setBackground(colors.bg)
  gpu.setForeground(colors.border)
  gpu.set(x, y, "╭─────╮")
  gpu.set(x, y+5, "╰─────╯")
  for i = 1, 4 do gpu.set(x, y+i, "│     │") end
  gpu.setForeground(colors.value)
  gpu.set(x+1, y+1, c.rank)
  gpu.set(x+6-#c.rank, y+4, c.rank)
  gpu.setForeground(isRed and colors.red or colors.black)
  gpu.set(x+2, y+2, c.suit)
end

local function drawHand(title, hand, x, y)
  gpu.setForeground(colors.fg)
  gpu.set(x, y-1, title.." ("..handValue(hand).."):")
  for i, c in ipairs(hand) do drawCard(x + (i-1)*8, y, c) end
end

local function drawButtons(state)
  gpu.setBackground(colors.lose)
  gpu.setForeground(0xFFFFFF)
  gpu.set(w-6, 1, "[EXIT]")
  gpu.setBackground(colors.bg)
  gpu.setForeground(colors.fg)
  gpu.fill(1, 22, w, 1, " ")
  gpu.setBackground(colors.button)
  gpu.setForeground(0xFFFFFF)
  if state == "play" then
    gpu.set(2, 22, "[HIT]")
    gpu.set(10, 22, "[STAND]")
  elseif state == "end" then
    gpu.set(20, 22, "[PLAY AGAIN]")
  end
  gpu.setBackground(colors.bg)
  gpu.setForeground(colors.fg)
end

local function waitForClick(state)
  while true do
    local _, _, x, y = event.pull("touch")
    if y == 22 then
      if state == "play" then
        if x >= 2 and x <= 6 then return "hit"
        elseif x >= 10 and x <= 17 then return "stand" end
      elseif state == "end" and x >= 20 and x <= 33 then return "again" end
    elseif y == 1 and x >= w - 6 then return "exit" end
  end
end

local function createDeck()
  local d = {}
  for _, s in ipairs(suits) do for _, r in ipairs(ranks) do table.insert(d, {rank=r, suit=s}) end end
  for i = #d, 2, -1 do local j = math.random(i) d[i], d[j] = d[j], d[i] end
  return d
end

local function askBet()
  clear()
  local x = math.floor(w/2) - 8
  gpu.setForeground(colors.button)
  gpu.set(x, 4, "╔══════════════════╗")
  gpu.set(x, 5, "║     OpenJack     ║")
  gpu.set(x, 6, "╚══════════════════╝")
  gpu.setForeground(colors.bar)
  gpu.set(x, 10, "Your Budget: $" .. budget)
  gpu.setForeground(colors.fg)
  local prompt = "Enter your bet: "
  gpu.set(x, 12, prompt)
  term.setCursor(x + #prompt, 12)
  io.write("")
  local bet = tonumber(io.read())
  return (not bet or bet < 1 or bet > budget) and askBet() or math.floor(bet)
end

local function printResult(msg, color, delta)
  gpu.setForeground(color)
  gpu.set(2, 20, msg)
  if delta then budget = budget + delta end
  beep(delta and (delta > 0 and 1000 or 220) or 440, 0.2)
end

local function game()
  while true do
    budget = 200
    while budget > 0 do
      currentBet = askBet()
      local deck = createDeck()
      local player, dealer = {}, {}
      table.insert(player, table.remove(deck))
      table.insert(dealer, table.remove(deck))
      table.insert(player, table.remove(deck))
      table.insert(dealer, table.remove(deck))

      local pv, dv = handValue(player), handValue(dealer)

      if pv == 21 or dv == 21 then
        clear()
        gpu.setForeground(colors.bar)
        gpu.set(2, 1, "Budget: $" .. budget .. "   Bet: $" .. currentBet)
        drawHand("Dealer", dealer, 2, 3)
        drawHand("Player", player, 2, 11)

        if pv == 21 and dv == 21 then
          printResult("Both have Blackjack. Push (tie).", colors.fg)
        elseif pv == 21 then
          printResult("Blackjack! +$"..currentBet, colors.win, currentBet)
        else
          printResult("Dealer has Blackjack. -$"..currentBet, colors.lose, -currentBet)
        end

        drawButtons("end")
        if waitForClick("end") ~= "again" then return end
        goto continue
      end

      local gameOver = false
      while not gameOver do
        clear()
        gpu.setForeground(colors.bar)
        gpu.set(2, 1, "Budget: $" .. budget .. "   Bet: $" .. currentBet)
        drawHand("Dealer", {dealer[1]}, 2, 3)
        drawHand("Player", player, 2, 11)
        drawButtons("play")
        if handValue(player) > 21 then
          printResult("You busted! Dealer wins.", colors.lose, -currentBet)
          gameOver = true
          break
        end
        local a = waitForClick("play")
        if a == "exit" then return end
        beep(800, 0.05)
        if a == "hit" then table.insert(player, table.remove(deck))
        elseif a == "stand" then break end
      end

      if handValue(player) <= 21 then
        while handValue(dealer) < 17 do table.insert(dealer, table.remove(deck)) end
        clear()
        gpu.setForeground(colors.bar)
        gpu.set(2, 1, "Budget: $" .. budget .. "   Bet: $" .. currentBet)
        drawHand("Dealer", dealer, 2, 3)
        drawHand("Player", player, 2, 11)
        local pv, dv = handValue(player), handValue(dealer)
        if dv > 21 or pv > dv then printResult("You win! +$"..currentBet, colors.win, currentBet)
        elseif dv > pv then printResult("Dealer wins! -$"..currentBet, colors.lose, -currentBet)
        else printResult("Push (tie).", colors.fg) end
      end

      if budget <= 0 then
        gpu.setForeground(colors.lose)
        gpu.set(2, 23, "You're broke! Restarting game...")
        os.sleep(2)
        break
      end

      drawButtons("end")
      local a = waitForClick("end")
      if a == "exit" or a ~= "again" then return end
      ::continue::
    end
  end
end

clear()
game()
