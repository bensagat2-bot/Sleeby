--[[
    meowlua private — Sleepy Hub UI port (FULL, mobile-friendly, toggle button)
    • 5 top-level tabs (Main, Combat, Defense, Misc, Settings) — rail fits on phone
    • Content scrolls fine (library native)
    • Standalone Toggle UI button in separate ScreenGui
    • Every feature wired, no stubs
]]

-- ============================================================
-- 1. AC LIBRARY
-- ============================================================
local AC = {}
AC.LoaderGate = {}
AC.LoaderGate.STATE_KEY = "_________MEOW_MEOW_MEOW67"
function AC.LoaderGate.getState() return getgenv()[AC.LoaderGate.STATE_KEY] end
function AC.LoaderGate.setState(v) getgenv()[AC.LoaderGate.STATE_KEY] = v end
AC.LoaderGate.EXPECTED_BYTECODE = {
	Root = { [1914481512] = false },
	ReplicatedController = { [1936447744] = false },
	MiscellaneousController = { [3892767096] = false, [337076960] = false },
	LocalScript3 = { [3892767096] = false, [337076960] = false },
	ClientFighter = { [2191862192] = false },
}
local function sumHash(t)
	local h = 0
	for _, v in pairs(t) do if type(v) ~= "number" then return 0 end h = h + v end
	return h
end
function AC.LoaderGate.verifyGameFiles()
	local expected = AC.LoaderGate.EXPECTED_BYTECODE
	local deadline = tick() + 60
	while tick() < deadline do
		for _, scr in getscripts() do
			local bucket = expected[scr.Name]
			if bucket == nil then continue end
			local ok, bytecode = pcall(getscriptbytecode, scr)
			if not ok or bytecode == nil then continue end
			local h = sumHash(bytecode)
			if bucket[h] == false then bucket[h] = true end
		end
		local missing = false
		for _, bucket in expected do
			local satisfied = false
			for _, hit in bucket do if hit then satisfied = true break end end
			if not satisfied then missing = true break end
		end
		if not missing then return true end
		task.wait(0.5)
	end
	return false
end
function AC.LoaderGate.bypass1() local d = tick() + 10 while tick() < d do task.wait(1.5) end return true end
function AC.LoaderGate.bypass2(indexFn, storeSlot)
	while true do
		for _, obj in getgc(true) do
			if type(obj) ~= "table" then continue end
			if indexFn(obj, "GetCameraData") ~= nil then storeSlot[1] = obj return true end
		end
		task.wait()
	end
end
function AC.LoaderGate.run(indexFn)
	local LocalPlayer = cloneref(game:GetService("Players")).LocalPlayer
	local state = AC.LoaderGate.getState()
	if state == "Loaded" then return true end
	if state == "Loading" then repeat task.wait() until AC.LoaderGate.getState() == "Loaded" return true end
	AC.LoaderGate.setState("Loading")
	repeat task.wait() until game:IsLoaded()
	if not AC.LoaderGate.verifyGameFiles() then LocalPlayer:Kick("Not all game files are what we expected..") return false end
	if not AC.LoaderGate.bypass1() then LocalPlayer:Kick("Failed bypass 1") return false end
	if not AC.LoaderGate.bypass2(indexFn, {}) then LocalPlayer:Kick("Failed bypass 2") return false end
	AC.LoaderGate.setState("Loaded") return true
end

AC.CameraCodec = {}
function AC.CameraCodec.encodeSingle(a)
	if a == a then return utf8.char(math.clamp(math.floor(a % (2*math.pi) / math.pi / 2 * 256 + 0.5), 0, 255)) end
	return utf8.char(0)
end
function AC.CameraCodec.encodeCameraRotation(v)
	if v == v then
		return utf8.char(math.clamp(math.floor(v.X % (2*math.pi) / math.pi / 2 * 256 + 0.5), 0, 255))
			.. utf8.char(math.clamp(math.floor(v.Y % (2*math.pi) / math.pi / 2 * 256 + 0.5), 0, 255))
	end
	return utf8.char(0) .. utf8.char(0)
end
function AC.CameraCodec.decodeSingle(s) return utf8.codepoint(s) * math.pi * 2 / 256 end
function AC.CameraCodec.fromXYToCameraRotation(x, y) return Vector2.new(x, y) * math.pi * 2 / 256 end
function AC.CameraCodec.decodeCameraRotation(v) return AC.CameraCodec.fromXYToCameraRotation(utf8.codepoint, v) end

AC.Humanization = {
	Flick = { DurationMs = { Min = 30, Max = 400 }, Curvature = { Min = 0, Max = 50 }, Humanness = { Min = 0, Max = 100 } },
	Firing = { ShotDelayMs = { Min = 0, Max = 250 }, CooldownMs = { Min = 0, Max = 2000 } },
}
AC.EnvAudit = {}
AC.EnvAudit.CLASSIFIERS = {"islclosure","iscclosure","isourclosure","isexecutorclosure","checkclosure","isnewcclosure","isfunctionhooked"}
AC.EnvAudit.TARGETS = {"__index","__newindex","FireServer","FireServerUnreliable","FindFirstChildOfClass","getrawmetatable","setrawmetatable","sethiddenproperty","clonefunction","hookfunction","replaceclosure","restorefunction","oth_is_hook_thread","oth_get_root_callback","oth_get_original_thread","islclosure","iscclosure","isourclosure","isexecutorclosure","checkclosure","isnewcclosure","isfunctionhooked","GetMouse"}
AC.Sentinel = { slots = 30, guarded = { [2]="f10436", [8]="print", [17]="f10434" }, statusBytes = {147,218,250} }
AC.DevModeGlobals = {"LUARMOR_SkipAntidebugDevMode","LUARMOR_AllowKeyCheckSkip"}

-- ============================================================
-- 2. BOOT GUARDS
-- ============================================================
local environment = getgenv()
local previous_unload = rawget(environment, "unload_all")
if type(previous_unload) == "function" then pcall(previous_unload) end
environment.unload_all = nil
environment.__meowlua_generation = (tonumber(environment.__meowlua_generation) or 0) + 1
local load_generation = environment.__meowlua_generation
environment.meowlua_loaded = false
environment.meowlua_loading = true
if not game:IsLoaded() then
	local deadline = os.clock() + 30
	repeat task.wait(0.1) until game:IsLoaded() or os.clock() >= deadline
end
if not game:IsLoaded() then environment.meowlua_loading = false return AC end

-- ============================================================
-- 3. SERVICES
-- ============================================================
local players = game:GetService("Players")
local localplayer = players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local user_input_service = game:GetService("UserInputService")
local run_service = game:GetService("RunService")
local virtual_user = game:GetService("VirtualUser")
local workspace = game:GetService("Workspace")
local http_service = game:GetService("HttpService")
local teleport_service = game:GetService("TeleportService")
local lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

-- ============================================================
-- 4. CONFIG DEFAULTS
-- ============================================================
getgenv().config = {
 riot_abuser_v1_enabled=false,riot_abuser_v1_spin_speed=720,riot_abuser_v1_tracking_position="Behind",riot_abuser_v1_tracking_distance=3,
 et_order="spiral",et_mode="Random",et_speed=1000,et_total=1000,riot_bypass_enabled=false,riot_bypass_distance=3,riot_bypass_position="Behind",
 riot_bypass_height=0,riot_bypass_update_rate=0.5,riot_bypass_snap=false,riot_abuser_v2_enabled=false,riot_abuser_v2_spin_speed=720,riot_abuser_v2_xjitter=30,riot_abuser_v2_yjitter=8,riot_abuser_v2_spread=300,
 anti_afk_enabled=false,autocollect_enabled=false,autocollect_radius=120,return_home_enabled=false,home_return_delay=1.0,
 safe_zone_enabled=false,safe_zone_y=-10,teleport_loop_enabled=false,teleport_loop_delay=0.5,ffa_hopping_enabled=false,
 spin_shot_enabled=false,
 slingshot_bypass_enabled=false,slingshot_bypass_range=100000000000000,slingshot_bypass_manipulation=true,slingshot_bypass_tp=true,
 bow_bypass_enabled=false,dagger_bypass_enabled=false,projectile_tp_enabled=false,projectile_tp_part="HumanoidRootPart",projectile_rapid_fire_proj_enabled=false,
 melee_bypass_enabled=false,melee_bypass_y_range=10,
 teleport_to_target_enabled=false,teleport_to_target_sync_to_ragebot=false,teleport_to_target_search_radius=999e15,
 teleport_to_target_mode="Closest",teleport_to_target_priority="",teleport_to_target_position="Exact",
 teleport_to_target_method="Adaptive",teleport_to_target_offset_dist=3,teleport_to_target_aim_lead=false,
 teleport_to_target_stagger=1,teleport_to_target_lock=false,teleport_to_target_lock_key="",
 teleport_to_target_aggression=3,teleport_to_target_auto_face=false,teleport_to_target_failsafe=true,
 teleport_to_target_snap_count=4,teleport_to_target_throttle=0,teleport_to_target_through_walls=true,
 teleport_to_target_recover_void=true,teleport_to_target_jitter=0,teleport_to_target_y_offset=0,
 teleport_to_target_orbit_mode=false,teleport_to_target_orbit_radius=5,teleport_to_target_orbit_speed=90,
 teleport_to_target_burst_mode=false,teleport_to_target_burst_count=3,teleport_to_target_randomize_pos=false,
 teleport_to_target_ghost_step=false,teleport_to_target_ghost_dist=500,teleport_to_target_velocity_kill=true,teleport_to_target_snap_face=false,
 vst_attack_method="Adaptive",ui_keybind="RightControl",ui_lock_keybind="LeftControl",
 vs_pos_resolver=false,vs_predictive_sync=false,vs_protocol="Adaptive",vs_pos_restore=false,
 vs_min_dist=1,vs_max_dist=50000,vs_char_origin=false,
 vs_dir_xp=5000,vs_dir_xn=5000,vs_dir_yp=5000,vs_dir_yn=5000,vs_dir_zp=5000,vs_dir_zn=5000,vs_radius=50000,
 vs_stabilizer_enabled=false,vs_stability=50,vs_movement="Random",vs_smoothness_enabled=false,vs_smoothness=10,vs_interval=1,
 vs_depth_bias=0,vs_chaos_amp=1,vs_burst_delay=0,vs_axis_lock_strength=0,
 evs_direction="Down",evs_distance=50000,evs_void_tick=60,evs_iter_radius=500000,evs_phase_shift=0,evs_amplitude=1,evs_frequency=1,
 evs_spread=500,evs_orbit_radius=10000,evs_orbit_speed=5,evs_spiral_tightness=1,evs_jitter=0,evs_y_bias=0,evs_burst=100,evs_layer_count=1,
 evs_pattern="Linear",evs_axis="Y",evs_falloff="None",evs_blend_mode="Replace",evs_auto_reverse=false,evs_kill_velocity=true,
 evs_warp_mode="Instant",evs_gravity_mult=1,evs_rotation_chaos=false,evs_snap_back=false,evs_snap_back_delay=0,evs_layer_offset=0,
 evs_axis_clamp=0,evs_turbulence=0,evs_echo_count=0,evs_echo_decay=0.5,evs_invert_x=false,evs_invert_y=false,evs_invert_z=false,
 evs_pattern2="None",evs_blend_weight=0.5,
 vs_dir_mode="Uniform",vs_radial_scale=1,vs_vertical_bias=0,vs_horizontal_lock=false,vs_chaos_mode="Off",vs_chaos_intensity=1,
 vs_pulse_rate=1,vs_warp_bias=0,vs_gravity_drain=false,vs_eccentricity=0,vs_enter_delay=0,vs_exit_delay=0,vs_snap_mode="Instant",
 vs_burst_shape="Random",vs_recoil_comp=false,vs_recoil_scale=1,vs_pos_clamp=false,vs_pos_clamp_radius=50000,vs_scatter_seed=1,
 vs_phase_mode="Off",vs_dir_blend="None",vs_layer_mix="Sequential",vs_burst_fade=false,vs_burst_fade_alpha=0.5,vs_momentum_carry=false,
 vs_momentum_scale=1,vs_angular_noise=0,vs_void_gate=false,vs_void_gate_dist=10000,
 evs_sync_to_ragebot=false,evs_scatter_mode="Random",evs_burst_profile="Flat",evs_tick_jitter=0,evs_invert_burst=false,evs_clamp_radius=0,
 evs_orbit_lock=false,evs_wave_freq=1,evs_depth_floor=0,evs_axis_weight_x=1,evs_axis_weight_y=1,evs_axis_weight_z=1,evs_burst_stagger=0,
 evs_layer_blend="Add",evs_pulse_sync=false,evs_gravity_dir="Down",evs_spin_lock=false,
 vst_enabled=false,vst_spin_speed=1e85,vst_type="Unhittability",vst_unhittability_y_range=10,vst_defend_intensity=50,
 vst_hide_time=0.3,vst_attack_time=0.3,vst_translocation_intensity=50,vst_hide_mode="Defend",
 vst_defend_proximity_escape=true,vst_defend_proximity_radius=20,vst_defend_escape_dist=1000,vst_bait_depth=20,
 vst_defend_x_dist=10000,vst_defend_y_dist=10000,vst_defend_z_dist=10000,vst_attack_tracking_type="Teleportation",
 vs_void_direction="Random",void_hide_x=1e6,void_hide_y=9e25,void_hide_enabled=false,void_hide_sync_to_ragebot=false,void_hide_z=1e6,
 pixel_enabled=false,pixel_count=8,anti_void_bait_freeze=false,anti_void_bait_hide=false,
 fake_pos_enabled=false,fake_pos_radius=500,fake_pos_height=0,fake_pos_speed=50,fake_pos_count=5,
 fake_pos_drop1="Scatter",fake_pos_drop2="Random",fake_pos_drop3="None",fake_pos_drop4="Linear",fake_pos_drop5="Off",
 fake_pos_tog1=false,fake_pos_tog2=false,fake_pos_tog3=false,fake_pos_tog4=false,fake_pos_tog5=false,
 desync_enabled=false,desync_intensity=50,desync_speed=10,desync_angle=90,desync_jitter=20,desync_flip=false,
 desync_unhittable_enabled=false,desync_unhittable_intensity=50,desync_unhittable_radius=9000,desync_unhittable_iters=100,desync_unhittable_y_range=10,
 vs_warp_multiplier=1,vs_scatter_radius=500000,vs_depth_mult=1,vs_rebound_strength=0,vs_axis_spin=0,vs_frequency_mod=1,
 vs_position_noise=0,vs_burst_gap=0,vs_entropy_mod=0,vs_gravity_strength=0,
 orbit_enabled=false,orbit_radius=50000,orbit_speed=5,orbit_height=0,orbit_iters=100,orbit_jitter=0,
 orbit_pattern="Circle",orbit_target="Closest",orbit_axis="Y",orbit_direction="Clockwise",orbit_warp_mode="Instant",
 orbit_warp_strength=50,orbit_falloff="None",orbit_phase_offset=0,orbit_layer_count=1,orbit_layer_offset=0,orbit_wave_freq=1,
 orbit_tightness=10,orbit_kill_velocity=true,orbit_sync_ragebot=false,orbit_chaos_blend=0,orbit_invert_x=false,orbit_invert_z=false,
 orbit_y_bias=0,orbit_depth_floor=0,
 vs_turbulence_freq=1,vs_turbulence_amp=1,vs_vortex_strength=0,vs_vortex_radius=10000,vs_layer_twist=0,vs_quantum_jump_prob=0,
 vs_quantum_jump_scale=1,vs_fractal_depth=1,vs_fractal_scale=1,vs_echo_trail=0,vs_echo_decay_rate=0.5,
 vs_gravity_vector_x=0,vs_gravity_vector_y=-1,vs_gravity_vector_z=0,vs_scatter_seed_mode="Random",vs_depth_pulse_freq=1,vs_depth_pulse_amp=0,
 vs_spiral_offset_x=0,vs_spiral_offset_z=0,vs_node_gravity=false,vs_flux_reversal=false,vs_axis_wobble=0,vs_chaos_feedback=false,
 vs_void_gate_mode="Instant",godmode_enabled=false,godmode_y_range=10,anti_aim_enabled=false,
 anti_aim_spin_speed=1e85,anti_aim_pitch=0,anti_aim_roll=0,anti_aim_jitter=0,
 perfect_block_enabled=false,perfect_block_target="",perfect_block_cover_front=false,perfect_block_cover_left=false,perfect_block_cover_right=false,
 sounds_enabled=false,sounds_toggle_sound="rbxassetid://9120386954",
 fly_enabled=false,fly_speed=60,fly_noclip=false,fly_gravity_cancel=true,
 bm_enabled=false,bm_pitch=90,bm_yaw=90,bm_randomangle=false,bm_minangle=30,bm_maxangle=60,
 anti_aim_angle="Down",anti_aim_method="Pixelation",anti_aim_custom_angle=0,
 prediction_enabled=false,prediction_activation_range=20,prediction_distance_range=30,
 void_mimic_enabled=false,void_mimic_learn_rate=0.85,
 kicia_counter_enabled=false,kicia_voidspam_enabled=false,
 ui_font="GothamMedium",
 magic_bullet_enabled=false,magic_bullet_hitchance=100,magic_bullet_closest_part=true,
 profile={skinchanger={enabled=false,userid="1"},fpsspoof={enabled=false,value="1",fraud=false},msspoof={enabled=false,value="1",fraud=false},regionspoof={enabled=false,value=".gg/meowwc"}},
}

getgenv().all_connections = {}
getgenv().loop_waypoints = {}
getgenv().loop_index = 1
local config = getgenv().config
local configs_folder = "meowlua private/configs"
if not isfolder("meowlua private") then makefolder("meowlua private") end
if not isfolder("meowlua private/configs") then makefolder("meowlua private/configs") end
if not isfolder("meowlua private/themes") then makefolder("meowlua private/themes") end

local function notify(title, content)
	pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {Title=title, Text=content, Duration=3}) end)
end

-- ============================================================
-- 5. CONFIG SAVE/LOAD
-- ============================================================
getgenv().save_cfg = function(name)
	if not name or name == "" then name = "default" end
	local path = configs_folder .. "/" .. name .. ".json"
	local data = {AutoLoadConfig=config.autoload_config, LastLoadedConfig=name, full_config=config}
	local ok, encoded = pcall(http_service.JSONEncode, http_service, data)
	if ok and encoded then
		local w_ok = pcall(writefile, path, encoded)
		if w_ok then notify("Config", "Saved: " .. name) return true end
	end
	notify("Config", "Failed to save config.") return false
end
getgenv().load_cfg = function(name)
	if not name or name == "" then name = "default" end
	local path = configs_folder .. "/" .. name .. ".json"
	if not isfile(path) then notify("Config", "Not found: " .. name) return false end
	local ok, raw = pcall(readfile, path)
	if not ok then notify("Config", "Failed to read config.") return false end
	local s, d = pcall(http_service.JSONDecode, http_service, raw)
	if s and d and d.full_config then
		config.autoload_config = d.AutoLoadConfig or true
		config.last_loaded_config = name
		for k, v in pairs(d.full_config) do if config[k] ~= nil and type(config[k]) == type(v) then config[k] = v end end
		notify("Config", "Loaded: " .. name) return true
	end
	notify("Config", "Corrupted config file.") return false
end
getgenv().delete_cfg = function(name)
	if not name or name == "" or name == "default" then notify("Config", "Cannot delete default.") return false end
	local path = configs_folder .. "/" .. name .. ".json"
	if not isfile(path) then notify("Config", "Not found.") return false end
	local ok = pcall(delfile, path)
	if ok then notify("Config", "Deleted: " .. name) return true end
	notify("Config", "Failed to delete.") return false
end
getgenv().list_cfgs = function()
	if not isfolder(configs_folder) then return {} end
	local list = {}
	local ok, files = pcall(listfiles, configs_folder)
	if ok and files then for _, f in ipairs(files) do local m = f:match("([^/\\]+)%.json$"); if m then table.insert(list, m) end end end
	table.sort(list) return list
end

-- ============================================================
-- 6. UTILITY
-- ============================================================
getgenv().get_hrp = function(plr)
	local p = plr or localplayer
	if not p.Character then return nil end
	return p.Character:FindFirstChild("HumanoidRootPart")
end
getgenv().safe_teleport = function(pos)
	local hrp = getgenv().get_hrp(localplayer); if not hrp then return end
	local x, y, z = pos.X, pos.Y, pos.Z
	y = math.clamp(y, 2, hrp.Position.Y + 800)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = {localplayer.Character}
	local hit = workspace:Raycast(Vector3.new(x, y + 60, z), Vector3.new(0, -220, 0), p)
	if hit then y = math.max(hit.Position.Y + 3, 2) end
	hrp.CFrame = CFrame.new(x, y, z)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
end
local cached_target, last_target_tick = nil, 0
getgenv().get_closest = function(check_ff)
	local now = tick()
	if now - last_target_tick < 0.1 and cached_target and cached_target.Character then
		local ct_hrp = cached_target.Character:FindFirstChild("HumanoidRootPart")
		local ct_hum = cached_target.Character:FindFirstChild("Humanoid")
		if ct_hrp and ct_hum and ct_hum.Health > 0 then
			if not check_ff or not cached_target.Character:FindFirstChildOfClass("ForceField") then return cached_target end
		end
	end
	last_target_tick = now
	local closest, min_d = nil, math.huge
	local hrp = getgenv().get_hrp(localplayer); if not hrp then return nil end
	for _, p in ipairs(players:GetPlayers()) do
		if p ~= localplayer and p.Character then
			if not (check_ff and p.Character:FindFirstChildOfClass("ForceField")) then
				local t_hrp = p.Character:FindFirstChild("HumanoidRootPart")
				local hum = p.Character:FindFirstChild("Humanoid")
				if t_hrp and hum and hum.Health > 0 then
					if localplayer.Team == nil or p.Team == nil or localplayer.Team ~= p.Team then
						local d = (hrp.Position - t_hrp.Position).Magnitude
						local sr = config.teleport_to_target_search_radius or 999e15
						if d < min_d and d <= sr then min_d = d; closest = p end
					end
				end
			end
		end
	end
	cached_target = closest return closest
