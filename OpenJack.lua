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
  bg = 0x2C2C2C,
  fg = 0xDDDDDD,
  border = 0xFFFFFF,
  value = 0xFFFF44,
  red = 0xFF4444,
  black = 0xFFFFFF,
  button = 0x007ACC,
  win = 0x00FF00,
  lose = 0xFF0000,
  bar = 0x00FFFF,
}

local suits = {"♠", "♥", "♦", "♣"}
local ranks = {"A","2","3","4","5","6","7","8","9","10","J","Q","K"}

local budget = 200
local currentBet = 0

local function beep(freq, dur)
  computer.beep(freq or 1000, dur or 0.05)
end

local function clearScreen()
  gpu.setBackground(colors.bg)
  gpu.setForeground(colors.fg)
  gpu.fill(1, 1, w, h, " ")
end

local function createDeck()
  local deck = {}
  for _, s in ipairs(suits) do
    for _, r in ipairs(ranks) do
      table.insert(deck, {rank = r, suit = s})
    end
  end
  for i = #deck, 2, -1 do
    local j = math.random(i)
    deck[i], deck[j] = deck[j], deck[i]
  end
  return deck
end

local function cardValue(card)
  if card.rank == "A" then return 11
  elseif card.rank == "K" or card.rank == "Q" or card.rank == "J" then return 10
  else return tonumber(card.rank) end
end

local function handValue(hand)
  local total, aces = 0, 0
  for _, card in ipairs(hand) do
    total = total + cardValue(card)
    if card.rank == "A" then aces = aces + 1 end
  end
  while total > 21 and aces > 0 do
    total = total - 10
    aces = aces - 1
  end
  return total
end

local function drawCard(x, y, card)
  local isRed = (card.suit == "♥" or card.suit == "♦")
  local fgSuit = isRed and colors.red or colors.black

  gpu.setBackground(colors.bg)
  gpu.setForeground(colors.border)
  gpu.set(x, y, "╭─────╮")
  gpu.set(x, y+5, "╰─────╯")
  for i = 1, 4 do gpu.set(x, y+i, "│     │") end

  gpu.setForeground(colors.value)
  gpu.set(x+1, y+1, card.rank)
  gpu.set(x+6 - #card.rank, y+4, card.rank)

  gpu.setForeground(fgSuit)
  gpu.set(x+2, y+2, card.suit)
end

local function drawHand(title, hand, x, y)
  gpu.setForeground(colors.fg)
  gpu.set(x, y-1, title .. " (" .. handValue(hand) .. "):")
  for i, card in ipairs(hand) do
    drawCard(x + (i-1)*8, y, card)
  end
end

local function drawButtons(state)
  gpu.setBackground(colors.lose)
  gpu.setForeground(0xFFFFFF)
  gpu.set(w - 6, 1, "[EXIT]")
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
      elseif state == "end" then
        if x >= 20 and x <= 33 then return "again" end
      end
    elseif y == 1 and x >= w - 6 then
      return "exit"
    end
  end
end

local function askBet()
  clearScreen()
  local centerX = math.floor(w / 2) - 8
  gpu.setForeground(colors.button)
  gpu.set(centerX, 4, "╔══════════════════╗")
  gpu.set(centerX, 5, "║     OpenJack     ║")
  gpu.set(centerX, 6, "╚══════════════════╝")

  gpu.setForeground(colors.bar)
  gpu.set(centerX, 10, "Your Budget: $" .. budget)
  gpu.setForeground(colors.fg)
  
  local prompt = "Enter your bet: "
  gpu.set(centerX, 12, prompt)

  term.setCursor(centerX + #prompt, 12)
  io.write("")
  local bet = tonumber(io.read())

  if not bet or bet < 1 or bet > budget then
    return askBet()
  end
  return math.floor(bet)
end


local function game()
  while budget > 0 do
    currentBet = askBet()
    local deck = createDeck()
    local player, dealer = {}, {}

    table.insert(player, table.remove(deck))
    table.insert(dealer, table.remove(deck))
    table.insert(player, table.remove(deck))
    table.insert(dealer, table.remove(deck))

    local gameOver = false
    while not gameOver do
      clearScreen()
      gpu.setForeground(colors.bar)
      gpu.set(2, 1, "Budget: $" .. budget .. "   Bet: $" .. currentBet)
      drawHand("Dealer", {dealer[1]}, 2, 3)
      drawHand("Player", player, 2, 11)
      drawButtons("play")

      if handValue(player) > 21 then
        gpu.setForeground(colors.lose)
        gpu.set(2, 20, "You busted! Dealer wins.")
        budget = budget - currentBet
        beep(220, 0.2)
        gameOver = true
        break
      end

      local action = waitForClick("play")
      if action == "exit" then return end
      beep(800, 0.05)
      if action == "hit" then
        table.insert(player, table.remove(deck))
      elseif action == "stand" then
        break
      end
    end

    if handValue(player) <= 21 then
      while handValue(dealer) < 17 do
        table.insert(dealer, table.remove(deck))
      end

      clearScreen()
      gpu.setForeground(colors.bar)
      gpu.set(2, 1, "Budget: $" .. budget .. "   Bet: $" .. currentBet)
      drawHand("Dealer", dealer, 2, 3)
      drawHand("Player", player, 2, 11)

      local pv, dv = handValue(player), handValue(dealer)

      if dv > 21 or pv > dv then
        gpu.setForeground(colors.win)
        gpu.set(2, 20, "You win! +$" .. currentBet)
        budget = budget + currentBet
        beep(1000, 0.2)
      elseif dv > pv then
        gpu.setForeground(colors.lose)
        gpu.set(2, 20, "Dealer wins! -$" .. currentBet)
        budget = budget - currentBet
        beep(220, 0.2)
      else
        gpu.setForeground(colors.fg)
        gpu.set(2, 20, "Push (tie).")
        beep(440, 0.2)
      end
    end

    if budget <= 0 then
      gpu.setForeground(colors.lose)
      gpu.set(2, 23, "You're broke! Game over.")
      break
    end

    drawButtons("end")
    local action = waitForClick("end")
    if action == "exit" or action ~= "again" then break end
  end
end

clearScreen()
game()
