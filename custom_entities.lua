meta = {
    name = "Custom Entities Library",
    version = "0.3",
    author = "Estebanfer",
    description = "A library for creating custom entities easier"
}
--TODO: Backpacks
local module = {}
local custom_types = {}

local cb_update, cb_loading, cb_transition, cb_post_room_gen, cb_post_level_gen = -1, -1, -1, -1, -1

local custom_entities_t_info = {} --transition info
local custom_entities_t_info_hh = {}
local custom_entities_t_info_storage = {}
local storage_pos = nil

local function set_transition_info(c_type_id, data, slot, mounted) --mounted: false = being held
    table.insert(custom_entities_t_info,
    {
        ["custom_type_id"] = c_type_id,
        ["data"] = data,
        ["slot"] = slot,
        ["mounted"] = mounted
    })
end

local function set_transition_info_hh(c_type_id, data, e_type, hp, cursed, poisoned)
    table.insert(custom_entities_t_info_hh,
    {
        ["custom_type_id"] = c_type_id,
        ["data"] = data,
        ["e_type"] = e_type,
        ["hp"] = hp,
        ["cursed"] = cursed,
        ["poisoned"] = poisoned
    })
end

local function set_transition_info_storage(c_type_id, data, e_type)
    if custom_entities_t_info_storage[e_type] then
        table.insert(custom_entities_t_info_storage[e_type], {
            ["custom_type_id"] = c_type_id,
            ["data"] = data
        })
    else
        custom_entities_t_info_storage[e_type] = {
            {
                ["custom_type_id"] = c_type_id,
                ["data"] = data
            }
        }
    end
end

local function update_customs()
    local is_portal = #get_entities_by_type(ENT_TYPE.FX_PORTAL) > 0 
    for _,c_type in ipairs(custom_types) do
        for uid, c_data in pairs(c_type.entities) do
            local ent = get_entity(uid)
            if ent then
                c_type.update(ent, c_data, c_type, is_portal)
            else
                c_type[uid] = nil
            end
        end
    end
end

local function get_holder_player(ent) -- or hh
    local holder = ent:topmost_mount()
    if holder == ent then
        return nil
    elseif holder.type.search_flags == MASK.PLAYER or holder.type.search_flags == MASK.MOUNT then
        if holder.type.search_flags == MASK.MOUNT then --if the topmost is a mount, that means the true holder is the one riding it
            holder = get_entity(holder.rider_uid)
        end
        return holder
    end
end

local function set_custom_items_waddler(items_zone, layer)
    local stored_items = get_entities_overlapping_hitbox(0, MASK.ITEM, items_zone, layer)
    for _, uid in ipairs(stored_items) do
        local ent = get_entity(uid)
        local custom_t_info = custom_entities_t_info_storage[ent.type.id]
        if custom_t_info and custom_t_info[1] then
            custom_types[custom_t_info[1].custom_type_id].entities[uid] = custom_types[custom_t_info[1].custom_type_id].set(ent, custom_t_info[1].data)
            table.remove(custom_entities_t_info_storage[ent.type.id], 1)
        end
    end
end

local function set_custom_ents_from_previous(companions)
    for i, info in ipairs(custom_entities_t_info) do
        for ip,p in ipairs(players) do
            if p.inventory.player_slot == info.slot then
                local custom_ent
                if info.mounted then
                    custom_ent = p:topmost_mount()
                else
                    custom_ent = p:get_held_entity()
                end
                custom_types[info.custom_type_id].entities[custom_ent.uid] = custom_types[info.custom_type_id].set(custom_ent, info.data)
            end
        end
    end
    for i, uid in ipairs(companions) do
        local ent = get_entity(uid)
        for _, info in pairs(custom_entities_t_info_hh) do
            if ent.type.id == info.e_type and ent.linked_companion_parent ~= -1 and
            ent.health == info.hp and test_flag(ent.more_flags, ENT_MORE_FLAG.CURSED_EFFECT) == info.cursed and
            ent:is_poisoned() == info.poisoned then
                local custom_ent = ent:get_held_entity()
                custom_types[info.custom_type_id][custom_ent.uid] = custom_types[info.custom_type_id].set(custom_ent, info.data)
            end
        end
    end
    if storage_pos then
        set_custom_items_waddler(AABB:new(storage_pos.x-0.5, storage_pos.y+1.5, storage_pos.x+1.5, storage_pos.y), storage_pos.l)
    end
    storage_pos = nil