end

-- ============================================================
-- 7. MANIPULATION
-- ============================================================
local manip_ray_params = RaycastParams.new()
local manip_offsets = {Vector3.new(0,12,0),Vector3.new(0,16,0),Vector3.new(0,20,0),Vector3.new(0,24,0),Vector3.new(0,28,0),Vector3.new(0,32,0),Vector3.new(0,36,0),Vector3.new(0,40,0)}
local manipulation = {}
do
 manipulation.get_closest = function()
  if not localplayer.Character or not localplayer.Character:FindFirstChild("HumanoidRootPart") then return nil, nil end
  local target, char, dist = nil, nil, math.huge
  for _, v in next, players:GetPlayers() do
   if v ~= localplayer and v.Character and v.Character:FindFirstChild("Head") then
    local mag = (localplayer.Character.HumanoidRootPart.Position - v.Character.Head.Position).Magnitude
    if mag < dist then dist = mag; target = v.Character.Head; char = v.Character end
   end
  end
  return target, char
 end
 manipulation.calculate_point = function(origin, target_pos, target_char)
  manip_ray_params.FilterDescendantsInstances = {localplayer.Character, target_char}
  manip_ray_params.FilterType = Enum.RaycastFilterType.Exclude
  if not workspace:Raycast(origin, target_pos - origin, manip_ray_params) then return origin, nil end
  for _, offset in next, manip_offsets do
   local scan_pos = origin + offset
   if not workspace:Raycast(scan_pos, target_pos - scan_pos, manip_ray_params) then return scan_pos, offset.Y end
  end
  return nil, nil
 end
 manipulation.fire_toward = function(target_part, target_char)
  pcall(function()
   local rs = game:GetService("ReplicatedStorage")
   local util_ok, util = pcall(require, rs.Modules.Utility)
   local enums_ok, enums = pcall(require, rs.Modules.EnumLibrary)
   local fighter_ok, fighter = pcall(require, localplayer.PlayerScripts.Controllers.FighterController)
   if not util_ok or not enums_ok or not fighter_ok then return end
   if not fighter.LocalFighter then return end
   local item = fighter.LocalFighter.EquippedItem
   if not item then return end
   local cam = workspace.CurrentCamera.CFrame
   local manip_pt, height = manipulation.calculate_point(cam.Position, target_part.Position, target_char)
   if not manip_pt then return end
   local shoot_pos = (height == nil and manip_pt) or cam.Position
   local cameradata = {}
   cameradata[utf8.char(1)] = {
    [utf8.char(0)] = util:EncodeCFrame(CFrame.new(shoot_pos.X, shoot_pos.Y + (height or 0), shoot_pos.Z) * CFrame.Angles(CFrame.lookAt(shoot_pos, target_part.Position):ToOrientation())),
    [utf8.char(1)] = height and util:EncodeCFrame(CFrame.new(target_part.Position) * CFrame.Angles(CFrame.lookAt(shoot_pos, target_part.Position):ToOrientation())) or util:EncodeCFrame(CFrame.new(shoot_pos.X, shoot_pos.Y + (height or 0), shoot_pos.Z) * CFrame.Angles(CFrame.lookAt(shoot_pos, target_part.Position):ToOrientation())),
    [utf8.char(2)] = target_part,
    [utf8.char(3)] = util:EncodeCFrame(target_part.CFrame:ToObjectSpace(CFrame.new(target_part.Position))),
   }
   rs.Remotes.Replication.Fighter.UseItem:FireServer(item:Get("ObjectID"), enums:ToEnum("StartShooting"), cameradata, nil)
  end)
 end
end

-- ============================================================
-- 8. SOUND SYSTEM
-- ============================================================
local astral_sound_ids = {Space="rbxassetid://719384308",Pop="rbxassetid://140323850218372",Bonk="rbxassetid://18794851884",Skeet="rbxassetid://83717596220569",Neverlose="rbxassetid://97643101798871",Slip="rbxassetid://70557734865364"}
local astral_sound_volume = 0.5
local astral_sound_selected = "Space"
local astral_sound_service = game:GetService("SoundService")
local astral_toggle_sound = Instance.new("Sound", astral_sound_service)
astral_toggle_sound.SoundId = astral_sound_ids[astral_sound_selected]
astral_toggle_sound.Volume = astral_sound_volume
local function play_toggle_sound()
	if not config.sounds_enabled then return end
	pcall(function()
		astral_toggle_sound.SoundId = astral_sound_ids[astral_sound_selected] or astral_sound_ids.Space
		astral_toggle_sound.Volume = astral_sound_volume
		astral_toggle_sound.PlaybackSpeed = math.random(95, 105) / 100
		astral_toggle_sound:Play()
	end)
end
getgenv().play_toggle_sound = play_toggle_sound

-- ============================================================
-- 9. SHARED STATE
-- ============================================================
local melee_active = false
local melee_fake_cf_store = {}
local MELEE_FAKE_OFFSET = Vector3.new(9000, 9000, 9000)

-- ============================================================
-- 10. MELEE BYPASS
-- ============================================================
local melee_conn = nil
local function melee_in_y_range(my_hrp, target_hrp)
	local range = config.melee_bypass_y_range or 10
	local y_diff = my_hrp.Position.Y - target_hrp.Position.Y
	return y_diff >= 0 and y_diff <= range
end
getgenv().start_melee_bypass = function()
	if melee_active then return end
	melee_active = true
	config.melee_bypass_enabled = true
	melee_conn = run_service.Heartbeat:Connect(function()
		if not config.melee_bypass_enabled then return end
		local my_hrp = getgenv().get_hrp(localplayer); if not my_hrp then return end
		pcall(function()
			for _, p in pairs(players:GetPlayers()) do
				if p ~= localplayer and p.Character then
					local h = p.Character:FindFirstChild("HumanoidRootPart")
					if h then
						if melee_in_y_range(my_hrp, h) then
							melee_fake_cf_store[p] = h.CFrame
							local mt = getrawmetatable(h)
							local old_ni = mt and rawget(mt, "__newindex")
							local fake_cf = CFrame.new(MELEE_FAKE_OFFSET)
							if old_ni then pcall(old_ni, h, "CFrame", fake_cf)
							else rawset(h, "CFrame", fake_cf) end
							h.AssemblyLinearVelocity = Vector3.zero
						else melee_fake_cf_store[p] = nil end
					end
				end
			end
		end)
	end)
end
getgenv().stop_melee_bypass = function()
	melee_active = false
	config.melee_bypass_enabled = false
	if melee_conn then melee_conn:Disconnect(); melee_conn = nil end
	melee_fake_cf_store = {}
end

-- ============================================================
-- 11. SLINGSHOT BYPASS
-- ============================================================
do
 local sling_targetPos = CFrame.new(9000, 9000, 9000)
 local sling_projectiles = {}
 local sling_conn, sling_childAddedConn, sling_childRemovedConn = nil, nil, nil
 local sling_active = false
 local sling_proj_names = {["CoreProjectile"]=true,["Slingshot.Slingshot"]=true,["Bow"]=true,["Dagger"]=true,["Daggers"]=true}
 local sling_raycast_hooked = false
 local function sling_apply_range_hook()
  if not sling_raycast_hooked then
   sling_raycast_hooked = true
   pcall(function()
    local old_raycast = workspace.Raycast
    hookfunction(old_raycast, function(self, origin, direction, params)
     if not config.slingshot_bypass_enabled then return old_raycast(self, origin, direction, params) end
     local range = math.clamp(config.slingshot_bypass_range or 100000000000000, 1, 100000000000000)
     local mag = direction.Magnitude
     if mag > 0 then direction = direction.Unit * math.max(mag, range) end
     return old_raycast(self, origin, direction, params)
    end)
   end)
  end
  pcall(function()
   local rs = game:GetService("ReplicatedStorage")
   local modules = rs:FindFirstChild("Modules"); if not modules then return end
   local il_ok, ItemLibrary = pcall(require, modules:FindFirstChild("ItemLibrary"))
   if not il_ok or not ItemLibrary then return end
   local Items = rawget(ItemLibrary, "Items"); if not Items then return end
   local range = math.clamp(config.slingshot_bypass_range or 100000000000000, 1, 100000000000000)
   for _, item in pairs(Items) do
    local nm = tostring(item.Name or "")
    if nm == "Slingshot" or nm == "Bow" or nm == "Dagger" or nm == "Daggers" then
     if item["Range"] then rawset(item, "Range", range) end
     if item["MaxRange"] then rawset(item, "MaxRange", range) end
     if item["ProjectileRange"] then rawset(item, "ProjectileRange", range) end
     if item["ShootRange"] then rawset(item, "ShootRange", range) end
    end
   end
  end)
 end
 getgenv().start_slingshot_bypass = function()
  if sling_active then return end
  sling_active = true
  config.slingshot_bypass_enabled = true
  sling_projectiles = {}
  sling_apply_range_hook()
  sling_childAddedConn = workspace.ChildAdded:Connect(function(o)
   if not o:IsA("BasePart") then return end
   if sling_proj_names[o.Name] then sling_projectiles[o] = true
   elseif o.Name == "Part" then
    task.defer(function() if o and o.Parent and o.AssemblyLinearVelocity.Magnitude > 50 then sling_projectiles[o] = true end end)
   end
  end)
  sling_childRemovedConn = workspace.ChildRemoved:Connect(function(o) sling_projectiles[o] = nil end)
  sling_conn = run_service.Heartbeat:Connect(function()
   if not config.slingshot_bypass_enabled then return end
   if config.slingshot_bypass_manipulation then
    pcall(function()
     for _, p in pairs(players:GetPlayers()) do
      if p ~= localplayer and p.Character then
       local h = p.Character:FindFirstChild("HumanoidRootPart")
       if h then h.CFrame = sling_targetPos h.AssemblyLinearVelocity = Vector3.zero end
      end
     end
     for _, o in pairs(workspace:GetChildren()) do
      if o:IsA("BasePart") and sling_proj_names[o.Name] then o.CFrame = sling_targetPos o.AssemblyLinearVelocity = Vector3.zero end
     end
     for p in pairs(sling_projectiles) do
      if p and p.Parent then p.CFrame = sling_targetPos p.AssemblyLinearVelocity = Vector3.zero
      else sling_projectiles[p] = nil end
     end
    end)
   end
  end)
 end
 getgenv().stop_slingshot_bypass = function()
  sling_active = false
  config.slingshot_bypass_enabled = false
  if sling_conn then sling_conn:Disconnect(); sling_conn = nil end
  if sling_childAddedConn then sling_childAddedConn:Disconnect(); sling_childAddedConn = nil end
  if sling_childRemovedConn then sling_childRemovedConn:Disconnect(); sling_childRemovedConn = nil end
  sling_projectiles = {}
  if not config.teleport_to_target_enabled then pcall(getgenv().stop_teleport_to_target) end
 end
end

-- ============================================================
-- 12. BOW BYPASS
-- ============================================================
do
 local bow_targetPos = CFrame.new(9000, 9000, 9000)
 local bow_projectiles = {}
 local bow_conn, bow_childAddedConn, bow_childRemovedConn = nil, nil, nil
 local bow_active = false
 getgenv().start_bow_bypass = function()
  if bow_active then return end
  bow_active = true
  config.bow_bypass_enabled = true
  bow_projectiles = {}
  bow_childAddedConn = workspace.ChildAdded:Connect(function(o)
   if not o:IsA("BasePart") then return end
   if o.Name == "arrow" then bow_projectiles[o] = true
   elseif o.Name == "Part" then
    task.defer(function() if o and o.Parent and o.AssemblyLinearVelocity.Magnitude > 50 then bow_projectiles[o] = true end end)
   end
  end)
  bow_childRemovedConn = workspace.ChildRemoved:Connect(function(o) bow_projectiles[o] = nil end)
  bow_conn = run_service.Heartbeat:Connect(function()
   if not config.bow_bypass_enabled then return end
   pcall(function()
    for _, p in pairs(players:GetPlayers()) do
     if p ~= localplayer and p.Character then
      local h = p.Character:FindFirstChild("HumanoidRootPart")
      if h then h.CFrame = bow_targetPos h.AssemblyLinearVelocity = Vector3.zero end
     end
    end
    for _, o in pairs(workspace:GetChildren()) do
     if o.Name == "arrow" and o:IsA("BasePart") then o.CFrame = bow_targetPos o.AssemblyLinearVelocity = Vector3.zero end
    end
    for p in pairs(bow_projectiles) do
     if p and p.Parent then p.CFrame = bow_targetPos p.AssemblyLinearVelocity = Vector3.zero
     else bow_projectiles[p] = nil end
    end
   end)
  end)
 end
 getgenv().stop_bow_bypass = function()
  bow_active = false
  config.bow_bypass_enabled = false
  if bow_conn then bow_conn:Disconnect(); bow_conn = nil end
  if bow_childAddedConn then bow_childAddedConn:Disconnect(); bow_childAddedConn = nil end
  if bow_childRemovedConn then bow_childRemovedConn:Disconnect(); bow_childRemovedConn = nil end
  bow_projectiles = {}
 end
end

-- ============================================================
-- 13. DAGGER BYPASS
-- ============================================================
do
 local dagger_targetPos = CFrame.new(9000, 9000, 9000)
 local dagger_projectiles = {}
 local dagger_conn, dagger_childAddedConn, dagger_childRemovedConn = nil, nil, nil
 local dagger_active = false
 getgenv().start_dagger_bypass = function()
  if dagger_active then return end
  dagger_active = true
  config.dagger_bypass_enabled = true
  dagger_projectiles = {}
  dagger_childAddedConn = workspace.ChildAdded:Connect(function(o)
   if not o:IsA("BasePart") then return end
   if o.Name == "daggers" then dagger_projectiles[o] = true
   elseif o.Name == "Part" then
    task.defer(function() if o and o.Parent and o.AssemblyLinearVelocity.Magnitude > 50 then dagger_projectiles[o] = true end end)
   end
  end)
  dagger_childRemovedConn = workspace.ChildRemoved:Connect(function(o) dagger_projectiles[o] = nil end)
  dagger_conn = run_service.Heartbeat:Connect(function()
   if not config.dagger_bypass_enabled then return end
   pcall(function()
    for _, p in pairs(players:GetPlayers()) do
     if p ~= localplayer and p.Character then
      local h = p.Character:FindFirstChild("HumanoidRootPart")
      if h then h.CFrame = dagger_targetPos h.AssemblyLinearVelocity = Vector3.zero end
     end
    end
    for _, o in pairs(workspace:GetChildren()) do
     if o.Name == "daggers" and o:IsA("BasePart") then o.CFrame = dagger_targetPos o.AssemblyLinearVelocity = Vector3.zero end
    end
    for p in pairs(dagger_projectiles) do
     if p and p.Parent then p.CFrame = dagger_targetPos p.AssemblyLinearVelocity = Vector3.zero
     else dagger_projectiles[p] = nil end
    end
   end)
  end)
 end
 getgenv().stop_dagger_bypass = function()
  dagger_active = false
  config.dagger_bypass_enabled = false
  if dagger_conn then dagger_conn:Disconnect(); dagger_conn = nil end
  if dagger_childAddedConn then dagger_childAddedConn:Disconnect(); dagger_childAddedConn = nil end
  if dagger_childRemovedConn then dagger_childRemovedConn:Disconnect(); dagger_childRemovedConn = nil end
  dagger_projectiles = {}
 end
end

-- ============================================================
-- 14. PROJECTILE TP + RAPID FIRE
-- ============================================================
local proj_tp_conn = nil
getgenv().start_projectile_tp = function()
	if proj_tp_conn then proj_tp_conn:Disconnect() end
	proj_tp_conn = run_service.Heartbeat:Connect(function()
		if not config.projectile_tp_enabled then return end
		pcall(function()
			local target = getgenv().get_closest(false)
			if not target or not target.Character then return end
			local partName = config.projectile_tp_part or "HumanoidRootPart"
			local targetPart = target.Character:FindFirstChild(partName); if not targetPart then return end
			local destCF = targetPart.CFrame
			for _, o in pairs(workspace:GetChildren()) do
				if o:IsA("BasePart") and (o.Name == "Slingshot.Slingshot" or o.Name == "arrow" or o.Name == "daggers") then
					o.CFrame = destCF o.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end)
	end)
end
getgenv().stop_projectile_tp = function()
	if proj_tp_conn then proj_tp_conn:Disconnect(); proj_tp_conn = nil end
	config.projectile_tp_enabled = false
end
local proj_rapid_fire_conn = nil
getgenv().start_projectile_rapid_fire = function()
	if proj_rapid_fire_conn then proj_rapid_fire_conn:Disconnect() end
	local Items
	pcall(function() local IL = require(game:GetService("ReplicatedStorage").Modules.ItemLibrary); Items = IL and rawget(IL, "Items") end)
	local function patch_items()
		if not Items then return end
		for _, Item in pairs(Items) do
			local Name = Item.Name
			if (Name == "Bow" or Name == "Daggers" or Name == "Slingshot") and Item["ReloadLength"] then
				rawset(Item, "ReloadLength", Name == "Daggers" and 0.09 or 0)
			end
		end
	end
	patch_items()
	proj_rapid_fire_conn = run_service.Heartbeat:Connect(function()
		if not config.projectile_rapid_fire_proj_enabled then return end
		patch_items()
	end)
end
getgenv().stop_projectile_rapid_fire = function()
	if proj_rapid_fire_conn then proj_rapid_fire_conn:Disconnect(); proj_rapid_fire_conn = nil end
	config.projectile_rapid_fire_proj_enabled = false
end

-- ============================================================
-- 15. ANTI AIM
-- ============================================================
local anti_aim_conn = nil
local anti_aim_active = false
local function aa_get_pitch()
	local m = config.anti_aim_angle or "Down"
	if m == "Down" then return math.rad(90)
	elseif m == "Up" then return math.rad(-90)
	elseif m == "Random" then return math.rad(math.random(0, 360))
	elseif m == "Custom" then return math.rad(config.anti_aim_custom_angle or 0) end
	return math.rad(90)
end
local function aa_apply_method(hrp, base_pitch, base_yaw)
	local method = config.anti_aim_method or "Pixelation"
	local pos = hrp.Position
	local mt = getrawmetatable(hrp)
	local ni = mt and rawget(mt, "__newindex")
	local function set_cf(cf) if ni then pcall(ni, hrp, "CFrame", cf) else pcall(function() hrp.CFrame = cf end) end end
	if method == "Pixelation" then
		local pixels = math.max(config.pixel_count or 8, 1)
		local step = math.max(1, math.floor(pixels))
		local char = localplayer.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					local sz = part.Size
					local snapped = Vector3.new(math.floor(sz.X/step+0.5)*step, math.floor(sz.Y/step+0.5)*step, math.floor(sz.Z/step+0.5)*step)
					pcall(function() part.Size = snapped end)
					local p2 = part.Position
					local sp = Vector3.new(math.floor(p2.X/step+0.5)*step, math.floor(p2.Y/step+0.5)*step, math.floor(p2.Z/step+0.5)*step)
					pcall(function() part.CFrame = CFrame.new(sp) * (part.CFrame - part.CFrame.Position) end)
				end
			end
		end
	elseif method == "Spin" then set_cf(CFrame.new(pos) * CFrame.Angles(base_pitch, base_yaw, 0))
	elseif method == "Jitter" then set_cf(CFrame.new(pos) * CFrame.Angles(base_pitch, math.rad(math.random(0,360)), math.rad(math.random(-180,180))))
	elseif method == "Flat" then set_cf(CFrame.new(pos) * CFrame.Angles(0, base_yaw, 0))
	elseif method == "Invert" then set_cf(CFrame.new(pos) * CFrame.Angles(-base_pitch, base_yaw + math.pi, 0))
	elseif method == "Roll" then set_cf(CFrame.new(pos) * CFrame.Angles(0, base_yaw, math.rad(90)))
	elseif method == "Chaos" then set_cf(CFrame.new(pos) * CFrame.Angles(math.rad(math.random(-180,180)), math.rad(math.random(-180,180)), math.rad(math.random(-180,180))))
	elseif method == "Wave" then set_cf(CFrame.new(pos) * CFrame.Angles(math.sin(tick()*3)*base_pitch, base_yaw, 0))
	elseif method == "Pulse" then set_cf(CFrame.new(pos) * CFrame.Angles(base_pitch*math.abs(math.sin(tick()*5)), base_yaw, 0))
	elseif method == "Desync" then set_cf(CFrame.new(pos) * CFrame.Angles(base_pitch, base_yaw, math.rad(180)))
	else set_cf(CFrame.new(pos) * CFrame.Angles(base_pitch, base_yaw, 0)) end
end
getgenv().start_anti_aim = function()
	if anti_aim_conn then anti_aim_conn:Disconnect() end
	anti_aim_active = true
	config.anti_aim_enabled = true
	local spd = config.anti_aim_spin_speed or 1e85
	anti_aim_conn = run_service.Heartbeat:Connect(function()
		if not config.anti_aim_enabled then return end
		local hrp = getgenv().get_hrp(localplayer); if not hrp then return end
		aa_apply_method(hrp, aa_get_pitch(), (tick()*spd) % (2*math.pi))
	end)
end
getgenv().stop_anti_aim = function()
	anti_aim_active = false
	config.anti_aim_enabled = false
	if anti_aim_conn then anti_aim_conn:Disconnect(); anti_aim_conn = nil end
end

