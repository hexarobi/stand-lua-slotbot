-- SlotBot
-- by Hexarobi

local SCRIPT_VERSION = "0.6"

---
--- Auto-Updater Lib Install
---

-- Auto Updater from https://github.com/hexarobi/stand-lua-auto-updater
local status, auto_updater = pcall(require, "auto-updater")
if not status then
    local auto_update_complete = nil util.toast("Installing auto-updater...", TOAST_ALL)
    async_http.init("raw.githubusercontent.com", "/hexarobi/stand-lua-auto-updater/main/auto-updater.lua",
            function(result, headers, status_code)
                local function parse_auto_update_result(result, headers, status_code)
                    local error_prefix = "Error downloading auto-updater: "
                    if status_code ~= 200 then util.toast(error_prefix..status_code, TOAST_ALL) return false end
                    if not result or result == "" then util.toast(error_prefix.."Found empty file.", TOAST_ALL) return false end
                    filesystem.mkdir(filesystem.scripts_dir() .. "lib")
                    local file = io.open(filesystem.scripts_dir() .. "lib\\auto-updater.lua", "wb")
                    if file == nil then util.toast(error_prefix.."Could not open file for writing.", TOAST_ALL) return false end
                    file:write(result) file:close() util.toast("Successfully installed auto-updater lib", TOAST_ALL) return true
                end
                auto_update_complete = parse_auto_update_result(result, headers, status_code)
            end, function() util.toast("Error downloading auto-updater lib. Update failed to download.", TOAST_ALL) end)
    async_http.dispatch() local i = 1 while (auto_update_complete == nil and i < 40) do util.yield(250) i = i + 1 end
    if auto_update_complete == nil then error("Error downloading auto-updater lib. HTTP Request timeout") end
    auto_updater = require("auto-updater")
end
if auto_updater == true then error("Invalid auto-updater lib. Please delete your Stand/Lua Scripts/lib/auto-updater.lua and try again") end

---
--- Auto Updater
---

local auto_update_config = {
    source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-slotbot/main/SlotBot.lua",
    script_relpath=SCRIPT_RELPATH,
    verify_file_begins_with="--",
    check_interval=604800,
}
auto_updater.run_auto_update(auto_update_config)

---
--- Dependencies and Data
---

util.require_natives(1663599433)

local state = {}
local menus = {}

local slot_machine_positions = {
    {
        seated={x=1102.2573, y=232.43211, z=-50.0909},
        standing={x=1102.6787, y=232.73073, z=-49.84076, h=90},
    },
    {
        seated={x=1112.4808, y=234.83745, z=-50.0909},
        standing={x=1112.0146, y=235.13573, z=-49.84075, h=-90},
    },
    {
        seated={x=1110.1028, y=235.05864, z=-50.0909},
        standing={x=1110.5834, y=235.30466, z=-49.840767, h=90},
    },
    {
        seated={x=1111.9581, y=237.83565, z=-50.0909},
        standing={x=1112.1866, y=237.27339, z=-49.840763, h=0},
    },
    {
        seated={x=1113.66, y=238.81334, z=-50.0909},
        standing={x=1113.8134, y=238.09317, z=-49.840786, h=0}
    },
    {
        seated={x=1139.4238, y=250.89787, z=-51.2909},
        standing={x=1139.8647, y=250.2418, z=-51.035732, h=70}
    },
    {
        seated={x=1130.6184, y=251.2604, z=-51.2909},
        standing={x=1130.7328, y=251.68321, z=-51.035774, h=180}
    },
    {
        seated={x=1137.2375, y=253.092, z=-51.2909},
        standing={x=1137.3026, y=253.69514, z=-51.03577, h=180}
    },
    {
        seated={x=1103.4133, y=230.6071, z=-50.0909},
        standing={x=1102.95, y=230.27, z=-49.84, h=-90},
    },
    {
        seated={x=1118.7598, y=230.03072, z=-50.0909},
        standing={x=1119.2648, y=230.20291, z=-49.840748, h=100}
    },
}

---
--- Utils
---

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

local function disp_time(time)
    --local days = math.floor(time/86400)
    local hours = math.floor((time % 86400)/3600)
    local minutes = math.floor((time % 3600)/60)
    --local seconds = math.floor(time % 60)
    return string.format("%d hours and %d minutes",hours,minutes)
end

local function is_player_within_dimensions(dimensions, pid)
    if pid == nil then pid = players.user_ped() end
    local target_ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pid)
    local player_pos = ENTITY.GET_ENTITY_COORDS(target_ped)
    return (
            player_pos.x > dimensions.min.x and player_pos.x < dimensions.max.x
                    and player_pos.y > dimensions.min.y and player_pos.y < dimensions.max.y
                    and player_pos.z > dimensions.min.z and player_pos.z < dimensions.max.z
    )
end

local function is_player_in_casino(pid)
    return is_player_within_dimensions({
        min={
            x=1073.9967,
            y=189.58717,
            z=-53.838943,
        },
        max={
            x=1166.935,
            y=284.88977,
            z=-42.28554,
        },
    }, pid)
end