end

set_post_tile_code_callback(function(x, y, l) 
    if not storage_pos then
        storage_pos = {['x'] = x, ['y'] = y, ['l'] = l}
    end
end, 'storage_floor')

function module.init(game_frame)
    if (game_frame) then
        cb_update = set_callback(function()
            update_customs()
        end, ON.GAMEFRAME)
    else
        cb_update = set_callback(function()
            update_customs()
        end, ON.FRAME)
    end
    
    cb_loading = set_callback(function()
        local is_storage_floor_there = #get_entities_by_type(ENT_TYPE.FLOOR_STORAGE) > 0
        if state.loading == 2 and ((state.screen_next == SCREEN.TRANSITION and state.screen ~= SCREEN.SPACESHIP) or state.screen_next == SCREEN.SPACESHIP) then
            for c_id,c_type in ipairs(custom_types) do
                for uid, c_data in pairs(c_type.entities) do
                    if c_type.is_item then
                        local ent = get_entity(uid)
                        local holder
                        if not ent or ent.state == 24 or ent.last_state == 24 then
                            holder = c_data.last_holder
                        else
                            holder = get_holder_player(ent)
                        end
                        if holder then
                            if holder.inventory.player_slot == -1 then
                                set_transition_info_hh(c_id, c_data, holder.type.id, holder.health, test_flag(holder.more_flags, ENT_MORE_FLAG.CURSED_EFFECT), holder:is_poisoned())
                            else
                                set_transition_info(c_id, c_data, holder.inventory.player_slot, false) --the bumble
                            end
                        elseif ent and is_storage_floor_there and ent.standing_on_uid and get_entity(ent.standing_on_uid).type.id == ENT_TYPE.FLOOR_STORAGE then
                            set_transition_info_storage(c_id, c_data, ent.type.id)
                        end
                    end
                    if c_type.is_mount then
                        local ent = get_entity(uid)
                        local holder, rider_uid
                        if not ent or ent.state == 24 or ent.last_state == 24 then
                            holder = c_data.last_holder
                            rider_uid = c_data.last_rider_uid
                        else
                            holder = get_holder_player(ent)
                            rider_uid = ent.rider_uid
                        end
                        if holder then
                            if holder.inventory.player_slot == -1 then
                                set_transition_info_hh(c_id, c_data, holder.type.id, holder.health, test_flag(holder.more_flags, ENT_MORE_FLAG.CURSED_EFFECT), holder:is_poisoned())
                            else
                                set_transition_info(c_id, c_data, holder.inventory.player_slot, false)
                            end
                        elseif rider_uid ~= -1 then
                            holder = get_entity(rider_uid)
                            if holder.type.search_flags == MASK.PLAYER then
                                set_transition_info(c_id, c_data, holder.inventory.player_slot, true)
                            end
                        end
                    end
                end
            end
        end
    end, ON.LOADING)
    
    cb_transition = set_callback(function()
        local companions = get_entities_by(0, MASK.PLAYER, LAYER.FRONT)
        set_custom_ents_from_previous(companions)
    end, ON.TRANSITION)
    
    cb_post_level_gen = set_callback(function()
        if state.screen == 12 then
            local px, py, pl = get_position(players[1].uid)
            local companions = get_entities_at(0, MASK.PLAYER, px, py, pl, 2)
            set_custom_ents_from_previous(companions)
            custom_entities_t_info = {} 
            custom_entities_t_info_hh = {}
        end
    end, ON.POST_LEVEL_GENERATION)
    
    cb_post_room_gen = set_callback(function()
        for _,c_type in ipairs(custom_types) do
            c_type.entities = {}
        end
    end, ON.POST_ROOM_GENERATION)