-- ============================================================
-- 16. EVADE
-- ============================================================
local evade_conn, evade_active = nil, false
local evade_last_pos = Vector3.new(0,0,0)
local function evade_gen_pos(origin)
	local min_d, max_d = config.evade_min_dist or 5000, config.evade_max_dist or 50000
	local shape = config.evade_shape or "Sphere"
	local y_mode = config.evade_y_mode or "Random"
	local axis_lock = config.evade_axis_lock or "None"
	local chaos = config.evade_chaos_amp or 1
	local invert_x, invert_z = config.evade_invert_x, config.evade_invert_z
	local y_bias = config.evade_y_bias or 0
	local dist = min_d + math.random() * (max_d - min_d)
	local x, y, z
	if shape == "Sphere" then
		local theta, phi = math.random()*2*math.pi, math.acos(2*math.random()-1)
		x, y, z = dist*math.sin(phi)*math.cos(theta), dist*math.sin(phi)*math.sin(theta), dist*math.cos(phi)
	elseif shape == "Cube" then
		x, y, z = (math.random()-0.5)*2*dist, (math.random()-0.5)*2*dist, (math.random()-0.5)*2*dist
	elseif shape == "Flat" then
		local theta = math.random()*2*math.pi
		x, y, z = dist*math.cos(theta), (math.random()-0.5)*dist*0.05, dist*math.sin(theta)
	elseif shape == "Vertical" then
		x, y, z = (math.random()-0.5)*dist*0.05, dist, (math.random()-0.5)*dist*0.05
	else
		local theta = math.random()*2*math.pi
		x, y, z = dist*math.cos(theta), dist*math.sin(theta), dist*math.sin(theta+math.pi*0.5)
	end
	x, y, z = x*chaos, y*chaos, z*chaos
	if invert_x then x = -x end
	if invert_z then z = -z end
	if y_mode == "Up" then y = math.abs(y) + dist*0.5
	elseif y_mode == "Down" then y = -(math.abs(y) + dist*0.5)
	elseif y_mode == "Flat" then y = 0 end
	y = y + y_bias
	if axis_lock == "X" then z = 0; y = 0
	elseif axis_lock == "Y" then x = 0; z = 0
	elseif axis_lock == "Z" then x = 0; y = 0
	elseif axis_lock == "XZ" then y = 0 end
	return Vector3.new(origin.X + x, origin.Y + y, origin.Z + z)
end
getgenv().start_evade = function()
	if evade_active then return end
	evade_active = true
	config.evade_enabled = true
	evade_conn = task.spawn(function()
		while evade_active and config.evade_enabled do
			pcall(function()
				local hrp = getgenv().get_hrp(localplayer)
				if hrp then
					local target = evade_gen_pos(evade_last_pos)
					evade_last_pos = target
					if (config.evade_warp_mode or "Instant") == "Instant" then
						hrp.CFrame = CFrame.new(target)
						if config.evade_kill_velocity then hrp.AssemblyLinearVelocity = Vector3.zero hrp.AssemblyAngularVelocity = Vector3.zero end
					else
						local start, goal = hrp.CFrame, CFrame.new(target)
						for i = 1, 5 do hrp.CFrame = start:Lerp(goal, i/5) task.wait() end
						if config.evade_kill_velocity then hrp.AssemblyLinearVelocity = Vector3.zero hrp.AssemblyAngularVelocity = Vector3.zero end
					end
				end
			end)
			task.wait(math.max(config.evade_delay or 0.1, 0.01))
		end
	end)
end
getgenv().stop_evade = function()
	evade_active = false
	config.evade_enabled = false
	evade_last_pos = Vector3.new(0,0,0)
end

-- ============================================================
-- 17. RIOT ABUSER v1
-- ============================================================
local rav1_conn = nil
local function rav1_find_target()
	local hrp = getgenv().get_hrp(localplayer); if not hrp then return nil end
	local best, best_d = nil, math.huge
	for _, plr in ipairs(players:GetPlayers()) do
		if plr ~= localplayer and plr.Character then
			local t_hrp = plr.Character:FindFirstChild("HumanoidRootPart")
			local hum = plr.Character:FindFirstChildOfClass("Humanoid")
			local no_ff = not plr.Character:FindFirstChildOfClass("ForceField")
			local diff_team = localplayer.Team == nil or plr.Team == nil or localplayer.Team ~= plr.Team
			if t_hrp and hum and hum.Health > 0 and no_ff and diff_team then
				local d = (hrp.Position - t_hrp.Position).Magnitude
				if d < best_d then best_d = d; best = plr end
			end
		end
	end
	return best
end
local function rav1_compute_dest(t_hrp)
	local pos, look, up = t_hrp.Position, t_hrp.CFrame.LookVector, Vector3.new(0,1,0)
	local dist = config.riot_abuser_v1_tracking_distance or 3
	local mode = config.riot_abuser_v1_tracking_position or "Behind"
	if mode == "Behind" then return pos - look*dist
	elseif mode == "Above" then return pos + up*dist
	elseif mode == "Front" then return pos + look*dist
	elseif mode == "Below" then return pos - up*dist
	elseif mode == "Left" then return pos - look:Cross(up).Unit*dist
	elseif mode == "Right" then return pos + look:Cross(up).Unit*dist end
	return pos
end
getgenv().start_riot_abuser_v1 = function()
	if rav1_conn then rav1_conn:Disconnect() end
	rav1_conn = run_service.Heartbeat:Connect(function()
		if not config.riot_abuser_v1_enabled then return end
		local hrp = getgenv().get_hrp(localplayer)
		local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then return end
		local target = rav1_find_target()
		local spinSpeed = config.riot_abuser_v1_spin_speed or 720
		local yaw = (tick()*math.rad(spinSpeed)) % (2*math.pi)
		local dest_pos
		if target and target.Character then
			local t_hrp = target.Character:FindFirstChild("HumanoidRootPart")
			if t_hrp then dest_pos = rav1_compute_dest(t_hrp) end
		end
		local dest_cf = CFrame.new(dest_pos or hrp.Position) * CFrame.Angles(0, yaw, 0)
		local mt = getrawmetatable and getrawmetatable(hrp) or nil
		local ni = mt and rawget(mt, "__newindex") or nil
		if ni then
			pcall(ni, hrp, "AssemblyLinearVelocity", Vector3.zero)
			pcall(ni, hrp, "AssemblyAngularVelocity", Vector3.zero)
			pcall(ni, hrp, "CFrame", dest_cf)
			pcall(ni, hrp, "AssemblyLinearVelocity", Vector3.zero)
		else
			pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero hrp.AssemblyAngularVelocity = Vector3.zero hrp.CFrame = dest_cf hrp.AssemblyLinearVelocity = Vector3.zero end)
		end
	end)
end
getgenv().stop_riot_abuser_v1 = function()
	if rav1_conn then rav1_conn:Disconnect(); rav1_conn = nil end
	config.riot_abuser_v1_enabled = false
end

-- ============================================================
-- 18. RIOT ABUSER (bypass)
-- ============================================================
local riot_abuser_target, riot_abuser_last_update, riot_abuser_conn = nil, 0, nil
local function findRiotAbuserTarget()
	local hrp = getgenv().get_hrp(localplayer); if not hrp then return nil end
	local closest, closestDist = nil, math.huge
	for _, plr in ipairs(players:GetPlayers()) do
		if plr ~= localplayer and plr.Character then
			local t_hrp = plr.Character:FindFirstChild("HumanoidRootPart")
			local hum = plr.Character:FindFirstChild("Humanoid")
			if t_hrp and hum and hum.Health > 0 then
				if localplayer.Team == nil or plr.Team == nil or localplayer.Team ~= plr.Team then
					local dist = (hrp.Position - t_hrp.Position).Magnitude
					if dist < closestDist then closestDist = dist; closest = plr end
				end
			end
		end
	end
	return closest
end
local function computeRiotAbuserPos(targetRoot)
	local pos, look, up = targetRoot.Position, targetRoot.CFrame.LookVector, Vector3.new(0,1,0)
	local dist = config.riot_bypass_distance or 3
	local height = config.riot_bypass_height or 0
	local mode = config.riot_bypass_position or "Behind"
	local base
	if mode == "Behind" then base = pos - look*dist
	elseif mode == "Front" then base = pos + look*dist
	elseif mode == "Above" then base = pos + up*dist
	elseif mode == "Below" then base = pos - up*dist
	elseif mode == "Left" then base = pos - look:Cross(up).Unit*dist
	elseif mode == "Right" then base = pos + look:Cross(up).Unit*dist
	else base = pos - look*dist end
	return base + Vector3.new(0, height, 0)
end
local function updateRiotAbuserTarget()
	if not config.riot_bypass_enabled then return end
	riot_abuser_target = findRiotAbuserTarget()
end
local function applyRiotAbuser()
	if not config.riot_bypass_enabled then return end
	local hrp = getgenv().get_hrp(localplayer); if not hrp then return end
	local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	if not riot_abuser_target or not riot_abuser_target.Character then updateRiotAbuserTarget() return end
	local targetRoot = riot_abuser_target.Character:FindFirstChild("HumanoidRootPart"); if not targetRoot then return end
	local destPos = computeRiotAbuserPos(targetRoot)
	if config.riot_bypass_snap then
		pcall(function() hrp.CFrame = CFrame.new(destPos) hrp.AssemblyLinearVelocity = Vector3.zero hrp.AssemblyAngularVelocity = Vector3.zero end)
	else
		local rate = math.max(config.riot_bypass_update_rate or 0.5, 0.05)
		local tween = TweenService:Create(hrp, TweenInfo.new(rate, Enum.EasingStyle.Linear), {CFrame=CFrame.new(destPos)})
		tween:Play()
	end
end
getgenv().start_riot_abuser = function()
	if riot_abuser_conn then riot_abuser_conn:Disconnect() end
	riot_abuser_last_update = 0
	riot_abuser_conn = run_service.Heartbeat:Connect(function()
		if not config.riot_bypass_enabled then return end
		if tick() - riot_abuser_last_update > (config.riot_bypass_update_rate or 0.5) then
			updateRiotAbuserTarget()
			riot_abuser_last_update = tick()
		end
		applyRiotAbuser()
	end)
end
getgenv().stop_riot_abuser = function()
	if riot_abuser_conn then riot_abuser_conn:Disconnect(); riot_abuser_conn = nil end
	riot_abuser_target = nil
	config.riot_bypass_enabled = false
end

-- ============================================================
-- 19. RIOT ABUSER v2
-- ============================================================
local ra_v2_conn, ra_v2_t0, ra_v2_seed = nil, nil, nil
getgenv().start_riot_abuser_v2 = function()
	if ra_v2_conn then ra_v2_conn:Disconnect() end
	ra_v2_t0 = tick()
	ra_v2_seed = math.random(1000, 9999)
	ra_v2_conn = run_service.Heartbeat:Connect(function(dt)
		if not config.riot_abuser_v2_enabled then return end
		local hrp = getgenv().get_hrp(localplayer)
		local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then return end
		local t = tick() - ra_v2_t0
		local spinSpeed = config.riot_abuser_v2_spin_speed or 720
		local riotXJitter = config.riot_abuser_v2_xjitter or 30
		local riotYJitter = config.riot_abuser_v2_yjitter or 8
		local riotDistance = config.riot_abuser_v2_spread or 300
		local yaw = math.rad(spinSpeed * dt)
		local pitch = math.rad(spinSpeed * 0.37 * dt * math.sin(t*3.1))
		local roll = math.rad(spinSpeed * 0.19 * dt * math.cos(t*5.7 + ra_v2_seed))
		local spinCF = hrp.CFrame * CFrame.Angles(pitch, yaw, roll)
		local spread = riotDistance / 300
		local jX = (math.random()-0.5)*riotXJitter*spread*2 + math.noise(t*9, ra_v2_seed, 0)*riotXJitter*spread
		local jY = (math.random()-0.5)*riotYJitter*spread + math.noise(0, t*9, ra_v2_seed)*riotYJitter*spread*0.3
		local jZ = (math.random()-0.5)*riotXJitter*spread*2 + math.noise(0, 0, t*9+ra_v2_seed)*riotXJitter*spread
		local newY = math.max(spinCF.Position.Y + jY, 2)
		local mt = getrawmetatable and getrawmetatable(hrp) or nil
		local ni = mt and rawget(mt, "__newindex") or nil
		if ni then
			pcall(ni, hrp, "AssemblyLinearVelocity", Vector3.zero)
			pcall(ni, hrp, "AssemblyAngularVelocity", Vector3.zero)
			pcall(ni, hrp, "CFrame", spinCF + Vector3.new(jX, newY - spinCF.Position.Y, jZ))
		else
			pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero hrp.AssemblyAngularVelocity = Vector3.zero hrp.CFrame = spinCF + Vector3.new(jX, newY - spinCF.Position.Y, jZ) end)
		end
	end)
end
getgenv().stop_riot_abuser_v2 = function()
	if ra_v2_conn then ra_v2_conn:Disconnect(); ra_v2_conn = nil end
	config.riot_abuser_v2_enabled = false
end

-- ============================================================
-- 20. FAKE POSITION
-- ============================================================
local fake_pos_conn, fake_pos_render_conn = nil, nil
local fake_pos_realCF = nil
local fake_pos_spiral_angle, fake_pos_linear_t, fake_pos_last_packet_t = 0, 0, 0
getgenv().start_fake_position = function()
	if fake_pos_conn then fake_pos_conn:Disconnect() end
	if fake_pos_render_conn then fake_pos_render_conn:Disconnect() end
	fake_pos_realCF = nil
	fake_pos_spiral_angle = 0
	fake_pos_linear_t = 0
	fake_pos_last_packet_t = 0
	fake_pos_conn = run_service.Heartbeat:Connect(function(dt)
		local hrp = getgenv().get_hrp(localplayer)
		if not config.fake_pos_enabled or not hrp then return end
		fake_pos_realCF = hrp.CFrame
		local radius = math.max(config.fake_pos_radius or 500, 1)
		local height = config.fake_pos_height or 0
		local spd = math.max(config.fake_pos_speed or 50, 1)
		local count = math.clamp(config.fake_pos_count or 5, 1, 20)
		local pattern = config.fake_pos_drop1 or "Scatter"
		local distribution = config.fake_pos_drop2 or "Random"
		local axis_lock = config.fake_pos_drop3 or "None"
		local reverse = config.fake_pos_tog2 or false
		local random_radius = config.fake_pos_tog3 or false
		local packet_interval = 1 / math.max(spd, 1)
		local now = tick()
		if now - fake_pos_last_packet_t < packet_interval then return end
		fake_pos_last_packet_t = now
		local eff_radius = random_radius and (math.random()*radius) or radius
		if reverse then eff_radius = -eff_radius end
		local mt = getrawmetatable(hrp)
		local ni = mt and rawget(mt, "__newindex")
		for _ = 1, count do
			local ox, oy, oz = 0, 0, 0
			if pattern == "Scatter" then
				local sx, sz = (math.random()<0.5) and 1 or -1, (math.random()<0.5) and 1 or -1
				ox, oy, oz = sx*(math.random()*math.abs(eff_radius)), height+(math.random()-0.5)*math.max(math.abs(height),1)*0.5, sz*(math.random()*math.abs(eff_radius))
			elseif pattern == "Linear" then
				fake_pos_linear_t = fake_pos_linear_t + 0.05
				local t = fake_pos_linear_t % 1
				ox, oy, oz = (t-0.5)*2*math.abs(eff_radius), height, (t-0.5)*2*math.abs(eff_radius)
			elseif pattern == "Circle" then
				fake_pos_spiral_angle = (fake_pos_spiral_angle + math.rad(spd*dt*60)) % (2*math.pi)
				ox, oy, oz = math.cos(fake_pos_spiral_angle)*math.abs(eff_radius), height, math.sin(fake_pos_spiral_angle)*math.abs(eff_radius)
			elseif pattern == "Random" then
				ox, oy, oz = (math.random()*2-1)*math.abs(eff_radius), height+(math.random()-0.5)*200, (math.random()*2-1)*math.abs(eff_radius)
			elseif pattern == "Spiral" then
				fake_pos_spiral_angle = (fake_pos_spiral_angle + math.rad(spd*dt*60)) % (2*math.pi)
				local r = math.abs(eff_radius) * (0.3 + 0.7 * ((fake_pos_spiral_angle/(2*math.pi))%1))
				ox, oy, oz = math.cos(fake_pos_spiral_angle)*r, height + fake_pos_spiral_angle*10, math.sin(fake_pos_spiral_angle)*r
			end
			if distribution == "Uniform" then
				local mag = math.sqrt(ox*ox+oz*oz)
				if mag > 0 then local s = math.abs(eff_radius)/mag ox = ox*s oz = oz*s end
			elseif distribution == "Weighted" then ox = ox*0.6 oz = oz*0.6
			elseif distribution == "Radial" then
				local theta = math.atan2(oz, ox)
				ox, oz = math.cos(theta)*math.abs(eff_radius), math.sin(theta)*math.abs(eff_radius)
			elseif distribution == "Clustered" then
				local ca = math.floor(math.random()*8)*(math.pi*0.25)
				ox, oz = math.cos(ca)*math.abs(eff_radius), math.sin(ca)*math.abs(eff_radius)
			end
			if axis_lock == "X" then oz = 0 oy = height
			elseif axis_lock == "Y" then ox = 0 oz = 0
			elseif axis_lock == "Z" then ox = 0 oy = height
			elseif axis_lock == "XZ" then oy = height end
			local fake_cf = fake_pos_realCF + Vector3.new(ox, oy, oz)
			if ni then pcall(ni, hrp, "AssemblyLinearVelocity", Vector3.zero) pcall(ni, hrp, "CFrame", fake_cf) pcall(ni, hrp, "AssemblyLinearVelocity", Vector3.zero)
			else pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero hrp.CFrame = fake_cf hrp.AssemblyLinearVelocity = Vector3.zero end) end
			if sethiddenproperty then
				pcall(sethiddenproperty, hrp, "CFrame", fake_cf)
				pcall(sethiddenproperty, hrp, "AssemblyLinearVelocity", Vector3.zero)
			end
		end
	end)
	fake_pos_render_conn = run_service.RenderStepped:Connect(function()
		local hrp = getgenv().get_hrp(localplayer)
		if config.fake_pos_enabled and hrp and fake_pos_realCF then
			hrp.CFrame = fake_pos_realCF
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end
getgenv().stop_fake_position = function()
	if fake_pos_conn then fake_pos_conn:Disconnect(); fake_pos_conn = nil end
	if fake_pos_render_conn then fake_pos_render_conn:Disconnect(); fake_pos_render_conn = nil end
	fake_pos_realCF = nil
	fake_pos_spiral_angle = 0
	fake_pos_linear_t = 0
	config.fake_pos_enabled = false
end

-- ============================================================
-- 21. PIXELATION
-- ============================================================
local pixel_conn = nil
getgenv().start_pixelation = function()
	if pixel_conn then pixel_conn:Disconnect() end
	pixel_conn = run_service.Heartbeat:Connect(function()
		if not config.pixel_enabled then return end
		local char = localplayer.Character; if not char then return end
		local step = math.max(1, math.floor(math.max(config.pixel_count or 8, 1)))
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				local sz = part.Size
				pcall(function() part.Size = Vector3.new(math.floor(sz.X/step+0.5)*step, math.floor(sz.Y/step+0.5)*step, math.floor(sz.Z/step+0.5)*step) end)
				local p = part.Position
				local sp = Vector3.new(math.floor(p.X/step+0.5)*step, math.floor(p.Y/step+0.5)*step, math.floor(p.Z/step+0.5)*step)
				pcall(function() part.CFrame = CFrame.new(sp) * (part.CFrame - part.CFrame.Position) end)
			end
		end
	end)
end
getgenv().stop_pixelation = function()
	if pixel_conn then pixel_conn:Disconnect(); pixel_conn = nil end
	config.pixel_enabled = false
end

-- ============================================================
-- 22. ANTI VOID BAIT
-- ============================================================
local anti_void_bait_conn = nil
getgenv().start_anti_void_bait_freeze = function()
	if anti_void_bait_conn then anti_void_bait_conn:Disconnect() end
	anti_void_bait_conn = run_service.Heartbeat:Connect(function()
		if not config.anti_void_bait_freeze then return end
		local hrp = getgenv().get_hrp(localplayer); if not hrp then return end
		pcall(function() hrp.CFrame = hrp.CFrame end)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end) end
	end)
end
getgenv().start_anti_void_bait_hide = function()
	if anti_void_bait_conn then anti_void_bait_conn:Disconnect() end
	anti_void_bait_conn = run_service.Heartbeat:Connect(function()
		if not config.anti_void_bait_hide then return end
		local hrp = getgenv().get_hrp(localplayer); if not hrp then return end
		local iters = math.clamp(config.et_total or 1000, 1, 500)
		local ir = math.max(config.evs_iter_radius or 500000, 1)
		local base = hrp.Position
		for _ = 1, iters do
			local sx = (math.random()<0.5) and 1 or -1
			local sy = (math.random()<0.5) and 1 or -1
			local sz = (math.random()<0.5) and 1 or -1
			pcall(function() hrp.CFrame = CFrame.new(base.X+sx*(ir*(0.5+math.random()*0.5)), base.Y+sy*(ir*(0.5+math.random()*0.5)), base.Z+sz*(ir*(0.5+math.random()*0.5))) end)
			base = hrp.Position
		end
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end)
end
getgenv().stop_anti_void_bait = function()
	if anti_void_bait_conn then anti_void_bait_conn:Disconnect(); anti_void_bait_conn = nil end
	config.anti_void_bait_freeze = false
	config.anti_void_bait_hide = false
end

-- ============================================================
-- 23. VOID MIMIC
-- ============================================================
local VM_VOID_THRESH = -1000000
local vm_store = {}
local vm_conn = nil
local VM_LEARN_WINDOW = 10
local VM_MIN_SAMPLES = 6
local function vm_valid(x, y, z)
	if x ~= x or y ~= y or z ~= z then return false end
	if math.abs(x) == math.huge or math.abs(y) == math.huge or math.abs(z) == math.huge then return false end
	return true
