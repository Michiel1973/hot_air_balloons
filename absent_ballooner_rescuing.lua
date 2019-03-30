--localize things for better performance
local serialize = minetest.serialize
local add_entity = minetest.add_entity
local after = minetest.after

--for storing which players left while in a balloon
local storage = minetest.get_mod_storage()
local absent_ballooners = minetest.deserialize(storage:get_string("absent_ballooners")) or {}


--putting leaving people into storage
local leave_while_ballooning = function(player)
	local parent = player:get_attach()
	if parent and parent.get_luaentity
	then
		local le = parent:get_luaentity()
		if le.is_hot_air_balloon
		then
			--remove() only works if someone else is in the area hence mark_for_deletion
			parent:remove()
			absent_ballooners[player:get_player_name()] = true
		end
	end
end

--same as on_leave but for all players
local on_shutdown = function()
	local connected_players = minetest.get_connected_players()
	for i, p in ipairs(connected_players)
	do
		leave_while_ballooning(p)
	end
	storage:set_string("absent_ballooners", serialize(absent_ballooners))
end
--putting leaving people into storage and saving storage
local on_leave = function(player)
	leave_while_ballooning(player)
	storage:set_string("absent_ballooners", serialize(absent_ballooners))
end

minetest.register_on_leaveplayer(on_leave)
minetest.register_on_shutdown(on_shutdown)

--checking if player who joined was ballooning when they left
--if so spawn a new balloon and set them as attachment
local on_join = function(player)
	if player
	then
		local name = player:get_player_name()
		if absent_ballooners[name]
		then
			local pos = player:get_pos()
			
			--minetest doesn't seem to like add_entity on init so a minetest.after is used
			--player is set as pilot in on_activate
			after(2,
				function()
					--concatenating "P" with name signals that player should be set as attach
					add_entity(pos, "hot_air_balloons:balloon", "P" .. name)
				end)
		end
	end
end
minetest.register_on_joinplayer(on_join)


--called in on_activate if balloon was spawned to rescue an absent ballooner
local set_rescue = function(self, playername)
	local player = minetest.get_player_by_name(playername)
	if not player --player logged off right away
	then
		self.object:remove()
		return
	end
	local pos = player:get_pos()
	self.pilot = playername
	player:set_attach(self.object, "",
		{x = 0,y = 1,z = 0}, {x = 0,y = 0,z = 0})
	absent_ballooners[playername] = nil
end
--set as get_staticdata
local mark_for_deletion = function(self)
	if self.pilot
	then
		--pilot logged off while ballooning, deleting balloon on next activation
		return "R"
	else
		--normally save and load balloon
		return ""
	end
end


return set_rescue, mark_for_deletion


