# SlotBot

Automatic spinning of casino slot machine in GTA5. Check the auto-spin box, go AFK for a few mins while you make a quick $50mil, repeat the next day.

Automates the following steps:
* Teleport to Casino if not already in Casino
* Acquire chips from Cashier if needed
* Finds an available high-payout slot machine (Diamond Miner or Deity of the Sun) and takes a seat
* Spins the slot machine for a loss
* Spins the slot machine for a win ($2.5mil)
* Repeats the above two steps until the daily limit is reached
* Visit Cashier to cash out chips, while keeping at least a few chips in reserve
* Keeps track of when your daily limit has expired so you can safely run the loop again

Warning: Avoid rigging slots if you have other used any other menus on your account (ie Kiddions)

# Installation

Save [the script file](https://raw.githubusercontent.com/hexarobi/stand-lua-slotbot/main/SlotBot.lua) to your `Stand/Lua Scripts` folder.