end
local function vm_read_part(part)
	if not part then return nil end
	local cf
	pcall(function() local mt = getrawmetatable(part) if mt then local ri = rawget(mt,"__index") if ri then cf = ri(part,"CFrame") end end end)
	if cf then local x,y,z = cf.X,cf.Y,cf.Z if vm_valid(x,y,z) then return Vector3.new(x,y,z) end end
	pcall(function() cf = part.CFrame end)
	if cf then local x,y,z = cf.X,cf.Y,cf.Z if vm_valid(x,y,z) then return Vector3.new(x,y,z) end end
	return nil
end
local function vm_find_target()
	local hrp = getgenv().get_hrp(localplayer); if not hrp then return nil end
	local best, best_d = nil, math.huge
	for _, p in ipairs(players:GetPlayers()) do
		if p ~= localplayer and p.Character then
			local t_hrp = p.Character:FindFirstChild("HumanoidRootPart")
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if t_hrp and hum and hum.Health > 0 and not p.Character:FindFirstChildOfClass("ForceField") then
				local d = (hrp.Position - t_hrp.Position).Magnitude
				if d < best_d then best_d = d; best = p end
			end
		end
	end
	return best
end
local function vm_record(target_hrp)
	local raw = vm_read_part(target_hrp); if not raw then return end
	local x, y, z = raw.X, raw.Y, raw.Z
	local now = tick()
	if not vm_store[target_hrp] then
		vm_store[target_hrp] = {samples={}, learned=false, learn_start=now, phase_x=0, phase_z=0, amp_x=0, amp_z=0, base_y=y, freq=1, cx=x, cz=z}
	end
	local st = vm_store[target_hrp]
	if y >= VM_VOID_THRESH then st.last_surface_x = x st.last_surface_z = z return end
	local alpha = math.clamp(config.void_mimic_learn_rate or 0.85, 0.1, 0.99)
	local sn = st.samples
	sn[#sn+1] = {x=x,y=y,z=z,t=now}
	if #sn > 256 then table.remove(sn, 1) end
	st.cx = st.cx*(1-alpha) + x*alpha
	st.cz = st.cz*(1-alpha) + z*alpha
	st.amp_x = st.amp_x*(1-alpha) + math.abs(x-st.cx)*alpha
	st.amp_z = st.amp_z*(1-alpha) + math.abs(z-st.cz)*alpha
	st.base_y = st.base_y*(1-alpha) + y*alpha
	if #sn >= 2 then
		local dt_s = sn[#sn].t - sn[#sn-1].t
		if dt_s > 0 then st.freq = st.freq*(1-alpha*0.3) + (1/dt_s)*(alpha*0.3) end
	end
	if (now - st.learn_start) >= VM_LEARN_WINDOW and #sn >= VM_MIN_SAMPLES then st.learned = true end
end
local function vm_get_mimic_pos(target_hrp, now)
	local st = vm_store[target_hrp]
	if not st or not st.learned then return nil end
	local spd = math.clamp(st.freq, 0.5, 20)
	local t = now * spd
	local bx = st.cx + math.sin(t + st.phase_x) * st.amp_x
	local bz = st.cz + math.cos(t + st.phase_z) * st.amp_z
	if not vm_valid(bx, st.base_y, bz) then return nil end
	return Vector3.new(bx, st.base_y, bz)
end
getgenv().vm_get_mimic_pos = vm_get_mimic_pos
getgenv().vm_store = vm_store
local vm_mimic_active = false
getgenv().start_void_mimic = function()
	if vm_mimic_active then return end
	vm_mimic_active = true
	config.void_mimic_enabled = true
	vm_store = {}
	getgenv().vm_store = vm_store
	if vm_conn then vm_conn:Disconnect() end
	vm_conn = run_service.Heartbeat:Connect(function()
		if not config.void_mimic_enabled then return end
		local target = vm_find_target()
		if not target or not target.Character then return end
		local t_hrp = target.Character:FindFirstChild("HumanoidRootPart"); if not t_hrp then return end
		local head = target.Character:FindFirstChild("Head")
		pcall(vm_record, t_hrp)
		if head then pcall(vm_record, head) end
	end)
end
getgenv().stop_void_mimic = function()
	vm_mimic_active = false
	config.void_mimic_enabled = false
	if vm_conn then vm_conn:Disconnect(); vm_conn = nil end
	vm_store = {}
	getgenv().vm_store = vm_store
end

-- ============================================================
-- 24. TT HELPERS
-- ============================================================
local TT_HISTORY_LEN = 128
local TT_MICRO_SAMPLES = 1024
local TT_VOID_THRESH = -200
local TT_VOID_HIST_LEN = 64
local TT_CHAOS_JUMP_THRESH = 400
local TT_DEEP_VOID_THRESH = -1000
local TT_SPAMMER_CHAOS_THRESHOLD = 4
local TT_MAX_EXTRAP_AGE = 0.4
local TT_VEL_EMA_FAST = 0.25
local TT_VEL_EMA_SLOW = 0.08
local tt_track, tt_live = {}, {}
local tt_locked_target = nil
local function tt_isnan(v) return v ~= v end
local function tt_isinf(v) return math.abs(v) == math.huge end
local function tt_valid_scalar(v) return not tt_isnan(v) and not tt_isinf(v) end
local function tt_valid_xyz(x,y,z) return tt_valid_scalar(x) and tt_valid_scalar(y) and tt_valid_scalar(z) end
local function tt_validate_vec3(v)
	if not v then return false end
	return tt_valid_xyz(v.X, v.Y, v.Z)
end
local function tt_record(part, x, y, z, cf, now)
	if not tt_valid_xyz(x,y,z) then return end
	local live = tt_live[part]
	if not live then
		tt_live[part] = {x=x,y=y,z=z,cf=cf,t=now,lkg_x=x,lkg_y=y,lkg_z=z,lkg_cf=cf,lkg_t=now,is_void=false,is_deep_void=false,void_vel=Vector3.zero,last_x=x,last_y=y,last_z=z,last_t=now,void_cx=x,void_cy=y,void_cz=z,void_cn=0,void_min_x=x,void_max_x=x,void_min_y=y,void_max_y=y,void_min_z=z,void_max_z=z,chaos_count=0,chaos_t=now,spd_ema_fast=0,spd_ema_slow=0,vel_x=0,vel_y=0,vel_z=0,vel_ema_x=0,vel_ema_y=0,vel_ema_z=0,surface_x=x,surface_y=y,surface_z=z,surface_t=now,last_surface_x=x,last_surface_y=y,last_surface_z=z,entry_void_t=nil,exit_void_t=now,jump_count=0}
		live = tt_live[part]
	else
		local prev_is_void = live.is_void
		local px,py,pz,pt = live.x,live.y,live.z,live.t
		live.last_x,live.last_y,live.last_z,live.last_t = px,py,pz,pt
		live.x,live.y,live.z,live.cf,live.t = x,y,z,cf,now
		local dt_r = now - pt
		if dt_r > 0.000001 then
			local jump = math.sqrt((x-px)^2+(y-py)^2+(z-pz)^2)
			local spd = jump / dt_r
			live.spd_ema_fast = live.spd_ema_fast*(1-TT_VEL_EMA_FAST) + spd*TT_VEL_EMA_FAST
			live.spd_ema_slow = live.spd_ema_slow*(1-TT_VEL_EMA_SLOW) + spd*TT_VEL_EMA_SLOW
			local raw_vx, raw_vy, raw_vz = (x-px)/dt_r, (y-py)/dt_r, (z-pz)/dt_r
			live.vel_x,live.vel_y,live.vel_z = raw_vx,raw_vy,raw_vz
			live.vel_ema_x = live.vel_ema_x*0.7 + raw_vx*0.3
			live.vel_ema_y = live.vel_ema_y*0.7 + raw_vy*0.3
			live.vel_ema_z = live.vel_ema_z*0.7 + raw_vz*0.3
			if jump > TT_CHAOS_JUMP_THRESH then live.chaos_count = (live.chaos_count or 0)+3 live.chaos_t = now live.jump_count = (live.jump_count or 0)+1
			else local cc = live.chaos_count or 0 if cc > 0 then live.chaos_count = cc-1 end end
		end
		local new_is_void = y < TT_VOID_THRESH
		local new_is_deep = y < TT_DEEP_VOID_THRESH
		live.is_void = new_is_void live.is_deep_void = new_is_deep
		if not new_is_void then
			live.lkg_x,live.lkg_y,live.lkg_z = x,y,z live.lkg_cf,live.lkg_t = cf,now
			live.surface_x,live.surface_y,live.surface_z = x,y,z live.surface_t = now
			live.last_surface_x,live.last_surface_y,live.last_surface_z = live.surface_x,live.surface_y,live.surface_z
		else
			if not prev_is_void then live.entry_void_t = now live.last_surface_x = live.lkg_x or x live.last_surface_y = live.lkg_y or y live.last_surface_z = live.lkg_z or z end
			local cn = (live.void_cn or 0)+1 live.void_cn = cn
			local w = 1/cn local keep = 1-w
			live.void_cx = (live.void_cx or x)*keep + x*w
			live.void_cy = (live.void_cy or y)*keep + y*w
			live.void_cz = (live.void_cz or z)*keep + z*w
			if live.void_min_x == nil or x < live.void_min_x then live.void_min_x = x end
			if live.void_max_x == nil or x > live.void_max_x then live.void_max_x = x end
			if live.void_min_y == nil or y < live.void_min_y then live.void_min_y = y end
			if live.void_max_y == nil or y > live.void_max_y then live.void_max_y = y end
			if live.void_min_z == nil or z < live.void_min_z then live.void_min_z = z end
			if live.void_max_z == nil or z > live.void_max_z then live.void_max_z = z end
		end
		if (not prev_is_void) and new_is_void then
			local dt_v = now - (live.lkg_t or now)
			if dt_v > 0.000001 then live.void_vel = Vector3.new((x-(live.lkg_x or x))/dt_v, (y-(live.lkg_y or y))/dt_v, (z-(live.lkg_z or z))/dt_v) end
		end
		if prev_is_void and not new_is_void then
			live.void_cn = 0 live.void_cx,live.void_cy,live.void_cz = x,y,z
			live.void_min_x,live.void_max_x = x,x live.void_min_y,live.void_max_y = y,y live.void_min_z,live.void_max_z = z,z
			live.exit_void_t = now
		end
	end
	local entry = tt_track[part]
	if not entry then tt_track[part] = {hist={},hi=0,void_hist={},vh=0} entry = tt_track[part] end
	local hi = (entry.hi % TT_HISTORY_LEN) + 1 entry.hi = hi
	entry.hist[hi] = {x=x,y=y,z=z,t=now}
	if y < TT_VOID_THRESH then
		local vh = (entry.vh % TT_VOID_HIST_LEN) + 1 entry.vh = vh
		entry.void_hist[vh] = {x=x,y=y,z=z,t=now}
	end
end
local function tt_predict_velocity(part)
	local live = tt_live[part]
	local entry = tt_track[part]
	if not entry or not entry.hist then return Vector3.zero end
	local hist = entry.hist local n = #hist
	if n < 3 then return Vector3.zero end
	local hi = entry.hi
	local is_voidspam = live and (live.chaos_count or 0) >= TT_SPAMMER_CHAOS_THRESHOLD
	if is_voidspam then
		if live and live.last_surface_x and tt_valid_xyz(live.last_surface_x,live.last_surface_y,live.last_surface_z) then
			local sx,sy,sz = live.last_surface_x,live.last_surface_y,live.last_surface_z
			local lx,ly,lz = live.lkg_x or sx, live.lkg_y or sy, live.lkg_z or sz
			local dvx,dvy,dvz = sx-lx,sy-ly,sz-lz
			if math.sqrt(dvx*dvx+dvy*dvy+dvz*dvz) > 0.5 then return Vector3.new(dvx,dvy,dvz) end
		end
		local vhist = entry.void_hist
		if vhist then
			local sx,sy,sz,cnt = 0,0,0,0
			for _,s in pairs(vhist) do if s then sx=sx+s.x sy=sy+s.y sz=sz+s.z cnt=cnt+1 end end
			if cnt >= 2 then
				local cx,cy,cz = sx/cnt,sy/cnt,sz/cnt
				return Vector3.new(cx - (live and live.lkg_x or cx), cy - (live and live.lkg_y or cy), cz - (live and live.lkg_z or cz))
			end
		end
	end
	local count = math.min(n, 24)
	local vx,vy,vz,tw = 0,0,0,0
	for k = 1, count-1 do
		local bi = ((hi-k-1+TT_HISTORY_LEN)%TT_HISTORY_LEN)+1
		local ai = ((hi-k-2+TT_HISTORY_LEN)%TT_HISTORY_LEN)+1
		local b, a = hist[bi], hist[ai]
		if b and a then
			local dt_h = b.t - a.t
			if dt_h > 0.000001 then
				local dvx,dvy,dvz = (b.x-a.x)/dt_h, (b.y-a.y)/dt_h, (b.z-a.z)/dt_h
				if dvx*dvx+dvy*dvy+dvz*dvz < 1e12 then
					local w = 1/(k*k)
					vx = vx+dvx*w vy = vy+dvy*w vz = vz+dvz*w tw = tw+w
				end
			end
		end
	end
	if tw == 0 then return Vector3.zero end
	return Vector3.new(vx/tw,vy/tw,vz/tw)
end
local function tt_target_valid(p)
	if not p or not p.Character then return false end
	local t_hrp = p.Character:FindFirstChild("HumanoidRootPart"); if not t_hrp then return false end
	if p.Character:FindFirstChildOfClass("ForceField") then return false end
	if localplayer.Team and p.Team and localplayer.Team == p.Team then return false end
	if tt_live[t_hrp] then return true end
	local hum = p.Character:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end
local function get_teleport_target()
	local mode = config.teleport_to_target_mode or "Closest"
	local priorityName = config.teleport_to_target_priority
	if priorityName and priorityName ~= "" then
		local sp = players:FindFirstChild(priorityName)
		if sp and tt_target_valid(sp) then if config.teleport_to_target_lock then tt_locked_target = sp end return sp end
	end
	if config.teleport_to_target_lock and tt_locked_target then
		if tt_target_valid(tt_locked_target) then return tt_locked_target else tt_locked_target = nil end
	end
	local hrp = getgenv().get_hrp(localplayer); if not hrp then return nil end
	local my_x,my_y,my_z = hrp.Position.X,hrp.Position.Y,hrp.Position.Z
	local best_target, best_val = nil, (mode == "Closest") and math.huge or -math.huge
	local sr = config.teleport_to_target_search_radius or 999e15
	for _,p in ipairs(players:GetPlayers()) do
		if p ~= localplayer and tt_target_valid(p) then
			local t_hrp = p.Character:FindFirstChild("HumanoidRootPart")
			if t_hrp then
				local tx,ty,tz
				local live = tt_live[t_hrp]
				if live then
					if live.is_void and live.lkg_x then tx,ty,tz = live.lkg_x,live.lkg_y,live.lkg_z
					else tx,ty,tz = live.x,live.y,live.z end
				else pcall(function() local cf=t_hrp.CFrame tx,ty,tz=cf.X,cf.Y,cf.Z end) end
				if tx and tt_valid_xyz(tx,ty,tz) then
					local dx,dy,dz = tx-my_x, ty-my_y, tz-my_z
					local dist_sq = dx*dx+dy*dy+dz*dz
					if dist_sq <= sr*sr then
						if mode == "Closest" and dist_sq < best_val then best_val=dist_sq best_target=p
						elseif mode == "Farthest" and dist_sq > best_val then best_val=dist_sq best_target=p
						elseif mode == "LowestHP" then
							local hum = p.Character:FindFirstChildOfClass("Humanoid")
							local hp = hum and hum.Health or math.huge
							if hp < best_val then best_val=hp best_target=p end
						end
					end
				end
			end
		end
	end
	if config.teleport_to_target_lock and best_target then tt_locked_target = best_target end
	return best_target
end
local function tt_sample_part(part)
	local cf local now = tick()
	pcall(function() local mt = getrawmetatable(part) if mt then local ri=rawget(mt,"__index") if ri then cf=ri(part,"CFrame") end end end)
	if not cf then pcall(function() if gethiddenproperty then local v=gethiddenproperty(part,"CFrame") if v then cf=v end end end) end
	if not cf then pcall(function() if ficlone then local cl=ficlone(part) if cl then cf=cl.CFrame end end end) end
	if not cf then pcall(function() cf = part.CFrame end) end
	if not cf then return end
	local px,py,pz = cf.X,cf.Y,cf.Z
	if not tt_valid_xyz(px,py,pz) then return end
	tt_record(part,px,py,pz,cf,now)
end
local function tt_raw_read_part(part)
	if not part then return nil end
	local cf
	pcall(function() local mt=getrawmetatable(part) if mt then local ri=rawget(mt,"__index") if ri then cf=ri(part,"CFrame") end end end)
	if not cf then pcall(function() if gethiddenproperty then local v=gethiddenproperty(part,"CFrame") if v then cf=v end end end) end
	if not cf then pcall(function() cf = part.CFrame end) end
	if cf then local x,y,z = cf.X,cf.Y,cf.Z if tt_valid_xyz(x,y,z) then return Vector3.new(x,y,z) end end
	return nil
end
local function tt_nuke_fallen_parts()
	pcall(function() workspace.FallenPartsDestroyHeight = -math.huge end)
	pcall(function() workspace.FallenPartsDestroyHeight = 0/0 end)
end
local function srb_write(hrp, target_cf)
	if not hrp or not target_cf then return end
	local V0 = Vector3.zero
	pcall(function() hrp.AssemblyLinearVelocity = V0 hrp.AssemblyAngularVelocity = V0 hrp.CFrame = target_cf hrp.AssemblyLinearVelocity = V0 hrp.AssemblyAngularVelocity = V0 end)
	pcall(function()
		local mt = getrawmetatable(hrp) if not mt then return end
		local ni = rawget(mt,"__newindex") if not ni then return end
		ni(hrp,"AssemblyLinearVelocity",V0) ni(hrp,"AssemblyAngularVelocity",V0) ni(hrp,"CFrame",target_cf)
		ni(hrp,"AssemblyLinearVelocity",V0) ni(hrp,"AssemblyAngularVelocity",V0)
	end)
	if sethiddenproperty then
		pcall(sethiddenproperty, hrp, "CFrame", target_cf)
		pcall(sethiddenproperty, hrp, "AssemblyLinearVelocity", V0)
	end
end
local function tt_force_cframe(hrp, target_cf)
	tt_nuke_fallen_parts()
	local V0 = Vector3.zero
	local written = false
	local function try(fn) if written then return end if pcall(fn) then written = true end end
	try(function() local mt = getrawmetatable(hrp) if mt then local ni = rawget(mt,"__newindex") if ni then ni(hrp,"AssemblyLinearVelocity",V0) ni(hrp,"AssemblyAngularVelocity",V0) ni(hrp,"CFrame",target_cf) ni(hrp,"AssemblyLinearVelocity",V0) ni(hrp,"AssemblyAngularVelocity",V0) end end end)
	try(function() hrp.AssemblyLinearVelocity = V0 hrp.AssemblyAngularVelocity = V0 hrp.CFrame = target_cf hrp.AssemblyLinearVelocity = V0 hrp.AssemblyAngularVelocity = V0 end)
	try(function() local was = hrp.Anchored hrp.Anchored = true hrp.CFrame = target_cf hrp.AssemblyLinearVelocity = V0 hrp.AssemblyAngularVelocity = V0 hrp.CFrame = target_cf hrp.Anchored = was end)
	try(function() if sethiddenproperty then sethiddenproperty(hrp,"CFrame",target_cf) sethiddenproperty(hrp,"AssemblyLinearVelocity",V0) end end)
	if not written then
		for _ = 1, 12 do pcall(function() hrp.CFrame = target_cf hrp.AssemblyLinearVelocity = V0 end) end
	else
		for _ = 1, 6 do pcall(function() hrp.CFrame = target_cf hrp.AssemblyLinearVelocity = V0 end) end
	end
	tt_nuke_fallen_parts()
end
local function tt_resolve_void_pos_deep(t_hrp, head)
	local live = tt_live[t_hrp]
	local r = tt_raw_read_part(t_hrp)
	if r and tt_validate_vec3(r) then return r end
	if head then r = tt_raw_read_part(head) if r and tt_validate_vec3(r) then return r end end
	if live and live.is_void and live.void_cn and live.void_cn > 0 then
		local cx,cy,cz = live.void_cx, live.void_cy, live.void_cz
		if tt_valid_xyz(cx,cy,cz) then return Vector3.new(cx,cy,cz) end
	end
	if live and live.lkg_x and tt_valid_xyz(live.lkg_x,live.lkg_y,live.lkg_z) then
		return Vector3.new(live.lkg_x, live.lkg_y, live.lkg_z)
	end
	return nil
end
local function tt_resolve_dest(head, t_hrp, method)
	local live = tt_live[t_hrp]
	local lkg = live and live.lkg_x and Vector3.new(live.lkg_x, live.lkg_y, live.lkg_z) or nil
	if live and (live.is_void or (live.chaos_count or 0) >= TT_SPAMMER_CHAOS_THRESHOLD) then
		if config.void_mimic_enabled and vm_get_mimic_pos then
			local mimic = vm_get_mimic_pos(t_hrp, tick())
			if mimic and tt_validate_vec3(mimic) then return mimic end
		end
		local cand = tt_resolve_void_pos_deep(t_hrp, head)
		if cand and tt_validate_vec3(cand) then return cand end
		if lkg then return lkg end
		return nil
	end
	local pos = tt_raw_read_part(t_hrp) or lkg
	if pos and tt_validate_vec3(pos) then return pos end
	return lkg
end
local function tt_force_dest_resolve(t_hrp, head)
	local live = tt_live[t_hrp]
	if live then
		if live.lkg_x and tt_valid_xyz(live.lkg_x,live.lkg_y,live.lkg_z) then return Vector3.new(live.lkg_x,live.lkg_y,live.lkg_z) end
		if live.x and tt_valid_xyz(live.x,live.y,live.z) then return Vector3.new(live.x,live.y,live.z) end
	end
	local raw = tt_raw_read_part(t_hrp)
	if raw and tt_validate_vec3(raw) then return raw end
	if head then local raw2 = tt_raw_read_part(head) if raw2 and tt_validate_vec3(raw2) then return raw2 end end
	return nil
end

-- ============================================================
-- 25. KICIA COUNTER
-- ============================================================
local kicia_counter_conn = nil
local kicia_counter_active = false
local KC_VOID_DEPTH = -300000
local function kc_find_target()
	local hrp = getgenv().get_hrp(localplayer); if not hrp then return nil end
	local best, best_d = nil, math.huge
	for _, p in ipairs(players:GetPlayers()) do
		if p ~= localplayer and p.Character then
			local t_hrp = p.Character:FindFirstChild("HumanoidRootPart")
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if t_hrp and hum and hum.Health > 0 and not p.Character:FindFirstChildOfClass("ForceField") then
				if localplayer.Team == nil or p.Team == nil or localplayer.Team ~= p.Team then
					local d = (hrp.Position - t_hrp.Position).Magnitude
					if d < best_d then best_d = d; best = p end
				end
			end
		end
	end
	return best
end
local function kc_force_cf(hrp, target_cf)
	local V0 = Vector3.zero
	pcall(function() hrp.AssemblyLinearVelocity = V0 hrp.AssemblyAngularVelocity = V0 hrp.CFrame = target_cf end)
	pcall(function()
		local mt = getrawmetatable(hrp) if not mt then return end
		local ni = rawget(mt,"__newindex") if not ni then return end
		ni(hrp,"AssemblyLinearVelocity",V0) ni(hrp,"CFrame",target_cf)
	end)
	pcall(function() local was = hrp.Anchored hrp.Anchored = true hrp.CFrame = target_cf hrp.Anchored = was end)
end
local kc_last_snap = 0
getgenv().start_kicia_counter = function()
	if kicia_counter_active then return end
	kicia_counter_active = true
	config.kicia_counter_enabled = true
	tt_nuke_fallen_parts()
	kicia_counter_conn = run_service.Heartbeat:Connect(function()
		if not config.kicia_counter_enabled then return end
		local hrp = getgenv().get_hrp(localplayer)
		local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then return end
		local target = kc_find_target()
		if not target or not target.Character then return end
		local t_hrp = target.Character:FindFirstChild("HumanoidRootPart"); if not t_hrp then return end
		local head = target.Character:FindFirstChild("Head")
		local aggression = math.clamp(config.void_counter_aggression or 5, 1, 5)
		for _ = 1, 16*aggression do
			pcall(tt_sample_part, t_hrp)
			if head then pcall(tt_sample_part, head) end
		end
		local now = tick()
		if now - kc_last_snap < 0.016/aggression then return end
		kc_last_snap = now
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
		pcall(function() hum.AutoRotate = false end)
		tt_nuke_fallen_parts()
		local void_cf = CFrame.new(hrp.Position.X, KC_VOID_DEPTH, hrp.Position.Z)
		local snaps = math.clamp(config.void_counter_snap_count or 8, 1, 16)
		for _ = 1, snaps do kc_force_cf(hrp, void_cf) end
		local dest = tt_resolve_void_pos_deep(t_hrp, head)
		if not dest or not tt_validate_vec3(dest) then dest = tt_resolve_dest(head, t_hrp, "Adaptive") end
		if not dest or not tt_validate_vec3(dest) then dest = tt_force_dest_resolve(t_hrp, head) end
		if dest and tt_validate_vec3(dest) then
			for _ = 1, snaps do pcall(tt_force_cframe, hrp, CFrame.new(dest)) end
			manipulation.fire_toward(head or t_hrp, target.Character)
		end
		tt_nuke_fallen_parts()
	end)
end
getgenv().stop_kicia_counter = function()
	kicia_counter_active = false
	config.kicia_counter_enabled = false
	if kicia_counter_conn then kicia_counter_conn:Disconnect(); kicia_counter_conn = nil end
	local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function() hum.AutoRotate = true end)
		pcall(function() hum.PlatformStand = false end)
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
	end
end

-- ============================================================
-- 26. KICIA VOIDSPAM
-- ============================================================
local kicia_voidspam_thread = nil
local kicia_voidspam_attack_num, kicia_voidspam_heavy_attack_num = 0, 0
local kicia_voidspam_last_attack, kicia_voidspam_reload_cooldown = 0, 0
local function kicia_vs_get_equipped(char) return char and char:FindFirstChild("EquippedItem") end
local function kicia_vs_get_hitbox(char)
	local head = char and (char:FindFirstChild("HitboxHead") or char:FindFirstChild("Head"))
	return head or (char and char:FindFirstChild("HumanoidRootPart"))
end
local function kicia_vs_random_unit() return Vector3.new(math.random()*2-1, math.random()*2-1, math.random()*2-1).Unit end
local function kicia_vs_rotation(part) return part and part.CFrame.Rotation or CFrame.new() end
local function kicia_vs_anim_keys(item) local vm = item and item.ViewModel return vm and vm:GetAnimationKeys() or {} end
local function kicia_vs_get_target()
	local myChar = localplayer.Character
	local best, bestDist = nil, math.huge
	for _, plr in ipairs(players:GetPlayers()) do
		if plr ~= localplayer and plr.Character then
			local char = plr.Character
			local hum = char:FindFirstChildOfClass("Humanoid")
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and hrp then
				local dist = (hrp.Position - (myChar and myChar:FindFirstChild("HumanoidRootPart") and myChar.HumanoidRootPart.Position or Vector3.zero)).Magnitude
				if dist < bestDist then bestDist = dist best = char end
			end
		end
	end
	return best
end
local function kicia_vs_ranged(target)
	local myChar = localplayer.Character
	local item = kicia_vs_get_equipped(myChar); if not item then return false end
	if item.Info and item.Info.Type ~= "Gun" then return false end
	kicia_voidspam_attack_num = kicia_voidspam_attack_num + 1
	local hitbox = kicia_vs_get_hitbox(target); if not hitbox then return false end
	local aimPos = hitbox.Position + kicia_vs_random_unit() * 0.5
	return pcall(function()
		game:GetService("ReplicatedStorage").Remotes.Replication.Fighter.UseItem:FireServer({
			id = http_service:GenerateGUID(false),
			objectId = http_service:GenerateGUID(false),
			item = "primary",
			position = aimPos,
			attackNum = kicia_voidspam_attack_num,
			animationKeys = kicia_vs_anim_keys(item),
			rotation = kicia_vs_rotation(hitbox),
			one = Vector3.one,
			packed = {"\x00","\x01","\x02","\x03"},
		})
	end)
end
local function kicia_vs_melee(target)
	local myChar = localplayer.Character
	local item = kicia_vs_get_equipped(myChar); if not item then return false end
	if item.Info and item.Info.Type ~= "Melee" then return false end
	local now = tick()
	local cooldown = item.Info and item.Info.HeavyAttackCooldown or 0.2
	if now - kicia_voidspam_last_attack < cooldown then return false end
	kicia_voidspam_last_attack = now
	kicia_voidspam_heavy_attack_num = kicia_voidspam_heavy_attack_num + 1
	local hitbox = kicia_vs_get_hitbox(target); if not hitbox then return false end
	local aimPos = hitbox.Position + kicia_vs_random_unit() * 0.35
	return pcall(function()
		game:GetService("ReplicatedStorage").Remotes.Replication.Fighter.UseItem:FireServer({
			id = http_service:GenerateGUID(false),
			objectId = http_service:GenerateGUID(false),
			item = "primary",
			position = aimPos,
			heavyAttackNum = kicia_voidspam_heavy_attack_num,
			animationKeys = kicia_vs_anim_keys(item),
			rotation = kicia_vs_rotation(hitbox),
			one = Vector3.one,
			startAiming = true,
			packed = {"\x00","\x01","\x02","\x03"},
		})
	end)
end
local function kicia_vs_loop()
	if not config.kicia_voidspam_enabled then return end
	local myChar = localplayer.Character; if not myChar then return end
	local item = kicia_vs_get_equipped(myChar); if not item then return end
	local target = kicia_vs_get_target(); if not target then return end
	local weaponType = item.Info and item.Info.Type
	local data = item.Data
	local ammo = data and data.Ammo
	local reserve = data and data.AmmoReserve
	local now = tick()
	if weaponType == "Gun" then
		if ammo and ammo <= 0 then
			if reserve and reserve > 0 and now > kicia_voidspam_reload_cooldown then
				pcall(function() item:StartReloading() end)
				kicia_voidspam_reload_cooldown = now + 0.4
			end
			return
		end
		kicia_vs_ranged(target)
		return
	end
	if weaponType == "Melee" then kicia_vs_melee(target) return end
end
getgenv().start_kicia_voidspam = function()
	if not config.kicia_voidspam_enabled then return end
	run_service.Heartbeat:Connect(function()
		if not config.kicia_voidspam_enabled then return end
		if kicia_voidspam_thread and coroutine.status(kicia_voidspam_thread) ~= "dead" then return end
		kicia_voidspam_thread = task.spawn(kicia_vs_loop)
	end)
end
getgenv().stop_kicia_voidspam = function()
	config.kicia_voidspam_enabled = false
	kicia_voidspam_thread = nil
end

-- ============================================================
-- 27. DESYNC
-- ============================================================
local desync_heartbeat, desync_render, desync_realVel = nil, nil, nil
local desync_angle_accum = 0
getgenv().start_desync = function()
	if desync_heartbeat then desync_heartbeat:Disconnect() end
	if desync_render then desync_render:Disconnect() end
	desync_realVel = nil
	desync_angle_accum = 0
	desync_heartbeat = run_service.Heartbeat:Connect(function(dt)
		local hrp = getgenv().get_hrp(localplayer)
		if not config.desync_enabled or not hrp then return end
		desync_realVel = hrp.AssemblyLinearVelocity
		local intensity = math.clamp(config.desync_intensity or 50, 1, 100)
		local spd = math.clamp(config.desync_speed or 10, 1, 100)
		local base_angle = math.rad(config.desync_angle or 90)
		local jitter_range = math.clamp(config.desync_jitter or 20, 0, 180)
		local dir_sign = (config.desync_flip) and -1 or 1
		desync_angle_accum = desync_angle_accum + math.rad(spd*dt*360)
		local angle = base_angle + math.rad((math.random()-0.5)*jitter_range*2) + desync_angle_accum
		local mag = (intensity/100)*50000
		local spoof_vel = Vector3.new(math.cos(angle)*mag*dir_sign, (math.random()-0.5)*mag*0.5, math.sin(angle)*mag*dir_sign)
		local mt = getrawmetatable(hrp) local ni = mt and rawget(mt,"__newindex")
		if ni then pcall(ni, hrp, "AssemblyLinearVelocity", spoof_vel) else pcall(function() hrp.AssemblyLinearVelocity = spoof_vel end) end
	end)
	desync_render = run_service.RenderStepped:Connect(function()
		local hrp = getgenv().get_hrp(localplayer)
		if config.desync_enabled and hrp and desync_realVel then hrp.AssemblyLinearVelocity = desync_realVel end
	end)
end
getgenv().stop_desync = function()
	if desync_heartbeat then desync_heartbeat:Disconnect(); desync_heartbeat = nil end
	if desync_render then desync_render:Disconnect(); desync_render = nil end
	desync_realVel = nil desync_angle_accum = 0 config.desync_enabled = false
end

-- ============================================================
-- 28. UNHITTABLE DESYNC
-- ============================================================
local desync_uh_conn, desync_uh_render = nil, nil
local desync_uh_realCF = nil
getgenv().start_unhittable_desync = function()
	if desync_uh_conn then desync_uh_conn:Disconnect() end
	if desync_uh_render then desync_uh_render:Disconnect() end
	desync_uh_realCF = nil
	desync_uh_conn = run_service.Heartbeat:Connect(function()
		local hrp = getgenv().get_hrp(localplayer)
		if not config.desync_unhittable_enabled or not hrp then return end
		desync_uh_realCF = hrp.CFrame
		local iters = math.clamp(config.desync_unhittable_iters or 100, 1, 500)
		local radius = math.max(config.desync_unhittable_radius or 9000, 1)
		local fake_offset = radius * (math.clamp(config.desync_unhittable_intensity or 50, 1, 100)/100)
		local base = hrp.Position
		local mt = getrawmetatable(hrp) local ni = mt and rawget(mt,"__newindex")
		for _ = 1, iters do
			local sx = (math.random()<0.5) and 1 or -1
			local sz = (math.random()<0.5) and 1 or -1
			local fake_cf = CFrame.new(base.X+sx*(fake_offset*(0.5+math.random()*0.5)), base.Y+(math.random()-0.5)*fake_offset*0.3, base.Z+sz*(fake_offset*(0.5+math.random()*0.5)))
			if ni then pcall(ni, hrp, "CFrame", fake_cf) pcall(ni, hrp, "AssemblyLinearVelocity", Vector3.zero)
			else pcall(function() hrp.CFrame = fake_cf hrp.AssemblyLinearVelocity = Vector3.zero end) end
		end
		pcall(function()
			for _, p in pairs(players:GetPlayers()) do
				if p ~= localplayer and p.Character then
					local eh = p.Character:FindFirstChild("HumanoidRootPart")
					if eh then
						local y_diff = hrp.Position.Y - eh.Position.Y
						if y_diff >= 0 and y_diff <= (config.desync_unhittable_y_range or 10) then
							melee_fake_cf_store[p] = eh.CFrame
							local emt = getrawmetatable(eh) local eni = emt and rawget(emt,"__newindex")
							local fake_cf_u = CFrame.new(MELEE_FAKE_OFFSET)
							if eni then pcall(eni, eh, "CFrame", fake_cf_u) else pcall(function() rawset(eh, "CFrame", fake_cf_u) end) end
							eh.AssemblyLinearVelocity = Vector3.zero
						else melee_fake_cf_store[p] = nil end
					end
				end
			end
		end)
	end)
	desync_uh_render = run_service.RenderStepped:Connect(function()
		local hrp = getgenv().get_hrp(localplayer)
		if config.desync_unhittable_enabled and hrp and desync_uh_realCF then
			pcall(function() hrp.CFrame = desync_uh_realCF hrp.AssemblyLinearVelocity = Vector3.zero end)
		end
	end)
end
getgenv().stop_unhittable_desync = function()
	if desync_uh_conn then desync_uh_conn:Disconnect(); desync_uh_conn = nil end
	if desync_uh_render then desync_uh_render:Disconnect(); desync_uh_render = nil end
	desync_uh_realCF = nil
	melee_fake_cf_store = {}
	config.desync_unhittable_enabled = false
end

-- ============================================================
-- 29. PERFECT BLOCK
-- ============================================================
local pb_active = false
local pb_rotFn, pb_camTable, pb_orig = nil, nil, nil
local function pb_nz(a) return (a + math.pi) % (2*math.pi) - math.pi end
local function pb_nearest()
	local myChar = localplayer.Character
	local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
	local best, bestD = nil, math.huge
	for _, p in ipairs(players:GetPlayers()) do
		if p ~= localplayer and p.Character then
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local d = (myHRP.Position - hrp.Position).Magnitude
				if d < bestD then bestD = d best = p end
			end
		end
	end
	return best
end
local function pb_apply()
	if not config.perfect_block_enabled then return end
	if not pb_camTable then return end
	local tgt = pb_nearest(); if not tgt then return end
	local eChar = tgt.Character; if not eChar then return end
	local eHRP = eChar:FindFirstChild("HumanoidRootPart"); if not eHRP then return end
	local eHead = eChar:FindFirstChild("Head")
	local myHRP = localplayer.Character and localplayer.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
	local eLook = eHRP.CFrame.LookVector
	local myYaw = pb_nz(math.atan2(eLook.X, eLook.Z) + math.pi)
	local pitch = 0
	if eHead then pitch = math.asin(math.clamp(eHead.CFrame.LookVector.Y, -1, 1)) end
	pb_camTable.Rotation = Vector2.new(-pitch, myYaw)
	local counter = Vector3.new(-eLook.X, 0, -eLook.Z)
	if counter.Magnitude > 0.001 then
		pcall(function() myHRP.CFrame = CFrame.lookAt(myHRP.Position, myHRP.Position + counter.Unit) myHRP.AssemblyAngularVelocity = Vector3.zero end)
	end
end
getgenv().start_perfect_block = function()
	if pb_active then return end
	pb_active = true
	config.perfect_block_enabled = true
	pcall(function()
		pb_rotFn = filtergc("function", {Name = "_UpdateCharacterRotation"}, true)
		if not pb_rotFn then return end
		pb_camTable = nil
		for _, v in ipairs(debug.getupvalues(pb_rotFn)) do
			if type(v) == "table" and typeof(v.Rotation) == "Vector2" then pb_camTable = v break end
		end
		if not pb_camTable then return end
		run_service:BindToRenderStep("__pb_mrot", Enum.RenderPriority.Character.Value - 1, pb_apply)
		if pb_orig then hookfunction(pb_rotFn, pb_orig) pb_orig = nil end
		pb_orig = hookfunction(pb_rotFn, function(...) pb_apply() return pb_orig(...) end)
	end)
end
getgenv().stop_perfect_block = function()
	pb_active = false
	config.perfect_block_enabled = false
	pcall(function() run_service:UnbindFromRenderStep("__pb_mrot") end)
	if pb_orig and pb_rotFn then pcall(function() hookfunction(pb_rotFn, pb_orig) end) pb_orig = nil end
	pb_rotFn = nil pb_camTable = nil
end

-- ============================================================
-- 30. PREDICTION
-- ============================================================
local prediction_conn = nil
local prediction_active = false
getgenv().start_prediction = function()
	if prediction_conn then prediction_conn:Disconnect() end
	prediction_active = true
	config.prediction_enabled = true
	prediction_conn = run_service.Heartbeat:Connect(function()
		if not config.prediction_enabled then return end
		local hrp = getgenv().get_hrp(localplayer); if not hrp then return end
		local activation_range = math.max(config.prediction_activation_range or 20, 1)
		local distance_range = math.max(config.prediction_distance_range or 30, 1)
		local my_pos = hrp.Position
		for _, p in ipairs(players:GetPlayers()) do
			if p ~= localplayer and p.Character then
				local t_hrp = p.Character:FindFirstChild("HumanoidRootPart")
				local t_hum = p.Character:FindFirstChildOfClass("Humanoid")
				if t_hrp and t_hum and t_hum.Health > 0 then
					local dist = (my_pos - t_hrp.Position).Magnitude
					if dist <= activation_range then
						local away = (my_pos - t_hrp.Position)
						if away.Magnitude > 0.001 then away = away.Unit else away = Vector3.new(1,0,0) end
						local target_pos = my_pos + away * distance_range
						pcall(function() hrp.CFrame = CFrame.new(target_pos) hrp.AssemblyLinearVelocity = Vector3.zero hrp.AssemblyAngularVelocity = Vector3.zero end)
						break
					end
				end
			end
		end
	end)
end
getgenv().stop_prediction = function()
	prediction_active = false
	config.prediction_enabled = false
	if prediction_conn then prediction_conn:Disconnect(); prediction_conn = nil end
end

-- ============================================================
-- 31. TELEPORT TO TARGET
-- ============================================================
local teleport_to_target_conn = nil
local tt_last_target_check = 0
local tt_cached_tgt = nil
local tt_last_snap = 0
local tt_orbit_angle = 0
local function tt_get_parts(target)
	local char = target.Character; if not char then return nil,nil,nil end
	local t_hrp = char:FindFirstChild("HumanoidRootPart"); if not t_hrp then return nil,nil,nil end
	return t_hrp, char:FindFirstChild("Head"), char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
end
local function tt_apply_teleport(hrp, dest, hum, t_hrp)
	if not tt_validate_vec3(dest) then return end
	if hum then pcall(function() hum.AutoRotate = false end) pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end) end
	local target_cf = CFrame.new(dest.X, dest.Y + (config.teleport_to_target_y_offset or 0), dest.Z)
	local jitter = config.teleport_to_target_jitter or 0
	if jitter > 0 then target_cf = CFrame.new(target_cf.X + (math.random()-0.5)*2*jitter, target_cf.Y, target_cf.Z + (math.random()-0.5)*2*jitter) end
	if config.teleport_to_target_burst_mode then
		local bc = math.clamp(config.teleport_to_target_burst_count or 3, 1, 8)
		for _ = 1, bc do tt_force_cframe(hrp, target_cf) end
	else tt_force_cframe(hrp, target_cf) end
	if t_hrp then
		local head = t_hrp.Parent and t_hrp.Parent:FindFirstChild("Head")
		manipulation.fire_toward(head or t_hrp, t_hrp.Parent)
	end