local function is_player_near_slot_machine(slot_machine_position, sensitivty)
    if sensitivty == nil then sensitivty = 1 end
    return is_player_within_dimensions({
        min={
            x=slot_machine_position.x - sensitivty,
            y=slot_machine_position.y - sensitivty,
            z=slot_machine_position.z - sensitivty,
        },
        max={
            x=slot_machine_position.x + sensitivty,
            y=slot_machine_position.y + sensitivty,
            z=slot_machine_position.z + sensitivty,
        },
    }, players.user())
end

local function is_player_at_any_slot_machine()
    for _, slot_machine_position in pairs(slot_machine_positions) do
        if is_player_near_slot_machine(slot_machine_position.seated, 0.3) then
            return true
        end
    end
    return false
end

local function find_free_slot_machine()
    for _, slot_machine_position in pairs(slot_machine_positions) do
        local pos = slot_machine_position.standing
        ENTITY.SET_ENTITY_COORDS(players.user_ped(), pos.x, pos.y, pos.z)
        ENTITY.SET_ENTITY_HEADING(players.user_ped(), pos.h)
        util.yield(100)
        PAD.SET_CONTROL_VALUE_NEXT_FRAME(0, 51, 1)
        util.yield(100)
        PAD.SET_CONTROL_VALUE_NEXT_FRAME(0, 201, 1)
        util.yield(5000)
        if is_player_near_slot_machine(slot_machine_position.seated, 0.3) then
            util.toast("Free machine found!")
            return true
        end
    end
    return false
end

---
--- Spin Log
---

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

---
--- Functions
---

local function get_num_wins_past_day()
    local spin_log = load_spin_log()
    return count_wins(spin_log)
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

local function is_num_daily_wins_exceeded()
    local num_wins = get_num_wins_past_day()
    if num_wins >= 19 then
        return true
    end
    return false
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

local function is_slots_ready_for_spin()

    if not is_player_in_casino(players.user()) then
        util.toast("You must be in the casino and seated at a high-payout slot machine to initiate auto-spin")
        exit_slots()
        return false
    end

    if not is_player_at_any_slot_machine() then
        util.toast("You must be seated at a high-payout slot machine (`Diamond Miner` or `Diety of the Sun`) to initiate auto-spin")
        exit_slots()
        return false
    end

    if is_num_daily_wins_exceeded() then
        util.toast("You've won your daily limit. Try again in "..get_safe_playtime())
        exit_slots()
        return false
    end

    return true
end

---
--- Spin Slots
---

local function spin_slots()

    if not is_slots_ready_for_spin() then
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
    util.yield(1000)

    -- Bet max
    PAD.SET_CONTROL_VALUE_NEXT_FRAME(0, 204, 1)
    util.yield(500)
    -- Spin
    PAD.SET_CONTROL_VALUE_NEXT_FRAME(0, 201, 1)
    util.yield(1000)

    menu.trigger_commands("rigslotmachines off")

    log_spin()
    refresh_daily_winnings()
end

---
--- Update Tick
---

local function bandit_tick()
    if state.auto_spin then
        local current_time = util.current_time_millis()
        if state.next_update_time == nil or current_time > state.next_update_time then
            local delay_time = 8000

            if is_num_daily_wins_exceeded() then
                util.toast("You've won your daily limit. Try again in "..get_safe_playtime())
            elseif not is_player_in_casino(players.user()) then
                menu.trigger_commands("casinotp"..players.get_name(players.user()))
                delay_time = 30000
            elseif not is_player_at_any_slot_machine() then
                find_free_slot_machine()
            else
                spin_slots()
            end

            state.next_update_time = util.current_time_millis() + delay_time + math.random(1,2000)
        end
    end
    return true
end

---
--- Menus
---

menus.auto_spin = menu.toggle(menu.my_root(), "Auto-Spin", {}, "You should be seated at a high-payout casino slot machine (either 'Diamond Miner' or 'Empire of the Sun') before engaging this feature. Once enabled, it will auto-spin the slots, alternating between winning and losing to avoid detection. Winning over $50mil per day is risky, so script will auto-cutoff at $47.5mil. Come back tomorrow and run the script again for more.", function(on)
    state.auto_spin = on
end)

menu.action(menu.my_root(), "Teleport to Casino", {}, "", function()
    menu.trigger_commands("casinotp"..players.get_name(players.user()))
end)

menu.action(menu.my_root(), "Find free slot machine", {}, "", function()
    find_free_slot_machine()
end)

menus.daily_winnings = menu.readonly(menu.my_root(), "Daily Winnings")
refresh_daily_winnings()

menus.script_meta = menu.list(menu.my_root(), "Script Meta")
menu.divider(menus.script_meta, "SlotBot")
menu.readonly(menus.script_meta, "Version", SCRIPT_VERSION)
menu.action(menus.script_meta, "Check for Update", {}, "The script will automatically check for updates at most daily, but you can manually check using this option anytime.", function()
    auto_update_config.check_interval = 0
    if auto_updater.run_auto_update(auto_update_config) then
        util.toast("No updates found")
    end
end)
menu.hyperlink(menus.script_meta, "Github Source", "https://github.com/hexarobi/stand-lua-slotbot", "View source files on Github")
menu.hyperlink(menus.script_meta, "Discord", "https://discord.gg/2u5HbHPB9y", "Open Discord Server")

---
--- Tick Handler
---

util.create_tick_handler(bandit_tick)
