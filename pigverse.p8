pico-8 cartridge // http://www.pico-8.com
version 15
__lua__

--pigverse--

-- constants

tile_size = 8
stage_size = 16


-- api

chars=" !\"#$%&'()*+,-./0123456789:;<=>?@abcdefghijklmnopqrstuvwxyz[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
s2c={} c2s={}
for i=1,95 do
	c=i+31
	s=sub(chars,i,i)
	c2s[c]=s
	s2c[s]=c
end

omsg_queue={} 
omsg=nil 
imsg=""

function split_str(str,sep)
 astr={} index=0
 for i=1,#str do
 	if (sub(str,i,i)==sep) then
 	 chunk=sub(str,index,i-1)
 	 index=i+1
 		add(astr,chunk)
 	end
 end
 chunk=sub(str,index,#str)
 add(astr,chunk)
 return astr
end

function send_msg(msg)
	add(omsg_queue,msg)
end

function update_msgs()
	update_omsgs()
	update_imsgs()
end

function update_omsgs()
	if (peek(0x5f80)==1) return
 
	if (omsg==nil and count(omsg_queue)>0) then
		omsg=omsg_queue[1]
		del(omsg_queue,omsg)
	end 
		
	if (omsg!=nil) then
	 poke(0x5f80,1)
		memset(0x5f81,0,63)
		chunk=sub(omsg,0,63)
		for i=1,#chunk do
			poke(0x5f80+i,s2c[sub(chunk,i,i)])
		end
		omsg=sub(omsg,64)
		if (#omsg==0) then
			omsg=nil
			if (#chunk==63) poke(0x5f80,2)
		end
	end
end

function update_imsgs()
	control=peek(0x5fc0)
	if (control==1 or control==2) then
		for i=1,63 do
			char=peek(0x5fc0+i)
			if (char==0) then
				process_input()
				imsg=""
				break
			end
			imsg=imsg..c2s[char]
		end
		if (control==2) then
			process_input()
			imsg=""
		end
		poke(0x5fc0,0)
	end
end



function _init()
end



-- /api


-- utilities

frame = 0

function random_int()
	return flr(rnd(500))
end

function contains(tbl, val)
	for v in all(tbl) do
		if (v == val) return true
	end
	return false
end

function msg_arg(msg, idx)
	if (msg == nil) return nil
	
	split_msg = split_str(msg, "_");	
	
	--for k,v in pairs(split_msg) do
	--	print("msg_arg: "..idx..", "..k.."="..v)
	--end
	
	return split_msg[idx]
end

-- /utilities


-- constants

attack_time = 12
sword_x = { -1, 1, 0, 0 }
sword_y = { 0, 0, -1, 1 }
move_period = 20
hops = { 0, 0, 1, 2, 3, 3, 2, 1 }

-- /constants


-- players

characters = {}

id_letters = "abcdefghijklmnopqrstuvwxyz"

function get_id_letter()
	idx = abs(random_int()) % (#id_letters - 1)
	return sub(id_letters, idx, idx)
end

function new_player_id()
	new_id = get_id_letter()..get_id_letter()..get_id_letter()
	if (characters[new_id] == nil) then
		return new_id
	end
	return new_player_id()
end

-- /players

-- characters

function spawn_character(id, x, y)
	characters[id] = {}
	characters[id].facing = 1
	characters[id].x = x
	characters[id].y = y
	characters[id].world_x = x * tile_size
	characters[id].world_y = y * tile_size
	characters[id].attack = 0
	characters[id].health = 4
	characters[id].hurt_timer = 0
	characters[id].powered_up = 0
	characters[id].hopping = false
end

function send_character(id)
	send_msg(id..'_character_'..characters[id].x..'_'..characters[id].y..'_'..characters[id].facing..'_'..characters[id].attack..'_'..characters[id].health..'_'..characters[id].hurt_timer..'_'..characters[id].powered_up)
end

-- /characters

hearts = {}

function spawn_heart(x, y)
	newheart = {}
	newheart.x = x
	newheart.y = y
	newheart.life = 12
	add(hearts, newheart)
end

-- start game

function is_blocked_by(x, y)
	blocking_character = false
	for id, character in pairs(characters) do
		if character.x == x and character.y == y then
			return 'character', id
		end
	end
	
	if fget(mget(x, y), 1) then
		return 'nothing', ''
	end

	return 'terrain', ''
end

function move(id, dir)
	new_x = characters[id].x
	new_y = characters[id].y
	move_type = split_str(id, "-")[2]
	if (dir == "left") then
		new_x -= 1
		characters[id].facing = 1;
	end
	if (dir == "right") then
		new_x += 1
		characters[id].facing = 2;
	end
	if (dir == "up") then
		new_y -= 1
		characters[id].facing = 3;
	end
	if (dir == "down") then
		new_y += 1
		characters[id].facing = 4;
	end
	
	blocked_by, blocked_id = is_blocked_by(new_x, new_y)

	if blocked_by == 'nothing' then
		characters[id].x = new_x
		characters[id].y = new_y
	end

	if blocked_by == 'character' then
		blocked_type = split_str(blocked_id, "-")[2]
		if move_type == nil and blocked_type != nil then
			hurt_character(id, 1)
		elseif move_type != nil and blocked_type == nil then
			hurt_character(blocked_id, 1)
		else
			spawn_heart((characters[id].x + new_x) / 2, (characters[id].y + new_y) / 2)
		end
	end
end
 
function process_input()
	--print(imsg)
	id_arg = msg_arg(imsg, 1)
	if (id_arg == your_id) then
		return
	end
	
	arg1 = msg_arg(imsg, 2)
	arg2 = msg_arg(imsg, 3)
	arg3 = msg_arg(imsg, 4)
	arg4 = msg_arg(imsg, 5)
	arg5 = msg_arg(imsg, 6)
	arg6 = msg_arg(imsg, 7)
	arg7 = msg_arg(imsg, 8)
	arg8 = msg_arg(imsg, 9)
	
	if (arg1 == "character") then
		if (characters[id_arg] == nil) then
			spawn_character(id_arg, arg2, arg3)
			send_character(your_id)
		end
		characters[id_arg].x = arg2+0
		characters[id_arg].y = arg3+0
		characters[id_arg].facing = arg4+0
		characters[id_arg].attack = arg5+0
		characters[id_arg].health = arg6+0
		characters[id_arg].hurt_timer = arg7+0
		characters[id_arg].powered_up = arg8+0
		
		check_attack(characters[id_arg])
	end
end

-- init game

your_id = new_player_id()
spawn_character(your_id, (random_int() % 5) + 15, (random_int() % 10) + 5)
send_character(your_id)

monster_ids = { your_id.."-blob-0", your_id.."-blob-1"}

for monster_id in all(monster_ids) do
	spawn_character(monster_id, (random_int() % 5) + 15, (random_int() % 10) + 5)
	send_character(monster_id)
end


-- update game

function check_btns()
	if (btnp(0)) then 
		move(your_id, "left")
		send_character(your_id)
	end
	if (btnp(1)) then 
		move(your_id, "right")
		send_character(your_id)
	end 	
	if (btnp(2)) then 
		move(your_id, "up")
		send_character(your_id)
	end
	if (btnp(3)) then 
		move(your_id, "down")
		send_character(your_id)
	end 
	if (btnp(4) and characters[your_id].attack <= 0) then 
		characters[your_id].attack = attack_time
		send_character(your_id)
	end 
end


function check_attack(character)
	--if character.powered_up == nil then
		--character.powered_up = 0
	--end
	if character.attack == attack_time or character.powered_up > 0 then
		attack_distance = attack_time - character.attack + 1;

		-- chop weeds
		sword_pos_x = character.x + sword_x[character.facing] * attack_distance
		sword_pos_y	= character.y + sword_y[character.facing] * attack_distance

		-- chop weed
		if mget(sword_pos_x, sword_pos_y) == 38 then
			mset(sword_pos_x, sword_pos_y, 16)
		end

		-- power up with anvil
		if mget(sword_pos_x, sword_pos_y) == 57 then
			character.powered_up = 1
		end
		
		-- attack monster
		for id, hit_character in pairs(characters) do
			sprite_type = split_str(id, "-")[2]
			if hit_character.x == sword_pos_x and hit_character.y == sword_pos_y and sprite_type != nil then
				hurt_character(id, 1)
			end
		end
	end
end

function hurt_character(id, amount)
	hit_character = characters[id]
	hit_character.health -= amount
	-- register kill
	if (hit_character.health < 0) then
		send_msg('server_kill');
	end
	hit_character.hurt_timer = 10
	send_character(id)
end

function _update()	
	check_btns()
	
	check_attack(characters[your_id])
	
	for id, character in pairs(characters) do
		-- end of update
		if character.attack > 0 then
			character.attack -= 1
		end
		if character.hurt_timer > 0 then
			character.hurt_timer -= 1
		end
	end
	
	for monster_id in all(monster_ids) do
		character = characters[monster_id]

		-- respawn dead monsters
		if character.health <= 0 then
			spawn_x = random_int() % (16 * 3)
			spawn_y = random_int() % (16 * 2)
			if is_blocked_by(spawn_x, spawn_y) == 'nothing' then
				spawn_character(monster_id, spawn_x, spawn_y)
				send_character(monster_id)
			end
		end

		-- move monsters around randomly
		if frame % move_period == 0 and random_int() % 3 == 0 then
			if character.health > 0 then
				dirs = { 'left', 'right', 'up', 'down' }
				random_dir = dirs[random_int() % 4 + 1]
				move(monster_id, random_dir)
			end
		end
	end

	for idx, heart in pairs(hearts) do
		heart.life -= 1
		if heart.life <= 0 then
			del(hearts, heart)
		end
	end
	
	-- check server messages
	update_msgs()

	frame += 1
end

-- end game


-- start draw 
 
character_sprite = { blob=64 }
function draw_character(id, character, camera_x, camera_y)
	sprite_num = character.facing
	sprite_type = split_str(id, "-")[2]

	-- get sprite
	if sprite_type == nil then
		if character.health <= 0 then
			sprite_num = 6
		elseif character.hurt_timer > 0 then
			sprite_num = 5
		end
	else
		--if character.health <= 0 then
			--return
		--end

		sprite_num = character_sprite[sprite_type]
		if character.hurt_timer > 0 then
			sprite_num += 1
		end
	end


	-- calculate position
	new_world_x = character.world_x + (character.x * tile_size - character.world_x) * .1
	new_world_y = character.world_y + (character.y * tile_size - character.world_y) * .1
	
	-- check if moving, hop if so
	hop_y = 0
	if character.hopping or abs(new_world_x - character.world_x) + abs(new_world_y - character.world_y) > .5 then
		hop_y = hops[frame % #hops + 1]
		character.hopping = true
		if frame % #hops == 0 then
			character.hopping = false
		end
	end

	character.world_x = new_world_x
	character.world_y = new_world_y

	-- for going 16x16 screen by screen
	screen_x = character.world_x - camera_x * stage_size * tile_size
	screen_y = character.world_y - camera_y * stage_size * tile_size - hop_y
	
	-- for following every move
	--screen_x = character.world_x - (characters[your_id].x - stage_size / 2) * tile_size
	--screen_y = character.world_y - (characters[your_id].y - stage_size / 2) * tile_size
	
	-- find sprite
	-- todo: fix this
	
	
	-- draw sprite
	spr(sprite_num, screen_x, screen_y)
end

function draw_attack(character, camera_x, camera_y)
	attack_distance = attack_time - character.attack + 1;

	screen_x = character.world_x - camera_x * stage_size * tile_size
	screen_y = character.world_y - camera_y * stage_size * tile_size

	if character.attack > 0 then
		-- regular sword
		spr(111 + character.facing, screen_x + sword_x[character.facing] * tile_size, screen_y + sword_y[character.facing] * tile_size)

		-- shooting sword
		if character.powered_up > 0 then
			spr(115 + character.facing, screen_x + sword_x[character.facing] * attack_distance * tile_size, screen_y + sword_y[character.facing] * attack_distance * tile_size)
		end
	end
end

function draw_heart(heart, camera_x, camera_y)
	screen_x = (heart.x - camera_x * stage_size) * tile_size
	screen_y = (heart.y - camera_y * stage_size) * tile_size + heart.life - tile_size * 2

	if heart.life > 0 then
		spr(120, screen_x, screen_y)
	end
end
 
function _draw()
	cls()
	
	camera_x = flr(characters[your_id].x / stage_size)
	camera_y = flr(characters[your_id].y / stage_size)
	
	map(camera_x * stage_size, camera_y * stage_size)
	
	for id, character in pairs(characters) do
		draw_character(id, character, camera_x, camera_y)
	end
	for id, character in pairs(characters) do
		draw_attack(character, camera_x, camera_y)
	end
	for idx, heart in pairs(hearts) do
		draw_heart(heart, camera_x, camera_y)
	end
	
	print(characters[your_id].x..', '..characters[your_id].y)
end


-- end draw


__gfx__
00000000011111100111111001ffff10011111100111111001111110000000000000000000000000000000000000000000000000000000000000000000000000
000000001eeee221122eeee112222221122222211eeeeee11e2ee2e1000000000000000000000000000000000000000000000000000000000000000000000000
007007007ee7e221122e7ee712222221122222211e7ee7e11ee11ee1000000000000000000000000000000000000000000000000000000000000000000000000
000770001ee1e221122e1ee11eeeeee11eeeeee11e1ee1e11e2ee2e1000000000000000000000000000000000000000000000000000000000000000000000000
00077000ffffe221122effff1eeeeee11e7ee7e11effffe11effffe1000000000000000000000000000000000000000000000000000000000000000000000000
00700700ffffe221122effff1eeeeee11e1ee1e11effffe11effffe1000000000000000000000000000000000000000000000000000000000000000000000000
000000001eeee221122eeee11eeeeee11effffe11222222112222221000000000000000000000000000000000000000000000000000000000000000000000000
0000000001111110011111100111111001ffff100111111001111110000000000000000000000000000000000000000000000000000000000000000000000000
333333333ccccccc7b7ccccccccccccbccccc7b7bb333333b3333333333333bb33333333cccc1113111cc3cc3d555333cccccccccccccccccccccccc00000000
333333333ccccccc3337bccccccccccbcccb733311bbb333b33333333333bb1133333333ccc3ccc1ccc33cccdc555133cccccccccbcbbcccccbbcccc00000000
333333333ccccccc33333bcccccccccbcc733333cc113b33b3333333333b11cc33333331cccc333c333ccccc15551333cccccccccccccccccccccccc00000000
333333333bcccccc3333333cccccccb3cb33333333cc1333cb3333333331cc3333333331ccccccc3cccccccc31113333cccccccccccccccccccccccc00000000
333333333bcccccc3333333ccccccc73cb333333cc33c133cb333333331c33cc3333331ccccccccccccccccc333dd553ccccccccccbbbbcccbbccbbc00000000
3333333333bccccc33333333ccccc733b3333333cccc3c13c1b3333331c3cccc33333b1ccccccccccccccccc31dc5555cccccccccccccccccccccccc00000000
33333333333bbccc33333333ccc7b333b3333333ccccc3c3cc1bb3333c3ccccc333bb1cccccccccccccccccc3b155551cccccccccccbbcbcccccbbcc00000000
3333333333333bbb33333333b7b33333b3333333ccccccc3ccc11bbb3cccccccbbb11ccccccccccccccccccc33331113cccccccccccccccccccccccc00000000
ccccccccb3bbbbb31ccccccccccccccb3333333333333333333333333333bbb33333333333333333333333332444444424444421ccccccccc3cccc3ccbbbcccc
cccccccc111111113ccccccccccccccb33333333333333333bbb3333333bb1b33bbb3333333333b3333333334444444244444442ccc333ccccc33cccc3bbcccc
cccccccccccccccc1cccccccccccccc733333333333333333b1b3b333b231b333b1bb3b33b3333b333dddd334444442144444442cc33333ccccccccccbbccccc
cccccccc333333331ccccccccccccccb33333333333333333b313133b33132bb3b313b133b33b3333d6dddd34444441344444442cc333ccccccccccccc3cbbcc
cccccccccccccccc1cccccccccccccc73333333333333333331112333131331b3311132333333b3315dddd514444441344444442cc33333ccccccccccccbb3cc
cccccccccccccccc1ccccccccccccccb33333333333333333b211233231111323221123333b33b33315d55134444442144444442ccc333cccccccccccccbbbcc
cccccccccccccccc1ccccccccccccccb333333333333333333212133321111233312211133b33333333113332444444244211242ccccbccccccccccccccc3ccc
b7bb7b7bcccccccc3cccccccccccccc7333333333333333333333333333223333331111333333333333333331222222242133122cccccccccccccccccccccccc
5666665333333333366d666301222221012222210122222133eeeee331222221337777733d515553333377330000000000000000000000000000000000000000
6d555d6335d553335ddddd531222222212222222122222223eeeeeee1222222237777777d551555d333733730000000000000000000000000000000000000000
6511156355666d336d666d662221212222212122222121223eed77de222121223777776711515551333377330000000000000000000000000000000000000000
650005615ddddd5dddddd5dd12dd11dd12dd11dd12dd11dd3e7ed7de12dd11dd377d66d635111115333333330000000000000000000000000000000000000000
56666651666d6665666d6663312dd1d1012dd1d1012dd1d132ee7de2312dd1d13e777d6e3d50005d337733330000000000000000000000000000000000000000
dd5dd5513dddd533ddddd53333111213001112133311121033222d233311121333eeede335511155373373330000000000000000000000000000000000000000
1dd5dd11336663336d666d6633112211001122113311221133115d513311221133115d5131111111337733330000000000000000000000000000000000000000
3111111333333333d3d5ddd33331111300311113333111103331111333311113333111133555555d333333330000000000000000000000000000000000000000
00000000000000000011110000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001111000011110001dddd1001888810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
017bb710017887101d7dd7d118788781000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e1bb1e00e1881e01d0dd0d118088081000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01bbbb100188881001dddd1001888810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1b1111b11811118101d11d1001811810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13bbbb31128888211d1661d118188181000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01111110011111100101101001011010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000770000001100000000000000000000007700000a00a000000000000000000000000000000000000000000000000000000000000000000
00000000000000000007700000011000000000000000000000777700000000000000000000000000000000000000000000000000000000000000000000000000
0000001000100000000770000011110007aaaa0aa0aaaa7000a77a0000a99a000011011000000000000000000000000000000000000000000000000000000000
77777711111777770007700000077000777aa900009aa77700aaaa0000aaaa000178188100000000000000000000000000000000000000000000000000000000
77777711111777770007700000077000777aa900009aa77700aaaa0000aaaa000188888100000000000000000000000000000000000000000000000000000000
0000001000100000000770000007700007aaaa0aa0aaaa7000a99a0000a77a000018881000000000000000000000000000000000000000000000000000000000
00000000000000000011110000077000000000000000000000000000007777000001810000000000000000000000000000000000000000000000000000000000
00000000000000000001100000077000000000000000000000a00a000007700000001000000000000000000000000000000000000000000000000000000000c1
c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1616363636363000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1d1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1911212121212000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1f2c1c1c1c1c1c1000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1e1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1d1c1e1c1c1c1c1c1e1c1c1d1c1c1c1c1c1000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1d2c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1e1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c1
c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000002000200020002000200000000000000000000000202000000020002020000000002020000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000003433333333221c1c233333333335003435000000000000343333333500000000003433350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00343433361025181c1c2f1c1636243636373736373500003433363636363733333333333333333333333500343500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
343336361024171a1c1c1d1c192115291024363636373737373737363610363629102a1b3636363636373733333500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
343610101010221e1c1c201c2d2f23101036373636373637371b1026101010101010101024101010101036372a3335000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
343610102610221c1c1410121c1e231010103636363637372a10101010101024102629101036382910263636373500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0034361010181c2f231010101120131010362936363636361026102910241010101010242629311024362a36373733350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00342410171a1c1c131026101010261025101010293636101010101721212121151b10291010321036363636373733333500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3437101b222d1c14101010102a1b101010101010102410101010182d1c1c2f1c232910171510293126361036373737373500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
343710262c2c2c2c102410101b1b1010102410101010101017211a1c1c1e1c1c1c16181c1c16101010101010101037373500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3436261b171a2e1921151010101b2a291010101010101026222f1c1d1c1c1c1c1c191a1c2f19211510101025101037373735000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3436101b111c2d1c1c23101029101b1010101010101010101120201c1c1c1d1c2f1c1c2d1c1c201310101010101037373733350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3437102610121e1c2f1c1610101010102510101010101010102a1b121c1c1c1c1c1c1c1e1c141010292a1010101037373737350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34361010241011201c2d192115101010101010101024361010103610221c1c1c1c1c1c1c2310311010252910101036373735000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
343636101010101b121c1d1c1c1626101010101010101010261010181d1c2f1c1c1c1c1c231b321039101b10253636373737350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34363636261010102611202f1c192121153610102a1b10101025171a2d1c1c2f1e1c1c2f231b313232323110103636373735000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3436363610252925101010121c1d1c2d2310241b1b1b10101010221c1c1c1e1c1c1c1e2d2310293232311010103636363735000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34372a362410101010241029222d2f1c2310101b1b2a1010101011201c1c2d1c1c1c20201310101024102510103636373500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
343736101036101010101036111c1c1e231010323110102510102610121c1c2f1c1410101010101031101010103637373500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
343710291010101010101010102c2c2c2c2c313225101010102410102c2c2c2c2c2c10101010102510102610101037373500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34373610241010103626101010172121151b323110101026291721211a2e2e2e2e1b1b2a2610101010101010101036373500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34373736101010251029101010222f2d1c16241010101010182d1c2020202020131b10292410101010101010101036363500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
342a3736362910101010101010111c1d1c191510101721211a1c141010361010291010101b2a101010101010101024363335000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3437373610101010101025101010121c1c1c1c2b181c2f1c2013361010103610101010102a1b102410101010362a36363733350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
003436381024301010102a1b2a1010221c2d1c2b1a1c1c143636383610101010101010101010101025102536363737363733350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
003436101010262a10101b2a1b29181c1c1c1c2b202013101010101010101010101010101010101010103636373637373733350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
343437101010101010262a1b17211a2f1c1c2f2b2a1b25101010311010101024101010102410251010103636363737373733350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3437101038361010102a1b1b221d1c2d1c1c132610103132323132312a101010101010101010102510362436373737373535000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3436102910102410101b2a29221c1c1c1c141025101010102632303231321010101010101010103636333636363335000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3436101010101010101010181c1c1c1c23251010103129101032323126102410101010102536363737373737350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34371010172121212121211a2f1c2c2c2c2c1010101017212121212121212121211510263636373737373335000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
343736181c1c2f1c1c1d1e1c2d1c2e2e2e16101b10181c1c2d2f1c1d1c1c2d1e2f2337373737373737373500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2121211a1c1c1c1c2f1c1c1c1c2f1c2d1c192121211a2f1c1e1c1c1c2f1c1d1c1c2336363737373500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