end
getgenv().start_teleport_to_target = function()
	if teleport_to_target_conn then teleport_to_target_conn:Disconnect() end
	pcall(function() run_service:UnbindFromRenderStep("TeleportToTargetSnap") end)
	tt_track = {} tt_live = {} tt_locked_target = nil tt_nuke_fallen_parts()
	tt_last_target_check = 0 tt_cached_tgt = nil tt_last_snap = 0 tt_orbit_angle = 0
	local function tt_get_cached_target()
		local now = tick()
		local throttle = math.clamp(config.teleport_to_target_throttle or 0, 0, 500)/1000
		if now - tt_last_target_check < math.max(throttle, 0.05) and tt_cached_tgt and tt_target_valid(tt_cached_tgt) then return tt_cached_tgt end
		tt_last_target_check = now
		tt_cached_tgt = get_teleport_target()
		return tt_cached_tgt
	end
	local function tt_snap_to(t_hrp, head, hrp, hum)
		local dest = tt_resolve_dest(head, t_hrp, config.teleport_to_target_method or "Adaptive")
		if not dest or not tt_validate_vec3(dest) then dest = tt_resolve_void_pos_deep(t_hrp, head) end
		if not dest or not tt_validate_vec3(dest) then dest = tt_force_dest_resolve(t_hrp, head) end
		if not dest or not tt_validate_vec3(dest) then return end
		if config.teleport_to_target_orbit_mode then
			tt_orbit_angle = (tt_orbit_angle + math.rad(config.teleport_to_target_orbit_speed or 90)*(1/60)) % (2*math.pi)
			local r = config.teleport_to_target_orbit_radius or 5
			dest = Vector3.new(dest.X + math.cos(tt_orbit_angle)*r, dest.Y, dest.Z + math.sin(tt_orbit_angle)*r)
		end
		local snaps = math.clamp(config.teleport_to_target_snap_count or 4, 1, 12)
		for _ = 1, snaps do pcall(tt_apply_teleport, hrp, dest, hum, t_hrp) end
	end
	run_service:BindToRenderStep("TeleportToTargetSnap", Enum.RenderPriority.Camera.Value + 2, function()
		if not config.teleport_to_target_enabled then return end
		local now = tick()
		local aggression = math.clamp(config.teleport_to_target_aggression or 3, 1, 5)
		if now - tt_last_snap < 0.016/aggression then return end
		tt_last_snap = now
		local target = tt_get_cached_target(); if not target or not target.Character then return end
		local t_hrp, head = tt_get_parts(target); if not t_hrp then return end
		local hrp = getgenv().get_hrp(localplayer)
		local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
		if not hrp then return end
		for _ = 1, math.min(aggression, 3) do tt_snap_to(t_hrp, head, hrp, hum) end
	end)
	teleport_to_target_conn = run_service.Heartbeat:Connect(function()
		if not config.teleport_to_target_enabled then return end
		local target = tt_get_cached_target(); if not target or not target.Character then return end
		local t_hrp, head = tt_get_parts(target); if not t_hrp then return end
		local aggression = math.clamp(config.teleport_to_target_aggression or 3, 1, 5)
		for _ = 1, 4*aggression do
			pcall(tt_sample_part, t_hrp)
			if head then pcall(tt_sample_part, head) end
		end
	end)
