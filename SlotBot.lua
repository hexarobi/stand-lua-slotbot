-- SlotBot
-- by Hexarobi

local SCRIPT_VERSION = "0.2"

util.require_natives(1663599433)

local state = {}
local menus = {}

local CONFIG_DIR = filesystem.store_dir() .. 'SlotBot\\'
filesystem.mkdirs(CONFIG_DIR)
local SPIN_LOG_FILE = CONFIG_DIR .. "spin_log.json"

local function save_spin_log(spin_log)
    local file = io.open(SPIN_LOG_FILE, "wb")
    if file == nil then util.toast("Error opening spin log file for writing: "..SPIN_LOG_FILE, TOAST_ALL) return end
    file:write(soup.json.encode(spin_log))
    file:close()
end

local function load_spin_log()
    local file = io.open(SPIN_LOG_FILE)
    if file then
        local version = file:read()
        file:close()
        local spin_log_status, spin_log = pcall(soup.json.decode, version)
        if not spin_log_status then
            error("Could not decode spin log file")
        end
        return spin_log
    else
        return {}
    end
end

local function count_wins(spin_log)
    local num_wins = 0
    local target_time = util.current_time_millis() - 86400000
    for _, spin in pairs(spin_log) do
        if spin.is_rigged and spin.time > target_time then
            num_wins = num_wins + 1
        end
    end
    return num_wins
end

local function log_spin()
    local spin_log = load_spin_log()
    local num_wins = count_wins(spin_log)
    -- Reset spin log if no daily wins. Avoid growing too large.
    if num_wins == 0 and #spin_log > 0 then spin_log = {} end
    table.insert(spin_log, {
        is_rigged=state.is_rigged,
        time=util.current_time_millis(),
    })
    save_spin_log(spin_log)
end

local function get_num_wins_past_day()
    local spin_log = load_spin_log()
    return count_wins(spin_log)
end

local function disp_time(time)
    --local days = math.floor(time/86400)
    local hours = math.floor((time % 86400)/3600)
    local minutes = math.floor((time % 3600)/60)
    --local seconds = math.floor(time % 60)
    return string.format("%2d hours and %2d minutes",hours,minutes)
end

local function get_safe_playtime()
    local spin_log = load_spin_log()
    local first_spin = spin_log[1]
    if first_spin ~= nil then
        local countdown = first_spin.time - util.current_time_millis() + 86400000
        if countdown > 0 then
            return disp_time(countdown / 1000)
        end
    end
end

local function is_safe_to_spin()
    local num_wins = get_num_wins_past_day()
    if num_wins >= 19 then
        util.toast("You've already won your daily limit. Try again in "..get_safe_playtime())
        return false
    end
    return true
end

local function refresh_daily_winnings()
    menus.daily_winnings.value = "$" .. (get_num_wins_past_day() * 2.5) .. "mil"
end

local function switch_rigged_state()
    if state.is_rigged == nil or state.is_rigged == true then
        state.is_rigged = false
    else
        state.is_rigged = true
    end
end

local function exit_slots()
    menu.trigger_commands("rigslotmachines off")
    PAD.SET_CONTROL_VALUE_NEXT_FRAME(0, 202, 1)
    menus.auto_spin.value = false
end

local function spin_slots()
    if not is_safe_to_spin() then
        exit_slots()
        return
    end

    switch_rigged_state()

    if state.is_rigged then
        util.toast("Spinning slots to win")
        menu.trigger_commands("rigslotmachines jackpot")
    else
        util.toast("Spinning slots to lose")
        menu.trigger_commands("rigslotmachines loss")
    end

    -- Bet max
    PAD.SET_CONTROL_VALUE_NEXT_FRAME(0, 204, 1)
    util.yield(100)
    -- Spin
    PAD.SET_CONTROL_VALUE_NEXT_FRAME(0, 201, 1)
    util.yield(100)

    menu.trigger_commands("rigslotmachines off")

    log_spin()
    refresh_daily_winnings()
end

local function bandit_tick()
    if state.auto_spin then
        local current_time = util.current_time_millis()
        if state.next_update_time == nil or current_time > state.next_update_time then
            spin_slots()
            state.next_update_time = util.current_time_millis() + 6000 + math.random(1,1000)
        end
    end
    return true
end

menu.action(menu.my_root(), "Teleport to Casino", {}, "", function()
    menu.trigger_commands("casinotp"..players.get_name(players.user()))
end)

menus.auto_spin = menu.toggle(menu.my_root(), "Auto-Spin", {}, "You should be seated at a high-payout casino slot machine (either 'Diamond Miner' or 'Empire of the Sun') before engaging this feature. Once enabled, it will auto-spin the slots, alternating between winning and losing to avoid detection. Winning over $50mil per day is risky, so script will auto-cutoff at $47.5mil. Come back tomorrow and run the script again for more.", function(on)
    state.auto_spin = on
end)

menus.daily_winnings = menu.readonly(menu.my_root(), "Daily Winnings")
refresh_daily_winnings()

util.create_tick_handler(bandit_tick)
