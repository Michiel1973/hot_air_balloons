local modpath = minetest.get_modpath("hot_air_balloons")

local handle_movement = dofile(modpath.."/movement.lua")

local is_in_creative = function(name)
	return creative and creative.is_enabled_for
		and creative.is_enabled_for(name)
end

local get_fire_particle = function (pos)
	pos.y = pos.y + 3
	return {
		amount = 3,
		time = 1,
		minpos = pos,
		maxpos = pos,
		minvel = {x = 0, y = 1, z = 0},
		maxvel = {x = 0, y = 1, z = 0},
		minexptime = 1,
		maxexptime = 1,
		minsize = 10,
		maxsize = 5,
		collisiondetection = false,
		vertical = false,
		texture = "hot_air_balloons_flame.png"
	}
end

local add_heat = function(self, player)
	local item_stack = player:get_wielded_item()
	local item_name = item_stack:get_name()
	local group_coal = minetest.get_item_group(item_name, "coal")
	if group_coal == 0
	then
		return false
	end
	local heat = self.heat
	heat = heat + 1200 * group_coal --1 min until heat is back to original
	if heat < 12000 --cap heat at 12000 (10 min)
	then
		self.heat = heat
		--adding particle effect
		local pos = self.object:get_pos()
		minetest.add_particlespawner(get_fire_particle(pos))
		if not is_in_creative(player:get_player_name())
		then
			item_stack:take_item()
			player:set_wielded_item(item_stack)
		end
	end
	return true
end

local hot_air_balloon_entity_def =
{
	initial_properties =
	{
		hp_max = 1,
		physical = true,
		weight = 5,
		collisionbox = {-0.65, 0, -0.65, 0.65, 1.11, 0.65},
		visual = "mesh",
		mesh = "hot_air_balloons_balloon.obj",
		textures = {"hot_air_balloons_balloon_model.png"},
		is_visible = true,
		makes_footstep_sound = false,
		automatic_rotate = false,
		backface_culling = false,
	},
	heat = 0,
	pilot = nil,
	
	on_step = function(self, dtime)
		--decrease heat, move
		if self.heat > 0
		then
			self.heat = self.heat - 1
		end
		handle_movement(self)
	end,
	on_rightclick = function (self, clicker)
		--if hoding coal, increase heat, else mount/dismount
		if not clicker or not clicker:is_player()
		then
			return
		end
		--checking if clicker is holding coal
		--heating balloon and returning if yes
		if add_heat(self, clicker)
		then
			return
		end
		
		--if not holding coal:
		local playername = clicker:get_player_name()
		if self.pilot and self.pilot == playername
		then
			--detach
			self.pilot = nil
			clicker:set_detach()
		elseif not self.pilot
		then
			--attach
			self.pilot = playername
			clicker:set_attach(self.object, "",
				{x = 0,y = 1,z = 0}, {x = 0,y = 0,z = 0})
		end
	end,
	--if pilot leaves start sinking and prepare for next pilot
	on_detach_child = function(self, child)
		self.pilot = nil
		self.heat = 0
		self.object:setvelocity({x = 0, y = 0, z = 0})
	end,
	
	on_activate = function(self, staticdata, dtime_s)
		self.object:setvelocity({x = 0, y = 0, z = 0})
	end,
	
	on_punch = function(self, puncher)
		if not (puncher and puncher:is_player())
		then
			return
		end
		local inv = puncher:get_inventory()
		if not is_in_creative(puncher:get_player_name())
			or not inv:contains_item("main", "hot_air_balloons:item")
		then
			local leftover = inv:add_item("main", "hot_air_balloons:item")
			if not leftover:is_empty()
			then
				minetest.add_item(self.object:get_pos(), leftover)
			end
		end
	end,
}
minetest.register_entity("hot_air_balloons:balloon", hot_air_balloon_entity_def)




--Defining and registering hot air balloon item
local hot_air_balloon_item_def =
{
	description = "Hot Air Balloon",
	inventory_image = "hot_air_balloons_balloon.png",
	stack_max = 1,
	liquids_pointable = true,
	on_place =
	function (itemstack, placer, pointed_thing)
		--places balloon if the clicked thing is a node and the above node is air
		if pointed_thing.type == "node"
			and minetest.get_node (pointed_thing.above).name == "air"
		then
			if not is_in_creative(placer:get_player_name())
			then
				itemstack:take_item()
			end
			local pos_to_place = pointed_thing.above
			pos_to_place.y = pos_to_place.y - 0.6 --subtracting 0.6 to place on ground
			minetest.add_entity(pointed_thing.above, "hot_air_balloons:balloon")
		end
		--add remaining items to inventory
		return itemstack
	end
}
minetest.register_craftitem("hot_air_balloons:item", hot_air_balloon_item_def)
minetest.register_craft({
	output = "hot_air_balloons:item",
	recipe = {
		{"default:paper", "default:paper",      "default:paper"},
		{"default:paper", "bucket:bucket_lava", "default:paper"},
		{"",              "group:wood",         ""             },
	},
})