end
getgenv().stop_teleport_to_target = function()
	config.teleport_to_target_enabled = false
	if teleport_to_target_conn then teleport_to_target_conn:Disconnect(); teleport_to_target_conn = nil end
	pcall(function() run_service:UnbindFromRenderStep("TeleportToTargetSnap") end)
	tt_track = {} tt_live = {} tt_locked_target = nil
	local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function() hum.AutoRotate = true end)
		pcall(function() hum.PlatformStand = false end)
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
	end
end

-- ============================================================
-- 32. ANTI AFK / AUTOCOLLECT / RETURN HOME / SAFE ZONE / TP LOOP
-- ============================================================
local afk_conn = nil
getgenv().start_anti_afk = function()
	if afk_conn then afk_conn:Disconnect() end
	afk_conn = localplayer.Idled:Connect(function()
		if config.anti_afk_enabled then
			virtual_user:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
			task.wait(1)
			virtual_user:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
		end
	end)
end
getgenv().stop_anti_afk = function() if afk_conn then afk_conn:Disconnect(); afk_conn = nil end end

local auto_conn, home_conn, safe_conn = nil, nil, nil
local last_auto_tick = 0
getgenv().start_autocollect = function()
	if auto_conn then auto_conn:Disconnect() end
	auto_conn = run_service.Heartbeat:Connect(function()
		if not config.autocollect_enabled then return end
		local hrp = getgenv().get_hrp(localplayer); if not hrp then return end
		if tick() - last_auto_tick < 0.25 then return end
		last_auto_tick = tick()
		local best, min_d = nil, math.huge
		for _, o in ipairs(workspace:GetDescendants()) do
			local n = string.lower(o.Name)
			if o:IsA("BasePart") and (n:find("drop") or n:find("chest") or n:find("loot") or n:find("coin") or n:find("gem")) then
				local d = (hrp.Position - o.Position).Magnitude
				if d < min_d and d < (config.autocollect_radius or 120) then min_d = d best = o end
			end
		end
		if best then hrp.CFrame = CFrame.new(best.Position) end
	end)
end
getgenv().stop_autocollect = function()
	if auto_conn then auto_conn:Disconnect(); auto_conn = nil end
	config.autocollect_enabled = false
end
getgenv().start_return_home = function()
	if home_conn then home_conn:Disconnect() end
	home_conn = run_service.Heartbeat:Connect(function()
		if not config.return_home_enabled or not getgenv().home_position then return end
		local hrp = getgenv().get_hrp(localplayer); if not hrp then return end
		hrp.CFrame = CFrame.new(getgenv().home_position)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end)
end
getgenv().stop_return_home = function()
	if home_conn then home_conn:Disconnect(); home_conn = nil end
	config.return_home_enabled = false
end
getgenv().start_safe_zone = function()
	if safe_conn then safe_conn:Disconnect() end
	safe_conn = run_service.Heartbeat:Connect(function()
		if not config.safe_zone_enabled then return end
		local hrp = getgenv().get_hrp(localplayer); if not hrp then return end
		if hrp.Position.Y < (config.safe_zone_y or -10) then
			hrp.CFrame = CFrame.new(hrp.Position.X, math.abs(config.safe_zone_y or -10) + 50, hrp.Position.Z)
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end
getgenv().stop_safe_zone = function()
	if safe_conn then safe_conn:Disconnect(); safe_conn = nil end
	config.safe_zone_enabled = false
end
local tl_conn = nil
getgenv().start_teleport_loop = function()
	if tl_conn then tl_conn:Disconnect() end
	tl_conn = run_service.Heartbeat:Connect(function()
		if not config.teleport_loop_enabled then return end
		if #getgenv().loop_waypoints == 0 then return end
		local idx = getgenv().loop_index
		local wp = getgenv().loop_waypoints[idx]
		if wp then
			local hrp = getgenv().get_hrp(localplayer)
			if hrp then hrp.CFrame = CFrame.new(wp) end
			getgenv().loop_index = (idx % #getgenv().loop_waypoints) + 1
		end
		task.wait(config.teleport_loop_delay or 0.5)
	end)
end
getgenv().stop_teleport_loop = function()
	if tl_conn then tl_conn:Disconnect(); tl_conn = nil end
	config.teleport_loop_enabled = false
end

-- ============================================================
-- 33. RAPID FIRE
-- ============================================================
local rapid_fire_hook_orig = nil
local rapid_fire_hook_active = false
local rapid_fire_weapon_settings = {
	ShootRecoil = 0, ShootSpread = 0, ProjectileSpeed = math.huge, ShootCooldown = 0,
	QuickShotCooldown = 0, ShootBurstCooldown = 0, ShootExplosionRadius = 0,
	AttackCooldown = 0, Cooldown = 0, DashCooldown = 0, SpinCooldown = 0,
	SpinSpeed = 500, DeflectCooldown = 0,
}
getgenv().start_rapid_fire = function()
	if rapid_fire_hook_active then return end
	pcall(function()
		local ClientItem = require(localplayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
		local Input = ClientItem.Input
		rapid_fire_hook_orig = hookfunction(Input, newcclosure(function(...)
			local args = {...}
			if config.rapid_fire_enabled and type(args[1]) == "table" and args[1].Info then
				for k, v in pairs(rapid_fire_weapon_settings) do args[1].Info[k] = v end
			end
			return rapid_fire_hook_orig(...)
		end))
		rapid_fire_hook_active = true
	end)
end
getgenv().stop_rapid_fire = function() config.rapid_fire_enabled = false end

-- ============================================================
-- 34. VOID HIDE
-- ============================================================
local void_hide_conn = nil
getgenv().start_void_hide = function()
	if void_hide_conn then void_hide_conn:Disconnect() end
	void_hide_conn = run_service.Heartbeat:Connect(function()
		if not config.void_hide_enabled then return end
		pcall(function() workspace.FallenPartsDestroyHeight = -math.huge end)
		pcall(function() workspace.FallenPartsDestroyHeight = 0/0 end)
		local hrp = getgenv().get_hrp(localplayer)
		local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then return end
		if hum:GetState() ~= Enum.HumanoidStateType.Physics then hum:ChangeState(Enum.HumanoidStateType.Physics) end
		local base = hrp.Position
		local hx, hy, hz = config.void_hide_x or 1e6, config.void_hide_y or 9e25, config.void_hide_z or 1e6
		local sx = (math.random()<0.5) and 1 or -1
		local sz = (math.random()<0.5) and 1 or -1
		local hide_cf = CFrame.new(base.X+sx*hx, base.Y-hy, base.Z+sz*hz)
		pcall(function() hrp.CFrame = hide_cf hrp.AssemblyLinearVelocity = Vector3.zero hrp.AssemblyAngularVelocity = Vector3.zero end)
		if config.void_hide_sync_to_ragebot then srb_write(hrp, hide_cf) end
	end)
end
getgenv().stop_void_hide = function()
	if void_hide_conn then void_hide_conn:Disconnect(); void_hide_conn = nil end
	config.void_hide_enabled = false
end

-- ============================================================
-- 35. VOIDSPAM TYPE
-- ============================================================
local vst_conn, void_spin_conn = nil, nil
local vst_phase = "hide"
local vst_phase_start, vst_dt_buf = 0, 0
local vst_last_pos = nil
local vst_pre_enable_cf = nil
getgenv().start_voidspam_type = function()
	if vst_conn then vst_conn:Disconnect() end
	if void_spin_conn then void_spin_conn:Disconnect() end
	vst_phase = "hide" vst_phase_start = tick() vst_dt_buf = 0 vst_last_pos = nil
	local hrp0 = getgenv().get_hrp(localplayer)
	if hrp0 and not vst_pre_enable_cf then vst_pre_enable_cf = hrp0.CFrame end
	void_spin_conn = run_service.Heartbeat:Connect(function()
		if not config.vst_enabled then return end
		local char = localplayer.Character; if not char then return end
		local spd = config.vst_spin_speed or 1e85
		local spinAngle = (tick()*spd) % (2*math.pi)
		local spinCF = CFrame.Angles(0, spinAngle, 0)
		local hrp_s = char:FindFirstChild("HumanoidRootPart")
		if hrp_s then pcall(function() hrp_s.AssemblyAngularVelocity = Vector3.zero end) end
		pcall(function()
			for _, v in pairs(char:GetDescendants()) do
				if v:IsA("Motor6D") then v.Transform = spinCF end
			end
		end)
	end)
	vst_conn = run_service.Heartbeat:Connect(function(dt)
		if not config.vst_enabled then return end
		pcall(function() workspace.FallenPartsDestroyHeight = -math.huge end)
		pcall(function() workspace.FallenPartsDestroyHeight = 0/0 end)
		local hrp = getgenv().get_hrp(localplayer)
		local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then return end
		local vtype = config.vst_type or "Defend"
		if vtype ~= "Bait" then
			if hum:GetState() ~= Enum.HumanoidStateType.Physics then hum:ChangeState(Enum.HumanoidStateType.Physics) end
		end
		local function vst_defend_burst()
			local iters = math.clamp(config.et_total or 1000, 1, 500)
			local base_dist = math.max(config.evs_iter_radius or 500000, 1) * (0.5+math.random()*0.5)
			for _ = 1, iters do
				local base = vst_last_pos or hrp.Position
				local sx = (math.random()<0.5) and 1 or -1
				local sy = (math.random()<0.5) and 1 or -1
				local sz = (math.random()<0.5) and 1 or -1
				pcall(function() hrp.CFrame = CFrame.new(base.X+sx*base_dist, base.Y+sy*base_dist, base.Z+sz*base_dist) end)
				vst_last_pos = hrp.Position
			end
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
		local function vst_hide_burst()
			pcall(function() hrp.CFrame = CFrame.new(hrp.Position.X + (math.random()<0.5 and 1 or -1)*1e6, hrp.Position.Y - 9e25, hrp.Position.Z + (math.random()<0.5 and 1 or -1)*1e6) end)
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
		local function vst_prox_escape()
			if not config.vst_defend_proximity_escape then return end
			local escape_radius = math.max(config.vst_defend_proximity_radius or 20, 1)
			local escape_dist = math.max(config.vst_defend_escape_dist or 1000, 1)
			local my_pos = hrp.Position
			for _, p in ipairs(players:GetPlayers()) do
				if p ~= localplayer and p.Character then
					local t_hrp = p.Character:FindFirstChild("HumanoidRootPart")
					local t_hum = p.Character:FindFirstChildOfClass("Humanoid")
					if t_hrp and t_hum and t_hum.Health > 0 then
						if (my_pos - t_hrp.Position).Magnitude <= escape_radius then
							for _ = 1, 100 do
								local sx = (math.random()<0.5) and 1 or -1
								local sy = (math.random()<0.5) and 1 or -1
								local sz = (math.random()<0.5) and 1 or -1
								pcall(function() hrp.CFrame = CFrame.new(my_pos.X+sx*escape_dist*10, my_pos.Y+sy*500000, my_pos.Z+sz*escape_dist*10) end)
							end
							vst_last_pos = hrp.Position
							return
						end
					end
				end
			end
		end
		if vtype == "Unhittability" then
			vst_prox_escape()
			vst_defend_burst()
			pcall(function()
				for _, p in pairs(players:GetPlayers()) do
					if p ~= localplayer and p.Character then
						local eh = p.Character:FindFirstChild("HumanoidRootPart")
						if eh then
							local y_diff = hrp.Position.Y - eh.Position.Y
							if y_diff >= 0 and y_diff <= (config.vst_unhittability_y_range or 10) then
								melee_fake_cf_store[p] = eh.CFrame
								local emt = getrawmetatable(eh) local eni = emt and rawget(emt, "__newindex")
								local fake_cf_u = CFrame.new(MELEE_FAKE_OFFSET)
								if eni then pcall(eni, eh, "CFrame", fake_cf_u) else pcall(function() rawset(eh, "CFrame", fake_cf_u) end) end
								eh.AssemblyLinearVelocity = Vector3.zero
							else melee_fake_cf_store[p] = nil end
						end
					end
				end
			end)
			vst_prox_escape()
		elseif vtype == "Defend" then
			vst_prox_escape()
			vst_defend_burst()
		elseif vtype == "Attack" then
			local hide_dur = math.clamp(config.vst_hide_time or 0.3, 0.01, 1)
			local atk_dur = math.clamp(config.vst_attack_time or 0.3, 0.01, 1)
			local elapsed = tick() - vst_phase_start
			if vst_phase == "hide" then
				local hm = config.vst_hide_mode or "Defend"
				if hm == "Extreme" then vst_hide_burst()
				elseif hm == "Unhittability" then
					vst_defend_burst()
					pcall(function()
						for _, p in pairs(players:GetPlayers()) do
							if p ~= localplayer and p.Character then
								local eh = p.Character:FindFirstChild("HumanoidRootPart")
								if eh then
									local y_diff = hrp.Position.Y - eh.Position.Y
									if y_diff >= 0 and y_diff <= (config.vst_unhittability_y_range or 10) then
										melee_fake_cf_store[p] = eh.CFrame
										local emt = getrawmetatable(eh) local eni = emt and rawget(emt, "__newindex")
										local fake_cf_u = CFrame.new(MELEE_FAKE_OFFSET)
										if eni then pcall(eni, eh, "CFrame", fake_cf_u) else pcall(function() rawset(eh, "CFrame", fake_cf_u) end) end
										eh.AssemblyLinearVelocity = Vector3.zero
									else melee_fake_cf_store[p] = nil end
								end
							end
						end
					end)
				else vst_defend_burst() end
				if elapsed >= hide_dur then vst_phase = "attack" vst_phase_start = tick() end
			else
				local target = get_teleport_target()
				if target and target.Character then
					local t_hrp = target.Character:FindFirstChild("HumanoidRootPart")
					if t_hrp then
						local head = target.Character:FindFirstChild("Head")
						local dest = tt_resolve_dest(head, t_hrp, "Adaptive")
						if not dest or not tt_validate_vec3(dest) then dest = tt_resolve_void_pos_deep(t_hrp, head) end
						if dest and tt_validate_vec3(dest) then
							for _ = 1, 8 do pcall(tt_force_cframe, hrp, CFrame.new(dest)) end
							manipulation.fire_toward(head or t_hrp, target.Character)
						end
					end
				end
				if elapsed >= atk_dur then vst_phase = "hide" vst_phase_start = tick() end
			end
		elseif vtype == "Bait" then
			hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y - (config.vst_bait_depth or 20), hrp.Position.Z)
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		elseif vtype == "Extreme" then
			pcall(function() hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y - 9e25, hrp.Position.Z) end)
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		elseif vtype == "Random" then
			local iters = math.clamp(config.et_total or 1000, 1, 500)
			local ir = math.max(config.evs_iter_radius or 500000, 1)
			for _ = 1, iters do
				local base = vst_last_pos or hrp.Position
				local sx = (math.random()<0.5) and 1 or -1
				local sy = (math.random()<0.5) and 1 or -1
				local sz = (math.random()<0.5) and 1 or -1
				pcall(function() hrp.CFrame = CFrame.new(base.X+sx*ir*(0.5+math.random()*0.5), base.Y+sy*ir*(0.5+math.random()*0.5), base.Z+sz*ir*(0.5+math.random()*0.5)) end)
				vst_last_pos = hrp.Position
			end
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end
getgenv().stop_voidspam_type = function()
	if vst_conn then vst_conn:Disconnect(); vst_conn = nil end
	if void_spin_conn then void_spin_conn:Disconnect(); void_spin_conn = nil end
	vst_last_pos = nil
end
getgenv().disable_voidspam_type = function()
	config.vst_enabled = false
	getgenv().stop_voidspam_type()
	local hrp = getgenv().get_hrp(localplayer)
	local char = localplayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hrp then
		if vst_pre_enable_cf then pcall(function() hrp.CFrame = vst_pre_enable_cf hrp.AssemblyLinearVelocity = Vector3.zero hrp.AssemblyAngularVelocity = Vector3.zero end) end
		pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero hrp.AssemblyAngularVelocity = Vector3.zero end)
	end
	if hum then
		pcall(function() hum.AutoRotate = true end)
		pcall(function() hum.PlatformStand = false end)
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
		task.defer(function() pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end) end)
	end
	if char then pcall(function() for _, v in pairs(char:GetDescendants()) do if v:IsA("Motor6D") then v.Transform = CFrame.new() end end end) end
	vst_pre_enable_cf = nil
end

-- ============================================================
-- 36. ORBIT
-- ============================================================
local orbit_conn = nil
local orbit_phase = 0
local function orb_get_base()
	if (config.orbit_target or "Self") == "Closest" then
		local closest = getgenv().get_closest(false)
		if closest and closest.Character then
			local t_hrp = closest.Character:FindFirstChild("HumanoidRootPart")
			if t_hrp then return t_hrp.Position end
		end
	end
	return nil
end
local function orb_compute_offset(i, total, phase)
	local frac = (i-1)/math.max(total-1, 1)
	local radius = math.max(config.orbit_radius or 50000, 1)
	local height = config.orbit_height or 0
	local pattern = config.orbit_pattern or "Circle"
	local dir_sign = (config.orbit_direction == "Counter-clockwise") and -1 or 1
	local jitter = config.orbit_jitter or 0
	local tightness = math.max(config.orbit_tightness or 10, 1)
	local a = frac*math.pi*2*dir_sign + phase
	local ox, oy, oz
	if pattern == "Circle" then ox, oy, oz = math.cos(a)*radius, height, math.sin(a)*radius
	elseif pattern == "Ellipse" then ox, oy, oz = math.cos(a)*radius, height, math.sin(a)*(radius*0.5)
	elseif pattern == "Figure8" then ox, oy, oz = math.sin(a)*radius, height, math.sin(a*2)*(radius*0.5)
	elseif pattern == "Helix" then ox, oy, oz = math.cos(a*tightness*0.1)*radius, height + frac*radius*0.5, math.sin(a*tightness*0.1)*radius
	elseif pattern == "Wave" then ox, oy, oz = math.cos(a)*radius, math.sin(frac*math.pi*2*(config.orbit_wave_freq or 1) + phase)*radius*0.4 + height, math.sin(a)*radius
	elseif pattern == "Spiral" then local rm = radius*(0.2+0.8*frac) ox, oy, oz = math.cos(a*tightness*0.1)*rm, height, math.sin(a*tightness*0.1)*rm
	elseif pattern == "Pulse" then local p = math.abs(math.sin(frac*math.pi*(config.orbit_wave_freq or 1) + phase)) ox, oy, oz = math.cos(a)*radius*p, height, math.sin(a)*radius*p
	else ox, oy, oz = math.cos(a)*radius, height, math.sin(a)*radius end
	if config.orbit_invert_x then ox = -ox end
	if config.orbit_invert_z then oz = -oz end
	oy = oy + (config.orbit_y_bias or 0)
	if jitter > 0 then ox = ox + (math.random()-0.5)*jitter oy = oy + (math.random()-0.5)*jitter*0.2 oz = oz + (math.random()-0.5)*jitter end
	return Vector3.new(ox, oy, oz)
end
getgenv().start_orbit = function()
	if orbit_conn then orbit_conn:Disconnect() end
	orbit_phase = 0
	orbit_conn = run_service.Heartbeat:Connect(function(dt)
		if not config.orbit_enabled then return end
		local hrp = getgenv().get_hrp(localplayer)
		local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then return end
		if hum:GetState() ~= Enum.HumanoidStateType.Physics then hum:ChangeState(Enum.HumanoidStateType.Physics) end
		orbit_phase = orbit_phase + dt * (config.orbit_speed or 5) * 0.5
		local iters = math.clamp(config.orbit_iters or 100, 1, 500)
		local base_override = orb_get_base()
		for i = 1, iters do
			local offset = orb_compute_offset(i, iters, orbit_phase)
			local base_pos = base_override or hrp.Position
			pcall(function() hrp.CFrame = CFrame.new(base_pos.X+offset.X, base_pos.Y+offset.Y, base_pos.Z+offset.Z) end)
		end
		if config.orbit_kill_velocity then hrp.AssemblyLinearVelocity = Vector3.zero hrp.AssemblyAngularVelocity = Vector3.zero end
		if config.orbit_sync_ragebot then srb_write(hrp, hrp.CFrame) end
	end)
