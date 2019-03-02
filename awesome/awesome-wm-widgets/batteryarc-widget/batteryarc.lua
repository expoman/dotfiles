local awful = require("awful")
local beautiful = require("beautiful")
local naughty = require("naughty")
local wibox = require("wibox")
local watch = require("awful.widget.watch")

local HOME = os.getenv("HOME")

-- only text
local text = wibox.widget {
    id = "txt",
    font = "Play 5",
    widget = wibox.widget.textbox
}

-- mirror the text, because the whole widget will be mirrored after
local mirrored_text = wibox.container.mirror(text, { horizontal = true })

-- mirrored text with background
local mirrored_text_with_background = wibox.container.background(mirrored_text)

local batteryarc = wibox.widget {
    mirrored_text_with_background,
    max_value = 1,
    rounded_edge = true,
    thickness = 2,
    start_angle = 4.71238898, -- 2pi*3/4
    forced_height = 17,
    forced_width = 17,
    bg = "#ffffff11",
    paddings = 2,
    widget = wibox.container.arcchart,
    set_value = function(self, value)
        self.value = value
    end,
}

-- mirror the widget, so that chart value increases clockwise
local batteryarc_widget = wibox.container.mirror(batteryarc, { horizontal = true })

local last_battery_check = os.time()

watch("acpi -i", 10,
    function(widget, stdout, stderr, exitreason, exitcode)
        local batteryType

        local battery_info = {}
        local capacities = {}
        for s in stdout:gmatch("[^\r\n]+") do
            local status, charge_str, time = string.match(s, '.+: (%a+), (%d?%d?%d)%%,?.*')
            if string.match(s, 'rate information') then
                -- ignore such line
            elseif status ~= nil then
                table.insert(battery_info, {status = status, charge = tonumber(charge_str)})
            else
                local cap_str = string.match(s, '.+:.+last full capacity (%d+)')
                table.insert(capacities, tonumber(cap_str))
            end
        end

        local capacity = 0
        for i, cap in ipairs(capacities) do
            capacity = capacity + cap
        end

        local charge = 0
        local status
        for i, batt in ipairs(battery_info) do
            if batt.charge >= charge then
                status = batt.status -- use most charged battery status
                -- this is arbitrary, and maybe another metric should be used
            end

            charge = charge + batt.charge * capacities[i]
        end
        charge = charge / capacity

        widget.value = charge / 100
        if status == 'Charging' then
            mirrored_text_with_background.bg = beautiful.widget_green
            mirrored_text_with_background.fg = beautiful.widget_black
        else
            mirrored_text_with_background.bg = beautiful.widget_transparent
            mirrored_text_with_background.fg = beautiful.widget_main_color
        end

        text.text = string.format('%d', charge)

        if charge < 15 then
            batteryarc.colors = { beautiful.widget_red }
            if status ~= 'Charging' and os.difftime(os.time(), last_battery_check) > 300 then
                -- if 5 minutes have elapsed since the last warning
                last_battery_check = time()

                show_battery_warning()
            end
        elseif charge > 15 and charge < 40 then
            batteryarc.colors = { beautiful.widget_yellow }
        else
            batteryarc.colors = { beautiful.widget_main_color }
        end
    end,
    batteryarc)

-- Popup with battery info
-- One way of creating a pop-up notification - naughty.notify
local notification
function show_battery_status()
    awful.spawn.easy_async([[bash -c 'acpi']],
        function(stdout, _, _, _)
            notification = naughty.notify {
                text = stdout,
                title = "Battery status",
                timeout = 5,
                hover_timeout = 0.5,
                width = 200,
            }
        end)
end

batteryarc:connect_signal("mouse::enter", function() show_battery_status() end)
batteryarc:connect_signal("mouse::leave", function() naughty.destroy(notification) end)

-- Alternative to naughty.notify - tooltip. You can compare both and choose the preferred one

--battery_popup = awful.tooltip({objects = {battery_widget}})

-- To use colors from beautiful theme put
-- following lines in rc.lua before require("battery"):
-- beautiful.tooltip_fg = beautiful.fg_normal
-- beautiful.tooltip_bg = beautiful.bg_normal

--[[ Show warning notification ]]
function show_battery_warning()
    naughty.notify {
        icon = HOME .. "/.config/awesome/nichosi.png",
        icon_size = 100,
        text = "Huston, we have a problem",
        title = "Battery is dying",
        timeout = 5,
        hover_timeout = 0.5,
        position = "bottom_right",
        bg = "#F06060",
        fg = "#EEE9EF",
        width = 300,
    }
end

return batteryarc_widget
