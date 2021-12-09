local c_ent_lib = require "custom_entities"

local colors = {'r', 'g', 'b'}

local function number_to_range(num, min, max)
    if num > max then
        num = (num - max) + min - 1
    elseif num < min then
        num = (num - min) + max + 1
    end
    return num
end

local function custom_back_set(ent, data)
    ent.color.b = 0
    ent.color.g = 0
    return {
        ["color_n"] = 2,
        ["vel"] = math.random()/20+0.01,
        ["up"] = true
    }
end

local function custom_back_update(ent, data)
    local color = colors[data.color_n]
    ent.color[color] = data.up and ent.color[color] + data.vel or ent.color[color] - data.vel
    if ent.color[color] <= 0 then
        ent.color[color] = 0
        data.color_n = number_to_range(data.color_n + 2, 1, 3)
        data.up = true
    elseif ent.color[color] >= 1 then
        ent.color[color] = 1
        data.color_n = number_to_range(data.color_n - 1, 1, 3)
        data.up = false
    end
end

c_ent_lib.init()
local custom_back = c_ent_lib.new_custom_entity(custom_back_set, custom_back_update, c_ent_lib.CARRY_TYPE.HELD, ENT_TYPE.ITEM_CAPE)
local custom_back_p = c_ent_lib.new_custom_purchasable_back(custom_back_set, custom_back_update, 40, custom_back, false)
messpect(custom_back, custom_back_p)
c_ent_lib.add_custom_shop_chance(custom_back_p, c_ent_lib.CHANCE.COMMON, c_ent_lib.ALL_SHOPS)

set_callback(function()
    local x, y, l = get_position(players[1].uid)
    local uid = spawn(ENT_TYPE.ITEM_CAPE, x, y, l, 0, 0)
    messpect(uid)
    c_ent_lib.set_custom_entity(uid, custom_back)
end, ON.LEVEL)