end
getgenv().stop_orbit = function()
	if orbit_conn then orbit_conn:Disconnect(); orbit_conn = nil end
	config.orbit_enabled = false
	orbit_phase = 0
end

-- ============================================================
-- 37. FLY
-- ============================================================
local fly_conn, fly_nc_conn = nil, nil
getgenv().start_fly = function()
	if fly_conn then fly_conn:Disconnect() end
	if fly_nc_conn then fly_nc_conn:Disconnect() end
	fly_conn = run_service.Heartbeat:Connect(function(dt)
		if not config.fly_enabled then return end
		local hrp = getgenv().get_hrp(localplayer); if not hrp then return end
		local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then pcall(function() hum.PlatformStand = true end) end
		local spd = math.max(config.fly_speed or 60, 1)
		local cf = workspace.CurrentCamera.CFrame
		local move = Vector3.zero
		if user_input_service:IsKeyDown(Enum.KeyCode.W) then move = move + cf.LookVector end
		if user_input_service:IsKeyDown(Enum.KeyCode.S) then move = move - cf.LookVector end
		if user_input_service:IsKeyDown(Enum.KeyCode.A) then move = move - cf.RightVector end
		if user_input_service:IsKeyDown(Enum.KeyCode.D) then move = move + cf.RightVector end
		if user_input_service:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
		if user_input_service:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end
		if move.Magnitude > 0 then move = move.Unit * spd * dt end
		if config.fly_gravity_cancel then
			pcall(function() hrp.AssemblyLinearVelocity = move.Magnitude > 0 and (move/dt) or Vector3.zero end)
		end
		pcall(function() hrp.CFrame = hrp.CFrame + move end)
	end)
	if config.fly_noclip then
		fly_nc_conn = run_service.Stepped:Connect(function()
			if not config.fly_enabled or not config.fly_noclip then return end
			local char = localplayer.Character; if not char then return end
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then pcall(function() part.CanCollide = false end) end
			end
		end)
	end
end
getgenv().stop_fly = function()
	if fly_conn then fly_conn:Disconnect(); fly_conn = nil end
	if fly_nc_conn then fly_nc_conn:Disconnect(); fly_nc_conn = nil end
	config.fly_enabled = false
	local hrp = getgenv().get_hrp(localplayer)
	if hrp then pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end) end
	local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then pcall(function() hum.PlatformStand = false end) end
	local char = localplayer.Character
	if char then for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then pcall(function() part.CanCollide = true end) end end end
end

-- ============================================================
-- 38. BODY MANIP
-- ============================================================
local bm_conn = nil
local function bm_getYawRad()
	local mode = config.bm_yaw_mode or "random"
	if mode == "random" then return math.rad(math.random(0, 360))
	elseif mode == "spin" then return math.rad((tick()*360) % 360)
	elseif mode == "custom" then return math.rad(config.bm_custom_yaw or 0) end
	return 0
end
local function bm_getPitchRad()
	local mode = config.bm_pitch_mode or "down"
	if mode == "down" then return math.rad(89)
	elseif mode == "up" then return math.rad(-89)
	elseif mode == "random" then return math.rad(math.random(-89, 89))
	elseif mode == "custom" then return math.rad(config.bm_custom_pitch or 0) end
	return 0
end
getgenv().start_body_manip = function()
	if bm_conn then bm_conn:Disconnect() end
	config.bm_enabled = true
	bm_conn = run_service.RenderStepped:Connect(function()
		if not config.bm_enabled then return end
		local hrp = getgenv().get_hrp(localplayer); if not hrp then return end
		local character = localplayer.Character; if not character then return end
		local rep = character:FindFirstChild("PhysicsRepRootPart") or hrp
		if config.bm_floor_hide and hrp.Position.Y < 8 then
			pcall(function() rep.CFrame = hrp.CFrame * CFrame.new(0, -3, 0) end)
			return
		end
		local base = hrp.CFrame
		local cf = CFrame.new(base.Position) * CFrame.Angles(0, bm_getYawRad(), 0) * CFrame.Angles(bm_getPitchRad(), 0, 0)
		pcall(function() rep.CFrame = cf end)
	end)
end
getgenv().stop_body_manip = function()
	if bm_conn then bm_conn:Disconnect(); bm_conn = nil end
	config.bm_enabled = false
	pcall(function()
		local character = localplayer.Character; if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		local rep = character:FindFirstChild("PhysicsRepRootPart")
		if hrp and rep then rep.CFrame = hrp.CFrame end
	end)
end

-- ============================================================
-- 39. MAGIC BULLET
-- ============================================================
local mb_enabled = false
local mb_hitchance = 100
local mb_closest_part = true
local mb_hook_ref = nil
local function mb_get_target_part(character)
	if mb_closest_part then
		local cam = workspace.CurrentCamera
		local best, bestDist = nil, math.huge
		for _, part in ipairs(character:GetChildren()) do
			if part:IsA("BasePart") then
				local dist = (part.Position - cam.CFrame.Position).Magnitude
				if dist < bestDist then bestDist = dist best = part end
			end
		end
		return best
	end
	return character:FindFirstChild("HitboxHead") or character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
end
local function mb_acquire()
	local cam = workspace.CurrentCamera; if not cam then return nil end
	local viewport = cam.ViewportSize
	local center = Vector2.new(viewport.X/2, viewport.Y/2)
	local focal = (viewport.X/2)/math.tan(math.rad(cam.FieldOfView)/2)
	local pixelLimit = focal * math.tan(math.rad(150))
	local best, bestDist = nil, math.huge
	for _, player in ipairs(players:GetPlayers()) do
		if player == localplayer then continue end
		local char = player.Character; if not char then continue end
		local hum = char:FindFirstChild("Humanoid"); if not hum or hum.Health <= 0 then continue end
		local part = mb_get_target_part(char); if not part then continue end
		local screen, onScreen = cam:WorldToViewportPoint(part.Position)
		if not onScreen then continue end
		local dist2d = (Vector2.new(screen.X, screen.Y) - center).Magnitude
		if dist2d > pixelLimit then continue end
		if dist2d < bestDist then bestDist = dist2d best = {player=player, character=char, part=part, position=part.Position} end
	end
	return best
end
getgenv().mb_start = function()
	if mb_hook_ref then return end
	mb_enabled = true
	local orig_Raycast = workspace.Raycast
	mb_hook_ref = newcclosure(function(ws, origin, direction, params)
		if mb_enabled and math.random(100) <= mb_hitchance then
			local target = mb_acquire()
			if target then
				return orig_Raycast(ws, origin, (target.position - origin).Unit * direction.Magnitude, params)
			end
		end
		return orig_Raycast(ws, origin, direction, params)
	end)
	hookfunction(workspace.Raycast, mb_hook_ref)
end
getgenv().mb_stop = function()
	if mb_hook_ref then
		pcall(function() hookfunction(workspace.Raycast, mb_hook_ref) end)
		mb_hook_ref = nil
	end
	mb_enabled = false
end
getgenv().mb_set_hitchance = function(v) mb_hitchance = v end
getgenv().mb_set_closest = function(v) mb_closest_part = v end

-- ============================================================
-- 40. UNLOAD (early ref; UI will overwrite)
-- ============================================================
getgenv().unload_all = function()
	getgenv().meowlua_loaded = false
	getgenv().meowlua_loading = false
	getgenv().__meowlua_generation = (tonumber(getgenv().__meowlua_generation) or 0) + 1
	pcall(getgenv().stop_anti_afk); pcall(getgenv().stop_autocollect); pcall(getgenv().stop_safe_zone)
	pcall(getgenv().stop_return_home); pcall(getgenv().stop_teleport_loop); pcall(getgenv().stop_teleport_to_target)
	pcall(getgenv().stop_riot_abuser); pcall(getgenv().stop_riot_abuser_v1); pcall(getgenv().stop_riot_abuser_v2)
	pcall(getgenv().stop_slingshot_bypass); pcall(getgenv().stop_bow_bypass); pcall(getgenv().stop_dagger_bypass)
	pcall(getgenv().stop_projectile_tp); pcall(getgenv().stop_projectile_rapid_fire); pcall(getgenv().stop_melee_bypass)
	pcall(getgenv().stop_evade); pcall(getgenv().stop_orbit); pcall(getgenv().stop_perfect_block)
	pcall(getgenv().stop_extra_voidspam); pcall(getgenv().stop_void_hide); pcall(getgenv().disable_voidspam_type)
	pcall(getgenv().stop_desync); pcall(getgenv().stop_unhittable_desync); pcall(getgenv().stop_body_manip)
	pcall(getgenv().stop_anti_aim); pcall(getgenv().stop_prediction); pcall(getgenv().stop_fake_position)
	pcall(getgenv().stop_pixelation); pcall(getgenv().stop_anti_void_bait); pcall(getgenv().stop_kicia_counter)
	pcall(getgenv().stop_fly); pcall(getgenv().stop_kicia_voidspam); pcall(getgenv().stop_rapid_fire); pcall(getgenv().mb_stop)
	config.ffa_hopping_enabled = false
	for _, c in ipairs(getgenv().all_connections) do pcall(function() c:Disconnect() end) end
	getgenv().all_connections = {}
	pcall(function() Library:Unload() end)
end

-- ============================================================
-- 41. SLEEPY HUB UI
-- ============================================================
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/yenkgg/Sleepy-Hub-UI/refs/heads/main/Library.lua"))()

-- ============================================================
-- STANDALONE MOBILE TOGGLE BUTTON
-- ============================================================
do
	local toggle_gui = Instance.new("ScreenGui")
	toggle_gui.Name = "MeowluaToggleOverlay"
	toggle_gui.ResetOnSpawn = false
	toggle_gui.IgnoreGuiInset = true
	toggle_gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	toggle_gui.DisplayOrder = 99999

	local ok = pcall(function() toggle_gui.Parent = game:GetService("CoreGui") end)
	if not ok then toggle_gui.Parent = localplayer:WaitForChild("PlayerGui") end

	local btn = Instance.new("TextButton")
	btn.Name = "ToggleUIButton"
	btn.Size = UDim2.fromOffset(110, 36)
	btn.Position = UDim2.fromOffset(14, 14)
	btn.BackgroundColor3 = Color3.fromRGB(155, 150, 219)
	btn.BackgroundTransparency = 0.35
	btn.BorderSizePixel = 0
	btn.Text = "Toggle UI"
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 14
	btn.Font = Enum.Font.Code
	btn.AutoButtonColor = false
	btn.Active = true
	btn.Draggable = true
	btn.ZIndex = 5
	btn.Parent = toggle_gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.6
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = btn

	local function press_feedback(t)
		pcall(function()
			TweenService:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { BackgroundTransparency = t }):Play()
		end)
	end

	local function toggle_menu()
		pcall(function()
			Library["items"].Enabled = not Library["items"].Enabled
		end)
	end

	btn.MouseButton1Click:Connect(toggle_menu)
	btn.TouchTap:Connect(toggle_menu)
	btn.MouseButton1Down:Connect(function() press_feedback(0.6) end)
	btn.MouseButton1Up:Connect(function() press_feedback(0.35) end)

	local old_unload = getgenv().unload_all
	getgenv().unload_all = function()
		pcall(function() toggle_gui:Destroy() end)
		if old_unload then old_unload() end
	end
end

local window = Library:window({
	name     = "meowlua",
	suffix   = "private",
	gameInfo = "meowlua private",
})

-- ============================================================
-- MAIN TABS — 5 total so rail fits on mobile
-- ============================================================
local mainTab, combatTab, defenseTab, miscTab, settingsTab = window:tab({
	name = "meowlua",
	tabs = { "Main", "Combat", "Defense", "Misc", "Settings" }
})

-- ---- MAIN (Void + Orbit + Evade + Void Hide) ----
do
	local l = mainTab:column({}) local r = mainTab:column({})
	local sec = l:section({name = "Void", default = true, icon = "rbxassetid://6022668898"})
	sec:toggle({name = "Void", default = false, seperator = true, callback = function(v)
		config.vst_enabled = v play_toggle_sound()
		if v then
			getgenv().start_voidspam_type()
			if (config.vst_type or "Unhittability") == "Unhittability" then
				config.melee_bypass_enabled = true
				config.melee_bypass_y_range = config.vst_unhittability_y_range or 10
				if not melee_active then getgenv().start_melee_bypass() end
			end
		else
			getgenv().disable_voidspam_type()
			if not config.godmode_enabled then getgenv().stop_melee_bypass() end
		end
	end})
	sec:dropdown({name = "Void Mode", items = {"Unhittability","Defend","Attack","Bait","Extreme","Random"}, default = "Unhittability", seperator = true, callback = function(v)
		config.vst_type = v
		if config.vst_enabled then getgenv().stop_voidspam_type() getgenv().start_voidspam_type() end
	end})
	sec:dropdown({name = "Void Direction", items = {"Random","Forward","Backward","Left","Right","Up","Down","Camera","Directional"}, default = "Random", seperator = true, callback = function(v) config.vs_void_direction = v end})
	sec:slider({name = "Spin Speed", min = 1, max = 1e85, interval = 0, default = 1e85, seperator = true, callback = function(v) config.vst_spin_speed = v end})
	sec:slider({name = "Iterations", min = 1, max = 1000, interval = 1, default = 1000, seperator = true, callback = function(v) config.evs_burst = v config.et_total = v end})
	sec:toggle({name = "Kill Velocity", default = true, seperator = true, callback = function(v) config.evs_kill_velocity = v end})
	sec:toggle({name = "Snap Back", default = false, seperator = true, callback = function(v) config.evs_snap_back = v end})
	sec:toggle({name = "Sync To Ragebot", default = false, seperator = true, callback = function(v) config.evs_sync_to_ragebot = v end})
	sec:toggle({name = "Character Origin", default = false, seperator = false, callback = function(v) config.vs_char_origin = v end})

	local dirSec = r:section({name = "Direction", default = true, icon = "rbxassetid://6022668898"})
	dirSec:slider({name = "X+ Direction", min = 1, max = 100000000, interval = 0, default = 5000, seperator = true, callback = function(v) config.vs_dir_xp = v end})
	dirSec:slider({name = "X- Direction", min = 1, max = 100000000, interval = 0, default = 5000, seperator = true, callback = function(v) config.vs_dir_xn = v end})
	dirSec:slider({name = "Y+ Direction", min = 1, max = 100000000, interval = 0, default = 5000, seperator = true, callback = function(v) config.vs_dir_yp = v end})
	dirSec:slider({name = "Y- Direction", min = 1, max = 100000000, interval = 0, default = 5000, seperator = true, callback = function(v) config.vs_dir_yn = v end})
	dirSec:slider({name = "Z+ Direction", min = 1, max = 100000000, interval = 0, default = 5000, seperator = true, callback = function(v) config.vs_dir_zp = v end})
	dirSec:slider({name = "Z- Direction", min = 1, max = 100000000, interval = 0, default = 5000, seperator = true, callback = function(v) config.vs_dir_zn = v end})
	dirSec:slider({name = "Min Distance", min = 1, max = 50000, interval = 1, default = 1, seperator = true, callback = function(v) config.vs_min_dist = v end})
	dirSec:slider({name = "Max Distance", min = 1, max = 500000, interval = 1, default = 50000, seperator = false, callback = function(v) config.vs_max_dist = v end})

	-- Orbit
	local orbSec = l:section({name = "Orbit", default = false, icon = "rbxassetid://6022668898"})
	orbSec:toggle({name = "Orbit", default = false, seperator = true, callback = function(v) config.orbit_enabled = v play_toggle_sound() if v then getgenv().start_orbit() else getgenv().stop_orbit() end end})
	orbSec:slider({name = "Orbit Radius", min = 1, max = 500000, interval = 1, default = 50000, seperator = true, callback = function(v) config.orbit_radius = v end})
	orbSec:slider({name = "Orbit Speed", min = 1, max = 200, interval = 1, default = 5, seperator = true, callback = function(v) config.orbit_speed = v end})
	orbSec:slider({name = "Iterations", min = 1, max = 500, interval = 1, default = 100, seperator = true, callback = function(v) config.orbit_iters = v end})
	orbSec:slider({name = "Height Offset", min = -500000, max = 500000, interval = 1, default = 0, seperator = true, callback = function(v) config.orbit_height = v end})
	orbSec:slider({name = "Jitter", min = 0, max = 100000, interval = 1, default = 0, seperator = true, callback = function(v) config.orbit_jitter = v end})
	orbSec:slider({name = "Tightness", min = 1, max = 100, interval = 1, default = 10, seperator = true, callback = function(v) config.orbit_tightness = v end})
	orbSec:dropdown({name = "Pattern", items = {"Circle","Ellipse","Figure8","Helix","Wave","Spiral","Pulse"}, default = "Circle", seperator = true, callback = function(v) config.orbit_pattern = v end})
	orbSec:dropdown({name = "Target", items = {"Self","Closest"}, default = "Self", seperator = true, callback = function(v) config.orbit_target = v end})
	orbSec:dropdown({name = "Direction", items = {"Clockwise","Counter-clockwise"}, default = "Clockwise", seperator = true, callback = function(v) config.orbit_direction = v end})
	orbSec:toggle({name = "Kill Velocity", default = true, seperator = true, callback = function(v) config.orbit_kill_velocity = v end})
	orbSec:toggle({name = "Sync To Ragebot", default = false, seperator = false, callback = function(v) config.orbit_sync_ragebot = v end})

	-- Evade
	local evSec = r:section({name = "Evade", default = false, icon = "rbxassetid://6022668898"})
	evSec:toggle({name = "Evade", default = false, seperator = true, callback = function(v) config.evade_enabled = v play_toggle_sound() if v then getgenv().start_evade() else getgenv().stop_evade() end end})
	evSec:slider({name = "Min Distance", min = 100, max = 50000, interval = 1, default = 5000, seperator = true, callback = function(v) config.evade_min_dist = v end})
	evSec:slider({name = "Max Distance", min = 100, max = 500000, interval = 1, default = 50000, seperator = true, callback = function(v) config.evade_max_dist = v end})
	evSec:slider({name = "Delay", min = 1, max = 1000, interval = 1, default = 10, seperator = true, callback = function(v) config.evade_delay = v / 100 end})
	evSec:slider({name = "Chaos Amplitude", min = 1, max = 100, interval = 1, default = 1, seperator = true, callback = function(v) config.evade_chaos_amp = v end})
	evSec:slider({name = "Y Bias", min = -50000, max = 50000, interval = 1, default = 0, seperator = true, callback = function(v) config.evade_y_bias = v end})
	evSec:dropdown({name = "Shape", items = {"Sphere","Cube","Flat","Vertical","Helix"}, default = "Sphere", seperator = true, callback = function(v) config.evade_shape = v end})
	evSec:dropdown({name = "Y Mode", items = {"Random","Up","Down","Flat"}, default = "Random", seperator = true, callback = function(v) config.evade_y_mode = v end})
	evSec:dropdown({name = "Axis Lock", items = {"None","X","Y","Z","XZ"}, default = "None", seperator = true, callback = function(v) config.evade_axis_lock = v end})
	evSec:dropdown({name = "Warp Mode", items = {"Instant","Lerp"}, default = "Instant", seperator = true, callback = function(v) config.evade_warp_mode = v end})
	evSec:toggle({name = "Kill Velocity", default = true, seperator = true, callback = function(v) config.evade_kill_velocity = v end})
	evSec:toggle({name = "Invert X", default = false, seperator = true, callback = function(v) config.evade_invert_x = v end})
	evSec:toggle({name = "Invert Z", default = false, seperator = false, callback = function(v) config.evade_invert_z = v end})

	-- Void Hide
	local vhSec = r:section({name = "Void Hide", default = false, icon = "rbxassetid://6022668898"})
	vhSec:toggle({name = "Void Hide", default = false, seperator = true, callback = function(v) config.void_hide_enabled = v if v then getgenv().start_void_hide() else getgenv().stop_void_hide() end end})
	vhSec:slider({name = "X Distance", min = 1, max = 12e25, interval = 0, default = 1000000, seperator = true, callback = function(v) config.void_hide_x = v end})
	vhSec:slider({name = "Y Distance", min = 1, max = 12e25, interval = 0, default = 9e25, seperator = true, callback = function(v) config.void_hide_y = v end})
	vhSec:slider({name = "Z Distance", min = 1, max = 12e25, interval = 0, default = 1000000, seperator = true, callback = function(v) config.void_hide_z = v end})
	vhSec:toggle({name = "Sync To Ragebot", default = false, seperator = false, callback = function(v) config.void_hide_sync_to_ragebot = v end})
end