end

function module.stop()
    clear_callback(cb_update)
    clear_callback(cb_loading)
    clear_callback(cb_transition)
    clear_callback(cb_post_level_gen)
    clear_callback(cb_post_room_gen)
end

function module.new_custom_entity(set_func, update_func, is_item, is_mount, opt_ent_type)
    local custom_id = #custom_types + 1
    custom_types[custom_id] = {
        ["set"] = set_func,
        ["update_callback"] = update_func,
        ["is_item"] = is_item,
        ["is_mount"] = is_mount,
        ["ent_type"] = opt_ent_type,
        ["entities"] = {}
    }
    
    if is_item then
        if is_mount then
            custom_types[custom_id].update = function(ent, c_data, c_type, is_portal)
                c_type.update_callback(ent, c_data)
                if is_portal then
                    if ent.state ~= 24 and ent.last_state ~= 24 then --24 seems to be the state when entering portal
                        c_data.last_holder = get_holder_player(ent)
                        c_data.last_rider_uid = ent.rider_uid
                    end
                end
            end
        else
            custom_types[custom_id].update = function(ent, c_data, c_type, is_portal)
                c_type.update_callback(ent, c_data)
                if is_portal then
                    if ent.state ~= 24 and ent.last_state ~= 24 then --24 seems to be the state when entering portal
                        c_data.last_holder = get_holder_player(ent)
                    end
                end
            end
        end
    elseif is_mount then
        custom_types[custom_id].update = function(ent, c_data, c_type, is_portal)
            c_type.update_callback(ent, c_data)
            if is_portal then
                if ent.state ~= 24 and ent.last_state ~= 24 then --24 seems to be the state when entering portal
                    c_data.last_rider_uid = ent.rider_uid
                end
            end
        end
    else
        custom_types[custom_id].update = function(ent, c_data, c_type)
            c_type.update_callback(ent, c_data)
        end
    end
    return custom_id
end

function module.new_custom_gun(set_func, update_func, firefunc, cooldown, recoil_x, recoil_y, opt_ent_type)
    local custom_id = #custom_types + 1
    custom_types[custom_id] = {
        ["set"] = set_func,
        ["update_callback"] = update_func,
        ["is_item"] = true,
        ["is_mount"] = false,
        ["ent_type"] = opt_ent_type,
        ["shoot"] = firefunc,
        ["cooldown"] = cooldown,
        ["recoil_x"] = recoil_x,
        ["recoil_y"] = recoil_y,
        ["entities"] = {}
    }
    custom_types[custom_id].update = function(ent, c_data, c_type, is_portal)
        ent.cooldown = math.max(ent.cooldown, 2)
        local holder = ent:topmost_mount()
        if holder ~= ent then
            local holder_input = read_input(holder.uid)
            if holder:is_button_pressed(BUTTON.WHIP) and ent.cooldown == 2 and holder.state ~= CHAR_STATE.DUCKING then
                ent.cooldown = c_type.cooldown+2
                local recoil_dir = test_flag(holder.flags, ENT_FLAG.FACING_LEFT) and 1 or -1
                holder.velocityx = holder.velocityx + c_type.recoil_x*recoil_dir
                holder.velocityy = holder.velocityy + c_type.recoil_y
                c_type.shoot(ent, c_data)
            end
        end
        c_type.update_callback(ent, c_data)
        if is_portal then
            if ent.state ~= 24 and ent.last_state ~= 24 then --24 seems to be the state when entering portal
                c_data.last_holder = get_holder_player(ent)
            end
        end
    end
    return custom_id
end

function module.set_custom_entity(uid, custom_ent_id)
    local ent = get_entity(uid)
    custom_types[custom_ent_id].entities[uid] = custom_types[custom_ent_id].set(ent)
end

module.custom_types = custom_types

register_console_command('get_custom_types', function() return custom_types end)

return module