-- ---- COMBAT (TP + Slingshot + Melee + Rapid Fire + Magic Bullet + Riot) ----
do
	local l = combatTab:column({}) local r = combatTab:column({})
	local tpSec = l:section({name = "Teleportation", default = true, icon = "rbxassetid://6022668898"})
	tpSec:toggle({name = "Teleportation", default = false, seperator = true, callback = function(v) config.teleport_to_target_enabled = v play_toggle_sound() if v then getgenv().start_teleport_to_target() else getgenv().stop_teleport_to_target() end end})
	tpSec:dropdown({name = "Tracking Method", items = {"Adaptive","Predictive"}, default = "Adaptive", seperator = true, callback = function(v) config.teleport_to_target_method = v end})
	tpSec:toggle({name = "Void Mimic", default = false, seperator = true, callback = function(v) config.void_mimic_enabled = v play_toggle_sound() if v then getgenv().start_void_mimic() else getgenv().stop_void_mimic() end end})
	tpSec:dropdown({name = "Target Mode", items = {"Closest","Farthest","LowestHP"}, default = "Closest", seperator = true, callback = function(v) config.teleport_to_target_mode = v end})
	tpSec:slider({name = "Aggression", min = 1, max = 5, interval = 1, default = 3, seperator = true, callback = function(v) config.teleport_to_target_aggression = v end})
	tpSec:slider({name = "Snap Count", min = 1, max = 12, interval = 1, default = 4, seperator = true, callback = function(v) config.teleport_to_target_snap_count = v end})
	tpSec:slider({name = "Height", min = -100, max = 100, interval = 1, default = 0, seperator = true, callback = function(v) config.teleport_to_target_y_offset = v end})
	tpSec:slider({name = "Throttle", min = 0, max = 500, interval = 1, default = 0, seperator = true, callback = function(v) config.teleport_to_target_throttle = v end})
	tpSec:slider({name = "Predictive Stagger", min = 0, max = 10, interval = 1, default = 1, seperator = true, callback = function(v) config.teleport_to_target_stagger = v end})
	tpSec:slider({name = "Search Radius", min = 1, max = 999000000000000, interval = 0, default = 999000000, seperator = true, callback = function(v) config.teleport_to_target_search_radius = v end})
	tpSec:slider({name = "Jitter", min = 0, max = 50, interval = 1, default = 0, seperator = true, callback = function(v) config.teleport_to_target_jitter = v end})
	tpSec:toggle({name = "Target Lead", default = false, seperator = true, callback = function(v) config.teleport_to_target_aim_lead = v end})
	tpSec:toggle({name = "Void Recovery", default = true, seperator = true, callback = function(v) config.teleport_to_target_recover_void = v end})
	tpSec:toggle({name = "Sync To Ragebot", default = false, seperator = true, callback = function(v) config.teleport_to_target_sync_to_ragebot = v end})
	tpSec:toggle({name = "Burst Snap", default = false, seperator = true, callback = function(v) config.teleport_to_target_burst_mode = v end})
	tpSec:slider({name = "Burst Count", min = 1, max = 8, interval = 1, default = 3, seperator = true, callback = function(v) config.teleport_to_target_burst_count = v end})
	tpSec:toggle({name = "Velocity Kill", default = true, seperator = true, callback = function(v) config.teleport_to_target_velocity_kill = v end})
	tpSec:toggle({name = "Orbit Mode", default = false, seperator = true, callback = function(v) config.teleport_to_target_orbit_mode = v end})
	tpSec:slider({name = "Orbit Radius", min = 1, max = 200, interval = 1, default = 5, seperator = true, callback = function(v) config.teleport_to_target_orbit_radius = v end})
	tpSec:slider({name = "Orbit Speed", min = 1, max = 3600, interval = 1, default = 90, seperator = true, callback = function(v) config.teleport_to_target_orbit_speed = v end})
	tpSec:toggle({name = "Target Lock", default = false, seperator = true, callback = function(v) config.teleport_to_target_lock = v end})
	tpSec:toggle({name = "Failsafe", default = true, seperator = false, callback = function(v) config.teleport_to_target_failsafe = v end})

	local slingSec = r:section({name = "Slingshot Bypass", default = false, icon = "rbxassetid://6022668898"})
	slingSec:toggle({name = "Slingshot Bypass", default = false, seperator = true, callback = function(v) if v then getgenv().start_slingshot_bypass() else getgenv().stop_slingshot_bypass() end end})
	slingSec:toggle({name = "Manipulation", default = true, seperator = true, callback = function(v) config.slingshot_bypass_manipulation = v end})
	slingSec:slider({name = "Range", min = 1, max = 100000000000000, interval = 0, default = 100000000000000, seperator = false, callback = function(v) config.slingshot_bypass_range = v end})

	local meleeSec = r:section({name = "Melee Bypass", default = false, icon = "rbxassetid://6022668898"})
	meleeSec:toggle({name = "Melee Bypass", default = false, seperator = true, callback = function(v)
		config.kicia_counter_enabled = v
		play_toggle_sound()
		if v then
			if not config.teleport_to_target_enabled then config.teleport_to_target_enabled = true getgenv().start_teleport_to_target() end
			getgenv().start_kicia_counter()
		else getgenv().stop_kicia_counter() end
	end})
	meleeSec:slider({name = "Aggression", min = 1, max = 5, interval = 1, default = 5, seperator = true, callback = function(v) config.void_counter_aggression = v end})
	meleeSec:slider({name = "Snap Count", min = 1, max = 16, interval = 1, default = 8, seperator = true, callback = function(v) config.void_counter_snap_count = v end})
	meleeSec:slider({name = "Iterations", min = 1, max = 500, interval = 1, default = 500, seperator = false, callback = function(v) config.et_total = v end})

	local rfSec = l:section({name = "Rapid Fire", default = false, icon = "rbxassetid://6022668898"})
	rfSec:toggle({name = "Rapid Fire", default = false, seperator = false, callback = function(v) config.rapid_fire_enabled = v play_toggle_sound() if v then getgenv().start_rapid_fire() else getgenv().stop_rapid_fire() end end})

	local mbSec = l:section({name = "Magic Bullet", default = false, icon = "rbxassetid://6022668898"})
	mbSec:toggle({name = "Magic Bullet", default = false, seperator = true, callback = function(v) config.magic_bullet_enabled = v play_toggle_sound() if v then getgenv().mb_start() else getgenv().mb_stop() end end})
	mbSec:slider({name = "Hit Chance", min = 1, max = 100, interval = 1, default = 100, seperator = true, callback = function(v) config.magic_bullet_hitchance = v getgenv().mb_set_hitchance(v) end})
	mbSec:toggle({name = "Closest Part", default = true, seperator = false, callback = function(v) config.magic_bullet_closest_part = v getgenv().mb_set_closest(v) end})

	local riotSec = r:section({name = "Riot Bypass", default = false, icon = "rbxassetid://6022668898"})
	riotSec:toggle({name = "Riot Bypass", default = false, seperator = true, callback = function(v) config.riot_bypass_enabled = v if v then getgenv().start_riot_abuser() else getgenv().stop_riot_abuser() end end})
	riotSec:slider({name = "Distance", min = 0, max = 100, interval = 1, default = 3, seperator = true, callback = function(v) config.riot_bypass_distance = v end})
	riotSec:slider({name = "Height", min = -30, max = 30, interval = 1, default = 0, seperator = true, callback = function(v) config.riot_bypass_height = v end})
	riotSec:slider({name = "Update Rate", min = 1, max = 100, interval = 1, default = 5, seperator = true, callback = function(v) config.riot_bypass_update_rate = v / 10 end})
	riotSec:toggle({name = "Riot Abuser v1", default = false, seperator = true, callback = function(v) config.riot_abuser_v1_enabled = v if v then getgenv().start_riot_abuser_v1() else getgenv().stop_riot_abuser_v1() end end})
	riotSec:slider({name = "v1 Spin Speed", min = 1, max = 9999, interval = 1, default = 720, seperator = true, callback = function(v) config.riot_abuser_v1_spin_speed = v end})
	riotSec:dropdown({name = "v1 Tracking", items = {"Behind","Above","Front","Below","Left","Right","Exact"}, default = "Behind", seperator = true, callback = function(v) config.riot_abuser_v1_tracking_position = v end})
	riotSec:toggle({name = "Riot Abuser v2", default = false, seperator = true, callback = function(v) config.riot_abuser_v2_enabled = v if v then getgenv().start_riot_abuser_v2() else getgenv().stop_riot_abuser_v2() end end})
	riotSec:slider({name = "v2 Spin Speed", min = 1, max = 3000000, interval = 1, default = 720, seperator = true, callback = function(v) config.riot_abuser_v2_spin_speed = v end})
	riotSec:slider({name = "v2 XZ Jitter", min = 0, max = 120, interval = 1, default = 30, seperator = true, callback = function(v) config.riot_abuser_v2_xjitter = v end})
	riotSec:slider({name = "v2 Y Jitter", min = 0, max = 60, interval = 1, default = 8, seperator = true, callback = function(v) config.riot_abuser_v2_yjitter = v end})
	riotSec:slider({name = "v2 Spread", min = 1, max = 5000, interval = 1, default = 300, seperator = false, callback = function(v) config.riot_abuser_v2_spread = v end})
end

-- ---- DEFENSE (Desync + Fake Pos + Godmode + AVB + Prediction + Kicia + Perfect Block) ----
do
	local l = defenseTab:column({}) local r = defenseTab:column({})

	local dsSec = l:section({name = "Desync", default = true, icon = "rbxassetid://6022668898"})
	dsSec:toggle({name = "Desync", default = false, seperator = true, callback = function(v) config.desync_enabled = v if v then getgenv().start_desync() else getgenv().stop_desync() end end})
	dsSec:slider({name = "Intensity", min = 1, max = 100, interval = 1, default = 50, seperator = true, callback = function(v) config.desync_intensity = v end})
	dsSec:slider({name = "Speed", min = 1, max = 100, interval = 1, default = 10, seperator = true, callback = function(v) config.desync_speed = v end})
	dsSec:slider({name = "Angle", min = 0, max = 360, interval = 1, default = 90, seperator = true, callback = function(v) config.desync_angle = v end})
	dsSec:slider({name = "Jitter", min = 0, max = 180, interval = 1, default = 20, seperator = true, callback = function(v) config.desync_jitter = v end})
	dsSec:toggle({name = "Flip", default = false, seperator = false, callback = function(v) config.desync_flip = v end})

	local uhSec = r:section({name = "Unhittable Desync", default = false, icon = "rbxassetid://6022668898"})
	uhSec:toggle({name = "Unhittable Desync", default = false, seperator = true, callback = function(v) config.desync_unhittable_enabled = v if v then getgenv().start_unhittable_desync() else getgenv().stop_unhittable_desync() end end})
	uhSec:slider({name = "Intensity", min = 1, max = 100, interval = 1, default = 50, seperator = true, callback = function(v) config.desync_unhittable_intensity = v end})
	uhSec:slider({name = "Radius", min = 100, max = 100000, interval = 1, default = 9000, seperator = true, callback = function(v) config.desync_unhittable_radius = v end})
	uhSec:slider({name = "Iterations", min = 1, max = 500, interval = 1, default = 100, seperator = true, callback = function(v) config.desync_unhittable_iters = v end})
	uhSec:slider({name = "Activation Range", min = 1, max = 50, interval = 1, default = 10, seperator = false, callback = function(v) config.desync_unhittable_y_range = v end})

	local fpSec = l:section({name = "Fake Position", default = false, icon = "rbxassetid://6022668898"})
	fpSec:toggle({name = "Fake Position", default = false, seperator = true, callback = function(v) config.fake_pos_enabled = v if v then getgenv().start_fake_position() else getgenv().stop_fake_position() end end})
	fpSec:slider({name = "Radius", min = 1, max = 5000, interval = 1, default = 500, seperator = true, callback = function(v) config.fake_pos_radius = v end})
	fpSec:slider({name = "Height", min = -2000, max = 2000, interval = 1, default = 0, seperator = true, callback = function(v) config.fake_pos_height = v end})
	fpSec:slider({name = "Speed", min = 1, max = 500, interval = 1, default = 50, seperator = true, callback = function(v) config.fake_pos_speed = v end})
	fpSec:slider({name = "Packet Count", min = 1, max = 20, interval = 1, default = 5, seperator = true, callback = function(v) config.fake_pos_count = v end})
	fpSec:dropdown({name = "Pattern", items = {"Scatter","Linear","Circle","Random","Spiral"}, default = "Scatter", seperator = true, callback = function(v) config.fake_pos_drop1 = v end})
	fpSec:dropdown({name = "Distribution", items = {"Random","Uniform","Weighted","Radial","Clustered"}, default = "Random", seperator = true, callback = function(v) config.fake_pos_drop2 = v end})
	fpSec:dropdown({name = "Axis Lock", items = {"None","X","Y","Z","XZ"}, default = "None", seperator = true, callback = function(v) config.fake_pos_drop3 = v end})
	fpSec:toggle({name = "Reverse", default = false, seperator = true, callback = function(v) config.fake_pos_tog2 = v end})
	fpSec:toggle({name = "Random Radius", default = false, seperator = false, callback = function(v) config.fake_pos_tog3 = v end})

	local gmSec = r:section({name = "Godmode", default = false, icon = "rbxassetid://6022668898"})
	gmSec:toggle({name = "Godmode", default = false, seperator = true, callback = function(v) config.godmode_enabled = v config.melee_bypass_enabled = v play_toggle_sound() if v then getgenv().start_melee_bypass() else getgenv().stop_melee_bypass() end end})
	gmSec:slider({name = "Activation Range", min = 1, max = 50, interval = 1, default = 10, seperator = false, callback = function(v) config.godmode_y_range = v config.melee_bypass_y_range = v end})

	local avbSec = r:section({name = "Anti Void Bait", default = false, icon = "rbxassetid://6022668898"})
	avbSec:toggle({name = "Freeze", default = false, seperator = true, callback = function(v) config.anti_void_bait_freeze = v if v then config.anti_void_bait_hide = false getgenv().start_anti_void_bait_freeze() else getgenv().stop_anti_void_bait() end end})
	avbSec:toggle({name = "Hide", default = false, seperator = false, callback = function(v) config.anti_void_bait_hide = v if v then config.anti_void_bait_freeze = false getgenv().start_anti_void_bait_hide() else getgenv().stop_anti_void_bait() end end})

	local predSec = l:section({name = "Prediction", default = false, icon = "rbxassetid://6022668898"})
	predSec:toggle({name = "Prediction", default = false, seperator = true, callback = function(v) config.prediction_enabled = v play_toggle_sound() if v then getgenv().start_prediction() else getgenv().stop_prediction() end end})
	predSec:slider({name = "Activation Range", min = 1, max = 200, interval = 1, default = 20, seperator = true, callback = function(v) config.prediction_activation_range = v end})
	predSec:slider({name = "Distance Range", min = 1, max = 500, interval = 1, default = 30, seperator = false, callback = function(v) config.prediction_distance_range = v end})

	local kiciaSec = l:section({name = "Kicia Voidspam", default = false, icon = "rbxassetid://6022668898"})
	kiciaSec:toggle({name = "Kicia Voidspam", default = false, seperator = false, callback = function(v) config.kicia_voidspam_enabled = v if v then getgenv().start_kicia_voidspam() else getgenv().stop_kicia_voidspam() end end})

	local pbSec = r:section({name = "Perfect Block", default = false, icon = "rbxassetid://6022668898"})
	pbSec:toggle({name = "Perfect Block", default = false, seperator = false, callback = function(v) config.perfect_block_enabled = v play_toggle_sound() if v then getgenv().start_perfect_block() else getgenv().stop_perfect_block() end end})
end

-- ---- MISC (Character + Automation + Teleport Loop) ----
do
	local l = miscTab:column({}) local r = miscTab:column({})

	local skinSec = l:section({name = "Skin Changer", default = true, icon = "rbxassetid://6022668898"})
	local function applyskin(c)
		if not (config.profile.skinchanger.enabled and c) then return end
		local h = c:WaitForChild("Humanoid", 5)
		local targetId = tonumber(config.profile.skinchanger.userid)
		if not h or not targetId then return end
		pcall(function()
			local model = players:CreateHumanoidModelFromUserId(targetId)
			if not model then return end
			for _, obj in ipairs(c:GetChildren()) do
				if obj:IsA("Accessory") or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("BodyColors") or obj:IsA("CharacterMesh") or obj:IsA("ShirtGraphic") then obj:Destroy() end
			end
			local head = c:FindFirstChild("Head")
			if head then local face = head:FindFirstChildOfClass("Decal") if face then face:Destroy() end end
			for _, obj in ipairs(model:GetChildren()) do
				if obj:IsA("Accessory") or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("BodyColors") or obj:IsA("CharacterMesh") or obj:IsA("ShirtGraphic") then obj:Clone().Parent = c
				elseif obj.Name == "Head" then
					local targetFace = obj:FindFirstChildOfClass("Decal")
					if targetFace and head then targetFace:Clone().Parent = head end
				end
			end
			model:Destroy()
		end)
	end
	skinSec:toggle({name = "Enable", default = false, seperator = true, callback = function(v) config.profile.skinchanger.enabled = v if v and localplayer.Character then applyskin(localplayer.Character) end end})
	skinSec:textbox({name = "User Id", placeholder = "type user id...", callback = function(v) config.profile.skinchanger.userid = v or "1" if config.profile.skinchanger.enabled and localplayer.Character then applyskin(localplayer.Character) end end})
	localplayer.CharacterAdded:Connect(function(c) task.defer(applyskin, c) end)

	local aaSec = l:section({name = "Anti Aim", default = false, icon = "rbxassetid://6022668898"})
	aaSec:toggle({name = "Anti Aim", default = false, seperator = true, callback = function(v) config.bm_enabled = v play_toggle_sound() if v then getgenv().start_body_manip() else getgenv().stop_body_manip() end end})
	aaSec:dropdown({name = "Yaw Mode", items = {"random","spin","custom"}, default = "random", seperator = true, callback = function(v) config.bm_yaw_mode = v end})
	aaSec:dropdown({name = "Pitch Mode", items = {"down","up","random","custom"}, default = "down", seperator = true, callback = function(v) config.bm_pitch_mode = v end})
	aaSec:slider({name = "Custom Yaw", min = -180, max = 180, interval = 1, default = 0, seperator = true, callback = function(v) config.bm_custom_yaw = v end})
	aaSec:slider({name = "Custom Pitch", min = -89, max = 89, interval = 1, default = 0, seperator = true, callback = function(v) config.bm_custom_pitch = v end})
	aaSec:toggle({name = "Underground", default = false, seperator = false, callback = function(v) config.bm_floor_hide = v end})

	local autoSec = r:section({name = "Automation", default = true, icon = "rbxassetid://6022668898"})
	autoSec:toggle({name = "Auto Collect", default = false, seperator = true, callback = function(v) config.autocollect_enabled = v if v then getgenv().start_autocollect() else getgenv().stop_autocollect() end end})
	autoSec:slider({name = "Collect Radius", min = 10, max = 300, interval = 1, default = 120, seperator = true, callback = function(v) config.autocollect_radius = v end})
	autoSec:toggle({name = "Safe Zone Rescue", default = false, seperator = true, callback = function(v) config.safe_zone_enabled = v if v then getgenv().start_safe_zone() else getgenv().stop_safe_zone() end end})
	autoSec:slider({name = "Depth Threshold", min = -200, max = 50, interval = 1, default = -10, seperator = true, callback = function(v) config.safe_zone_y = v end})
	autoSec:toggle({name = "Return Home", default = false, seperator = true, callback = function(v) config.return_home_enabled = v if v then getgenv().start_return_home() else getgenv().stop_return_home() end end})
	autoSec:button({name = "Save Home Position", seperator = true, callback = function() local hrp = getgenv().get_hrp(localplayer) if hrp then getgenv().home_position = hrp.Position notify("System", "Home position saved.") end end})
	autoSec:slider({name = "Return Delay", min = 1, max = 150, interval = 1, default = 10, seperator = true, callback = function(v) config.home_return_delay = v / 10 end})
	autoSec:toggle({name = "Anti AFK", default = false, seperator = true, callback = function(v) config.anti_afk_enabled = v if v then getgenv().start_anti_afk() else getgenv().stop_anti_afk() end end})
	autoSec:toggle({name = "FFA Hopping", default = false, seperator = false, callback = function(v) config.ffa_hopping_enabled = v end})

	local loopSec = r:section({name = "Teleport Loop", default = false, icon = "rbxassetid://6022668898"})
	loopSec:toggle({name = "Teleport Loop", default = false, seperator = true, callback = function(v) if v then getgenv().start_teleport_loop() else getgenv().stop_teleport_loop() end end})
	loopSec:slider({name = "Loop Delay", min = 10, max = 1000, interval = 1, default = 50, seperator = true, callback = function(v) config.teleport_loop_delay = v / 100 end})
	loopSec:button({name = "Add Waypoint", seperator = true, callback = function() local hrp = getgenv().get_hrp(localplayer) if hrp then table.insert(getgenv().loop_waypoints, hrp.Position) notify("System", "Waypoint added.") end end})
	loopSec:button({name = "Clear Waypoints", seperator = false, callback = function() getgenv().loop_waypoints = {} getgenv().loop_index = 1 notify("System", "Waypoints cleared.") end})
end

-- ---- SETTINGS ----
do
	local l = settingsTab:column({}) local r = settingsTab:column({})
	local sndSec = r:section({name = "Sounds", default = true, icon = "rbxassetid://6022668898"})
	sndSec:toggle({name = "Enable Sounds", default = false, seperator = true, callback = function(v) config.sounds_enabled = v end})
	sndSec:dropdown({name = "Select Sound", items = {"Space","Pop","Bonk","Skeet","Neverlose","Slip"}, default = "Space", seperator = true, callback = function(v) astral_sound_selected = v astral_toggle_sound.SoundId = astral_sound_ids[v] or astral_sound_ids.Space end})
	sndSec:slider({name = "Sound Volume", min = 0, max = 100, interval = 1, default = 50, seperator = true, callback = function(v) astral_sound_volume = v / 100 astral_toggle_sound.Volume = astral_sound_volume end})
	sndSec:button({name = "Test Sound", seperator = false, callback = function() local prev = config.sounds_enabled config.sounds_enabled = true play_toggle_sound() config.sounds_enabled = prev end})

	local menuSec = l:section({name = "Menu", default = true, icon = "rbxassetid://6022668898"})
	menuSec:button({name = "Unload", seperator = false, callback = function() getgenv().unload_all() end})
end

-- ============================================================
-- 42. INIT
-- ============================================================
task.delay(1, function() notify("meowlua", "Loaded successfully.") end)
Library:init_config(window)
environment.meowlua_loading = false
environment.meowlua_loaded = true
return AC