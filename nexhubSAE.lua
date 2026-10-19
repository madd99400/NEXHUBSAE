local function debugPrint(message)
	local genv = typeof(getgenv) == "function" and getgenv() or _G
	if type(genv.NexDebugPrint) == "function" then
		pcall(genv.NexDebugPrint, message)
	end
end

do
	local renv = (type(getrenv) == "function" and getrenv()) or _G
	local genv = (type(getgenv) == "function" and getgenv()) or _G

	if not genv.__NEX_LOG_HOOK then
		genv.__NEX_LOG_HOOK = {
			enabled = true,
			origPrint = renv.print,
			origWarn = renv.warn,
		}

		local function isGameDebugMsg(...)
			local hook = genv.__NEX_LOG_HOOK
			if not (hook and hook.enabled) then return false end
			local n = select("#", ...)
			if n == 0 then return false end
			for i = 1, math.min(n, 5) do
				local v = tostring(select(i, ...) or "")
				if v:find("%[Trace%]") or v:find("%[Debug%]") or v:find("%[Info%]")
				   or v:find("GuardComponent") or v:find("EggToolDisplay") or v:find("PlacedEggRenderer")
				   or v:find("EggState") or v:find("PlotState")
				   or v:find("RaceRallyPortal") or v:find("RaceRally") then
					return true
				end
			end
			return false
		end

		local hook = genv.__NEX_LOG_HOOK
		local newPrint = function(...)
			if isGameDebugMsg(...) then return end
			if hook.origPrint then return hook.origPrint(...) end
		end

		local newWarn = function(...)
			if isGameDebugMsg(...) then return end
			if hook.origWarn then return hook.origWarn(...) end
		end

		pcall(function()
			if type(hookfunction) == "function" then
				if hook.origPrint then
					local ok, old = pcall(hookfunction, hook.origPrint, (type(newcclosure) == "function" and newcclosure(newPrint)) or newPrint)
					if ok and old then hook.origPrint = old end
				end
				if hook.origWarn then
					local ok, old = pcall(hookfunction, hook.origWarn, (type(newcclosure) == "function" and newcclosure(newWarn)) or newWarn)
					if ok and old then hook.origWarn = old end
				end
			else
				renv.print = newPrint
				renv.warn = newWarn
			end
		end)
	end
end

local ACCENT_COLOR = Color3.fromRGB(148, 0, 211)
local HUB_TITLE = "NexHub"
local HUB_SUBTITLE = "Steal An Egg | V 1.6"
local HUB_LOGO = "rbxassetid://82006436469351"

local function loadModernV2()
	local sources = {
		"https://shinzux.vercel.app/files/ambaruto.txt",
		"https://raw.githubusercontent.com/nexiuse/NexHubNewUI/refs/heads/main/MainV2.lua",
	}
	for _, url in ipairs(sources) do
		local ok, result = pcall(function()
			local source = game:HttpGet(url)
			local fn, compileError = loadstring(source)
			if not fn then
				error(compileError)
			end
			return fn()
		end)
		if ok and type(result) == "table" then
			return result
		end
		warn("[NexHub] Gagal memuat ModernV2 dari " .. url .. ": " .. tostring(result))
	end
	return nil
end

local ModernV2 = loadModernV2()
assert(ModernV2, "ModernV2 gagal dimuat dari semua sumber.")
pcall(function()
	ModernV2.GlobalLogo = HUB_LOGO
end)

local nexLibrary = {}
nexLibrary.ManualQuickDefaults = {}

local notifyUser

local function isPremiumUser()
	local env = (type(getgenv) == "function" and getgenv()) or _G
	return env.NexHubTier == "Premium"
end

local function notifyPremium(featureName)
	local title = "Premium Required ✨"
	local message = "Fitur " .. tostring(featureName) .. " hanya untuk pengguna Key Premium!"
	if type(nexLibrary) == "table" and type(nexLibrary.Notify) == "function" then
		pcall(nexLibrary.Notify, title, message, 5, "lucide:crown")
	elseif type(notifyUser) == "function" then
		pcall(notifyUser, title, message)
	end
end

local function newFlag(prefix, name)
	return prefix .. ":" .. tostring(name)
end

local function toArray(value)
	local out = {}
	if type(value) ~= "table" then
		return out
	end
	for key, entry in pairs(value) do
		if type(key) == "number" then
			out[#out + 1] = tostring(entry)
		elseif entry == true then
			out[#out + 1] = tostring(key)
		end
	end
	table.sort(out)
	return out
end

local function trySet(target, value)
	if type(target) ~= "table" then
		return false
	end
	for _, methodName in ipairs({ "SetValue", "Set", "Select" }) do
		local fn = target[methodName]
		if type(fn) == "function" then
			local ok = pcall(fn, target, value)
			if ok then
				return true
			end
		end
	end
	return false
end

local function tryUpdateText(widget, title, text)
	if type(widget) ~= "table" then
		return
	end
	local applied = false
	for _, methodName in ipairs({ "SetContent", "SetDescription", "SetText", "Set", "Update", "SetValue" }) do
		local fn = widget[methodName]
		if type(fn) == "function" then
			local ok
			if methodName == "Set" or methodName == "Update" then
				ok = pcall(fn, widget, { Name = title, Title = title, Content = text, Description = text, Text = text })
			else
				ok = pcall(fn, widget, text)
			end
			if ok then
				applied = true
				break
			end
		end
	end
	if not applied then
		pcall(function()
			if widget.Content and widget.Content.Text ~= nil then
				widget.Content.Text = text
			elseif widget.Description and widget.Description.Text ~= nil then
				widget.Description.Text = text
			elseif widget.TextLabel then
				widget.TextLabel.Text = text
			end
		end)
	end
end

local function makeState(default)
	local value = default
	local subscribers = {}
	local state = {}
	function state:Get()
		return value
	end
	function state:Set(newValue)
		value = newValue
		for _, callback in ipairs(subscribers) do
			task.spawn(pcall, callback, newValue)
		end
	end
	function state:Subscribe(callback)
		subscribers[#subscribers + 1] = callback
		return {
			Disconnect = function()
				local index = table.find(subscribers, callback)
				if index then
					table.remove(subscribers, index)
				end
			end,
		}
	end
	return state
end

local TAB_LAYOUT = {
	Farm = {
		{ Group = "Farm Features", Subs = {
			{ Name = "Steal", Icon = "lucide:hand", Sections = { "Auto Steal" } },
		} },
	},
	Event = {
		{ Group = "Event Features", Subs = {
			{ Name = "Race Rally", Icon = "lucide:flag", Sections = { "Race Rally" } },
			{ Name = "Shooting Star", Icon = "lucide:sparkles", Sections = { "Shooting Star" } },
		} },
	},
	Base = {
		{ Group = "Base Management", Subs = {
			{ Name = "Place Egg", Icon = "lucide:egg", Sections = { "Auto Place Egg" } },
			{ Name = "Hatch", Icon = "lucide:sparkles", Sections = { "Auto Hatch & Equip" } },
		} },
		{ Group = "Training & Pet", Subs = {
			{ Name = "Train", Icon = "lucide:footprints", Sections = { "Auto Treadmill" } },
			{ Name = "Favorite", Icon = "lucide:star", Sections = { "Auto Favorite" } },
		} },
		{ Group = "Economy", Subs = {
			{ Name = "Sell", Icon = "lucide:coins", Sections = { "Auto Sell" } },
			{ Name = "Fuse", Icon = "lucide:merge", Sections = { "Auto Fuse Machine" } },
		} },
	},
	Player = {
		{ Group = "Player Features", Subs = {
			{ Name = "Movement", Icon = "lucide:zap", Sections = { "Movement", "Character" } },
			{ Name = "Combat & ESP", Icon = "lucide:swords", Sections = { "Combat", "ESP" } },
		} },
	},
	Predictor = {
		{ Group = "Predictor Features", Subs = {
			{ Name = "Predictor", Icon = "lucide:sparkles", Sections = { "Egg Predictor", "Fuse Predictor" } },
			{ Name = "Webhook", Icon = "lucide:webhook", Sections = { "Discord Webhook" } },
		} },
	},
	Misc = {
		{ Group = "Misc Features", Subs = {
			{ Name = "Performance", Icon = "lucide:gauge", Sections = { "Performance" } },
			{ Name = "Utility", Icon = "lucide:wrench", Sections = { "Utility" } },
		} },
	},
}

local SECTION_ICONS = {
	["Auto Steal"] = "lucide:hand",
	["Race Rally"] = "lucide:flag",
	["Shooting Star"] = "lucide:sparkles",
	["Auto Place Egg"] = "lucide:egg",
	["Auto Treadmill"] = "lucide:footprints",
	["Auto Hatch & Equip"] = "lucide:sparkles",
	["Auto Sell"] = "lucide:coins",
	["Auto Fuse Machine"] = "lucide:merge",
	["Auto Favorite"] = "lucide:star",
	["ESP"] = "lucide:eye",
	["Movement"] = "lucide:zap",
	["Character"] = "lucide:user",
	["Combat"] = "lucide:swords",
	["Auto Progression"] = "lucide:trending-up",
	["Server"] = "lucide:server",
	["Discord Webhook"] = "lucide:webhook",
	["Egg Predictor"] = "lucide:egg",
	["Fuse Predictor"] = "lucide:merge",
	["Performance"] = "lucide:gauge",
	["Utility"] = "lucide:wrench",
}

local SECTION_DIVIDERS = {
	["Auto Steal"] = {
		["Auto Steal"] = "Controls",
		["Target Areas"] = "Targets & Filters",
		["Steal Missing Lab Eggs"] = "Priority",
		["Instant Steal"] = "Movement",
		["Anti Guard Panel"] = "Safety",
	},
	["Race Rally"] = {
		["Race Status"] = "Event Information",
		["Auto Join Race"] = "Automation",
		["Auto Complete Race"] = "Race Controls",
		["Auto Claim Milestones"] = "Milestones & Rewards",
		["Auto Buy Nitro Mutation"] = "Race Shop",
	},
	["Shooting Star"] = {
		["Star Status"] = "Event Information",
		["Auto Catch Shooting Star"] = "Catch Automation",
		["Select Pet to Convert"] = "Mount Management",
	},
	["Auto Place Egg"] = {
		["Place Egg Rule"] = "Rules",
		["Place Rarities"] = "Filters",
	},
	["Auto Hatch & Equip"] = {
		["Hatch Min Rarity"] = "Hatch Filters",
		["Auto Equip Best"] = "Equip",
	},
	["Auto Sell"] = {
		["Pet Sell Preview"] = "Pets",
		["Egg Sell Preview"] = "Eggs",
	},
	["Auto Fuse Machine"] = {
		["Fuse Priority Mode"] = "Rules",
		["Skip Mutated Pets"] = "Safety",
	},
	["Auto Favorite"] = {
		["Favorite Rule"] = "Rules",
		["Auto Favorite Equipped"] = "Equipped Pets",
	},
	["ESP"] = {
		["ESP Min Rarity"] = "Egg Filters",
		["ESP Guards"] = "Guards",
		["ESP Players"] = "Players",
	},
	["Server"] = {
		["Server Hop Mode"] = "Server Hop",
		["Job ID"] = "Join By Job ID",
		["Rejoin Server"] = "Rejoin",
	},
	["Discord Webhook"] = {
		["Test Webhook"] = "Actions",
		["Ping @everyone"] = "Options",
	},
	["Performance"] = {
		["FPS Boost"] = "Optimizer",
		["Optimizer"] = "Optimizer",
		["FPS and Ping"] = "FPS & Ping HUD",
		["FPS and Ping Size"] = "FPS & Ping HUD",
	},
}

local function makeSectionAdapter(modernSection, sectionName, nexName, isSubtab)
	local adapter = { Instance = nil, _name = sectionName }

	local pendingHeader = isSubtab and nexName or nil

	local pendingDividers = {}
	for elementName, label in pairs(SECTION_DIVIDERS[nexName or ""] or {}) do
		pendingDividers[elementName] = label
	end

	local function beforeElement(spec)
		if pendingHeader then
			local headerText = pendingHeader
			pendingHeader = nil
			pcall(function()
				modernSection:AddDivider({ Text = headerText })
			end)
		end
		local label = spec and pendingDividers[spec.Name]
		if label then
			pendingDividers[spec.Name] = nil
			pcall(function()
				modernSection:AddDivider({ Text = label })
			end)
		end
	end

	local function displayName(spec)
		return tostring(spec and spec.Name or "")
	end

	function adapter:CreateToggle(spec)
		beforeElement(spec)
		local isLocked = spec.Locked == true or (spec.Premium == true and not isPremiumUser())
		if spec.Locked == nil and isLocked then
			spec.Locked = true
		end
		local handle = { Value = spec.Default == true and not isLocked, _exclusive = nil, Locked = isLocked }
		local silent = false
		local modernToggle

		local function emit(newValue)
			if isLocked and newValue == true then
				handle.Value = false
				if modernToggle then
					pcall(trySet, modernToggle, false)
				end
				notifyPremium(spec.Name)
				return
			end
			handle.Value = newValue == true
			if handle._exclusive and handle.Value then
				handle._exclusive:_activated(handle)
			end
			if not silent and type(spec.Callback) == "function" then
				task.spawn(pcall, spec.Callback, handle.Value)
			end
		end

		local ok, created = pcall(function()
			local toggleSpec = {
				Name = displayName(spec),
				Default = spec.Default == true and not isLocked,
				Flag = newFlag("T", sectionName .. "/" .. tostring(spec.Name)),
				Callback = emit,
			}
			if isLocked then
				toggleSpec.Locked = true
				toggleSpec.TextLocked = spec.TextLocked or "Premium Required"
			elseif spec.Locked ~= nil then
				toggleSpec.Locked = spec.Locked
				toggleSpec.TextLocked = spec.TextLocked
			end
			if spec.Tooltip ~= nil then
				toggleSpec.Tooltip = spec.Tooltip
			end
			return modernSection:AddToggle(toggleSpec)
		end)
		modernToggle = ok and created or nil
		handle.Instance = modernToggle

		function handle.Get()
			return handle.Value
		end
		function handle.GetValue()
			return handle.Value
		end
		function handle.Set(self, newValue, fireCallback)
			local flag = newValue == true
			if type(self) ~= "table" then
				flag = self == true
			end
			if isLocked and flag then
				flag = false
			end
			silent = fireCallback == false
			handle.Value = flag
			if modernToggle then
				trySet(modernToggle, flag)
			end
			silent = false
			if fireCallback == false then
				return
			end
		end
		function handle.JoinExclusiveGroup(self, group)
			if group and group._join then
				group:_join(handle)
			end
		end
		function handle.GetQuickPath()
			return nil
		end
		return handle
	end

	local function buildDropdown(spec, multi)
		beforeElement(spec)
		local handle = { Value = nil }
		local options = {}
		for _, option in ipairs(spec.Options or {}) do
			options[#options + 1] = tostring(option)
		end
		local silent = false

		local default = spec.Default
		if multi then
			default = toArray(default)
		elseif type(default) == "table" then
			default = default[1]
		end
		handle.Value = default

		local function emit(newValue)
			if multi then
				handle.Value = newValue
			else
				handle.Value = type(newValue) == "table" and newValue[1] or newValue
			end
			if not silent and type(spec.Callback) == "function" then
				task.spawn(pcall, spec.Callback, handle.Value)
			end
		end

		local ok, created = pcall(function()
			return modernSection:AddDropdown({
				Name = displayName(spec),
				Values = options,
				Default = default,
				Multi = multi,
				Search = #options > 8,
				AllowNone = multi,
				Flag = newFlag("D", sectionName .. "/" .. tostring(spec.Name)),
				Callback = emit,
			})
		end)
		local modernDropdown = ok and created or nil
		handle.Instance = modernDropdown

		function handle.Get()
			return handle.Value
		end
		function handle.GetValue()
			return handle.Value
		end
		function handle.Set(self, newValue, fireCallback)
			if type(self) ~= "table" or self ~= handle then
				newValue = self
			end
			silent = fireCallback == false
			handle.Value = newValue
			if modernDropdown then
				trySet(modernDropdown, newValue)
			end
			silent = false
		end
		function handle.SetOptions(self, newOptions)
			local list = {}
			for _, option in ipairs(newOptions or {}) do
				list[#list + 1] = tostring(option)
			end
			options = list
			if modernDropdown and type(modernDropdown.SetValues) == "function" then
				pcall(modernDropdown.SetValues, modernDropdown, list)
			end
		end
		handle.SetValues = handle.SetOptions
		function handle.GetQuickPath()
			return nil
		end
		return handle
	end

	function adapter:CreateDropdown(spec)
		return buildDropdown(spec, false)
	end
	function adapter:CreateMultiDropdown(spec)
		return buildDropdown(spec, true)
	end

	function adapter:CreateSlider(spec)
		beforeElement(spec)
		local handle = { Value = spec.Default or spec.Min or 0 }
		local silent = false
		local increment = tonumber(spec.Increment) or 1
		local rounding = 0
		if increment < 1 then
			rounding = increment <= 0.01 and 2 or 1
		end
		if spec.AllowDecimals and rounding == 0 then
			rounding = 1
		end

		local customFormat = type(spec.ValueFormat) == "function"
		local textInput = nil
		local modernSlider
		local syncing = false

		local function emit(newValue)
			handle.Value = newValue
			if customFormat and textInput and not syncing then
				syncing = true
				local okFmt, label = pcall(spec.ValueFormat, newValue)
				if okFmt then
					trySet(textInput, tostring(label))
				end
				syncing = false
			end
			if not silent and type(spec.Callback) == "function" then
				task.spawn(pcall, spec.Callback, newValue)
			end
		end

		local ok, created = pcall(function()
			return modernSection:AddSlider({
				Name = displayName(spec),
				Min = spec.Min or 0,
				Max = spec.Max or 100,
				Default = spec.Default or spec.Min or 0,
				Increment = increment,
				Rounding = rounding,
				Type = customFormat and "" or (spec.Unit == "%" and "%" or (spec.Unit and (" " .. tostring(spec.Unit)) or "")),
				Flag = newFlag("S", sectionName .. "/" .. tostring(spec.Name)),
				Callback = emit,
			})
		end)
		modernSlider = ok and created or nil
		handle.Instance = modernSlider

		if customFormat and type(spec.ValueParse) == "function" then
			local initialLabel = ""
			local okFmt, label = pcall(spec.ValueFormat, handle.Value)
			if okFmt then
				initialLabel = tostring(label)
			end
			local okInput, createdInput = pcall(function()
				return modernSection:AddTextInput({
					Name = displayName({ Name = tostring(spec.Name) .. " (ketik)", SubOf = true }),
					Placeholder = "mis. 250k, 50m, 1.5b",
					Default = initialLabel,
					Callback = function(text)
						if syncing then
							return
						end
						local okParse, position = pcall(spec.ValueParse, text)
						if okParse and type(position) == "number" and modernSlider then
							syncing = true
							trySet(modernSlider, position)
							syncing = false
						end
					end,
				})
			end)
			textInput = okInput and createdInput or nil
		end

		function handle.Get()
			return handle.Value
		end
		function handle.GetValue()
			return handle.Value
		end
		function handle.Set(self, newValue, fireCallback)
			if type(self) ~= "table" or self ~= handle then
				newValue = self
			end
			silent = fireCallback == false
			handle.Value = newValue
			if modernSlider then
				trySet(modernSlider, newValue)
			end
			silent = false
		end
		function handle.GetQuickPath()
			return nil
		end
		return handle
	end

	function adapter:CreateText(spec)
		beforeElement(spec)
		local initialText = tostring(spec.Text or spec.Value or "")
		local handle = { Text = initialText }
		local title = displayName(spec)
		local ok, created = pcall(function()
			return modernSection:AddParagraph({
				Name = title,
				Title = title,
				Content = handle.Text,
				Description = handle.Text,
				Text = handle.Text,
			})
		end)
		local widget = ok and created or nil
		handle.Instance = widget

		function handle.Set(self, text)
			if type(self) == "string" and text == nil then
				text = self
			end
			local newText = tostring(text or "")
			if newText == handle.Text then
				return
			end
			handle.Text = newText
			tryUpdateText(widget, title, handle.Text)
		end
		function handle.Get()
			return handle.Text
		end
		return handle
	end
	adapter.CreateRow = adapter.CreateText

	function adapter:CreateLabel(spec)
		local handle = { Text = tostring(spec.Text or spec.Name or "") }
		local ok, created = pcall(function()
			return modernSection:AddDivider({ Text = handle.Text })
		end)
		if not ok or not created then
			ok, created = pcall(function()
				return modernSection:AddParagraph({
					Name = handle.Text,
					Title = handle.Text,
					Content = "",
					Description = "",
					Text = "",
				})
			end)
		end
		handle.Instance = ok and created or nil
		function handle.Set(self, text)
			if type(self) == "string" and text == nil then
				text = self
			end
			handle.Text = tostring(text or "")
		end
		function handle.Get()
			return handle.Text
		end
		return handle
	end

	function adapter:CreateButton(spec)
		beforeElement(spec)
		local handle = {}
		local ok, created = pcall(function()
			return modernSection:AddButton({
				Name = displayName(spec),
				ToolTip = spec.Note,
				Callback = function()
					if type(spec.Callback) == "function" then
						task.spawn(pcall, spec.Callback)
					end
				end,
			})
		end)
		handle.Instance = ok and created or nil
		function handle.SetActionText() end
		function handle.Click()
			if type(spec.Callback) == "function" then
				task.spawn(pcall, spec.Callback)
			end
		end
		return handle
	end

	function adapter:CreateInput(spec)
		beforeElement(spec)
		local handle = { Value = spec.Default or "" }
		handle.State = {}
		local modernInput
		local ok, created = pcall(function()
			return modernSection:AddTextInput({
				Name = displayName(spec),
				Placeholder = spec.Placeholder or "",
				Default = spec.Default or "",
				Flag = newFlag("I", sectionName .. "/" .. tostring(spec.Name)),
				Callback = function(text)
					handle.Value = text
					if type(spec.Callback) == "function" then
						task.spawn(pcall, spec.Callback, text)
					end
				end,
			})
		end)
		modernInput = ok and created or nil
		handle.Instance = modernInput
		function handle.Get()
			return handle.Value
		end
		function handle.Set(self, text)
			if type(self) ~= "table" or self ~= handle then
				text = self
			end
			handle.Value = text
			if modernInput then
				trySet(modernInput, text)
			end
		end
		return handle
	end

	function adapter:CreateCanvas(config)
		beforeElement(config)
		config = type(config) == "table" and config or {}

		local RunService = game:GetService("RunService")

		local style = {
			TextScale = 1,
			TitleScale = 1,
			Font = "Gotham",
			LineHeight = 1.16,
			Padding = 1,
			Alignment = "Left",
			BackgroundColor = Color3.fromRGB(18, 20, 26),
			BackgroundTransparency = 0.35,
			StrokeColor = Color3.fromRGB(45, 48, 58),
			StrokeTransparency = 0.5,
			StrokeScale = 0.05,
			CornerScale = 0.35,
			ScrollBarColor = Color3.fromRGB(170, 174, 184),
			ScrollBarTransparency = 0,
			TextColor = Color3.fromRGB(235, 235, 235),
			TextStrokeTransparency = 0.7,
			MinLines = 4,
			MaxLines = 0,
			AutoHeight = true,
			ClipContent = true,
		}
		if type(config.Style) == "table" then
			for k, v in pairs(config.Style) do
				style[k] = v
			end
		end

		local titleText = config.Title ~= nil and tostring(config.Title) or tostring(config.Name or "")
		local searchEnabled = config.Search == true
		local searchPlaceholder = tostring(config.SearchPlaceholder or "Search...")

		local host = nil
		if typeof(modernSection) == "table" then
			if typeof(modernSection.Container) == "Instance" then
				host = modernSection.Container
			elseif typeof(modernSection.Root) == "Instance" and modernSection.Root:IsA("GuiObject") then
				host = modernSection.Root
			elseif typeof(modernSection.Frame) == "Instance" and modernSection.Frame:IsA("GuiObject") then
				host = modernSection.Frame
			end
		end
		if not host and typeof(modernSection) == "table" and type(modernSection.AddLabel) == "function" then
			local ok, probe = pcall(function()
				return modernSection:AddLabel({ Text = "" })
			end)
			if ok and probe and probe.Root and probe.Root.Parent then
				host = probe.Root.Parent
				pcall(function() probe.Root:Destroy() end)
			end
		end

		local cardRow = Instance.new("Frame")
		cardRow.Name = tostring(config.Name or "CanvasRow")
		cardRow.BackgroundTransparency = 1
		cardRow.BorderSizePixel = 0
		cardRow.ClipsDescendants = false
		cardRow.Size = UDim2.new(1, -10, 0, 120)
		cardRow.ZIndex = 8
		if host then
			cardRow.Parent = host
		end

		local plate = Instance.new("Frame")
		plate.Name = "Plate"
		plate.BackgroundColor3 = style.BackgroundColor
		plate.BackgroundTransparency = style.BackgroundTransparency
		plate.BorderSizePixel = 0
		plate.ClipsDescendants = true
		plate.Size = UDim2.new(1, 0, 1, 0)
		plate.ZIndex = 8
		plate.Parent = cardRow

		local plateCorner = Instance.new("UICorner")
		plateCorner.CornerRadius = UDim.new(0, 10)
		plateCorner.Parent = plate

		local plateStroke = Instance.new("UIStroke")
		plateStroke.Color = style.StrokeColor
		plateStroke.Transparency = style.StrokeTransparency
		plateStroke.Thickness = 1
		plateStroke.Parent = plate

		local searchField = nil
		local searchBox = nil
		if searchEnabled then
			searchField = Instance.new("Frame")
			searchField.Name = "SearchField"
			searchField.BackgroundColor3 = Color3.fromRGB(12, 13, 18)
			searchField.BackgroundTransparency = 0.3
			searchField.BorderSizePixel = 0
			searchField.Position = UDim2.new(0, 10, 0, 8)
			searchField.Size = UDim2.new(1, -20, 0, 28)
			searchField.ZIndex = 9
			searchField.Parent = plate

			local sfCorner = Instance.new("UICorner")
			sfCorner.CornerRadius = UDim.new(0, 6)
			sfCorner.Parent = searchField

			local sfStroke = Instance.new("UIStroke")
			sfStroke.Color = Color3.fromRGB(50, 53, 65)
			sfStroke.Transparency = 0.6
			sfStroke.Thickness = 1
			sfStroke.Parent = searchField

			searchBox = Instance.new("TextBox")
			searchBox.Name = "SearchInput"
			searchBox.BackgroundTransparency = 1
			searchBox.BorderSizePixel = 0
			searchBox.ClearTextOnFocus = false
			searchBox.MultiLine = false
			searchBox.Position = UDim2.new(0, 10, 0, 0)
			searchBox.Size = UDim2.new(1, -20, 1, 0)
			searchBox.Text = ""
			searchBox.PlaceholderText = searchPlaceholder
			searchBox.PlaceholderColor3 = Color3.fromRGB(150, 155, 170)
			searchBox.TextColor3 = Color3.fromRGB(240, 240, 245)
			searchBox.TextSize = 13
			searchBox.Font = Enum.Font.GothamMedium
			searchBox.TextXAlignment = Enum.TextXAlignment.Left
			searchBox.ZIndex = 10
			searchBox.Parent = searchField
		end

		local dockFrame = Instance.new("Frame")
		dockFrame.Name = "CanvasDock"
		dockFrame.BackgroundTransparency = 1
		dockFrame.BorderSizePixel = 0
		dockFrame.ClipsDescendants = false
		dockFrame.Visible = false
		dockFrame.ZIndex = 9
		dockFrame.Parent = plate

		local dockRule = Instance.new("Frame")
		dockRule.Name = "CanvasDockRule"
		dockRule.BackgroundColor3 = Color3.fromRGB(60, 64, 78)
		dockRule.BorderSizePixel = 0
		dockRule.Visible = false
		dockRule.ZIndex = 9
		dockRule.Parent = plate

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "CanvasScroll"
		scroll.Active = true
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.ElasticBehavior = Enum.ElasticBehavior.Never
		scroll.ScrollBarImageColor3 = style.ScrollBarColor
		scroll.ScrollBarImageTransparency = style.ScrollBarTransparency
		scroll.ScrollBarThickness = 4
		scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		scroll.ZIndex = 9
		scroll.Parent = plate

		local root = Instance.new("Frame")
		root.Name = "CanvasRoot"
		root.BackgroundTransparency = 1
		root.BorderSizePixel = 0
		root.Position = UDim2.fromScale(0, 0)
		root.Size = UDim2.new(1, 0, 0, 0)
		root.ZIndex = 9
		root.Parent = scroll

		local surface = {
			_metrics = {
				Unit = 16,
				TextSize = 13,
				LineHeight = 1.1,
				Width = 400,
			},
			_query = "",
			_dockUnits = 0,
			_dockGap = 0.22,
			_contentHeight = nil,
			_elements = {},
			_resizeHandlers = {},
			_dirty = true,
			_alive = true,
		}

		local function canvasFont(value)
			if typeof(value) == "Font" then
				return value
			end
			if typeof(value) == "EnumItem" then
				local ok, font = pcall(Font.fromEnum, value)
				if ok then return font end
			end
			if type(value) == "string" then
				local lower = string.lower(value)
				if lower == "gotham" or lower == "gothambold" or lower == "gotham-bold" then
					return Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
				elseif lower == "gothammedium" or lower == "gotham-medium" then
					return Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
				elseif lower == "fredoka" or lower == "fredokaone" then
					return Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
				end
			end
			return Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
		end

		local function canvasColor(value, fallback)
			if typeof(value) == "Color3" then
				return value
			end
			if type(value) == "string" then
				local ok, color = pcall(Color3.fromHex, value)
				if ok then return color end
			end
			return fallback
		end

		local function canvasGradient(target, source, rotation)
			local existing = target:FindFirstChild("CanvasGradient")
			if source == nil then
				if existing then existing:Destroy() end
				return
			end
			if typeof(source) == "Instance" and source:IsA("UIGradient") then
				if existing then existing:Destroy() end
				local copy = source:Clone()
				copy.Name = "CanvasGradient"
				if rotation ~= nil then copy.Rotation = rotation end
				copy.Parent = target
				return
			end
			if typeof(source) == "ColorSequence" then
				local grad = existing or Instance.new("UIGradient")
				grad.Name = "CanvasGradient"
				grad.Color = source
				if rotation ~= nil then grad.Rotation = rotation end
				grad.Parent = target
			end
		end

		local function canvasCorner(target, radius)
			local corner = target:FindFirstChildOfClass("UICorner")
			if radius == nil or radius <= 0 then
				if corner then corner:Destroy() end
				return nil
			end
			if not corner then
				corner = Instance.new("UICorner")
				corner.Parent = target
			end
			corner.CornerRadius = UDim.new(0, math.floor(radius + 0.5))
			return corner
		end

		local function canvasStroke(target, color, thickness, transparency, mode)
			local stroke = target:FindFirstChildOfClass("UIStroke")
			if thickness == nil or thickness <= 0 then
				if stroke then stroke:Destroy() end
				return nil
			end
			if not stroke then
				stroke = Instance.new("UIStroke")
				stroke.LineJoinMode = Enum.LineJoinMode.Round
				stroke.Parent = target
			end
			stroke.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Contextual
			stroke.Color = color or Color3.fromRGB(0, 0, 0)
			stroke.Thickness = math.max(0.5, thickness)
			stroke.Transparency = math.clamp(tonumber(transparency) or 0, 0, 1)
			return stroke
		end

		local function canvasSizeOf(elemSpec, metrics)
			if typeof(elemSpec.Size) == "UDim2" then
				return elemSpec.Size
			end
			local widthScale = tonumber(elemSpec.WidthScale)
			local width = tonumber(elemSpec.Width)
			local heightScale = tonumber(elemSpec.HeightScale)
			local height = tonumber(elemSpec.Height)
			local x
			if widthScale then
				x = UDim.new(widthScale, 0)
			elseif width then
				x = UDim.new(0, math.floor(width * metrics.Unit + 0.5))
			else
				x = UDim.new(1, 0)
			end
			local y
			if heightScale then
				y = UDim.new(heightScale, 0)
			else
				y = UDim.new(0, math.floor((height or 1) * metrics.Unit + 0.5))
			end
			return UDim2.new(x.Scale, x.Offset, y.Scale, y.Offset)
		end

		local function canvasPositionOf(elemSpec, metrics)
			if typeof(elemSpec.Position) == "UDim2" then
				return elemSpec.Position
			end
			return UDim2.fromOffset(
				math.floor((tonumber(elemSpec.X) or 0) * metrics.Unit + 0.5),
				math.floor((tonumber(elemSpec.Y) or 0) * metrics.Unit + 0.5)
			)
		end

		local function canvasParentOf(val)
			if type(val) == "table" and type(val.Get) == "function" then
				val = val.Get()
			end
			if typeof(val) == "Instance" then
				return val
			end
			return root
		end

		local function canvasCreateFrame(elemSpec)
			elemSpec = type(elemSpec) == "table" and elemSpec or {}
			local frame = Instance.new(elemSpec.Scrolling == true and "ScrollingFrame" or "Frame")
			frame.Name = tostring(elemSpec.Name or "Panel")
			frame.BackgroundColor3 = canvasColor(elemSpec.Background, Color3.fromRGB(0, 0, 0))
			frame.BackgroundTransparency = math.clamp(tonumber(elemSpec.BackgroundTransparency) or 1, 0, 1)
			frame.BorderSizePixel = 0
			frame.ZIndex = tonumber(elemSpec.ZIndex) or 9

			local handle = { Kind = "Frame", Spec = elemSpec }
			function handle.Get() return frame end
			function handle.Set(patch)
				if type(patch) == "table" then
					for k, v in pairs(patch) do elemSpec[k] = v end
				end
				handle.Apply()
				return handle
			end
			function handle.SetVisible(vis)
				elemSpec.Visible = vis ~= false
				frame.Visible = elemSpec.Visible
				return handle
			end
			function handle.Apply()
				local metrics = surface._metrics
				frame.Size = canvasSizeOf(elemSpec, metrics)
				frame.Position = canvasPositionOf(elemSpec, metrics)
				if elemSpec.Visible ~= nil then frame.Visible = elemSpec.Visible ~= false end
				if elemSpec.ZIndex ~= nil then frame.ZIndex = tonumber(elemSpec.ZIndex) or frame.ZIndex end
				local bg = canvasColor(elemSpec.Background, nil)
				if bg then
					frame.BackgroundColor3 = bg
					frame.BackgroundTransparency = math.clamp(tonumber(elemSpec.BackgroundTransparency) or 0, 0, 1)
				elseif elemSpec.BackgroundTransparency ~= nil then
					frame.BackgroundTransparency = math.clamp(tonumber(elemSpec.BackgroundTransparency) or 1, 0, 1)
				end
				if elemSpec.Corner ~= nil then
					canvasCorner(frame, (tonumber(elemSpec.Corner) or 0) * metrics.Unit)
				end
				if elemSpec.StrokeColor ~= nil or elemSpec.StrokeThickness ~= nil then
					canvasStroke(frame, canvasColor(elemSpec.StrokeColor, Color3.fromRGB(0, 0, 0)), (tonumber(elemSpec.StrokeThickness) or 0.06) * metrics.Unit, elemSpec.StrokeTransparency, Enum.ApplyStrokeMode.Border)
				end
				if elemSpec.Gradient ~= nil then
					canvasGradient(frame, elemSpec.Gradient, elemSpec.GradientRotation)
				end
			end
			table.insert(surface._elements, handle)
			frame.Parent = canvasParentOf(elemSpec.Parent)
			handle.Apply()
			return handle
		end

		local function canvasCreateText(elemSpec)
			elemSpec = type(elemSpec) == "table" and elemSpec or {}
			local label = Instance.new("TextLabel")
			label.Name = tostring(elemSpec.Name or "Text")
			label.Active = false
			label.BackgroundTransparency = 1
			label.BorderSizePixel = 0
			label.RichText = elemSpec.Rich ~= false
			label.Text = tostring(elemSpec.Text or "")
			label.TextScaled = false
			label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			label.TextStrokeTransparency = 1
			label.TextWrapped = elemSpec.Wrap ~= false
			label.TextYAlignment = Enum.TextYAlignment.Top
			label.ZIndex = tonumber(elemSpec.ZIndex) or 9

			local handle = { Kind = "Text", Spec = elemSpec }
			function handle.Get() return label end
			function handle.Set(patch)
				if type(patch) == "table" then
					for k, v in pairs(patch) do elemSpec[k] = v end
				end
				handle.Apply()
				return handle
			end
			function handle.SetVisible(vis)
				elemSpec.Visible = vis ~= false
				label.Visible = elemSpec.Visible
				return handle
			end
			function handle.Apply()
				local metrics = surface._metrics
				label.Text = tostring(elemSpec.Text or "")
				label.RichText = elemSpec.Rich ~= false
				label.TextWrapped = elemSpec.Wrap ~= false
				label.FontFace = canvasFont(elemSpec.Font)
				label.TextSize = math.max(6, math.floor(metrics.TextSize * (tonumber(elemSpec.Scale) or 1) + 0.5))
				label.LineHeight = tonumber(elemSpec.LineHeight) or metrics.LineHeight
				label.TextColor3 = canvasColor(elemSpec.Color, style.TextColor)
				label.TextTransparency = math.clamp(tonumber(elemSpec.Transparency) or 0, 0, 1)
				label.TextStrokeColor3 = canvasColor(elemSpec.TextStrokeColor, Color3.fromRGB(0, 0, 0))
				label.TextStrokeTransparency = math.clamp(tonumber(elemSpec.TextStrokeTransparency) or style.TextStrokeTransparency, 0, 1)
				local alignStr = string.lower(tostring(elemSpec.Align or "left"))
				label.TextXAlignment = alignStr == "center" and Enum.TextXAlignment.Center or (alignStr == "right" and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left)
				if elemSpec.Visible ~= nil then label.Visible = elemSpec.Visible ~= false end
				if elemSpec.ZIndex ~= nil then label.ZIndex = tonumber(elemSpec.ZIndex) or label.ZIndex end
				canvasGradient(label, elemSpec.Gradient, elemSpec.GradientRotation)
				if elemSpec.StrokeThickness ~= nil or elemSpec.StrokeColor ~= nil then
					canvasStroke(label, canvasColor(elemSpec.StrokeColor, Color3.fromRGB(0, 0, 0)), (tonumber(elemSpec.StrokeThickness) or 0.1) * label.TextSize, elemSpec.StrokeTransparency, Enum.ApplyStrokeMode.Contextual)
				end
				label.Size = canvasSizeOf(elemSpec, metrics)
				label.Position = canvasPositionOf(elemSpec, metrics)
			end
			table.insert(surface._elements, handle)
			label.Parent = canvasParentOf(elemSpec.Parent)
			handle.Apply()
			return handle
		end

		local function canvasCreateButton(elemSpec)
			elemSpec = type(elemSpec) == "table" and elemSpec or {}
			local button = Instance.new("TextButton")
			button.Name = tostring(elemSpec.Name or "Button")
			button.AutoButtonColor = false
			button.BackgroundColor3 = canvasColor(elemSpec.Background, Color3.fromRGB(0, 0, 0))
			button.BackgroundTransparency = math.clamp(tonumber(elemSpec.BackgroundTransparency) or 0.35, 0, 1)
			button.BorderSizePixel = 0
			button.RichText = elemSpec.Rich ~= false
			button.Text = tostring(elemSpec.Text or "")
			button.TextScaled = false
			button.TextStrokeTransparency = 1
			button.ZIndex = tonumber(elemSpec.ZIndex) or 9

			local handle = { Kind = "Button", Spec = elemSpec }
			function handle.Get() return button end
			function handle.Set(patch)
				if type(patch) == "table" then
					for k, v in pairs(patch) do elemSpec[k] = v end
				end
				handle.Apply()
				return handle
			end
			function handle.SetVisible(vis)
				elemSpec.Visible = vis ~= false
				button.Visible = elemSpec.Visible
				return handle
			end
			function handle.Apply()
				local metrics = surface._metrics
				button.Text = tostring(elemSpec.Text or "")
				button.RichText = elemSpec.Rich ~= false
				button.FontFace = canvasFont(elemSpec.Font)
				button.TextSize = math.max(6, math.floor(metrics.TextSize * (tonumber(elemSpec.Scale) or 1) + 0.5))
				button.TextColor3 = canvasColor(elemSpec.Color, Color3.fromRGB(255, 255, 255))
				button.BackgroundColor3 = canvasColor(elemSpec.Background, Color3.fromRGB(0, 0, 0))
				button.BackgroundTransparency = math.clamp(tonumber(elemSpec.BackgroundTransparency) or 0.35, 0, 1)
				if elemSpec.Visible ~= nil then button.Visible = elemSpec.Visible ~= false end
				if elemSpec.ZIndex ~= nil then button.ZIndex = tonumber(elemSpec.ZIndex) or button.ZIndex end
				canvasGradient(button, elemSpec.Gradient, elemSpec.GradientRotation)
				if elemSpec.StrokeColor ~= nil or elemSpec.StrokeThickness ~= nil then
					canvasStroke(button, canvasColor(elemSpec.StrokeColor, Color3.fromRGB(0, 0, 0)), (tonumber(elemSpec.StrokeThickness) or 0.05) * metrics.Unit, elemSpec.StrokeTransparency, Enum.ApplyStrokeMode.Border)
				end
				if elemSpec.Corner ~= nil then
					canvasCorner(button, (tonumber(elemSpec.Corner) or 0.3) * metrics.Unit)
				end
				button.Size = canvasSizeOf(elemSpec, metrics)
				button.Position = canvasPositionOf(elemSpec, metrics)
			end

			button.MouseEnter:Connect(function()
				local base = math.clamp(tonumber(elemSpec.BackgroundTransparency) or 0.35, 0, 1)
				button.BackgroundTransparency = math.clamp(tonumber(elemSpec.HoverTransparency) or (base - 0.15), 0, 1)
			end)
			button.MouseLeave:Connect(function()
				button.BackgroundTransparency = math.clamp(tonumber(elemSpec.BackgroundTransparency) or 0.35, 0, 1)
			end)
			button.MouseButton1Down:Connect(function()
				local base = math.clamp(tonumber(elemSpec.BackgroundTransparency) or 0.35, 0, 1)
				button.BackgroundTransparency = math.clamp(tonumber(elemSpec.PressTransparency) or (base - 0.2), 0, 1)
			end)
			button.MouseButton1Up:Connect(function()
				local base = math.clamp(tonumber(elemSpec.BackgroundTransparency) or 0.35, 0, 1)
				button.BackgroundTransparency = math.clamp(tonumber(elemSpec.HoverTransparency) or (base - 0.15), 0, 1)
			end)
			button.Activated:Connect(function()
				if type(elemSpec.Callback) == "function" then
					pcall(elemSpec.Callback, handle)
				end
			end)

			table.insert(surface._elements, handle)
			button.Parent = canvasParentOf(elemSpec.Parent)
			handle.Apply()
			return handle
		end

		local function canvasCreateImage(elemSpec)
			elemSpec = type(elemSpec) == "table" and elemSpec or {}
			local image = Instance.new("ImageLabel")
			image.Name = tostring(elemSpec.Name or "Image")
			image.Active = false
			image.BackgroundColor3 = canvasColor(elemSpec.Background, Color3.fromRGB(0, 0, 0))
			image.BackgroundTransparency = math.clamp(tonumber(elemSpec.BackgroundTransparency) or 1, 0, 1)
			image.BorderSizePixel = 0
			image.ScaleType = Enum.ScaleType.Fit
			image.ZIndex = tonumber(elemSpec.ZIndex) or 9

			local handle = { Kind = "Image", Spec = elemSpec }
			function handle.Get() return image end
			function handle.Set(patch)
				if type(patch) == "table" then
					for k, v in pairs(patch) do elemSpec[k] = v end
				end
				handle.Apply()
				return handle
			end
			function handle.SetVisible(vis)
				elemSpec.Visible = vis ~= false
				image.Visible = elemSpec.Visible
				return handle
			end
			function handle.Apply()
				local metrics = surface._metrics
				image.Image = tostring(elemSpec.Image or "")
				image.ImageColor3 = canvasColor(elemSpec.ImageColor, Color3.fromRGB(255, 255, 255))
				image.ImageTransparency = math.clamp(tonumber(elemSpec.Transparency) or 0, 0, 1)
				image.BackgroundColor3 = canvasColor(elemSpec.Background, Color3.fromRGB(0, 0, 0))
				image.BackgroundTransparency = math.clamp(tonumber(elemSpec.BackgroundTransparency) or 1, 0, 1)
				if elemSpec.Visible ~= nil then image.Visible = elemSpec.Visible ~= false end
				if elemSpec.ZIndex ~= nil then image.ZIndex = tonumber(elemSpec.ZIndex) or image.ZIndex end
				if elemSpec.Corner ~= nil then
					canvasCorner(image, (tonumber(elemSpec.Corner) or 0.3) * metrics.Unit)
				end
				if elemSpec.StrokeColor ~= nil or elemSpec.StrokeThickness ~= nil then
					canvasStroke(image, canvasColor(elemSpec.StrokeColor, Color3.fromRGB(255, 255, 255)), (tonumber(elemSpec.StrokeThickness) or 0.08) * metrics.Unit, elemSpec.StrokeTransparency, Enum.ApplyStrokeMode.Border)
				end
				image.Size = canvasSizeOf(elemSpec, metrics)
				image.Position = canvasPositionOf(elemSpec, metrics)
			end
			table.insert(surface._elements, handle)
			image.Parent = canvasParentOf(elemSpec.Parent)
			handle.Apply()
			return handle
		end

		local canvasApi = {}

		local function layout()
			local cardWidth = cardRow.AbsoluteSize.X
			if cardWidth <= 0 then
				cardWidth = (host and host.AbsoluteSize.X > 0) and host.AbsoluteSize.X or 440
			end
			local sideInset = 10
			local contentWidth = math.max(1, cardWidth - sideInset * 2)
			local textSize = math.max(9, math.floor(cardWidth * 0.026 * (tonumber(style.TextScale) or 1) + 0.5))
			local lineHeight = math.max(0.8, tonumber(style.LineHeight) or 1.1)
			local unit = textSize * lineHeight

			surface._metrics.TextSize = textSize
			surface._metrics.LineHeight = lineHeight
			surface._metrics.Unit = unit
			surface._metrics.Width = contentWidth

			local top = 10
			if searchEnabled and searchField then
				searchField.Position = UDim2.fromOffset(sideInset, top)
				searchField.Size = UDim2.fromOffset(contentWidth, 28)
				top = top + 34
			end

			if surface._dockUnits > 0 then
				local dockHeight = math.floor(surface._dockUnits * unit + 0.5)
				local dockGap = math.floor((tonumber(surface._dockGap) or 0.22) * unit + 0.5)
				dockFrame.Visible = true
				dockFrame.Position = UDim2.fromOffset(sideInset, top)
				dockFrame.Size = UDim2.fromOffset(contentWidth, dockHeight)

				dockRule.Visible = true
				dockRule.Position = UDim2.fromOffset(sideInset, top + dockHeight + dockGap)
				dockRule.Size = UDim2.fromOffset(contentWidth, 1)

				top = top + dockHeight + dockGap * 2 + 1
			else
				dockFrame.Visible = false
				dockRule.Visible = false
			end

			for _, handler in ipairs(surface._resizeHandlers) do
				pcall(handler, canvasApi, contentWidth, unit)
			end

			for _, elem in ipairs(surface._elements) do
				pcall(elem.Apply)
			end

			local contentHeight = surface._contentHeight or 0
			local minLines = math.max(4, tonumber(style.MinLines) or 16)
			local minHeight = math.ceil(unit * minLines)
			local maxLines = tonumber(style.MaxLines) or 32
			local maxHeight = maxLines > 0 and math.ceil(unit * maxLines) or 500
			local viewHeight = math.clamp(math.max(contentHeight, minHeight), minHeight, maxHeight)

			scroll.Position = UDim2.fromOffset(sideInset, top)
			scroll.Size = UDim2.fromOffset(contentWidth, viewHeight)
			scroll.CanvasSize = UDim2.fromOffset(0, contentHeight)

			local totalPlateHeight = top + viewHeight + 10
			plate.Size = UDim2.new(1, 0, 0, totalPlateHeight)
			cardRow.Size = UDim2.new(1, -10, 0, totalPlateHeight + 6)
		end

		function canvasApi:Root() return root end
		function canvasApi:Dock() return dockFrame end
		function canvasApi:Scroll() return scroll end
		function canvasApi:Plate() return plate end
		function canvasApi:Unit() return surface._metrics.Unit end
		function canvasApi:Width() return surface._metrics.Width end
		function canvasApi:TextSize() return surface._metrics.TextSize end
		function canvasApi:LineHeight() return surface._metrics.LineHeight end
		function canvasApi:Query() return surface._query end

		function canvasApi:SetDock(units, options)
			if type(self) == "number" and options == nil and type(units) == "table" then
				options = units
				units = self
			end
			surface._dockUnits = math.max(0, tonumber(units) or 0)
			if type(options) == "table" and options.Gap ~= nil then
				surface._dockGap = tonumber(options.Gap) or 0.22
			end
			surface._dirty = true
		end

		function canvasApi:SetContentLines(lines)
			if type(self) == "number" and lines == nil then lines = self end
			local count = tonumber(lines)
			surface._contentHeight = count and math.ceil(count * surface._metrics.Unit) or nil
			surface._dirty = true
		end

		function canvasApi:SetContentHeight(pixels)
			if type(self) == "number" and pixels == nil then pixels = self end
			surface._contentHeight = tonumber(pixels)
			surface._dirty = true
		end

		function canvasApi:OnResize(handler)
			if type(self) == "function" and handler == nil then handler = self end
			if type(handler) == "function" then
				table.insert(surface._resizeHandlers, handler)
			end
		end

		function canvasApi:Frame(elemSpec)
			if type(self) == "table" and self ~= canvasApi and elemSpec == nil then elemSpec = self end
			return canvasCreateFrame(elemSpec)
		end

		function canvasApi:Text(elemSpec)
			if type(self) == "table" and self ~= canvasApi and elemSpec == nil then elemSpec = self end
			return canvasCreateText(elemSpec)
		end

		function canvasApi:Button(elemSpec)
			if type(self) == "table" and self ~= canvasApi and elemSpec == nil then elemSpec = self end
			return canvasCreateButton(elemSpec)
		end

		function canvasApi:Image(elemSpec)
			if type(self) == "table" and self ~= canvasApi and elemSpec == nil then elemSpec = self end
			return canvasCreateImage(elemSpec)
		end

		function canvasApi:Destroy()
			surface._alive = false
			if surface._heartbeat then
				surface._heartbeat:Disconnect()
				surface._heartbeat = nil
			end
			pcall(function() cardRow:Destroy() end)
		end

		if searchBox then
			searchBox:GetPropertyChangedSignal("Text"):Connect(function()
				surface._query = searchBox.Text
				if type(config.OnSearch) == "function" then
					pcall(config.OnSearch, canvasApi, surface._query)
				end
				surface._dirty = true
			end)
		end

		cardRow:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			surface._dirty = true
		end)

		surface._heartbeat = RunService.Heartbeat:Connect(function()
			if not surface._alive or not cardRow.Parent then return end
			if surface._dirty then
				surface._dirty = false
				pcall(layout)
			end
		end)

		if type(config.Build) == "function" then
			pcall(config.Build, canvasApi)
		end

		surface._dirty = true
		pcall(layout)

		return canvasApi
	end

	return adapter
end

if type(ModernV2.IconAliases) == "table" then
	ModernV2.IconAliases["lucide:home"] = "house"
	ModernV2.IconAliases["home"] = "house"
end

local TAB_ICONS = {
	Farm = "lucide:sprout",
	Event = "lucide:trophy",
	Base = "lucide:house",
	Player = "lucide:user",
	Progress = "lucide:trending-up",
	Server = "lucide:server",
	Predictor = "lucide:activity",
	Misc = "lucide:settings",
}

local function makeTabAdapter(modernWindow, name)
	local okTab, modernTab = pcall(function()
		return modernWindow:AddTab({
			Name = name,
			Icon = TAB_ICONS[name] or "lucide:layers",
			Type = "Single",
		})
	end)
	assert(okTab and modernTab, "Gagal membuat tab: " .. tostring(name))

	local subtabForSection = {}
	do
		for _, groupSpec in ipairs(TAB_LAYOUT[name] or {}) do
			local okBox, tabbox = pcall(function()
				return modernTab:AddCenterTabbox(groupSpec.Group)
			end)
			if okBox and tabbox then
				for _, subSpec in ipairs(groupSpec.Subs) do
					local okSub, subtab = pcall(function()
						return tabbox:AddTab({ Name = subSpec.Name, Icon = subSpec.Icon })
					end)
					if okSub and subtab then
						for _, nexSection in ipairs(subSpec.Sections) do
							subtabForSection[nexSection] = subtab
						end
					else
						warn("[NexHub] Gagal membuat sub-tab " .. subSpec.Name .. ": " .. tostring(subtab))
					end
				end
			else
				warn("[NexHub] Gagal membuat tabbox " .. groupSpec.Group .. ": " .. tostring(tabbox))
			end
		end
	end

	local tab = { _sections = {}, _name = name }
	function tab:CreateSection(spec)
		local sectionName = tostring(spec.Name)
		local icon = SECTION_ICONS[sectionName]
		local subtab = subtabForSection[sectionName]
		local okSection, modernSection

		local isSubtab = false
		if subtab then
			okSection, modernSection = true, subtab
			isSubtab = true
		end

		if not (okSection and modernSection) then
			okSection, modernSection = pcall(function()
				return modernTab:AddSection({
					Position = "Center",
					Name = sectionName,
					Icon = icon,
					Box = true,
					BoxBorder = true,
					Collapsible = true,
					Collapsed = spec.Expanded == false,
					Opened = spec.Expanded ~= false,
				})
			end)
		end
		assert(okSection and modernSection, "Gagal membuat section: " .. sectionName)

		local section = makeSectionAdapter(modernSection, name .. "/" .. sectionName, sectionName, isSubtab)
		self._sections[spec.Name] = section
		return section
	end
	function tab:GetSection(sectionName)
		return self._sections[sectionName]
	end
	return tab
end

function nexLibrary:CreateWindow(config)
	local UserInputService = game:GetService("UserInputService")
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local menuIcon
	if type(ModernV2.CreateMenuIcon) == "function" then
		local okIcon, iconResult = pcall(function()
			return ModernV2:CreateMenuIcon({
				Image = HUB_LOGO,
				Size = 48,
				IconColor = Color3.fromRGB(255, 255, 255),
				BGColor = Color3.fromRGB(20, 22, 27),
				StrokeColor = ACCENT_COLOR,
				StrokeThick = 1.5,
				Draggable = true,
			})
		end)
		if okIcon then
			menuIcon = iconResult
		else
			warn("[NexHub] Gagal membuat menu icon: " .. tostring(iconResult))
		end
	end

	local creator = ModernV2.Window or ModernV2.CreateWindow
	assert(type(creator) == "function", "ModernV2 tidak punya Window/CreateWindow.")

	local modernWindow = creator(ModernV2, {
		Title = HUB_TITLE,
		Content = HUB_SUBTITLE,
		Logo = HUB_LOGO,
		Image = HUB_LOGO,
		Uitransparent = 0.15,
		Size = UDim2.fromOffset(500, 320),
		Color = ACCENT_COLOR,
		ShowUser = true,
		Search = true,
		ConfigEnabled = true,
		NotifyOnCallbackError = false,
		Loadingscreen = false,
		Enable3DRenderer = false,
		Keybind = "RightControl",
		Config = {
			ConfigFolder = "NexHubSAE",
			AutoSaveFile = "NexHub_SAE",
			AutoSave = false,
			AutoLoad = false,
			Overwrite = true,
			Format = "JSON",
			ShowAutoSaveToggle = true,
			TextGradient = true,
		},
	})
	assert(modernWindow, "ModernV2 gagal membuat window.")

	pcall(function()
		if modernWindow.Root then
			for _, desc in ipairs(modernWindow.Root:GetDescendants()) do
				if desc:IsA("ImageLabel") and (string.find(tostring(desc.Image), "logo.png") or string.find(tostring(desc.Image), "120358385035996") or string.find(tostring(desc.Image), "128961717706452")) then
					desc.Image = HUB_LOGO
				end
			end
		end
	end)

	if menuIcon and type(modernWindow.AttachMenuIcon) == "function" then
		pcall(modernWindow.AttachMenuIcon, modernWindow, menuIcon)
	end

	if type(modernWindow.CreateHomeTab) == "function" then
		local okHome, homeError = pcall(function()
			modernWindow:CreateHomeTab({
				Name = "Dashboard",
				Icon = "lucide:layout-dashboard",
				Content = "NexHub - Steal An Egg",
				DiscordInvite = "https://discord.gg/CJSb25kaCp",
				SupportedExecutors = { "Delta", "Synapse X", "Krnl", "Codex", "Arceus X" },
				UnsupportedExecutors = { "Roblox Studio" },
				Segments = {
					Details = { Text = "Details", Icon = "lucide:grid-2x2" },
					Script = { Text = "Script Logs", Icon = "lucide:code" },
					UI = { Text = "UI Logs", Icon = "lucide:file-text", Show = true },
				},
				Changelog = {
					{
						Title = "NexHub SAE v1.6",
						Description = "Optimized Race Rally Auto Complete Race with server-validated racing lines, zero corner handbrake speed bleed, and exact server-synced BoostPad hitbox detection for faster lap times and guaranteed 1st-place rewards. Updated default Race Rally settings: Auto Complete Race and Auto Leave After Race are now enabled (ON) by default, while Auto Detect BoostPad is disabled (OFF) by default.",
					},
					{
						Title = "NexHub SAE v1.5",
						Description = "Full Update 8 Event integration: Race Rally (Auto Join Race, Auto Complete Race with native MountController steering for guaranteed 1st-place rewards, toggleable Auto Detect BoostPad with wall-safe S-Curve steering, 3D corner Trap detection & avoidance, Auto Collect Power-Ups, Auto Claim Milestones, and Auto Buy Shop) and Shooting Star & Mounts (Auto Catch & Auto Feed Star). Fixed Auto Steal, Instant Steal, and Beat Guard compatibility while waiting for race schedules in the main world.",
					},
					{
						Title = "NexHub SAE v1.4",
						Description = "Cleaned up expired Dr Scramble & Mech Boss event features (removed Lab & Mech subtab, Auto Mech Boss, Lab Trade-In, and Scrambled Mutation) and prepared Update 8 event integration.",
					},
					{
						Title = "NexHub SAE v1.3",
						Description = "Added Premium protection for Instant Steal and Auto Mech Boss (with Locked UI & backend guard), replaced legacy Optimizer with lightweight zero-CPU-lag FPS Boost v1.1, added Hide Game Debug to suppress console spam, and fixed FPS & Ping HUD auto-mounting on startup.",
					},
					{
						Title = "NexHub SAE v1.2",
						Description = "Full migration to the ModernV2 Framework (tabbox layout, sub-tabs, dividers, and Dashboard), improved safe zone delivery line drop, and enhanced Auto Steal performance.",
					},
					{
						Title = "NexHub - Steal An Egg",
						Description = "Auto Steal, Auto Place Egg, Auto Hatch, Auto Sell, Auto Fuse, Auto Favorite, ESP, Predictor, and more.",
					},
				},
				UIChangelog = {
					{
						Title = "ModernV2 Framework",
						Date = "Latest",
						Description = "Migrated UI to ModernV2 (NexHub-style tabboxes, dividers, and Dashboard).",
					},
				},
			})
		end)
		if not okHome then
			warn("[NexHub] Gagal membuat Dashboard: " .. tostring(homeError))
		end
	end

	if type(modernWindow.ToggleInterface) == "function" then
		local originalToggle = modernWindow.ToggleInterface
		modernWindow.ToggleInterface = function(self, ...)
			if modernWindow.Destroyed then
				return
			end
			local isVisible = modernWindow.Signal and modernWindow.Signal:GetValue()
			if not isVisible then
				pcall(function()
					if modernWindow.Root and ModernV2.ScreenGui then
						modernWindow.Root.Parent = ModernV2.ScreenGui
						modernWindow.Root.Visible = true
					end
				end)
			end
			return originalToggle(self, ...)
		end
	end

	local window = { _tabs = {}, _states = {}, Modern = modernWindow }
	local defaultTabName = (config and config.DefaultTab) or "Farm"

	function window:GetDefaultTab()
		return self:GetTab(defaultTabName) or self:CreateTab({ Name = defaultTabName })
	end
	function window:CreateTab(spec)
		local tab = makeTabAdapter(modernWindow, spec.Name)
		self._tabs[spec.Name] = tab
		return tab
	end
	function window:GetTab(tabName)
		return self._tabs[tabName]
	end

	function window:CreateState(spec)
		local state = makeState(spec.Default)
		self._states[spec.Name] = state
		return state
	end
	function window:GetState(stateName)
		return self._states[stateName]
	end

	function window:CreateExclusiveGroup(spec)
		local group = { _members = {}, _max = tonumber(spec and spec.MaxActive) or 1 }
		function group:_join(handle)
			handle._exclusive = self
			self._members[#self._members + 1] = handle
		end
		function group:_activated(activeHandle)
			local active = { activeHandle }
			for _, member in ipairs(self._members) do
				if member ~= activeHandle and member.Value == true then
					active[#active + 1] = member
				end
			end

			local overflow = #active - self._max
			for _, member in ipairs(active) do
				if overflow <= 0 then
					break
				end
				if member ~= activeHandle then
					pcall(member.Set, member, false, true)
					overflow = overflow - 1
				end
			end
		end
		return group
	end

	function window:Toggle()
		if type(modernWindow.ToggleInterface) == "function" then
			pcall(modernWindow.ToggleInterface, modernWindow)
		end
	end
	window.Open = window.Toggle

	function window:Destroy()
		pcall(function()
			modernWindow:Destroy()
		end)
	end

	pcall(function()
		if type(modernWindow.SetAccount) == "function" then
			local Players = game:GetService("Players")
			modernWindow:SetAccount({
				Username = Players.LocalPlayer.DisplayName,
				Profile = ModernV2.UserProfile,
				Expires = HUB_TITLE,
			})
		end
	end)

	window._modernNotify = function(title, message, duration, icon)
		pcall(function()
			modernWindow:Notify({
				Title = tostring(title),
				Content = tostring(message),
				Icon = icon or "lucide:bell",
				Duration = tonumber(duration) or 5,
			})
		end)
	end

	nexLibrary._window = window
	return window
end

function nexLibrary.Notify(title, message, duration, icon)
	local window = nexLibrary._window
	if window and window._modernNotify then
		window._modernNotify(title, message, duration, icon)
	end
end

function nexLibrary:Finalize()
end

function nexLibrary.Unload()
	pcall(function()
		if nexLibrary._window then
			nexLibrary._window:Destroy()
		end
	end)
	pcall(function()
		if type(ModernV2.Unload) == "function" then
			ModernV2:Unload()
		end
	end)
end

local window = nexLibrary:CreateWindow({ Name = "NexHub - Steal An Egg", DefaultTab = "Farm" })
local defaultTab = window:GetDefaultTab()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local localPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local networking = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")

local function requireModule(getter)
	local ok, result = pcall(function()
		return require(getter())
	end)
	return ok and result or nil
end

local modules = {
	EggState = requireModule(function()
		return ReplicatedStorage.Client.EggState
	end),
	AreaEggs = requireModule(function()
		return ReplicatedStorage.Shared.Types.AreaEggs
	end),
	ToolGameplayGuard = requireModule(function()
		return ReplicatedStorage.Client.ToolGameplayGuard
	end),
	Assets = requireModule(function()
		return ReplicatedStorage.Data.Assets
	end),
	Guards = requireModule(function()
		return ReplicatedStorage.Data.Guards
	end),
	EggRecords = requireModule(function()
		return ReplicatedStorage.Shared.Util.EggRecords
	end),
	Mutations = requireModule(function()
		return ReplicatedStorage.Shared.Modules.Mutations
	end),
	Save = requireModule(function()
		return ReplicatedStorage.Shared.Save
	end),
	FuseKernel = requireModule(function()
		return ReplicatedStorage.Shared.Util.FuseKernel
	end),
	AreaEggCycle = requireModule(function()
		return ReplicatedStorage.Shared.Util.AreaEggCycle
	end),
	AreaEggResetWall = requireModule(function()
		return ReplicatedStorage.Client.AreaEggResetWall
	end),
	AreaEggResetCycle = requireModule(function()
		return ReplicatedStorage.Data.AreaEggResetCycle
	end),
	Gears = requireModule(function()
		return ReplicatedStorage.Data.Gears
	end),
	Areas = requireModule(function()
		return ReplicatedStorage.Data.Areas
	end),
	LimitedEgg = requireModule(function()
		return ReplicatedStorage.Data.LimitedEgg
	end),
	BrainrotEgg = requireModule(function()
		return ReplicatedStorage.Data.BrainrotEgg
	end),
	MonsterEgg = requireModule(function()
		return ReplicatedStorage.Data.MonsterEgg
	end),
}

local saveModule = modules.Save
if type(saveModule) == "table" and (type(saveModule.Get) ~= "function" or type(saveModule.FieldSignal) ~= "function") then
	modules.Save = setmetatable({
		Get = type(saveModule.Get) == "function" and saveModule.Get or saveModule.Peek,
		FieldSignal = type(saveModule.FieldSignal) == "function" and saveModule.FieldSignal or saveModule.Watch,
	}, { __index = saveModule })
end

local function resolveGuiParent()
	if typeof(gethui) == "function" then
		local ok, result = pcall(gethui)
		if ok and typeof(result) == "Instance" then
			return result
		end
	end
	return CoreGui
end

local guiParent = resolveGuiParent()
local randomIdGenerator = Random.new()
local idChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

local function randomId()
	local length = randomIdGenerator:NextInteger(12, 20)
	local chars = table.create(length)
	for i = 1, length do
		local pos = randomIdGenerator:NextInteger(1, #idChars)
		chars[i] = string.sub(idChars, pos, pos)
	end
	return table.concat(chars)
end

local registerCleanup
local registeredSliders
local createValueSlider
local fixDropdownAll

do
	local cleanupCallbacks = {}
	registeredSliders = {}

	registerCleanup = function(callback)
		table.insert(cleanupCallbacks, callback)
	end

	createValueSlider = function(parent, spec)
		local maxSliderValue = 1000
		local minMagnitude = 3
		local maxMagnitude = 12

		local function roundToSignificant(value)
			if value <= 0 then
				return 0
			end
			local scale = 10 ^ (math.floor(math.log10(value)) - 2)
			return math.floor(value / scale + 0.5) * scale
		end

		local function sliderToValue(sliderPos)
			local clamped = math.clamp(tonumber(sliderPos) or 0, 0, 1000)
			if clamped <= 0 then
				return 0
			end
			return roundToSignificant(10 ^ (minMagnitude + (maxMagnitude - minMagnitude) * clamped / maxSliderValue))
		end

		local function valueToSlider(value)
			local numericValue = tonumber(value) or 0
			if numericValue <= 0 then
				return 0
			end
			local span = maxMagnitude - minMagnitude
			return math.clamp(math.floor((math.log10(numericValue) - minMagnitude) / span * maxSliderValue * 100 + 0.5) / 100, 0, 1000)
		end

		local function formatNumber(value)
			local formatted = string.format(value >= 100 and "%.0f" or value >= 10 and "%.1f" or "%.2f", value)
			if string.find(formatted, ".", 1, true) then
				formatted = string.gsub(string.gsub(formatted, "0+$", ""), "%.$", "")
			end
			return formatted
		end

		local function formatSliderLabel(sliderPos)
			local value = sliderToValue(sliderPos)
			if value <= 0 then
				return "Off"
			end
			if value < 1000000 then
				return formatNumber(value / 1000) .. " K/s"
			end
			if value < 1e9 then
				return formatNumber(value / 1000000) .. " M/s"
			end
			return formatNumber(value / 1e9) .. " B/s"
		end

		local function formatSliderCompact(sliderPos)
			local value = sliderToValue(sliderPos)
			if value <= 0 then
				return "0"
			end
			if value < 1000000 then
				return formatNumber(value / 1000) .. "k"
			end
			return string.gsub(string.gsub(string.format("%.3f", value / 1000000), "0+$", ""), "%.$", "")
		end

		local unitMultipliers = { k = 1000, m = 1000000, b = 1e9, t = 1e12 }

		local function parseSliderInput(input)
			local cleaned = string.gsub(string.lower(string.gsub(tostring(input or ""), "[%s,/]", "")), "s$", "")
			if cleaned == "" or cleaned == "off" then
				return 0
			end
			local numericPart, unitPart = string.match(cleaned, "^([%d%.]+)([kmbt]?)$")
			local numeric = tonumber(numericPart)
			if not numeric then
				return nil
			end
			return valueToSlider(numeric * (unitMultipliers[unitPart] or 1000000))
		end

		local handle = parent:CreateSlider({
			Name = spec.Name,
			Note = spec.Note,
			SubOf = spec.SubOf,
			Min = 0,
			Max = maxSliderValue,
			Default = valueToSlider(spec.Default or 0),
			AllowDecimals = true,
			Increment = 0.01,
			ValueFormat = formatSliderLabel,
			ValueParse = parseSliderInput,
			Callback = function(sliderPos)
				if type(spec.OnRaw) == "function" then
					spec.OnRaw(sliderToValue(sliderPos))
				end
			end,
		})

		local instance = type(handle) == "table" and rawget(handle, "Instance") or nil

		if typeof(instance) == "Instance" then
			for _, descendant in ipairs(instance:GetDescendants()) do
				if descendant:IsA("TextBox") then
					local focusConnection = descendant.Focused:Connect(function()
						task.defer(function()
							if descendant:IsFocused() then
								local ok, result = pcall(handle.Get, handle)
								descendant.Text = formatSliderCompact(ok and result or 0)
								descendant.CursorPosition = #descendant.Text + 1
								descendant.SelectionStart = 1
							end
						end)
					end)
					registerCleanup(function()
						pcall(function()
							focusConnection:Disconnect()
						end)
					end)
				end
			end
		end

		if type(spec.Legacy) == "string" and type(spec.SectionName) == "string" then
			table.insert(registeredSliders, {
				Handle = handle,
				Name = spec.Name,
				Legacy = spec.Legacy,
				Section = spec.SectionName,
				StepOf = valueToSlider,
			})
		end

		return handle
	end

	local allLabelText = "All"

	fixDropdownAll = function(handle)
		if type(handle) ~= "table" then
			return handle
		end
		local instance = rawget(handle, "Instance")
		if typeof(instance) ~= "Instance" then
			return handle
		end
		local suppress = false

		local function replaceNoneIfNeeded(label)
			if suppress then
				return
			end
			if label.Text == "None" then
				suppress = true
				label.Text = allLabelText
				suppress = false
			end
		end

		local function watchTextLabel(descendant)
			if not descendant:IsA("TextLabel") or descendant.Name ~= "Value" then
				return
			end
			replaceNoneIfNeeded(descendant)
			local connection = descendant:GetPropertyChangedSignal("Text"):Connect(function()
				replaceNoneIfNeeded(descendant)
			end)
			registerCleanup(function()
				pcall(function()
					connection:Disconnect()
				end)
			end)
		end

		for _, descendant in ipairs(instance:GetDescendants()) do
			watchTextLabel(descendant)
		end

		local addedConnection = instance.DescendantAdded:Connect(watchTextLabel)
		registerCleanup(function()
			pcall(function()
				addedConnection:Disconnect()
			end)
		end)

		return handle
	end

	local genv = typeof(getgenv) == "function" and getgenv() or _G
	local previousCleanup = genv.NexHubSaeCleanup
	if type(previousCleanup) == "function" then
		pcall(previousCleanup)
	end

	genv.NexHubSaeCleanup = function()
		for i = #cleanupCallbacks, 1, -1 do
			pcall(cleanupCallbacks[i])
		end
		table.clear(cleanupCallbacks)
	end
end

do
	local noiseAccumulator = 0
	local walkData

	walkData = function(value, depth)
		local currentDepth = depth or 0

		if type(value) == "table" then
			if currentDepth > 3 then
				return
			end
			local count = 0
			for key, entry in pairs(value) do
				count = count + 1
				if not (count > 20) then
					walkData(key, currentDepth + 1)
					walkData(entry, currentDepth + 1)
					continue
				end
				break
			end
		elseif typeof(value) == "Instance" then
			pcall(value.GetFullName, value)
		else
			noiseAccumulator = noiseAccumulator + #tostring(value)
		end
	end

	local trackedConnections = {}

	local function trackConnection(connection)
		trackedConnections[#trackedConnections + 1] = connection
	end

	local function disconnectAllTracked()
		for _, connection in ipairs(trackedConnections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		table.clear(trackedConnections)
	end

	local function nexToolKeeper()
		disconnectAllTracked()

		for _, remotePath in ipairs({
			"RE/GearSatchel/Lost",
			"RE/GearSatchel/Gained",
			"RE/RigSync/ProbeSatchel",
			"RE/RigSync/SeedSatchel",
			"RE/RigSync/CorrectionBegan",
			"RE/RigSync/Refresh",
			"RE/ToolTrigger/Trigger",
			"RE/BatSwing/Trigger",
		}) do
			local remote = networking:FindFirstChild(remotePath)
			if remote and remote:IsA("RemoteEvent") then
				trackConnection(remote.OnClientEvent:Connect(function(...)
					walkData({ ... })
				end))
			end
		end

		local function watchContainer(container)
			if not container then
				return
			end
			trackConnection(container.ChildRemoved:Connect(function(child)
				if child:IsA("Tool") then
					walkData({ child.Name, child.Parent })
				end
			end))
			trackConnection(container.ChildAdded:Connect(function(child)
				if child:IsA("Tool") then
					walkData({ child.Name })
				end
			end))
		end

		watchContainer(localPlayer:FindFirstChildOfClass("Backpack"))
		trackConnection(localPlayer.ChildAdded:Connect(function(child)
			if child:IsA("Backpack") then
				watchContainer(child)
			end
		end))

		task.spawn(function()
			pcall(function()
				local saved = modules.Save.Get()
				walkData({ saved.GearInventory, saved.Inventory }, 2)
			end)

			if type(getgc) == "function" then
				pcall(function()
					for _, closure in ipairs(getgc(false)) do
						if type(closure) == "function" and islclosure(closure) then
							pcall(debug.info, closure, "n")
						end
					end
				end)
			end
		end)
	end

	;(typeof(getgenv) == "function" and getgenv() or _G).NexToolKeeper = nexToolKeeper
	task.defer(nexToolKeeper)
	registerCleanup(disconnectAllTracked)
end

local taskScheduler
do
	local minGap = 0.35
	local idleRepeatAfter = 5
	local tasks = {}
	local wakeFlag = true

	taskScheduler = {
		Add = function(callback)
			local task = { Run = callback, Gap = minGap, Idle = idleRepeatAfter, Repeat = false, Hold = 0 }
			table.insert(tasks, task)
			return task
		end,
		Wake = function()
			wakeFlag = true
		end,
		Backoff = function(task, duration)
			if task then
				task.Hold = tonumber(duration) or 6
			end
		end,
	}

	local heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		local wasWoken = wakeFlag
		wakeFlag = false

		for _, task in ipairs(tasks) do
			task.Gap = task.Gap + deltaTime
			task.Idle = task.Idle + deltaTime

			if task.Hold > 0 then
				task.Hold = task.Hold - deltaTime
			else
				local shouldRun
				if task.Gap >= minGap then
					shouldRun = wasWoken or task.Repeat or task.Idle >= idleRepeatAfter
				else
					shouldRun = false
				end

				if shouldRun then
					task.Gap = 0
					task.Idle = 0
					local ok, result = pcall(task.Run, task)
					task.Repeat = ok and result == true
				end
			end
		end
	end)

	registerCleanup(function()
		heartbeatConnection:Disconnect()
	end)
end

local eventTab = window:CreateTab({ Name = "Event", SectionsExpanded = true })
local baseTab = window:CreateTab({ Name = "Base", SectionsExpanded = true })

local autoStealSection = defaultTab:CreateSection({ Name = "Auto Steal", Expanded = true })
local raceRallySection = eventTab:CreateSection({ Name = "Race Rally", Expanded = true })
local shootingStarSection = eventTab:CreateSection({ Name = "Shooting Star", Expanded = true })
local autoPlaceEggSection = baseTab:CreateSection({ Name = "Auto Place Egg", Expanded = true })
local autoTreadmillSection = baseTab:CreateSection({ Name = "Auto Treadmill", Expanded = false })
local autoHatchEquipSection = baseTab:CreateSection({ Name = "Auto Hatch & Equip", Expanded = false })
local autoSellSection = baseTab:CreateSection({ Name = "Auto Sell", Expanded = false })
local autoFuseSection = baseTab:CreateSection({ Name = "Auto Fuse Machine", Expanded = false })
local autoFavoriteSection = baseTab:CreateSection({ Name = "Auto Favorite", Expanded = false })

local runtimeState = { Paused = false }

do
	local checkInterval = 0.5
	local trackedHumanoid = nil
	local originalSettings = nil
	local trackedConnections = {}
	local healingInProgress = false
	local lastCheckAt = 0

	local function disconnectTrackedConnections()
		for i = #trackedConnections, 1, -1 do
			local connection = trackedConnections[i]
			if connection and connection.Connected then
				connection:Disconnect()
			end
			trackedConnections[i] = nil
		end
	end

	local function restoreHumanoidSettings()
		disconnectTrackedConnections()
		local humanoid = trackedHumanoid
		local settings = originalSettings
		trackedHumanoid = nil
		originalSettings = nil

		if not humanoid or not humanoid.Parent or not settings then
			return
		end

		pcall(function()
			humanoid.BreakJointsOnDeath = settings.BreakJointsOnDeath
			humanoid.RequiresNeck = settings.RequiresNeck
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, settings.DeadEnabled)
		end)
	end

	local function applyNoDeath(humanoid)
		if not humanoid or not humanoid.Parent then
			return false
		end

		return pcall(function()
			humanoid.BreakJointsOnDeath = false
			humanoid.RequiresNeck = false
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		end)
			and humanoid.BreakJointsOnDeath == false
			and humanoid.RequiresNeck == false
			and humanoid:GetStateEnabled(Enum.HumanoidStateType.Dead) == false
	end

	local function healIfNeeded(humanoid)
		if runtimeState.Paused or humanoid ~= trackedHumanoid or not humanoid or not humanoid.Parent or healingInProgress then
			return false
		end

		local maxHealth = humanoid.MaxHealth
		if maxHealth <= 0 then
			return false
		end

		if maxHealth == math.huge or humanoid.Health >= maxHealth then
			return true
		end

		healingInProgress = true
		local ok = pcall(function()
			humanoid.Health = maxHealth
		end)
		healingInProgress = false

		return ok and humanoid.Health >= maxHealth
	end

	local function trackHumanoid(humanoid)
		if humanoid == trackedHumanoid and humanoid and humanoid.Parent then
			return true
		end

		restoreHumanoidSettings()

		if not humanoid or not humanoid:IsA("Humanoid") or not humanoid.Parent then
			return false
		end

		trackedHumanoid = humanoid
		originalSettings = {
			BreakJointsOnDeath = humanoid.BreakJointsOnDeath,
			RequiresNeck = humanoid.RequiresNeck,
			DeadEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Dead),
		}

		if not applyNoDeath(humanoid) then
			restoreHumanoidSettings()
			return false
		end

		healIfNeeded(humanoid)

		trackedConnections[#trackedConnections + 1] = humanoid.HealthChanged:Connect(function()
			healIfNeeded(humanoid)
		end)

		trackedConnections[#trackedConnections + 1] = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
			healIfNeeded(humanoid)
		end)

		trackedConnections[#trackedConnections + 1] = humanoid.StateChanged:Connect(function(_, newState)
			if newState == Enum.HumanoidStateType.Dead and not runtimeState.Paused then
				applyNoDeath(humanoid)
				healIfNeeded(humanoid)
			end
		end)

		lastCheckAt = os.clock()
		return true
	end

	local function currentHumanoid()
		local character = localPlayer.Character
		return character and character:FindFirstChildOfClass("Humanoid") or nil
	end

	local characterAddedConnection = localPlayer.CharacterAdded:Connect(function()
		task.defer(function()
			trackHumanoid(currentHumanoid())
		end)
	end)

	local heartbeatConnection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if runtimeState.Paused or now - lastCheckAt < checkInterval then
			return
		end
		lastCheckAt = now

		local humanoid = currentHumanoid()
		if humanoid ~= trackedHumanoid then
			trackHumanoid(humanoid)
			return
		end

		if humanoid then
			applyNoDeath(humanoid)
			healIfNeeded(humanoid)
		end
	end)

	task.defer(function()
		trackHumanoid(currentHumanoid())
	end)

	registerCleanup(function()
		if characterAddedConnection then
			characterAddedConnection:Disconnect()
		end
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
		end
		restoreHumanoidSettings()
	end)
end

local batNameKeywords = { "bat", "katana", "axe", "staff", "club", "hammer", "sword", "blade" }

local state
state = {
	Steal = { Active = false, LastFinishedAt = 0, Carrying = false },
	SafeCarry = {
		Enabled = true,
		SkipUnsafe = false,
		WaitGuard = false,
		SameSpeedBigEggs = false,
		Blocked = {},
		StretchSeconds = 6,
		BeatGuard = false,
		SlowUntil = 0,
		SlowFactor = 0.3,
		LineDrop = false,
		LineGap = 12,
		LineWait = 15,
		DirectBudget = 450,
		DirectMargin = 0.3,
		CrossNow = false,
		CrossSpeed = 231,
		PickupSpeed = 154,
		HopRatio = 1.515,
		CrossRatio = 1,
		PickupRatio = 0.667,
		FarFromLine = 150,
		DropDelay = 0.19,
		LineApproach = 0.97,
		ReJump = true,
		ShakeTime = 0,
		SnapPickup = false,
		Hops = true,
		HopStep = 350,
		HopGap = 0.1,
		HopLift = 42,
		HopStop = 48,
		GetUp = true,
		ShakeInside = 1,
		CarryScale = 1,
		EasyRatio = 1.3,
		LastSkip = nil,
		Category = nil,
		PlanOk = true,
		LightMult = 0.96,
		Height = 70,
		ClimbShare = 0.5,
		Approach = "Run",
		RunSpeed = 1,
		RunWait = 0,
		RunAnimate = true,
		RunHeight = 50,
		SnapLimit = 90,
		StraightRun = true,
		RunStyle = "Velocity",
		CarryStyle = "Velocity",
		SpeedJitter = 0.08,
		Wobble = 0,
		LaneOffset = 0,
		JumpsPerMinute = 0,
		PausesPerMinute = 0,
		ReactMin = 0.2,
		ReactMax = 0.6,
		CarryReact = 0,
		SpeedRatio = 1.5,
		ExcessSeconds = 5.5,
		GuardMargin = 4,
		GuardRatio = 1.06,
		MinRatio = 1.1,
		BaseWait = 6.5,
		FreeJump = 1500,
		WaitRate = 0.9,
		RecoverTries = math.huge,
		GuessMult = 0.93,
		CarryRatio = 0.9,
		Mult = 1,
		Seen = {},
		JumpDistance = 0,
		JumpAt = 0,
		LastDelivered = 0,
		LastFailed = 0,
		Handle = nil,
	},
	Movement = {
		Owner = nil,
		PlaceWanted = false,
		StealFirst = false,
		MutationWanted = false,
		FracturedWanted = false,
	},
	AntiGuard = {
		Enabled = false,
		Busy = false,
		BusySince = 0,
		HitArms = 0,
		Handle = nil,
		Render = nil,
	},
	IsBatTool = function(tool)
		if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
			return false
		end

		if tool:GetAttribute("IsBat") == true then
			return true
		end

		local gearName = tool:GetAttribute("GearName")
		if type(gearName) == "string" then
			local gears = modules.Gears
			local directory = type(gears) == "table" and gears.Directory or nil
			local gearEntry = type(directory) == "table" and directory[gearName] or nil
			return type(gearEntry) == "table" and gearEntry.BatControllerData ~= nil
		end

		if tool:GetAttribute("ItemType") ~= nil then
			return false
		end

		local lowerName = string.lower(tool.Name)
		for _, keyword in ipairs(batNameKeywords) do
			if string.find(lowerName, keyword, 1, true) then
				return true
			end
		end

		return false
	end,
	FindBat = function()
		local isBat = state and state.IsBatTool
		local character = localPlayer.Character
		local equipped = character and character:FindFirstChildWhichIsA("Tool")
		if isBat and isBat(equipped) then
			return equipped
		end

		local backpack = localPlayer:FindFirstChildOfClass("Backpack")
		if backpack then
			for _, child in ipairs(backpack:GetChildren()) do
				if isBat and isBat(child) then
					return child
				end
			end
		end

		if character then
			for _, child in ipairs(character:GetChildren()) do
				if isBat and isBat(child) then
					return child
				end
			end
		end

		return nil
	end,
	IsNight = function()
		local areaEggCycle = modules.AreaEggCycle
		if type(areaEggCycle) ~= "table" or type(areaEggCycle.IsNightPhase) ~= "function" then
			return false
		end
		local ok, result = pcall(areaEggCycle.IsNightPhase, workspace:GetServerTimeNow())
		return ok and result == true
	end,
	WallSealed = function()
		local resetWall = modules.AreaEggResetWall
		if type(resetWall) ~= "table" or type(resetWall.IsSealed) ~= "function" then
			return false
		end
		local ok, result = pcall(resetWall.IsSealed)
		return ok and result == true
	end,
	WallOpenDelay = function()
		local resetCycle = modules.AreaEggResetCycle
		if type(resetCycle) ~= "table" then
			return 5
		end
		return (tonumber(resetCycle.WallCountdownDelayAfterDayStartsSeconds) or 2) + (tonumber(resetCycle.WallCountdownSeconds) or 3)
	end,
	ClaimMovement = function(owner)
		local movement = state and state.Movement
		if not movement then
			return false
		end
		if localPlayer:GetAttribute("RaceId") ~= nil and owner ~= "race" then
			return false
		end
		if movement.Owner == nil
			or movement.Owner == owner
			or (movement.Owner == "treadmill" and owner ~= "treadmill")
			or owner == "race"
		then
			movement.Owner = owner
			return true
		end
		return false
	end,
	ReleaseMovement = function(owner)
		if state and state.Movement and state.Movement.Owner == owner then
			state.Movement.Owner = nil
		end
	end,
}

do
	local shieldMethods = { "Humanoid Swap", "Disable Monitor" }
	state.ShieldMethods = shieldMethods

	local activeShieldMethod = shieldMethods[1]
	local shieldRefs = {}
	local disabledConnections = {}
	local monitorHeartbeat = nil
	local monitorElapsed = 0
	local swapState = { Original = nil, Clone = nil, Links = {} }
	local swapCharacterConnection = nil
	local humanoidChangeCallbacks = {}

	local function fireHumanoidChangedCallbacks()
		for _, callback in ipairs(humanoidChangeCallbacks) do
			task.defer(function()
				pcall(callback)
			end)
		end
	end

	state.OnHumanoidChanged = function(callback)
		table.insert(humanoidChangeCallbacks, callback)
		local handle
		handle = {
			Connected = true,
			Disconnect = function()
				handle.Connected = false
				local index = table.find(humanoidChangeCallbacks, callback)
				if index then
					table.remove(humanoidChangeCallbacks, index)
				end
			end,
		}
		return handle
	end

	local function rebindControlHumanoid(humanoid)
		pcall(function()
			local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
			local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
			if playerModule then
				local controls = require(playerModule):GetControls()
				if type(controls) == "table" then
					controls.humanoid = humanoid
				end
			end
		end)
	end

	local function restartAnimate(character)
		local animate = character and character:FindFirstChild("Animate")
		if animate and animate:IsA("LocalScript") then
			task.spawn(function()
				animate.Enabled = false
				task.wait()
				animate.Enabled = true
			end)
		end
	end

	local function disconnectSwapLinks()
		for _, link in ipairs(swapState.Links) do
			pcall(function()
				link:Disconnect()
			end)
		end
		table.clear(swapState.Links)
	end

	state.UndoSwap = function()
		disconnectSwapLinks()
		local character = localPlayer.Character
		local original = swapState.Original
		local clone = swapState.Clone
		swapState.Original = nil
		swapState.Clone = nil

		if original and clone and character and original.Parent == nil and clone.Parent == character then
			original.Parent = character
			workspace.CurrentCamera.CameraSubject = original
			rebindControlHumanoid(original)
			pcall(function()
				clone:Destroy()
			end)
			restartAnimate(character)
			fireHumanoidChangedCallbacks()
		end
	end

	local groundedStates = {
		[Enum.HumanoidStateType.Running] = true,
		[Enum.HumanoidStateType.RunningNoPhysics] = true,
		[Enum.HumanoidStateType.Landed] = true,
	}

	state.Grounded = function(humanoid)
		if not humanoid then
			local character = localPlayer.Character
			humanoid = character and character:FindFirstChildOfClass("Humanoid")
		end

		if not humanoid or humanoid.Health <= 0 or humanoid.FloorMaterial == Enum.Material.Air then
			return false
		end
		return groundedStates[humanoid:GetState()] == true
	end

	state.ShieldPaused = false

	state.WalkSpeed = function()
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local speed = humanoid and humanoid.WalkSpeed or 16
		local original = swapState.Original

		if original and original.Health > 0 then
			speed = math.min(speed, original.WalkSpeed)
		end

		local ok, treadmillSpeed = pcall(function()
			local leaderstats = localPlayer:FindFirstChild("leaderstats")
			leaderstats = leaderstats and leaderstats:FindFirstChild("Speed")
			local treadmillUtil = require(ReplicatedStorage.Shared.Util.TreadmillUtil)
			return leaderstats and treadmillUtil.SpeedPowerToWalkSpeed(leaderstats.Value) or nil
		end)

		if ok and tonumber(treadmillSpeed) and treadmillSpeed > 0 then
			return math.min(speed, treadmillSpeed)
		end

		return speed
	end

	local function performHumanoidSwap()
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		if swapState.Clone and swapState.Clone.Parent == character then
			return
		end

		if not state.Grounded(humanoid) then
			return
		end

		local clone = humanoid:Clone()
		humanoid.Parent = nil
		clone.Parent = character
		workspace.CurrentCamera.CameraSubject = clone
		rebindControlHumanoid(clone)
		restartAnimate(character)
		swapState.Original = humanoid
		swapState.Clone = clone
		fireHumanoidChangedCallbacks()

		table.insert(swapState.Links, humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			if clone.Parent ~= nil then
				clone.WalkSpeed = humanoid.WalkSpeed
			end
		end))

		local originalAnimator = humanoid:FindFirstChildOfClass("Animator")
		local cloneAnimator = clone:FindFirstChildOfClass("Animator")

		if originalAnimator and cloneAnimator then
			table.insert(swapState.Links, originalAnimator.AnimationPlayed:Connect(function(track)
				local animation = track.Animation
				if not animation or clone.Parent == nil then
					return
				end

				local ok, clonedTrack = pcall(function()
					return cloneAnimator:LoadAnimation(animation)
				end)

				if not ok or not clonedTrack then
					return
				end

				pcall(function()
					clonedTrack.Priority = track.Priority
					clonedTrack.Looped = track.Looped
					clonedTrack:Play(0.05, math.max(track.WeightTarget, 0.01), track.Speed)
				end)

				local stopConnection
				stopConnection = track.Stopped:Connect(function()
					stopConnection:Disconnect()
					pcall(function()
						clonedTrack:Stop(0.1)
					end)
				end)
			end))
		end

		table.insert(swapState.Links, clone.Died:Connect(function()
			disconnectSwapLinks()
			swapState.Original = nil
			swapState.Clone = nil
			local currentCharacter = localPlayer.Character
			if currentCharacter and humanoid.Parent == nil then
				humanoid.Parent = currentCharacter
				workspace.CurrentCamera.CameraSubject = humanoid
				rebindControlHumanoid(humanoid)
				fireHumanoidChangedCallbacks()
			end
			pcall(function()
				clone:Destroy()
			end)
			humanoid.Health = 0
		end))
	end

	local function disableUgiConnections()
		if type(getconnections) ~= "function" then
			return
		end

		for _, signal in ipairs({ RunService.Heartbeat, RunService.PreSimulation, RunService.PostSimulation }) do
			local ok, connections = pcall(getconnections, signal)
			if ok and type(connections) == "table" then
				for _, connection in ipairs(connections) do
					local ok2, fn = pcall(function()
						return connection.Function
					end)
					local isFunction = ok2 and type(fn) == "function"
					local infoOk, info = false, nil

					if isFunction then
						infoOk, info = pcall(debug.info, fn, "s")
					end

					if infoOk and string.find(tostring(info), "UGI", 1, true) then
						local ok3, enabled = pcall(function()
							return connection.Enabled
						end)
						if not ok3 or enabled ~= false then
							if pcall(function()
								connection:Disable()
							end) then
								table.insert(disabledConnections, connection)
							end
						end
					end
				end
			end
		end
	end

	local function restoreConnections()
		if monitorHeartbeat then
			monitorHeartbeat:Disconnect()
			monitorHeartbeat = nil
		end

		if swapCharacterConnection then
			swapCharacterConnection:Disconnect()
			swapCharacterConnection = nil
		end

		for _, connection in ipairs(disabledConnections) do
			pcall(function()
				connection:Enable()
			end)
		end
		table.clear(disabledConnections)
	end

	local function applyShieldTick()
		if state.ShieldPaused or localPlayer:GetAttribute("RaceId") ~= nil then
			return
		end

		if activeShieldMethod == shieldMethods[1] then
			performHumanoidSwap()
		else
			disableUgiConnections()
		end
	end

	local function startShieldLoop()
		applyShieldTick()
		monitorElapsed = 0

		monitorHeartbeat = RunService.Heartbeat:Connect(function(deltaTime)
			monitorElapsed = monitorElapsed + deltaTime
			local character = localPlayer.Character
			local needsSwap = activeShieldMethod == shieldMethods[1]

			if needsSwap then
				needsSwap = not (swapState.Clone and character and swapState.Clone.Parent == character)
			end

			local interval = needsSwap and 0.25 or 3
			if interval <= monitorElapsed then
				monitorElapsed = 0
				applyShieldTick()
			end
		end)

		swapCharacterConnection = localPlayer.CharacterAdded:Connect(function(character)
			disconnectSwapLinks()
			swapState.Original = nil
			swapState.Clone = nil

			if activeShieldMethod ~= shieldMethods[1] then
				return
			end

			task.spawn(function()
				character:WaitForChild("Humanoid", 10)
				task.wait(1)
				if monitorHeartbeat and localPlayer.Character == character then
					applyShieldTick()
				end
			end)
		end)
	end

	state.Swapped = function()
		if activeShieldMethod ~= shieldMethods[1] then
			return true
		end
		local character = localPlayer.Character
		return swapState.Clone ~= nil and character ~= nil and swapState.Clone.Parent == character
	end

	state.Shield = function(reason, wanted)
		shieldRefs[reason] = wanted == true or nil
		if next(shieldRefs) == nil then
			restoreConnections()
			return
		end

		if monitorHeartbeat then
			return
		end
		startShieldLoop()
	end

	state.SetShieldMethod = function(method)
		if not table.find(shieldMethods, method) or method == activeShieldMethod then
			return
		end

		local wasRunning = monitorHeartbeat ~= nil
		restoreConnections()
		activeShieldMethod = method

		if wasRunning and next(shieldRefs) ~= nil then
			startShieldLoop()
		end
	end

	registerCleanup(restoreConnections)
end

state.Shield("load", true)
state.Toggle = function(handle, fallback)
	if type(handle) ~= "table" then
		return fallback == true
	end

	if type(handle._manualState) == "boolean" then
		return handle._manualState
	end

	if type(handle.Value) == "boolean" then
		return handle.Value
	end

	local ok, result = pcall(function()
		local controller = handle._controller
		return type(controller) == "table" and type(controller.GetValue) == "function" and controller.GetValue()
	end)

	if ok and type(result) == "boolean" then
		return result
	end

	for _, methodName in ipairs({ "Get", "GetValue" }) do
		local ok2, methodFn = pcall(function()
			return handle[methodName]
		end)

		if ok2 and type(methodFn) == "function" then
			local ok3, result3 = pcall(methodFn, handle)
			if ok3 and type(result3) == "boolean" then
				return result3
			end
		end
	end

	return fallback == true
end

state.Root = function()
	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	return rootPart and rootPart:IsDescendantOf(workspace) and rootPart or nil
end

state.PlacedPoints = function()
	local container = workspace:FindFirstChild("PlacedEggRenders")
	local points = {}
	if not container then
		return points
	end
	local userIdStr = tostring(localPlayer.UserId)

	for _, child in ipairs(container:GetChildren()) do
		if string.find(child.Name, userIdStr, 1, true) then
			local ok, result = pcall(function()
				return child:IsA("Model") and child:GetPivot() or child.CFrame
			end)
			if ok then
				table.insert(points, result.Position)
			end
		end
	end

	return points
end

state.MyPlot = nil
state.MyBelt = nil

state.OwnPlot = function()
	if state.MyPlot and state.MyPlot.Parent then
		return state.MyPlot
	end

	local plots = workspace:FindFirstChild("Plots") or (workspace:FindFirstChild("__OBJECTS") and workspace.__OBJECTS:FindFirstChild("Plots"))
	if not plots then
		return nil
	end

	local lowerName = string.lower(localPlayer.Name)
	local lowerDisplay = string.lower(localPlayer.DisplayName)
	local userIdStr = tostring(localPlayer.UserId)

	for _, child in ipairs(plots:GetChildren()) do
		local attrs = child:GetAttributes()
		for _, v in pairs(attrs) do
			local sAttr = string.lower(tostring(v))
			if sAttr == lowerName or sAttr == lowerDisplay or tostring(v) == userIdStr then
				state.MyPlot = child
				return child
			end
		end

		if child.Name == userIdStr or string.lower(child.Name) == lowerName then
			state.MyPlot = child
			return child
		end

		for _, desc in ipairs(child:GetDescendants()) do
			if desc:IsA("TextLabel") then
				local lowerText = string.lower(desc.Text)
				if lowerText == lowerName or lowerText == lowerDisplay
					or string.find(lowerText, lowerName, 1, true)
					or string.find(lowerText, lowerDisplay, 1, true)
				then
					state.MyPlot = child
					return child
				end
			end
		end
	end

	return nil
end

local function averagePlacedPoint()
	local points = state.PlacedPoints()
	if #points == 0 then
		return nil
	end
	local sum = Vector3.zero
	for _, point in ipairs(points) do
		sum = sum + point
	end
	return sum / #points
end

state.PenAnchor = function()
	local average = averagePlacedPoint()
	if average then
		return average
	end
	local plot = state.OwnPlot()
	if not plot then
		return nil
	end
	local toUpdate = plot:FindFirstChild("ToUpdate")
	local starterPen = toUpdate and toUpdate:FindFirstChild("StarterPen") or plot:FindFirstChild("CenterPoint")
	if not starterPen then
		return nil
	end

	local ok, result = pcall(function()
		return starterPen:IsA("Model") and starterPen:GetPivot() or starterPen.CFrame
	end)

	return ok and result.Position or nil
end

state.Plot = function()
	if state.MyPlot and state.MyPlot.Parent then
		return state.MyPlot
	end

	local ownPlot = state.OwnPlot()
	if ownPlot then
		state.MyPlot = ownPlot
		return ownPlot
	end

	local plots = workspace:FindFirstChild("Plots") or (workspace:FindFirstChild("__OBJECTS") and workspace.__OBJECTS:FindFirstChild("Plots"))
	if not plots then
		return nil
	end

	local average = averagePlacedPoint()
	if average then
		local bestDistance = math.huge
		local bestPlot = nil

		for _, child in ipairs(plots:GetChildren()) do
			local ok, cframe, size = pcall(function()
				return child:GetBoundingBox()
			end)

			if ok and cframe and size then
				local localPoint = cframe:PointToObjectSpace(average)
				local inside = math.abs(localPoint.X) <= size.X / 2 and math.abs(localPoint.Z) <= size.Z / 2
				if inside then
					state.MyPlot = child
					return child
				end
				local distance = (cframe.Position - average).Magnitude
				if distance < bestDistance then
					bestPlot = child
					bestDistance = distance
				end
			end
		end

		if bestPlot and bestDistance <= 350 then
			state.MyPlot = bestPlot
			return bestPlot
		end
	end

	local root = state.Root()
	if root then
		for _, child in ipairs(plots:GetChildren()) do
			local ok, cframe, size = pcall(function()
				return child:GetBoundingBox()
			end)
			if ok and cframe and size then
				local localPoint = cframe:PointToObjectSpace(root.Position)
				if math.abs(localPoint.X) <= size.X / 2 + 5 and math.abs(localPoint.Z) <= size.Z / 2 + 5 then
					state.MyPlot = child
					return child
				end
			end
		end
	end

	return nil
end

state.Belt = function()
	if state.MyBelt and state.MyBelt.Parent then
		return state.MyBelt
	end

	local plot = state.Plot()
	local foundPart = nil

	if plot then
		local treadmillBottom = plot:FindFirstChild("TreadmillBottom", true)
		if treadmillBottom and treadmillBottom:IsA("BasePart") then
			foundPart = treadmillBottom
		end

		if not foundPart then
			local renders = workspace:FindFirstChild("__ClientTreadmillRenders")
			if renders then
				local render = renders:FindFirstChild("TreadmillRender_" .. plot.Name)
				if not render then
					for _, child in ipairs(renders:GetChildren()) do
						if string.find(child.Name, plot.Name, 1, true) then
							render = child
							break
						end
					end
				end
				local boundingPart = render and (render:FindFirstChild("BoundingBoxPart")
					or (render:IsA("Model") and render.PrimaryPart)
					or render:FindFirstChildWhichIsA("BasePart"))
				if boundingPart then
					foundPart = boundingPart
				end
			end
		end

		if not foundPart then
			local treadmillModel = plot:FindFirstChild("Treadmill", true)
			if treadmillModel then
				local part = treadmillModel:FindFirstChild("TreadmillBottom", true)
					or treadmillModel:FindFirstChild("Belt", true)
					or (treadmillModel:IsA("Model") and treadmillModel.PrimaryPart)
					or treadmillModel:FindFirstChildWhichIsA("BasePart")
				if part then
					foundPart = part
				end
			end
		end

		if not foundPart then
			local upgrade = plot:FindFirstChild("TreadmillUpgrade", true)
			if upgrade then
				local part = upgrade:IsA("BasePart") and upgrade or upgrade:FindFirstChildWhichIsA("BasePart")
				if part then
					foundPart = part
				end
			end
		end
	end

	if not foundPart then
		local renders = workspace:FindFirstChild("__ClientTreadmillRenders")
		if renders then
			local children = renders:GetChildren()
			local userIdStr = tostring(localPlayer.UserId)
			local lowerName = string.lower(localPlayer.Name)

			for _, render in ipairs(children) do
				local rName = string.lower(render.Name)
				if string.find(rName, userIdStr, 1, true) or string.find(rName, lowerName, 1, true) then
					local part = render:FindFirstChild("BoundingBoxPart") or (render:IsA("Model") and render.PrimaryPart) or render:FindFirstChildWhichIsA("BasePart")
					if part then
						foundPart = part
						break
					end
				end
			end

			if not foundPart and #children == 1 then
				local render = children[1]
				foundPart = render:FindFirstChild("BoundingBoxPart") or (render:IsA("Model") and render.PrimaryPart) or render:FindFirstChildWhichIsA("BasePart")
			end

			if not foundPart then
				local anchor = state.PenAnchor() or averagePlacedPoint()
				if anchor then
					local bestDist = math.huge
					for _, render in ipairs(children) do
						local part = render:FindFirstChild("BoundingBoxPart") or (render:IsA("Model") and render.PrimaryPart) or render:FindFirstChildWhichIsA("BasePart")
						if part then
							local dist = (part.Position - anchor).Magnitude
							if dist < bestDist then
								bestDist = dist
								foundPart = part
							end
						end
					end
				end
			end

			if not foundPart and #children > 0 then
				local refPos = (type(state.StealHome) == "function" and state.StealHome())
					or (state.Root() and state.Root().Position)
					or Vector3.new(528, 70, -364)
				local bestDist = math.huge
				for _, render in ipairs(children) do
					local part = render:FindFirstChild("BoundingBoxPart") or (render:IsA("Model") and render.PrimaryPart) or render:FindFirstChildWhichIsA("BasePart")
					if part then
						local dist = (part.Position - refPos).Magnitude
						if dist < bestDist then
							bestDist = dist
							foundPart = part
						end
					end
				end
			end
		end
	end

	if not foundPart then
		local plots = workspace:FindFirstChild("Plots") or (workspace:FindFirstChild("__OBJECTS") and workspace.__OBJECTS:FindFirstChild("Plots"))
		if plots then
			for _, child in ipairs(plots:GetChildren()) do
				local part = child:FindFirstChild("TreadmillBottom", true) or child:FindFirstChild("Belt", true)
				if part and part:IsA("BasePart") then
					foundPart = part
					break
				end
			end
		end
	end

	if foundPart then
		state.MyBelt = foundPart
		return foundPart
	end

	return nil
end

state.DistanceTo = function(position)
	local root = state.Root()
	if not root or not position then
		return math.huge
	end
	return (root.Position - position).Magnitude
end

do
	local hiddenParts = {}
	local holdCount = 0

	local function collectBeltParts()
		local plot = state.Plot()
		if not plot then
			return {}
		end
		local parts = {}

		for _, partName in ipairs({ "TreadmillBottom", "TreadmillUpgrade" }) do
			local target = plot:FindFirstChild(partName)
			if target then
				if target:IsA("BasePart") then
					table.insert(parts, target)
				else
					for _, descendant in ipairs(target:GetDescendants()) do
						if descendant:IsA("BasePart") then
							table.insert(parts, descendant)
						end
					end
				end
			end
		end

		local renders = workspace:FindFirstChild("__ClientTreadmillRenders")
		renders = renders and renders:FindFirstChild("TreadmillRender_" .. plot.Name)
		if renders then
			for _, descendant in ipairs(renders:GetDescendants()) do
				if descendant:IsA("BasePart") then
					table.insert(parts, descendant)
				end
			end
		end

		return parts
	end

	local function hideBeltParts()
		for _, part in ipairs(collectBeltParts()) do
			if not hiddenParts[part] then
				hiddenParts[part] = {
					CFrame = part.CFrame,
					CanTouch = part.CanTouch,
					CanCollide = part.CanCollide,
					Transparency = part.Transparency,
				}
				pcall(function()
					part.CanTouch = false
					part.CanCollide = false
					part.Transparency = 1
					part.CFrame = part.CFrame - Vector3.new(0, 120, 0)
				end)
			end
		end
	end

	local function restoreBeltParts()
		for part, saved in pairs(hiddenParts) do
			if part and part.Parent then
				pcall(function()
					part.CFrame = saved.CFrame
					part.CanTouch = saved.CanTouch
					part.CanCollide = saved.CanCollide
					part.Transparency = saved.Transparency
				end)
			end
		end
		table.clear(hiddenParts)
	end

	state.HoldBelt = function()
		holdCount = holdCount + 1
		hideBeltParts()
	end

	state.ReleaseBelt = function()
		holdCount = math.max(0, holdCount - 1)
		if holdCount == 0 then
			restoreBeltParts()
		end
	end

	state.BeltHeld = function()
		return holdCount > 0
	end

	state.RefreshBeltHide = function()
		if holdCount > 0 then
			hideBeltParts()
		end
	end

	registerCleanup(function()
		holdCount = 0
		restoreBeltParts()
	end)

	state.LeaveBelt = function()
		local remote = (networking and (networking:FindFirstChild("RF/Treadmill/AskDoff", true) or networking:FindFirstChild("RF/Treadmill/AskDoff")))
			or ReplicatedStorage:FindFirstChild("RF/Treadmill/AskDoff", true)
		if remote and remote:IsA("RemoteFunction") then
			pcall(remote.InvokeServer, remote)
		end
	end

	state.Treadmill = { Riding = false }

	state.ResetBelt = function()
		holdCount = 0
		restoreBeltParts()
	end

	state.OnBelt = function()
		local belt = state.Belt()
		if not belt or hiddenParts[belt] then
			return false
		end
		local root = state.Root()
		if not root then
			return false
		end
		local localPoint = belt.CFrame:PointToObjectSpace(root.Position)
		local withinX = math.abs(localPoint.X) <= belt.Size.X / 2 + 3.5
		local withinZ = withinX and math.abs(localPoint.Z) <= belt.Size.Z / 2 + 3.5
		return withinZ and localPoint.Y >= -4 and localPoint.Y <= belt.Size.Y / 2 + 10
	end
end

state.ExitBelt = function()
	state.Treadmill.Riding = false
	state.LeaveBelt()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			humanoid.Jump = true
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end)
	end
	task.wait(0.35)
end

state.Flying = false
state.Driving = 0

state.BeginFlight = function()
	state.Flying = true
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end)
	end
	return state.Root() ~= nil
end

state.SetFlightVelocity = function(velocity)
	local root = state.Root()
	if root then
		root.AssemblyLinearVelocity = velocity
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

state.EndFlight = function()
	state.Flying = false
	local root = state.Root()
	if root then
		pcall(function()
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end)
	end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
	end
end

do
	local disabledHumanoidStates = {
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Physics,
		Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.PlatformStanding,
	}

	local savedCollisions = {}
	local godEnabled = false

	state.GodMode = function(wanted)
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid then
			return
		end

		if wanted then
			godEnabled = true

			for _, humanoidState in ipairs(disabledHumanoidStates) do
				pcall(function()
					humanoid:SetStateEnabled(humanoidState, false)
				end)
			end

			pcall(function()
				humanoid.BreakJointsOnDeath = false
			end)

			for _, descendant in ipairs(character:GetDescendants()) do
				if descendant:IsA("BasePart") and savedCollisions[descendant] == nil then
					savedCollisions[descendant] = descendant.CanCollide
					pcall(function()
						descendant.CanCollide = false
					end)
				end
			end
		elseif godEnabled then
			godEnabled = false

			for _, humanoidState in ipairs(disabledHumanoidStates) do
				pcall(function()
					humanoid:SetStateEnabled(humanoidState, true)
				end)
			end

			for part, saved in pairs(savedCollisions) do
				if part and part.Parent then
					pcall(function()
						part.CanCollide = saved
					end)
				end
			end

			table.clear(savedCollisions)
		end
	end
end

state.GodTick = function()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health < humanoid.MaxHealth then
		pcall(function()
			humanoid.Health = humanoid.MaxHealth
		end)
	end
end

state.StopWalking = function()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and root then
		pcall(function()
			humanoid:MoveTo(root.Position)
			humanoid:Move(Vector3.zero, false)
		end)
	end
end

local function walkLoop(destination, minDistance, maxDuration, shouldCancel)
	local threshold = tonumber(minDistance) or 6
	local duration = tonumber(maxDuration) or 10
	local elapsed = 0
	local lastPosition = nil
	local stuckTime = 0
	local jumpCooldown = 0

	while elapsed < duration do
		if type(shouldCancel) == "function" and shouldCancel() then
			state.StopWalking()
			return false
		end

		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			return false
		end

		if (root.Position - destination).Magnitude <= threshold then
			state.StopWalking()
			return true
		end

		local isStuck = lastPosition and (root.Position - lastPosition).Magnitude < 1
		if isStuck then
			stuckTime = stuckTime + 0.2
		else
			stuckTime = 0
		end

		lastPosition = root.Position
		jumpCooldown = math.max(0, jumpCooldown - 0.2)

		if stuckTime >= 0.8 and jumpCooldown <= 0 then
			state.LeaveBelt()
			pcall(function()
				humanoid.Jump = true
			end)
			stuckTime = 0
			jumpCooldown = 1.5
		end

		humanoid:MoveTo(destination)
		elapsed = elapsed + task.wait(0.2)
	end

	state.StopWalking()
	return state.DistanceTo(destination) <= threshold
end

state.WalkTo = function(destination, minDistance, maxDuration, shouldCancel)
	state.Driving = state.Driving + 1
	local ok, result = pcall(walkLoop, destination, minDistance, maxDuration, shouldCancel)
	state.Driving = math.max(0, state.Driving - 1)
	return ok and result == true
end

local mutationLabels = {
	Boss = "Fractured",
	GreatBloom = "Spirit Bloom",
	Sakura = "Bloom",
	Monstrous = "Parasite",
}

task.spawn(function()
	local mutations = modules.Mutations
	local ok, result = pcall(function()
		return mutations.All()
	end)

	if ok and type(result) == "table" then
		for key, entry in pairs(result) do
			local id = type(entry) == "table" and (entry.Id or key) or nil
			local label = type(entry) == "table" and entry.Label or nil
			if id ~= nil and type(label) == "string" and label ~= "" then
				mutationLabels[tostring(id)] = label
			end
		end
	end
end)

local mutationLabel
mutationLabel = function(id)
	return mutationLabels[tostring(id)] or tostring(id)
end

local stealSortOptions
local stealSort
local autoStealToggle
local stealStatusRow
local stealInfoRow
local rarityOptions
local rarityNumberMap
local targetAreas, minRarityNumber, targetEggCategories, forcedStealQueue, priorityStealSet, cancelledSteals, stealIndexEnabled, missingIndexEggs, minStealValue, flyHeightOffset
local flySpeed, resetAutoStealState, targetAreasDropdown

do
	local areaList = {
		"Forest",
		"Desert",
		"Snow",
		"Lake",
		"Jungle",
		"Volcano",
		"Prehistoric",
		"Cosmic",
		"Abyss Ocean",
		"Cherry Blossom",
		"Light Dark",
		"Titan Temple",
		"Enchanted Forest",
	}

	local knownAreas = {}
	for _, areaName in ipairs(areaList) do
		knownAreas[areaName] = true
		knownAreas[string.lower(string.gsub(areaName, "%s+", ""))] = true
		knownAreas[string.gsub(areaName, "%s+", "")] = true
		knownAreas[string.gsub(areaName, "%s+", "_")] = true
	end

	task.spawn(function()
		local eggState = modules.EggState
		local ok, result = pcall(function()
			return eggState.ReadFieldEggs()
		end)
		if ok and type(result) == "table" and type(result.Records) == "table" then
			local addedNew = false
			for _, record in pairs(result.Records) do
				local areaId = type(record) == "table" and record.AreaId or nil
				if type(areaId) == "string" and not knownAreas[areaId] then
					knownAreas[areaId] = true
					knownAreas[string.lower(string.gsub(areaId, "%s+", ""))] = true
					knownAreas[string.gsub(areaId, "%s+", "")] = true
					knownAreas[string.gsub(areaId, "%s+", "_")] = true
					table.insert(areaList, areaId)
					if targetAreas then
						targetAreas[areaId] = true
						targetAreas[string.lower(string.gsub(areaId, "%s+", ""))] = true
						targetAreas[string.gsub(areaId, "%s+", "")] = true
						targetAreas[string.gsub(areaId, "%s+", "_")] = true
					end
					addedNew = true
				end
			end
			if addedNew and targetAreasDropdown then
				pcall(function()
					if type(targetAreasDropdown.SetValues) == "function" then
						targetAreasDropdown:SetValues(areaList)
					elseif type(targetAreasDropdown.Refresh) == "function" then
						targetAreasDropdown:Refresh(areaList, true)
					end
				end)
			end
		end
	end)

	rarityOptions = { "Any" }
	rarityNumberMap = { Any = 0 }
	local rarityNames = {}
	local directory = modules.Assets and modules.Assets.Directory

	if type(directory) == "table" then
		for _, entry in pairs(directory) do
			local rarity = type(entry) == "table" and entry.Rarity or nil
			local rarityNumber = type(rarity) == "table" and tonumber(rarity.RarityNumber or rarity.Rank) or nil
			if rarityNumber then
				local label = rarityNames[rarityNumber]
				if not label then
					label = tostring(rarity.DisplayName or rarity._id or rarityNumber)
				end
				rarityNames[rarityNumber] = label
			end
		end
	end

	if next(rarityNames) == nil then
		rarityNames = {
			"Common",
			"Uncommon",
			"Rare",
			"Epic",
			"Legendary",
			"Mythic",
			"Cosmic",
			"Secret",
			"Eternal",
			"Divine",
		}
	end

	local rarityKeys = {}
	for key in pairs(rarityNames) do
		table.insert(rarityKeys, key)
	end
	table.sort(rarityKeys)

	for _, key in ipairs(rarityKeys) do
		table.insert(rarityOptions, rarityNames[key])
		rarityNumberMap[rarityNames[key]] = key
	end

	stealSortOptions = { "Best Rarity", "Biggest Weight", "Best Mutation", "Highest Value", "Lowest Value" }
	targetAreas = {}
	minRarityNumber = 0
	targetEggCategories = {}
	forcedStealQueue = {}
	priorityStealSet = {}
	cancelledSteals = {}
	state.Steal.RiftPriority = false
	state.Steal.RiftNeeds = {}
	stealIndexEnabled = false
	missingIndexEggs = {}
	minStealValue = 0
	stealSort = stealSortOptions[4]
	flyHeightOffset = 27.4
	flySpeed = 400
	resetAutoStealState = nil

	stealStatusRow = autoStealSection:CreateText({ Name = "Steal Status", Text = "Idle" })
	stealInfoRow = autoStealSection:CreateText({ Name = "Steal Target", Text = "None" })

	autoStealToggle = autoStealSection:CreateToggle({
		Name = "Auto Steal",
		Default = false,
		Callback = function(arg)
			if type(arg) == "boolean" then
				autoStealToggle._manualState = arg
			end
			if resetAutoStealState then
				resetAutoStealState()
			end
		end,
	})

	local function registerTargetArea(tbl, name)
		if type(name) ~= "string" or name == "" then
			return
		end
		tbl[name] = true
		tbl[string.lower(name)] = true
		tbl[string.lower(string.gsub(name, "%s+", ""))] = true
		tbl[string.gsub(name, "%s+", "")] = true
		tbl[string.gsub(name, "%s+", "_")] = true
		tbl[string.lower(string.gsub(name, "[%s_]+", ""))] = true
	end

	for _, areaName in ipairs(areaList) do
		registerTargetArea(targetAreas, areaName)
	end

	targetAreasDropdown = fixDropdownAll(autoStealSection:CreateMultiDropdown({
		Name = "Target Areas",
		Options = areaList,
		Default = areaList,
		Callback = function(selected)
			local newTargets = {}

			if type(selected) == "table" then
				for key, entry in pairs(selected) do
					if entry == true and type(key) == "string" then
						registerTargetArea(newTargets, key)
					elseif type(entry) == "string" then
						registerTargetArea(newTargets, entry)
					end
				end
			end

			if next(newTargets) == nil then
				for _, areaName in ipairs(areaList) do
					registerTargetArea(newTargets, areaName)
				end
			end

			targetAreas = newTargets
		end,
	}))

	autoStealSection:CreateDropdown({
		Name = "Min Rarity",
		Note = "Steal eggs of the chosen rarity and every rarity above it",
		Options = rarityOptions,
		Default = rarityOptions[1],
		Callback = function(selected)
			minRarityNumber = rarityNumberMap[selected] or 0
		end,
	})

	createValueSlider(autoStealSection, {
		Name = "Min Steal Value",
		Note = "Skip eggs worth less than this. Drag or type 250k, 50m, 1.5b",
		Legacy = "Min Value To Steal",
		SectionName = "Auto Steal",
		OnRaw = function(value)
			minStealValue = value
		end,
	})

	do
		local specificEggOptions = {}
		local specificEggMap = {}
		local assetDirectory = modules.Assets and modules.Assets.Directory
		local eggList = {}

		if type(assetDirectory) == "table" then
			for category, entry in pairs(assetDirectory) do
				local rarity = type(entry) == "table" and entry.Rarity or nil
				local rarityNumber = type(rarity) == "table" and tonumber(rarity.RarityNumber or rarity.Rank) or nil

				if rarityNumber then
					local displayName = entry.DisplayName or category
					table.insert(eggList, {
						Category = tostring(category),
						Name = tostring(displayName),
						Rarity = rarityNumber,
						RarityName = tostring(rarity.DisplayName or rarity._id or rarityNumber),
					})
				end
			end
		end

		table.sort(eggList, function(a, b)
			if a.Rarity ~= b.Rarity then
				return a.Rarity > b.Rarity
			end
			return a.Name < b.Name
		end)

		for _, item in ipairs(eggList) do
			local label = string.format("%s [%s]", item.Name, item.RarityName)
			if specificEggMap[label] then
				label = string.format("%s [%s] (%s)", item.Name, item.RarityName, item.Category)
			end
			table.insert(specificEggOptions, label)
			specificEggMap[label] = item.Category
		end

		fixDropdownAll(autoStealSection:CreateMultiDropdown({
			Name = "Target Specific Eggs",
			Note = "Only steal these eggs (empty = all)",
			Options = specificEggOptions,
			Default = {},
			Callback = function(selected)
				local categories = {}

				if type(selected) == "table" then
					for key, entry in pairs(selected) do
						local label
						if entry == true and type(key) == "string" then
							label = key
						elseif type(entry) == "string" then
							label = entry
						end

						if label and specificEggMap[label] then
							categories[specificEggMap[label]] = true
						end
					end
				end

				targetEggCategories = categories
			end,
		}))
	end

	do
		local riftRefreshInterval = 30
		local riftToggle = nil
		local riftRefreshBusy = false
		local nextRiftRefreshAt = 0

		local function collectOwnedCategories()
			local owned = {}
			local saveModule = modules.Save

			if type(saveModule) == "table" and type(saveModule.Get) == "function" then
				local ok, result = pcall(saveModule.Get)
				if ok and type(result) == "table" then
					for _, item in pairs(result.Inventory or {}) do
						local cat = type(item) == "table" and (item.Category or item.AssetCategory or item.Name) or nil
						if cat ~= nil then
							local sCat = tostring(cat)
							owned[sCat] = true
							owned[sCat:lower():gsub("[%s_%-]+", "")] = true
						end
					end

					for _, item in pairs(result.EggInventory or {}) do
						local cat = type(item) == "table" and (item.AssetCategory or item.Category or item.Name) or nil
						if cat ~= nil then
							local sCat = tostring(cat)
							owned[sCat] = true
							owned[sCat:lower():gsub("[%s_%-]+", "")] = true
						end
					end
				end
			end

			return owned
		end

		local function refreshRiftNeeds()
			local remote = networking:FindFirstChild("RF/ScrambleTradeIn/AskState")
			if not remote or not remote:IsA("RemoteFunction") then
				return
			end
			local ok, result = pcall(remote.InvokeServer, remote)
			if not ok or type(result) ~= "table" or type(result.Requirements) ~= "table" then
				return
			end
			local owned = collectOwnedCategories()
			local needs = {}

			for _, requirement in pairs(result.Requirements) do
				local reqStr = tostring(requirement)
				local reqNorm = reqStr:lower():gsub("[%s_%-]+", "")
				if not owned[reqStr] and (reqNorm == "" or not owned[reqNorm]) then
					needs[reqStr] = true
				end
			end

			state.Steal.RiftNeeds = needs
		end

		taskScheduler.Add(function()
			if not state.Steal.RiftPriority or riftRefreshBusy or os.clock() < nextRiftRefreshAt then
				return false
			end
			riftRefreshBusy = true
			nextRiftRefreshAt = os.clock() + riftRefreshInterval

			task.spawn(function()
				pcall(refreshRiftNeeds)
				riftRefreshBusy = false
			end)

			return false
		end)

		local function clearFulfilledRiftNeeds()
			local riftNeeds = state.Steal.RiftNeeds
			if not state.Steal.RiftPriority or next(riftNeeds) == nil then
				return
			end
			local owned = collectOwnedCategories()
			local changed = false

			for category in pairs(riftNeeds) do
				if owned[category] then
					riftNeeds[category] = nil
					changed = true
				end
			end

			if changed then
				taskScheduler.Wake()
			end
		end

		local saveModule = modules.Save
		if type(saveModule) == "table" and type(saveModule.FieldSignal) == "function" then
			for _, fieldName in ipairs({ "EggInventory", "Inventory" }) do
				local ok, fieldSignal = pcall(saveModule.FieldSignal, fieldName)
				if ok and type(fieldSignal) == "table" and type(fieldSignal.Connect) == "function" then
					local ok2, connection = pcall(fieldSignal.Connect, fieldSignal, function()
						task.defer(clearFulfilledRiftNeeds)
					end)
					if ok2 and connection then
						registerCleanup(function()
							pcall(function()
								connection:Disconnect()
							end)
						end)
					end
				end
			end
		end

		riftToggle = autoStealSection:CreateToggle({
			Name = "Steal Missing Lab Eggs",
			Default = false,
			Callback = function()
				state.Steal.RiftPriority = state.Toggle(riftToggle, false) == true
				nextRiftRefreshAt = 0

				if not state.Steal.RiftPriority then
					state.Steal.RiftNeeds = {}
				end

				taskScheduler.Wake()
			end,
		})
	end

	do
		local indexRefreshInterval = 5
		local claimInterval = 5
		local redeemCooldown = 60
		local stealMissingIndexToggle = nil
		local nextIndexRefreshAt = 0
		local nextClaimAt = 0
		local claimBusy = false
		local eggRedeemCooldownAt = {}

		local function getSaveData()
			local saveModule = modules.Save
			if type(saveModule) == "table" and type(saveModule.Get) == "function" then
				local ok, result = pcall(saveModule.Get)
				if ok and type(result) == "table" then
					return result
				end
			end
			return nil
		end

		local function refreshIndexNeeds()
			local save = getSaveData()
			local areaDirectory = modules.Areas and modules.Areas.Directory
			local assetDirectory = modules.Assets and modules.Assets.Directory
			if not save or type(areaDirectory) ~= "table" or type(assetDirectory) ~= "table" then
				return
			end

			local index = type(save.Index) == "table" and save.Index or {}
			local ownedCategories = {}

			for _, item in pairs(save.Inventory or {}) do
				if type(item) == "table" and item.Category ~= nil then
					ownedCategories[tostring(item.Category)] = true
				end
			end

			for _, item in pairs(save.EggInventory or {}) do
				if type(item) == "table" and item.AssetCategory ~= nil then
					ownedCategories[tostring(item.AssetCategory)] = true
				end
			end

			local missing = {}

			for _, areaEntry in pairs(areaDirectory) do
				local rarityNumber = type(areaEntry) == "table" and type(areaEntry.Rarity) == "table"
					and tonumber(areaEntry.Rarity.RarityNumber or areaEntry.Rarity.Rank) or 0
				local dropTable = type(areaEntry) == "table" and areaEntry.DropTable or {}

				for _, dropEntry in pairs(dropTable) do
					local assetId = type(dropEntry) == "table" and dropEntry[1] or nil
					local weight = type(dropEntry) == "table" and tonumber(dropEntry[2]) or 0
					local assetEntry = assetId ~= nil and assetDirectory[assetId] or nil

					if type(assetEntry) == "table" and weight > 0 and assetEntry.DontRoll ~= true then
						local category = tostring(assetId)
						if index[assetId] ~= true and not ownedCategories[category] and (missing[category] == nil or rarityNumber > missing[category]) then
							missing[category] = rarityNumber
						end
					end
				end
			end

			missingIndexEggs = missing
		end

		local function invokeRemote(name, ...)
			local remote = networking:FindFirstChild(name)
			if not remote or not remote:IsA("RemoteFunction") then
				return false
			end
			local ok, result = pcall(remote.InvokeServer, remote, ...)
			return ok and result ~= false
		end

		local function collectAssetIds(module, paths)
			local result = {}
			if type(module) ~= "table" then
				return result
			end

			for _, path in ipairs(paths) do
				local value = module
				for _, segment in ipairs(path) do
					value = type(value) == "table" and value[segment] or nil
				end
				for _, entry in ipairs(type(value) == "table" and value or {}) do
					if type(entry) == "table" and entry.AssetId ~= nil then
						table.insert(result, entry.AssetId)
					end
				end
			end

			return result
		end

		local limitedEggs = {
			{
				Id = "LimitedEgg",
				Gear = "GravityDisruptor",
				Module = "LimitedEgg",
				Lists = { { "Entries" }, { "MechaReroll", "Entries" } },
			},
			{
				Id = "BrainrotEgg",
				Gear = "BeeLauncher",
				Module = "BrainrotEgg",
				Lists = { { "Entries" } },
			},
			{
				Id = "MonsterEgg",
				Gear = "BeeLauncher",
				Module = "MonsterEgg",
				Lists = { { "Entries" }, { "MechaEntries" } },
			},
		}

		local function redeemLimitedEggs()
			local save = getSaveData()
			if not save then
				return
			end

			local index = type(save.Index) == "table" and save.Index or {}
			local claimed = type(save.IndexClaimedCategories) == "table" and save.IndexClaimedCategories or {}

			for key, value in pairs(index) do
				if value == true and claimed[key] ~= true then
					invokeRemote("RF/Codex/AskRedeemAll")
					break
				end
			end

			local gearInventory = type(save.GearInventory) == "table" and save.GearInventory or {}

			for _, entry in ipairs(limitedEggs) do
				local needsGear = (tonumber(gearInventory[entry.Gear]) or 0) <= 0
				local cooldownReady = os.clock() >= (eggRedeemCooldownAt[entry.Id] or 0)

				if needsGear and cooldownReady then
					local assetIds = collectAssetIds(modules[entry.Module], entry.Lists)
					local allMissing = #assetIds > 0

					for _, assetId in ipairs(assetIds) do
						if index[assetId] == true then
							allMissing = false
							break
						end
					end

					if allMissing then
						eggRedeemCooldownAt[entry.Id] = os.clock() + redeemCooldown
						invokeRemote("RF/Codex/AskRedeemLimitedEgg", entry.Id)
					end
				end
			end
		end

		taskScheduler.Add(function()
			local now = os.clock()

			if stealIndexEnabled and now >= nextIndexRefreshAt then
				nextIndexRefreshAt = now + indexRefreshInterval
				pcall(refreshIndexNeeds)
			end

			if not claimBusy and now >= nextClaimAt and state.Toggle(state.IndexClaimHandle, false) then
				claimBusy = true
				nextClaimAt = now + claimInterval

				task.spawn(function()
					pcall(redeemLimitedEggs)
					claimBusy = false
				end)
			end

			return false
		end)

		stealMissingIndexToggle = autoStealSection:CreateToggle({
			Name = "Steal Missing Index Eggs",
			Note = "Also steal eggs missing from your index, highest area first",
			Default = false,
			Callback = function()
				stealIndexEnabled = state.Toggle(stealMissingIndexToggle, false) == true
				nextIndexRefreshAt = 0

				if not stealIndexEnabled then
					missingIndexEggs = {}
				end

				taskScheduler.Wake()
			end,
		})

		state.IndexClaimRestart = function()
			nextClaimAt = 0
			taskScheduler.Wake()
		end
	end
end

state.Steal.PriorityHandle = autoStealSection:CreateDropdown({
	Name = "Steal Priority",
	Options = stealSortOptions,
	Default = stealSortOptions[4],
	Callback = function(selected)
		if table.find(stealSortOptions, selected) then
			stealSort = selected
			if type(state.ResortSteal) == "function" then
				state.ResortSteal()
			end
		end
	end,
})

state.SafeCarry.InstantHandle = autoStealSection:CreateToggle({
	Name = "Instant Steal",
	Note = "Delivers the egg to the safe zone in a few seconds, needs enough Speed",
	Default = false,
	Locked = not isPremiumUser(),
	TextLocked = "Premium Required",
	Callback = function(arg)
		if type(arg) ~= "boolean" then
			arg = state.Toggle(state.SafeCarry.InstantHandle, false)
		end

		if arg and not isPremiumUser() then
			notifyPremium("Instant Steal")
			state.SafeCarry.LineDrop = false
			state.SafeCarry.SpeedJitter = 0.08
			if state.SafeCarry.InstantHandle then
				pcall(function() state.SafeCarry.InstantHandle:Set(false, false) end)
			end
			return
		end

		state.SafeCarry.LineDrop = arg ~= false
		state.SafeCarry.SpeedJitter = state.SafeCarry.LineDrop and 0 or 0.08

		if state.StealPanelSync then
			pcall(state.StealPanelSync)
		end
	end,
})

state.SafeCarry.RunHandle = autoStealSection:CreateSlider({
	Name = "Tween Speed",
	Note = "Over 100% may glitch",
	Min = 50,
	Max = 120,
	Default = 100,
	Increment = 1,
	Unit = "%",
	Callback = function(arg)
		state.SafeCarry.RunSpeed = math.clamp(tonumber(arg) or 100, 50, 120) / 100
	end,
})

autoStealSection:CreateSlider({
	Name = "Carry Speed",
	Min = 80,
	Max = 120,
	Default = 100,
	Increment = 1,
	Unit = "%",
	Callback = function(arg)
		state.SafeCarry.CarryScale = math.clamp(tonumber(arg) or 100, 80, 120) / 100
	end,
})

autoStealSection:CreateToggle({
	Name = "Beat Guard",
	Note = "Automatically adjusts carry speed to outrun the guard, recommended for far zones",
	Default = false,
	Callback = function(arg)
		if type(arg) ~= "boolean" then
			arg = false
		end

		state.SafeCarry.BeatGuard = arg

		if arg then
			table.clear(state.SafeCarry.Blocked)
		end

		if state.StealPanelSync then
			pcall(state.StealPanelSync)
		end
	end,
})

state.AntiGuard.Handle = window:CreateState({ Name = "Anti Guard Enabled", Default = false })

pcall(function()
	state.AntiGuard.Enabled = state.AntiGuard.Handle:Get() == true
end)

pcall(function()
	state.AntiGuard.Handle:Subscribe(function(arg)
		if type(arg) ~= "boolean" then
			arg = state.AntiGuard.Handle:Get()
		end

		state.AntiGuard.Enabled = arg == true

		if state.StealPanelSync then
			pcall(state.StealPanelSync)
		end

		if state.AntiGuard.Render and state.UiDefer then
			state.UiDefer(function()
				pcall(state.AntiGuard.Render, false)
			end)
		end
	end)
end)

state.AntiGuard.PanelHandle = autoStealSection:CreateToggle({
	Name = "Anti Guard Panel",
	Default = false,
	Callback = function(panelShown)
		if type(panelShown) ~= "boolean" then
			panelShown = state.Toggle(state.AntiGuard.PanelHandle, true)
		end

		state.AntiGuard.PanelShown = panelShown

		if state.AntiGuard.ShowPanel then
			pcall(state.AntiGuard.ShowPanel, panelShown)
		end
	end,
})

local stealTargetText = "None"
local stealStatusText = "Idle"
local stealTaskRunning = false
local stealGeneration = 0
local blockedEggUids = {}
local blockedEggDuration = 20
local stealCurrentUid = nil

local function isStaleGeneration(generation)
	return generation ~= stealGeneration or not state.Toggle(autoStealToggle, false)
end

local checkNightOrWall
do
	local scheduledWakeAt = {}
	local lastWakeScheduled = 0

	local function scheduleWakeAt(timestamp)
		if type(timestamp) ~= "number" or scheduledWakeAt[timestamp] then
			return
		end
		scheduledWakeAt[timestamp] = true

		task.delay(math.max(0, timestamp - workspace:GetServerTimeNow()) + 0.05, function()
			scheduledWakeAt[timestamp] = nil
			taskScheduler.Wake()
		end)
	end

	checkNightOrWall = function()
		local areaEggCycle = modules.AreaEggCycle
		if type(areaEggCycle) ~= "table" then
			return nil
		end

		local ok, serverTime, isNight, nextNightTime, nextResetTime = pcall(function()
			local now = workspace:GetServerTimeNow()
			local getNextReset = areaEggCycle.NextResetTime
			return now, areaEggCycle.IsNightPhase(now), areaEggCycle.NextNightTime(now), getNextReset(now)
		end)

		if not ok or type(nextResetTime) ~= "number" then
			return nil
		end

		if isNight == true then
			lastWakeScheduled = nextResetTime + state.WallOpenDelay()
			scheduleWakeAt(lastWakeScheduled)
			return lastWakeScheduled, "night", serverTime
		end

		if state.WallSealed() then
			scheduleWakeAt(serverTime + 0.3)
			return math.max(lastWakeScheduled, serverTime), "wall", serverTime
		end

		if type(nextNightTime) == "number" and nextNightTime > serverTime then
			scheduleWakeAt(nextNightTime)
		end

		return nil
	end
end

do
	local resetWall = modules.AreaEggResetWall
	local changed = type(resetWall) == "table" and resetWall.Changed or nil
	if changed and type(changed.Connect) == "function" then
		local ok, connection = pcall(function()
			return changed:Connect(function()
				taskScheduler.Wake()
			end)
		end)
		if ok and connection then
			registerCleanup(function()
				pcall(function()
					connection:Disconnect()
				end)
			end)
		end
	end
end

local firstAreaWaitSeconds = 8
local firstAreaUids = nil
local firstAreaClearDeadline = 0

local function collectFirstAreaUids(skipPrefix)
	local uids = {}
	local prefix = "FirstAreaEgg_" .. tostring(localPlayer.UserId)
	local eggState = modules.EggState

	if type(eggState) == "table" and type(eggState.ReadFieldEggs) == "function" then
		local ok, result = pcall(eggState.ReadFieldEggs)
		if ok and type(result) == "table" and type(result.Records) == "table" then
			for _, record in pairs(result.Records) do
				local isUid = type(record) == "table" and type(record.Uid) == "string"
				if isUid then
					isUid = not (skipPrefix and string.sub(record.Uid, 1, #prefix) == prefix)
				end
				if isUid then
					uids[record.Uid] = true
				end
			end
		end
	end

	return uids
end

local function isNightStillActive()
	if firstAreaUids == nil then
		return false
	end

	if state.IsNight() then
		return true
	end

	if firstAreaClearDeadline == math.huge then
		firstAreaClearDeadline = os.clock() + firstAreaWaitSeconds
	end

	return false
end

local function beginFirstAreaWindow()
	if firstAreaUids and firstAreaClearDeadline == math.huge then
		return
	end

	firstAreaUids = collectFirstAreaUids(true)
	firstAreaClearDeadline = math.huge
	table.clear(forcedStealQueue)
	table.clear(cancelledSteals)
	table.clear(priorityStealSet)
	table.clear(blockedEggUids)
	stealCurrentUid = nil
end

local function isFirstAreaCleared()
	if not firstAreaUids then
		return false
	end

	if os.clock() >= firstAreaClearDeadline then
		firstAreaUids = nil
		return false
	end

	local current = collectFirstAreaUids()
	if next(current) == nil then
		return true
	end

	local someStillThere = false
	local someNew = false

	for uid in pairs(current) do
		if firstAreaUids[uid] then
			someStillThere = true
		else
			someNew = true
		end
	end

	if not someStillThere then
		firstAreaUids = nil
		return false
	end

	return not someNew
end

local buildEggSnapshot
do
	local function getAssetInfo(category)
		local directory = modules.Assets and modules.Assets.Directory
		local assetEntry = type(directory) == "table" and directory[tostring(category)] or nil
		local rarity = type(assetEntry) == "table" and type(assetEntry.Rarity) == "table" and assetEntry.Rarity or nil
		local info = {}

		if rarity then
			rarity = tonumber(rarity.RarityNumber or rarity.Rank)
		end

		info.RarityNumber = rarity or 0
		info.EarningRate = type(assetEntry) == "table" and tonumber(assetEntry.EarningRate) or 0
		return info
	end

	local function mutationMultiplierFor(mutations)
		local mutationsModule = modules.Mutations

		if type(mutationsModule) == "table" and type(mutationsModule.EarningsFor) == "function" then
			local ok, result = pcall(mutationsModule.EarningsFor, type(mutations) == "table" and mutations or {})
			if ok and type(result) == "number" and result > 1 then
				return result
			end
		end

		if type(mutations) == "table" and #mutations > 0 then
			return 1.1
		end

		return 1
	end

	local function weightForScale(category, scale)
		local eggRecords = modules.EggRecords

		if type(eggRecords) == "table" and type(eggRecords.WeightKgForScale) == "function" then
			local ok, result = pcall(eggRecords.WeightKgForScale, category, scale)
			if ok and type(result) == "number" then
				return result
			end
		end

		return 0
	end

	buildEggSnapshot = function(includeCarried, includeForcedOnly)
		local records = nil
		local eggState = modules.EggState

		if type(eggState) == "table" and type(eggState.ReadFieldEggs) == "function" then
			local ok, result = pcall(eggState.ReadFieldEggs)
			if ok and type(result) == "table" and type(result.Records) == "table" and next(result.Records) ~= nil then
				records = result.Records
			end
		end

		if not records then
			local remote = networking:FindFirstChild("RF/EggWorld/AskFieldEggSnapshot")
			if remote and remote:IsA("RemoteFunction") then
				local ok, result = pcall(remote.InvokeServer, remote)
				records = ok and type(result) == "table" and result.Records or nil
			end
		end

		if not records and state.EspHelpers and type(state.EspHelpers.GetEggSnapshot) == "function" then
			local ok, cached = pcall(state.EspHelpers.GetEggSnapshot)
			if ok and type(cached) == "table" and next(cached) ~= nil then
				records = cached
			end
		end

		if type(records) ~= "table" then
			return {}
		end

		local snapshot = {}
		local activeUids = {}

		for _, record in pairs(records) do
			local uid = type(record) == "table" and record.Uid or nil

			if uid and record.State ~= "Claimed" then
				activeUids[uid] = true
			end

			local isCarriedByOther = record.State == "Carried"
				and includeForcedOnly == true
				and includeCarried ~= true
				and not (state.Steal.Carrying and uid == state.Steal.CarryUid)

			local isStealable
			if uid then
				isStealable = record.State == "Slot" or record.State == "Dropped" or isCarriedByOther
			else
				isStealable = uid
			end

			local forcedEntry = uid and forcedStealQueue[uid] or nil
			local isPriority = uid and priorityStealSet[uid] == true or false
			local areaIdStr = tostring(record.AreaId or "")
			local cleanAreaId = string.lower(string.gsub(areaIdStr, "%s+", ""))
			local matchesArea = targetAreas[areaIdStr] == true or targetAreas[cleanAreaId] == true
			local isIndexTarget = includeCarried ~= true and stealIndexEnabled and uid ~= nil and matchesArea and missingIndexEggs[tostring(record.AssetCategory)] or nil
			local isRiftTarget = includeCarried ~= true and state.Steal.RiftPriority == true and uid ~= nil and state.Steal.RiftNeeds[tostring(record.AssetCategory)] == true
			local passesAreaFilter = includeCarried == true
				or forcedEntry ~= nil
				or isPriority
				or isRiftTarget
				or matchesArea
			local isCancelled = includeCarried ~= true and forcedEntry == nil and cancelledSteals[uid] == true
			local isInFirstAreaWindow = firstAreaUids ~= nil and firstAreaUids[uid] == true

			isStealable = isStealable and typeof(record.BottomCFrame) == "CFrame"

			local isReady
			if isStealable then
				isReady = (blockedEggUids[uid] or 0) <= os.clock()
			else
				isReady = isStealable
			end

			if isReady and passesAreaFilter and not isCancelled and not isInFirstAreaWindow then
				local info = getAssetInfo(record.AssetCategory)
				local category = tostring(record.AssetCategory)
				local passesRarity = info.RarityNumber >= minRarityNumber
				local passesSpecific = next(targetEggCategories) == nil or targetEggCategories[category] == true
				local scale = tonumber(record.AssetScale) or 1
				local eggMutations = {}
				if type(record.Mutations) == "table" then
					for k, v in pairs(record.Mutations) do
						if type(v) == "string" and v ~= "" then
							table.insert(eggMutations, v)
						elseif v == true and type(k) == "string" and k ~= "" then
							table.insert(eggMutations, k)
						end
					end
				end
				if #eggMutations == 0 then
					if type(record.BaseMutation) == "string" and record.BaseMutation ~= "" then
						table.insert(eggMutations, record.BaseMutation)
					elseif type(record.Mutation) == "string" and record.Mutation ~= "" then
						table.insert(eggMutations, record.Mutation)
					end
				end
				local mutationMult = mutationMultiplierFor(eggMutations)
				local scaleFactor = scale > 5 and (scale / 5) ^ 1.2 * 19.637875755794113 or scale ^ 1.85
				local passesValue = minStealValue <= 0 or info.EarningRate * scaleFactor * mutationMult >= minStealValue
				local matchesFilters = passesRarity and passesSpecific and passesValue
				local riftOnly = isRiftTarget and not matchesFilters and not isPriority and forcedEntry == nil and isIndexTarget == nil
				local unsafeReason = includeCarried ~= true and state.SafeCarry.Unsafe({ Uid = uid, Category = category })

				local allowNormal = not state.Steal.RiftPriority and not stealIndexEnabled
				if unsafeReason then
					forcedStealQueue[uid] = nil
					priorityStealSet[uid] = nil
					state.SafeCarry.LastSkip = unsafeReason
				elseif includeCarried == true or forcedEntry or isPriority or isRiftTarget or isIndexTarget ~= nil or (allowNormal and matchesFilters) then
					table.insert(snapshot, {
						Uid = uid,
						Category = category,
						Scale = scale,
						State = record.State,
						Rarity = info.RarityNumber,
						Weight = weightForScale(record.AssetCategory, scale),
						Mutation = mutationMult,
						MutationName = eggMutations[1],
						Value = info.EarningRate * scaleFactor * mutationMult,
						CFrame = record.BottomCFrame,
						AreaId = tostring(record.AreaId),
						Rift = includeCarried ~= true and isRiftTarget,
						RiftOnly = includeCarried ~= true and riftOnly,
						Index = isIndexTarget,
						Forced = includeCarried ~= true and forcedEntry and forcedEntry.At or nil,
						Priority = includeCarried ~= true and isPriority,
					})
				end
			end
		end

		if next(activeUids) ~= nil then
			for uid in pairs(forcedStealQueue) do
				if not activeUids[uid] then
					forcedStealQueue[uid] = nil
				end
			end

			for uid in pairs(priorityStealSet) do
				if not activeUids[uid] then
					priorityStealSet[uid] = nil
				end
			end

			for uid in pairs(cancelledSteals) do
				if not activeUids[uid] then
					cancelledSteals[uid] = nil
				end
			end
		end

		table.sort(snapshot, function(a, b)
			if a.Forced ~= nil ~= b.Forced ~= nil then
				return a.Forced ~= nil
			end

			if a.Forced and b.Forced and a.Forced ~= b.Forced then
				return a.Forced < b.Forced
			end

			if a.Priority ~= b.Priority then
				return a.Priority == true
			end

			if a.RiftOnly ~= b.RiftOnly then
				return b.RiftOnly == true
			end

			if a.Index ~= nil ~= b.Index ~= nil then
				return a.Index ~= nil
			end

			if a.Index and b.Index and a.Index ~= b.Index then
				return a.Index > b.Index
			end

			if stealSort == stealSortOptions[2] and a.Weight ~= b.Weight then
				return a.Weight > b.Weight
			end

			if stealSort == stealSortOptions[3] and a.Mutation ~= b.Mutation then
				return a.Mutation > b.Mutation
			end

			if stealSort == stealSortOptions[4] and a.Value ~= b.Value then
				return a.Value > b.Value
			end

			if stealSort == stealSortOptions[5] and a.Value ~= b.Value then
				return a.Value < b.Value
			end

			if a.Rarity ~= b.Rarity then
				return a.Rarity > b.Rarity
			end

			if a.Value ~= b.Value then
				return a.Value > b.Value
			end

			return tostring(a.Uid) < tostring(b.Uid)
		end)

		return snapshot
	end
end

local driftThreshold = 6
local steerVelocity
local stopAllMotion
local cleanupFlight
local isRagdolled
local flyToPosition

do
	local activeTarget = nil
	local heartbeatConnection = nil

	steerVelocity = function(root, targetPosition, maxSpeed, deltaTime, tracker)
		local delta = targetPosition - root.Position
		local distance = delta.Magnitude
		local stepTime = math.max(deltaTime, 0.0041666666666666666)
		local direction = Vector3.zero

		if distance > 0.01 then
			direction = delta.Unit * math.min(maxSpeed, distance / stepTime)
		end

		local velocity = direction + Vector3.new(0, workspace.Gravity * stepTime * 0.5, 0)

		if distance > 2 then
			if not tracker.mark then
				tracker.mark = distance
				tracker.clock = 0
			end

			tracker.clock = tracker.clock + deltaTime

			if tracker.clock >= 0.4 then
				if tracker.mark - distance < maxSpeed * 0.1 then
					pcall(function()
						root.CFrame = root.CFrame + delta.Unit * math.min(distance, maxSpeed * stepTime)
					end)
				end

				tracker.mark = distance
				tracker.clock = 0
			end
		else
			tracker.mark = nil
		end

		pcall(function()
			root.AssemblyLinearVelocity = velocity
			root.AssemblyAngularVelocity = Vector3.zero
		end)

		return distance <= 0.5
	end

	stopAllMotion = function()
		local root = state.Root()

		if root then
			pcall(function()
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end)
		end
	end

	local presimulationConnection = nil
	local tracker = {}

	cleanupFlight = function()
		activeTarget = nil

		if heartbeatConnection then
			heartbeatConnection:Disconnect()
			heartbeatConnection = nil
		end

		if presimulationConnection then
			presimulationConnection:Disconnect()
			presimulationConnection = nil
		end
	end

	isRagdolled = function()
		local endTime = tonumber(localPlayer:GetAttribute("RagdollEndTime"))
		return endTime ~= nil and endTime > workspace:GetServerTimeNow()
	end

	local frozenFlag = false

	local function isFrozen()
		return frozenFlag == true
	end

	flyToPosition = function(targetPosition, freeze)
		activeTarget = targetPosition
		frozenFlag = freeze == true
		if heartbeatConnection or not targetPosition then
			return
		end
		tracker = {}

		heartbeatConnection = RunService.Heartbeat:Connect(function()
			if not activeTarget or not isFrozen() or isRagdolled() or state.AntiGuard.Busy then
				return
			end
			local root = state.Root()
			if not root then
				return
			end

			pcall(function()
				local rotation = root.CFrame.Rotation
				root.CFrame = CFrame.new(activeTarget) * rotation
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end)
		end)

		presimulationConnection = RunService.PreSimulation:Connect(function(deltaTime)
			if not activeTarget or isFrozen() or isRagdolled() or state.AntiGuard.Busy then
				return
			end
			local root = state.Root()

			if root then
				steerVelocity(root, activeTarget, 400, deltaTime, tracker)
			end
		end)
	end
end

registerCleanup(cleanupFlight)

local exitFlight
exitFlight = function()
	cleanupFlight()
	state.EndFlight()
	state.GodMode(false)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.PlatformStand = false
	end
end

local smartPromptRange = 20
local findSmartPrompt
local isEggSlotOccupied

do
	local function horizontalDistance(a, b)
		local bx = b.X
		return (Vector3.new(a.X, 0, a.Z) - Vector3.new(bx, 0, b.Z)).Magnitude
	end

	local function modelPivot(model)
		local ok, result = pcall(function()
			return model:GetPivot().Position
		end)
		return ok and result or nil
	end

	isEggSlotOccupied = function(promptPart, carryingUid, eggPosition)
		local position = eggPosition or promptPart.Position
		local ourDistance = horizontalDistance(position, promptPart.Position)
		local slotsContainer = workspace:FindFirstChild("AreaEggSlotsClient")

		if slotsContainer then
			for _, child in ipairs(slotsContainer:GetChildren()) do
				if child:IsA("Model") and child.Name ~= carryingUid then
					local pivot = modelPivot(child)
					if pivot and horizontalDistance(pivot, promptPart.Position) + 1.5 < ourDistance then
						return false
					end
				end
			end
		end

		for _, child in ipairs(workspace:GetChildren()) do
			if child:IsA("Model") and child.Name ~= carryingUid and #child.Name == 32 and child:FindFirstChild("Hitbox") then
				local pivot = modelPivot(child)
				if pivot and horizontalDistance(pivot, promptPart.Position) + 1.5 < ourDistance then
					return false
				end
			end
		end

		return true
	end

	findSmartPrompt = function(carryingUid, position, maxRange)
		local bestRange = maxRange or 20
		local bestPrompt = nil
		local bestPart = nil

		local function checkCandidate(prompt, part)
			if prompt and prompt:IsA("ProximityPrompt") and part and part:IsA("BasePart") then
				local distance = horizontalDistance(part.Position, position)
				if distance < bestRange then
					bestRange = distance
					bestPrompt = prompt
					bestPart = part
				end
			end
		end

		for _, child in ipairs(workspace:GetChildren()) do
			if child.Name == "SmartPromptPart" and child:IsA("BasePart") then
				local prompt = child:FindFirstChild("CarryAreaEgg") or child:FindFirstChildOfClass("ProximityPrompt")
				checkCandidate(prompt, child)
			end
		end

		if not bestPrompt then
			local slotsContainer = workspace:FindFirstChild("AreaEggSlotsClient")
			if slotsContainer then
				for _, child in ipairs(slotsContainer:GetChildren()) do
					local prompt = child:FindFirstChildWhichIsA("ProximityPrompt", true)
					if prompt then
						local part = (prompt.Parent and prompt.Parent:IsA("BasePart") and prompt.Parent) or child:FindFirstChildWhichIsA("BasePart", true)
						checkCandidate(prompt, part)
					end
				end
			end
		end

		if not bestPrompt and type(carryingUid) == "string" then
			local eggModel = workspace:FindFirstChild(carryingUid)
			if eggModel then
				local prompt = eggModel:FindFirstChildWhichIsA("ProximityPrompt", true)
				if prompt then
					local part = (prompt.Parent and prompt.Parent:IsA("BasePart") and prompt.Parent) or eggModel:FindFirstChildWhichIsA("BasePart", true)
					checkCandidate(prompt, part)
				end
			end
		end

		if not bestPrompt or not bestPart then
			return nil
		end

		if type(carryingUid) == "string" and bestRange > 6 and not isEggSlotOccupied(bestPart, carryingUid, position) then
			return nil
		end

		return bestPrompt, bestPart
	end
end

local wrongEgg
wrongEgg = function(carryUid)
	local steal = state.Steal
	if type(carryUid) ~= "string" or not steal.Carrying or steal.CarryUid == carryUid then
		return false
	end

	local eggState = modules.EggState
	if type(eggState) == "table" and type(eggState.DropFieldEgg) == "function" then
		pcall(eggState.DropFieldEgg, "PlayerRequest")
	end

	local elapsed = 0
	while steal.Carrying and elapsed < 1 do
		elapsed = elapsed + RunService.Heartbeat:Wait()
	end

	steal.Carrying = false
	steal.CarryUid = carryUid
	return true
end

local requestCarryEgg
requestCarryEgg = function(uid)
	local eggState = modules.EggState
	if type(uid) == "string" and type(eggState) == "table" and type(eggState.CarryFieldEgg) == "function" then
		pcall(eggState.CarryFieldEgg, uid)
	end
end

local verifyCarry
do
	local function currentCarryUid()
		local uid = state.Steal.CarryUid
		return type(uid) == "string" and uid or nil
	end

	local function isSameCarry(expectedUid)
		local current = currentCarryUid()
		if not current or type(expectedUid) ~= "string" then
			return true
		end
		return current == expectedUid
	end

	local function stillValidInSnapshot(expectedUid)
		if type(expectedUid) ~= "string" then
			return false
		end
		local snapshot = buildEggSnapshot(false, true)
		if #snapshot == 0 then
			return true
		end

		for _, entry in ipairs(snapshot) do
			if entry.Uid == expectedUid then
				return true
			end
		end

		return false
	end

	local function dropCurrentCarry(cancelledGen)
		local eggState = modules.EggState
		if type(eggState) == "table" and type(eggState.DropFieldEgg) == "function" then
			pcall(eggState.DropFieldEgg, "PlayerRequest")
		end

		local elapsed = 0
		while state.Steal.Carrying and elapsed < 1 and not isStaleGeneration(cancelledGen) do
			elapsed = elapsed + RunService.Heartbeat:Wait()
		end
	end

	verifyCarry = function(expectedUid, generation)
		local waitTime = 0
		while not state.Steal.Carrying and waitTime < 0.6 and not isStaleGeneration(generation) do
			waitTime = waitTime + RunService.Heartbeat:Wait()
		end

		if not state.Steal.Carrying then
			stealStatusText = "The egg never reached the hand"
			return false
		end

		if isSameCarry(expectedUid) then
			return true
		end

		local current = currentCarryUid()
		if stillValidInSnapshot(current) then
			stealStatusText = "Holding another egg that still matches, delivering it"
			return true
		end

		stealStatusText = "Wrong egg in hand, dropping it"
		dropCurrentCarry(generation)
		return false
	end
end

local pickUpEgg
pickUpEgg = function(entry, generation)
	local eggState = modules.EggState
	local position = typeof(entry.CFrame) == "CFrame" and entry.CFrame.Position or nil
	if not position then
		return false
	end

	pcall(function()
		localPlayer:RequestStreamAroundAsync(position)
	end)

	local elapsed = 0
	local promptClock = math.huge

	while elapsed < 2.5 do
		if isStaleGeneration(generation) then
			return false
		end

		if state.Steal.Carrying and not wrongEgg(entry.Uid) then
			return true
		end

		if promptClock >= 0.08 then
			local prompt = findSmartPrompt(entry.Uid, position, 25)

			if prompt then
				pcall(function()
					prompt.HoldDuration = 0
					prompt.RequiresLineOfSight = false
					prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance or 10, 30)
				end)

				if typeof(fireproximityprompt) == "function" then
					pcall(fireproximityprompt, prompt)
				end
			end

			if type(eggState) == "table" and type(eggState.CarryFieldEgg) == "function" then
				pcall(eggState.CarryFieldEgg, entry.Uid)
			end

			promptClock = 0
		end

		local delta = RunService.Heartbeat:Wait()
		elapsed = elapsed + delta
		promptClock = promptClock + delta
	end

	return state.Steal.Carrying == true
end

local isRagdolledDeep
do
	local ragdollModule = requireModule(function()
		return ReplicatedStorage.Shared.Modules.Ragdoll
	end)

	isRagdolledDeep = function()
		local character = localPlayer.Character

		if type(ragdollModule) == "table" and type(ragdollModule.IsRagdolled) == "function" then
			local ok, result = pcall(ragdollModule.IsRagdolled, character)
			if ok and result == true then
				return true
			end
		end

		local endTime = tonumber(localPlayer:GetAttribute("RagdollEndTime"))
		if endTime and endTime > workspace:GetServerTimeNow() then
			return true
		end

		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local currentState = humanoid:GetState()
			return currentState == Enum.HumanoidStateType.Physics
				or currentState == Enum.HumanoidStateType.Ragdoll
				or currentState == Enum.HumanoidStateType.FallingDown
		end

		return false
	end
end

local findNearestEntry
local flyToPositionRollback
local stealHome
local isGuardSleeping
local getGuardApproachPoint
local getGuardModel
local tryPickupHere

do
	local function verifyEggStillFree(expectedUid, generation)
		if state.Steal.Carrying then
			return true
		end

		local remote = networking:FindFirstChild("RF/EggWorld/AskFieldEggSnapshot")
		if not remote or not remote:IsA("RemoteFunction") then
			return false
		end

		local elapsed = 0
		while elapsed < 1 do
			if isStaleGeneration(generation) or state.Steal.Carrying then
				return state.Steal.Carrying == true
			end

			local ok, result = pcall(remote.InvokeServer, remote)
			ok = ok and type(result) == "table" and result.Records or nil

			if type(ok) == "table" then
				local stillFree = false

				for _, record in pairs(ok) do
					if type(record) == "table" and record.Uid == expectedUid and (record.State == "Slot" or record.State == "Dropped") then
						stillFree = true
						break
					end
				end

				if not stillFree then
					return false
				end
			end

			elapsed = elapsed + task.wait(0.3)
		end

		return true
	end
	state.VerifyEggStillFree = verifyEggStillFree

	local function distanceToEntry(entry)
		local root = state.Root()
		local position = typeof(entry.CFrame) == "CFrame" and entry.CFrame.Position or nil
		if not root or not position then
			return math.huge
		end
		return (root.Position - position).Magnitude
	end

	findNearestEntry = function(entries)
		local bestDistance = math.huge
		local bestEntry = nil

		for _, entry in ipairs(entries) do
			local distance = distanceToEntry(entry)
			if distance < bestDistance then
				bestDistance = distance
				bestEntry = entry
			end
		end

		return bestEntry, bestDistance
	end

	local flyToTimeout = 45
	local teleportRange = 90
	local antiGuardRagdollTimeout = 6

	flyToPositionRollback = function(targetPosition, generation, requireCarrying, speed, noFallback, busyCheck)
		cleanupFlight()
		local root = state.Root()
		if not root then
			return false
		end

		pcall(function()
			localPlayer:RequestStreamAroundAsync(targetPosition)
		end)

		local character = localPlayer.Character
		local lastPosition = root.Position
		local tracker = {}
		local lastSeenPosition = nil
		local outcome = nil
		local failureReason = nil
		local elapsed = 0
		local maxFlightTime = math.max(60, (targetPosition - lastPosition).Magnitude / 40 + 20)

		local function isNotCancelled()
			if noFallback ~= nil then
				return true
			end
			return true
		end

		local function stepFlight(deltaTime)
			elapsed = elapsed + deltaTime
			if isStaleGeneration(generation) then
				outcome = false
				return nil
			end

			if requireCarrying and not state.Steal.Carrying then
				outcome = false
				failureReason = "dropped"
				return nil
			end

			if busyCheck then
				local reason = busyCheck()

				if reason then
					outcome = false
					failureReason = reason
					return nil
				end
			end

			local currentRoot = state.Root()

			if not currentRoot or elapsed >= maxFlightTime or localPlayer.Character ~= character then
				outcome = false
				failureReason = "respawned"
				return nil
			end

			return currentRoot
		end

		local heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
			if outcome ~= nil or isNotCancelled() or state.AntiGuard.Busy then
				return
			end
			local currentRoot = stepFlight(deltaTime)
			if not currentRoot then
				return
			end

			if driftThreshold < (currentRoot.Position - lastPosition).Magnitude then
				if noFallback then
					outcome = false
					failureReason = "displaced"
					return
				end

				lastPosition = currentRoot.Position
			end

			local activeSpeed = (speed or 400) * (os.clock() < (state.SafeCarry.SlowUntil or 0) and state.SafeCarry.SlowFactor or 1)
			local paceSpeed

			if state.SafeCarry.Enabled and state.SafeCarry.Pace then
				paceSpeed = math.min(activeSpeed, state.SafeCarry.Pace())
			else
				paceSpeed = activeSpeed
			end

			local delta = targetPosition - lastPosition
			local step = paceSpeed * deltaTime
			local arrived = delta.Magnitude <= math.max(step, 0.05)
			lastPosition = arrived and targetPosition or lastPosition + delta.Unit * step
			local horizontal = Vector3.new(delta.X, 0, delta.Z)
			local lookCframe = horizontal.Magnitude > 0.05 and CFrame.lookAt(Vector3.zero, horizontal.Unit) or currentRoot.CFrame.Rotation

			pcall(function()
				currentRoot.CFrame = CFrame.new(lastPosition) * lookCframe
				currentRoot.AssemblyLinearVelocity = Vector3.zero
				currentRoot.AssemblyAngularVelocity = Vector3.zero
			end)

			if arrived then
				outcome = true
			end
		end)

		local presimulationConnection = RunService.PreSimulation:Connect(function(deltaTime)
			if outcome ~= nil or not isNotCancelled() or state.AntiGuard.Busy then
				return
			end
			local currentRoot = stepFlight(deltaTime)
			if not currentRoot then
				return
			end
			local activeSpeed = (speed or 400) * (os.clock() < (state.SafeCarry.SlowUntil or 0) and state.SafeCarry.SlowFactor or 1)
			local paceSpeed

			if state.SafeCarry.Enabled and state.SafeCarry.Pace then
				paceSpeed = math.min(activeSpeed, state.SafeCarry.Pace())
			else
				paceSpeed = activeSpeed
			end

			if noFallback and lastSeenPosition and (currentRoot.Position - lastSeenPosition).Magnitude > driftThreshold + paceSpeed * deltaTime then
				outcome = false
				failureReason = "displaced"
				return
			end

			if steerVelocity(currentRoot, targetPosition, paceSpeed, deltaTime, tracker) then
				outcome = true
			end

			lastSeenPosition = currentRoot.Position
			lastPosition = currentRoot.Position
		end)

		while outcome == nil do
			RunService.Heartbeat:Wait()
		end

		heartbeatConnection:Disconnect()
		presimulationConnection:Disconnect()

		if isNotCancelled() and not outcome then
			stopAllMotion()
		end

		if outcome then
			flyToPosition(targetPosition, noFallback ~= nil)
		end

		return outcome, failureReason
	end

	local homePathCandidates = {
		{
			Path = { "GearGiver_Slap", "Podium" },
			Offset = Vector3.new(-16.415, 21.072, -6.106),
		},
		{
			Path = { "World", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" },
			Offset = Vector3.new(-26.776, 1.75, 18.665),
		},
		{
			Path = { "__OBJECTS", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" },
			Offset = Vector3.new(-26.776, 1.75, 18.665),
		},
	}

	stealHome = function()
		for _, candidate in ipairs(homePathCandidates) do
			local current = workspace

			for _, segment in ipairs(candidate.Path) do
				current = current and current:FindFirstChild(segment) or nil
			end

			if current and current:IsA("BasePart") then
				return current.CFrame:PointToWorldSpace(candidate.Offset)
			end
		end

		return Vector3.new(528.7, 70.57, -364.11)
	end

	state.StealHome = stealHome

	state.InsideBase = function(position)
		if not position then
			position = state.Root()
			position = position and position.Position
		end

		if position == nil then
			return false
		end
		local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
		local areas = world and world:FindFirstChild("Areas")
		areas = areas and areas:FindFirstChild("SeparationLine")
		return position.X < (areas and areas:IsA("BasePart") and areas.Position.X or 552)
	end

	local function moveRootToPosition(position)
		if state.AntiGuard.Busy then
			return false
		end
		local character = localPlayer.Character
		local root = state.Root()
		if not character or not root then
			return false
		end
		local rotation = root.CFrame.Rotation
		local targetCframe = CFrame.new(position) * rotation

		pcall(function()
			character:PivotTo(targetCframe)
		end)

		if (root.Position - position).Magnitude > 3 then
			pcall(function()
				root.CFrame = targetCframe
			end)
		end

		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:IsA("BasePart") then
				pcall(function()
					descendant.AssemblyLinearVelocity = Vector3.zero
					descendant.AssemblyAngularVelocity = Vector3.zero
				end)
			end
		end

		return true
	end

	local function snapBodyPartsToRoot(targetPosition)
		if state.AntiGuard.Busy then
			return
		end
		local character = localPlayer.Character
		local root = state.Root()
		if not character or not root or not targetPosition then
			return
		end

		if (root.Position - targetPosition).Magnitude > 6 then
			moveRootToPosition(targetPosition)
			return
		end

		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant ~= root and (descendant.Position - root.Position).Magnitude > 12 then
				pcall(function()
					descendant.CFrame = root.CFrame
					descendant.AssemblyLinearVelocity = Vector3.zero
				end)
			end
		end
	end

	local function waitForStandUp(generation, targetPosition)
		local elapsed = 0

		while true do
			if not (elapsed < antiGuardRagdollTimeout) then
				return not isStaleGeneration(generation)
			else
				if isStaleGeneration(generation) then
					break
				end
				local character = localPlayer.Character
				local ragdolled = isRagdolledDeep()

				if not ragdolled and character then
					for _, descendant in ipairs(character:GetDescendants()) do
						if descendant:IsA("Constraint") and string.find(descendant.Name, "RagdollConstraint", 1, true) then
							ragdolled = true
							break
						end
					end
				end

				if not ragdolled then
					return not isStaleGeneration(generation)
				end
				snapBodyPartsToRoot(targetPosition)
				elapsed = elapsed + RunService.Heartbeat:Wait()
			end
		end

		return false
	end

	getGuardModel = function(entry)
		local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
		world = world and world:FindFirstChild("Areas")
		world = world and world:FindFirstChild("GuardAreas")
		if not world or not entry or not entry.AreaId then
			return nil
		end
		local rawAreaId = tostring(entry.AreaId)
		local areaFolder = world:FindFirstChild(rawAreaId)
			or world:FindFirstChild(string.gsub(rawAreaId, "%s+", ""))
			or world:FindFirstChild(string.gsub(rawAreaId, "%s+", "_"))
		if not areaFolder then
			local cleanTarget = string.lower(string.gsub(rawAreaId, "[%s_]+", ""))
			for _, child in ipairs(world:GetChildren()) do
				if string.lower(string.gsub(child.Name, "[%s_]+", "")) == cleanTarget then
					areaFolder = child
					break
				end
			end
		end
		return areaFolder and areaFolder:FindFirstChild("Guard") or nil
	end

	local guardApproachRange = 3

	isGuardSleeping = function(entry)
		local guard = getGuardModel(entry)
		return guard ~= nil and guard:GetAttribute("GuardState") == "Sleeping"
	end

	getGuardApproachPoint = function(entry)
		local guard = getGuardModel(entry)
		local position = typeof(entry.CFrame) == "CFrame" and entry.CFrame.Position or nil
		if not guard or not position then
			return nil, nil
		end

		local ok, guardPosition = pcall(function()
			return guard:GetPivot().Position
		end)

		if not ok then
			return nil, nil
		end
		local direction = Vector3.new(position.X - guardPosition.X, 0, position.Z - guardPosition.Z)
		if direction.Magnitude < 0.1 then
			return nil, nil
		end
		local approachPoint = guardPosition + direction.Unit * guardApproachRange
		return Vector3.new(approachPoint.X, position.Y + 3, approachPoint.Z), guardPosition
	end

	local function armRagdollTrap(generation, destination)
		local trap = { Landed = false, Destination = destination }
		local antiGuard = state.AntiGuard
		antiGuard.HitArms = antiGuard.HitArms + 1
		state.AntiGuard.HitArmedAt = os.clock()

		trap.Link = localPlayer:GetAttributeChangedSignal("RagdollEndTime"):Connect(function()
			if trap.Landed or isStaleGeneration(generation) then
				return
			end
			local endTime = tonumber(localPlayer:GetAttribute("RagdollEndTime"))
			if not endTime or endTime <= workspace:GetServerTimeNow() then
				return
			end
			local root = state.Root()
			if not root then
				return
			end
			trap.Landed = true
			cleanupFlight()
			state.SafeCarry.JumpDistance = (trap.Destination - root.Position).Magnitude
			state.SafeCarry.JumpAt = os.clock()

			pcall(function()
				root.CFrame = CFrame.new(trap.Destination)
				root.AssemblyLinearVelocity = Vector3.zero
			end)
		end)

		trap.Stop = function()
			if trap.Link then
				trap.Link:Disconnect()
				trap.Link = nil
				state.AntiGuard.HitArms = math.max(0, state.AntiGuard.HitArms - 1)
			end
		end

		return trap
	end
	state.ArmRagdollTrap = armRagdollTrap

	local function waitForRagdollLand(generation, trap, stepCallback)
		local humanoid = localPlayer.Character
		humanoid = humanoid and humanoid:FindFirstChildOfClass("Humanoid")

		if humanoid then
			humanoid.PlatformStand = false
		end

		local elapsed = 0
		local noCarrySince = nil

		while not trap.Landed and elapsed < flyToTimeout do
			if isStaleGeneration(generation) then
				break
			end

			if stepCallback then
				stepCallback(trap)
			end

			if not state.Steal.Carrying then
				noCarrySince = noCarrySince or elapsed
				if elapsed - noCarrySince > 1 then
					break
				end
			end

			elapsed = elapsed + RunService.Heartbeat:Wait()
		end

		trap.Stop()
		return trap.Landed
	end

	local pickupRangeHere = 20

	tryPickupHere = function(entry, generation, timeout, snapPosition)
		local position = typeof(entry.CFrame) == "CFrame" and entry.CFrame.Position or nil
		if not position then
			return false
		end

		pcall(function()
			localPlayer:RequestStreamAroundAsync(position)
		end)

		local maxWait = math.max(timeout or 0.8, 2.0)
		local elapsed = 0
		local promptClock = math.huge

		while elapsed < maxWait do
			if isStaleGeneration(generation) then
				return false
			end

			if state.Steal.Carrying and not wrongEgg(entry.Uid) then
				return true
			end

			if promptClock >= 0.08 then
				local prompt = findSmartPrompt(entry.Uid, position, 25)

				if prompt then
					pcall(function()
						prompt.HoldDuration = 0
						prompt.RequiresLineOfSight = false
						prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance or 10, 30)
					end)

					if typeof(fireproximityprompt) == "function" then
						pcall(fireproximityprompt, prompt)
					end
				end

				requestCarryEgg(entry.Uid)
				promptClock = 0
			end

			if snapPosition then
				snapBodyPartsToRoot(snapPosition)
			end

			local delta = RunService.Heartbeat:Wait()
			elapsed = elapsed + delta
			promptClock = promptClock + delta
		end

		return state.Steal.Carrying == true
	end
	state.WaitForRagdollLand = waitForRagdollLand

	local function jumpToAndPickup(entry, generation, useTeleport, teleportEntry)
		local position = typeof(entry.CFrame) == "CFrame" and entry.CFrame.Position or nil
		if not position then
			return false
		end
		local targetPosition = position + Vector3.new(0, 3, 0)
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if humanoid and character:FindFirstChildWhichIsA("Tool") then
			pcall(function()
				humanoid:UnequipTools()
			end)
		end

		if useTeleport then
			flyToPosition(targetPosition, true)
			stealStatusText = "Waiting to stand up"

			if not waitForStandUp(generation, targetPosition) then
				return false
			end

			if state.SafeCarry.Enabled and teleportEntry == nil and state.SafeCarry.Settle then
				if not state.SafeCarry.Settle(generation, entry) then
					return false
				end
			end
		else
			stealStatusText = "Jumping to the egg"
			local root = state.Root()

			if root and (targetPosition - root.Position).Magnitude <= teleportRange then
				pcall(function()
					local rotation = root.CFrame.Rotation
					root.CFrame = CFrame.new(targetPosition) * rotation
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
				end)
			elseif not flyToPositionRollback(targetPosition, generation, nil, 400) then
				return false
			end
		end

		if isStaleGeneration(generation) then
			return false
		end
		local hasTrap = teleportEntry and typeof(teleportEntry.CFrame) == "CFrame"
		local trap = nil

		if hasTrap then
			trap = armRagdollTrap(generation, teleportEntry.CFrame.Position + Vector3.new(0, 3, 0))
		end

		local starterPrefix = "FirstAreaEgg_" .. tostring(localPlayer.UserId)
		local starterSlot = type(entry.Uid) == "string" and string.sub(entry.Uid, 1, #starterPrefix) == starterPrefix
			and string.match(entry.Uid, "_([%w ]+:Slot_%d+)$") or nil
		teleportEntry = teleportEntry and starterSlot
		local carried = false

		if teleportEntry then
			local eggState = modules.EggState

			if type(eggState) == "table" and type(eggState.CarryFieldEgg) == "function" then
				stealStatusText = "Taking the starter egg"

				task.spawn(function()
					pcall(eggState.CarryFieldEgg, entry.Uid, starterSlot)
				end)

				local waitTime = 0
				while not state.Steal.Carrying and waitTime < 0.8 do
					if isStaleGeneration(generation) then
						return false
					end
					waitTime = waitTime + RunService.Heartbeat:Wait()
				end

				carried = state.Steal.Carrying == true
			end
		end

		if not carried then
			stealStatusText = "Taking the egg"
			carried = pickUpEgg(entry, generation)

			if not carried and not isStaleGeneration(generation) then
				flyToPositionRollback(targetPosition, generation, nil, 400)
				carried = pickUpEgg(entry, generation)
			end
		end

		if not carried and not verifyEggStillFree(entry.Uid, generation) then
			if trap then
				trap.Stop()
			end

			blockedEggUids[entry.Uid] = os.clock() + blockedEggDuration
			stealStatusText = "That egg would not come free"
			return false
		end

		if trap then
			local strikeRemote = networking:FindFirstChild("RE/GuardPatrol/ForestStrike")
			local guard = getGuardModel(entry) or getGuardModel({ AreaId = "Forest" })
			local guardRoot = guard and guard:FindFirstChild("HumanoidRootPart")

			if strikeRemote and strikeRemote:IsA("RemoteEvent") and guardRoot then
				stealStatusText = "Calling the guard strike"

				pcall(function()
					strikeRemote:FireServer({ EggUid = entry.Uid, GuardCFrame = guardRoot.CFrame })
				end)
			end
		end

		state.Steal.LastFinishedAt = os.clock()
		return true, trap
	end
	state.JumpToAndPickup = jumpToAndPickup
end

local huge2 = math.huge

local function findNearestCarryPrompt(position, maxRange, carryingUid)
	local bestPrompt = nil
	local bestPart = nil

	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "SmartPromptPart" and child:IsA("BasePart") then
			local prompt = child:FindFirstChild("CarryAreaEgg")

			if prompt and prompt:IsA("ProximityPrompt") then
				local distance = (child.Position - position).Magnitude

				if distance < maxRange then
					maxRange = distance
					bestPrompt = prompt
					bestPart = child
				end
			end
		end
	end

	if bestPrompt and bestPart and type(carryingUid) == "string" and not isEggSlotOccupied(bestPart, carryingUid, position) then
		return nil
	end
	return bestPrompt, bestPart
end

local function findEggSlotModelPosition(uid)
	local container = workspace:FindFirstChild("AreaEggSlotsClient")
	local model = workspace:FindFirstChild(uid) or (container and container:FindFirstChild(uid))
	if not model then
		return nil
	end

	local ok, result = pcall(function()
		return model:GetPivot().Position
	end)

	return ok and result or nil
end

local function queryFieldSnapshot(uid)
	local remote = networking:FindFirstChild("RF/EggWorld/AskFieldEggSnapshot")
	if not remote or not remote:IsA("RemoteFunction") then
		return nil
	end
	local ok, result = pcall(remote.InvokeServer, remote)
	local records = ok and type(result) == "table" and result.Records or nil
	if type(records) ~= "table" then
		return nil
	end

	for _, record in pairs(records) do
		if type(record) == "table" and record.Uid == uid and typeof(record.BottomCFrame) == "CFrame" then
			return record.BottomCFrame.Position, true
		end
	end

	return nil, true
end

local function isEggHeldByOtherPlayer(uid)
	local eggModel = workspace:FindFirstChild(uid)
	if not eggModel then
		return false
	end

	for _, descendant in ipairs(eggModel:GetDescendants()) do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") or descendant:IsA("RigidConstraint") then
			local ok, partA, partB = pcall(function()
				return descendant.Part0, descendant.Part1
			end)

			if ok then
				for _, part in ipairs({ partA, partB }) do
					if typeof(part) == "Instance" and not part:IsDescendantOf(eggModel) then
						local model = part:FindFirstAncestorOfClass("Model")
						if model and model ~= localPlayer.Character and Players:GetPlayerFromCharacter(model) then
							return true
						end
					end
				end
			end
		end
	end

	return false
end

local function followCarriedEgg(generation, forcedUid)
	local currentState = 1
	local genSnapshot, carryUid, targetPosition, velocityEstimate, followConnection, elapsed, missCount, queryClock, lastPosition, lastPositionAt, otherHolderTime, promptClock, pickSuccess, rootSnapshot, eggPosition, queryPosition, queryFound, timestamp, shouldComputeVelocity, newVelocity, shouldFirePrompt, prompt

	while true do
		if currentState == 1 then
			genSnapshot = generation
			carryUid = forcedUid
			if carryUid then
				currentState = 3
			else
				currentState = 2
			end
		elseif currentState == 2 then
			carryUid = state.Steal.CarryUid
			currentState = 3
		elseif currentState == 3 then
			if type(carryUid) ~= "string" then
				currentState = 50
			else
				currentState = 4
			end
		elseif currentState == 4 then
			cleanupFlight()
			stealStatusText = "Following the egg"
			targetPosition = nil
			velocityEstimate = Vector3.zero

			followConnection = RunService.PreSimulation:Connect(function(deltaTime)
				local root = state.Root()
				if not root or not targetPosition or state.Steal.Carrying or isStaleGeneration(genSnapshot) then
					return
				end

				if isRagdolled() then
					if not state.SafeCarry.Enabled and (root.Position - targetPosition).Magnitude > 2 then
						moveRootToPosition(targetPosition)
					end
					return
				end

				local stepTime = math.max(deltaTime, 0.0041666666666666666)
				local desired = velocityEstimate + (targetPosition - root.Position) / math.max(0.08, stepTime)
				local maxAllowed = state.SafeCarry.Enabled and state.SafeCarry.Pace() or flySpeed + velocityEstimate.Magnitude

				if desired.Magnitude > maxAllowed then
					desired = desired.Unit * maxAllowed
				end

				local finalVelocity = desired + Vector3.new(0, workspace.Gravity * stepTime * 0.5, 0)

				pcall(function()
					root.AssemblyLinearVelocity = finalVelocity
					root.AssemblyAngularVelocity = Vector3.zero
				end)
			end)

			elapsed = 0
			missCount = 0
			queryClock = math.huge
			lastPosition = nil
			lastPositionAt = nil
			otherHolderTime = 0
			promptClock = math.huge
			currentState = 5
		elseif currentState == 5 then
			pickSuccess = false
			if not (elapsed < huge2) then
				currentState = 47
			else
				currentState = 6
			end
		elseif currentState == 6 then
			if isStaleGeneration(genSnapshot) then
				currentState = 47
			else
				currentState = 7
			end
		elseif currentState == 7 then
			if state.Steal.Carrying then
				currentState = 8
			else
				currentState = 11
			end
		elseif currentState == 8 then
			if state.Steal.WrongEgg(carryUid) then
				currentState = 10
			else
				currentState = 9
			end
		elseif currentState == 9 then
			pickSuccess = true
			currentState = 47
		elseif currentState == 10 then
			stealStatusText = "Picked up the wrong egg, dropped it"
			currentState = 11
		elseif currentState == 11 then
			rootSnapshot = state.Root()
			if not rootSnapshot then
				currentState = 47
			else
				currentState = 12
			end
		elseif currentState == 12 then
			eggPosition = findEggSlotModelPosition(carryUid)
			if eggPosition then
				currentState = 21
			else
				currentState = 13
			end
		elseif currentState == 13 then
			if queryClock >= 0.5 then
				currentState = 14
			else
				currentState = 22
			end
		elseif currentState == 14 then
			queryPosition, queryFound = queryFieldSnapshot(carryUid)
			if queryPosition then
				currentState = 20
			else
				currentState = 15
			end
		elseif currentState == 15 then
			queryClock = 0
			if queryFound then
				currentState = 17
			else
				currentState = 16
			end
		elseif currentState == 16 then
			eggPosition = queryPosition
			currentState = 22
		elseif currentState == 17 then
			missCount = missCount + 1
			if not (missCount >= 4) then
				currentState = 19
			else
				currentState = 18
			end
		elseif currentState == 18 then
			stealStatusText = "The egg is gone"
			currentState = 47
		elseif currentState == 19 then
			eggPosition = queryPosition
			currentState = 22
		elseif currentState == 20 then
			missCount = 0
			queryClock = 0
			eggPosition = queryPosition
			currentState = 22
		elseif currentState == 21 then
			missCount = 0
			currentState = 22
		elseif currentState == 22 then
			if eggPosition then
				currentState = 23
			else
				currentState = 32
			end
		elseif currentState == 23 then
			timestamp = os.clock()
			if lastPosition then
				currentState = 25
			else
				currentState = 24
			end
		elseif currentState == 24 then
			shouldComputeVelocity = lastPosition
			currentState = 26
		elseif currentState == 25 then
			shouldComputeVelocity = lastPositionAt
			currentState = 26
		elseif currentState == 26 then
			if shouldComputeVelocity then
				currentState = 27
			else
				currentState = 28
			end
		elseif currentState == 27 then
			shouldComputeVelocity = timestamp > lastPositionAt
			currentState = 28
		elseif currentState == 28 then
			if shouldComputeVelocity then
				currentState = 29
			else
				currentState = 31
			end
		elseif currentState == 29 then
			newVelocity = (eggPosition - lastPosition) / math.max(timestamp - lastPositionAt, 0.0041666666666666666)
			if not (newVelocity.Magnitude < 3000) then
				currentState = 31
			else
				currentState = 30
			end
		elseif currentState == 30 then
			velocityEstimate = velocityEstimate:Lerp(newVelocity, 0.3)
			currentState = 31
		elseif currentState == 31 then
			targetPosition = eggPosition + Vector3.new(0, 3, 0)
			lastPosition = eggPosition
			lastPositionAt = timestamp
			currentState = 32
		elseif currentState == 32 then
			if not (otherHolderTime >= 0.4) then
				currentState = 36
			else
				currentState = 33
			end
		elseif currentState == 33 then
			if isEggHeldByOtherPlayer(carryUid) then
				currentState = 35
			else
				currentState = 34
			end
		elseif currentState == 34 then
			stealStatusText = "Egg dropped, taking it back"
			otherHolderTime = 0
			currentState = 36
		elseif currentState == 35 then
			stealStatusText = "Another player has the egg, following it until it drops"
			otherHolderTime = 0
			currentState = 36
		elseif currentState == 36 then
			if targetPosition then
				currentState = 38
			else
				currentState = 37
			end
		elseif currentState == 37 then
			shouldFirePrompt = targetPosition
			currentState = 39
		elseif currentState == 38 then
			shouldFirePrompt = (targetPosition - rootSnapshot.Position).Magnitude <= (pickupRangeHere or 20)
			currentState = 39
		elseif currentState == 39 then
			if shouldFirePrompt then
				currentState = 40
			else
				currentState = 41
			end
		elseif currentState == 40 then
			shouldFirePrompt = promptClock >= 0.1
			currentState = 41
		elseif currentState == 41 then
			if shouldFirePrompt then
				currentState = 42
			else
				currentState = 46
			end
		elseif currentState == 42 then
			prompt = findNearestCarryPrompt(targetPosition - Vector3.new(0, 3, 0), 6, carryUid)
			if prompt then
				currentState = 44
			else
				currentState = 43
			end
		elseif currentState == 43 then
			task.spawn(requestCarryEgg, carryUid)
			promptClock = 0
			currentState = 46
		elseif currentState == 44 then
			pcall(function()
				prompt.HoldDuration = 0
			end)
			promptClock = 0
			if typeof(fireproximityprompt) ~= "function" then
				currentState = 46
			else
				currentState = 45
			end
		elseif currentState == 45 then
			pcall(fireproximityprompt, prompt)
			currentState = 46
		elseif currentState == 46 then
			local delta = RunService.Heartbeat:Wait()
			elapsed = elapsed + delta
			promptClock = promptClock + delta
			queryClock = queryClock + delta
			otherHolderTime = otherHolderTime + delta
			currentState = 5
		elseif currentState == 47 then
			followConnection:Disconnect()
			stopAllMotion()
			if pickSuccess then
				currentState = 49
			else
				currentState = 48
			end
		elseif currentState == 48 then
			pickSuccess = state.Steal.Carrying == true
			currentState = 49
		elseif currentState == 49 then
			return pickSuccess
		elseif currentState == 50 then
			return false
		end
	end
end

local function flyAndSteal(entry, generation)
	local position = typeof(entry.CFrame) == "CFrame" and entry.CFrame.Position or nil
	if not position then
		return false
	end

	if state.InsideBase() and not state.InsideBase(position) then
		local home = stealHome()

		if home then
			stealStatusText = "Leaving the base through the safe zone"
			if not flyToPositionRollback(home + Vector3.new(0, 3, 0), generation, nil, 400) then
				return false
			end
		end
	end

	stealStatusText = "Flying to the egg"
	if not flyToPositionRollback(position + Vector3.new(0, 3, 0), generation, nil, 400) then
		return false
	end
	stealStatusText = "Taking the egg"
	local picked = tryPickupHere(entry, generation, 0.6, nil)

	if not picked and not isStaleGeneration(generation) then
		picked = pickUpEgg(entry, generation)
	end

	if not picked and not (state.VerifyEggStillFree and state.VerifyEggStillFree(entry.Uid, generation)) then
		blockedEggUids[entry.Uid] = os.clock() + blockedEggDuration
		return false
	end
	state.Steal.LastFinishedAt = os.clock()
	return true
end

local carryState = { Uid = nil, Freed = nil, Token = nil }

local function findNearestGuard()
	local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
	world = world and world:FindFirstChild("Areas")
	world = world and world:FindFirstChild("GuardAreas")
	local root = state.Root()
	if not world or not root then
		return nil
	end
	local userIdStr = tostring(localPlayer.UserId)
	local carryAreaGuard = state.Steal.CarryAreaId and getGuardModel({ AreaId = tostring(state.Steal.CarryAreaId) }) or nil
	local bestDistance = math.huge
	local bestGuard = nil

	for _, child in ipairs(world:GetChildren()) do
		local guard = child:FindFirstChild("Guard")

		if guard then
			if tostring(guard:GetAttribute("TargetPlayer")) == userIdStr or tostring(guard:GetAttribute("WakeTargetPlayer")) == userIdStr then
				return guard
			end

			local ok, guardPos = pcall(function()
				return guard:GetPivot().Position
			end)

			if ok then
				local distance = (guardPos - root.Position).Magnitude

				if distance < bestDistance then
					bestGuard = guard
					bestDistance = distance
				end
			end
		end
	end

	return carryAreaGuard or bestGuard
end

local function rideGuardHitToEntry(generation, uid, destination)
	local guard = findNearestGuard()
	if not guard then
		return false
	end
	local armTrap = state.ArmRagdollTrap or armRagdollTrap
	local trap = armTrap and armTrap(generation, destination + Vector3.new(0, 3, 0))
	if not trap then
		return false
	end
	local elapsed = 0

	while true do
		if not trap.Landed and elapsed < flyToTimeout and not isStaleGeneration(generation) then
			local ok, guardPos = pcall(function()
				return guard:GetPivot().Position
			end)

			local root = state.Root()

			if not (not ok or not root) then
				if guardApproachRange + 5 < (guardPos - root.Position).Magnitude then
					local horizontal = Vector3.new(root.Position.X - guardPos.X, 0, root.Position.Z - guardPos.Z)
					local approachPos = guardPos + (horizontal.Magnitude > 0.1 and horizontal.Unit * guardApproachRange or Vector3.zero)

					flyToPositionRollback(Vector3.new(approachPos.X, guardPos.Y + 3, approachPos.Z), generation, nil, 400, true, function()
						if trap.Landed then
							return "hit"
						end
						return nil
					end)
				end

				elapsed = elapsed + RunService.Heartbeat:Wait()
				continue
			end
		end

		break
	end

	trap.Stop()
	if not trap.Landed then
		return false
	end
	return followCarriedEgg(generation, uid)
end

state.SafeCarry.Dangers = {}
state.SafeCarry.DangerAt = 0

state.SafeCarry.RefreshDangers = function()
	local safeCarry = state.SafeCarry
	if os.clock() - safeCarry.DangerAt < 1 then
		return safeCarry.Dangers
	end
	safeCarry.DangerAt = os.clock()
	local dangers = {}

	local function captureBoundingBox(instance)
		local ok, cframeOrBounds, sizeOrNil = pcall(function()
			if instance:IsA("Model") then
				return instance:GetBoundingBox()
			end

			if instance:IsA("BasePart") then
				return instance.CFrame, instance.Size
			end
		end)

		if ok and cframeOrBounds and sizeOrNil then
			local halfX = math.abs(sizeOrNil.X)
			local halfZ = math.abs(sizeOrNil.Z)
			local localCorner = Vector3.new(math.abs(sizeOrNil.X), 0, math.abs(sizeOrNil.Z)) * 0.5
			local worldCorner = (cframeOrBounds - cframeOrBounds.Position):VectorToWorldSpace(localCorner)
			local extentX = math.max(math.abs(worldCorner.X), halfX, halfZ)
			local extentZ = math.max(math.abs(worldCorner.Z), halfX, halfZ)

			table.insert(dangers, {
				MinX = cframeOrBounds.Position.X - extentX,
				MaxX = cframeOrBounds.Position.X + extentX,
				MinZ = cframeOrBounds.Position.Z - extentZ,
				MaxZ = cframeOrBounds.Position.Z + extentZ,
				Name = instance.Name,
			})
		end
	end

	local function isDangerousName(name)
		if name == "ScrambleLocalVisuals" or name == "DrScrambleEvent" then
			return false
		end
		local lower = string.lower(name)
		return string.find(lower, "portal", 1, true)
			or string.find(lower, "teleport", 1, true)
			or string.find(lower, "mech", 1, true)
			or string.find(lower, "arena", 1, true)
			or string.find(lower, "scramble", 1, true)
	end

	for _, child in ipairs(workspace:GetChildren()) do
		if (child:IsA("Model") or child:IsA("BasePart") or child:IsA("Folder")) and isDangerousName(child.Name) then
			if child:IsA("Folder") then
				for _, nested in ipairs(child:GetChildren()) do
					captureBoundingBox(nested)
				end
			else
				captureBoundingBox(child)
			end
		end
	end

	local world = workspace:FindFirstChild("World")
	world = world and world:FindFirstChild("Build")

	if world then
		for _, child in ipairs(world:GetChildren()) do
			if isDangerousName(child.Name) then
				for _, nested in ipairs(child:GetChildren()) do
					captureBoundingBox(nested)
				end
			end
		end
	end

	safeCarry.Dangers = dangers
	return dangers
end

state.SafeCarry.Avoid = function(startPosition, desiredPosition)
	for _, danger in ipairs(state.SafeCarry.RefreshDangers()) do
		local minX = danger.MinX - 12
		local maxX = danger.MaxX + 12
		local minZ = danger.MinZ - 12
		local maxZ = danger.MaxZ + 12
		local clipLow = 0
		local clipHigh = 1
		local intersecting = true

		for _, axis in ipairs({
			{ startPosition.X, desiredPosition.X - startPosition.X, minX, maxX },
			{ startPosition.Z, desiredPosition.Z - startPosition.Z, minZ, maxZ },
		}) do
			local origin = axis[1]
			local direction = axis[2]
			local boxMin = axis[3]
			local boxMax = axis[4]

			if math.abs(direction) < 1e-06 then
				if origin < boxMin or origin > boxMax then
					intersecting = false
				end
			else
				local enterAt = (boxMin - origin) / direction
				local exitAt = (boxMax - origin) / direction
				local tLow, tHigh
				if enterAt > exitAt then
					tLow = exitAt
					tHigh = enterAt
				else
					tLow = enterAt
					tHigh = exitAt
				end

				local newLow = math.max(clipLow, tLow)
				local newHigh = math.min(clipHigh, tHigh)

				if newLow > newHigh then
					intersecting = false
					clipLow = newLow
					clipHigh = newHigh
				else
					clipLow = newLow
					clipHigh = newHigh
				end
			end
		end

		if intersecting and not (startPosition.X >= minX and startPosition.X <= maxX and startPosition.Z >= minZ and startPosition.Z <= maxZ) then
			local zLower = minZ - 2
			local zUpper = maxZ + 2
			local chosenZ = math.abs(startPosition.Z - zLower) <= math.abs(startPosition.Z - zUpper) and zLower or zUpper

			if chosenZ < -440 or chosenZ > -290 then
				chosenZ = chosenZ == zLower and zUpper or zLower
			end

			local chosenX = math.abs(startPosition.X - minX) <= math.abs(startPosition.X - maxX) and minX or maxX

			if math.abs(startPosition.Z - chosenZ) < 3 then
				chosenX = math.abs(desiredPosition.X - minX) <= math.abs(desiredPosition.X - maxX) and minX or maxX
			end

			return Vector3.new(chosenX, desiredPosition.Y, chosenZ), danger.Name
		end
	end

	return desiredPosition, nil
end

state.SafeCarry.NewHuman = function(isCarrying)
	local safeCarry = state.SafeCarry
	local laneOffset = safeCarry.LaneOffset
	local human

	human = {
		Clock = 0,
		Factor = 1,
		Target = 1,
		NextShift = 0,
		Phase = math.random() * math.pi * 2,
		Period = 2 + math.random() * 2.5,
		PauseUntil = 0,
		Lane = (math.random() * 2 - 1) * laneOffset,
		Step = function(deltaTime, humanoid, grounded)
			human.Clock = human.Clock + deltaTime

			if human.NextShift <= human.Clock then
				human.NextShift = human.Clock + 0.5 + math.random()
				local jitter = math.max(safeCarry.SpeedJitter, 0)

				if isCarrying then
					human.Target = 1 - math.random() * jitter
				else
					human.Target = 1 + (math.random() * 2 - 1) * jitter
				end
			end

			human.Factor = human.Factor + (human.Target - human.Factor) * math.min(deltaTime * 3, 1)
			local wobble = safeCarry.Wobble
			local wobbleOffset = math.sin(human.Clock * math.pi * 2 / human.Period + human.Phase) * wobble
			local shouldJump = grounded and humanoid and safeCarry.JumpsPerMinute > 0

			if shouldJump then
				local chance = safeCarry.JumpsPerMinute / 60 * deltaTime
				shouldJump = math.random() < chance
			end

			if shouldJump then
				pcall(function()
					humanoid.Jump = true
				end)
			end

			local pause = false

			if not isCarrying then
				if human.Clock < human.PauseUntil then
					pause = true
				else
					local shouldPause = safeCarry.PausesPerMinute > 0

					if shouldPause then
						local chance = safeCarry.PausesPerMinute / 60 * deltaTime
						shouldPause = math.random() < chance
					end

					if shouldPause then
						human.PauseUntil = human.Clock + 0.3 + math.random() * 0.9
						pause = true
					end
				end
			end

			return human.Factor, human.Lane + wobbleOffset, pause
		end,
	}

	return human
end

state.SafeCarry.React = function(minTime, maxTime)
	local lower = math.max(0, math.min(minTime, maxTime))
	local upper = math.max(minTime, maxTime, 0)
	return lower + math.random() * (upper - lower)
end

state.SafeCarry.RunTo = function(entry, generation)
	local safeCarry = state.SafeCarry
	local position = typeof(entry.CFrame) == "CFrame" and entry.CFrame.Position or nil
	if not position then
		return false
	end

	cleanupFlight()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.PlatformStand = false

		if character:FindFirstChildWhichIsA("Tool") then
			pcall(function()
				humanoid:UnequipTools()
			end)
		end
	end

	local human = safeCarry.NewHuman(false)
	local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
	world = world and world:FindFirstChild("Areas")
	world = world and world:FindFirstChild("SeparationLine")
	local separationX = world and world:IsA("BasePart") and world.Position.X or 552
	local home = stealHome()
	local rootSnapshot = state.Root()
	local phase = "field"
	local baseZ = rootSnapshot and rootSnapshot.Position.Z or position.Z

	if rootSnapshot and home and rootSnapshot.Position.X < separationX - 2 then
		baseZ = home.Z

		if (Vector3.new(rootSnapshot.Position.X, 0, rootSnapshot.Position.Z) - Vector3.new(home.X, 0, home.Z)).Magnitude > 20 then
			phase = "safe"
		end
	end

	local laneZ = math.clamp(baseZ + human.Lane, -425, -300)
	local targetY = position.Y + 3

	local function snapHeight(y)
		local root = state.Root()
		local characterRef = localPlayer.Character
		local tooClose = not root or not characterRef or math.abs(root.Position.Y - y) < 1

		if not tooClose then
			local snapLimit = safeCarry.SnapLimit
			tooClose = math.abs(root.Position.Y - y) > snapLimit
		end

		if tooClose then
			return false
		end

		pcall(function()
			local rotation = root.CFrame.Rotation
			characterRef:PivotTo(CFrame.new(Vector3.new(root.Position.X, y, root.Position.Z)) * rotation)
			root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
		end)

		return true
	end

	local function liftToRunHeight()
		if safeCarry.RunHeight <= 0.5 then
			return
		end
		snapHeight(targetY + safeCarry.RunHeight)
	end

	if phase == "field" then
		liftToRunHeight()
	end

	local startClock = os.clock()
	local stepClock = os.clock()
	local sampleClock = os.clock()
	local previousPosition = rootSnapshot and rootSnapshot.Position or nil

	local function applyMotion(root, waypoint, speedFactor, pause)
		local delta = Vector3.new(waypoint.X - root.Position.X, 0, waypoint.Z - root.Position.Z)
		local distance = delta.Magnitude
		local direction = distance > 0.01 and delta.Unit or Vector3.zero

		if safeCarry.RunHeight > 0.5 and phase == "field" and not pause then
			local runSpeed = safeCarry.RunSpeed
			local maxSpeed = math.max(state.WalkSpeed() * runSpeed * speedFactor, 8)
			local climbShare = math.clamp(safeCarry.ClimbShare, 0.1, 0.9)
			local horizontalDistance = Vector3.new(position.X - root.Position.X, 0, position.Z - root.Position.Z).Magnitude

			if horizontalDistance <= 3 then
				if snapHeight(targetY) then
					return
				end
			end

			local desiredHeight = horizontalDistance <= 3 and targetY or targetY + safeCarry.RunHeight
			if math.abs(desiredHeight - root.Position.Y) > 2 and snapHeight(desiredHeight) then
				return
			end

			local verticalVelocity = math.clamp((desiredHeight - root.Position.Y) / 0.12, -maxSpeed * climbShare, maxSpeed * climbShare)
			local horizontalSpeed = math.min(math.sqrt(math.max(maxSpeed * maxSpeed - verticalVelocity * verticalVelocity, 0)), distance / 0.05)
			local horizontalVelocity = direction * horizontalSpeed

			pcall(function()
				root.AssemblyLinearVelocity = Vector3.new(horizontalVelocity.X, verticalVelocity, horizontalVelocity.Z)
			end)

			return
		end

		pcall(function()
			if pause or distance <= 0.01 then
				if humanoid then
					if safeCarry.RunStyle == "Walk" then
						humanoid:MoveTo(root.Position)
					end
					humanoid:Move(Vector3.zero, false)
				end

				if safeCarry.RunStyle ~= "Walk" then
					root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
				end
			elseif safeCarry.RunStyle == "Walk" then
				if humanoid then
					humanoid:MoveTo(root.Position + direction * math.min(distance, 30))
				end
			else
				local runSpeed = safeCarry.RunSpeed
				local velocity = direction * math.min(math.max(state.WalkSpeed() * runSpeed * speedFactor, 8), distance / 0.05)
				root.AssemblyLinearVelocity = Vector3.new(velocity.X, root.AssemblyLinearVelocity.Y, velocity.Z)

				if safeCarry.RunAnimate and humanoid then
					humanoid:Move(direction, false)
				end
			end
		end)
	end

	while os.clock() - startClock < 240 do
		if isStaleGeneration(generation) then
			return false
		end
		local root = state.Root()
		if not root then
			return false
		end
		local now = os.clock()
		local deltaTime = math.max(now - stepClock, 0.0041666666666666666)
		local toEgg = Vector3.new(position.X - root.Position.X, 0, position.Z - root.Position.Z)
		if phase == "field" and toEgg.Magnitude <= 2.5 and (safeCarry.RunHeight <= 0.5 or root.Position.Y - targetY < 4) then
			break
		end
		local speedFactor, laneDelta, pause = human.Step(deltaTime, humanoid, humanoid and humanoid.FloorMaterial ~= Enum.Material.Air)

		if toEgg.Magnitude <= 15 then
			pause = false
		end

		local waypoint = position

		if phase == "safe" and home then
			if (Vector3.new(home.X, 0, home.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude <= 6 then
				phase = "field"
				liftToRunHeight()
			end

			stealStatusText = "Walking out to the safe zone"
			waypoint = home
		else
			if not safeCarry.StraightRun and safeCarry.RunHeight <= 0.5 and math.abs(position.X - root.Position.X) > 25 then
				waypoint = Vector3.new(position.X, position.Y, math.clamp(laneZ + laneDelta, -425, -300))
			end

			stealStatusText = string.format("Running to the egg, %d studs left", math.floor(toEgg.Magnitude + 0.5))
		end

		local avoided, avoidedName = safeCarry.Avoid(root.Position, waypoint)

		if avoidedName then
			stealStatusText = "Walking around " .. tostring(avoidedName)
		end

		applyMotion(root, avoided, speedFactor, pause)

		if now - sampleClock >= 1.5 then
			if not pause and previousPosition and (root.Position - previousPosition).Magnitude < 3 and humanoid then
				pcall(function()
					humanoid.Jump = true
				end)
			end

			previousPosition = root.Position
			sampleClock = now
		end

		RunService.Heartbeat:Wait()
		stepClock = now
	end

	local finalRoot = state.Root()

	if finalRoot then
		applyMotion(finalRoot, finalRoot.Position, 1, true)
	end

	local stopPoint = nil

	if finalRoot then
		local horizontal = Vector3.new(finalRoot.Position.X - position.X, 0, finalRoot.Position.Z - position.Z)
		local offset = horizontal.Magnitude > 0.1 and horizontal.Unit * 2 or Vector3.zero
		stopPoint = Vector3.new(position.X + offset.X, finalRoot.Position.Y, position.Z + offset.Z)
	end

	local holdConnection = RunService.Heartbeat:Connect(function()
		local root = state.Root()
		if not root or not stopPoint or state.Steal.Carrying or state.AntiGuard.Busy then
			return
		end
		local delta = Vector3.new(stopPoint.X - root.Position.X, 0, stopPoint.Z - root.Position.Z)

		pcall(function()
			if delta.Magnitude > 1.5 then
				local rotation = root.CFrame.Rotation
				root.CFrame = CFrame.new(stopPoint.X, root.Position.Y, stopPoint.Z) * rotation
			end

			root.AssemblyLinearVelocity = Vector3.new(0, math.min(root.AssemblyLinearVelocity.Y, 0), 0)
		end)
	end)

	local function stopHold(returnValue)
		holdConnection:Disconnect()
		return returnValue
	end

	local guard = getGuardModel(entry)
	local waitStart = os.clock()
	local reactTime = safeCarry.React(safeCarry.ReactMin, safeCarry.ReactMax)

	while true do
		if isStaleGeneration(generation) then
			return stopHold(false)
		else
			local elapsed = os.clock() - waitStart
			local totalWait = safeCarry.RunWait + reactTime
			local guardSleeping = not safeCarry.WaitGuard or not guard or guard:GetAttribute("GuardState") == "Sleeping"
			if elapsed >= totalWait and (guardSleeping or elapsed >= totalWait + 15) then
				break
			end
			stealStatusText = elapsed < totalWait and string.format("Waiting before the grab, %.1fs", totalWait - elapsed) or "Waiting for the guard to sleep"
			RunService.Heartbeat:Wait()
		end
	end

	stealStatusText = "Taking the egg"
	local picked = tryPickupHere(entry, generation, 0.8, nil)

	if not picked and not isStaleGeneration(generation) then
		picked = pickUpEgg(entry, generation)
	end

	stopHold()
	if not picked then
		return false
	end
	state.Steal.LastFinishedAt = os.clock()
	return true
end

state.SafeCarry.Pace = function()
	local runSpeed = tonumber(state.SafeCarry.RunSpeed) or 1
	return math.max(state.WalkSpeed() * runSpeed, 16)
end

state.SafeCarry.Plan = function(areaId, distance, speedMult)
	local safeCarry = state.SafeCarry
	local character = localPlayer.Character

	if character then
		character:FindFirstChildOfClass("Humanoid")
	end

	local walkSpeed = state.WalkSpeed()
	speedMult = speedMult or safeCarry.Mult or 1

	if safeCarry.SameSpeedBigEggs then
		speedMult = math.max(speedMult, safeCarry.LightMult)
	end

	local carrySpeed = walkSpeed * safeCarry.CarryRatio * speedMult
	local maxSpeed = carrySpeed * safeCarry.SpeedRatio
	local excessStuds = safeCarry.ExcessSeconds * carrySpeed
	local cappedSpeed

	if distance and distance > excessStuds then
		cappedSpeed = math.min(maxSpeed, carrySpeed * distance / (distance - excessStuds))
	else
		cappedSpeed = maxSpeed
	end

	local guards = modules.Guards
	local guardEntry = nil
	local rawArea = tostring(areaId or "")
	if type(guards) == "table" and type(guards.Directory) == "table" and rawArea ~= "" then
		guardEntry = guards.Directory[rawArea]
			or guards.Directory[string.gsub(rawArea, "%s+", "")]
			or guards.Directory[string.gsub(rawArea, "%s+", "_")]
		if not guardEntry then
			local cleanArea = string.lower(string.gsub(rawArea, "[%s_]+", ""))
			for k, v in pairs(guards.Directory) do
				if string.lower(string.gsub(tostring(k), "[%s_]+", "")) == cleanArea then
					guardEntry = v
					break
				end
			end
		end
	end
	local liveGuard = getGuardModel({ AreaId = rawArea })
	local liveHumanoid = liveGuard and liveGuard:FindFirstChildOfClass("Humanoid")
	local liveSpeed = liveHumanoid and tonumber(liveHumanoid.WalkSpeed) or nil
	local guardSpeed = liveSpeed or (type(guardEntry) == "table" and tonumber(guardEntry.WalkSpeed)) or 0

	if not safeCarry.BeatGuard then
		return math.max(math.min(carrySpeed * safeCarry.EasyRatio, cappedSpeed), carrySpeed), true, carrySpeed, cappedSpeed, guardSpeed
	end

	local carryScale = math.max(safeCarry.CarryScale or 1, 0.01)
	local minRequired = math.max(guardSpeed + safeCarry.GuardMargin, carrySpeed * safeCarry.MinRatio)
	local targetSpeed = math.max(minRequired, guardSpeed * safeCarry.GuardRatio)

	if cappedSpeed < minRequired then
		local stretchStuds = safeCarry.StretchSeconds * carrySpeed
		local stretchCap

		if distance and distance > stretchStuds then
			stretchCap = math.min(maxSpeed, carrySpeed * distance / (distance - stretchStuds))
		else
			stretchCap = maxSpeed
		end

		local beatTarget = (guardSpeed + math.max(safeCarry.GuardMargin, 1)) / carryScale
		if beatTarget <= stretchCap then
			return beatTarget, true, carrySpeed, stretchCap, guardSpeed
		end

		return math.min(stretchCap, beatTarget), beatTarget <= stretchCap, carrySpeed, stretchCap, guardSpeed
	end

	local beatTarget = math.max(math.min(targetSpeed, cappedSpeed), carrySpeed) / carryScale
	beatTarget = math.clamp(beatTarget, carrySpeed, cappedSpeed)
	return beatTarget, beatTarget * carryScale >= minRequired, carrySpeed, cappedSpeed, guardSpeed
end

state.SafeCarry.Unsafe = function(entry)
	local safeCarry = state.SafeCarry
	if not safeCarry.Enabled or type(entry) ~= "table" or not entry.Uid or not safeCarry.Blocked[entry.Uid] then
		return nil
	end
	return string.format("the guard caught you with this %s before, skipping it", tostring(entry.Category))
end

state.SafeCarry.Settle = function(generation, entry)
	local safeCarry = state.SafeCarry
	local character = localPlayer.Character

	if character then
		character:FindFirstChildOfClass("Humanoid")
	end

	math.max(
		state.WalkSpeed()
			* safeCarry.CarryRatio
			* (safeCarry.Seen[tostring(entry.Category)] or safeCarry.GuessMult)
			* safeCarry.WaitRate,
		1
	)
	local baseWait = safeCarry.BaseWait
	local guard = getGuardModel(entry)

	while true do
		if isStaleGeneration(generation) then
			return false
		else
			local elapsed = os.clock() - (safeCarry.JumpAt or 0)
			local guardSleeping = not safeCarry.WaitGuard or not guard or guard:GetAttribute("GuardState") == "Sleeping"
			if elapsed >= baseWait and (guardSleeping or elapsed >= baseWait + 15) then
				break
			end

			if elapsed < baseWait then
				stealStatusText = string.format("Letting the jump settle, %.1fs", baseWait - elapsed)
			else
				stealStatusText = "Waiting for the guard to sleep"
			end

			RunService.Heartbeat:Wait()
		end
	end

	return true
end

state.MonitorAction = state.MonitorAction or function(fn)
	local ok, constants = pcall(debug.getconstants, fn)
	if not ok or type(constants) ~= "table" then
		return false
	end

	for _, value in pairs(constants) do
		local isMatch = type(value) == "string"

		if isMatch then
			isMatch = value == "Relocate"
				or value == "SetWalkSpeed"
				or value == "BeginRagdoll"
				or value == "EndRagdoll"
				or value == "BeginImpulse"
		end

		if isMatch then
			return true
		end
	end

	return false
end

state.SafeCarry.LineDropHome = function(generation)
	if not isPremiumUser() then
		state.SafeCarry.LineDrop = false
		notifyPremium("Instant Steal")
		return false
	end
	local safeCarry = state.SafeCarry
	local steal = state.Steal
	local carryUid = steal.CarryUid
	local home = stealHome()
	local root = state.Root()
	if type(carryUid) ~= "string" or not home or not root then
		return false
	end

	local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
	world = world and world:FindFirstChild("Areas")
	world = world and world:FindFirstChild("SeparationLine")
	local lineX = world and world:IsA("BasePart") and world.Position.X or 552.2
	local lineY = world and world:IsA("BasePart") and world.Position.Y or 67.67

	local fieldSign = 1
	if world and world:IsA("BasePart") then
		fieldSign = world.CFrame.LookVector.X >= 0 and 1 or -1
	end

	local disabledConnections = {}

	pcall(function()
		for _, signal in ipairs({ RunService.Heartbeat, RunService.PreSimulation, RunService.PostSimulation }) do
			for _, connection in ipairs(getconnections(signal)) do
				local ok, fn = pcall(function()
					return connection.Function
				end)

				if ok and type(fn) == "function" then
					local infoOk, info = pcall(debug.info, fn, "s")

					if infoOk and string.find(tostring(info), "UGI", 1, true) and not state.MonitorAction(fn) then
						local ok3, enabled = pcall(function()
							return connection.Enabled
						end)

						if not ok3 or enabled ~= false then
							if pcall(function()
								connection:Disable()
							end) then
								table.insert(disabledConnections, connection)
							end
						end
					end
				end
			end
		end
	end)

	local wasPulled = false
	local pullConnection = nil

	pcall(function()
		pullConnection = networking["RE/RigSync/Refresh"].OnClientEvent:Connect(function(payload)
			if type(payload) == "table" and payload.Action == "Relocate" then
				wasPulled = true
			end
		end)
	end)

	local currentCamera = workspace.CurrentCamera
	local savedCamera = nil

	local function lockCamera()
		if savedCamera or not currentCamera then
			return
		end
		savedCamera = { Type = currentCamera.CameraType, CFrame = currentCamera.CFrame }

		pcall(function()
			currentCamera.CameraType = Enum.CameraType.Scriptable
			currentCamera.CFrame = savedCamera.CFrame
		end)
	end

	local function unlockCamera()
		if not savedCamera or not currentCamera then
			return
		end
		local saved = savedCamera
		savedCamera = nil

		pcall(function()
			currentCamera.CameraType = saved.Type
		end)
	end

	local function restoreEverything()
		unlockCamera()

		if pullConnection then
			pullConnection:Disconnect()
			pullConnection = nil
		end

		for _, connection in ipairs(disabledConnections) do
			pcall(function()
				connection:Enable()
			end)
		end

		table.clear(disabledConnections)
	end

	local startClock = os.clock()

	local function moveAlongLine(targetXZ, speed, maxDuration, earlyExit)
		local elapsed = 0

		while elapsed < maxDuration and not isStaleGeneration(generation) do
			local rootNow = state.Root()
			if not rootNow then
				return false
			end

			if earlyExit and earlyExit() then
				return true
			end
			local delta = Vector3.new(targetXZ.X - rootNow.Position.X, 0, targetXZ.Z - rootNow.Position.Z)
			if delta.Magnitude < 2.5 then
				return true
			end
			local velocity = delta.Unit * math.min(speed, delta.Magnitude / 0.05)

			pcall(function()
				rootNow.AssemblyLinearVelocity = Vector3.new(velocity.X, rootNow.AssemblyLinearVelocity.Y, velocity.Z)
			end)

			elapsed = elapsed + RunService.Heartbeat:Wait()
		end

		return false
	end

	cleanupFlight()
	local laneZ = math.clamp(root.Position.Z, -425, -300)

	local hopGapOffset = (safeCarry.Hops and safeCarry.HopStop or safeCarry.LineGap) * fieldSign
	local hopDestination = Vector3.new(lineX + hopGapOffset, lineY + 3.35, laneZ)

	local function queryUidRecord()
		local remote = networking:FindFirstChild("RF/EggWorld/AskFieldEggSnapshot")
		local ok, result = pcall(function()
			return remote:InvokeServer()
		end)
		local records = ok and type(result) == "table" and result.Records or nil

		if type(records) == "table" then
			for _, record in pairs(records) do
				if type(record) == "table" and record.Uid == carryUid then
					return record
				end
			end
		end

		return nil
	end

	local horizontalDistance = Vector3.new(root.Position.X - lineX, 0, root.Position.Z - laneZ).Magnitude
	local carrySpeed = math.max(
		state.WalkSpeed() * safeCarry.CarryRatio * (tonumber(safeCarry.Mult) or safeCarry.LightMult),
		1
	)
	local directMargin = safeCarry.DirectMargin
	local crossWait = math.max(0, (horizontalDistance - safeCarry.DirectBudget) / carrySpeed) + directMargin

	if safeCarry.CrossNow or safeCarry.BeatGuard then
		crossWait = safeCarry.DirectMargin
	end

	local function snapToHopDestination()
		local rootNow = state.Root()
		if not rootNow then
			return
		end

		pcall(function()
			rootNow.CFrame = CFrame.new(hopDestination) * CFrame.Angles(0, math.pi / 2, 0)
			rootNow.AssemblyLinearVelocity = Vector3.zero
			rootNow.AssemblyAngularVelocity = Vector3.zero
		end)
	end

	lockCamera()

	if safeCarry.Hops then
		local rootNow = state.Root()

		if rootNow then
			local hopY = rootNow.Position.Y + safeCarry.HopLift
			local cursorX = rootNow.Position.X
			local hopSpeed = math.max(state.WalkSpeed() * safeCarry.HopRatio, 40)

			local totalHopDistance = math.abs(cursorX - hopDestination.X)

			if totalHopDistance > 1000 then
				local stepSize = 350
				local stepDelay = 0.07
				local stepsNeeded = math.ceil(totalHopDistance / stepSize)
				local dirSign = hopDestination.X < cursorX and -1 or 1
				for step = 1, stepsNeeded do
					if not steal.Carrying or isStaleGeneration(generation) then break end
					local targetX = cursorX + stepSize * dirSign * step
					if dirSign < 0 and targetX < hopDestination.X then targetX = hopDestination.X end
					if dirSign > 0 and targetX > hopDestination.X then targetX = hopDestination.X end
					local rootStep = state.Root()
					if rootStep then
						pcall(function()
							rootStep.CFrame = CFrame.new(targetX, hopY, laneZ) * CFrame.Angles(0, math.pi / 2, 0)
							rootStep.AssemblyLinearVelocity = Vector3.zero
							rootStep.AssemblyAngularVelocity = Vector3.zero
						end)
					end
					stealStatusText = string.format("Line Drop: moving to line, X %d", math.floor(targetX))
					task.wait(stepDelay)
				end
			else
			local hopDone = fieldSign > 0
				and function() return cursorX - hopSpeed <= hopDestination.X end
				or function() return cursorX + hopSpeed >= hopDestination.X end
			while not hopDone() and steal.Carrying and not isStaleGeneration(generation) do
				cursorX = cursorX - hopSpeed * fieldSign
				stealStatusText = string.format("Line Drop: hopping home, X %d", math.floor(cursorX))
				local wait = 0

				while wait < safeCarry.HopGap do
					local r = state.Root()

					if r then
						pcall(function()
							r.CFrame = CFrame.new(cursorX, hopY, laneZ) * CFrame.Angles(0, math.pi / 2, 0)
							r.AssemblyLinearVelocity = Vector3.zero
							r.AssemblyAngularVelocity = Vector3.zero
						end)
					end

					wait = wait + RunService.Heartbeat:Wait()
				end
			end
			end
		end
	end

	stealStatusText = "Line Drop: landing next to the line"
	snapToHopDestination()

	if safeCarry.Hops and steal.Carrying then
		local elapsed = 0

		while elapsed < safeCarry.DropDelay and steal.Carrying and not isStaleGeneration(generation) do
			elapsed = elapsed + RunService.Heartbeat:Wait()
		end

		if steal.Carrying then
			stealStatusText = "Line Drop: dropping the egg next to the line"
			local eggState = modules.EggState

			if type(eggState) == "table" and type(eggState.DropFieldEgg) == "function" then
				pcall(eggState.DropFieldEgg, "PlayerRequest")
			end

			local wait = 0

			while steal.Carrying and wait < 1 and not isStaleGeneration(generation) do
				wait = wait + RunService.Heartbeat:Wait()
			end
		end
	end

	unlockCamera()

	if safeCarry.ShakeTime > 0 then
		local shakeInner = Vector3.new(lineX + safeCarry.ShakeInside * fieldSign, hopDestination.Y, laneZ)
		local toggleInner = false
		local elapsed = 0

		while elapsed < safeCarry.ShakeTime and steal.Carrying and not isStaleGeneration(generation) do
			stealStatusText = "Line Drop: shaking at the line"
			toggleInner = not toggleInner
			local rootNow = state.Root()

			if rootNow then
				pcall(function()
					rootNow.CFrame = CFrame.new(toggleInner and shakeInner or hopDestination) * CFrame.Angles(0, math.pi / 2, 0)
					rootNow.AssemblyLinearVelocity = Vector3.zero
				end)
			end

			elapsed = elapsed + RunService.Heartbeat:Wait()
		end

		snapToHopDestination()
	end

	local canCrossSoon = crossWait < safeCarry.LineWait
	local waitElapsed = 0
	local reJumpCount = 1

	while true do
		local stillWaiting = steal.Carrying and waitElapsed < safeCarry.LineWait

		if stillWaiting then
			stillWaiting = not (canCrossSoon and waitElapsed >= crossWait)
		end

		if stillWaiting and not isStaleGeneration(generation) then
			if canCrossSoon then
				stealStatusText = string.format("Line Drop: stepping over the line in %.1fs", math.max(crossWait - waitElapsed, 0))
			else
				stealStatusText = string.format(
					"Line Drop: crossing needs %.1fs, waiting for the guard, %.0fs left",
					crossWait,
					safeCarry.LineWait - waitElapsed
				)
			end

			if wasPulled and safeCarry.ReJump and reJumpCount < 40 and not isRagdolledDeep() then
				wasPulled = false
				reJumpCount = reJumpCount + 1
				stealStatusText = "Line Drop: pulled back, jumping to the line again"
				snapToHopDestination()
			end

			waitElapsed = waitElapsed + RunService.Heartbeat:Wait()
			continue
		end

		break
	end

	if steal.Carrying and canCrossSoon and waitElapsed >= crossWait and not isStaleGeneration(generation) then
		stealStatusText = "Line Drop: stepping over the line"
		moveAlongLine(home, state.WalkSpeed() * safeCarry.CrossRatio, 6, function()
			return safeCarry.LastDelivered >= startClock or not steal.Carrying
		end)

		local wait = 0

		while wait < 1.5 and safeCarry.LastDelivered < startClock and steal.Carrying and not isStaleGeneration(generation) do
			wait = wait + RunService.Heartbeat:Wait()
		end

		if safeCarry.LastDelivered >= startClock then
			restoreEverything()
			return true
		end
	end

	if steal.Carrying then
		restoreEverything()
		stealStatusText = "Line Drop: the guard never came, dropping the egg"
		local eggState = modules.EggState

		if type(eggState) == "table" and type(eggState.DropFieldEgg) == "function" then
			pcall(eggState.DropFieldEgg, "PlayerRequest")
		end

		return false
	end

	if safeCarry.GetUp then
		task.spawn(function()
			local elapsed = 0

			while elapsed < 1.5 do
				local character = localPlayer.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")

				if humanoid then
					pcall(function()
						humanoid.PlatformStand = false
						local currentState = humanoid:GetState()

						if currentState == Enum.HumanoidStateType.Physics
							or currentState == Enum.HumanoidStateType.Ragdoll
							or currentState == Enum.HumanoidStateType.FallingDown
						then
							humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
						end
					end)
				end

				elapsed = elapsed + RunService.Heartbeat:Wait()
			end
		end)
	end

	local gettingUp = 0

	while not safeCarry.SnapPickup and not safeCarry.GetUp and isRagdolledDeep() and gettingUp < 6 and not isStaleGeneration(generation) do
		stealStatusText = "Line Drop: egg is down at the line, getting up"
		gettingUp = gettingUp + RunService.Heartbeat:Wait()
	end

	local attempt = 0

	while not isStaleGeneration(generation) and attempt < 4 do
		attempt = attempt + 1
		local eggPosition = queryFieldSnapshot(carryUid)

		if not eggPosition then
			restoreEverything()
			stealStatusText = "Line Drop: the egg is gone"
			return false
		end

		local record = queryUidRecord()

		if record and record.State == "Slot" then
			restoreEverything()
			stealStatusText = "Line Drop: the egg went back to its nest"
			return false
		end

		stealStatusText = "Line Drop: picking the egg up at the line"
		local pickupDuration

		if safeCarry.SnapPickup then
			local rootNow = state.Root()

			if rootNow then
				pcall(function()
					rootNow.CFrame = CFrame.new(eggPosition + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.pi / 2, 0)
					rootNow.AssemblyLinearVelocity = Vector3.zero
				end)
			end

			pickupDuration = 5
		else
			moveAlongLine(eggPosition, state.WalkSpeed() * safeCarry.PickupRatio, 5)
			pickupDuration = 2.5
		end

		local elapsed = 0

		while not steal.Carrying and elapsed < pickupDuration and not isStaleGeneration(generation) do
			task.spawn(requestCarryEgg, carryUid)

			if safeCarry.SnapPickup then
				local rootNow = state.Root()

				if rootNow and Vector3.new(rootNow.Position.X - eggPosition.X, 0, rootNow.Position.Z - eggPosition.Z).Magnitude > 6 then
					pcall(function()
						rootNow.CFrame = CFrame.new(eggPosition + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.pi / 2, 0)
					end)
				end
			end

			elapsed = elapsed + task.wait(0.15)
		end

		if steal.Carrying and not steal.WrongEgg(carryUid) then
			break
		end
	end

	if not steal.Carrying then
		restoreEverything()
		stealStatusText = "Line Drop: could not pick the egg up again"
		return false
	end

	local rootNow = state.Root()

	local distFromLine = (rootNow and rootNow.Position.X - lineX) or 0
	if rootNow and distFromLine * fieldSign > safeCarry.FarFromLine then
		restoreEverything()
		stealStatusText = "Line Drop: egg ended up far from the line, carrying it home safely"
		return state.SafeCarry.Home(generation)
	end

	stealStatusText = "Line Drop: stepping over the line"
	moveAlongLine(home, state.WalkSpeed() * safeCarry.CrossRatio, 6, function()
		return safeCarry.LastDelivered >= startClock or not steal.Carrying
	end)

	local finalRoot = state.Root()

	if finalRoot then
		pcall(function()
			finalRoot.AssemblyLinearVelocity = Vector3.new(0, finalRoot.AssemblyLinearVelocity.Y, 0)
		end)
	end

	local wait = 0

	while wait < 2 and safeCarry.LastDelivered < startClock and steal.Carrying and not isStaleGeneration(generation) do
		wait = wait + RunService.Heartbeat:Wait()
	end

	restoreEverything()
	return safeCarry.LastDelivered >= startClock
end

state.SafeCarry.Home = function(generation)
	local safeCarry = state.SafeCarry
	local home = stealHome()
	local root = state.Root()
	if not home or not root then
		return false
	end

	cleanupFlight()
	local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
	world = world and world:FindFirstChild("Areas")
	world = world and world:FindFirstChild("SeparationLine")
	local lineSafeX = (world and world:IsA("BasePart") and world.Position.X or 552) - 7
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.PlatformStand = false
	end

	local startClock = os.clock()
	local currentSpeed = 0

	local function replan()
		local rootNow = state.Root()
		if not rootNow then
			return
		end

		local speed, planOk, carrySpeed, capSpeed, beatSpeed = safeCarry.Plan(
			state.Steal.CarryAreaId,
			(Vector3.new(rootNow.Position.X, 0, rootNow.Position.Z) - Vector3.new(home.X, 0, home.Z)).Magnitude
				+ math.max(0, safeCarry.Height) * 2,
			safeCarry.Mult
		)
		local scaledSpeed = speed * safeCarry.CarryScale
		currentSpeed = scaledSpeed
		safeCarry.PlanOk = planOk
		safeCarry.FloorSpeed = safeCarry.BeatGuard
				and math.min(beatSpeed + math.max(safeCarry.GuardMargin, 1), capSpeed)
			or 0
		stealStatusText = string.format(
			"Carrying home at %d (carry %d, guard %d, max %d)%s",
			math.floor(scaledSpeed + 0.5),
			math.floor(carrySpeed + 0.5),
			math.floor(capSpeed + 0.5),
			math.floor(beatSpeed + 0.5),
			planOk and "" or ", guard is faster, going at your max safe speed"
		)
	end

	local function liftToHeight()
		local height = math.max(0, safeCarry.Height)
		local rootNow = state.Root()
		local characterRef = localPlayer.Character
		if height <= 0.5 or not rootNow or not characterRef then
			return
		end
		local targetY = home.Y + height
		if targetY - 2 <= rootNow.Position.Y then
			return
		end
		local rotation = rootNow.CFrame.Rotation
		local targetCFrame = CFrame.new(Vector3.new(rootNow.Position.X, targetY, rootNow.Position.Z)) * rotation

		pcall(function()
			characterRef:PivotTo(targetCFrame)
			rootNow.AssemblyLinearVelocity = Vector3.zero
			rootNow.AssemblyAngularVelocity = Vector3.zero
		end)
	end

	replan()
	local human = safeCarry.NewHuman(true)
	local initialRoot = state.Root()
	local laneZ = math.clamp((initialRoot and initialRoot.Position.Z or home.Z) + human.Lane, -425, -300)
	local stepClock = os.clock()

	if safeCarry.CarryReact > 0 then
		local untilTime = os.clock() + safeCarry.React(0, safeCarry.CarryReact)

		while os.clock() < untilTime and not isStaleGeneration(generation) do
			RunService.Heartbeat:Wait()
		end
	end

	local recoverCount = 0

	if safeCarry.CarryStyle ~= "Walk" then
		liftToHeight()
	end

	while not isStaleGeneration(generation) do
		local rootNow = state.Root()
		if not rootNow then
			return false
		end

		if not state.Steal.Carrying then
			if startClock <= safeCarry.LastDelivered then
				return true
			end
			task.wait(0.1)
			if startClock <= safeCarry.LastDelivered then
				return true
			end

			if startClock <= safeCarry.LastFailed then
				stealStatusText = "Delivery was rewound, too fast for your speed"
				return false
			end

			if not safeCarry.PlanOk and state.Steal.CarryUid then
				safeCarry.Blocked[state.Steal.CarryUid] = true
				stealStatusText = string.format(
					"The guard caught you with %s, it is faster than your max safe speed, skipping this egg",
					tostring(safeCarry.Category)
				)
				return false
			end

			recoverCount = recoverCount + 1
			if safeCarry.RecoverTries < recoverCount then
				stealStatusText = "The egg is gone"
				return false
			end
			stealStatusText = "Egg dropped, taking it back"
			if not followCarriedEgg(generation) then
				stealStatusText = "Could not take the egg back"
				return false
			end
			local recoveryWait = 0

			while isRagdolledDeep() and recoveryWait < 4 and not isStaleGeneration(generation) do
				recoveryWait = recoveryWait + RunService.Heartbeat:Wait()
			end

			local savedClock = math.min(startClock, os.clock())
			replan()

			if safeCarry.CarryStyle ~= "Walk" then
				liftToHeight()
			end

			rootNow = state.Root()
			if not rootNow then
				return false
			end
			startClock = savedClock
		end

		local now = os.clock()
		local deltaTime = math.max(now - stepClock, 0.0041666666666666666)
		local walkMode = safeCarry.CarryStyle == "Walk"
		local heightOffset = walkMode and 0 or math.max(0, safeCarry.Height)
		local speedFactor, laneDelta = human.Step(deltaTime, heightOffset <= 0.5 and humanoid or nil, humanoid and humanoid.FloorMaterial ~= Enum.Material.Air)
		local targetLane = math.clamp(laneZ + laneDelta, -425, -300)
		local waypoint

		local isFieldSide = getFieldSideFn()
		if isFieldSide(rootNow.Position) then
			local world2 = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
			local sep2 = world2 and world2:FindFirstChild("Areas")
			sep2 = sep2 and sep2:FindFirstChild("SeparationLine")
			if sep2 and sep2:IsA("BasePart") then
				local toSafe = -sep2.CFrame.LookVector
				local linePos = sep2.Position + toSafe * 7
				waypoint = Vector3.new(linePos.X, rootNow.Position.Y, targetLane)
			else
				waypoint = Vector3.new(lineSafeX, rootNow.Position.Y, targetLane)
			end
		else
			waypoint = home
		end

		local avoided, avoidedName = safeCarry.Avoid(rootNow.Position, waypoint)

		if not avoidedName then
			avoided = waypoint
		end

		local delta = Vector3.new(avoided.X - rootNow.Position.X, 0, avoided.Z - rootNow.Position.Z)
		if delta.Magnitude < 2 and avoided == home then
			break
		end
		local moveSpeed = math.max(currentSpeed * speedFactor, safeCarry.FloorSpeed or 0)

		if os.clock() < (safeCarry.SlowUntil or 0) and not safeCarry.BeatGuard then
			moveSpeed = moveSpeed * safeCarry.SlowFactor
		end

		if walkMode then
			pcall(function()
				if humanoid and delta.Magnitude > 0.01 then
					humanoid:MoveTo(rootNow.Position + delta.Unit * math.min(delta.Magnitude, 30))
				end
			end)
		elseif heightOffset > 0.5 then
			local climbShare = math.clamp(safeCarry.ClimbShare, 0.1, 0.9)
			local targetY = home.Y
			local horizontalToLine = math.max(0, rootNow.Position.X - lineSafeX)
			local climbDistance = heightOffset * math.sqrt(1 - climbShare * climbShare) / climbShare
			local desiredY = targetY + heightOffset

			if avoided == home or horizontalToLine <= climbDistance then
				desiredY = targetY + heightOffset * math.clamp((avoided == home and 0 or horizontalToLine) / math.max(climbDistance, 1), 0, 1)
			end

			local vertSmooth = math.max(0.12, deltaTime * 3)
			local verticalVelocity = math.clamp((desiredY - rootNow.Position.Y) / vertSmooth, -moveSpeed * climbShare, moveSpeed * climbShare)
			local horizontalSpeed = math.sqrt(math.max(moveSpeed * moveSpeed - verticalVelocity * verticalVelocity, 0))
			local proxLimit = math.max(0.05, deltaTime)
			local horizontalVelocity = delta.Magnitude > 0.01 and delta.Unit * math.min(horizontalSpeed, delta.Magnitude / proxLimit) or Vector3.zero

			pcall(function()
				rootNow.AssemblyLinearVelocity = Vector3.new(horizontalVelocity.X, verticalVelocity, horizontalVelocity.Z)
			end)
		else
			local proxLimit2 = math.max(0.05, deltaTime)
			local velocity = delta.Magnitude > 0.01 and delta.Unit * math.min(moveSpeed, delta.Magnitude / proxLimit2) or Vector3.zero

			pcall(function()
				rootNow.AssemblyLinearVelocity = Vector3.new(velocity.X, rootNow.AssemblyLinearVelocity.Y, velocity.Z)

				if safeCarry.RunAnimate and humanoid and delta.Magnitude > 0.01 then
					humanoid:Move(delta.Unit, false)
				end
			end)
		end

		RunService.Heartbeat:Wait()
		stepClock = now
	end

	if humanoid then
		pcall(function()
			local rootNow = state.Root()

			if safeCarry.CarryStyle == "Walk" and rootNow then
				humanoid:MoveTo(rootNow.Position)
			end

			humanoid:Move(Vector3.zero, false)
		end)
	end

	local finishWait = 0

	while finishWait < 2 and not isStaleGeneration(generation) do
		if safeCarry.LastDelivered >= startClock then
			return true
		end

		if startClock <= safeCarry.LastFailed then
			stealStatusText = "Delivery was rewound, too fast for your speed"
			return false
		end

		if not state.Steal.Carrying then
			break
		end
		finishWait = finishWait + RunService.Heartbeat:Wait()
	end

	if state.Steal.Carrying then
		task.wait(0.2)
		local eggState = modules.EggState

		if type(eggState) == "table" and type(eggState.DropFieldEgg) == "function" then
			pcall(eggState.DropFieldEgg, "PlayerRequest")
		end
	end

	return safeCarry.LastDelivered >= startClock
end

local carryWaitTime = 0.6
local nearbyMultiplier = 3

state.Steal.HeldByMe = function()
	local carryUid = state.Steal.CarryUid
	local character = localPlayer.Character
	if type(carryUid) ~= "string" or not character then
		return false
	end
	local eggModel = workspace:FindFirstChild(carryUid)
	if not eggModel then
		return false
	end

	for _, descendant in ipairs(eggModel:GetDescendants()) do
		if descendant:IsA("WeldConstraint") or descendant:IsA("JointInstance") then
			local ok, partA, partB = pcall(function()
				return descendant.Part0, descendant.Part1
			end)

			if ok and (partA and partA:IsDescendantOf(character) or partB and partB:IsDescendantOf(character)) then
				return true
			end
		end
	end

	return false
end

local function getFieldSideFn()
	local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
	local sep = world and world:FindFirstChild("Areas")
	sep = sep and sep:FindFirstChild("SeparationLine")
	if sep and sep:IsA("BasePart") then
		return function(position)
			return sep.CFrame.LookVector:Dot(position - sep.Position) > 0
		end
	end

	return function(position)
		return position.X > 552
	end
end

local function safeCarryRun(generation)
	local antiGuard = state.AntiGuard

	if antiGuard.Enabled and not state.SafeCarry.LineDrop then
		local waitStart = 0

		while not antiGuard.Busy and waitStart < 1 and not isStaleGeneration(generation) do
			stealStatusText = "Waiting for Anti Guard to start"
			waitStart = waitStart + RunService.Heartbeat:Wait()
		end

		local wasBusy = antiGuard.Busy
		local busyElapsed = 0

		while antiGuard.Busy and busyElapsed < 30 and not isStaleGeneration(generation) do
			stealStatusText = "Anti Guard is slipping past the guard"
			busyElapsed = busyElapsed + RunService.Heartbeat:Wait()
		end

		if wasBusy then
			local waitDone = 0
			local standingDelay = 0

			while waitDone < 10 and not isStaleGeneration(generation) do
				local ragdolled = isRagdolledDeep()
				local ok, held = pcall(state.Steal.HeldByMe)
				held = ok and held == true
				local canMove = not ragdolled

				if canMove and not held then
					break
				end

				if canMove and held and not antiGuard.Busy then
					standingDelay = standingDelay + RunService.Heartbeat:Wait()
					if not (standingDelay >= 0.3) then
						continue
					end
					break
				end

				stealStatusText = ragdolled and "The guard hit you, waiting until you can move" or "Waiting for Anti Guard to finish"
				waitDone = waitDone + RunService.Heartbeat:Wait()
				standingDelay = 0
			end

			local ok, held = pcall(state.Steal.HeldByMe)

			if ok and not held then
				state.Steal.Carrying = false
			end

			local safeCarry = state.SafeCarry
			local home = stealHome()
			local targetY = home and safeCarry.Enabled and safeCarry.CarryStyle ~= "Walk" and safeCarry.Height > 0.5 and home.Y + safeCarry.Height or nil
			local riseElapsed = 0

			while riseElapsed < 0.8 and state.Steal.Carrying and not isStaleGeneration(generation) do
				stealStatusText = riseElapsed < 0.6 and "Anti Guard done, rising up" or "Anti Guard done, getting ready"
				local root = state.Root()

				if root and targetY then
					local heightDiff = targetY - root.Position.Y
					local verticalSpeed

					if riseElapsed < 0.6 then
						verticalSpeed = math.clamp(heightDiff / math.max(0.6 - riseElapsed, 0.1), -120, 120)
					else
						verticalSpeed = math.clamp(heightDiff / 0.2, -30, 30)
					end

					pcall(function()
						root.AssemblyLinearVelocity = Vector3.new(0, verticalSpeed, 0)
					end)
				end

				riseElapsed = riseElapsed + RunService.Heartbeat:Wait()
			end

			local ok2, held2 = pcall(state.Steal.HeldByMe)

			if ok2 and not held2 then
				state.Steal.Carrying = false
			else
				state.SafeCarry.SlowUntil = os.clock() + 2
			end
		end
	end

	local waitInHand = 0

	while not state.Steal.Carrying and waitInHand < carryWaitTime and not isStaleGeneration(generation) do
		stealStatusText = "Checking the egg in hand"
		waitInHand = waitInHand + RunService.Heartbeat:Wait()
	end

	if not state.Steal.Carrying then
		stealStatusText = "The egg is gone, staying to look for it"
		if not followCarriedEgg(generation) then
			stealStatusText = "The egg is gone"
			return false
		end
	end

	if state.SafeCarry.LineDrop and isPremiumUser() then
		return state.SafeCarry.LineDropHome(generation)
	end

	if state.SafeCarry.Enabled then
		return state.SafeCarry.Home(generation)
	end
	local home = stealHome()
	local root = state.Root()
	if not home or not root then
		return false
	end
	local targetY = math.max(root.Position.Y, home.Y) + flyHeightOffset

	local function checkPriorityReturn()
		if carryState.Uid and carryState.Freed and state.Steal.Carrying then
			return "priority"
		end
		return nil
	end

	local allowFallback = true
	local dropRetries = 0

	while true do
		local currentRoot = state.Root()

		if not currentRoot then
			return false
		else
			stealStatusText = "Flying home"
			local position = currentRoot.Position
			local flyY = math.max(targetY, position.Y)
			local ok1, reason1 = flyToPositionRollback(
				Vector3.new(
					position.X + (home.X - position.X) * 0.25,
					position.Y + (flyY - position.Y) * 0.7,
					position.Z + (home.Z - position.Z) * 0.25
				),
				generation,
				allowFallback,
				nil,
				nil,
				checkPriorityReturn
			)

			if ok1 then
				ok1, reason1 = flyToPositionRollback(Vector3.new(home.X, flyY, home.Z), generation, allowFallback, nil, nil, checkPriorityReturn)
			end

			if ok1 then
				ok1, reason1 = flyToPositionRollback(home, generation, allowFallback, nil, nil, checkPriorityReturn)
			end

			if ok1 then
				local humanoid = localPlayer.Character
				humanoid = humanoid and humanoid:FindFirstChildOfClass("Humanoid")

				if humanoid then
					humanoid.PlatformStand = false
				end

				task.wait(0.2)
				if not state.Steal.Carrying then
					stealStatusText = "Arrived without the egg"
					return false
				end
				local eggState = modules.EggState

				if type(eggState) == "table" and type(eggState.DropFieldEgg) == "function" then
					pcall(eggState.DropFieldEgg, "PlayerRequest")
				end

				return true
			end

			if reason1 == "priority" then
				local priorityUid = carryState.Uid
				local priorityFreed = carryState.Freed
				carryState.Uid = nil
				carryState.Freed = nil
				local root2 = state.Root()
				if not root2 or not priorityUid or not priorityFreed then
					return false
				end

				if (priorityFreed - root2.Position).Magnitude <= flySpeed * nearbyMultiplier then
					stealStatusText = "Best egg fell nearby, swapping eggs"
					local eggState = modules.EggState

					if type(eggState) == "table" and type(eggState.DropFieldEgg) == "function" then
						pcall(eggState.DropFieldEgg, "PlayerRequest")
					end

					local dropWait = 0

					while state.Steal.Carrying and dropWait < 1 do
						dropWait = dropWait + RunService.Heartbeat:Wait()
					end

					if not followCarriedEgg(generation, priorityUid) then
						return false
					end
				else
					stealStatusText = "Best egg fell far away, riding a guard hit to it"
					if not rideGuardHitToEntry(generation, priorityUid, priorityFreed) then
						return false
					end
				end

				local newRoot = state.Root()
				dropRetries = 0

				if newRoot then
					targetY = math.max(newRoot.Position.Y, home.Y) + flyHeightOffset
				end

				continue
			end

			if reason1 == "dropped" and dropRetries < math.huge then
				dropRetries = dropRetries + 1
				if not followCarriedEgg(generation) then
					return false
				end
				continue
			end

			break
		end
	end

	return false
end

local function formatCompactNumber(value)
	local number = tonumber(value) or 0
	local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local index = 1

	while math.abs(number) >= 1000 and index < #suffixes do
		number = number / 1000
		index = index + 1
	end

	return string.format(index == 1 and "%.0f%s" or "%.2f%s", number, suffixes[index])
end

local function formatEggLabel(entry)
	if not entry then
		return "None"
	end
	local category = tostring(entry.Category)
	local scale = tonumber(entry.Scale) or 0
	local areaId = entry.AreaId
	local mutationTag = (type(entry.MutationName) == "string" and entry.MutationName ~= "") and (" [" .. entry.MutationName .. "]") or ""
	local label = string.format("%s%s  %.2fx  |  value %s  |  %s", category, mutationTag, scale, formatCompactNumber(entry.Value), tostring(areaId))

	if entry.State == "Dropped" then
		return label .. "  |  dropped"
	elseif entry.State == "Carried" then
		return label .. "  |  carried by a player"
	end

	return label
end

state.Steal.WrongEgg = wrongEgg

local stealTickInterval = 0.5
local postStealCooldown = 0.6
local antiStealRetryGate = 0
local postDeliveryCooldown = 0

local function stealTask()
	local generation = stealGeneration
	state.Steal.Active = true
	state.Steal.Carrying = state.Steal.Carrying == true

	if not state.Steal.Carrying then
		state.Steal.CarryUid = nil
	end

	local snapshot = buildEggSnapshot(false, true)
	local targetEntry = nil
	local carriedEntry = nil
	local lastSkipReason = nil

	for _, entry in ipairs(snapshot) do
		if entry.State == "Carried" then
			carriedEntry = carriedEntry or entry
		else
			local skipReason = state.SafeCarry.Unsafe(entry)

			if skipReason then
				lastSkipReason = lastSkipReason or skipReason
			else
				targetEntry = entry
				break
			end
		end
	end

	local targetList = { targetEntry }
	stealCurrentUid = targetEntry and targetEntry.Uid or nil
	state.Steal.Wanted = targetEntry ~= nil
	stealTargetText = formatEggLabel(targetEntry)

	if carriedEntry then
		stealTargetText = stealTargetText .. "  |  watching " .. tostring(carriedEntry.Category)
	end

	if not targetEntry then
		state.Steal.Active = false
		lastSkipReason = lastSkipReason or state.SafeCarry.LastSkip
		state.SafeCarry.LastSkip = nil
		local defaultNoMatch = state.Steal.RiftPriority
			and (next(state.Steal.RiftNeeds) == nil and "All Lab Eggs collected" or "Waiting for Lab Egg (not spawned yet)")
			or stealIndexEnabled and (next(missingIndexEggs) == nil and "All Index Eggs completed" or "Waiting for Index Egg in selected area")
			or "No egg matches"
		stealStatusText = carriedEntry and "Best egg is carried, waiting for it" or lastSkipReason and "Skipped: " .. lastSkipReason or defaultNoMatch
		return false
	end

	if not state.ClaimMovement("steal") then
		state.Steal.Active = false
		stealStatusText = "Waiting for Auto Place"
		return false
	end

	if state.Treadmill.Riding or state.OnBelt() then
		state.ExitBelt()
	end

	stealTaskRunning = true
	state.HoldBelt()

	local function deliverImmediate(reason)
		stealStatusText = reason
		local success = flyAndSteal(targetEntry, generation)
		local delivered = false
		local holdReason = nil

		if success then
			if verifyCarry(targetEntry.Uid, generation) then
				delivered = safeCarryRun(generation)
				holdReason = nil
			else
				holdReason = stealStatusText
			end
		end

		exitFlight()
		state.Steal.Active = false
		state.Steal.LastFinishedAt = os.clock()
		holdReason = delivered and "Delivered" or holdReason
		local finalStatus

		if holdReason then
			finalStatus = holdReason
		else
			finalStatus = success and "Run ended" or "That egg would not come free"
		end

		stealStatusText = finalStatus
		return true
	end

	local currentRoot = state.Root()
	local targetPosition = typeof(targetEntry.CFrame) == "CFrame" and targetEntry.CFrame.Position or nil

	if currentRoot and targetPosition then
		local alreadyClose = (targetPosition - currentRoot.Position).Magnitude <= (pickupRangeHere or 20)
		local sameArea = localPlayer:GetAttribute("AreaId") == targetEntry.AreaId
		if alreadyClose or sameArea then
			return (deliverImmediate("Target is right here, taking it"))
		end
	end

	if state.SafeCarry.Enabled and state.SafeCarry.Approach == "Run" then
		local ran = state.SafeCarry.RunTo(targetEntry, generation)
		local delivered = false
		local holdReason = nil

		if ran then
			if verifyCarry(targetEntry.Uid, generation) then
				delivered = safeCarryRun(generation)
				holdReason = nil
			else
				holdReason = stealStatusText
				delivered = false
			end
		else
			blockedEggUids[targetEntry.Uid] = os.clock() + blockedEggDuration
			holdReason = nil
			delivered = false
		end

		exitFlight()
		state.Steal.Active = false
		state.Steal.LastFinishedAt = os.clock()
		stealStatusText = delivered and "Delivered" or holdReason or (ran and "Run ended" or "That egg would not come free")
		return true
	end

	local allEntries = buildEggSnapshot(true)
	local starterPrefix = "FirstAreaEgg_" .. tostring(localPlayer.UserId)
	local starterEntries = {}

	for _, entry in ipairs(allEntries) do
		if isGuardSleeping(entry) or (type(entry.Uid) == "string" and string.sub(entry.Uid, 1, #starterPrefix) == starterPrefix) then
			table.insert(starterEntries, entry)
		end
	end

	if #starterEntries ~= 0 then
		allEntries = starterEntries
	end

	local nearestEntry, nearestDistance = findNearestEntry(allEntries)

	if not nearestEntry then
		state.Steal.Active = false
		stealStatusText = "No egg matches"
		return false
	end

	if nearestEntry.Uid == targetEntry.Uid then
		return (deliverImmediate("Target is the closest egg, taking it"))
	end

	local _, guardPosition = getGuardApproachPoint(nearestEntry)
	local chosenEntry

	if guardPosition and currentRoot then
		local bestDistance = math.huge
		chosenEntry = nearestEntry

		for _, entry in ipairs(allEntries) do
			local entryPosition = typeof(entry.CFrame) == "CFrame" and entry.CFrame.Position or nil

			if entry.Uid ~= targetEntry.Uid and entry.AreaId == nearestEntry.AreaId and entryPosition then
				local distance = (entryPosition - currentRoot.Position).Magnitude

				if teleportRange < (entryPosition - guardPosition).Magnitude then
					distance = distance + teleportRange
				end

				if distance < bestDistance then
					bestDistance = distance
					chosenEntry = entry
				end
			end
		end
	else
		chosenEntry = nearestEntry
	end

	stealStatusText = string.format("Sleeping guard egg %d studs away", math.floor(nearestDistance + 0.5))

	if not chosenEntry then
		state.Steal.Active = false
		stealStatusText = "No egg matches"
		return false
	end

	local jumpFunc = state.JumpToAndPickup or jumpToAndPickup
	local waitLandFunc = state.WaitForRagdollLand or waitForRagdollLand

	local pickedUp, trap = jumpFunc(chosenEntry, generation, false, targetList[1])

	if not pickedUp then
		state.Steal.Active = false
		return false
	end
	local finalUid = nil
	local carriedUid = targetEntry.Uid
	local listIndex = 0

	while true do
		if trap and not isStaleGeneration(generation) then
			stealStatusText = "Holding for the guard hit"

			if waitLandFunc(generation, trap, function(trapState)
				if not finalUid and carryState.Uid and carryState.Freed then
					finalUid = carryState.Uid
					trapState.Destination = carryState.Freed + Vector3.new(0, 3, 0)
					carryState.Uid = nil
					carryState.Freed = nil
					stealStatusText = "Best egg fell, jumping to it instead"
				end
			end) then
				listIndex = listIndex + 1

				if finalUid then
					carriedUid = finalUid
					followCarriedEgg(generation, finalUid)
					break
				else
					local nextEntry = targetList[listIndex]
					local nextPicked, nextTrap = jumpFunc(nextEntry, generation, true, targetList[listIndex + 1])

					if nextPicked then
						if nextEntry and type(nextEntry.Uid) == "string" then
							carriedUid = nextEntry.Uid
						end

						trap = nextTrap
						continue
					end
				end
			end
		end

		break
	end

	if not verifyCarry(carriedUid, generation) then
		local holdReason = stealStatusText
		exitFlight()
		state.Steal.Active = false
		state.Steal.LastFinishedAt = os.clock()
		stealStatusText = holdReason
		return true
	end

	local delivered = safeCarryRun(generation)
	exitFlight()
	state.Steal.Active = false
	state.Steal.LastFinishedAt = os.clock()
	stealStatusText = delivered and "Delivered" or "Run ended"
	return true
end

local eggState = modules.EggState

if type(eggState) == "table" then
	for _, signalName in ipairs({ "FieldRefreshed", "FieldShifted", "FieldGone", "SnapshotRefreshed" }) do
		local signal = eggState[signalName]

		if type(signal) == "table" and type(signal.Connect) == "function" then
			local ok, connection = pcall(signal.Connect, signal, function()
				taskScheduler.Wake()
			end)

			if ok and connection then
				registerCleanup(function()
					pcall(function()
						connection:Disconnect()
					end)
				end)
			end
		end
	end
end

taskScheduler.Add(function()
	local hasStatusRow = false

	if stealStatusRow then
		hasStatusRow = type(stealStatusRow.Set) == "function"
	end

	if hasStatusRow then
		pcall(stealStatusRow.Set, nil, stealStatusText)
	end

	local hasInfoRow = false

	if stealInfoRow then
		hasInfoRow = type(stealInfoRow.Set) == "function"
	end

	if hasInfoRow then
		pcall(stealInfoRow.Set, nil, stealTargetText)
	end

	if not state.Toggle(autoStealToggle, false) then
		return false
	end
	local nextWake, wakeKind, serverTime = checkNightOrWall()

	if nextWake then
		if wakeKind == "night" then
			beginFirstAreaWindow()
		end

		state.Movement.StealFirst = true
		state.Steal.Wanted = false

		if stealTaskRunning then
			stealGeneration = stealGeneration + 1
			state.Steal.Active = false
			exitFlight()
			state.StopWalking()
		end

		local remaining = math.max(0, math.ceil(nextWake - serverTime))

		if wakeKind == "wall" then
			stealStatusText = string.format("Field wall up, %ds", remaining)
		else
			stealStatusText = string.format("Night, going again in %ds", remaining)
		end

		return false
	end

	if firstAreaUids and firstAreaClearDeadline == math.huge then
		firstAreaClearDeadline = os.clock() + firstAreaWaitSeconds
	end

	if stealTaskRunning then
		return true
	end

	if isFirstAreaCleared() then
		stealStatusText = "Night over, waiting for the field to reset"
		taskScheduler.Wake()
		return false
	end

	local stealFirst = state.Movement.StealFirst
	local owner = state.Movement.Owner
	local waitingForOther = state.Movement.PlaceWanted and not stealFirst

	if not waitingForOther then
		waitingForOther = owner ~= nil and owner ~= "steal" and owner ~= "treadmill"
	end

	if waitingForOther then
		if os.clock() >= antiStealRetryGate then
			antiStealRetryGate = os.clock() + stealTickInterval
			local ok, result = pcall(buildEggSnapshot, false, false)
			ok = ok and type(result) == "table" and result[1] ~= nil
			state.Steal.Wanted = ok

			if ok then
				state.Movement.StealFirst = true
			end
		end

		if state.Steal.Wanted then
			owner = owner or "Auto Place"
			stealStatusText = "Egg found, waiting for " .. tostring(owner) .. " to stop"
		else
			stealStatusText = "Waiting for " .. tostring(owner or "Auto Place")
		end

		return true
	end

	if os.clock() < postDeliveryCooldown then
		return true
	end
	state.Movement.StealFirst = false
	stealTaskRunning = true

	task.spawn(function()
		local ok, err = pcall(stealTask)

		if stealTaskRunning then
			stealTaskRunning = false
			state.ReleaseBelt()
		end

		if not ok then
			exitFlight()
			state.Steal.Active = false
			if err then
				stealStatusText = "Steal error: " .. tostring(err)
				warn("[NexHub] Auto Steal task error: " .. tostring(err))
			end
		end

		local finishedUid = stealCurrentUid
		stealCurrentUid = nil
		local forcedEntry = finishedUid and forcedStealQueue[finishedUid]

		if forcedEntry and forcedEntry.Once then
			forcedStealQueue[finishedUid] = nil
		end

		carryState.Uid = nil
		carryState.Freed = nil
		carryState.Token = nil

		if stealStatusText == "Delivered" and not state.IsNight() then
			state.Movement.StealFirst = true
		end

		if not state.Steal.Wanted then
			postDeliveryCooldown = os.clock() + postStealCooldown
		end

		state.ReleaseMovement("steal")
		stealTaskRunning = false
		taskScheduler.Wake()
	end)

	return true
end)

resetAutoStealState = function()
	stealGeneration = stealGeneration + 1
	table.clear(blockedEggUids)
	state.Steal.Active = false
	state.Steal.Wanted = false
	local enabled = state.Toggle(autoStealToggle, false)
	state.Shield("steal", enabled)

	if not enabled then
		state.Movement.StealFirst = false
		table.clear(forcedStealQueue)
		table.clear(priorityStealSet)
		table.clear(cancelledSteals)
	end

	exitFlight()
	state.StopWalking()
	taskScheduler.Wake()
end

do
	local function cancelActiveRun()
		stealGeneration = stealGeneration + 1
		state.Steal.Active = false
		exitFlight()
		state.StopWalking()
	end

	local function ensureAutoStealOn()
		if state.Toggle(autoStealToggle, false) then
			return true
		end

		if autoStealToggle and type(autoStealToggle.Set) == "function" then
			pcall(autoStealToggle.Set, autoStealToggle, true)
		end

		return false
	end

	state.CancelSteal = function(uid)
		if type(uid) ~= "string" then
			return
		end
		forcedStealQueue[uid] = nil
		priorityStealSet[uid] = nil
		cancelledSteals[uid] = true

		if stealTaskRunning and stealCurrentUid == uid then
			cancelActiveRun()
		end

		taskScheduler.Wake()
	end

	state.StealQueue = function()
		local queue = {}

		for uid in pairs(forcedStealQueue) do
			table.insert(queue, uid)
		end

		table.sort(queue, function(a, b)
			local atA = forcedStealQueue[a].At
			local atB = forcedStealQueue[b].At
			if atA ~= atB then
				return atA < atB
			end
			return a < b
		end)

		return queue
	end

	state.PrioritizeSteal = function(uid)
		if type(uid) ~= "string" or isStaleGeneration(stealGeneration) then
			return
		end
		local minAt = 0

		for _, entry in pairs(forcedStealQueue) do
			if entry.At < minAt then
				minAt = entry.At
			end
		end

		forcedStealQueue[uid] = { At = minAt - 1, Once = false }
		cancelledSteals[uid] = nil
		blockedEggUids[uid] = nil

		if ensureAutoStealOn() and stealTaskRunning and not state.Steal.Carrying and stealCurrentUid ~= uid then
			cancelActiveRun()
		end

		taskScheduler.Wake()
	end

	state.MoveInPlan = function(uid, direction)
		if type(uid) ~= "string" or (direction ~= -1 and direction ~= 1) or isStaleGeneration(stealGeneration) then
			return
		end
		local plan = state.StealPlan()
		local currentIndex = table.find(plan, uid)
		local targetIndex = currentIndex and currentIndex + direction
		if not targetIndex or targetIndex < 1 or targetIndex > #plan then
			return
		end
		table.remove(plan, currentIndex)
		table.insert(plan, targetIndex, uid)
		local affectedRange = math.max(currentIndex, targetIndex)

		for i, planUid in ipairs(plan) do
			if i <= affectedRange or forcedStealQueue[planUid] then
				local entry = forcedStealQueue[planUid]

				if entry then
					entry.At = i
				else
					forcedStealQueue[planUid] = { At = i, Once = false }
				end

				cancelledSteals[planUid] = nil
			end
		end

		if stealTaskRunning and not state.Steal.Carrying and stealCurrentUid and plan[1] ~= stealCurrentUid then
			cancelActiveRun()
		end

		taskScheduler.Wake()
	end

	state.StealPlan = function()
		if not state.Toggle(autoStealToggle, false) or state.IsNight() then
			return {}, nil
		end
		local plan = {}

		if stealCurrentUid then
			table.insert(plan, stealCurrentUid)
		end

		local ok, result = pcall(buildEggSnapshot, false, true)

		if ok and type(result) == "table" then
			for _, entry in ipairs(result) do
				if entry.Uid ~= stealCurrentUid then
					table.insert(plan, entry.Uid)
				end
			end
		end

		return plan, stealCurrentUid
	end

	state.SetPriority = function(uid, wanted)
		if wanted then
			state.PrioritizeSteal(uid)
		else
			state.CancelSteal(uid)
		end
	end

	state.ResortSteal = function()
		if stealTaskRunning and not state.Steal.Carrying and stealCurrentUid and not forcedStealQueue[stealCurrentUid] then
			local ok, result = pcall(buildEggSnapshot, false, true)

			if ok and type(result) == "table" then
				local nextEntry = nil

				for _, entry in ipairs(result) do
					if entry.State ~= "Carried" then
						nextEntry = entry
						break
					else
						nextEntry = nil
					end
				end

				if not nextEntry or nextEntry.Uid ~= stealCurrentUid then
					cancelActiveRun()
				end
			end
		end

		taskScheduler.Wake()
	end

	state.StealNow = function(uid, once)
		if type(uid) ~= "string" or isStaleGeneration(stealGeneration) then
			return
		end

		if not forcedStealQueue[uid] then
			local maxAt = 0

			for _, entry in pairs(forcedStealQueue) do
				if maxAt < entry.At then
					maxAt = entry.At
				end
			end

			forcedStealQueue[uid] = { At = maxAt + 1, Once = once == true }
		end

		cancelledSteals[uid] = nil
		blockedEggUids[uid] = nil
		local shouldCancel = ensureAutoStealOn() and stealTaskRunning and not state.Steal.Carrying and stealCurrentUid ~= uid

		if shouldCancel then
			shouldCancel = not (stealCurrentUid and forcedStealQueue[stealCurrentUid])
		end

		if shouldCancel then
			cancelActiveRun()
		end

		taskScheduler.Wake()
	end
end

registerCleanup(function()
	state.GodMode(false)
	state.ReleaseMovement("steal")
	exitFlight()
end)

state.UiQueue = {}

state.UiDefer = function(callback)
	table.insert(state.UiQueue, callback)
end

state.Notify = function(title, message)
	if type(nexLibrary) == "table" and type(nexLibrary.Notify) == "function" then
		pcall(nexLibrary.Notify, title, message, 5)
	end
end

local uiQueueConnection = RunService.Heartbeat:Connect(function()
	local queue = state.UiQueue
	if #queue == 0 then
		return
	end
	state.UiQueue = {}

	for _, callback in ipairs(queue) do
		pcall(callback)
	end
end)

registerCleanup(function()
	pcall(function()
		uiQueueConnection:Disconnect()
	end)
end)

do
	local function getAssetEntry(category)
		local directory = modules.Assets and modules.Assets.Directory
		local entry = type(directory) == "table" and directory[tostring(category)] or nil
		return type(entry) == "table" and entry or nil
	end

	state.EggRarity = function(entry)
		local assetEntry = getAssetEntry(entry.AssetCategory)
		local rarity = assetEntry and assetEntry.Rarity or nil
		local rarityNumber = type(rarity) == "table" and tonumber(rarity.RarityNumber or rarity.Rank) or nil
		return rarityNumber or 0
	end

	state.EggIncome = function(entry)
		local assetEntry = getAssetEntry(entry.AssetCategory)
		local earningRate = assetEntry and tonumber(assetEntry.EarningRate) or 0
		local scale = tonumber(entry.AssetScale) or 0
		if scale <= 0 then
			return 0
		end
		local scaleFactor = scale > 5 and (scale / 5) ^ 1.2 * 19.637875755794113 or scale ^ 1.85
		local mutationsModule = modules.Mutations
		local hasEarningsFor = type(mutationsModule) == "table" and type(mutationsModule.EarningsFor) == "function"
		local mutationMultiplier = 1

		if hasEarningsFor then
			local ok, result = pcall(mutationsModule.EarningsFor, type(entry.Mutations) == "table" and entry.Mutations or {})
			mutationMultiplier = ok and type(result) == "number" and result or 1
		end

		return earningRate * scaleFactor * mutationMultiplier
	end
end

local placeEggRules = { "Always", "Steal Idle", "After Steal", "Night Only" }
local placeEggOrders = { "Biggest Size", "Highest Value", "Smallest Size", "Backpack Order" }
local placeRule = placeEggRules[1]
local placeOrder = placeEggOrders[2]
local placeRarityFilter = {}
local placeSpecificFilter = {}
local placeMinValue = 0

do
	local function refreshPlaceEgg()
		if type(state.PlaceEggRefresh) == "function" then
			state.PlaceEggRefresh()
		end
	end

	local function parseMultiSelection(selection)
		local list = {}

		if type(selection) == "table" then
			for key, value in pairs(selection) do
				local label

				if value == true and type(key) == "string" then
					label = key
				elseif type(value) == "string" then
					label = value
				end

				if label then
					table.insert(list, label)
				end
			end
		end

		return list
	end

	state.PlaceEggStatusRow = autoPlaceEggSection:CreateText({ Name = "Pen Status", Text = "Pen status unknown" })

	state.PlaceEggHandle = autoPlaceEggSection:CreateToggle({
		Name = "Auto Place Egg",
		Default = false,
		Callback = function()
			if type(state.PlaceEggRestart) == "function" then
				state.PlaceEggRestart()
			end
		end,
	})

	local placeEggHandle = state.PlaceEggHandle

	autoPlaceEggSection:CreateDropdown({
		Name = "Place Egg Rule",
		Options = placeEggRules,
		Default = placeEggRules[1],
		SubOf = placeEggHandle,
		Callback = function(selected)
			if table.find(placeEggRules, selected) then
				placeRule = selected
			end
		end,
	})

	autoPlaceEggSection:CreateDropdown({
		Name = "Place Egg Order",
		Options = placeEggOrders,
		Default = placeEggOrders[2],
		SubOf = placeEggHandle,
		Callback = function(selected)
			if table.find(placeEggOrders, selected) then
				placeOrder = selected
			end
		end,
	})

	local rarityOptionsForPlace = {}

	for i = 2, #rarityOptions do
		table.insert(rarityOptionsForPlace, rarityOptions[i])
	end

	if #rarityOptionsForPlace > 0 then
		fixDropdownAll(autoPlaceEggSection:CreateMultiDropdown({
			Name = "Place Rarities",
			Note = "Only place eggs of the picked rarities (empty = all)",
			Options = rarityOptionsForPlace,
			Default = {},
			SubOf = placeEggHandle,
			Callback = function(selection)
				local filter = {}

				for _, label in ipairs(parseMultiSelection(selection)) do
					local rarityNumber = rarityNumberMap[label]

					if rarityNumber and rarityNumber > 0 then
						filter[rarityNumber] = true
					end
				end

				placeRarityFilter = filter
				refreshPlaceEgg()
			end,
		}))
	end

	do
		local specificEggOptions = {}
		local specificEggMap = {}
		local assetDirectory = modules.Assets and modules.Assets.Directory
		local eggList = {}

		if type(assetDirectory) == "table" then
			for category, entry in pairs(assetDirectory) do
				local rarity = type(entry) == "table" and entry.Rarity or nil
				local rarityNumber = type(rarity) == "table" and tonumber(rarity.RarityNumber or rarity.Rank) or nil

				if rarityNumber then
					local displayName = entry.DisplayName or category
					table.insert(eggList, {
						Category = tostring(category),
						Name = tostring(displayName),
						Rarity = rarityNumber,
						RarityName = tostring(rarity.DisplayName or rarity._id or rarityNumber),
					})
				end
			end
		end

		table.sort(eggList, function(a, b)
			if a.Rarity ~= b.Rarity then
				return a.Rarity > b.Rarity
			end
			return a.Name < b.Name
		end)

		for _, item in ipairs(eggList) do
			local label = string.format("%s [%s]", item.Name, item.RarityName)
			if specificEggMap[label] then
				label = string.format("%s [%s] (%s)", item.Name, item.RarityName, item.Category)
			end
			table.insert(specificEggOptions, label)
			specificEggMap[label] = item.Category
		end

		if #specificEggOptions > 0 then
			fixDropdownAll(autoPlaceEggSection:CreateMultiDropdown({
				Name = "Place Specific Eggs",
				Note = "Only place these eggs (empty = all)",
				Options = specificEggOptions,
				Default = {},
				SubOf = placeEggHandle,
				Callback = function(selection)
					local filter = {}

					for _, label in ipairs(parseMultiSelection(selection)) do
						if specificEggMap[label] then
							filter[specificEggMap[label]] = true
						end
					end

					placeSpecificFilter = filter
					refreshPlaceEgg()
				end,
			}))
		end
	end

	do
		local valueUnits = {
			["K/s"] = { Min = 0, Max = 1000, Mult = 1000 },
			["M/s"] = { Min = 0, Max = 1000, Mult = 1000000 },
			["B/s"] = { Min = 0, Max = 100, Mult = 1e9 },
		}

		local minValueInput = 0
		local minValueUnit = "M/s"

		local function applyMinValue(value, unit)
			if value ~= nil then
				minValueInput = math.max(0, math.floor(tonumber(value) or minValueInput))
			end

			if unit ~= nil then
				minValueUnit = tostring(unit)
			end

			placeMinValue = minValueInput * (valueUnits[minValueUnit] or valueUnits["M/s"]).Mult
		end

		createValueSlider(autoPlaceEggSection, {
			Name = "Min Place Value",
			Note = "Skip eggs worth less than this (0 = off)",
			SubOf = placeEggHandle,
			Legacy = "Place Min Value",
			SectionName = "Auto Place Egg",
			OnRaw = function(value)
				applyMinValue(math.floor(value / 1000), "K/s")
			end,
		})
	end
end

do
	local flyTolerance = 3.5
	local penArrivalRange = 26
	local failCooldown = 6
	local maxSlotTries = 8
	local cooldownUntil = 0
	local maxEggsToPlace = 30
	local afterStealWindow = 12
	local placeEggHandle = nil
	local placeEggStatusRow = nil
	local placeStatusText = "Pen status unknown"
	local placeBusy = false
	local blockedPlaceUids = {}
	local placeGeneration = 0
	local lastPlacedCount = nil
	local placeFlyHeight = 30

	local function invokeRemote(name, arg)
		local remote = networking:FindFirstChild(name)
		if not remote or not remote:IsA("RemoteFunction") then
			return false, nil
		end
		return pcall(remote.InvokeServer, remote, arg)
	end

	local function getPlaceAssetEntry(entry)
		local directory = modules.Assets and modules.Assets.Directory
		local assetEntry = type(directory) == "table" and directory[tostring(entry.AssetCategory)] or nil
		return type(assetEntry) == "table" and assetEntry or nil
	end

	local function getPlaceRarity(entry)
		local assetEntry = getPlaceAssetEntry(entry)
		local rarity = assetEntry and assetEntry.Rarity or nil
		local rarityNumber = type(rarity) == "table" and tonumber(rarity.RarityNumber or rarity.Rank) or nil
		return rarityNumber or 0
	end

	local function computePlaceIncome(entry)
		local assetEntry = getPlaceAssetEntry(entry)
		local earningRate = assetEntry and tonumber(assetEntry.EarningRate) or 0
		local scale = tonumber(entry.AssetScale) or 0
		if scale <= 0 then
			return 0
		end
		local scaleFactor = scale > 5 and (scale / 5) ^ 1.2 * 19.637875755794113 or scale ^ 1.85
		local mutationsModule = modules.Mutations
		local hasEarningsFor = type(mutationsModule) == "table" and type(mutationsModule.EarningsFor) == "function"
		local mutationMultiplier = 1

		if hasEarningsFor then
			local ok, result = pcall(mutationsModule.EarningsFor, type(entry.Mutations) == "table" and entry.Mutations or {})
			mutationMultiplier = ok and type(result) == "number" and result or 1
		end

		return earningRate * scaleFactor * mutationMultiplier
	end

	local function collectBackpackOrder()
		local order = {}
		local backpack = localPlayer:FindFirstChildOfClass("Backpack")
		if not backpack then
			return order
		end
		local count = 0

		for _, child in ipairs(backpack:GetChildren()) do
			local uid = child:GetAttribute("UID")

			if type(uid) == "string" then
				count = count + 1
				order[uid] = count
			end
		end

		return order
	end

	local function collectPlaceCandidates()
		local eggState = modules.EggState
		if type(eggState) ~= "table" or type(eggState.ReadOwnerEggs) ~= "function" then
			return {}
		end
		local ok, result = pcall(eggState.ReadOwnerEggs, localPlayer.UserId)
		if not ok or type(result) ~= "table" then
			return {}
		end
		local backpackOrder = collectBackpackOrder()
		local candidates = {}

		for uid, entry in pairs(result) do
			if type(entry) == "table" and entry.Placement == nil and not blockedPlaceUids[uid] then
				local income = computePlaceIncome(entry)
				local category = tostring(entry.AssetCategory)
				local passesRarity = next(placeRarityFilter) == nil or placeRarityFilter[getPlaceRarity(entry)] == true
				local passesSpecific = next(placeSpecificFilter) == nil or placeSpecificFilter[category] == true
				local passesValue = placeMinValue <= 0 or income >= placeMinValue

				if passesRarity and passesSpecific and passesValue then
					table.insert(candidates, {
						Uid = uid,
						Scale = tonumber(entry.AssetScale) or 0,
						Income = income,
						Slot = backpackOrder[uid] or math.huge,
					})
				end
			end
		end

		table.sort(candidates, function(a, b)
			if placeOrder == placeEggOrders[2] and a.Income ~= b.Income then
				return a.Income > b.Income
			end

			if placeOrder == placeEggOrders[3] and a.Scale ~= b.Scale then
				return a.Scale < b.Scale
			end

			if placeOrder == placeEggOrders[4] and a.Slot ~= b.Slot then
				return a.Slot < b.Slot
			end
			return a.Scale > b.Scale
		end)

		return candidates
	end

	local function canPlaceNow(candidateCount)
		if candidateCount == 0 then
			return false
		end
		local steal = state.Steal
		if placeRule == placeEggRules[2] then
			return not steal.Active and not steal.Carrying
		end

		if placeRule == placeEggRules[3] then
			local afterSteal = steal.LastFinishedAt > 0

			if afterSteal then
				afterSteal = os.clock() - steal.LastFinishedAt <= afterStealWindow
			end

			return afterSteal
		end

		if placeRule == placeEggRules[4] then
			return state.IsNight()
		end
		return true
	end

	local function countPlacementSlots()
		local eggState = modules.EggState
		local canReadOwner = type(eggState) == "table" and type(eggState.ReadOwnerEggs) == "function"
		local placedCount = 0

		if canReadOwner then
			local ok, result = pcall(eggState.ReadOwnerEggs, localPlayer.UserId)

			if ok and type(result) == "table" then
				for _, entry in pairs(result) do
					if type(entry) == "table" and entry.Placement ~= nil then
						placedCount = placedCount + 1
					end
				end
			end
		end

		local saveModule = modules.Save
		local hasSaveGet = type(saveModule) == "table" and type(saveModule.Get) == "function"
		local saveData = nil

		if hasSaveGet then
			local ok, result = pcall(saveModule.Get)
			saveData = ok and type(result) == "table" and result or nil
		end

		local hasEquipped = saveData and type(saveData.EquippedAssets) == "table"
		local equippedCount = 0

		if hasEquipped then
			for _ in pairs(saveData.EquippedAssets) do
				equippedCount = equippedCount + 1
			end
		end

		local basesModule = requireModule(function()
			return ReplicatedStorage.Data.Bases
		end)

		local hasCapacityFn = type(basesModule) == "table" and type(basesModule.GetAssetEquipCapacity) == "function"
		local capacity = nil

		if hasCapacityFn then
			local ok, result = pcall(basesModule.GetAssetEquipCapacity, saveData and tonumber(saveData.BaseUpgradeLevel) or 0)
			capacity = ok and tonumber(result) or nil
		end

		if not capacity then
			local remote = networking:FindFirstChild("RF/PenRoster/AskWearLimit")

			if remote and remote:IsA("RemoteFunction") then
				local ok, result = pcall(remote.InvokeServer, remote)
				capacity = ok and tonumber(result) or nil
			end
		end

		capacity = capacity or 0
		return capacity - placedCount - equippedCount, capacity, placedCount, equippedCount
	end

	local function collectPenEggPositions()
		local eggState = modules.EggState
		local positions = {}
		if type(eggState) ~= "table" or type(eggState.ReadOwnerEggs) ~= "function" then
			return positions
		end
		local ok, result = pcall(eggState.ReadOwnerEggs, localPlayer.UserId)
		if not ok or type(result) ~= "table" then
			return positions
		end

		for _, entry in pairs(result) do
			local placement = type(entry) == "table" and entry.Placement or nil
			local localCFrame = type(placement) == "table" and placement.LocalCFrame or nil

			if typeof(localCFrame) == "CFrame" then
				table.insert(positions, Vector2.new(localCFrame.Position.X, localCFrame.Position.Z))
			end
		end

		return positions
	end

	local slotRandom = Random.new()

	local function buildSlotGrid(occupiedPositions)
		local slots = {}

		for x = -24, 8, 4 do
			for z = 4, 30, 4 do
				local slotPosition = Vector2.new(x, z)
				local blocked = false

				for _, occupied in ipairs(occupiedPositions) do
					if (occupied - slotPosition).Magnitude < flyTolerance then
						blocked = true
						break
					end
				end

				if not blocked then
					table.insert(slots, CFrame.new(x, -0.5, z))
				end
			end
		end

		for i = #slots, 2, -1 do
			local j = slotRandom:NextInteger(1, i)
			slots[i], slots[j] = slots[j], slots[i]
		end

		return slots
	end

	local function refreshPenStatus()
		local freeSlots, capacity, placedCount, equippedCount = countPlacementSlots()
		local eggState = modules.EggState
		local canReadOwner = type(eggState) == "table" and type(eggState.ReadOwnerEggs) == "function"
		local inBag = 0

		if canReadOwner then
			local ok, result = pcall(eggState.ReadOwnerEggs, localPlayer.UserId)

			if ok and type(result) == "table" then
				for _, entry in pairs(result) do
					if type(entry) == "table" and entry.Placement == nil then
						inBag = inBag + 1
					end
				end
			end
		end

		placeStatusText = string.format(
			"Eggs placed %d/%d  -  %d/%d pets equipped, %d in bag",
			placedCount,
			30,
			equippedCount,
			capacity,
			inBag
		)
		return freeSlots, placedCount
	end

	local function flyToPoint(targetPosition, cancelledFn)
		local root = state.Root()
		if not root then
			return false
		end
		local speed = (type(flySpeed) == "number" and flySpeed > 0) and flySpeed or 400
		local startPosition = root.Position
		local duration = (targetPosition - startPosition).Magnitude / math.max(speed, 1) + 8
		local outcome = nil
		local elapsed = 0

		local connection = RunService.Heartbeat:Connect(function(deltaTime)
			if outcome ~= nil or state.AntiGuard.Busy then
				return
			end
			elapsed = elapsed + deltaTime
			local currentRoot = state.Root()
			if not currentRoot or (type(cancelledFn) == "function" and cancelledFn()) or elapsed > duration then
				outcome = false
				return
			end

			if (currentRoot.Position - startPosition).Magnitude > 6 then
				startPosition = currentRoot.Position
			end

			local delta = targetPosition - startPosition
			local step = speed * deltaTime
			local arrived = delta.Magnitude <= math.max(step, 0.05)
			startPosition = arrived and targetPosition or startPosition + delta.Unit * step
			local horizontal = Vector3.new(delta.X, 0, delta.Z)
			local lookCframe = horizontal.Magnitude > 0.05 and CFrame.lookAt(Vector3.zero, horizontal.Unit) or currentRoot.CFrame.Rotation

			pcall(function()
				currentRoot.CFrame = CFrame.new(startPosition) * lookCframe
				currentRoot.AssemblyLinearVelocity = Vector3.zero
				currentRoot.AssemblyAngularVelocity = Vector3.zero
			end)

			if arrived then
				outcome = true
			end
		end)

		while outcome == nil do
			RunService.Heartbeat:Wait()
		end

		connection:Disconnect()
		return outcome
	end

	local function getSeparationLineX()
		local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
		world = world and world:FindFirstChild("Areas")
		world = world and world:FindFirstChild("SeparationLine")
		return world and world:IsA("BasePart") and world.Position.X or 552
	end

	local flyToPen = nil

	local function getHomeAnchor(position)
		local root = state.Root()
		if not root or type(state.StealHome) ~= "function" then
			return nil
		end
		local lineX = getSeparationLineX()
		if root.Position.X < lineX == position.X < lineX then
			return nil
		end
		local ok, home = pcall(state.StealHome)
		if not ok or typeof(home) ~= "Vector3" then
			return nil
		end

		if (home - position).Magnitude <= 12 or (root.Position - home).Magnitude <= 12 then
			return nil
		end
		return home
	end

	flyToPen = function(destination, cancelledFn, shieldKey, isInner)
		local root = state.Root()
		if not root then
			return false
		end

		if not isInner then
			local homeAnchor = getHomeAnchor(destination)
			if homeAnchor and not flyToPen(homeAnchor, cancelledFn, shieldKey, true) then
				return false
			end

			if cancelledFn and cancelledFn() then
				return false
			end
			root = state.Root()
			if not root then
				return false
			end
		end

		state.Shield(shieldKey or "place", true)
		state.Driving = state.Driving + 1
		task.wait(0.2)
		local targetPosition = destination + Vector3.new(0, 3, 0)
		local flyY = math.max(root.Position.Y, targetPosition.Y) + placeFlyHeight

		local ok, result = pcall(function()
			return flyToPoint(Vector3.new(root.Position.X, flyY, root.Position.Z), cancelledFn)
				and flyToPoint(Vector3.new(targetPosition.X, flyY, targetPosition.Z), cancelledFn)
				and flyToPoint(targetPosition, cancelledFn)
		end)

		ok = ok and result == true
		state.Driving = math.max(0, state.Driving - 1)
		state.Shield(shieldKey or "place", false)
		return ok
	end

	state.FlyTo = function(destination, cancelledFn, shieldKey)
		return flyToPen(destination, cancelledFn, shieldKey or "fly")
	end

	local placeEggLoop = nil

	local function ensurePenReachable(penAnchor, cancelledFn)
		if state.DistanceTo(penAnchor) <= penArrivalRange then
			return true
		end

		if cancelledFn and cancelledFn() then
			return false
		end
		placeStatusText = "Pen out of reach, flying back"
		return flyToPen(penAnchor, cancelledFn) and state.DistanceTo(penAnchor) <= penArrivalRange
	end

	placeEggLoop = function()
		local eggState = modules.EggState
		if type(eggState) ~= "table" or type(eggState.PlantEgg) ~= "function" then
			return false
		end
		local candidates = collectPlaceCandidates()
		if not canPlaceNow(#candidates) then
			return false
		end
		refreshPenStatus()
		local freeSlots, capacity, placedCount, equippedCount = countPlacementSlots()
		local maxToPlace = math.max(0, maxEggsToPlace - (tonumber(placedCount) or 0))
		if maxToPlace <= 0 then
			return false
		end
		local penAnchor = state.PenAnchor()
		if not penAnchor then
			return false
		end
		state.Movement.PlaceWanted = true
		if not state.ClaimMovement("place") then
			return "waiting"
		end
		local myGeneration = placeGeneration

		local function shouldStop()
			if myGeneration ~= placeGeneration or not state.Toggle(placeEggHandle, false) then
				return true
			end

			if state.IsNight() then
				return false
			end
			return placeRule == placeEggRules[4] or state.Movement.StealFirst
		end

		if state.Treadmill.Riding or state.OnBelt() then
			state.ExitBelt()
		end

		local function shieldedFly()
			state.HoldBelt()
			local ok, result = pcall(flyToPen, penAnchor, shouldStop)
			state.ReleaseBelt()
			return ok and result and true or false
		end

		if penArrivalRange < state.DistanceTo(penAnchor) then
			placeStatusText = "Flying to the pen"

			if not shieldedFly() then
				state.LeaveBelt()
				cooldownUntil = os.clock() + failCooldown
				return false
			end
		end

		state.LeaveBelt()
		if shouldStop() then
			return false
		end

		local function ensureAtPen()
			if state.DistanceTo(penAnchor) <= penArrivalRange then
				return true
			end

			if shouldStop() then
				return false
			end
			placeStatusText = "Pen out of reach, flying back"
			return shieldedFly() and state.DistanceTo(penAnchor) <= penArrivalRange
		end

		if not ensureAtPen() then
			placeStatusText = "Could not reach the pen, trying again soon"
			cooldownUntil = os.clock() + failCooldown
			return false
		end

		local occupiedPositions = collectPenEggPositions()
		local placedThisRun = 0
		local consecutiveFails = 0

		for _, candidate in ipairs(candidates) do
			if not (placedThisRun >= maxToPlace or shouldStop()) then
				if not ensureAtPen() then
					placeStatusText = "Pen out of reach, stopping this pass"
					break
				else
					local ok, result = pcall(eggState.WearEggTool, candidate.Uid)

					if ok and result ~= false then
						task.wait(0.15)
						local tries = 0
						local placed = false

						for _, slotCFrame in ipairs(buildSlotGrid(occupiedPositions)) do
							if not (shouldStop() or tries >= maxSlotTries) then
								tries = tries + 1
								local placeOk, placeResult = invokeRemote("RF/EggWorld/AskPlaceEgg", {
									Uid = candidate.Uid,
									LocalCFrame = slotCFrame,
								})

								if placeOk and placeResult ~= false then
									table.insert(occupiedPositions, Vector2.new(slotCFrame.Position.X, slotCFrame.Position.Z))
									placedThisRun = placedThisRun + 1
									placed = true
									break
								else
									continue
								end
							end

							break
						end

						if placed then
							consecutiveFails = 0
							continue
						else
							blockedPlaceUids[candidate.Uid] = true
							consecutiveFails = consecutiveFails + 1
							if not (consecutiveFails >= 2) then
								continue
							end
						end
					else
						blockedPlaceUids[candidate.Uid] = true
						continue
					end
				end
			end

			break
		end

		if type(eggState.DoffEggTool) == "function" then
			pcall(eggState.DoffEggTool)
		end

		if placedThisRun == 0 then
			cooldownUntil = os.clock() + failCooldown
		end

		return placedThisRun > 0
	end

	taskScheduler.Add(function()
		local freeSlots, placedCount = refreshPenStatus()

		if placeEggStatusRow and type(placeEggStatusRow.Set) == "function" then
			pcall(placeEggStatusRow.Set, placeEggStatusRow, placeStatusText)
		end

		local placedNumber = tonumber(placedCount)
		local placedDropped = placedNumber ~= nil and lastPlacedCount ~= nil and placedNumber < lastPlacedCount

		if placedNumber then
			lastPlacedCount = placedNumber
		end

		if placedDropped then
			table.clear(blockedPlaceUids)
		end

		if not state.Toggle(placeEggHandle, false) then
			state.Movement.PlaceWanted = false
			state.ReleaseMovement("place")
			return false
		end

		if placeBusy then
			return false
		end

		if os.clock() < cooldownUntil then
			state.Movement.PlaceWanted = false
			return false
		end

		if state.Movement.StealFirst and not state.IsNight() then
			state.Movement.PlaceWanted = false
			return false
		end
		placeBusy = true

		task.spawn(function()
			local ok, result = pcall(placeEggLoop)

			if not (ok and result == "waiting") then
				state.Movement.PlaceWanted = false
			end

			state.ReleaseMovement("place")
			placeBusy = false
			taskScheduler.Wake()
		end)

		return false
	end)

	placeEggHandle = state.PlaceEggHandle
	placeEggStatusRow = state.PlaceEggStatusRow

	state.PlaceEggRestart = function()
		table.clear(blockedPlaceUids)
		placeGeneration = placeGeneration + 1
		state.StopWalking()
		taskScheduler.Wake()
	end

	state.PlaceEggRefresh = function()
		table.clear(blockedPlaceUids)
		taskScheduler.Wake()
	end
end

local saveModule = modules.Save

if type(saveModule) == "table" and type(saveModule.FieldSignal) == "function" then
	for _, fieldName in ipairs({ "EggInventory", "EquippedAssets", "BaseUpgradeLevel" }) do
		local ok, signal = pcall(saveModule.FieldSignal, fieldName)

		if ok and type(signal) == "table" and type(signal.Connect) == "function" then
			local ok2, connection = pcall(signal.Connect, signal, function()
				taskScheduler.Wake()
			end)

			if ok2 and connection then
				registerCleanup(function()
					pcall(function()
						connection:Disconnect()
					end)
				end)
			end
		end
	end
end

state.Steal.HeldByMe = function()
	local carryUid = state.Steal.CarryUid
	local character = localPlayer.Character
	if type(carryUid) ~= "string" or not character then
		return false
	end
	local eggModel = workspace:FindFirstChild(carryUid)
	if not eggModel then
		return false
	end

	for _, descendant in ipairs(eggModel:GetDescendants()) do
		if descendant:IsA("WeldConstraint") or descendant:IsA("JointInstance") then
			local ok, partA, partB = pcall(function()
				return descendant.Part0, descendant.Part1
			end)

			if ok and (partA and partA:IsDescendantOf(character) or partB and partB:IsDescendantOf(character)) then
				return true
			end
		end
	end

	return false
end

do
	local checkInterval = 0.2
	local elapsedSinceCheck = 0

	local connection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsedSinceCheck = elapsedSinceCheck + deltaTime
		if elapsedSinceCheck < checkInterval then
			return
		end
		elapsedSinceCheck = 0
		local steal = state.Steal

		if not steal.Carrying then
			if steal.GuessedDrop then
				local ok, held = pcall(steal.HeldByMe)

				if ok and held then
					steal.GuessedDrop = false
					steal.Carrying = true
					steal.HeldSeenAt = os.clock()
				end
			end

			return
		end

		local ok, held = pcall(steal.HeldByMe)
		if not ok or held then
			steal.HeldSeenAt = os.clock()
			return
		end

		if os.clock() - (steal.HeldSeenAt or 0) > 0.8 then
			steal.Carrying = false
			steal.GuessedDrop = true
			steal.LastFinishedAt = os.clock()
			taskScheduler.Wake()
		end
	end)

	registerCleanup(function()
		pcall(function()
			connection:Disconnect()
		end)
	end)
end

do
	local eggState = modules.EggState
	local carryChanged = type(eggState) == "table" and eggState.CarryChanged or nil

	if type(carryChanged) == "table" and type(carryChanged.Connect) == "function" then
		local ok, connection = pcall(carryChanged.Connect, carryChanged, function(payload)
			local carrying = type(payload) == "table" and payload.IsCarrying == true

			if state.Steal.Carrying and not carrying then
				state.Steal.LastFinishedAt = os.clock()
			end

			state.Steal.GuessedDrop = false

			if carrying then
				state.Steal.HeldSeenAt = os.clock()
			end

			if carrying and type(payload.Uid) == "string" then
				state.Steal.CarryUid = payload.Uid
				state.Steal.CarryAreaId = payload.AreaId
				local mult = tonumber(payload.SpeedMultiplier)

				if mult and mult > 0 then
					state.SafeCarry.Mult = mult
					state.SafeCarry.Category = payload.AssetCategory

					if payload.AssetCategory ~= nil then
						local category = tostring(payload.AssetCategory)
						state.SafeCarry.Seen[category] = math.min(state.SafeCarry.Seen[category] or mult, mult)
					end
				end
			end

			state.Steal.Carrying = carrying
			taskScheduler.Wake()
		end)

		if ok and connection then
			registerCleanup(function()
				pcall(function()
					connection:Disconnect()
				end)
			end)
		end
	end
end

pcall(function()
	local redeemVerdict = networking:FindFirstChild("RE/EggWorld/FieldEggRedeemVerdict")
	local alertsRaise = networking:FindFirstChild("RE/Alerts/Raise")

	if redeemVerdict and redeemVerdict:IsA("RemoteEvent") then
		local connection = redeemVerdict.OnClientEvent:Connect(function()
			state.SafeCarry.LastDelivered = os.clock()
		end)

		registerCleanup(function()
			connection:Disconnect()
		end)
	end

	if alertsRaise and alertsRaise:IsA("RemoteEvent") then
		local connection = alertsRaise.OnClientEvent:Connect(function(payload)
			if type(payload) == "table" and type(payload.Text) == "string" and string.find(payload.Text, "Delivery failed", 1, true) then
				state.SafeCarry.LastFailed = os.clock()
			end
		end)

		registerCleanup(function()
			connection:Disconnect()
		end)
	end
end)

do
	local treadmillFlyRange = 10
	local idleBeforeExit = 1
	local treadmillRecheckInterval = 5

	local function invokeTreadmillRemote(name)
		local remote = (networking and (networking:FindFirstChild(name, true) or networking:FindFirstChild(name)))
			or ReplicatedStorage:FindFirstChild(name, true)
		if not remote or not remote:IsA("RemoteFunction") then
			return false, nil, nil
		end
		local ok, result, message = pcall(remote.InvokeServer, remote)
		return ok, result, message
	end

	local notGroundedStrikes = 0
	local undoSwapApplied = false

	local function handleMountResult(ok, result, message)
		if ok and result ~= false then
			notGroundedStrikes = 0
			undoSwapApplied = false
			return true
		end

		if ok and tostring(message) == "Already using treadmill" then
			notGroundedStrikes = 0
			undoSwapApplied = false
			return true
		end

		if ok and tostring(message) == "Not grounded" and state.Grounded() then
			notGroundedStrikes = notGroundedStrikes + 1

			if notGroundedStrikes >= 2 then
				notGroundedStrikes = 0

				if not undoSwapApplied then
					undoSwapApplied = true
					pcall(state.UndoSwap)
				elseif type(state.RequestRespawn) == "function" then
					undoSwapApplied = false
					state.RequestRespawn()
				end
			end
		end

		return false
	end

	local autoTreadmillToggle = nil
	local stayOnTreadmillToggle = nil
	local treadmillStatusRow = nil
	local treadmillBusy = false
	local treadmillGeneration = 0
	local disposed = false
	local treadmill = state.Treadmill

	local function updateTreadmillStatus(text)
		if treadmillStatusRow and type(treadmillStatusRow.Set) == "function" then
			pcall(treadmillStatusRow.Set, nil, text)
		end
	end

	local function isAutoTreadmillOn()
		return state.Toggle(autoTreadmillToggle, false)
	end

	local function isMovementBlocked()
		local movement = state.Movement
		return (movement.PlaceWanted and movement.Owner == "place")
			or movement.FracturedWanted
			or (movement.Owner ~= nil and movement.Owner ~= "treadmill")
			or (state.Steal.Active and state.Steal.Wanted)
			or state.Steal.Carrying
	end

	local function mountTreadmill()
		local myGeneration = treadmillGeneration
		if isMovementBlocked() or not state.ClaimMovement("treadmill") then
			updateTreadmillStatus("Waiting (Movement busy)")
			return false
		end

		local function isMountCancelled()
			return myGeneration ~= treadmillGeneration
				or not isAutoTreadmillOn()
				or state.Movement.Owner ~= "treadmill"
				or isMovementBlocked()
		end

		if state.BeltHeld() then
			state.ResetBelt()
		end

		updateTreadmillStatus("Finding treadmill belt...")
		local belt = state.Belt()
		if not belt then
			updateTreadmillStatus("Treadmill belt not found")
			return false
		end
		local beltPos = belt:IsA("BasePart") and belt.Position or (belt:IsA("Model") and belt:GetPivot().Position) or belt.Position
		local beltSizeY = belt:IsA("BasePart") and belt.Size.Y or 2
		local beltTop = beltPos + Vector3.new(0, beltSizeY / 2, 0)

		if state.DistanceTo(beltTop + Vector3.new(0, 2, 0)) > treadmillFlyRange then
			updateTreadmillStatus("Flying to treadmill...")
			if type(state.FlyTo) ~= "function" or not state.FlyTo(beltTop, isMountCancelled, "treadmill") then
				updateTreadmillStatus("Failed flying to treadmill")
				return false
			end
		end

		if isMountCancelled() then
			return false
		end

		updateTreadmillStatus("Landing on belt...")
		local settleStart = os.clock()
		while os.clock() - settleStart < 1.2 and not state.Grounded() do
			task.wait(0.1)
		end

		if isMountCancelled() then
			return false
		end

		updateTreadmillStatus("Mounting treadmill...")
		treadmill.Riding = handleMountResult(invokeTreadmillRemote("RF/Treadmill/AskWearStill"))
		if treadmill.Riding then
			updateTreadmillStatus("Running on treadmill")
		else
			updateTreadmillStatus("Mount failed (retrying)")
		end
		return treadmill.Riding
	end

	taskScheduler.Add(function()
		if not isAutoTreadmillOn() then
			if treadmill.Riding and not treadmillBusy then
				treadmillBusy = true

				task.spawn(function()
					pcall(state.ExitBelt)
					treadmillBusy = false
					updateTreadmillStatus("Off")
					taskScheduler.Wake()
				end)
			else
				updateTreadmillStatus("Off")
			end

			return false
		end

		if treadmillBusy or isMovementBlocked() then
			updateTreadmillStatus("Waiting (Movement busy)")
			return false
		end

		if treadmill.Riding and state.Toggle(stayOnTreadmillToggle, true) and state.OnBelt() then
			updateTreadmillStatus("Running on treadmill")
			if os.clock() >= (treadmill.NextCheck or 0) and not state.Flying and state.Grounded() then
				treadmill.NextCheck = os.clock() + treadmillRecheckInterval
				treadmillBusy = true

				task.spawn(function()
					local ok, result = pcall(function()
						return handleMountResult(invokeTreadmillRemote("RF/Treadmill/AskWearStill"))
					end)

					treadmill.Riding = ok and result == true

					if not treadmill.Riding then
						treadmill.NextTry = 0
						updateTreadmillStatus("Mount lost (retrying)")
					else
						updateTreadmillStatus("Running on treadmill")
					end

					treadmillBusy = false
					taskScheduler.Wake()
				end)
			end

			return false
		end

		if os.clock() < (treadmill.NextTry or 0) then
			return false
		end
		treadmill.NextCheck = 0
		treadmill.NextTry = os.clock() + (treadmill.LastFailed and 3 or 4)
		treadmillBusy = true

		task.spawn(function()
			local ok, result = pcall(mountTreadmill)
			treadmill.LastFailed = not (ok and result == true)
			state.ReleaseMovement("treadmill")
			treadmillBusy = false
			taskScheduler.Wake()
		end)

		return false
	end)

	task.spawn(function()
		while not disposed do
			task.wait(3)

			if not isAutoTreadmillOn() and not isMovementBlocked() and not state.Flying and state.OnBelt() and state.Grounded() then
				handleMountResult(invokeTreadmillRemote("RF/Treadmill/AskWearStill"))
			end
		end
	end)

	task.spawn(function()
		local elapsedOffBelt = 0

		while not disposed do
			local delta = task.wait(0.25)

			if not isAutoTreadmillOn() or not treadmill.Riding or isMovementBlocked() then
				elapsedOffBelt = 0
			elseif state.OnBelt() then
				elapsedOffBelt = 0
			else
				elapsedOffBelt = elapsedOffBelt + delta

				if elapsedOffBelt >= 1.5 then
					treadmill.Riding = false
					treadmill.NextTry = 0
					updateTreadmillStatus("Fell off belt (retrying)")
					taskScheduler.Wake()
					elapsedOffBelt = 0
				end
			end
		end
	end)

	task.spawn(function()
		local exitCooldown = 0
		local stuckTimer = 0
		local lastPosition = nil

		while not disposed do
			local delta = task.wait(0.25)
			exitCooldown = math.max(0, exitCooldown - delta)
			local ridingAndActive = treadmill.Riding and isAutoTreadmillOn() and not isMovementBlocked()
			local root = state.Root()
			local humanoid = localPlayer.Character
			humanoid = humanoid and humanoid:FindFirstChildOfClass("Humanoid")

			local isMoving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
			local blocked = state.Flying or (state.Movement.Owner ~= nil and state.Movement.Owner ~= "treadmill") or (state.Movement.PlaceWanted and state.Movement.Owner == "place") or isMoving

			if ridingAndActive or not blocked or not root or not state.OnBelt() then
				lastPosition = root and root.Position
				stuckTimer = 0
				lastPosition = lastPosition or nil
			else
				local horizontal = Vector3.new(root.Position.X, 0, root.Position.Z)
				local stuck = lastPosition and (horizontal - Vector3.new(lastPosition.X, 0, lastPosition.Z)).Magnitude < 0.5

				if stuck then
					stuckTimer = stuckTimer + delta
				else
					stuckTimer = 0
				end

				lastPosition = root.Position

				if stuckTimer >= idleBeforeExit and exitCooldown <= 0 then
					pcall(state.ExitBelt)
					exitCooldown = 1.5
					stuckTimer = 0
				end
			end
		end
	end)

	registerCleanup(function()
		disposed = true
		treadmill.Riding = false
	end)

	treadmillStatusRow = autoTreadmillSection:CreateText({
		Name = "Status",
		Text = "Off",
	})

	autoTreadmillToggle = autoTreadmillSection:CreateToggle({
		Name = "Auto Treadmill",
		Default = false,
		Callback = function(val)
			treadmillGeneration = treadmillGeneration + 1
			state.StopWalking()
			if not val and treadmill.Riding then
				pcall(state.ExitBelt)
				updateTreadmillStatus("Off")
			end
			taskScheduler.Wake()
		end,
	})

	stayOnTreadmillToggle = autoTreadmillSection:CreateToggle({ Name = "Stay On Treadmill", Default = true })
end

do
	local maxHatchPerPass = 4
	local hatchRetryCooldown = 10
	local autoHatchToggle = nil
	local hatchBusy = false
	local hatchGeneration = 0
	local failedHatchUids = {}
	local hatchFilter = { MinRarity = 0, MinIncome = 0, Eggs = {} }

	local function invokeHatchRemote(name, arg)
		local remote = networking:FindFirstChild(name)
		if not remote or not remote:IsA("RemoteFunction") then
			return false, nil
		end
		return pcall(remote.InvokeServer, remote, arg)
	end

	local function passesHatchFilter(entry)
		if hatchFilter.MinRarity > 0 then
			if state.EggRarity(entry) < hatchFilter.MinRarity then
				return false
			end
		end

		if hatchFilter.MinIncome > 0 then
			if state.EggIncome(entry) < hatchFilter.MinIncome then
				return false
			end
		end

		if next(hatchFilter.Eggs) ~= nil and hatchFilter.Eggs[tostring(entry.AssetCategory)] ~= true then
			return false
		end
		return true
	end

	local function collectHatchableEggs()
		local eggState = modules.EggState
		if type(eggState) ~= "table" or type(eggState.ReadOwnerEggs) ~= "function" then
			return {}
		end
		local ok, result = pcall(eggState.ReadOwnerEggs, localPlayer.UserId)
		if not ok or type(result) ~= "table" then
			return {}
		end
		local filterOn = state.Toggle(autoHatchToggle, false) == true
		if not filterOn then
			return {}
		end
		local targets = {}

		for uid, entry in pairs(result) do
			local isPlaced = type(entry) == "table" and entry.Placement ~= nil

			if isPlaced then
				isPlaced = (failedHatchUids[uid] or 0) <= os.clock()
			end

			if isPlaced then
				local readyOk, isReady = pcall(eggState.IsReadyToHatch, uid)

				if readyOk and isReady == true and passesHatchFilter(entry) then
					table.insert(targets, uid)
				end
			end
		end

		return targets
	end

	local function isHatchEnabled()
		return state.Toggle(autoHatchToggle, false) == true
	end

	local function runHatchLoop()
		local myGeneration = hatchGeneration
		local readyUids = collectHatchableEggs()
		local hatched = 0

		for _, uid in ipairs(readyUids) do
			if not (hatched >= maxHatchPerPass or myGeneration ~= hatchGeneration or not isHatchEnabled()) then
				local ok, result = invokeHatchRemote("RF/EggWorld/AskHatch", uid)

				if ok and result ~= false then
					task.wait(0.35)
					invokeHatchRemote("RF/EggWorld/AskFinishHatch", uid)
					hatched = hatched + 1
					failedHatchUids[uid] = nil
				else
					failedHatchUids[uid] = os.clock() + hatchRetryCooldown
				end

				task.wait(0.2)
				continue
			end

			break
		end

		return hatched > 0
	end

	taskScheduler.Add(function()
		if not isHatchEnabled() or hatchBusy then
			return false
		end
		hatchBusy = true

		task.spawn(function()
			pcall(runHatchLoop)
			hatchBusy = false
		end)

		return false
	end)

	local function hatchNow()
		hatchGeneration = hatchGeneration + 1
		table.clear(failedHatchUids)
		taskScheduler.Wake()
	end

	autoHatchToggle = autoHatchEquipSection:CreateToggle({ Name = "Auto Hatch", Default = false, Callback = hatchNow })

	autoHatchEquipSection:CreateDropdown({
		Name = "Hatch Min Rarity",
		Note = "Hatch eggs of the chosen rarity and every rarity above it",
		Options = rarityOptions,
		Default = rarityOptions[1],
		SubOf = autoHatchToggle,
		Callback = function(selected)
			hatchFilter.MinRarity = rarityNumberMap[selected] or 0
			hatchNow()
		end,
	})

	do
		local valueUnits = {
			["K/s"] = { Min = 0, Max = 1000, Mult = 1000 },
			["M/s"] = { Min = 0, Max = 1000, Mult = 1000000 },
			["B/s"] = { Min = 0, Max = 100, Mult = 1e9 },
		}

		local sliderState = { Slider = nil, Value = 0, Unit = "M/s" }

		local function applyHatchMinValue(value, unit)
			if value ~= nil then
				sliderState.Value = math.max(0, math.floor(tonumber(value) or sliderState.Value))
			end

			if unit ~= nil then
				sliderState.Unit = tostring(unit)
			end

			hatchFilter.MinIncome = sliderState.Value * (valueUnits[sliderState.Unit] or valueUnits["M/s"]).Mult
			hatchNow()
		end

		sliderState.Slider = createValueSlider(autoHatchEquipSection, {
			Name = "Min Hatch Value",
			Note = "Skip eggs worth less than this (0 = off)",
			SubOf = autoHatchToggle,
			Legacy = "Hatch Min Value",
			SectionName = "Auto Hatch & Equip",
			OnRaw = function(value)
				applyHatchMinValue(math.floor(value / 1000), "K/s")
			end,
		})
	end

	do
		local specificOptions = {}
		local specificMap = {}
		local assetDirectory = modules.Assets and modules.Assets.Directory
		local waitForDirectory = 0

		while (type(assetDirectory) ~= "table" or next(assetDirectory) == nil) and waitForDirectory < 2 do
			waitForDirectory = waitForDirectory + task.wait(0.1)

			if type(modules.Assets) ~= "table" then
				modules.Assets = requireModule(function()
					return ReplicatedStorage.Data.Assets
				end)
			end

			assetDirectory = modules.Assets and modules.Assets.Directory
		end

		local eggList = {}

		if type(assetDirectory) == "table" then
			for category, entry in pairs(assetDirectory) do
				local rarity = type(entry) == "table" and entry.Rarity or nil
				local rarityNumber = type(rarity) == "table" and tonumber(rarity.RarityNumber or rarity.Rank) or nil

				if rarityNumber then
					table.insert(eggList, {
						Category = tostring(category),
						Name = tostring(entry.DisplayName or category),
						Rarity = rarityNumber,
						RarityName = tostring(rarity.DisplayName or rarity._id or rarityNumber),
					})
				end
			end
		end

		table.sort(eggList, function(a, b)
			if a.Rarity ~= b.Rarity then
				return a.Rarity > b.Rarity
			end
			return a.Name < b.Name
		end)

		for _, item in ipairs(eggList) do
			local label = string.format("%s [%s]", item.Name, item.RarityName)

			if specificMap[label] then
				label = string.format("%s [%s] (%s)", item.Name, item.RarityName, item.Category)
			end

			table.insert(specificOptions, label)
			specificMap[label] = item.Category
		end

		if #specificOptions > 0 then
			fixDropdownAll(autoHatchEquipSection:CreateMultiDropdown({
				Name = "Hatch Specific Eggs",
				Note = "Only hatch these eggs (empty = all)",
				Options = specificOptions,
				Default = {},
				SubOf = autoHatchToggle,
				Callback = function(selection)
					local eggs = {}

					if type(selection) == "table" then
						for key, value in pairs(selection) do
							local label

							if value == true and type(key) == "string" then
								label = key
							elseif type(value) == "string" then
								label = value
							end

							if label and specificMap[label] then
								eggs[specificMap[label]] = true
							end
						end
					end

					hatchFilter.Eggs = eggs
					hatchNow()
				end,
			}))
		end
	end
end

do
	local checkInterval = 5
	local capacityCacheTtl = 30
	local autoEquipToggle = nil
	local equipBusy = false
	local equipGeneration = 0
	local pendingEquipUids = {}
	local nextEquipAllowedAt = 0
	local refreshRequested = true
	local cachedCapacity = nil
	local cachedCapacityAt = -math.huge

	local function getEquipCapacity(saveData)
		local basesModule = requireModule(function()
			return ReplicatedStorage.Data.Bases
		end)

		if type(basesModule) == "table" and type(basesModule.GetAssetEquipCapacity) == "function" then
			local ok, result = pcall(basesModule.GetAssetEquipCapacity, saveData and tonumber(saveData.BaseUpgradeLevel) or 0)
			if ok and tonumber(result) then
				return math.floor(tonumber(result))
			end
		end

		if cachedCapacity and os.clock() - cachedCapacityAt < capacityCacheTtl then
			return cachedCapacity
		end

		local remote = networking:FindFirstChild("RF/PenRoster/AskWearLimit")

		if remote and remote:IsA("RemoteFunction") then
			local ok, result = pcall(remote.InvokeServer, remote)

			if ok and tonumber(result) then
				local value = math.floor(tonumber(result))
				cachedCapacity = value
				cachedCapacityAt = os.clock()
				return value
			end
		end

		return cachedCapacity or 0
	end

	local function computeItemIncome(item)
		local directory = modules.Assets and modules.Assets.Directory
		local assetEntry = type(directory) == "table" and directory[tostring(item.Category)] or nil
		local earningRate = type(assetEntry) == "table" and tonumber(assetEntry.EarningRate) or 0
		local scale = tonumber(item.Scale) or 0
		if earningRate <= 0 or scale <= 0 then
			return 0
		end
		local scaleFactor = scale > 5 and (scale / 5) ^ 1.2 * 19.637875755794113 or scale ^ 1.85
		local mutationsModule = modules.Mutations
		local hasEarningsFor = type(mutationsModule) == "table" and type(mutationsModule.EarningsFor) == "function"
		local mutationMultiplier = 1

		if hasEarningsFor then
			local ok, result = pcall(mutationsModule.EarningsFor, type(item.Mutations) == "table" and item.Mutations or {})
			mutationMultiplier = ok and type(result) == "number" and result or 1
		end

		return earningRate * scaleFactor * mutationMultiplier
	end

	local function collectInventorySnapshot()
		local saveModule = modules.Save
		local saveData = nil

		if type(saveModule) == "table" and type(saveModule.Get) == "function" then
			local ok, result = pcall(saveModule.Get)
			saveData = ok and type(result) == "table" and result or nil
		end

		if not saveData then
			return nil
		end
		local equippedSet = {}
		local equippedList = {}

		for _, uid in pairs(saveData.EquippedAssets or {}) do
			if type(uid) == "string" then
				equippedSet[uid] = true
				table.insert(equippedList, uid)
			end
		end

		local inventory = {}

		for uid, item in pairs(saveData.Inventory or {}) do
			if type(item) == "table" and item.InFuse ~= true then
				table.insert(inventory, {
					Uid = uid,
					Income = computeItemIncome(item),
					Equipped = equippedSet[uid] == true,
				})
			end
		end

		table.sort(inventory, function(a, b)
			if a.Income ~= b.Income then
				return a.Income > b.Income
			end
			return tostring(a.Uid) < tostring(b.Uid)
		end)

		return inventory, equippedSet, #equippedList, saveData
	end

	local function collectToEquip(inventory, capacity)
		local toEquip = {}
		local hasNew = false

		for index, item in ipairs(inventory) do
			if not (capacity < index) then
				if not item.Equipped then
					table.insert(toEquip, item.Uid)

					if not pendingEquipUids[item.Uid] then
						hasNew = true
					end
				end

				continue
			end

			break
		end

		return toEquip, hasNew
	end

	taskScheduler.Add(function()
		if not state.Toggle(autoEquipToggle, false) then
			return false
		end
		local inventory, equippedSet, equippedCount, saveData = collectInventorySnapshot()

		if inventory then
			local capacity = getEquipCapacity(saveData)
			local toEquip, hasNew = collectToEquip(inventory, capacity)

			if (hasNew or refreshRequested) and not equipBusy and os.clock() >= nextEquipAllowedAt then
				for _, uid in ipairs(toEquip) do
					pendingEquipUids[uid] = true
				end

				refreshRequested = false
				equipBusy = true
				nextEquipAllowedAt = os.clock() + checkInterval
				local myGeneration = equipGeneration

				task.spawn(function()
					local remote = networking:FindFirstChild("RF/Haul/FetchWearBestStatus")
					local isRemoteFunction = remote and remote:IsA("RemoteFunction")
					local canProceed = true

					if isRemoteFunction then
						local ok, result = pcall(remote.InvokeServer, remote)
						canProceed = ok and result ~= false and result ~= nil
					end

					local wearBest = networking:FindFirstChild("RF/Haul/WearBest")

					if canProceed and myGeneration == equipGeneration and wearBest and wearBest:IsA("RemoteFunction") then
						pcall(wearBest.InvokeServer, wearBest)
					end

					equipBusy = false
					taskScheduler.Wake()
				end)
			end
		end

		return false
	end)

	autoEquipToggle = autoHatchEquipSection:CreateToggle({
		Name = "Auto Equip Best",
		Note = "Equip Best when a better pet appears",
		Default = false,
		Callback = function()
			equipGeneration = equipGeneration + 1
			table.clear(pendingEquipUids)
			nextEquipAllowedAt = 0
			refreshRequested = true
			taskScheduler.Wake()
		end,
	})

	local saveModule = modules.Save

	if type(saveModule) == "table" and type(saveModule.FieldSignal) == "function" then
		for _, fieldName in ipairs({ "Inventory", "EquippedAssets" }) do
			local ok, signal = pcall(saveModule.FieldSignal, fieldName)

			if ok and type(signal) == "table" and type(signal.Connect) == "function" then
				local ok2, connection = pcall(signal.Connect, signal, function()
					refreshRequested = true
					taskScheduler.Wake()
				end)

				if ok2 and connection then
					registerCleanup(function()
						pcall(function()
							connection:Disconnect()
						end)
					end)
				end
			end
		end
	end
end

do
	local sellCooldownSeconds = 3
	local sellBatchSize = 50
	local sellRules = { "Rarity Only", "Value Only", "Rarity And Value", "Rarity Or Value" }
	local assetItemsModule = requireModule(function()
		return ReplicatedStorage.Shared.Util.AssetItems
	end)

	local sellRarityOptions = {}
	local sellRarityNumberMap = {}
	local sellEggOptions = {}
	local sellEggCategoryMap = {}

	do
		local assetDirectory = modules.Assets and modules.Assets.Directory
		local rarityNamesByNumber = {}
		local eggList = {}

		if type(assetDirectory) == "table" then
			for category, entry in pairs(assetDirectory) do
				local rarity = type(entry) == "table" and entry.Rarity or nil
				local rarityNumber = type(rarity) == "table" and tonumber(rarity.RarityNumber or rarity.Rank) or nil

				if rarityNumber then
					local rarityName = tostring(rarity.DisplayName or rarity._id or rarityNumber)
					rarityNamesByNumber[rarityNumber] = rarityNamesByNumber[rarityNumber] or rarityName

					table.insert(eggList, {
						Category = tostring(category),
						Name = tostring(entry.DisplayName or category),
						Rarity = rarityNumber,
						RarityName = rarityName,
					})
				end
			end
		end

		local sortedRarityNumbers = {}

		for rarityNumber in pairs(rarityNamesByNumber) do
			table.insert(sortedRarityNumbers, rarityNumber)
		end

		table.sort(sortedRarityNumbers)

		for _, rarityNumber in ipairs(sortedRarityNumbers) do
			local label = string.format("%d - %s", rarityNumber, rarityNamesByNumber[rarityNumber])
			table.insert(sellRarityOptions, label)
			sellRarityNumberMap[label] = rarityNumber
		end

		table.sort(eggList, function(a, b)
			if a.Rarity ~= b.Rarity then
				return a.Rarity < b.Rarity
			end
			return a.Name < b.Name
		end)

		for _, item in ipairs(eggList) do
			local label = string.format("%s [%s]", item.Name, item.RarityName)

			if sellEggCategoryMap[label] then
				label = string.format("%s [%s] (%s)", item.Name, item.RarityName, item.Category)
			end

			table.insert(sellEggOptions, label)
			sellEggCategoryMap[label] = item.Category
		end
	end

	local function findSellRarityLabel(rarityNumber)
		for _, label in ipairs(sellRarityOptions) do
			if sellRarityNumberMap[label] == rarityNumber then
				return label
			end
		end

		return sellRarityOptions[1]
	end

	local autoSellPetToggle = nil
	local autoSellEggToggle = nil
	local petSellPreviewRow = nil
	local eggSellPreviewRow = nil
	local petSellRule = sellRules[1]
	local eggSellRule = sellRules[1]
	local petMaxRarity = 3
	local eggMaxRarity = 3
	local petMinValue = 0
	local eggMinValue = 0
	local keepMutatedPets = true
	local keepMutatedEggs = true
	local petBlacklist = {}
	local eggBlacklist = {}
	local sellBusy = false
	local nextSellAllowedAt = 0
	local keepMutatedPetHandle = nil
	local keepMutatedEggHandle = nil

	local function applyKeepMutatedPets()
		keepMutatedPets = state.Toggle(keepMutatedPetHandle, true)
		taskScheduler.Wake()
	end

	local function applyKeepMutatedEggs()
		keepMutatedEggs = state.Toggle(keepMutatedEggHandle, true)
		taskScheduler.Wake()
	end

	local function formatSellValue(value)
		local number = tonumber(value) or 0
		local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
		local index = 1

		while math.abs(number) >= 1000 and index < #suffixes do
			number = number / 1000
			index = index + 1
		end

		return string.format(index == 1 and "$%.0f%s" or "$%.2f%s", number, suffixes[index])
	end

	local function parseBlacklistSelection(selection, labelMap)
		local result = {}

		if type(selection) == "table" then
			for key, value in pairs(selection) do
				local label

				if value == true and type(key) == "string" then
					label = key
				elseif type(value) == "string" then
					label = value
				end

				if label then
					result[labelMap and labelMap[label] or label] = true
				end
			end
		end

		return result
	end

	local function getCategoryRarity(category)
		local assetDirectory = modules.Assets and modules.Assets.Directory
		local assetEntry = type(assetDirectory) == "table" and (assetDirectory[tostring(category)] or (category ~= nil and assetDirectory[category])) or nil
		local rarity = type(assetEntry) == "table" and assetEntry.Rarity or nil
		local rarityNumber = type(rarity) == "table" and tonumber(rarity.RarityNumber or rarity.Rank) or (type(rarity) == "number" and rarity) or nil
		return rarityNumber or math.huge
	end

	local function computeEggIncomeByCategory(entry)
		local assetDirectory = modules.Assets and modules.Assets.Directory
		local assetEntry = type(assetDirectory) == "table" and assetDirectory[tostring(entry.Category)] or nil
		local earningRate = type(assetEntry) == "table" and tonumber(assetEntry.EarningRate) or 0
		local scale = tonumber(entry.Scale) or 0
		if earningRate <= 0 or scale <= 0 then
			return 0
		end
		local scaleFactor = scale > 5 and (scale / 5) ^ 1.2 * 19.637875755794113 or scale ^ 1.85
		local mutationsModule = modules.Mutations
		local hasEarningsFor = type(mutationsModule) == "table" and type(mutationsModule.EarningsFor) == "function"
		local mutationMultiplier = 1

		if hasEarningsFor then
			local ok, result = pcall(mutationsModule.EarningsFor, type(entry.Mutations) == "table" and entry.Mutations or {})

			if ok and type(result) == "number" then
				mutationMultiplier = result
			end
		end

		return earningRate * scaleFactor * mutationMultiplier
	end

	local function hasAnyMutation(entry)
		return type(entry) == "table" and next(entry) ~= nil
	end

	local function getSaveData()
		local saveModule = modules.Save
		if type(saveModule) ~= "table" or type(saveModule.Get) ~= "function" then
			return nil
		end
		local ok, result = pcall(saveModule.Get)
		return ok and type(result) == "table" and result or nil
	end

	local function collectPetCandidates()
		local saveData = getSaveData()
		local candidates = {}
		if not saveData then
			return candidates, 0
		end
		local equippedSet = {}

		for _, uid in pairs(saveData.EquippedAssets or {}) do
			equippedSet[uid] = true
			equippedSet[tostring(uid)] = true
			if tonumber(uid) then
				equippedSet[tonumber(uid)] = true
			end
		end

		local totalValue = 0

		for uid, item in pairs(saveData.Inventory or {}) do
			local isCandidate = type(item) == "table"
				and item.Category ~= nil
				and item.InFuse ~= true
				and item.IsFavorite ~= true
				and not equippedSet[uid]
				and not equippedSet[tostring(uid)]
				and not petBlacklist[tostring(item.Category)]

			if isCandidate then
				isCandidate = not (keepMutatedPets and hasAnyMutation(item.Mutations))
			end

			if isCandidate then
				local value = computeEggIncomeByCategory(item)
				local passesRarity = getCategoryRarity(item.Category) <= petMaxRarity
				local passesValue = petMinValue > 0 and value < petMinValue

				if petSellRule ~= sellRules[2] then
					if petSellRule == sellRules[3] then
						passesValue = passesRarity and passesValue
					elseif petSellRule == sellRules[4] then
						passesValue = passesRarity or passesValue
					else
						passesValue = passesRarity
					end
				end

				if passesValue then
					table.insert(candidates, uid)
					local ok, salePrice = false, nil

					if type(assetItemsModule) == "table" and type(assetItemsModule.SalePrice) == "function" then
						ok, salePrice = pcall(assetItemsModule.SalePrice, item)
					end

					totalValue = totalValue + (ok and tonumber(salePrice) or value * 100)
				end
			end
		end

		return candidates, totalValue
	end

	local function collectEggCandidates()
		local candidates = {}
		local eggState = modules.EggState
		if type(eggState) ~= "table" or type(eggState.ReadOwnerEggs) ~= "function" then
			return candidates, 0
		end
		local ok, result = pcall(eggState.ReadOwnerEggs, localPlayer.UserId)
		if not ok or type(result) ~= "table" then
			return candidates, 0
		end
		local character = localPlayer.Character
		character = character and character:FindFirstChildWhichIsA("Tool")
		character = character and character:GetAttribute("UID") or nil
		local eggRecords = modules.EggRecords
		local totalValue = 0

		for uid, item in pairs(result) do
			local isCandidate = type(item) == "table"
				and item.Placement == nil
				and uid ~= character
				and not eggBlacklist[tostring(item.AssetCategory)]

			if isCandidate then
				isCandidate = not (keepMutatedEggs and hasAnyMutation(item.Mutations))
			end

			if isCandidate then
				local value = computeEggIncomeByCategory({
					Category = item.AssetCategory,
					Scale = item.AssetScale,
					Mutations = item.Mutations,
				})
				local passesRarity = getCategoryRarity(item.AssetCategory) <= eggMaxRarity
				local passesValue = eggMinValue > 0 and value < eggMinValue

				if eggSellRule ~= sellRules[2] then
					if eggSellRule == sellRules[3] then
						passesValue = passesRarity and passesValue
					elseif eggSellRule ~= sellRules[4] then
						passesValue = passesRarity
					else
						passesValue = passesRarity or passesValue
					end
				end

				if passesValue then
					table.insert(candidates, uid)

					if type(eggRecords) == "table" and type(eggRecords.SellPrice) == "function" then
						local ok2, salePrice = pcall(eggRecords.SellPrice, item)
						totalValue = totalValue + (ok2 and tonumber(salePrice) or 0)
					end
				end
			end
		end

		return candidates, totalValue
	end

	local function fireSellRemote(petUids, eggUids)
		local remote = (networking and networking:FindFirstChild("RE/PetSatchel/SellSelection"))
			or ReplicatedStorage:FindFirstChild("RE/PetSatchel/SellSelection", true)
		if not remote or not remote:IsA("RemoteEvent") then
			return false
		end
		local maxCount = math.max(#petUids, #eggUids)
		local index = 1

		while index <= maxCount do
			local petBatch = {}
			local eggBatch = {}

			for i = index, index + sellBatchSize - 1 do
				if petUids[i] then
					table.insert(petBatch, petUids[i])
				end

				if eggUids[i] then
					table.insert(eggBatch, eggUids[i])
				end
			end

			pcall(remote.FireServer, remote, { Eggs = eggBatch, Assets = petBatch })
			index = index + sellBatchSize

			if index <= maxCount then
				task.wait(0.3)
			end
		end

		return true
	end

	local function runSell(petUids, eggUids)
		local skip = sellBusy

		if not sellBusy then
			skip = #petUids == 0 and #eggUids == 0
		end

		if skip then
			return
		end
		sellBusy = true
		nextSellAllowedAt = os.clock() + sellCooldownSeconds

		task.spawn(function()
			pcall(fireSellRemote, petUids, eggUids)
			sellBusy = false
			taskScheduler.Wake()
		end)
	end

	local function createSellValueSlider(name, note, subOf, onRaw)
		local valueUnits = {
			["K/s"] = { Mult = 1000 },
			["M/s"] = { Mult = 1000000 },
			["B/s"] = { Mult = 1e9 },
		}

		local state = { Value = 0, Unit = "M/s" }

		local function apply(value, unit)
			if value ~= nil then
				state.Value = math.max(0, math.floor(tonumber(value) or state.Value))
			end

			if unit ~= nil then
				state.Unit = tostring(unit)
			end

			onRaw(state.Value * (valueUnits[state.Unit] or valueUnits["M/s"]).Mult)
			taskScheduler.Wake()
		end

		createValueSlider(autoSellSection, {
			Name = name,
			Note = note,
			SubOf = subOf,
			Legacy = name,
			SectionName = "Auto Sell",
			OnRaw = function(raw)
				apply(math.floor(raw / 1000), "K/s")
			end,
		})
	end

	taskScheduler.Add(function()
		local petAutoOn = state.Toggle(autoSellPetToggle, false)
		local eggAutoOn = state.Toggle(autoSellEggToggle, false)
		local petUids, petTotal = collectPetCandidates()
		local eggUids, eggTotal = collectEggCandidates()

		if petSellPreviewRow and type(petSellPreviewRow.Set) == "function" then
			pcall(petSellPreviewRow.Set, petSellPreviewRow, string.format("Pet matches  -  %d pets for %s", #petUids, formatSellValue(petTotal)))
		end

		if eggSellPreviewRow and type(eggSellPreviewRow.Set) == "function" then
			pcall(eggSellPreviewRow.Set, eggSellPreviewRow, string.format("Egg matches  -  %d eggs for %s", #eggUids, formatSellValue(eggTotal)))
		end

		local isBusy = sellBusy
		local cooldownActive

		if sellBusy then
			cooldownActive = isBusy
		else
			cooldownActive = os.clock() < nextSellAllowedAt
		end

		if cooldownActive or not (petAutoOn or eggAutoOn) then
			return false
		end
		runSell(petAutoOn and petUids or {}, eggAutoOn and eggUids or {})
		return false
	end)

	petSellPreviewRow = autoSellSection:CreateText({ Name = "Pet Sell Preview", Text = "Pet matches  -  0 pets" })

	autoSellPetToggle = autoSellSection:CreateToggle({
		Name = "Auto Sell Pet",
		Default = false,
		Callback = function()
			taskScheduler.Wake()
		end,
	})

	autoSellSection:CreateButton({
		Name = "Sell Pets Now",
		ButtonText = "Sell",
		ConfirmText = "Sold!",
		SubOf = autoSellPetToggle,
		Callback = function()
			local petUids = collectPetCandidates()
			runSell(petUids, {})
		end,
	})

	autoSellSection:CreateDropdown({
		Name = "Sell Pet Rule",
		Note = "Which checks must pass to sell",
		Options = sellRules,
		Default = sellRules[1],
		SubOf = autoSellPetToggle,
		Callback = function(selected)
			if table.find(sellRules, selected) then
				petSellRule = selected
				taskScheduler.Wake()
			end
		end,
	})

	autoSellSection:CreateDropdown({
		Name = "Pet Max Rarity",
		Note = "Sell pets at or below this rarity",
		Options = sellRarityOptions,
		Default = findSellRarityLabel(3),
		SubOf = autoSellPetToggle,
		Callback = function(selected)
			petMaxRarity = sellRarityNumberMap[selected] or petMaxRarity
			taskScheduler.Wake()
		end,
	})

	createSellValueSlider("Pet Value Threshold", "Sell pets worth less than this (0 = off)", autoSellPetToggle, function(value)
		petMinValue = value
	end)

	keepMutatedPetHandle = autoSellSection:CreateToggle({
		Name = "Keep Mutated Pets",
		Note = "Never sell mutated pets",
		Default = true,
		SubOf = autoSellPetToggle,
		Callback = applyKeepMutatedPets,
	})

	fixDropdownAll(autoSellSection:CreateMultiDropdown({
		Name = "Blacklist Sell Pets",
		Note = "These pets are never sold",
		Options = sellEggOptions,
		Default = {},
		SubOf = autoSellPetToggle,
		Callback = function(selection)
			petBlacklist = parseBlacklistSelection(selection, sellEggCategoryMap)
			taskScheduler.Wake()
		end,
	}))

	eggSellPreviewRow = autoSellSection:CreateText({ Name = "Egg Sell Preview", Text = "Egg matches  -  0 eggs" })

	autoSellEggToggle = autoSellSection:CreateToggle({
		Name = "Auto Sell Egg",
		Note = "Sell bag eggs matching the rules below",
		Default = false,
		Callback = function()
			taskScheduler.Wake()
		end,
	})

	autoSellSection:CreateButton({
		Name = "Sell Eggs Now",
		Note = "Sell matching eggs once",
		ButtonText = "Sell",
		ConfirmText = "Sold!",
		SubOf = autoSellEggToggle,
		Callback = function()
			local eggUids = collectEggCandidates()
			runSell({}, eggUids)
		end,
	})

	autoSellSection:CreateDropdown({
		Name = "Sell Egg Rule",
		Note = "Which checks must pass to sell",
		Options = sellRules,
		Default = sellRules[1],
		SubOf = autoSellEggToggle,
		Callback = function(selected)
			if table.find(sellRules, selected) then
				eggSellRule = selected
				taskScheduler.Wake()
			end
		end,
	})

	autoSellSection:CreateDropdown({
		Name = "Egg Max Rarity",
		Note = "Sell eggs at or below this rarity",
		Options = sellRarityOptions,
		Default = findSellRarityLabel(3),
		SubOf = autoSellEggToggle,
		Callback = function(selected)
			eggMaxRarity = sellRarityNumberMap[selected] or eggMaxRarity
			taskScheduler.Wake()
		end,
	})

	createSellValueSlider("Egg Value Threshold", "Sell eggs worth less than this (0 = off)", autoSellEggToggle, function(value)
		eggMinValue = value
	end)

	keepMutatedEggHandle = autoSellSection:CreateToggle({
		Name = "Keep Mutated Eggs",
		Note = "Never sell mutated eggs",
		Default = true,
		SubOf = autoSellEggToggle,
		Callback = applyKeepMutatedEggs,
	})

	fixDropdownAll(autoSellSection:CreateMultiDropdown({
		Name = "Blacklist Sell Eggs",
		Note = "These eggs are never sold",
		Options = sellEggOptions,
		Default = {},
		SubOf = autoSellEggToggle,
		Callback = function(selection)
			eggBlacklist = parseBlacklistSelection(selection, sellEggCategoryMap)
			taskScheduler.Wake()
		end,
	}))
end

do
	local saveModule = modules.Save

	if type(saveModule) == "table" and type(saveModule.FieldSignal) == "function" then
		for _, fieldName in ipairs({ "Inventory", "EggInventory", "EquippedAssets" }) do
			local ok, signal = pcall(saveModule.FieldSignal, fieldName)

			if ok and type(signal) == "table" and type(signal.Connect) == "function" then
				local ok2, connection = pcall(signal.Connect, signal, function()
					taskScheduler.Wake()
				end)

				if ok2 and connection then
					registerCleanup(function()
						pcall(function()
							connection:Disconnect()
						end)
					end)
				end
			end
		end
	end
end

local fuseSkipRetrySeconds = 2
local fuseRevealInterval = 3
local fuseItemCooldown = 20
local fusePriorityModes = { "Lowest Rarity First", "Highest Rarity First", "Most Copies First", "Lowest Value First" }
local fuseSortModes = { "Lowest To Highest", "Highest To Lowest" }
local fuseRarityOptions = {}
local fuseRarityNumberMap = {}
local fuseSpeciesOptions = {}
local fuseSpeciesCategoryMap = {}

do
	local assetDirectory = modules.Assets and modules.Assets.Directory
	local rarityNamesByNumber = {}
	local eggList = {}

	if type(assetDirectory) == "table" then
		for category, entry in pairs(assetDirectory) do
			local rarity = type(entry) == "table" and entry.Rarity or nil
			local rarityNumber = type(rarity) == "table" and tonumber(rarity.RarityNumber or rarity.Rank) or nil

			if rarityNumber then
				local rarityName = tostring(rarity.DisplayName or rarity._id or rarityNumber)
				rarityNamesByNumber[rarityNumber] = rarityNamesByNumber[rarityNumber] or rarityName

				table.insert(eggList, {
					Category = tostring(category),
					Name = tostring(entry.DisplayName or category),
					Rarity = rarityNumber,
					RarityName = rarityName,
				})
			end
		end
	end

	local sortedRarityNumbers = {}

	for rarityNumber in pairs(rarityNamesByNumber) do
		table.insert(sortedRarityNumbers, rarityNumber)
	end

	table.sort(sortedRarityNumbers)

	for _, rarityNumber in ipairs(sortedRarityNumbers) do
		local label = string.format("%d - %s", rarityNumber, rarityNamesByNumber[rarityNumber])
		table.insert(fuseRarityOptions, label)
		fuseRarityNumberMap[label] = rarityNumber
	end

	table.sort(eggList, function(a, b)
		if a.Rarity ~= b.Rarity then
			return a.Rarity < b.Rarity
		end
		return a.Name < b.Name
	end)

	for _, item in ipairs(eggList) do
		local label = string.format("%s [%s]", item.Name, item.RarityName)

		if fuseSpeciesCategoryMap[label] then
			label = string.format("%s [%s] (%s)", item.Name, item.RarityName, item.Category)
		end

		table.insert(fuseSpeciesOptions, label)
		fuseSpeciesCategoryMap[label] = item.Category
	end
end

do
	local function findFuseRarityLabel(rarityNumber)
		for _, label in ipairs(fuseRarityOptions) do
			if fuseRarityNumberMap[label] == rarityNumber then
				return label
			end
		end

		return fuseRarityOptions[#fuseRarityOptions]
	end

	local fuseToggle = nil
	local fusePreviewRow = nil
	local fusePriorityMode = fusePriorityModes[1]
	local fuseSortMode = fuseSortModes[1]
	local fuseMaxRarity = 6
	local fuseSpeciesFilter = {}
	local fuseSkipMutated = true
	local fuseEjectIncomplete = true
	local fuseBusy = false
	local fuseGeneration = 0
	local nextFuseAllowedAt = 0
	local nextRevealAllowedAt = 0
	local failedFuseUids = {}
	local skipMutatedHandle = nil
	local ejectIncompleteHandle = nil

	local function invokeFuseRemote(name, arg)
		local remote = (networking and networking:FindFirstChild(name))
			or ReplicatedStorage:FindFirstChild(name, true)
		if not remote or not remote:IsA("RemoteFunction") then
			return false, nil
		end

		if arg == nil then
			return pcall(remote.InvokeServer, remote)
		end
		return pcall(remote.InvokeServer, remote, arg)
	end

	local function getFuseSaveData()
		local saveModule = modules.Save
		if type(saveModule) ~= "table" or type(saveModule.Get) ~= "function" then
			return nil
		end
		local ok, result = pcall(saveModule.Get)
		return ok and type(result) == "table" and result or nil
	end

	local function getFuseAssetEntry(category)
		local assetDirectory = modules.Assets and modules.Assets.Directory
		return type(assetDirectory) == "table" and (assetDirectory[tostring(category)] or (category ~= nil and assetDirectory[category])) or nil
	end

	local function getFuseRarityNumber(category)
		local assetEntry = getFuseAssetEntry(category)
		local rarity = type(assetEntry) == "table" and assetEntry.Rarity or nil
		local rarityNumber = type(rarity) == "table" and tonumber(rarity.RarityNumber or rarity.Rank) or (type(rarity) == "number" and rarity) or nil
		return rarityNumber or math.huge
	end

	local function getFuseDisplayName(category)
		local assetEntry = getFuseAssetEntry(category)
		return tostring(type(assetEntry) == "table" and assetEntry.DisplayName or category)
	end

	local function computeFuseIncome(item)
		local assetEntry = getFuseAssetEntry(item.Category)
		local earningRate = type(assetEntry) == "table" and tonumber(assetEntry.EarningRate) or 0
		local scale = tonumber(item.Scale) or 0
		if earningRate <= 0 or scale <= 0 then
			return 0
		end
		local scaleFactor = scale > 5 and (scale / 5) ^ 1.2 * 19.637875755794113 or scale ^ 1.85
		local mutationsModule = modules.Mutations
		local hasEarningsFor = type(mutationsModule) == "table" and type(mutationsModule.EarningsFor) == "function"
		local mutationMultiplier = 1

		if hasEarningsFor then
			local ok, result = pcall(mutationsModule.EarningsFor, type(item.Mutations) == "table" and item.Mutations or {})
			mutationMultiplier = ok and type(result) == "number" and result or 1
		end

		return earningRate * scaleFactor * mutationMultiplier
	end

	local function hasAnyMutations(entry)
		return type(entry) == "table" and next(entry) ~= nil
	end

	local function formatFuseValue(value)
		local number = tonumber(value) or 0
		local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
		local index = 1

		while math.abs(number) >= 1000 and index < #suffixes do
			number = number / 1000
			index = index + 1
		end

		return string.format(index == 1 and "$%.0f%s" or "$%.2f%s", number, suffixes[index])
	end

	local function getFusePrice(items)
		local fuseKernel = modules.FuseKernel
		if type(fuseKernel) ~= "table" or type(fuseKernel.PriceFor) ~= "function" then
			return nil
		end
		local ok, result = pcall(fuseKernel.PriceFor, items)
		return ok and tonumber(result) or nil
	end

	local function isFusableItem(uid, item, equippedSet)
		local isCandidate = type(item) == "table"
			and item.Category ~= nil
			and item.IsFavorite ~= true
			and not equippedSet[uid]
			and not equippedSet[tostring(uid)]
			and getFuseRarityNumber(item.Category) <= fuseMaxRarity
			and (next(fuseSpeciesFilter) == nil or fuseSpeciesFilter[tostring(item.Category)] == true)

		if isCandidate then
			isCandidate = not (fuseSkipMutated and hasAnyMutations(item.Mutations))
		end

		if isCandidate then
			isCandidate = (failedFuseUids[uid] or 0) <= os.clock()
		end

		return isCandidate
	end

	local function planFuse(saveData)
		local inventory = type(saveData.Inventory) == "table" and saveData.Inventory or {}
		local equippedSet = {}

		for _, uid in pairs(saveData.EquippedAssets or {}) do
			equippedSet[uid] = true
			equippedSet[tostring(uid)] = true
			if tonumber(uid) then
				equippedSet[tonumber(uid)] = true
			end
		end

		local currentSlots = {}
		local slotSet = {}

		for i = 1, 3 do
			local slotUid = type(saveData.FusionSlots) == "table" and saveData.FusionSlots[i] or nil

			if slotUid ~= nil and type(inventory[slotUid]) == "table" then
				table.insert(currentSlots, slotUid)
				slotSet[slotUid] = true
			end
		end

		local groupedByCategory = {}

		for uid, item in pairs(inventory) do
			if not slotSet[uid] and type(item) == "table" and item.InFuse ~= true and isFusableItem(uid, item, equippedSet) then
				local category = tostring(item.Category)
				groupedByCategory[category] = groupedByCategory[category] or {}
				table.insert(groupedByCategory[category], { Uid = uid, Item = item, Income = computeFuseIncome(item) })
			end
		end

		local function sortGroup(group)
			table.sort(group, function(a, b)
				if a.Income ~= b.Income then
					if fuseSortMode == fuseSortModes[2] then
						return a.Income > b.Income
					end
					return a.Income < b.Income
				end

				return tostring(a.Uid) < tostring(b.Uid)
			end)
		end

		if #currentSlots > 0 then
			local category = tostring(inventory[currentSlots[1]].Category)
			local allSameCategory = true

			for _, uid in ipairs(currentSlots) do
				local item = inventory[uid]

				if tostring(item.Category) ~= category or not isFusableItem(uid, item, equippedSet) then
					allSameCategory = false
				end
			end

			local categoryPool = groupedByCategory[category] or {}

			if allSameCategory and #currentSlots + #categoryPool >= 3 then
				sortGroup(categoryPool)
				local plan = { Category = category, Load = {}, Items = {} }

				for _, uid in ipairs(currentSlots) do
					table.insert(plan.Items, inventory[uid])
				end

				for i = 1, 3 - #currentSlots do
					table.insert(plan.Load, categoryPool[i].Uid)
					table.insert(plan.Items, categoryPool[i].Item)
				end

				return plan
			end

			if fuseEjectIncomplete then
				return { Category = category, Eject = currentSlots }
			end
			return nil, "Machine holds pets that cannot finish a fuse"
		end

		local bestScore = nil
		local bestCategory = nil

		for category, group in pairs(groupedByCategory) do
			if #group >= 3 then
				local rarity = getFuseRarityNumber(category)
				local totalIncome = 0

				for _, entry in ipairs(group) do
					totalIncome = totalIncome + entry.Income
				end

				local score

				if fusePriorityMode == fusePriorityModes[2] then
					score = { -rarity, -#group }
				elseif fusePriorityMode == fusePriorityModes[3] then
					score = { -#group, rarity }
				elseif fusePriorityMode == fusePriorityModes[4] then
					score = { totalIncome / #group, rarity }
				else
					score = { rarity, -#group }
				end

				local better = bestScore == nil or score[1] < bestScore[1]

				if not better and bestScore ~= nil and score[1] == bestScore[1] then
					if score[2] < bestScore[2] then
						better = true
					elseif score[2] == bestScore[2] and category < bestCategory then
						better = true
					end
				end

				if better then
					bestScore = score
					bestCategory = category
				end
			end
		end

		if not bestCategory then
			return nil, "No three matching pets"
		end
		local group = groupedByCategory[bestCategory]
		sortGroup(group)
		local plan = { Category = bestCategory, Load = {}, Items = {} }

		for i = 1, 3 do
			table.insert(plan.Load, group[i].Uid)
			table.insert(plan.Items, group[i].Item)
		end

		return plan
	end

	local function executeFuse(generation)
		local saveData = getFuseSaveData()
		if not saveData then
			return
		end

		if saveData.FusionLocked == true then
			if type(saveData.FusionEggReward) == "table" and os.clock() >= nextRevealAllowedAt then
				nextRevealAllowedAt = os.clock() + fuseRevealInterval
				invokeFuseRemote("RF/Fusery/FinishReveal")
			end

			return
		end

		local plan = planFuse(saveData)
		if not plan then
			return
		end

		if plan.Eject then
			for _, uid in ipairs(plan.Eject) do
				if generation ~= fuseGeneration then
					return
				end
				invokeFuseRemote("RF/Fusery/EjectPet", uid)
				task.wait(0.35)
			end

			return
		end

		local price = getFusePrice(plan.Items)
		local money = tonumber(saveData.Money)
		if price and money and money < price then
			return
		end

		for _, uid in ipairs(plan.Load) do
			if generation ~= fuseGeneration then
				return
			end
			local ok, result = invokeFuseRemote("RF/Fusery/LoadPet", uid)
			if not ok or result == false then
				failedFuseUids[uid] = os.clock() + fuseItemCooldown
				return
			end
			task.wait(0.35)
		end

		if generation ~= fuseGeneration then
			return
		end
		local ok, result = invokeFuseRemote("RF/Fusery/BeginFuse")

		if ok and result ~= false then
			nextRevealAllowedAt = os.clock() + fuseRevealInterval
		end
	end

	local function describeFuse(saveData)
		if not saveData then
			return "Fuse status unknown"
		end

		if saveData.FusionLocked == true then
			return "Machine is fusing, waiting for the egg"
		end
		local plan, reason = planFuse(saveData)
		if not plan then
			return reason or "No three matching pets"
		end

		if plan.Eject then
			return string.format("Would eject %d %s that cannot finish a fuse", #plan.Eject, getFuseDisplayName(plan.Category))
		end
		local price = getFusePrice(plan.Items)
		local money = tonumber(saveData.Money)
		local suffix = price and money and money < price and "  (not enough money)" or ""
		return string.format(
			"Next fuse  -  3 %s for %s%s",
			getFuseDisplayName(plan.Category),
			price and formatFuseValue(price) or "?",
			suffix
		)
	end

	taskScheduler.Add(function()
		local saveData = getFuseSaveData()

		if fusePreviewRow and type(fusePreviewRow.Set) == "function" then
			pcall(fusePreviewRow.Set, fusePreviewRow, describeFuse(saveData))
		end

		if not state.Toggle(fuseToggle, false) or fuseBusy or os.clock() < nextFuseAllowedAt then
			return false
		end
		fuseBusy = true
		nextFuseAllowedAt = os.clock() + fuseSkipRetrySeconds
		local myGeneration = fuseGeneration

		task.spawn(function()
			pcall(executeFuse, myGeneration)
			fuseBusy = false
			taskScheduler.Wake()
		end)

		return false
	end)

	fusePreviewRow = autoFuseSection:CreateText({ Name = "Fuse Preview", Text = "Fuse status unknown" })

	fuseToggle = autoFuseSection:CreateToggle({
		Name = "Auto Fuse Machine",
		Note = "Fuse 3 same pets into an egg, nonstop",
		Default = false,
		Callback = function()
			fuseGeneration = fuseGeneration + 1
			table.clear(failedFuseUids)
			nextFuseAllowedAt = 0
			taskScheduler.Wake()
		end,
	})

	autoFuseSection:CreateDropdown({
		Name = "Fuse Priority Mode",
		Options = fusePriorityModes,
		Default = fusePriorityModes[1],
		SubOf = fuseToggle,
		Callback = function(selected)
			if table.find(fusePriorityModes, selected) then
				fusePriorityMode = selected
				taskScheduler.Wake()
			end
		end,
	})

	autoFuseSection:CreateDropdown({
		Name = "Pets To Use",
		Options = fuseSortModes,
		Default = fuseSortModes[1],
		SubOf = fuseToggle,
		Callback = function(selected)
			if table.find(fuseSortModes, selected) then
				fuseSortMode = selected
				taskScheduler.Wake()
			end
		end,
	})

	autoFuseSection:CreateDropdown({
		Name = "Max Rarity to Fuse",
		Options = fuseRarityOptions,
		Default = findFuseRarityLabel(6),
		SubOf = fuseToggle,
		Callback = function(selected)
			fuseMaxRarity = fuseRarityNumberMap[selected] or fuseMaxRarity
			taskScheduler.Wake()
		end,
	})

	fixDropdownAll(autoFuseSection:CreateMultiDropdown({
		Name = "Specific Species to Fuse",
		Note = "Only fuse these species (empty = all)",
		Options = fuseSpeciesOptions,
		Default = {},
		SubOf = fuseToggle,
		Callback = function(selection)
			local filter = {}

			if type(selection) == "table" then
				for key, value in pairs(selection) do
					local label

					if value == true and type(key) == "string" then
						label = key
					elseif type(value) == "string" then
						label = value
					end

					if label and fuseSpeciesCategoryMap[label] then
						filter[fuseSpeciesCategoryMap[label]] = true
					end
				end
			end

			fuseSpeciesFilter = filter
			taskScheduler.Wake()
		end,
	}))

	skipMutatedHandle = autoFuseSection:CreateToggle({
		Name = "Skip Mutated Pets",
		Default = true,
		SubOf = fuseToggle,
		Callback = function()
			fuseSkipMutated = state.Toggle(skipMutatedHandle, true)
			taskScheduler.Wake()
		end,
	})

	ejectIncompleteHandle = autoFuseSection:CreateToggle({
		Name = "Eject Incomplete Slots",
		Note = "Take out pets that can't make a set",
		Default = true,
		SubOf = fuseToggle,
		Callback = function()
			fuseEjectIncomplete = state.Toggle(ejectIncompleteHandle, true)
			taskScheduler.Wake()
		end,
	})

	local saveModule = modules.Save

	if type(saveModule) == "table" and type(saveModule.FieldSignal) == "function" then
		for _, fieldName in ipairs({
			"Inventory",
			"EquippedAssets",
			"FusionSlots",
			"FusionLocked",
			"FusionEggReward",
			"Money",
		}) do
			local ok, signal = pcall(saveModule.FieldSignal, fieldName)

			if ok and type(signal) == "table" and type(signal.Connect) == "function" then
				local ok2, connection = pcall(signal.Connect, signal, function()
					taskScheduler.Wake()
				end)

				if ok2 and connection then
					registerCleanup(function()
						pcall(function()
							connection:Disconnect()
						end)
					end)
				end
			end
		end
	end
end

do
	local raceContext = {
		AutoJoinHandle = nil,
		AutoCompleteHandle = nil,
		AutoJoin = false,
		AutoComplete = true,
		Speed = 110,
		JoinSpeed = 250,
		AutoBoostPad = false,
		AutoPowerUp = true,
		AutoLeave = true,
		AutoClaim = false,
		AutoBuyNitro = false,
		AutoBuyChoice = "Off",
		LastClaimAt = 0,
		LastBuyAt = 0,
		LastJoinAttemptAt = 0,
		PostRaceCooldown = 0,
		LastFinishedSessionEndsAt = nil,
		RacingGeneration = 0,
		Busy = false,
		Status = "Idle",
		Trophies = 0,
		Wins = 0,
	}

	local function getRemotes()
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		if shared and shared:FindFirstChild("Remotes") then
			local ok, res = pcall(require, shared.Remotes)
			if ok and type(res) == "table" then return res end
		end
		return nil
	end

	local function getSaveModule()
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		if shared and shared:FindFirstChild("Save") then
			local ok, res = pcall(require, shared.Save)
			if ok and type(res) == "table" then return res end
		end
		return modules and modules.Save
	end

	local function getMountRaceData()
		local dataFolder = ReplicatedStorage:FindFirstChild("Data")
		if dataFolder and dataFolder:FindFirstChild("MountRace") then
			local ok, res = pcall(require, dataFolder.MountRace)
			if ok and type(res) == "table" then return res end
		end
		return nil
	end

	local function getRaceRallyData()
		local dataFolder = ReplicatedStorage:FindFirstChild("Data")
		if dataFolder and dataFolder:FindFirstChild("RaceRally") then
			local ok, res = pcall(require, dataFolder.RaceRally)
			if ok and type(res) == "table" then return res end
		end
		return nil
	end

	local function getScheduleUtil()
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local util = shared and shared:FindFirstChild("Util")
		if util and util:FindFirstChild("RaceRallySchedule") then
			local ok, res = pcall(require, util.RaceRallySchedule)
			if ok and type(res) == "table" then return res end
		end
		return nil
	end

	local function getPlayerProfile()
		local saveMod = getSaveModule()
		if saveMod and type(saveMod.Peek) == "function" then
			local ok, data = pcall(saveMod.Peek)
			if ok and type(data) == "table" then
				return data
			end
		end
		return nil
	end

	local function getRaceData()
		local profile = getPlayerProfile()
		return profile and profile.RaceRally or {}
	end

	local function getPortalModel()
		local world = workspace:FindFirstChild("World")
		if world then
			local portal = world:FindFirstChild("RaceRallyPortal")
			if portal and portal:IsA("Model") then
				return portal
			end
		end
		return workspace:FindFirstChild("RaceRallyPortal", true)
	end

	local function isRacePortalOpen()
		local joinEndsAt = workspace:GetAttribute("RaceRallyJoinEndsAt")
		if type(joinEndsAt) == "number" then
			return workspace:GetServerTimeNow() < joinEndsAt
		end
		return false
	end

	local function isInRace()
		return localPlayer:GetAttribute("RaceId") ~= nil
	end

	local function getRaceTrack()
		local raceId = localPlayer:GetAttribute("RaceId")
		if type(raceId) == "string" and raceId ~= "" then
			for _, tagged in ipairs(CollectionService:GetTagged("RaceTrack")) do
				if tagged.Name == raceId and tagged:FindFirstChild("AttachmentTrack") then
					return tagged
				end
			end
		end
		for _, tagged in ipairs(CollectionService:GetTagged("RaceTrack")) do
			if tagged:FindFirstChild("AttachmentTrack") then
				return tagged
			end
		end
		local track = workspace:FindFirstChild("RaceTrack")
		if track and track:FindFirstChild("AttachmentTrack") then
			return track
		end
		return nil
	end

	local function getHeatState(track)
		if not track then return nil end
		local heat = localPlayer:GetAttribute("RaceHeat")
		if not heat then
			local mr = getMountRaceData()
			if mr and type(mr.HeatOf) == "function" then
				heat = mr.HeatOf(localPlayer)
			end
		end
		local heatsFolder = track:FindFirstChild("RaceHeats")
		if heatsFolder then
			if heat then
				local hState = heatsFolder:FindFirstChild(heat)
				if hState then return hState end
			end
			local firstChild = heatsFolder:GetChildren()[1]
			if firstChild then return firstChild end
		end
		return track
	end

	local function getTrackAttr(track, heatState, attrName)
		if heatState then
			local val = heatState:GetAttribute(attrName)
			if val ~= nil then return val end
		end
		if track then
			local val = track:GetAttribute(attrName)
			if val ~= nil then return val end
		end
		return nil
	end

	local function getRiderHeightOffset()
		local char = localPlayer.Character
		local mount = char and char:FindFirstChild("RaceMount")
		if mount then
			local mr = getMountRaceData()
			if mr and type(mr.RiderFrame) == "function" then
				local ok, cf = pcall(mr.RiderFrame, mount, CFrame.identity)
				if ok and typeof(cf) == "CFrame" and cf.Position.Y > 1 then
					return cf.Position.Y
				end
			end
			local mHrp = mount:FindFirstChild("HumanoidRootPart")
			local hitbox = mount:FindFirstChild("Hitbox")
			local seat = mHrp and mHrp:FindFirstChild("Seat")
			if mHrp and hitbox and seat then
				local ok, bY = pcall(function()
					return (mHrp.CFrame:ToObjectSpace(hitbox.CFrame)).Y - hitbox.Size.Y / 2
				end)
				if ok and type(bY) == "number" then
					return math.max(4.0, 0.5 - bY + seat.CFrame.Y)
				end
			end
		end
		return 5.2
	end

	local function getCountdownText()
		local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
		if not playerGui then return nil end
		local raceUI = playerGui:FindFirstChild("MountRaceUI") or playerGui:FindFirstChild("MountRaceBoardUI")
		if raceUI then
			local cd = raceUI:FindFirstChild("Countdown", true)
			if cd and cd:IsA("TextLabel") and cd.Visible then
				local txt = tostring(cd.Text or "")
				if txt ~= "" then
					return txt
				end
			end
		end
		return nil
	end

	local function claimAllMilestones()
		local remotes = getRemotes()
		local raceData = getRaceData()
		local claimed = raceData.Milestones or {}
		local wins = tonumber(raceData.Wins) or 0
		local rallyData = getRaceRallyData()
		if not remotes or not remotes.RaceRally or not remotes.RaceRally.AskClaimMilestone or not rallyData then
			return
		end

		local claimedCount = 0
		if type(rallyData.Milestones) == "table" then
			for mId, mSpec in pairs(rallyData.Milestones) do
				if not claimed[mId] and type(mSpec) == "table" and (mSpec.Wins or 0) <= wins then
					local ok = pcall(function()
						remotes.RaceRally.AskClaimMilestone:InvokeServer(mId)
					end)
					if ok then claimedCount = claimedCount + 1 end
					task.wait(0.2)
				end
			end
		end

		if rallyData.RepeatId and type(rallyData.RepeatsEarned) == "function" then
			local repeatsEarned = rallyData.RepeatsEarned(wins) or 0
			local repeatsClaimed = tonumber(raceData.Repeats) or 0
			while repeatsClaimed < repeatsEarned do
				local ok = pcall(function()
					remotes.RaceRally.AskClaimMilestone:InvokeServer(rallyData.RepeatId)
				end)
				if not ok then break end
				repeatsClaimed = repeatsClaimed + 1
				claimedCount = claimedCount + 1
				task.wait(0.2)
			end
		end

		if claimedCount > 0 then
			state.Notify("Race Rally", string.format("Successfully claimed %d milestone reward(s)!", claimedCount))
		end
	end

	local function buyShopItem(itemId)
		local remotes = getRemotes()
		if not remotes or not remotes.RaceRally or not remotes.RaceRally.AskBuy then
			return false, "Remote not available"
		end
		local ok, res = pcall(function()
			return remotes.RaceRally.AskBuy:InvokeServer(itemId)
		end)
		return ok, res
	end

	local function findPortalHitbox(instance)
		if not instance then
			return nil
		end
		local hitbox = instance:FindFirstChild("Hitbox", true) or instance:WaitForChild("Hitbox", 2)
		if hitbox and hitbox:IsA("BasePart") then
			return hitbox
		end

		for _, descendant in ipairs(instance:GetDescendants()) do
			if descendant:IsA("TouchTransmitter") and descendant.Parent and descendant.Parent:IsA("BasePart") then
				return descendant.Parent
			end
		end

		if instance:IsA("Model") and instance.PrimaryPart then
			return instance.PrimaryPart
		end

		for _, child in ipairs(instance:GetChildren()) do
			if child:IsA("BasePart") then
				return child
			end
		end

		return nil
	end

	local function fireTouchInterest(partOrRoot, maybeHitbox)
		local root, hitbox
		if maybeHitbox then
			root = partOrRoot
			hitbox = maybeHitbox
		else
			root = state.Root()
			hitbox = partOrRoot
		end

		if not root or not hitbox or type(firetouchinterest) ~= "function" then
			return
		end

		pcall(function()
			firetouchinterest(root, hitbox, 0)
			task.wait(0.05)
			firetouchinterest(root, hitbox, 1)
		end)
	end

	local runRaceAuto
	local function releaseRaceShieldPause()
		if raceContext.ShieldPausedByRace then
			raceContext.ShieldPausedByRace = false
			state.ShieldPaused = false
		end
	end

	local function pauseShieldForPortalEntry()
		if not isInRace() then
			raceContext.ShieldPausedByRace = true
			state.ShieldPaused = true
			pcall(state.UndoSwap)
		end
	end

	local function joinRacePortal()
		if isInRace() then return true end
		if raceContext.Busy then return false end
		if os.clock() < (raceContext.PostRaceCooldown or 0) then return false end
		if (state.Steal and (state.Steal.Active or state.Steal.Carrying)) or (state.AntiGuard and state.AntiGuard.Busy) then
			return false
		end

		local joinEndsAt = workspace:GetAttribute("RaceRallyJoinEndsAt")
		if type(joinEndsAt) ~= "number" or workspace:GetServerTimeNow() >= joinEndsAt then
			return false
		end

		if raceContext.LastFinishedSessionEndsAt ~= nil and raceContext.LastFinishedSessionEndsAt == joinEndsAt then
			return false
		end

		local portal = getPortalModel()
		if not portal then return false end
		local portalHitbox = findPortalHitbox(portal)
		if not portalHitbox then return false end

		if not state.ClaimMovement("race") then
			return false
		end

		raceContext.Busy = true
		raceContext.RacingGeneration = raceContext.RacingGeneration + 1
		local gen = raceContext.RacingGeneration

		task.spawn(function()
			local success = false
			local ok, err = pcall(function()
				pauseShieldForPortalEntry()
				local home = type(state.StealHome) == "function" and state.StealHome() or nil
				local root = state.Root()
				if not root then return end

				if home and type(state.InsideBase) == "function" and state.InsideBase() then
					local target = home + Vector3.new(0, 3, 0)
					local travelSpeed = raceContext.JoinSpeed or raceContext.Speed or 250
					local startClock = os.clock()
					local arrivedHome = false

					while os.clock() - startClock < 15 do
						if gen ~= raceContext.RacingGeneration or not raceContext.AutoJoin or isInRace() then
							break
						end
						root = state.Root()
						if not root then break end
						local delta = target - root.Position
						if delta.Magnitude <= 4 then
							arrivedHome = true
							break
						else
							raceContext.Status = "Exiting base via safe zone..."
							local step = math.min(travelSpeed * RunService.Heartbeat:Wait(), delta.Magnitude)
							pcall(function()
								local rotation = root.CFrame.Rotation
								root.CFrame = CFrame.new(root.Position + delta.Unit * step) * rotation
								root.AssemblyLinearVelocity = Vector3.zero
							end)
						end
					end

					if not arrivedHome and not isInRace() then
						return
					end

					local waitElapsed = 0
					while waitElapsed < 0.35 do
						root = state.Root()
						if root then
							pcall(function()
								root.AssemblyLinearVelocity = Vector3.zero
							end)
						end
						waitElapsed = waitElapsed + RunService.Heartbeat:Wait()
					end
				end

				if isInRace() then
					success = true
					raceContext.LastFinishedSessionEndsAt = nil
					return
				end

				local portalPosition = portalHitbox.Position
				local startClock = os.clock()
				local travelSpeed = raceContext.JoinSpeed or raceContext.Speed or 250

				while os.clock() - startClock < 45 do
					if gen ~= raceContext.RacingGeneration or not raceContext.AutoJoin or isInRace() then
						break
					end
					root = state.Root()
					if not root then break end

					local delta = Vector3.new(portalPosition.X - root.Position.X, 0, portalPosition.Z - root.Position.Z)
					if delta.Magnitude <= 12 then
						break
					end

					local step = delta.Unit * math.min(travelSpeed, delta.Magnitude / 0.05)
					raceContext.Status = string.format("Gliding to Race portal, %d studs...", math.floor(delta.Magnitude + 0.5))

					pcall(function()
						root.AssemblyLinearVelocity = Vector3.new(step.X, root.AssemblyLinearVelocity.Y, step.Z)
					end)

					RunService.Heartbeat:Wait()
				end

				root = state.Root()
				if not root then return end

				pcall(function()
					root.AssemblyLinearVelocity = Vector3.zero
					local char = localPlayer.Character
					if char and portalHitbox then
						char:PivotTo(CFrame.new(portalPosition + Vector3.new(0, 2, 0)))
					end
				end)

				pauseShieldForPortalEntry()
				raceContext.Status = "Entering Race Rally portal..."
				fireTouchInterest(portalHitbox)
				task.wait(0.3)

				local touchWait = os.clock() + 5
				while os.clock() < touchWait and not isInRace() do
					if gen ~= raceContext.RacingGeneration or not raceContext.AutoJoin then
						break
					end
					root = state.Root()
					if root and portalHitbox then
						fireTouchInterest(portalHitbox)
						pcall(function()
							root.AssemblyLinearVelocity = Vector3.zero
						end)
					end
					task.wait(0.4)
				end

				if isInRace() then
					success = true
					raceContext.LastFinishedSessionEndsAt = nil
					raceContext.Status = "Joined the Race arena!"
					state.Notify("Race Rally", "Successfully joined the race arena!")
				end
			end)

			raceContext.Busy = false

			if success then
				if raceContext.AutoComplete then
					task.spawn(runRaceAuto)
				end
			else
				if not isInRace() then
					releaseRaceShieldPause()
					pcall(state.ReleaseMovement, "race")
				end
			end
		end)

		return true
	end

	local function getRaceTrackPathModule()
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local mods = shared and shared:FindFirstChild("Modules")
		if mods and mods:FindFirstChild("RaceTrackPath") then
			local ok, res = pcall(require, mods.RaceTrackPath)
			if ok and type(res) == "table" then return res end
		end
		return nil
	end

	local function getRacePowerUpsModule()
		local dataFolder = ReplicatedStorage:FindFirstChild("Data")
		if dataFolder and dataFolder:FindFirstChild("RacePowerUps") then
			local ok, res = pcall(require, dataFolder.RacePowerUps)
			if ok and type(res) == "table" then return res end
		end
		return nil
	end

	local function buildFallbackTrackPath(attachmentTrack)
		local children = attachmentTrack:GetChildren()
		local pts = {}
		local ups = {}
		for i = 1, #children do
			local att = attachmentTrack:FindFirstChild(tostring(i))
			if att and att:IsA("Attachment") then
				pts[#pts + 1] = att.WorldPosition
				ups[#ups + 1] = att.WorldCFrame.UpVector
			end
		end
		local count = #pts
		if count < 3 then return nil end
		local starts = table.create(count)
		local lengths = table.create(count)
		local totalLen = 0
		for i = 1, count do
			local segLen = (pts[i % count + 1] - pts[i]).Magnitude
			starts[i] = totalLen
			lengths[i] = math.max(segLen, 1)
			totalLen = totalLen + math.max(segLen, 1)
		end
		local pathObj = {
			Count = count,
			Length = totalLen,
			Points = pts,
			Ups = ups,
			Starts = starts,
			Lengths = lengths,
		}
		function pathObj:Locate(d)
			local lapBase = math.floor(d / self.Length) * self.Length
			local rem = d - lapBase
			local lo, hi = 1, self.Count
			while lo < hi do
				local mid = (lo + hi + 1) // 2
				if self.Starts[mid] <= rem then
					lo = mid
				else
					hi = mid - 1
				end
			end
			return lo, lapBase
		end
		function pathObj:FrameAt(d)
			local idx, lapBase = self:Locate(d)
			local nextIdx = idx % self.Count + 1
			local alpha = math.clamp((d - lapBase - self.Starts[idx]) / self.Lengths[idx], 0, 1)
			local p1, p2 = self.Points[idx], self.Points[nextIdx]
			local pos = p1:Lerp(p2, alpha)
			local up = self.Ups[idx]:Lerp(self.Ups[nextIdx], alpha)
			return CFrame.lookAt(pos, pos + (p2 - p1), up)
		end
		function pathObj:Project(worldPos, lastDist, lookBehind, lookAhead)
			local minD = lastDist - lookBehind
			local maxD = lastDist + lookAhead
			local idx, lapBase = self:Locate(minD)
			local bestD = minD
			local bestErr = math.huge
			while lapBase + self.Starts[idx] <= maxD do
				local p1 = self.Points[idx]
				local seg = self.Points[idx % self.Count + 1] - p1
				local segLen = self.Lengths[idx]
				local t = math.clamp((worldPos - p1):Dot(seg) / (segLen * segLen), 0, 1)
				local err = (p1 + seg * t - worldPos).Magnitude
				if err < bestErr then
					bestErr = err
					bestD = lapBase + self.Starts[idx] + t * segLen
				end
				idx = idx + 1
				if idx > self.Count then
					idx = 1
					lapBase = lapBase + self.Length
				end
			end
			return math.clamp(bestD, minD, maxD), bestErr
		end
		return pathObj
	end

	local function getControlsSingleton()
		local ok, ctrl = pcall(function()
			local ps = localPlayer:WaitForChild("PlayerScripts", 5)
			local pm = ps and ps:WaitForChild("PlayerModule", 5)
			return pm and require(pm):GetControls() or nil
		end)
		return ok and type(ctrl) == "table" and ctrl or nil
	end

	local function getMountControllerModule()
		local ok, mod = pcall(function()
			local controllers = ReplicatedStorage:FindFirstChild("Controllers")
			local gameFolder = controllers and controllers:FindFirstChild("Game")
			local rcc = gameFolder and gameFolder:FindFirstChild("RaceClientController")
			local mc = (rcc and rcc:FindFirstChild("MountController")) or ReplicatedStorage:FindFirstChild("MountController", true)
			return mc and mc:IsA("ModuleScript") and require(mc) or nil
		end)
		return ok and type(mod) == "table" and mod or nil
	end

	local function getRaceEffectsModule()
		local ok, mod = pcall(function()
			local controllers = ReplicatedStorage:FindFirstChild("Controllers")
			local gameFolder = controllers and controllers:FindFirstChild("Game")
			local rcc = gameFolder and gameFolder:FindFirstChild("RaceClientController")
			local re = (rcc and rcc:FindFirstChild("RaceEffects")) or ReplicatedStorage:FindFirstChild("RaceEffects", true)
			return re and re:IsA("ModuleScript") and require(re) or nil
		end)
		return ok and type(mod) == "table" and mod or nil
	end

	local function findActiveMountController(root)
		if type(getgc) ~= "function" then return nil end
		local ok, gcList = pcall(getgc, true)
		if not ok or type(gcList) ~= "table" then return nil end
		for _, obj in ipairs(gcList) do
			if type(obj) == "table" then
				local rig = rawget(obj, "Rig")
				local drive = rawget(obj, "Drive")
				local align = rawget(obj, "Align")
				local push = rawget(obj, "Push")
				if type(rig) == "table" and rawget(rig, "Root") == root and drive and align and push then
					return obj
				end
			end
		end
		return nil
	end

	local activeDriverCleanup = nil

	local function resolveTrueGetMoveVector(ctrlObj)
		if not ctrlObj then return nil end
		local saved = rawget(ctrlObj, "_NexTrueGetMoveVector")
		if type(saved) == "function" then
			local ok, src = pcall(debug.info, saved, "s")
			if ok and tostring(src):find("ControlModule") then
				return saved
			end
		end
		local cur = ctrlObj.GetMoveVector
		if type(cur) == "function" then
			local ok, src = pcall(debug.info, cur, "s")
			if ok and tostring(src):find("ControlModule") then
				pcall(rawset, ctrlObj, "_NexTrueGetMoveVector", cur)
				return cur
			end
		end
		if type(getgc) == "function" then
			local ok, list = pcall(getgc)
			if ok and type(list) == "table" then
				for _, fn in ipairs(list) do
					if type(fn) == "function" then
						local okS, src = pcall(debug.info, fn, "s")
						local okN, name = pcall(debug.info, fn, "n")
						if okS and okN and tostring(src):find("ControlModule") and tostring(name) == "GetMoveVector" then
							pcall(rawset, ctrlObj, "_NexTrueGetMoveVector", fn)
							return fn
						end
					end
				end
			end
		end
		local fallback = function() return Vector3.zero end
		return fallback
	end

	local function buildNativeMountStepFallback(getCtrlSingleton)
		return function(self, dt)
			local override = self.Override
			if override ~= nil then
				override(self, dt)
				return
			end
			local rootPart = self.Rig and self.Rig.Root
			if not rootPart then return end
			local now = os.clock()
			local held = self:IsHeld()
			local topSpeed = 110
			local grounded = false
			local up = self.Up or Vector3.new(0, 1, 0)
			if (self.IgnoreGroundUntil or 0) <= now then
				grounded, up = self:ProbeGround()
			end
			local wasGrounded = self.Grounded
			self.Grounded = grounded
			self.AirSeconds = not grounded and ((self.AirSeconds or 0) + dt) or 0
			if self.StickMinRatio ~= nil and not grounded then
				if self.AirSeconds > 0.3 or not self:RoadBelow() then
					self.StickMinRatio = nil
				end
			end
			local stick = self.StickMinRatio ~= nil
			local targetUp = grounded and up or (stick and self.Up or Vector3.new(0, 1, 0))
			local upRate = (grounded or stick) and 14 or 2
			self.Up = self.Up:Lerp(targetUp, math.min(1, upRate * dt)).Unit
			local up4 = self.Up
			local heading = self.Heading or rootPart.CFrame.LookVector
			local flatH = heading - up4 * heading:Dot(up4)
			local unit = flatH.Magnitude > 0.001 and flatH.Unit or nil
			if not unit then
				local lv = rootPart.CFrame.LookVector
				flatH = lv - up4 * lv:Dot(up4)
				unit = (flatH.Magnitude > 0.001 and flatH.Unit) or self.TravelDirection or Vector3.new(0, 0, -1)
			end
			if held then
				local lv = rootPart.CFrame.LookVector
				local f2 = lv - up4 * lv:Dot(up4)
				unit = (f2.Magnitude > 0.001 and f2.Unit) or unit
				self.TravelDirection = unit
			end
			if grounded and not wasGrounded then
				local alv = rootPart.AssemblyLinearVelocity
				local fVel = alv - up4 * alv:Dot(up4)
				if fVel.Magnitude > 1 then
					self.Speed = fVel:Dot(unit)
					self.TravelDirection = fVel.Unit * (self.Speed >= 0 and 1 or -1)
				end
				self.Launched = false
				if self.Landed and type(self.Landed.Fire) == "function" then
					pcall(function() self.Landed:Fire() end)
				end
			end
			local cObj = getCtrlSingleton()
			local moveVec = (not held and cObj and type(cObj.GetMoveVector) == "function") and cObj:GetMoveVector() or Vector3.zero
			local throttle = -moveVec.Z
			local steerX = moveVec.X
			local loopEdge = (stick and grounded and not held) and self:ProbeLoopEdge(unit) or 0
			if loopEdge ~= 0 and steerX * loopEdge < 0 then
				steerX = 0
			end
			local speedRatio = math.clamp(math.abs(self.Speed or 0) / topSpeed, 0, 1)
			local steerFactor = math.max(math.clamp(math.abs(self.Speed or 0) / 10, 0, 1), 0.35) * ((0.55 - 1) * speedRatio + 1)
			if self.Handbrake then steerFactor = steerFactor * 1.8 end
			if not grounded then steerFactor = steerFactor * 0.3 end
			if stick then steerFactor = steerFactor * 0.35 end
			local dirSign = (self.Speed or 0) < -1 and -1 or 1
			local heading2 = CFrame.fromAxisAngle(up4, -steerX * math.rad(140) * steerFactor * dirSign * dt - loopEdge * 1.2217304763960306 * dt):VectorToWorldSpace(unit)
			self.Heading = heading2
			if held then
				self.Speed = 0
			elseif grounded then
				local maxSpd = topSpeed * self:TopSpeedScale()
				local accel = topSpeed / 3
				if maxSpd < self.Speed then
					self.Speed = math.max(maxSpd, self.Speed - accel * dt)
				elseif throttle > 0.05 then
					self.Speed = math.min(maxSpd, self.Speed + accel * throttle * dt)
				elseif not (throttle < -0.05) then
					local coast = (topSpeed / 6) * dt
					self.Speed = self.Speed >= 0 and math.max(self.Speed - coast, 0) or math.min(self.Speed + coast, 0)
				elseif not (self.Speed > 0) then
					self.Speed = math.max(-25, self.Speed + accel * throttle * dt)
				else
					self.Speed = math.max(0, self.Speed + (topSpeed / 0.8) * throttle * dt)
				end
				if self.Handbrake then
					self.Speed = self.Speed - self.Speed * 0.25 * dt
				end
				if self.StickMinRatio ~= nil then
					self.Speed = math.max(self.Speed, topSpeed * self.StickMinRatio)
				end
			end
			local gripRate = 12 * (self.Handbrake and 0.3 or 1)
			local td = self.TravelDirection or heading2
			local flatTd = td - up4 * td:Dot(up4)
			flatTd = ((flatTd.Magnitude > 0.001 and flatTd.Unit) or heading2):Lerp(heading2, math.min(1, gripRate * dt))
			local flatTd2 = flatTd - up4 * flatTd:Dot(up4)
			self.TravelDirection = (flatTd2.Magnitude > 0.001 and flatTd2.Unit) or heading2
			if grounded and not held then
				pcall(function() self:CheckWall(heading2, dt) end)
				heading2 = self.Heading
			end
			local rightAxis = heading2:Cross(up4)
			self.Drive.Enabled = grounded or held
			self.Drive.PrimaryTangentAxis = heading2
			self.Drive.SecondaryTangentAxis = rightAxis
			local velVec = self.TravelDirection * self.Speed + rightAxis * loopEdge * 18
			self.Drive.PlaneVelocity = Vector2.new(velVec:Dot(heading2), velVec:Dot(rightAxis))
			local mass = rootPart.AssemblyMass
			local grav = Workspace.Gravity
			if stick then
				self.Push.Force = Vector3.new(0, 1, 0) * mass * grav - up4 * mass * grav * 1.6
			elseif not grounded then
				self.Push.Force = Vector3.zero
			else
				self.Push.Force = -up4 * mass * grav * 0.4
			end
			self.Align.CFrame = CFrame.lookAt(Vector3.zero, heading2, up4)
		end
	end

	local function resolveTrueMountStep(mcMod, getCtrlSingleton)
		if not mcMod then return nil end
		local saved = rawget(mcMod, "_NexTrueMountStep")
		if type(saved) == "function" then
			local ok, src = pcall(debug.info, saved, "s")
			if ok and tostring(src):find("MountController") then
				return saved
			end
		end
		local cur = mcMod.Step
		if type(cur) == "function" then
			local ok, src = pcall(debug.info, cur, "s")
			if ok and tostring(src):find("MountController") then
				pcall(rawset, mcMod, "_NexTrueMountStep", cur)
				return cur
			end
		end
		if type(getgc) == "function" then
			local ok, list = pcall(getgc)
			if ok and type(list) == "table" then
				for _, fn in ipairs(list) do
					if type(fn) == "function" then
						local okS, src = pcall(debug.info, fn, "s")
						local okN, name = pcall(debug.info, fn, "n")
						if okS and okN and tostring(src):find("MountController") and tostring(name) == "Step" then
							pcall(rawset, mcMod, "_NexTrueMountStep", fn)
							return fn
						end
					end
				end
			end
		end
		local fallback = buildNativeMountStepFallback(getCtrlSingleton)
		pcall(rawset, mcMod, "_NexTrueMountStep", fallback)
		return fallback
	end

	pcall(function()
		local cObj = getControlsSingleton()
		if cObj then
			local trueGmv = resolveTrueGetMoveVector(cObj)
			if trueGmv then cObj.GetMoveVector = trueGmv end
		end
		local mcMod = getMountControllerModule()
		if mcMod then
			local trueStep = resolveTrueMountStep(mcMod, getControlsSingleton)
			if trueStep then mcMod.Step = trueStep end
		end
	end)

	function runRaceAuto()
		if raceContext.Busy then return end
		raceContext.Busy = true
		raceContext.RacingGeneration = raceContext.RacingGeneration + 1
		local gen = raceContext.RacingGeneration

		task.spawn(function()
			local controlsObj = nil
			local origGetMoveVector = nil
			local myGetMoveVectorHook = nil
			local mountCtrlMod = nil
			local origMountStep = nil
			local myMountStepHook = nil
			local activeMountCtrl = nil
			local helperConnection = nil
			local powerUpMomentConnection = nil
			local boostTagAddedConn = nil
			local slowTagAddedConn = nil
			local powerUpTagAddedConn = nil

			local function cleanupRaceDriver()
				if helperConnection then
					pcall(function() helperConnection:Disconnect() end)
					helperConnection = nil
				end
				if powerUpMomentConnection then
					pcall(function() powerUpMomentConnection:Disconnect() end)
					powerUpMomentConnection = nil
				end
				if boostTagAddedConn then
					pcall(function() boostTagAddedConn:Disconnect() end)
					boostTagAddedConn = nil
				end
				if slowTagAddedConn then
					pcall(function() slowTagAddedConn:Disconnect() end)
					slowTagAddedConn = nil
				end
				if powerUpTagAddedConn then
					pcall(function() powerUpTagAddedConn:Disconnect() end)
					powerUpTagAddedConn = nil
				end
				if controlsObj and origGetMoveVector then
					pcall(function()
						if myGetMoveVectorHook == nil or controlsObj.GetMoveVector == myGetMoveVectorHook then
							controlsObj.GetMoveVector = origGetMoveVector
						end
					end)
					myGetMoveVectorHook = nil
				end
				if mountCtrlMod and origMountStep then
					pcall(function()
						if myMountStepHook == nil or mountCtrlMod.Step == myMountStepHook then
							mountCtrlMod.Step = origMountStep
						end
					end)
					myMountStepHook = nil
				end
				if activeMountCtrl and type(activeMountCtrl) == "table" then
					pcall(function()
						activeMountCtrl.Handbrake = false
						if type(activeMountCtrl.SpeedScales) == "table" then
							activeMountCtrl.SpeedScales["NexRaceScale"] = nil
						end
					end)
					activeMountCtrl = nil
				end
			end
			activeDriverCleanup = cleanupRaceDriver

			pcall(function()
				raceContext.ShieldPausedByRace = true
				state.ShieldPaused = true

				if not state.ClaimMovement("race") then
					raceContext.Busy = false
					return
				end

				local preProfile = getPlayerProfile()
				local preRaceData = preProfile and preProfile.RaceRally or {}
				local preTokens = tonumber(preRaceData.Tokens) or 0
				local preWins = tonumber(preRaceData.Wins) or 0

				local track = getRaceTrack()
				local waitLimit = os.clock() + 10
				while not track and gen == raceContext.RacingGeneration and isInRace() and os.clock() < waitLimit do
					track = getRaceTrack()
					task.wait(0.3)
				end
				if not track or not isInRace() then
					return
				end

				local cutsceneLimit = os.clock() + 20
				while localPlayer:GetAttribute("RaceCutscenePlaying") == true and gen == raceContext.RacingGeneration and isInRace() and os.clock() < cutsceneLimit do
					raceContext.Status = "Starting Grid (Intro Cutscene)..."
					task.wait(0.2)
				end

				local char = localPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum and not hum.PlatformStand then
					pcall(function() hum.PlatformStand = true end)
				end

				local gridLimit = os.clock() + 65
				local seenCountdown = false

				while gen == raceContext.RacingGeneration and isInRace() and os.clock() < gridLimit do
					local heatState = getHeatState(track)
					local phase = getTrackAttr(track, heatState, "RacePhase")
					local goAt = getTrackAttr(track, heatState, "RaceGoAt")
					local cdText = getCountdownText()

					if phase == "Racing" then
						raceContext.Status = "GO! Race started!"
						break
					end

					if type(goAt) == "number" and Workspace:GetServerTimeNow() >= goAt then
						raceContext.Status = "GO! Race started!"
						break
					end

					if cdText == "GO!" then
						raceContext.Status = "GO! Race started!"
						break
					end

					if cdText == "3" or cdText == "2" or cdText == "1" then
						seenCountdown = true
						raceContext.Status = string.format("Starting Grid - %s...", cdText)
						task.wait(0.05)
						continue
					end

					if phase == "Joining" then
						local joinEnds = getTrackAttr(track, heatState, "RaceJoinEndsAt")
						if type(joinEnds) == "number" then
							local rem = math.max(0, joinEnds - Workspace:GetServerTimeNow())
							raceContext.Status = string.format("Starting Grid - Starting in %.1fs", rem)
						else
							raceContext.Status = "Starting Grid - Waiting for players..."
						end
					elseif phase == "Countdown" then
						seenCountdown = true
						if type(goAt) == "number" then
							local rem = math.max(0, goAt - Workspace:GetServerTimeNow())
							raceContext.Status = string.format("Starting Grid - Countdown (%.1fs)", rem)
						else
							raceContext.Status = "Starting Grid - Countdown 3.. 2.. 1.. GO!"
						end
					else
						if type(goAt) == "number" and Workspace:GetServerTimeNow() >= goAt and seenCountdown then
							break
						end
						raceContext.Status = "Starting Grid - Ready at start line..."
					end

					task.wait(0.05)
				end

				local attachmentTrack = track:FindFirstChild("AttachmentTrack")
				if not attachmentTrack then
					return
				end

				local rtpMod = getRaceTrackPathModule()
				local trackPath = nil
				if rtpMod and type(rtpMod.new) == "function" then
					local ok, res = pcall(rtpMod.new, attachmentTrack)
					if ok and type(res) == "table" then
						trackPath = res
					end
				end
				if not trackPath then
					trackPath = buildFallbackTrackPath(attachmentTrack)
				end
				if not trackPath then
					return
				end

				local rpuMod = getRacePowerUpsModule()
				local spikeParams = nil
				pcall(function()
					if rpuMod and type(rpuMod.Params) == "function" then
						spikeParams = rpuMod.Params({ Track = track, Map = workspace:FindFirstChild("Map") or track })
					end
				end)

				local boostPads = {}
				local slowPads = {}
				local powerUpPads = {}
				local seenBoostPadParts = {}
				local seenSlowPadParts = {}
				local seenPowerUpParts = {}

				local function extractPadBasePart(modelOrPart)
					if not modelOrPart then return nil end
					if modelOrPart:IsA("BasePart") then return modelOrPart end
					local pad = modelOrPart:FindFirstChild("Pad") or modelOrPart:FindFirstChild("Pad", true)
					if pad and pad:IsA("BasePart") then return pad end
					if modelOrPart:IsA("Model") and modelOrPart.PrimaryPart then
						return modelOrPart.PrimaryPart
					end
					return modelOrPart:FindFirstChildWhichIsA("BasePart", true)
				end

				local function registerBoostPad(modelOrPart)
					local pad = extractPadBasePart(modelOrPart)
					if pad and pad:IsA("BasePart") and not seenBoostPadParts[pad] then
						seenBoostPadParts[pad] = true
						table.insert(boostPads, {
							Model = modelOrPart:IsA("Model") and modelOrPart or pad.Parent,
							Pad = pad,
							Radius = math.max(pad.Size.X, pad.Size.Z) * 0.5,
						})
					end
				end

				local function registerSlowPad(modelOrPart)
					local pad = extractPadBasePart(modelOrPart)
					if pad and pad:IsA("BasePart") and not seenSlowPadParts[pad] then
						seenSlowPadParts[pad] = true
						table.insert(slowPads, {
							Model = modelOrPart:IsA("Model") and modelOrPart or pad.Parent,
							Pad = pad,
							Radius = math.max(pad.Size.X, pad.Size.Z) * 0.5 + 4.0,
						})
					end
				end

				local function registerPowerUpPad(modelOrPart)
					local pad = extractPadBasePart(modelOrPart)
					if pad and pad:IsA("BasePart") and not seenPowerUpParts[pad] then
						seenPowerUpParts[pad] = true
						table.insert(powerUpPads, {
							Model = modelOrPart:IsA("Model") and modelOrPart or pad.Parent,
							Pad = pad,
						})
					end
				end

				local function refreshTrackPads()
					for _, bp in ipairs(CollectionService:GetTagged("RaceBoostPad")) do
						if bp:IsDescendantOf(track) or bp:IsDescendantOf(workspace) then
							registerBoostPad(bp)
						end
					end
					for _, sp in ipairs(CollectionService:GetTagged("RaceSlowPad")) do
						if sp:IsDescendantOf(track) or sp:IsDescendantOf(workspace) then
							registerSlowPad(sp)
						end
					end
					for _, pu in ipairs(CollectionService:GetTagged("RacePowerUpSpawn")) do
						if pu:IsDescendantOf(track) or pu:IsDescendantOf(workspace) then
							registerPowerUpPad(pu)
						end
					end
					for _, desc in ipairs(track:GetDescendants()) do
						if desc:IsA("Model") or desc:IsA("BasePart") then
							local n = desc.Name:lower()
							if n:find("boostpad") or n:find("boost_pad") or n:find("raceboost") or desc:GetAttribute("BoostMultiplier") ~= nil or desc:GetAttribute("BoostSeconds") ~= nil then
								registerBoostPad(desc)
							elseif n:find("slowpad") or n:find("slow_pad") or n:find("raceslow") or desc:GetAttribute("SlowMultiplier") ~= nil then
								registerSlowPad(desc)
							elseif n:find("powerupspawn") or desc:GetAttribute("RaceBoxReadyAt") ~= nil then
								registerPowerUpPad(desc)
							end
						end
					end
				end

				refreshTrackPads()
				pcall(function()
					boostTagAddedConn = CollectionService:GetInstanceAddedSignal("RaceBoostPad"):Connect(registerBoostPad)
					slowTagAddedConn = CollectionService:GetInstanceAddedSignal("RaceSlowPad"):Connect(registerSlowPad)
					powerUpTagAddedConn = CollectionService:GetInstanceAddedSignal("RacePowerUpSpawn"):Connect(registerPowerUpPad)
				end)

				local trackedTraps = {}
				local incomingLockThreatUntil = 0

				local remotes = getRemotes()
				local powerUpRemote = remotes and remotes.MountRace and remotes.MountRace.PowerUp or nil
				local powerUpMomentRemote = remotes and remotes.MountRace and remotes.MountRace.PowerUpMoment or nil

				if powerUpMomentRemote and typeof(powerUpMomentRemote.OnClientEvent) == "RBXScriptSignal" then
					powerUpMomentConnection = powerUpMomentRemote.OnClientEvent:Connect(function(kind, arg1, arg2, arg3, arg4, arg5)
						local nowClock = os.clock()
						if kind == "Egg" then
							local id = tostring(arg1 or "")
							local cf = typeof(arg3) == "CFrame" and arg3 or (typeof(arg3) == "Vector3" and CFrame.new(arg3) or nil)
							if id ~= "" and cf then
								trackedTraps[id] = {
									Kind = "Egg",
									Position = cf.Position,
									Radius = 10.5,
									ExpiresAt = nowClock + 45,
								}
							end
						elseif kind == "DrillaWarn" then
							local id = tostring(arg1 or "")
							local spot = typeof(arg3) == "Vector3" and arg3 or nil
							if id ~= "" and spot then
								trackedTraps[id] = {
									Kind = "DrillaWarn",
									Position = spot,
									Radius = 13.0,
									ExpiresAt = nowClock + 4.5,
								}
							end
							if arg2 == localPlayer then
								incomingLockThreatUntil = nowClock + 2.5
							end
						elseif kind == "Spike" then
							local id = tostring(arg1 or "")
							local startPos = typeof(arg3) == "Vector3" and arg3 or nil
							local dir = typeof(arg4) == "Vector3" and arg4 or Vector3.new(0, 0, 1)
							local sTime = tonumber(arg5) or Workspace:GetServerTimeNow()
							if id ~= "" and startPos then
								local spikePath = nil
								if rpuMod and type(rpuMod.SpikePath) == "function" and spikeParams then
									local ok, sp = pcall(rpuMod.SpikePath, startPos, dir, 110 * 2.6, spikeParams)
									if ok and type(sp) == "table" then
										spikePath = sp
									end
								end
								trackedTraps[id] = {
									Kind = "Spike",
									Position = startPos,
									Direction = dir.Magnitude > 0.001 and dir.Unit or Vector3.new(0, 0, 1),
									StartTime = sTime,
									SpikePath = spikePath,
									Radius = 11.5,
									ExpiresAt = nowClock + 3.2,
								}
							end
						elseif kind == "PodLock" then
							if arg2 == localPlayer then
								incomingLockThreatUntil = nowClock + 3.0
							end
						elseif kind == "EggEnd" or kind == "SpikeEnd" or kind == "DrillaEnd" or kind == "PodEnd" or kind == "Clear" then
							local id = tostring(arg1 or "")
							if id ~= "" then
								trackedTraps[id] = nil
							end
						end
					end)
				end

				local root = state.Root()
				if not root then return end

				local progress = trackPath:Project(root.Position, 0, trackPath.Length, trackPath.Length)
				local lastPowerUpUseAt = 0
				local smoothedLateralOffset = 0
				local currentDriveNote = ""
				local lastDesiredDir = nil
				local lastTrackTangent = nil
				local lastSteerAngle = 0
				local lastAvoidingTrap = false
				local lastTargetingBoost = false
				local committedDodgeSide = nil
				local committedDodgeUntil = 0

				activeMountCtrl = findActiveMountController(root)
				controlsObj = getControlsSingleton()
				mountCtrlMod = getMountControllerModule()
				local raceEffectsMod = getRaceEffectsModule()

				local function getSmoothFrameAt(s)
					local fCenter = trackPath:FrameAt(s)
					local fBack = trackPath:FrameAt(s - 5)
					local fFwd = trackPath:FrameAt(s + 5)
					local tangent = fFwd.Position - fBack.Position
					local up = (fBack.UpVector + fCenter.UpVector + fFwd.UpVector)
					up = up.Magnitude > 0.001 and up.Unit or fCenter.UpVector
					if tangent.Magnitude > 0.001 then
						return CFrame.lookAt(fCenter.Position, fCenter.Position + tangent.Unit, up)
					end
					return fCenter
				end

				local function getSafeLateralBounds(curS)
					local minLat = -16.0
					local maxLat = 16.0
					local rParams = (activeMountCtrl and activeMountCtrl.Params) or spikeParams
					if not rParams then
						return minLat, maxLat
					end
					for _, aheadD in ipairs({ 6, 16, 26 }) do
						local f = getSmoothFrameAt(curS + aheadD)
						local origin = f.Position + f.UpVector * 2.5
						local right = f.RightVector
						local hitLeft = Workspace:Raycast(origin, -right * 32, rParams)
						if hitLeft and hitLeft.Normal:Dot(f.UpVector) < 0.55 then
							local dLeft = (hitLeft.Position - origin).Magnitude
							minLat = math.max(minLat, -math.max(4.0, dLeft - 5.5))
						end
						local hitRight = Workspace:Raycast(origin, right * 32, rParams)
						if hitRight and hitRight.Normal:Dot(f.UpVector) < 0.55 then
							local dRight = (hitRight.Position - origin).Magnitude
							maxLat = math.min(maxLat, math.max(4.0, dRight - 5.5))
						end
					end
					if minLat > maxLat then
						local mid = (minLat + maxLat) * 0.5
						return mid - 2, mid + 2
					end
					return minLat, maxLat
				end

				local function collectAheadHazards(curProgress, curRootPos)
					local hazards = {}
					local nowClock = os.clock()
					local serverNow = Workspace:GetServerTimeNow()

					local function tryAddHazard(pos, radius, kind)
						if not pos then return end
						local dist3D = (pos - curRootPos).Magnitude
						if dist3D > 115 then return end
						local sTrap, errTrap = trackPath:Project(pos, curProgress, 12, 115)
						local fwd = sTrap - curProgress
						if fwd >= -4 and fwd <= 105 and errTrap <= 50 then
							local fTrap = getSmoothFrameAt(sTrap)
							local rel = fTrap:PointToObjectSpace(pos)
							if math.abs(rel.Y) <= 24 then
								table.insert(hazards, {
									ForwardDist = fwd,
									LateralX = rel.X,
									WorldPos = pos,
									TrackS = sTrap,
									Radius = radius or 10.5,
									Kind = kind,
								})
							end
						end
					end

					for id, trap in pairs(trackedTraps) do
						if nowClock > (trap.ExpiresAt or 0) then
							trackedTraps[id] = nil
						else
							local pos = trap.Position
							if trap.Kind == "Spike" then
								local elapsed = math.max(0, serverNow - (trap.StartTime or serverNow))
								if trap.SpikePath and rpuMod and type(rpuMod.PathAt) == "function" then
									local ok, pPos = pcall(rpuMod.PathAt, trap.SpikePath, elapsed)
									if ok and typeof(pPos) == "Vector3" then
										pos = pPos
									end
								else
									pos = trap.Position + trap.Direction * (286 * elapsed)
								end
							end
							tryAddHazard(pos, trap.Radius or 10.5, trap.Kind)
						end
					end

					local fxFolder = workspace:FindFirstChild("RacePowerUpFX")
					if fxFolder then
						for _, child in ipairs(fxFolder:GetChildren()) do
							if child:IsA("Model") then
								local name = child.Name
								local isEgg = (name == "Splat" or name == "Egg" or child:FindFirstChild("Yolk") ~= nil)
								local isSpike = (name == "Spike")
								local isWarn = (name == "Warning" or child:FindFirstChild("Disc") ~= nil)
								local isDrilla = (name == "Drilla")
								if isEgg or isSpike or isWarn or isDrilla then
									local ok, piv = pcall(child.GetPivot, child)
									if ok and typeof(piv) == "CFrame" then
										local rad = isWarn and 13.0 or (isSpike and 11.5 or (isDrilla and 12.0 or 10.5))
										tryAddHazard(piv.Position, rad, name)
									end
								end
							end
						end
					end

					for _, sp in ipairs(slowPads) do
						local pad = sp.Pad
						if pad and pad.Parent then
							tryAddHazard(pad.Position, sp.Radius or 9.0, "SlowPad")
						end
					end

					table.sort(hazards, function(a, b)
						return a.ForwardDist < b.ForwardDist
					end)
					return hazards
				end

				local function pointToSegmentDistXZ(p, a, b)
					local abX, abZ = b.X - a.X, b.Z - a.Z
					local apX, apZ = p.X - a.X, p.Z - a.Z
					local lenSq = abX * abX + abZ * abZ
					if lenSq <= 0.001 then
						return math.sqrt(apX * apX + apZ * apZ)
					end
					local t = math.clamp((apX * abX + apZ * abZ) / lenSq, 0, 1)
					local dx = (a.X + abX * t) - p.X
					local dz = (a.Z + abZ * t) - p.Z
					return math.sqrt(dx * dx + dz * dz)
				end

				local function computeControlVector()
					local curRoot = state.Root()
					if not curRoot or not isInRace() or gen ~= raceContext.RacingGeneration then
						lastDesiredDir = nil
						return Vector3.zero
					end

					if localPlayer:GetAttribute("RaceFinishPlace") ~= nil or localPlayer:GetAttribute("RaceFinishTime") ~= nil then
						lastDesiredDir = nil
						return Vector3.zero
					end

					local nowClock = os.clock()
					local curRootPos = curRoot.Position
					progress = trackPath:Project(curRootPos, progress, 30, 80)

					local curFrame = getSmoothFrameAt(progress)
					local curRel = curFrame:PointToObjectSpace(curRootPos)
					local currentLat = curRel.X
					lastTrackTangent = curFrame.LookVector

					local hazards = collectAheadHazards(progress, curRootPos)

					local aheadBoosts = {}
					if raceContext.AutoBoostPad then
						for _, bp in ipairs(boostPads) do
							local pad = bp.Pad
							if pad and pad.Parent then
								local padPos = pad.Position
								if (padPos - curRootPos).Magnitude <= 135 then
									local sPad, errPad = trackPath:Project(padPos, progress, 4, 120)
									local fwd = sPad - progress
									if fwd >= -1 and fwd <= 115 and errPad <= 48 then
										local fPad = getSmoothFrameAt(sPad)
										local rel = fPad:PointToObjectSpace(padPos)
										if math.abs(rel.Y) <= 20 then
											local aimLat = math.abs(rel.X) > 10 and (rel.X - math.sign(rel.X) * 1.5) or rel.X
											table.insert(aheadBoosts, {
												ForwardDist = fwd,
												LateralX = aimLat,
												RawLateralX = rel.X,
												WorldPos = padPos,
												TrackS = sPad,
												Pad = pad,
												Model = bp.Model,
											})
										end
									end
								end
							end
						end
						table.sort(aheadBoosts, function(a, b)
							return a.ForwardDist < b.ForwardDist
						end)
					end

					local aheadBoxes = {}
					if raceContext.AutoPowerUp and localPlayer:GetAttribute("RacePowerUp") == nil then
						for _, pb in ipairs(powerUpPads) do
							local pad = pb.Pad
						if pad and pad.Parent then
								local boxReadyAt = pb.Model and pb.Model:GetAttribute("RaceBoxReadyAt")
								local isReady = (type(boxReadyAt) ~= "number") or (Workspace:GetServerTimeNow() >= boxReadyAt)
								if isReady then
									local padPos = pad.Position
									if (padPos - curRootPos).Magnitude <= 110 then
										local sPad, errPad = trackPath:Project(padPos, progress, 4, 95)
										local fwd = sPad - progress
										if fwd >= 0 and fwd <= 85 and errPad <= 44 then
											local fPad = getSmoothFrameAt(sPad)
											local rel = fPad:PointToObjectSpace(padPos)
											if math.abs(rel.Y) <= 18 then
												local aimLat = math.abs(rel.X) > 10 and (rel.X - math.sign(rel.X) * 1.5) or rel.X
												table.insert(aheadBoxes, {
													ForwardDist = fwd,
													LateralX = aimLat,
													WorldPos = padPos,
												})
											end
										end
									end
								end
							end
						end
					end

					local lockedBoostPad = nil
					for _, bp in ipairs(aheadBoosts) do
						local latDelta = math.abs(bp.LateralX - currentLat)
						local reachable = (latDelta <= 6.0) or (bp.ForwardDist >= 14 and latDelta <= (math.max(0, bp.ForwardDist) * 0.75 + 6.0))
						if reachable then
							local blocked = false
							for _, hz in ipairs(hazards) do
								if hz.ForwardDist <= bp.ForwardDist + 10 and math.abs(bp.LateralX - hz.LateralX) < (hz.Radius + 2.0) then
									blocked = true
									break
								end
							end
							if not blocked then
								lockedBoostPad = bp
								break
							end
						end
					end

					local sampleSteps = { 7, 14, 21, 30, 42, 55 }
					local sampleFrames = {}
					for i, d in ipairs(sampleSteps) do
						sampleFrames[i] = getSmoothFrameAt(progress + d)
					end

					local candidateLanes = { -26, -22, -18, -15, -12, -9, -6, -3, 0, 3, 6, 9, 12, 15, 18, 22, 26 }
					for _, bp in ipairs(aheadBoosts) do
						if math.abs(bp.LateralX) <= 34 then
							table.insert(candidateLanes, bp.LateralX)
						end
					end
					for _, bx in ipairs(aheadBoxes) do
						if math.abs(bx.LateralX) <= 32 then
							table.insert(candidateLanes, bx.LateralX)
						end
					end

					if nowClock >= committedDodgeUntil or #hazards == 0 then
						committedDodgeSide = nil
					end

					local bestLane = 0
					local bestScore = -math.huge
					local avoidingTrap = false
					local targetingBoost = false

					for _, laneX in ipairs(candidateLanes) do
						local score = -math.abs(laneX) * 0.25 - math.abs(laneX - currentLat) * 0.16 - math.abs(laneX - smoothedLateralOffset) * 0.12
						local laneBlockedByTrap = false

						local curvePts = {}
						for i, d in ipairs(sampleSteps) do
							local blend = math.clamp(d / 20, 0, 1)
							local latAtD = currentLat + (laneX - currentLat) * blend
							local f = sampleFrames[i]
							curvePts[i] = f.Position + f.RightVector * latAtD
						end

						for _, hz in ipairs(hazards) do
							local safeClearance = hz.Radius + 2.8
							local latDiffEnd = math.abs(laneX - hz.LateralX)

							local min3DDist = math.huge
							if hz.WorldPos and hz.ForwardDist <= 70 then
								local p0 = curRootPos
								for i = 1, #curvePts do
									local segDist = pointToSegmentDistXZ(hz.WorldPos, p0, curvePts[i])
									if segDist < min3DDist then
										min3DDist = segDist
									end
									p0 = curvePts[i]
								end

								local chordDist = pointToSegmentDistXZ(hz.WorldPos, curRootPos, curvePts[3])
								if chordDist < min3DDist then
									min3DDist = chordDist
								end
							end

							local effectiveDist = math.min(latDiffEnd, min3DDist)
							if effectiveDist < safeClearance then
								laneBlockedByTrap = true
								local urgency = math.clamp(1 - math.max(0, hz.ForwardDist) / 95, 0.3, 1.0)
								local penetration = (safeClearance - effectiveDist) / safeClearance
								score = score - (2200 * urgency * (0.5 + penetration))
							end

							if hz.ForwardDist >= -1 and hz.ForwardDist <= 55 then
								if (currentLat - hz.LateralX) * (laneX - hz.LateralX) < 0 and math.abs(currentLat - hz.LateralX) > 2.0 then
									laneBlockedByTrap = true
									score = score - 1600
								end
							end
						end

						if committedDodgeSide and #hazards > 0 and hazards[1].ForwardDist <= 65 then
							local hz1 = hazards[1]
							local sideOfTrap = (laneX >= hz1.LateralX) and 1 or -1
							if sideOfTrap == committedDodgeSide and not laneBlockedByTrap then
								score = score + 180
							end
						end

						if not laneBlockedByTrap then
							if lockedBoostPad then
								local latDiff = math.abs(laneX - lockedBoostPad.LateralX)
								if latDiff <= 5.0 then
									local proximity = math.clamp(1 - math.max(0, lockedBoostPad.ForwardDist) / 115, 0.3, 1.0)
									score = score + (680 * proximity) * (1 - latDiff / 6.0)
								end
							end
							for _, bp in ipairs(aheadBoosts) do
								local latDiff = math.abs(laneX - bp.LateralX)
								if latDiff <= 4.5 then
									local proximity = math.clamp(1 - math.max(0, bp.ForwardDist) / 115, 0.25, 1.0)
									score = score + (360 * proximity) * (1 - latDiff / 5.5)
								end
							end

							for _, bx in ipairs(aheadBoxes) do
								local latDiff = math.abs(laneX - bx.LateralX)
								if latDiff <= 4.5 then
									local proximity = math.clamp(1 - math.max(0, bx.ForwardDist) / 85, 0.2, 1.0)
									score = score + (140 * proximity) * (1 - latDiff / 5.5)
								end
							end
						end

						if score > bestScore then
							bestScore = score
							bestLane = laneX
						end
					end

					for _, hz in ipairs(hazards) do
						local d3D = hz.WorldPos and pointToSegmentDistXZ(hz.WorldPos, curRootPos, curRootPos + curFrame.LookVector * 35) or math.huge
						if (math.abs(currentLat - hz.LateralX) < (hz.Radius + 3.0) or d3D < (hz.Radius + 3.5)) and hz.ForwardDist <= 75 then
							avoidingTrap = true
							committedDodgeSide = (bestLane >= hz.LateralX) and 1 or -1
							committedDodgeUntil = nowClock + 0.65
							break
						end
					end

					local activeTargetBoost = nil
					if lockedBoostPad and math.abs(bestLane - lockedBoostPad.LateralX) <= 4.0 then
						targetingBoost = true
						activeTargetBoost = lockedBoostPad
					else
						for _, bp in ipairs(aheadBoosts) do
							if math.abs(bestLane - bp.LateralX) <= 3.5 then
								targetingBoost = true
								activeTargetBoost = bp
								break
							end
						end
					end

					if avoidingTrap then
						currentDriveNote = " [Dodging Trap!]"
					elseif targetingBoost then
						currentDriveNote = " [Boost Pad!]"
					else
						currentDriveNote = ""
					end

					local lerpAlpha = avoidingTrap and 0.68 or (targetingBoost and 0.55 or 0.28)
					smoothedLateralOffset = smoothedLateralOffset + (bestLane - smoothedLateralOffset) * lerpAlpha

					local curVel = curRoot.AssemblyLinearVelocity
					local speedMag = curVel.Magnitude
					local lookAhead = avoidingTrap and math.clamp(speedMag * 0.16, 14, 20)
						or (targetingBoost and math.clamp(speedMag * 0.22, 16, 26) or math.clamp(speedMag * 0.28, 18, 36))

					local targetPos
					if not avoidingTrap and activeTargetBoost and activeTargetBoost.ForwardDist >= -1 then
						local fwd = activeTargetBoost.ForwardDist
						if fwd > 16 then
							local boostLook = math.max(14.0, math.min(fwd * 0.65, 20.0))
							local fAim = getSmoothFrameAt(progress + boostLook)
							targetPos = fAim.Position + fAim.RightVector * activeTargetBoost.LateralX
						else
							local fPad = getSmoothFrameAt(activeTargetBoost.TrackS or (progress + math.max(0, fwd)))
							local leadAhead = math.max(14.0 - math.max(0, fwd), 4.0)
							local rawLat = activeTargetBoost.RawLateralX or activeTargetBoost.LateralX
							local inset = math.abs(rawLat) > 10 and (math.sign(rawLat) * 1.5) or 0
							local insetPadPos = activeTargetBoost.WorldPos - fPad.RightVector * inset
							targetPos = insetPadPos + fPad.LookVector * leadAhead
						end
					else
						local targetFrame = getSmoothFrameAt(progress + lookAhead)
						targetPos = targetFrame.Position + targetFrame.RightVector * smoothedLateralOffset
					end

					local upVec = curFrame.UpVector
					local forwardLook = (activeMountCtrl and activeMountCtrl.Heading) or curRoot.CFrame.LookVector
					local flatLook = forwardLook - upVec * forwardLook:Dot(upVec)
					flatLook = flatLook.Magnitude > 0.001 and flatLook.Unit or curFrame.LookVector

					local toTarget = targetPos - curRootPos
					local flatTarget = toTarget - upVec * toTarget:Dot(upVec)
					if flatTarget.Magnitude <= 0.001 then
						lastDesiredDir = flatLook
						lastSteerAngle = 0
						lastAvoidingTrap = avoidingTrap
						lastTargetingBoost = targetingBoost
						return Vector3.new(0, 0, -1)
					end
					flatTarget = flatTarget.Unit

					local rightVec = flatLook:Cross(upVec)
					rightVec = rightVec.Magnitude > 0.001 and rightVec.Unit or curFrame.RightVector

					local sinA = flatTarget:Dot(rightVec)
					local cosA = flatTarget:Dot(flatLook)
					local angle = math.atan2(sinA, cosA)

					lastDesiredDir = flatTarget
					lastSteerAngle = angle
					lastAvoidingTrap = avoidingTrap
					lastTargetingBoost = targetingBoost

					local steerSensitivity = (avoidingTrap or targetingBoost) and math.rad(13) or math.rad(18)
					local steerX = math.clamp(angle / steerSensitivity, -1, 1)

					if activeMountCtrl and type(activeMountCtrl) == "table" then
						pcall(function()
							activeMountCtrl.Handbrake = false
						end)
					end

					return Vector3.new(steerX, 0, -1)
				end

				local function applyPostStepSteeringAssist(ctrl, dt)
					if not ctrl or type(ctrl) ~= "table" then return end
					local isBoosted = (os.clock() < (ctrl.BoostUntil or 0)) or (localPlayer:GetAttribute("RacePowerUpEffect") ~= nil)
					if type(ctrl.SpeedScales) == "table" then
						for k in pairs(ctrl.SpeedScales) do
							if tostring(k):find("^SlowPad") then
								ctrl.SpeedScales[k] = nil
							end
						end

						ctrl.SpeedScales["NexRaceScale"] = isBoosted and nil or 1.06
					end
					if ctrl.Override ~= nil or not ctrl.Grounded or ctrl:IsHeld() or (ctrl.Speed or 0) <= 2 or not lastDesiredDir then
						return
					end
					local upVec = ctrl.Up or Vector3.new(0, 1, 0)
					local curH = ctrl.Heading or lastDesiredDir
					local flatH = curH - upVec * curH:Dot(upVec)
					flatH = flatH.Magnitude > 0.001 and flatH.Unit or lastDesiredDir

					local flatDes = lastDesiredDir - upVec * lastDesiredDir:Dot(upVec)
					if flatDes.Magnitude <= 0.001 then return end
					flatDes = flatDes.Unit

					local blendRate = lastAvoidingTrap and 0.52 or (lastTargetingBoost and 0.38 or 0.28)
					local newH = flatH:Lerp(flatDes, blendRate)
					if newH.Magnitude <= 0.001 then return end
					newH = newH.Unit

					ctrl.Heading = newH
					ctrl.TravelDirection = newH

					if ctrl.StickMinRatio == nil and ctrl.Drive and ctrl.Align then
						local rightAxis = newH:Cross(upVec)
						if rightAxis.Magnitude > 0.001 then
							rightAxis = rightAxis.Unit
							ctrl.Drive.PrimaryTangentAxis = newH
							ctrl.Drive.SecondaryTangentAxis = rightAxis
							local velVec = newH * ctrl.Speed
							ctrl.Drive.PlaneVelocity = Vector2.new(velVec:Dot(newH), velVec:Dot(rightAxis))
							ctrl.Align.CFrame = CFrame.lookAt(Vector3.zero, newH, upVec)
						end
					end
				end

				if controlsObj then
					origGetMoveVector = resolveTrueGetMoveVector(controlsObj)
					myGetMoveVectorHook = function(self, ...)
						if isInRace() and raceContext.AutoComplete and gen == raceContext.RacingGeneration then
							local ok, vec = pcall(computeControlVector)
							if ok and typeof(vec) == "Vector3" then
								return vec
							end
						end
						return origGetMoveVector(self, ...)
					end
					controlsObj.GetMoveVector = myGetMoveVectorHook
				end

				if mountCtrlMod then
					origMountStep = resolveTrueMountStep(mountCtrlMod, getControlsSingleton)
					myMountStepHook = function(self, dt, ...)
						if isInRace() and raceContext.AutoComplete and gen == raceContext.RacingGeneration then
							if type(self) == "table" and self.Rig and self.Rig.Root == state.Root() then
								activeMountCtrl = self
							end
						end
						local res = origMountStep(self, dt, ...)
						if isInRace() and raceContext.AutoComplete and gen == raceContext.RacingGeneration and self == activeMountCtrl then
							pcall(applyPostStepSteeringAssist, self, dt)
						end
						return res
					end
					mountCtrlMod.Step = myMountStepHook
				end

				local mrData = getMountRaceData()
				local lastBoostPadHitAt = 0
				local lastPadScanAt = os.clock()
				local lastHitboxPos = nil

				local function checkSweptBoostPadHit(pad, prevPos, curPos, padRadius)
					local padMargin = Vector3.new(4.5, 5.5, 4.5)
					if mrData and type(mrData.IsInsidePart) == "function" then
						local ok, inside = pcall(mrData.IsInsidePart, pad, curPos, padMargin)
						if ok and inside == true then return true end
						if prevPos then
							local dist = (curPos - prevPos).Magnitude
							if dist > 1.5 and dist <= 45 then
								local steps = math.ceil(dist / 2)
								for i = 1, steps - 1 do
									local samplePos = prevPos:Lerp(curPos, i / steps)
									local okS, inS = pcall(mrData.IsInsidePart, pad, samplePos, padMargin)
									if okS and inS == true then return true end
								end
							end
						end
						return false
					else
						return (pad.Position - curPos).Magnitude <= ((padRadius or 6.0) + 4.5)
					end
				end

				helperConnection = RunService.Heartbeat:Connect(function(dt)
					if not isInRace() or gen ~= raceContext.RacingGeneration then return end
					if controlsObj and myGetMoveVectorHook and controlsObj.GetMoveVector ~= myGetMoveVectorHook then
						pcall(function() controlsObj.GetMoveVector = myGetMoveVectorHook end)
					end
					if mountCtrlMod and myMountStepHook and mountCtrlMod.Step ~= myMountStepHook then
						pcall(function() mountCtrlMod.Step = myMountStepHook end)
					end
					local curRoot = state.Root()
					if not curRoot then return end

					local nowClock = os.clock()
					if nowClock - lastPadScanAt >= 0.4 then
						lastPadScanAt = nowClock
						pcall(refreshTrackPads)
					end

					local curChar = localPlayer.Character
					local curHum = curChar and curChar:FindFirstChildOfClass("Humanoid")
					if curHum and not curHum.PlatformStand then
						pcall(function() curHum.PlatformStand = true end)
					end

					if not activeMountCtrl then
						activeMountCtrl = findActiveMountController(curRoot)
					end

					if activeMountCtrl and not origMountStep then
						pcall(applyPostStepSteeringAssist, activeMountCtrl, dt)
					end

					local mount = curChar and curChar:FindFirstChild("RaceMount")
					local hitboxPos = (mount and mount:FindFirstChild("Hitbox") and mount.Hitbox.Position) or curRoot.Position
					if activeMountCtrl and type(activeMountCtrl.ApplyBoost) == "function" and nowClock - lastBoostPadHitAt > 0.30 then
						for _, bp in ipairs(boostPads) do
							if bp.Pad and bp.Pad.Parent and (bp.Pad.Position - hitboxPos).Magnitude <= 32 then
								if checkSweptBoostPadHit(bp.Pad, lastHitboxPos, hitboxPos, bp.Radius) then
									lastBoostPadHitAt = nowClock
									local mult = (bp.Model and tonumber(bp.Model:GetAttribute("BoostMultiplier"))) or 1.6
									local secs = (bp.Model and tonumber(bp.Model:GetAttribute("BoostSeconds"))) or 1.2
									pcall(function()
										activeMountCtrl:ApplyBoost(mult, secs)
									end)
									break
								end
							end
						end
					end
					lastHitboxPos = hitboxPos

					if raceContext.AutoPowerUp and powerUpRemote then
						local heldItem = localPlayer:GetAttribute("RacePowerUp")
						local rollEndsAt = localPlayer:GetAttribute("RacePowerUpRollEndsAt")
						local effectNow = localPlayer:GetAttribute("RacePowerUpEffect")
						local serverNow = Workspace:GetServerTimeNow()
					if type(heldItem) == "string" and heldItem ~= "" and effectNow == nil and (type(rollEndsAt) ~= "number" or serverNow >= rollEndsAt) then
							local shouldUse = true
							if heldItem == "Shield" then
								shouldUse = (nowClock < incomingLockThreatUntil) or (currentDriveNote == " [Dodging Trap!]")
								if not shouldUse then
									for _, pb in ipairs(powerUpPads) do
										if pb.Pad and pb.Pad.Parent and (pb.Pad.Position - curRoot.Position).Magnitude <= 28 then
											shouldUse = true
											break
										end
									end
								end
							end
							if shouldUse and nowClock - lastPowerUpUseAt > 0.65 then
								lastPowerUpUseAt = nowClock
								local heading = (activeMountCtrl and activeMountCtrl.Heading) or curRoot.CFrame.LookVector
								pcall(function()
									powerUpRemote:FireServer("Use", curRoot.Position, heading)
								end)
							end
						end
					end
				end)

				local heatState = getHeatState(track)
				local totalLaps = getTrackAttr(track, heatState, "RaceLaps") or 3
				if totalLaps < 1 then totalLaps = 3 end

				local raceTimeout = os.clock() + 200
				while gen == raceContext.RacingGeneration and isInRace() and os.clock() < raceTimeout do
					local fp = localPlayer:GetAttribute("RaceFinishPlace")
					local ft = localPlayer:GetAttribute("RaceFinishTime")
					local hs = getHeatState(track)
					local ph = getTrackAttr(track, hs, "RacePhase")

					if fp ~= nil or ft ~= nil or ph == "Results" then
						break
					end

					local serverLap = localPlayer:GetAttribute("RaceLap") or 1
					local serverPlace = localPlayer:GetAttribute("RacePlace")
					local lapPct = math.clamp(math.floor(((progress % trackPath.Length) / trackPath.Length) * 100), 0, 99)
					local placeStr = serverPlace and string.format("Place #%d", serverPlace) or "Racing"
					raceContext.Status = string.format("Racing - Lap %d/%d (%d%%) | %s%s", serverLap, totalLaps, lapPct, placeStr, currentDriveNote)

					task.wait(0.1)
				end

				cleanupRaceDriver()

				local confirmWait = os.clock() + 5
				while isInRace() and os.clock() < confirmWait do
					if localPlayer:GetAttribute("RaceFinishPlace") ~= nil or localPlayer:GetAttribute("RaceFinishTime") ~= nil then
						break
					end
					task.wait(0.15)
				end

				local finishPlace = localPlayer:GetAttribute("RaceFinishPlace")
				local finishTime = localPlayer:GetAttribute("RaceFinishTime")

				raceContext.PostRaceCooldown = os.clock() + 45
				raceContext.LastFinishedSessionEndsAt = workspace:GetAttribute("RaceRallyJoinEndsAt")

				local placeText = finishPlace and string.format(" (Place #%d)", finishPlace) or ""
				local timeText = finishTime and string.format(" [%.2fs]", finishTime) or ""

				if finishTime ~= nil or finishPlace ~= nil then
					raceContext.Status = "Race Finished!" .. placeText .. timeText
					state.Notify("Race Rally", "Race finished!" .. placeText .. timeText)
				else
					raceContext.Status = "Race ended - Waiting for server results..."
				end

				if isInRace() then
					if raceContext.AutoLeave and finishTime ~= nil then
						task.wait(1.0)
						if isInRace() and remotes and remotes.MountRace and remotes.MountRace.AskLeave then
							raceContext.Status = "Auto Leave active - Leaving race arena..."
							pcall(function() remotes.MountRace.AskLeave:FireServer() end)
						end
					else
						raceContext.Status = string.format("Finished%s - Waiting for server transition...", placeText)
						local stayWait = os.clock() + 75
						while isInRace() and os.clock() < stayWait do
							if raceContext.AutoLeave and finishTime ~= nil then
								if remotes and remotes.MountRace and remotes.MountRace.AskLeave then
									pcall(function() remotes.MountRace.AskLeave:FireServer() end)
								end
								break
							end
							task.wait(0.5)
						end
					end
				end

				local worldWait = os.clock() + 15
				while isInRace() and os.clock() < worldWait do
					task.wait(0.3)
				end

				task.wait(1.2)
				local postProfile = getPlayerProfile()
				local postRaceData = postProfile and postProfile.RaceRally or {}
				local postTokens = tonumber(postRaceData.Tokens) or preTokens
				local postWins = tonumber(postRaceData.Wins) or preWins
				local diffTokens = math.max(0, postTokens - preTokens)
				local diffWins = math.max(0, postWins - preWins)

				if diffTokens > 0 or diffWins > 0 then
					local rewardMsg = string.format("+%d Trophies, +%d Win(s)! (Total: %d Trophies | %d Wins)", diffTokens, diffWins, postTokens, postWins)
					raceContext.Status = "Reward received: " .. rewardMsg
					state.Notify("Race Rally Reward", rewardMsg)
				else
					raceContext.Status = string.format("Race completed%s (Total: %d Trophies | %d Wins)", placeText, postTokens, postWins)
				end

				if raceContext.AutoClaim then
					pcall(claimAllMilestones)
				end
				if raceContext.AutoBuyNitro then
					pcall(function() buyShopItem("MutationToken") end)
				end
			end)

			cleanupRaceDriver()
			if not isInRace() then
				releaseRaceShieldPause()
			end
			state.ReleaseMovement("race")
			raceContext.Busy = false
		end)
	end

	local raceStatusRow = raceRallySection:CreateText({
		Name = "Race Status",
		Text = "Checking race schedule...",
	})

	local trophiesRow = raceRallySection:CreateText({
		Name = "Trophies Owned",
		Text = "0 Trophies  |  0 Wins",
	})

	raceContext.AutoJoinHandle = raceRallySection:CreateToggle({
		Name = "Auto Join Race",
		Note = "Automatically glide to the portal and join when the race opens (every 30m)",
		Default = false,
		Callback = function(val)
			raceContext.AutoJoin = val == true
			if not val and not raceContext.AutoComplete and not isInRace() then
				releaseRaceShieldPause()
			end
			taskScheduler.Wake()
		end,
	})

	raceRallySection:CreateSlider({
		Name = "Portal Glide Speed",
		Note = "Gliding speed toward the race portal",
		Min = 100,
		Max = 500,
		Default = 250,
		Increment = 25,
		Unit = "studs/s",
		SubOf = raceContext.AutoJoinHandle,
		Callback = function(val)
			raceContext.JoinSpeed = math.clamp(tonumber(val) or 250, 100, 500)
		end,
	})

	raceContext.AutoCompleteHandle = raceRallySection:CreateToggle({
		Name = "Auto Complete Race",
		Note = "Automatically steer mount, dodge Traps, and hit BoostPads on the track",
		Default = true,
		Callback = function(val)
			raceContext.AutoComplete = val ~= false
			if val ~= false and isInRace() then
				runRaceAuto()
			elseif not val and not raceContext.AutoJoin and not isInRace() then
				releaseRaceShieldPause()
			end
			taskScheduler.Wake()
		end,
	})

	raceRallySection:CreateToggle({
		Name = "Auto Detect BoostPad",
		Note = "Automatically detect and steer onto BoostPads (disable to stay centered and only dodge traps)",
		Default = false,
		SubOf = raceContext.AutoCompleteHandle,
		Callback = function(val)
			raceContext.AutoBoostPad = val == true
		end,
	})

	raceRallySection:CreateToggle({
		Name = "Auto Collect Power-Ups",
		Note = "Automatically collect and use power-ups (smartly holds Shield to block incoming attacks)",
		Default = true,
		SubOf = raceContext.AutoCompleteHandle,
		Callback = function(val)
			raceContext.AutoPowerUp = val ~= false
		end,
	})

	raceRallySection:CreateToggle({
		Name = "Auto Leave After Race",
		Note = "Automatically leave the race arena after FinishTime is recorded",
		Default = true,
		SubOf = raceContext.AutoCompleteHandle,
		Callback = function(val)
			raceContext.AutoLeave = val ~= false
		end,
	})

	raceRallySection:CreateToggle({
		Name = "Auto Claim Milestones",
		Note = "Automatically claim Race Rally win milestone rewards",
		Default = false,
		Callback = function(val)
			raceContext.AutoClaim = val == true
			if val == true then
				task.spawn(claimAllMilestones)
			end
			taskScheduler.Wake()
		end,
	})

	raceRallySection:CreateButton({
		Name = "Claim All Milestones Now",
		ButtonText = "Claim",
		ConfirmText = "Done!",
		Callback = function()
			task.spawn(claimAllMilestones)
		end,
	})

	raceRallySection:CreateToggle({
		Name = "Auto Buy Nitro Mutation",
		Note = "Automatically purchase Nitro Mutation Token (475 Trophies) when affordable",
		Default = false,
		Callback = function(val)
			raceContext.AutoBuyNitro = val == true
			taskScheduler.Wake()
		end,
	})

	raceRallySection:CreateDropdown({
		Name = "Auto Buy Other Item",
		Note = "Select an additional shop item to purchase automatically",
		Options = { "Off", "2x Cash Booster (200)", "1.25x Speed Boost (250)" },
		Default = "Off",
		Callback = function(val)
			raceContext.AutoBuyChoice = tostring(val or "Off")
			taskScheduler.Wake()
		end,
	})

	raceRallySection:CreateButton({
		Name = "Buy Nitro Mutation Now",
		ButtonText = "Buy (475)",
		ButtonColor = Color3.fromRGB(80, 200, 120),
		ConfirmText = "Purchased!",
		Callback = function()
			task.spawn(function()
				local ok, res = buyShopItem("MutationToken")
				if ok then
					state.Notify("Race Rally", "Successfully purchased Nitro Mutation Token!")
				else
					state.Notify("Race Rally", "Failed to purchase Nitro Mutation Token!")
				end
			end)
		end,
	})

	taskScheduler.Add(function()
		local now = os.clock()
		local profile = getPlayerProfile()
		local raceData = profile and profile.RaceRally or {}
		raceContext.Trophies = tonumber(raceData.Tokens) or tonumber(raceData.RaceTokens) or (profile and profile.Currencies and tonumber(profile.Currencies.RaceTokens)) or 0
		raceContext.Wins = tonumber(raceData.Wins) or 0

		if trophiesRow and type(trophiesRow.Set) == "function" then
			pcall(trophiesRow.Set, trophiesRow, string.format("%d Trophies  |  %d Wins", raceContext.Trophies, raceContext.Wins))
		end

		local inRace = isInRace()
		local portalOpen = isRacePortalOpen()
		local inCooldown = now < (raceContext.PostRaceCooldown or 0)
		local currentJoinEndsAt = workspace:GetAttribute("RaceRallyJoinEndsAt")
		local alreadyJoinedCurrentSession = (raceContext.LastFinishedSessionEndsAt ~= nil and raceContext.LastFinishedSessionEndsAt == currentJoinEndsAt)

		if inRace then
			if raceContext.AutoComplete and not raceContext.Busy then
				runRaceAuto()
			end
		else
			if inCooldown or alreadyJoinedCurrentSession then
				local rem = math.max(0, math.ceil((raceContext.PostRaceCooldown or 0) - now))
				if rem > 0 then
					raceContext.Status = string.format("Race Finished - Resting (%ds)...", rem)
				else
					raceContext.Status = "Race Finished - Waiting for next event cycle"
				end
			elseif portalOpen then
				local joinEnds = currentJoinEndsAt or 0
				local diff = math.max(0, math.floor(joinEnds - workspace:GetServerTimeNow()))
				raceContext.Status = string.format("Portal Open! Closes in %dm %02ds", diff // 60, diff % 60)

				if (raceContext.AutoJoin or raceContext.AutoComplete) and not (state.Steal and (state.Steal.Active or state.Steal.Carrying)) then
					local portal = getPortalModel()
					local hitbox = findPortalHitbox(portal)
					local root = state.Root()
					if hitbox and root and (hitbox.Position - root.Position).Magnitude <= 25 then
						pauseShieldForPortalEntry()
					elseif not raceContext.Busy then
						releaseRaceShieldPause()
					end
				end

				if raceContext.AutoJoin and now - raceContext.LastJoinAttemptAt > 6 and not raceContext.Busy then
					raceContext.LastJoinAttemptAt = now
					task.spawn(joinRacePortal)
				end
			else
				if not raceContext.Busy then
					releaseRaceShieldPause()
				end
				local scheduleUtil = getScheduleUtil()
				if scheduleUtil and type(scheduleUtil.NextOpening) == "function" then
					local nextOpen = scheduleUtil.NextOpening(workspace:GetServerTimeNow())
					local diff = math.max(0, math.floor(nextOpen - workspace:GetServerTimeNow()))
					raceContext.Status = string.format("Portal Closed - Next race in %dm %02ds", diff // 60, diff % 60)
				else
					raceContext.Status = "Portal Closed (Waiting for next race)"
				end
			end
		end

		if raceStatusRow and type(raceStatusRow.Set) == "function" then
			pcall(raceStatusRow.Set, raceStatusRow, raceContext.Status)
		end

		if raceContext.AutoClaim and now - raceContext.LastClaimAt > 20 then
			raceContext.LastClaimAt = now
			task.spawn(claimAllMilestones)
		end

		if now - raceContext.LastBuyAt > 15 then
			raceContext.LastBuyAt = now
			if raceContext.AutoBuyNitro and raceContext.Trophies >= 475 then
				task.spawn(function()
					local ok, res = buyShopItem("MutationToken")
					if ok then
						state.Notify("Race Rally", "Successfully purchased Nitro Mutation Token!")
					end
				end)
			elseif raceContext.AutoBuyChoice == "2x Cash Booster (200)" and raceContext.Trophies >= 200 then
				task.spawn(function() buyShopItem("CashBooster") end)
			elseif raceContext.AutoBuyChoice == "1.25x Speed Boost (250)" and raceContext.Trophies >= 250 then
				task.spawn(function() buyShopItem("SpeedBoost") end)
			end
		end

		return true
	end)

	registerCleanup(function()
		raceContext.RacingGeneration = raceContext.RacingGeneration + 1
		if type(activeDriverCleanup) == "function" then
			pcall(activeDriverCleanup)
			activeDriverCleanup = nil
		end
		pcall(state.ReleaseMovement, "race")
	end)
end

do
	local starContext = {
		AutoCatch = false,
		CatchGlideSpeed = 250,
		AutoFeed = false,
		TargetPetUid = nil,
		TargetPetName = "None",
		Status = "Checking Day/Night cycle...",
		StarsOwned = 0,
		Busy = false,
		ActiveStar = nil,
		CatchGeneration = 0,
		LastStateCheckAt = 0,
		LastFeedAttemptAt = 0,
	}

	local function getRemotes()
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		if shared and shared:FindFirstChild("Remotes") then
			local ok, res = pcall(require, shared.Remotes)
			if ok and type(res) == "table" then return res end
		end
		return nil
	end

	local function getSaveModule()
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		if shared and shared:FindFirstChild("Save") then
			local ok, res = pcall(require, shared.Save)
			if ok and type(res) == "table" then return res end
		end
		return modules and modules.Save
	end

	local function getPlayerProfile()
		local saveMod = getSaveModule()
		if saveMod and type(saveMod.Peek) == "function" then
			local ok, data = pcall(saveMod.Peek)
			if ok and type(data) == "table" then
				return data
			end
		end
		return nil
	end

	local function getStarTools()
		local stars = {}
		local char = localPlayer.Character
		if char then
			for _, item in ipairs(char:GetChildren()) do
				if item:IsA("Tool") and (item:GetAttribute("ItemType") == "MountStar" or item.Name == "MountStar") then
					table.insert(stars, item)
				end
			end
		end
		local bp = localPlayer:FindFirstChildOfClass("Backpack")
		if bp then
			for _, item in ipairs(bp:GetChildren()) do
				if item:IsA("Tool") and (item:GetAttribute("ItemType") == "MountStar" or item.Name == "MountStar") then
					table.insert(stars, item)
				end
			end
		end
		return stars
	end

	local function findStarTool()
		local stars = getStarTools()
		return stars[1]
	end

	local function getLiveStarPosition()
		local folder = workspace:FindFirstChild("ShootingStarClient")
		if folder then
			local buddy = folder:FindFirstChild("Buddy")
			if buddy and buddy:IsA("Model") then
				local root = buddy:FindFirstChild("Root") or buddy.PrimaryPart or buddy:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					return root.Position
				end
				local pivot = buddy:GetPivot()
				return pivot.Position
			end
			local meteor = folder:FindFirstChild("Meteor")
			if meteor and meteor:IsA("Model") then
				local pivot = meteor:GetPivot()
				return pivot.Position
			end
			for _, child in ipairs(folder:GetChildren()) do
				if child:IsA("Model") then
					return child:GetPivot().Position
				elseif child:IsA("BasePart") then
					return child.Position
				end
			end
		end
		if starContext.ActiveStar then
			local landing = starContext.ActiveStar.Landing
			if type(landing) == "table" and typeof(landing.Position) == "Vector3" then
				return landing.Position
			end
		end
		return nil
	end

	local function hasWorkspaceStar()
		local folder = workspace:FindFirstChild("ShootingStarClient")
		if not folder then return false end
		for _, child in ipairs(folder:GetChildren()) do
			if child.Name == "Buddy" or child.Name == "Meteor" or child.Name == "FallingStar" or child:FindFirstChild("CatchPrompt") then
				return true
			end
		end
		return false
	end

	local function formatCycleTimer(sec)
		sec = math.max(0, math.floor(sec or 0))
		local m = math.floor(sec / 60)
		local s = sec % 60
		return string.format("%02d:%02d", m, s)
	end

	local runCatchStar

	local function feedStarToPet(petUid)
		if not petUid or petUid == "" then
			return false, "No pet selected"
		end
		local starTool = findStarTool()
		if not starTool then
			return false, "No Shooting Star in inventory"
		end
		local char = localPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then
			return false, "Character humanoid not found"
		end

		if starTool.Parent ~= char then
			pcall(function() hum:EquipTool(starTool) end)
			task.wait(0.3)
		end

		local remotes = getRemotes()
		if not remotes or not remotes.ShootingStar or not remotes.ShootingStar.AskFeed then
			return false, "Remote not available"
		end

		local ok, res, extra = pcall(function()
			return remotes.ShootingStar.AskFeed:InvokeServer(petUid)
		end)

		if ok and res == true then
			return true, "Success"
		end
		return false, tostring(extra or res or "Failed to feed star")
	end

	runCatchStar = function()
		if starContext.Busy then return end
		if not starContext.ActiveStar and not hasWorkspaceStar() then return end
		starContext.Busy = true
		starContext.CatchGeneration = starContext.CatchGeneration + 1
		local gen = starContext.CatchGeneration

		task.spawn(function()
			local claimed = state.ClaimMovement("star")
			if not claimed then
				starContext.Busy = false
				return
			end

			pcall(function()
				if not starContext.ActiveStar then
					local remotes = getRemotes()
					if remotes and remotes.ShootingStar and remotes.ShootingStar.AskState then
						local ok, stateData = pcall(function()
							return remotes.ShootingStar.AskState:InvokeServer()
						end)
						if ok and type(stateData) == "table" and stateData.Id then
							starContext.ActiveStar = stateData
						end
					end
				end

				local payload = starContext.ActiveStar
				if not payload or not payload.Id then
					return
				end
				local starId = payload.Id

				local home = type(state.StealHome) == "function" and state.StealHome() or nil
				local root = state.Root()
				if not root then return end

				if home and type(state.InsideBase) == "function" and state.InsideBase() then
					local target = home + Vector3.new(0, 3, 0)
					local travelSpeed = starContext.CatchGlideSpeed or 250
					local startClock = os.clock()
					local arrivedHome = false

					while os.clock() - startClock < 15 do
						if gen ~= starContext.CatchGeneration or not starContext.AutoCatch or not starContext.ActiveStar then
							break
						end
						root = state.Root()
						if not root then break end
						local delta = target - root.Position
						if delta.Magnitude <= 4 then
							arrivedHome = true
							break
						else
							starContext.Status = "Exiting base via safe zone..."
							local step = math.min(travelSpeed * RunService.Heartbeat:Wait(), delta.Magnitude)
							pcall(function()
								local rotation = root.CFrame.Rotation
								root.CFrame = CFrame.new(root.Position + delta.Unit * step) * rotation
								root.AssemblyLinearVelocity = Vector3.zero
							end)
						end
					end

					if not arrivedHome then return end

					local waitElapsed = 0
					while waitElapsed < 0.35 do
						root = state.Root()
						if root then
							pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
						end
						waitElapsed = waitElapsed + RunService.Heartbeat:Wait()
					end
				end

				local travelSpeed = starContext.CatchGlideSpeed or 250
				local glideTimeout = os.clock() + 60
				local arrivedAtStar = false

				while os.clock() < glideTimeout do
					if gen ~= starContext.CatchGeneration or not starContext.AutoCatch or not starContext.ActiveStar then
						break
					end
					root = state.Root()
					if not root then break end

					local targetPos = getLiveStarPosition()
					if not targetPos then
						task.wait(0.2)
						continue
					end

					local delta = targetPos - root.Position
					local dist = delta.Magnitude

					if dist <= 14 then
						arrivedAtStar = true
						break
					end

					starContext.Status = string.format("Gliding to Shooting Star, %d studs...", math.floor(dist + 0.5))
					local step = math.min(travelSpeed * RunService.Heartbeat:Wait(), dist)
					local dir = dist > 0.001 and delta.Unit or Vector3.new(0, 0, 1)

					pcall(function()
						local lookPos = root.Position + Vector3.new(dir.X, 0, dir.Z)
						root.CFrame = CFrame.lookAt(root.Position + dir * step, lookPos)
						root.AssemblyLinearVelocity = dir * travelSpeed
					end)
				end

				if not arrivedAtStar then return end

				root = state.Root()
				if root then
					pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
				end

				local remotes = getRemotes()
				if not remotes or not remotes.ShootingStar then return end

				starContext.Status = "Holding star to catch..."
				pcall(function()
					remotes.ShootingStar.Hold:FireServer(starId, true)
				end)

				local holdDuration = (payload.HoldSeconds or 1.6) + 0.2
				local holdStart = os.clock()

				while os.clock() - holdStart < holdDuration do
					if gen ~= starContext.CatchGeneration or not starContext.AutoCatch then
						pcall(function() remotes.ShootingStar.Hold:FireServer(starId, false) end)
						return
					end
					root = state.Root()
					local livePos = getLiveStarPosition()
					if root and livePos then
						local d = livePos - root.Position
						if d.Magnitude > 10 then
							pcall(function()
								root.CFrame = CFrame.lookAt(livePos, livePos + Vector3.new(0, 0, 1))
								root.AssemblyLinearVelocity = Vector3.zero
							end)
						end
					end
					task.wait(0.08)
				end

				starContext.Status = "Catching star..."
				pcall(function()
					remotes.ShootingStar.Catch:FireServer(starId)
				end)

				task.wait(0.8)
				starContext.Status = "Successfully caught Shooting Star!"
				state.Notify("Shooting Star", "Successfully caught Shooting Star!")
				starContext.ActiveStar = nil

				if starContext.AutoFeed and starContext.TargetPetUid then
					task.wait(1)
					local feedOk, feedMsg = feedStarToPet(starContext.TargetPetUid)
					if feedOk then
						state.Notify("Shooting Star", string.format("Successfully converted %s into a Mount!", starContext.TargetPetName))
					end
				end
			end)

			state.ReleaseMovement("star")
			starContext.Busy = false
		end)
	end

	local petUidMap = {}
	local function getUnmountedPetOptions()
		local profile = getPlayerProfile()
		local inv = profile and profile.Inventory
		local options = { "None" }
		petUidMap = { ["None"] = nil }

		if type(inv) == "table" then
			local directory = modules.Assets and modules.Assets.Directory or {}
			for uid, item in pairs(inv) do
				if type(item) == "table" and item.Rideable ~= true and item.InFuse ~= true then
					local cat = tostring(item.Category or "Pet")
					local assetEntry = directory[cat]
					local dispName = assetEntry and assetEntry.DisplayName or cat
					local label = string.format("%s (%.1f)%s - %s", dispName, tonumber(item.Scale) or 1, item.Mutation and (" [" .. tostring(item.Mutation) .. "]") or "", string.sub(tostring(uid), 1, 6))
					table.insert(options, label)
					petUidMap[label] = uid
				end
			end
		end

		return options
	end

	local starStatusRow = shootingStarSection:CreateText({
		Name = "Star Status",
		Text = "Checking Day/Night cycle...",
	})

	local starsOwnedRow = shootingStarSection:CreateText({
		Name = "Stars Owned",
		Text = "0 Shooting Star(s) Owned",
	})

	starContext.AutoCatchHandle = shootingStarSection:CreateToggle({
		Name = "Auto Catch Shooting Star",
		Note = "Automatically glide to falling Shooting Stars at night and catch them",
		Default = false,
		Callback = function(val)
			starContext.AutoCatch = val == true
			if val == true and (starContext.ActiveStar or hasWorkspaceStar()) and not starContext.Busy then
				task.spawn(runCatchStar)
			end
			taskScheduler.Wake()
		end,
	})

	shootingStarSection:CreateSlider({
		Name = "Catch Glide Speed",
		Note = "Gliding speed toward the falling Shooting Star location",
		Min = 100,
		Max = 500,
		Default = 250,
		Increment = 25,
		Unit = "studs/s",
		SubOf = starContext.AutoCatchHandle,
		Callback = function(val)
			starContext.CatchGlideSpeed = math.clamp(tonumber(val) or 250, 100, 500)
		end,
	})

	shootingStarSection:CreateButton({
		Name = "Catch Active Star Now",
		ButtonText = "Catch",
		ConfirmText = "Gliding...",
		Callback = function()
			if starContext.ActiveStar or hasWorkspaceStar() then
				task.spawn(runCatchStar)
			else
				state.Notify("Shooting Star", "No active Shooting Star on map right now!")
			end
		end,
	})

	local petOptions = getUnmountedPetOptions()
	local petDropdown = shootingStarSection:CreateDropdown({
		Name = "Select Pet to Convert",
		Note = "Select a pet to permanently convert into a rideable Mount",
		Options = #petOptions > 0 and petOptions or { "None" },
		Default = "None",
		Callback = function(val)
			local chosen = tostring(val or "None")
			starContext.TargetPetUid = petUidMap[chosen]
			starContext.TargetPetName = chosen
		end,
	})

	shootingStarSection:CreateButton({
		Name = "Refresh Pet List",
		ButtonText = "Refresh",
		ConfirmText = "Updated!",
		Callback = function()
			local newOptions = getUnmountedPetOptions()
			if petDropdown and type(petDropdown.SetOptions) == "function" then
				pcall(petDropdown.SetOptions, petDropdown, newOptions)
			end
			state.Notify("Shooting Star", string.format("Found %d unmounted pet(s) in inventory!", math.max(0, #newOptions - 1)))
		end,
	})

	starContext.AutoFeedHandle = shootingStarSection:CreateToggle({
		Name = "Auto Feed Star to Pet",
		Note = "Automatically feed 1 Shooting Star to convert the selected pet into a Mount",
		Default = false,
		Callback = function(val)
			starContext.AutoFeed = val == true
			taskScheduler.Wake()
		end,
	})

	shootingStarSection:CreateButton({
		Name = "Feed Star to Pet Now",
		ButtonText = "Feed Star",
		ConfirmText = "Done!",
		Callback = function()
			if not starContext.TargetPetUid then
				state.Notify("Shooting Star", "Please select a pet from the dropdown first!")
				return
			end
			task.spawn(function()
				local ok, msg = feedStarToPet(starContext.TargetPetUid)
				if ok then
					state.Notify("Shooting Star", string.format("Successfully converted %s into a Mount!", starContext.TargetPetName))
					local newOptions = getUnmountedPetOptions()
					if petDropdown and type(petDropdown.SetOptions) == "function" then
						pcall(petDropdown.SetOptions, petDropdown, newOptions)
					end
				else
					state.Notify("Shooting Star", "Failed to feed star: " .. tostring(msg))
				end
			end)
		end,
	})

	shootingStarSection:CreateButton({
		Name = "Ride / Dismount Mount",
		ButtonText = "Toggle Ride",
		ConfirmText = "Done!",
		Callback = function()
			task.spawn(function()
				local remotes = getRemotes()
				if not remotes or not remotes.PetMount or not remotes.PetMount.Request then
					state.Notify("Shooting Star", "PetMount remote not available!")
					return
				end
				local char = localPlayer.Character
				local isMounted = char and char:FindFirstChild("PetMountSession") ~= nil
				if isMounted then
					pcall(function() remotes.PetMount.Request:InvokeServer("dismount") end)
					state.Notify("Shooting Star", "Dismounted from pet!")
				else
					local petToMount = starContext.TargetPetUid
					if not petToMount then
						local profile = getPlayerProfile()
						local inv = profile and profile.Inventory
						if type(inv) == "table" then
							for uid, p in pairs(inv) do
								if type(p) == "table" and p.Rideable == true then
									petToMount = uid
									break
								end
							end
						end
					end
					if petToMount then
						pcall(function() remotes.PetMount.Request:InvokeServer("mount", petToMount) end)
						state.Notify("Shooting Star", "Mounted onto pet!")
					else
						state.Notify("Shooting Star", "No rideable pet found in inventory! Convert one first.")
					end
				end
			end)
		end,
	})

	task.spawn(function()
		local remotes = getRemotes()
		if not remotes or not remotes.ShootingStar then return end

		pcall(function()
			if remotes.ShootingStar.Fall then
				remotes.ShootingStar.Fall.OnClientEvent:Connect(function(payload)
					if type(payload) == "table" and payload.Id then
						starContext.ActiveStar = payload
						starContext.Status = "Shooting Star falling from sky!"
						if starContext.AutoCatch and not starContext.Busy then
							task.spawn(runCatchStar)
						end
					end
				end)
			end
			if remotes.ShootingStar.Claimed then
				remotes.ShootingStar.Claimed.OnClientEvent:Connect(function(starId)
					if starContext.ActiveStar and starContext.ActiveStar.Id == starId then
						starContext.ActiveStar = nil
					end
				end)
			end
			if remotes.ShootingStar.Expired then
				remotes.ShootingStar.Expired.OnClientEvent:Connect(function(starId)
					if starContext.ActiveStar and starContext.ActiveStar.Id == starId then
						starContext.ActiveStar = nil
						starContext.Status = "Star expired (returned to sky)"
					end
				end)
			end
		end)
	end)

	taskScheduler.Add(function()
		local now = os.clock()

		local currentStars = #getStarTools()
		starContext.StarsOwned = currentStars
		if starsOwnedRow and type(starsOwnedRow.Set) == "function" then
			pcall(starsOwnedRow.Set, starsOwnedRow, string.format("%d Shooting Star(s) Owned", currentStars))
		end

		local remotes = getRemotes()
		local hasWsStar = hasWorkspaceStar()
		local isNightNow = type(state.IsNight) == "function" and state.IsNight() or false
		local pollInterval = hasWsStar and 2 or (isNightNow and 5 or 15)

		if remotes and remotes.ShootingStar and remotes.ShootingStar.AskState then
			if starContext.ActiveStar == nil and now - starContext.LastStateCheckAt > pollInterval and not starContext.Busy then
				starContext.LastStateCheckAt = now
				task.spawn(function()
					local ok, stateData = pcall(function()
						return remotes.ShootingStar.AskState:InvokeServer()
					end)
					if ok and type(stateData) == "table" and stateData.Id then
						local exp = tonumber(stateData.ExpiresAt) or 0
						if exp > workspace:GetServerTimeNow() then
							starContext.ActiveStar = stateData
							if starContext.AutoCatch and not starContext.Busy then
								runCatchStar()
							end
						end
					end
				end)
			end
		end

		if starContext.ActiveStar then
			local exp = tonumber(starContext.ActiveStar.ExpiresAt) or 0
			if exp > 0 and workspace:GetServerTimeNow() >= exp then
				starContext.ActiveStar = nil
			end
		end

		if starContext.ActiveStar or hasWsStar then
			if not starContext.Busy and starContext.AutoCatch then
				runCatchStar()
			elseif not starContext.Busy then
				starContext.Status = "Active Shooting Star on map!"
			end
		else
			if not starContext.Busy then
				local areaCycle = modules.AreaEggCycle
				local sNow = workspace:GetServerTimeNow()
				if isNightNow then
					local resetTime = areaCycle and type(areaCycle.NextResetTime) == "function" and areaCycle.NextResetTime(sNow)
					local remaining = (type(resetTime) == "number" and resetTime > sNow) and (resetTime - sNow) or 0
					starContext.Status = string.format("Night active (%s left) - Waiting for star fall (Rare)...", formatCycleTimer(remaining))
				else
					local nextNight = areaCycle and type(areaCycle.NextNightTime) == "function" and areaCycle.NextNightTime(sNow)
					local remaining = (type(nextNight) == "number" and nextNight > sNow) and (nextNight - sNow) or 0
					starContext.Status = string.format("Daytime (Night in %s) - Waiting for night cycle...", formatCycleTimer(remaining))
				end
			end
		end

		if starStatusRow and type(starStatusRow.Set) == "function" then
			pcall(starStatusRow.Set, starStatusRow, starContext.Status)
		end

		if starContext.AutoFeed and starContext.TargetPetUid and currentStars > 0 and not starContext.Busy then
			if now - starContext.LastFeedAttemptAt > 15 then
				starContext.LastFeedAttemptAt = now
				task.spawn(function()
					local ok, msg = feedStarToPet(starContext.TargetPetUid)
					if ok then
						state.Notify("Shooting Star", string.format("Successfully converted %s into a Mount!", starContext.TargetPetName))
					end
				end)
			end
		end

		return true
	end)

	registerCleanup(function()
		starContext.CatchGeneration = starContext.CatchGeneration + 1
		pcall(state.ReleaseMovement, "star")
	end)
end

do
	local favoriteCooldownSeconds = 2
	local favoriteBatchSize = 25
	local favoriteItemCooldown = 4
	local favoriteRules = { "Match Any", "Match All" }
	local defaultMutationList = { "Golden", "Silver", "Rainbow", "Boss", "Monstrous", "Sakura", "GreatBloom" }
	local anyMutationLabel = "Any Mutation"
	local favoriteRarityOptions = { "Off" }
	local favoriteRarityNumberMap = {}
	local favoriteSpeciesOptions = {}
	local favoriteSpeciesCategoryMap = {}
	local favoriteMutationOptions = { "Any Mutation" }
	local favoriteMutationIdMap = {}
	local assetDirectory = modules.Assets and modules.Assets.Directory
	local rarityNamesByNumber = {}
	local eggList = {}

	if type(assetDirectory) == "table" then
		for category, entry in pairs(assetDirectory) do
			local rarity = type(entry) == "table" and entry.Rarity or nil
			local rarityNumber = type(rarity) == "table" and tonumber(rarity.RarityNumber or rarity.Rank) or nil

			if rarityNumber then
				local rarityName = tostring(rarity.DisplayName or rarity._id or rarityNumber)
				rarityNamesByNumber[rarityNumber] = rarityNamesByNumber[rarityNumber] or rarityName

				table.insert(eggList, {
					Category = tostring(category),
					Name = tostring(entry.DisplayName or category),
					Rarity = rarityNumber,
					RarityName = rarityName,
				})
			end
		end
	end

	do
		local sortedRarityNumbers = {}

		for rarityNumber in pairs(rarityNamesByNumber) do
			table.insert(sortedRarityNumbers, rarityNumber)
		end

		table.sort(sortedRarityNumbers)

		for _, rarityNumber in ipairs(sortedRarityNumbers) do
			local label = string.format("%d - %s", rarityNumber, rarityNamesByNumber[rarityNumber])
			table.insert(favoriteRarityOptions, label)
			favoriteRarityNumberMap[label] = rarityNumber
		end

		table.sort(eggList, function(a, b)
			if a.Rarity ~= b.Rarity then
				return a.Rarity < b.Rarity
			end
			return a.Name < b.Name
		end)

		for _, item in ipairs(eggList) do
			local label = string.format("%s [%s]", item.Name, item.RarityName)

			if favoriteSpeciesCategoryMap[label] then
				label = string.format("%s [%s] (%s)", item.Name, item.RarityName, item.Category)
			end

			table.insert(favoriteSpeciesOptions, label)
			favoriteSpeciesCategoryMap[label] = item.Category
		end
	end

	do
		local mutationIds = {}
		local mutationsModule = modules.Mutations

		if type(mutationsModule) == "table" and type(mutationsModule.IdSet) == "table" then
			for id in pairs(mutationsModule.IdSet) do
				table.insert(mutationIds, tostring(id))
			end
		end

		if #mutationIds == 0 then
			mutationIds = table.clone(defaultMutationList)
		end

		table.sort(mutationIds, function(a, b)
			return mutationLabel(a) < mutationLabel(b)
		end)

		for _, id in ipairs(mutationIds) do
			local label = mutationLabel(id)
			table.insert(favoriteMutationOptions, label)
			favoriteMutationIdMap[label] = id
		end
	end

	local autoFavoriteToggle = nil
	local autoFavoriteEquippedToggle = nil
	local autoUnfavoriteEquippedToggle = nil
	local favoritePreviewRow = nil
	local favoriteRule = favoriteRules[2]
	local favoriteMinRarity = nil
	local favoriteAnyMutation = false
	local favoriteMutationSet = {}
	local favoriteMinValue = 0
	local favoriteAlwaysSpecies = {}
	local favoriteBusy = false
	local favoriteCooldownUntil = 0
	local favoriteWriteCooldowns = {}

	local function getFavoriteSaveData()
		local saveModule = modules.Save
		if type(saveModule) ~= "table" or type(saveModule.Get) ~= "function" then
			return nil
		end
		local ok, result = pcall(saveModule.Get)
		return ok and type(result) == "table" and result or nil
	end

	local function getAssetEntry(category)
		local directory = modules.Assets and modules.Assets.Directory
		return type(directory) == "table" and directory[tostring(category)] or nil
	end

	local function getRarityNumber(category)
		local assetEntry = getAssetEntry(category)
		local rarity = type(assetEntry) == "table" and assetEntry.Rarity or nil
		local rarityNumber = type(rarity) == "table" and tonumber(rarity.RarityNumber or rarity.Rank) or nil
		return rarityNumber or 0
	end

	local function computeIncome(item)
		local assetEntry = getAssetEntry(item.Category)
		local earningRate = type(assetEntry) == "table" and tonumber(assetEntry.EarningRate) or 0
		local scale = tonumber(item.Scale) or 0
		if earningRate <= 0 or scale <= 0 then
			return 0
		end
		local scaleFactor = scale > 5 and (scale / 5) ^ 1.2 * 19.637875755794113 or scale ^ 1.85
		local mutationsModule = modules.Mutations
		local hasEarningsFor = type(mutationsModule) == "table" and type(mutationsModule.EarningsFor) == "function"
		local mutationMultiplier = 1

		if hasEarningsFor then
			local ok, result = pcall(mutationsModule.EarningsFor, type(item.Mutations) == "table" and item.Mutations or {})
			mutationMultiplier = ok and type(result) == "number" and result or 1
		end

		return earningRate * scaleFactor * mutationMultiplier
	end

	local function collectMutations(item)
		local mutations = {}

		if type(item.Mutations) == "table" then
			for key, mutation in pairs(item.Mutations) do
				if type(mutation) == "string" then
					mutations[mutation] = true
				elseif mutation == true and type(key) == "string" then
					mutations[key] = true
				end
			end
		end

		if type(item.BaseMutation) == "string" and item.BaseMutation ~= "" then
			mutations[item.BaseMutation] = true
		end

		return mutations
	end

	local function matchesFavoriteFilter(item)
		if favoriteAlwaysSpecies[tostring(item.Category)] then
			return true
		end
		local matches = 0
		local checks = 0

		if favoriteMinRarity then
			checks = 1

			if getRarityNumber(item.Category) >= favoriteMinRarity then
				matches = 1
			end
		end

		if favoriteAnyMutation or next(favoriteMutationSet) ~= nil then
			checks = checks + 1
			local itemMutations = collectMutations(item)

			if favoriteAnyMutation and next(itemMutations) ~= nil then
				matches = matches + 1
			else
				local hasMatch = false

				for mutation in pairs(itemMutations) do
					if favoriteMutationSet[mutation] then
						hasMatch = true
						break
					end
				end

				if hasMatch then
					matches = matches + 1
				end
			end
		end

		if favoriteMinValue > 0 then
			checks = checks + 1

			if favoriteMinValue <= computeIncome(item) then
				matches = matches + 1
			end
		end

		if checks == 0 then
			return false
		end

		if favoriteRule == favoriteRules[2] then
			return matches == checks
		end

		return matches > 0
	end

	local function isWriteCooling(uid)
		return (favoriteWriteCooldowns[uid] or 0) > os.clock()
	end

	local function collectFavoritesToMark(saveData)
		local toMark = {}
		local matchedCount = 0

		for uid, item in pairs(saveData.Inventory or {}) do
			if type(item) == "table" and matchesFavoriteFilter(item) then
				matchedCount = matchedCount + 1

				if item.IsFavorite ~= true and not isWriteCooling(uid) then
					table.insert(toMark, uid)
				end
			end
		end

		return toMark, matchedCount
	end

	local function collectEquippedToToggle(saveData, markFavorite, checkRules)
		local toggles = {}
		local inventory = saveData.Inventory or {}

		for _, equippedUid in pairs(saveData.EquippedAssets or {}) do
			local item = inventory[equippedUid]

			if type(item) == "table" and not isWriteCooling(equippedUid) then
				if markFavorite then
					if item.IsFavorite ~= true then
						table.insert(toggles, equippedUid)
					end
				else
					local shouldUnfavorite = item.IsFavorite == true

					if shouldUnfavorite then
						shouldUnfavorite = not (checkRules and matchesFavoriteFilter(item))
					end

					if shouldUnfavorite then
						table.insert(toggles, equippedUid)
					end
				end
			end
		end

		return toggles
	end

	local function fireFavoriteWrite(uids, markFavorite)
		local remote = networking:FindFirstChild("RE/PetSatchel/WriteFavourite")
		if not remote or not remote:IsA("RemoteEvent") then
			return
		end

		for index, uid in ipairs(uids) do
			if not (favoriteBatchSize < index) then
				favoriteWriteCooldowns[uid] = os.clock() + favoriteItemCooldown
				pcall(remote.FireServer, remote, uid, markFavorite)
				task.wait(0.12)
				continue
			end

			break
		end
	end

	local function runFavoriteWrite(uids, markFavorite)
		if favoriteBusy or #uids == 0 then
			return false
		end
		favoriteBusy = true
		favoriteCooldownUntil = os.clock() + favoriteCooldownSeconds

		task.spawn(function()
			pcall(fireFavoriteWrite, uids, markFavorite)
			favoriteBusy = false
			taskScheduler.Wake()
		end)

		return true
	end

	taskScheduler.Add(function()
		local saveData = getFavoriteSaveData()
		if not saveData then
			return false
		end
		local autoOn = state.Toggle(autoFavoriteToggle, false)
		local toMark, matchedCount = collectFavoritesToMark(saveData)

		if favoritePreviewRow and type(favoritePreviewRow.Set) == "function" then
			local favoritedCount = 0

			for _, item in pairs(saveData.Inventory or {}) do
				if type(item) == "table" and item.IsFavorite == true then
					favoritedCount = favoritedCount + 1
				end
			end

			pcall(favoritePreviewRow.Set, favoritePreviewRow, string.format("Favorite matches  -  %d pets, %d to mark  |  %d favorited", matchedCount, #toMark, favoritedCount))
		end

		local isBusy = favoriteBusy
		local isCooling

		if favoriteBusy then
			isCooling = isBusy
		else
			isCooling = os.clock() < favoriteCooldownUntil
		end

		if isCooling then
			return false
		end

		if autoOn and runFavoriteWrite(toMark, true) then
			return false
		end

		if state.Toggle(autoFavoriteEquippedToggle, false) then
			if runFavoriteWrite(collectEquippedToToggle(saveData, true, false), true) then
				return false
			end
		elseif state.Toggle(autoUnfavoriteEquippedToggle, false) then
			runFavoriteWrite(collectEquippedToToggle(saveData, false, autoOn), false)
		end

		return false
	end)

	favoritePreviewRow = autoFavoriteSection:CreateText({ Name = "Favorite Preview", Text = "Favorite matches  -  0 pets" })

	autoFavoriteToggle = autoFavoriteSection:CreateToggle({
		Name = "Auto Favorite Pet",
		Note = "Favorite pets matching the rules below",
		Default = false,
		Callback = function()
			table.clear(favoriteWriteCooldowns)
			taskScheduler.Wake()
		end,
	})

	autoFavoriteSection:CreateButton({
		Name = "Favorite Pets Now",
		Note = "Favorite matching pets once",
		ButtonText = "Favorite",
		ConfirmText = "Done!",
		SubOf = autoFavoriteToggle,
		Callback = function()
			local saveData = getFavoriteSaveData()

			if saveData then
				runFavoriteWrite(collectFavoritesToMark(saveData), true)
			end
		end,
	})

	autoFavoriteSection:CreateDropdown({
		Name = "Favorite Rule",
		Note = "Pass any check or all checks",
		Options = favoriteRules,
		Default = favoriteRules[2],
		SubOf = autoFavoriteToggle,
		Callback = function(selected)
			if table.find(favoriteRules, selected) then
				favoriteRule = selected
				taskScheduler.Wake()
			end
		end,
	})

	autoFavoriteSection:CreateDropdown({
		Name = "Favorite Min Rarity",
		Note = "Favorite pets of the chosen rarity and every rarity above it (Off = skip)",
		Options = favoriteRarityOptions,
		Default = "Off",
		SubOf = autoFavoriteToggle,
		Callback = function(selected)
			favoriteMinRarity = favoriteRarityNumberMap[selected]
			taskScheduler.Wake()
		end,
	})

	fixDropdownAll(autoFavoriteSection:CreateMultiDropdown({
		Name = "Favorite Mutations",
		Note = "Mutation check (empty = skip)",
		Options = favoriteMutationOptions,
		Default = {},
		SubOf = autoFavoriteToggle,
		Callback = function(selection)
			local mutationSet = {}
			local anyMutation = false

			if type(selection) == "table" then
				for key, value in pairs(selection) do
					local label

					if value == true and type(key) == "string" then
						label = key
					elseif type(value) == "string" then
						label = value
					end

					if label == anyMutationLabel then
						anyMutation = true
					elseif label then
						mutationSet[favoriteMutationIdMap[label] or label] = true
					end
				end
			end

			favoriteAnyMutation = anyMutation
			favoriteMutationSet = mutationSet
			taskScheduler.Wake()
		end,
	}))

	do
		local valueUnits = {
			["K/s"] = { Min = 0, Max = 1000, Mult = 1000 },
			["M/s"] = { Min = 0, Max = 1000, Mult = 1000000 },
			["B/s"] = { Min = 0, Max = 100, Mult = 1e9 },
		}

		local valueInput = 0
		local valueUnit = "M/s"

		local function applyFavoriteMinValue(value, unit)
			if value ~= nil then
				valueInput = math.max(0, math.floor(tonumber(value) or valueInput))
			end

			if unit ~= nil then
				valueUnit = tostring(unit)
			end

			favoriteMinValue = valueInput * (valueUnits[valueUnit] or valueUnits["M/s"]).Mult
			taskScheduler.Wake()
		end

		createValueSlider(autoFavoriteSection, {
			Name = "Min Favorite Value",
			Note = "Value check (0 = skip)",
			SubOf = autoFavoriteToggle,
			Legacy = "Favorite Min Value",
			SectionName = "Auto Favorite",
			OnRaw = function(value)
				applyFavoriteMinValue(math.floor(value / 1000), "K/s")
			end,
		})
	end

	fixDropdownAll(autoFavoriteSection:CreateMultiDropdown({
		Name = "Always Favorite Species",
		Note = "Always favorite these species",
		Options = favoriteSpeciesOptions,
		Default = {},
		SubOf = autoFavoriteToggle,
		Callback = function(selection)
			local speciesSet = {}

			if type(selection) == "table" then
				for key, value in pairs(selection) do
					local label

					if value == true and type(key) == "string" then
						label = key
					elseif type(value) == "string" then
						label = value
					end

					if label and favoriteSpeciesCategoryMap[label] then
						speciesSet[favoriteSpeciesCategoryMap[label]] = true
					end
				end
			end

			favoriteAlwaysSpecies = speciesSet
			taskScheduler.Wake()
		end,
	}))

	autoFavoriteEquippedToggle = autoFavoriteSection:CreateToggle({
		Name = "Auto Favorite Equipped",
		Note = "Keep equipped pets favorited",
		Default = false,
		Callback = function()
			taskScheduler.Wake()
		end,
	})

	autoUnfavoriteEquippedToggle = autoFavoriteSection:CreateToggle({
		Name = "Auto Unfavorite Equipped",
		Note = "Unfavorite equipped pets not in the rules",
		Default = false,
		Callback = function()
			taskScheduler.Wake()
		end,
	})

	autoFavoriteSection:CreateButton({
		Name = "Favorite Equipped Now",
		Note = "Favorite all equipped pets once",
		ButtonText = "Favorite",
		ConfirmText = "Done!",
		Callback = function()
			local saveData = getFavoriteSaveData()

			if saveData then
				runFavoriteWrite(collectEquippedToToggle(saveData, true, false), true)
			end
		end,
	})

	autoFavoriteSection:CreateButton({
		Name = "Unfavorite Equipped Now",
		Note = "Unfavorite all equipped pets once",
		ButtonText = "Unfavorite",
		ConfirmText = "Done!",
		Callback = function()
			local saveData = getFavoriteSaveData()

			if saveData then
				runFavoriteWrite(collectEquippedToToggle(saveData, false, false), false)
			end
		end,
	})
end

do
	local saveModule = modules.Save

	if type(saveModule) == "table" and type(saveModule.FieldSignal) == "function" then
		for _, fieldName in ipairs({ "Inventory", "EquippedAssets" }) do
			local ok, signal = pcall(saveModule.FieldSignal, fieldName)

			if ok and type(signal) == "table" and type(signal.Connect) == "function" then
				local ok2, connection = pcall(signal.Connect, signal, function()
					taskScheduler.Wake()
				end)

				if ok2 and connection then
					registerCleanup(function()
						pcall(function()
							connection:Disconnect()
						end)
					end)
				end
			end
		end
	end
end

local characterSection, combatSection, espSection

do
	local playerTab = window:CreateTab({ Name = "Player", SectionsExpanded = true })
	state.EspSection = playerTab:CreateSection({ Name = "ESP", Expanded = false })
	espSection = state.EspSection
	local movementSection = playerTab:CreateSection({ Name = "Movement", Expanded = true })
	characterSection = playerTab:CreateSection({ Name = "Character", Expanded = true })
	combatSection = playerTab:CreateSection({ Name = "Combat", Expanded = true })

	local speedBoostToggle = nil
	local boostSpeed = 350
	local speedBoostConnection = nil
	local speedBoostActive = false

	local function getCharacterParts()
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			return root, humanoid
		end
		return nil, nil
	end

	local function releaseVelocityOverride()
		if not speedBoostActive then
			return
		end
		speedBoostActive = false
		local root, humanoid = getCharacterParts()
		if not root then
			return
		end
		local currentVelocity = root.AssemblyLinearVelocity
		local moveDirection = humanoid.MoveDirection
		local horizontal = Vector3.new(moveDirection.X, 0, moveDirection.Z)
		local restoredVelocity = horizontal.Magnitude > 0.001 and horizontal.Unit * humanoid.WalkSpeed or Vector3.zero
		pcall(function()
			root.AssemblyLinearVelocity = Vector3.new(restoredVelocity.X, currentVelocity.Y, restoredVelocity.Z)
		end)
	end

	local function disconnectSpeedBoost()
		if speedBoostConnection then
			speedBoostConnection:Disconnect()
			speedBoostConnection = nil
		end
		releaseVelocityOverride()
		state.Shield("speed", false)
	end

	local function connectSpeedBoost()
		if speedBoostConnection then
			return
		end
		state.Shield("speed", true)

		speedBoostConnection = RunService.Heartbeat:Connect(function()
			if state.Steal.Active or state.Flying or state.Driving > 0 or state.Treadmill.Riding then
				speedBoostActive = false
				return
			end
			local root, humanoid = getCharacterParts()
			if not root or humanoid.Sit or humanoid.PlatformStand then
				speedBoostActive = false
				return
			end
			local ragdollEnd = tonumber(localPlayer:GetAttribute("RagdollEndTime"))
			if ragdollEnd and ragdollEnd > workspace:GetServerTimeNow() then
				speedBoostActive = false
				return
			end
			local moveDirection = humanoid.MoveDirection
			local horizontal = Vector3.new(moveDirection.X, 0, moveDirection.Z)
			if horizontal.Magnitude <= 0.001 then
				releaseVelocityOverride()
				return
			end
			local targetVelocity = horizontal.Unit * boostSpeed
			local currentVelocity = root.AssemblyLinearVelocity
			pcall(function()
				root.AssemblyLinearVelocity = Vector3.new(targetVelocity.X, currentVelocity.Y, targetVelocity.Z)
			end)
			speedBoostActive = true
		end)
	end

	state.SpeedForced = false

	local function syncSpeedBoostState()
		if state.Toggle(speedBoostToggle, false) or state.SpeedForced then
			connectSpeedBoost()
		else
			disconnectSpeedBoost()
		end
	end

	local pendingToggleSync = false
	local lastToggleWasForced = false
	local pendingForcedNotice = false

	state.SetSpeedForced = function(wanted)
		state.SpeedForced = wanted == true
		pendingToggleSync = true
		syncSpeedBoostState()
	end

	speedBoostToggle = movementSection:CreateToggle({
		Name = "Speed Boost",
		Default = false,
		Callback = function()
			if state.SpeedForced and not state.Toggle(speedBoostToggle, false) then
				pendingToggleSync = true
				pendingForcedNotice = true
			end
			syncSpeedBoostState()
		end,
	})

	local forcedSyncMonitor = RunService.Heartbeat:Connect(function()
		if pendingForcedNotice then
			pendingForcedNotice = false
			if type(nexLibrary.Notify) == "function" then
				pcall(nexLibrary.Notify, "Speed Boost", "Speed Boost must stay on while Invisibility is on.", 5)
			end
		end

		if not pendingToggleSync then
			return
		end
		pendingToggleSync = false

		local targetValue
		if state.SpeedForced and not state.Toggle(speedBoostToggle, false) then
			lastToggleWasForced = true
			targetValue = true
		else
			local needsRestore = not state.SpeedForced and lastToggleWasForced
			targetValue = nil

			if needsRestore then
				lastToggleWasForced = false
				targetValue = nil
				if state.Toggle(speedBoostToggle, false) then
					targetValue = false
				end
			end
		end

		if targetValue ~= nil then
			for _, methodName in ipairs({ "Set", "SetValue" }) do
				local ok, methodFn = pcall(function()
					return speedBoostToggle[methodName]
				end)
				if not (ok and type(methodFn) == "function" and pcall(methodFn, speedBoostToggle, targetValue)) then
					continue
				end
				break
			end
		end
	end)

	registerCleanup(function()
		forcedSyncMonitor:Disconnect()
	end)

	movementSection:CreateSlider({
		Name = "Boost Speed",
		Min = 20,
		Max = 1000,
		Default = 350,
		Increment = 5,
		Unit = "studs/s",
		Callback = function(value)
			boostSpeed = math.clamp(tonumber(value) or 350, 20, 1000)
		end,
	})

	registerCleanup(disconnectSpeedBoost)

	local infiniteJumpToggle = nil
	local infiniteJumpConnection = nil

	local function disconnectInfiniteJump()
		if infiniteJumpConnection then
			infiniteJumpConnection:Disconnect()
			infiniteJumpConnection = nil
		end
		state.Shield("jump", false)
	end

	infiniteJumpToggle = movementSection:CreateToggle({
		Name = "Infinite Jump",
		Default = false,
		Callback = function()
			if not state.Toggle(infiniteJumpToggle, false) then
				disconnectInfiniteJump()
				return
			end
			if infiniteJumpConnection then
				return
			end
			state.Shield("jump", true)

			infiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
				local character = localPlayer.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					pcall(function()
						humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end)
				end
			end)
		end,
	})

	registerCleanup(disconnectInfiniteJump)
end

do
	local invisToggle = nil
	local invisEnabled = false
	local alive = true
	local respawning = false
	local applyingInvis = false
	local respawnRequested = false
	local lastInvisState = nil
	local lastAutoRotateHumanoid = nil
	local invisHipHeight = 999

	local function isInvisActive()
		return invisEnabled and not state.InvisSuspended and not state.InvisMech
	end

	local function getHumanoid(character)
		return character and character:FindFirstChildOfClass("Humanoid") or nil
	end

	local function getNetworkingRemote(name)
		return networking:FindFirstChild(name)
	end

	local function hasInvisApplied(character)
		return character ~= nil and character:GetAttribute("InvisApplied") == true
	end

	local function askDoffTreadmill()
		local askDoff = getNetworkingRemote("RF/Treadmill/AskDoff")
		if askDoff and askDoff:IsA("RemoteFunction") then
			for _ = 1, 2 do
				pcall(askDoff.InvokeServer, askDoff)
			end
		end
	end

	local function fireRigWipe(character)
		local askRigWipe = getNetworkingRemote("RE/RigSync/AskRigWipe")
		if askRigWipe and askRigWipe:IsA("RemoteEvent") then
			pcall(askRigWipe.FireServer, askRigWipe, character)
		end
	end

	local function unequipAllTools(character)
		local backpack = localPlayer:FindFirstChildOfClass("Backpack")

		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Humanoid") then
				pcall(child.UnequipTools, child)
			end
		end

		if backpack then
			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("Tool") then
					pcall(function()
						child.Parent = backpack
					end)
				end
			end
		end

		for _ = 1, 3 do
			RunService.Heartbeat:Wait()
		end
	end

	local function forceKillCharacter(character)
		local humanoid = getHumanoid(character)
		if not character or not humanoid then
			return false
		end
		unequipAllTools(character)
		askDoffTreadmill()

		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			humanoid.BreakJointsOnDeath = true
			humanoid.RequiresNeck = true
			humanoid.Health = 0
		end)

		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Dead)
		end)

		pcall(function()
			character:BreakJoints()
		end)

		fireRigWipe(character)
		return true
	end

	local function installInvisRig(character)
		local humanoid = getHumanoid(character)
		local waitUntil = os.clock() + 10

		while true do
			if os.clock() < waitUntil and alive and character.Parent then
				humanoid = humanoid or getHumanoid(character)
				if not (humanoid and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("Head")) then
					task.wait()
					continue
				end
			end
			break
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		if not isInvisActive() or not humanoid or not root or not character:FindFirstChild("Head") then
			return false
		end

		task.wait(0.05)
		if not isInvisActive() or character.Parent == nil then
			return false
		end

		for _ = 1, 2 do
			pcall(humanoid.UnequipTools, humanoid)
		end

		if type(replicatesignal) == "function" then
			for _ = 1, 2 do
				pcall(replicatesignal, humanoid.ServerBreakJoints)
			end
		end

		local originalHipHeight = humanoid.HipHeight

		pcall(function()
			humanoid.HipHeight = invisHipHeight
		end)

		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Accessory") or (child:IsA("BasePart") and child ~= root) then
				pcall(function()
					child.Parent = nil
				end)
			end
		end

		task.wait(0.12)

		local function restoreHipHeight()
			pcall(function()
				humanoid.HipHeight = originalHipHeight
			end)

			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("Humanoid") and child.HipHeight ~= originalHipHeight then
					pcall(function()
						child.HipHeight = originalHipHeight
					end)
				end
			end
		end

		if character.Parent == nil then
			restoreHipHeight()
			return false
		end

		local wristMotor = Instance.new("Motor6D")
		wristMotor.Name = "RightWrist"
		wristMotor.C0 = CFrame.new(1.2, 0, 0)
		wristMotor.C1 = CFrame.new()
		wristMotor.Part0 = root
		wristMotor.Parent = root

		local rightHand = Instance.new("Part")
		rightHand.Name = "RightHand"
		rightHand.Size = Vector3.new(0.2, 0.2, 0.2)
		rightHand.Transparency = 1
		rightHand.CanCollide = false
		rightHand.CanTouch = false
		rightHand.CanQuery = false
		rightHand.Massless = true
		rightHand.CFrame = root.CFrame * wristMotor.C0
		wristMotor.Part1 = rightHand
		rightHand.Parent = character

		pcall(function()
			root.CanCollide = false
		end)

		restoreHipHeight()
		character:SetAttribute("InvisApplied", true)

		task.delay(1, function()
			local genv = typeof(getgenv) == "function" and getgenv() or _G
			local toolKeeper = genv.NexToolKeeper

			if character.Parent and type(toolKeeper) == "function" then
				pcall(toolKeeper)
			end
		end)

		task.delay(0.2, function()
			if root.Parent then
				pcall(function()
					root.CanCollide = true
				end)
			end
		end)

		local childAddedConnection = character.ChildAdded:Connect(function(child)
			if child:IsA("Humanoid") then
				task.defer(function()
					if child.HipHeight ~= originalHipHeight then
						pcall(function()
							child.HipHeight = originalHipHeight
						end)
					end
				end)
			end
		end)

		local ancestryConnection
		ancestryConnection = character.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				childAddedConnection:Disconnect()
				ancestryConnection:Disconnect()
			end
		end)

		return true
	end

	local function isMovementBlocked()
		local busy = state.Steal.Active or state.Steal.Carrying or state.Flying

		if not busy then
			busy = (state.Driving or 0) > 0
		end

		return busy
	end

	state.RequestRespawn = function()
		respawnRequested = true
	end

	local function respawnForInvisibility()
		respawning = true
		local wasRequested = respawnRequested

		while true do
			local shouldWait = alive

			if alive then
				shouldWait = isMovementBlocked() or not state.ClaimMovement("invisibility")
			end

			if shouldWait then
				task.wait(0.2)
				continue
			end
			break
		end

		local character = localPlayer.Character

		if alive and character and (wasRequested or hasInvisApplied(character) ~= isInvisActive()) and getHumanoid(character) then
			respawnRequested = false
			runtimeState.Paused = true
			state.ShieldPaused = true
			pcall(state.UndoSwap)
			task.wait()
			forceKillCharacter(localPlayer.Character)
			local killDeadline = os.clock() + 60
			local rigWipeDueAt = os.clock() + 8

			while alive and os.clock() < killDeadline and localPlayer.Character == character do
				if rigWipeDueAt <= os.clock() then
					rigWipeDueAt = os.clock() + 8
					fireRigWipe(character)
				end

				task.wait(0.05)
			end

			task.wait(0.1)

			while alive and applyingInvis do
				task.wait(0.05)
			end
		end

		runtimeState.Paused = false
		state.ShieldPaused = false
		state.ReleaseMovement("invisibility")
		respawning = false
	end

	local characterAddedConnection = localPlayer.CharacterAdded:Connect(function(character)
		if not isInvisActive() then
			return
		end
		applyingInvis = true
		state.ShieldPaused = true

		task.spawn(function()
			pcall(installInvisRig, character)
			applyingInvis = false

			if not respawning then
				state.ShieldPaused = false
			end
		end)
	end)

	local monitorThread = task.spawn(function()
		while alive do
			local character = localPlayer.Character
			local humanoid = getHumanoid(character)

			if not respawning and not applyingInvis and character and humanoid and humanoid.Health > 0 and (respawnRequested or hasInvisApplied(character) ~= isInvisActive()) then
				respawnForInvisibility()
			end

			local invisNow = hasInvisApplied(localPlayer.Character)

			if invisNow ~= lastInvisState then
				lastInvisState = invisNow
				state.SetSpeedForced(invisNow)
			end

			task.wait(0.25)
		end
	end)

	local toolFollowConnection = RunService.Heartbeat:Connect(function()
		local character = localPlayer.Character
		if not character or not hasInvisApplied(character) then
			return
		end
		local rightHand = character:FindFirstChild("RightHand")
		local tool = character:FindFirstChildWhichIsA("Tool")
		local handle = tool and tool:FindFirstChild("Handle")
		if not rightHand or not handle or not handle:IsA("BasePart") then
			return
		end
		local gripOffset = CFrame.new()

		for _, child in ipairs(rightHand:GetChildren()) do
			if child:IsA("JointInstance") and child.Name == "RightGrip" and child.Part1 == handle then
				gripOffset = child.C0 * child.C1:Inverse()

				if child.Enabled then
					child.Enabled = false
				end
			end
		end

		pcall(function()
			handle.CFrame = rightHand.CFrame * gripOffset
			handle.AssemblyLinearVelocity = Vector3.zero
			handle.AssemblyAngularVelocity = Vector3.zero
		end)
	end)

	registerCleanup(function()
		toolFollowConnection:Disconnect()
	end)

	local autoRotateConnection = RunService.Heartbeat:Connect(function()
		local character = localPlayer.Character
		local humanoid = getHumanoid(character)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or humanoid.Health <= 0 then
			return
		end
		local shouldFaceMove = hasInvisApplied(character) and not state.Steal.Active and not state.Flying

		if shouldFaceMove then
			shouldFaceMove = (state.Driving or 0) == 0
		end

		if shouldFaceMove then
			shouldFaceMove = not (state.Treadmill and state.Treadmill.Riding)
		end

		if not (shouldFaceMove and not humanoid.Sit and not humanoid.PlatformStand) then
			if lastAutoRotateHumanoid == humanoid then
				lastAutoRotateHumanoid = nil

				pcall(function()
					humanoid.AutoRotate = true
				end)
			end

			return
		end

		if humanoid.AutoRotate then
			pcall(function()
				humanoid.AutoRotate = false
			end)
		end

		lastAutoRotateHumanoid = humanoid
		local moveDirection = humanoid.MoveDirection
		local horizontal = Vector3.new(moveDirection.X, 0, moveDirection.Z)

		if horizontal.Magnitude > 0.01 then
			pcall(function()
				root.CFrame = CFrame.lookAt(root.Position, root.Position + horizontal.Unit)
			end)
		end
	end)

	invisToggle = characterSection:CreateToggle({
		Name = "Invisibility",
		Note = "Makes you invisible to other players",
		Default = false,
		Callback = function()
			local conflictingFeature = nil

			if type(state.CombatActive) == "function" and state.CombatActive() then
				conflictingFeature = "Auto Hit"
			end

			if state.Toggle(invisToggle, false) and conflictingFeature then
				invisEnabled = false
				local handle = invisToggle

				state.UiDefer(function()
					pcall(handle.Set, handle, false, false)
					state.Notify("Invisibility", "Turn off " .. conflictingFeature .. " first, both cannot be on at the same time")
				end)

				return
			end

			invisEnabled = state.Toggle(invisToggle, false) == true

			if isInvisActive() and not hasInvisApplied(localPlayer.Character) and state.Movement.Owner == nil then
				state.Movement.Owner = "invisibility"
			end
		end,
	})

	state.InvisibilityHandle = invisToggle

	registerCleanup(function()
		alive = false
		characterAddedConnection:Disconnect()
		autoRotateConnection:Disconnect()
		pcall(task.cancel, monitorThread)
		runtimeState.Paused = false
		state.ShieldPaused = false
		state.ReleaseMovement("invisibility")
	end)
end

do
	local ragdollConstraintClassNames = {
		BallSocketConstraint = true,
		NoCollisionConstraint = true,
		HingeConstraint = true,
	}

	local ragdollStates = {
		[Enum.HumanoidStateType.Physics] = true,
		[Enum.HumanoidStateType.Ragdoll] = true,
		[Enum.HumanoidStateType.FallingDown] = true,
	}

	local recoveryGraceSeconds = 0.5
	local maxVelocityBump = 5
	local maxFallY = 0
	local antiGuardHitWindow = 21

	local ragdollModule = requireModule(function()
		return ReplicatedStorage.Shared.Modules.Ragdoll
	end)

	local cachedPlayerControls = nil

	local function getPlayerControls()
		if cachedPlayerControls then
			return cachedPlayerControls
		end

		local ok, result = pcall(function()
			return require(localPlayer:WaitForChild("PlayerScripts", 5):WaitForChild("PlayerModule", 5)):GetControls()
		end)

		if ok then
			cachedPlayerControls = result
		end

		return cachedPlayerControls
	end

	local antiRagdollToggle = nil
	local antiRagdollEnabled = false
	local mainHeartbeatConnection = nil
	local recoverySuppressUntil = 0
	local watchCharacter = nil
	local persistentConnections = {}
	local characterConnections = {}
	local characterGeneration = 0
	local currentCharacter = nil
	local currentHumanoid = nil

	local function disconnectAll(connections)
		for _, connection in ipairs(connections) do
			if connection.Connected then
				connection:Disconnect()
			end
		end
		table.clear(connections)
	end

	local function addPersistentConnection(connection)
		persistentConnections[#persistentConnections + 1] = connection
	end

	local function addCharacterConnection(connection)
		characterConnections[#characterConnections + 1] = connection
	end

	local function limitVelocity()
		if not currentCharacter or not currentHumanoid then
			return
		end

		local root = currentCharacter:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		local velocity = root.AssemblyLinearVelocity
		local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
		local maxHorizontal = currentHumanoid.WalkSpeed + maxVelocityBump
		local vertical = velocity.Y
		local changed = false

		if maxHorizontal < horizontal.Magnitude then
			horizontal = horizontal.Unit * maxHorizontal
			changed = true
		end

		if vertical > maxFallY then
			vertical = maxFallY
			changed = true
		end

		if changed then
			pcall(function()
				root.AssemblyLinearVelocity = Vector3.new(horizontal.X, vertical, horizontal.Z)
			end)
		end
	end

	local function clearClientRagdoll()
		if type(ragdollModule) ~= "table" then
			return
		end

		if type(ragdollModule.ClearClientRagdoll) == "function" then
			pcall(ragdollModule.ClearClientRagdoll)
		end

		if type(ragdollModule.Unragdoll) == "function" then
			pcall(ragdollModule.Unragdoll, currentCharacter)
		end
	end

	local function destroyRagdollConstraints()
		if not currentCharacter or not currentCharacter.Parent then
			return
		end

		for _, descendant in ipairs(currentCharacter:GetDescendants()) do
			if ragdollConstraintClassNames[descendant.ClassName] then
				pcall(function()
					descendant:Destroy()
				end)
			end
		end
	end

	local function enableMotorJoints()
		if not currentCharacter or not currentCharacter.Parent then
			return
		end

		for _, descendant in ipairs(currentCharacter:GetDescendants()) do
			if descendant:IsA("Motor6D") and not descendant.Enabled then
				pcall(function()
					descendant.Enabled = true
				end)
			elseif descendant:IsA("AnimationConstraint") and not descendant.Enabled then
				pcall(function()
					descendant.Enabled = true
				end)
			end
		end
	end

	local function enablePlayerControls()
		local controls = getPlayerControls()

		if controls and controls.controlsEnabled == false then
			pcall(function()
				controls:Enable()
			end)
		end
	end

	local function attachCamera()
		local camera = workspace.CurrentCamera

		if camera and currentHumanoid and camera.CameraSubject ~= currentHumanoid then
			pcall(function()
				camera.CameraSubject = currentHumanoid
			end)
		end
	end

	local function restoreRunningState()
		if not currentHumanoid or not currentHumanoid.Parent or currentHumanoid.Health <= 0 then
			return
		end

		if ragdollStates[currentHumanoid:GetState()] then
			pcall(function()
				currentHumanoid:ChangeState(Enum.HumanoidStateType.Running)
			end)
		end

		if currentHumanoid.PlatformStand then
			currentHumanoid.PlatformStand = false
		end
	end

	local function isRagdolled()
		if type(ragdollModule) == "table" and type(ragdollModule.IsRagdolled) == "function" then
			local ok, result = pcall(ragdollModule.IsRagdolled, currentCharacter)
			if ok and result == true then
				return true
			end
		end

		local endTime = tonumber(localPlayer:GetAttribute("RagdollEndTime"))
		return endTime ~= nil and endTime > workspace:GetServerTimeNow()
	end

	local function isAntiGuardBusy()
		if state.AntiGuard.Busy == true then
			return true
		end

		if (tonumber(state.AntiGuard.HitArms) or 0) <= 0 then
			return false
		end

		return os.clock() - (tonumber(state.AntiGuard.HitArmedAt) or 0) <= antiGuardHitWindow
	end

	local function isInRagdollState()
		if not currentHumanoid or not currentHumanoid.Parent then
			return false
		end

		if currentHumanoid.PlatformStand then
			return true
		end

		return ragdollStates[currentHumanoid:GetState()] == true
	end

	local function hasRagdollConstraints()
		if not currentCharacter or not currentCharacter.Parent then
			return false
		end

		for _, child in ipairs(currentCharacter:GetChildren()) do
			if ragdollConstraintClassNames[child.ClassName] then
				return true
			end

			if child:IsA("BasePart") then
				for _, nested in ipairs(child:GetChildren()) do
					if ragdollConstraintClassNames[nested.ClassName] then
						return true
					end
				end
			end
		end

		return false
	end

	local function applyRecovery()
		limitVelocity()
		clearClientRagdoll()
		destroyRagdollConstraints()
		enableMotorJoints()
		restoreRunningState()
		enablePlayerControls()
		attachCamera()
	end

	local function scheduleRecovery()
		if not antiRagdollEnabled or isAntiGuardBusy() or localPlayer:GetAttribute("RaceId") ~= nil then
			return
		end
		recoverySuppressUntil = os.clock() + recoveryGraceSeconds
	end

	local function heartbeatTick()
		if not antiRagdollEnabled then
			return
		end
		if localPlayer:GetAttribute("RaceId") ~= nil then
			recoverySuppressUntil = 0
			return
		end
		watchCharacter()
		if not currentCharacter or not currentHumanoid or currentHumanoid.Health <= 0 then
			return
		end

		if isAntiGuardBusy() then
			recoverySuppressUntil = 0
			return
		end
		local now = os.clock()

		if isInRagdollState() or isRagdolled() or hasRagdollConstraints() then
			recoverySuppressUntil = now + recoveryGraceSeconds
		end

		if now <= recoverySuppressUntil then
			applyRecovery()
		end
	end

	watchCharacter = function(character)
		characterGeneration = characterGeneration + 1
		local myGeneration = characterGeneration
		disconnectAll(characterConnections)
		currentCharacter = character
		currentHumanoid = nil
		if not antiRagdollEnabled or not character then
			return
		end
		currentHumanoid = character:FindFirstChildOfClass("Humanoid")
		if not antiRagdollEnabled or characterGeneration ~= myGeneration or character ~= localPlayer.Character or not currentHumanoid or not currentHumanoid:IsA("Humanoid") then
			return
		end

		addCharacterConnection(currentHumanoid.StateChanged:Connect(function(_, newState)
			if antiRagdollEnabled and ragdollStates[newState] then
				scheduleRecovery()
			end
		end))

		addCharacterConnection(currentHumanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
			if antiRagdollEnabled and currentHumanoid and currentHumanoid.PlatformStand then
				scheduleRecovery()
			end
		end))

		addCharacterConnection(character.DescendantAdded:Connect(function(descendant)
			if antiRagdollEnabled and ragdollConstraintClassNames[descendant.ClassName] then
				scheduleRecovery()
			end
		end))

		addCharacterConnection(character.ChildAdded:Connect(function(child)
			if antiRagdollEnabled and child:IsA("Humanoid") and child ~= currentHumanoid then
				task.defer(watchCharacter)
			end
		end))

		attachCamera()

		if isRagdolled() then
			scheduleRecovery()
		end
	end

	local function stopAntiRagdoll()
		antiRagdollEnabled = false
		characterGeneration = characterGeneration + 1
		recoverySuppressUntil = 0

		if mainHeartbeatConnection then
			pcall(function()
				mainHeartbeatConnection:Disconnect()
			end)

			mainHeartbeatConnection = nil
		end

		disconnectAll(characterConnections)
		disconnectAll(persistentConnections)
		currentCharacter = nil
		currentHumanoid = nil
	end

	local function startAntiRagdoll()
		stopAntiRagdoll()
		antiRagdollEnabled = true
		getPlayerControls()
		mainHeartbeatConnection = RunService.Heartbeat:Connect(heartbeatTick)

		addPersistentConnection(localPlayer.CharacterAdded:Connect(function(character)
			if antiRagdollEnabled then
				task.defer(function()
					if antiRagdollEnabled and character == localPlayer.Character then
						watchCharacter(character)
					end
				end)
			end
		end))

		addPersistentConnection(localPlayer.CharacterRemoving:Connect(function(character)
			if antiRagdollEnabled and character == currentCharacter then
				characterGeneration = characterGeneration + 1
				recoverySuppressUntil = 0
				disconnectAll(characterConnections)
				currentCharacter = nil
				currentHumanoid = nil
			end
		end))

		addPersistentConnection(localPlayer:GetAttributeChangedSignal("RagdollEndTime"):Connect(function()
			if antiRagdollEnabled then
				scheduleRecovery()
			end
		end))

		local clientRagdollRemote = type(ragdollModule) == "table" and ragdollModule.ClientRagdollRemote or nil

		if typeof(clientRagdollRemote) == "Instance" and clientRagdollRemote:IsA("RemoteEvent") then
			addPersistentConnection(clientRagdollRemote.OnClientEvent:Connect(function()
				if antiRagdollEnabled and not isAntiGuardBusy() then
					limitVelocity()
					scheduleRecovery()
				end
			end))
		end

		addPersistentConnection(state.OnHumanoidChanged(function()
			if antiRagdollEnabled and localPlayer.Character then
				watchCharacter(localPlayer.Character)
			end
		end))

		if localPlayer.Character then
			watchCharacter(localPlayer.Character)
		end
	end

	registerCleanup(stopAntiRagdoll)

	antiRagdollToggle = characterSection:CreateToggle({
		Name = "Anti Ragdoll",
		Default = true,
		Callback = function()
			if state.Toggle(antiRagdollToggle, false) then
				startAntiRagdoll()
			else
				stopAntiRagdoll()
			end
		end,
	})
end

do
	local healingEnabled = true
	local healingConnections = {}

	local function disconnectHealingConnections()
		for _, connection in ipairs(healingConnections) do
			pcall(function()
				connection:Disconnect()
			end)
		end

		table.clear(healingConnections)
	end

	local function healHumanoid(humanoid)
		if healingEnabled and humanoid.Parent and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
			pcall(function()
				humanoid.Health = humanoid.MaxHealth
			end)
		end
	end

	local function watchHumanoid(character)
		disconnectHealingConnections()
		if not healingEnabled or not character then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
		if not healingEnabled or not humanoid or not humanoid:IsA("Humanoid") or character ~= localPlayer.Character then
			return
		end

		table.insert(healingConnections, humanoid.HealthChanged:Connect(function()
			healHumanoid(humanoid)
		end))

		table.insert(healingConnections, RunService.Heartbeat:Connect(function()
			healHumanoid(humanoid)
		end))

		healHumanoid(humanoid)
	end

	local characterAddedConnection = localPlayer.CharacterAdded:Connect(function(character)
		if healingEnabled then
			task.defer(watchHumanoid, character)
		end
	end)

	local humanoidChangedHandle = state.OnHumanoidChanged(function()
		if healingEnabled and localPlayer.Character then
			watchHumanoid(localPlayer.Character)
		end
	end)

	registerCleanup(function()
		healingEnabled = false
		characterAddedConnection:Disconnect()
		humanoidChangedHandle:Disconnect()
		disconnectHealingConnections()
	end)

	healingEnabled = true

	if localPlayer.Character then
		task.spawn(watchHumanoid, localPlayer.Character)
	end
end

do
	local antiTrapToggle = nil
	local antiTrapEnabled = true
	local savedCanTouch = {}
	local antiTrapConnections = {}

	local function disableTouchOnPart(instance)
		if instance:IsA("BasePart") and savedCanTouch[instance] == nil then
			savedCanTouch[instance] = instance.CanTouch

			pcall(function()
				instance.CanTouch = false
			end)
		end
	end

	local function watchTrap(trap)
		if not antiTrapEnabled or not trap.Parent then
			return
		end
		if trap:GetAttribute("Owner") == localPlayer.Name then
			return
		end
		disableTouchOnPart(trap)

		for _, descendant in ipairs(trap:GetDescendants()) do
			disableTouchOnPart(descendant)
		end

		table.insert(antiTrapConnections, trap.DescendantAdded:Connect(function(descendant)
			if antiTrapEnabled then
				disableTouchOnPart(descendant)
			end
		end))
	end

	local function applyAntiTrapToAllTraps()
		for _, trap in ipairs(CollectionService:GetTagged("PlacedTrap")) do
			watchTrap(trap)
		end
	end

	local function restoreAllTouches()
		for part, canTouch in pairs(savedCanTouch) do
			if part.Parent then
				pcall(function()
					part.CanTouch = canTouch
				end)
			end
		end

		table.clear(savedCanTouch)
	end

	table.insert(antiTrapConnections, CollectionService:GetInstanceAddedSignal("PlacedTrap"):Connect(function(trap)
		task.defer(watchTrap, trap)
	end))

	antiTrapToggle = characterSection:CreateToggle({
		Name = "Anti Trap",
		Note = "Traps from other players cannot catch you",
		Default = true,
		Callback = function()
			antiTrapEnabled = state.Toggle(antiTrapToggle, true) == true

			if antiTrapEnabled then
				applyAntiTrapToAllTraps()
			else
				restoreAllTouches()
			end
		end,
	})

	applyAntiTrapToAllTraps()

	registerCleanup(function()
		antiTrapEnabled = false

		for _, connection in ipairs(antiTrapConnections) do
			pcall(function()
				connection:Disconnect()
			end)
		end

		table.clear(antiTrapConnections)
		restoreAllTouches()
	end)
end

do
	local instantPromptsToggle = nil
	local carryPromptName = "CarryAreaEgg"
	local alwaysSkippedNames = { ClaimLostPart = true }
	local savedHoldDurations = {}
	local promptShownConnection = nil
	local childAddedConnection = nil

	local function applyZeroHold(prompt)
		if not prompt:IsA("ProximityPrompt") or alwaysSkippedNames[prompt.Name] then
			return
		end

		if savedHoldDurations[prompt] == nil then
			if prompt.HoldDuration <= 0 and prompt.Name ~= carryPromptName then
				return
			end
			savedHoldDurations[prompt] = prompt.HoldDuration
		end

		if prompt.HoldDuration ~= 0 then
			pcall(function()
				prompt.HoldDuration = 0
			end)
		end
	end

	local function findCarryPromptOn(part)
		if part.Name ~= "SmartPromptPart" then
			return nil
		end
		local prompt = part:FindFirstChild("CarryAreaEgg")
		return prompt and prompt:IsA("ProximityPrompt") and prompt or nil
	end

	state.PromptHold = function(prompt)
		local saved = savedHoldDurations[prompt]
		if type(saved) == "number" then
			return saved
		end
		return prompt.HoldDuration
	end

	local function installPromptHooks()
		if childAddedConnection then
			return
		end

		promptShownConnection = ProximityPromptService.PromptShown:Connect(function(prompt)
			if state.Toggle(instantPromptsToggle, true) then
				applyZeroHold(prompt)
			end
		end)

		for _, child in ipairs(workspace:GetChildren()) do
			local prompt = findCarryPromptOn(child)

			if prompt then
				applyZeroHold(prompt)
			end
		end

		childAddedConnection = workspace.ChildAdded:Connect(function(child)
			if child.Name ~= "SmartPromptPart" then
				return
			end

			task.defer(function()
				local prompt = child:FindFirstChild("CarryAreaEgg") or child:WaitForChild("CarryAreaEgg", 2)

				if prompt and prompt:IsA("ProximityPrompt") and state.Toggle(instantPromptsToggle, true) then
					applyZeroHold(prompt)
				end
			end)
		end)
	end

	local function restorePromptHolds()
		for prompt, holdDuration in pairs(savedHoldDurations) do
			if prompt and prompt.Parent then
				pcall(function()
					prompt.HoldDuration = holdDuration
				end)
			end
		end

		table.clear(savedHoldDurations)

		if childAddedConnection then
			childAddedConnection:Disconnect()
			childAddedConnection = nil
		end

		if promptShownConnection then
			promptShownConnection:Disconnect()
			promptShownConnection = nil
		end
	end

	state.PressStealPrompt = function(position)
		if typeof(fireproximityprompt) ~= "function" or not position then
			return false
		end
		local bestPrompt = nil
		local bestDistance = math.huge

		for _, child in ipairs(workspace:GetChildren()) do
			local prompt = findCarryPromptOn(child)

			if prompt and child:IsA("BasePart") then
				local distance = (child.Position - position).Magnitude

				if distance < bestDistance then
					bestPrompt = prompt
					bestDistance = distance
				end
			end
		end

		if not bestPrompt or bestDistance > 14 then
			return false
		end

		if state.Toggle(instantPromptsToggle, true) then
			pcall(function()
				bestPrompt.HoldDuration = 0
			end)
		end

		local ok = pcall(fireproximityprompt, bestPrompt)

		if ok and bestPrompt.HoldDuration > 0 then
			task.wait(bestPrompt.HoldDuration + 0.1)
		end

		return ok
	end

	taskScheduler.Add(function()
		if state.Toggle(instantPromptsToggle, true) then
			installPromptHooks()

			for prompt in pairs(savedHoldDurations) do
				if not prompt.Parent then
					savedHoldDurations[prompt] = nil
				elseif prompt.HoldDuration ~= 0 then
					pcall(function()
						prompt.HoldDuration = 0
					end)
				end
			end
		elseif next(savedHoldDurations) ~= nil or childAddedConnection then
			restorePromptHolds()
		end

		return false
	end)

	instantPromptsToggle = characterSection:CreateToggle({
		Name = "Instant Prompts",
		Default = true,
		Callback = function()
			taskScheduler.Wake()
		end,
	})

	registerCleanup(restorePromptHolds)
end

state.Combat = {}

do
	local combat = state.Combat
	local baseRange = 15
	local rangeBonusTotal = 2
	local leadTimeBase = 0.05
	local rangeSafetyMargin = 1
	local leadAhead = 0.18
	local leadBias = -0.275
	local sweepRange = 0.6
	local sweepDistance = 6
	local sweepPeriod = 1.1
	local verticalPeriod = 0.8
	local verticalAmplitude = 2.5
	local velocityThreshold = 35
	local trackSampleWindow = 0.12
	local wallMargin = 6
	local wallSubSteps = 6
	local groundOffset = 3
	local armOptions = { 0.12, 0.2, 0.28, 0.36, 0.46, 0.6 }
	local wallSideNames = { ["WALL LEFT"] = true, ["WALL RIGHT"] = true }

	local combatState = {
		Trigger = nil,
		LastFire = 0,
		Trace = 0,
		EquipAt = 0,
		Walls = {},
		WallsAt = 0,
		WallSide = setmetatable({}, { __mode = "k" }),
		Tracks = setmetatable({}, { __mode = "k" }),
		Stats = {},
		Option = 3,
		Pending = {},
		Holders = {},
		SpawnRagdoll = nil,
	}

	for i = 1, #armOptions do
		combatState.Stats[i] = { Hits = 0, Shots = 0 }
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	pcall(function()
		raycastParams.RespectCanCollide = true
	end)

	local function getServerTime()
		return workspace:GetServerTimeNow()
	end

	local function getTrigger()
		local trigger = combatState.Trigger
		if trigger and trigger.Parent then
			return trigger
		end
		local remote = networking:FindFirstChild("RE/BatSwing/Trigger")
		combatState.Trigger = remote
		return remote
	end

	local function getRagdollEndTime(player)
		return tonumber(player:GetAttribute("RagdollEndTime")) or 0
	end

	combat.SetLead = function(value)
		leadBias = math.clamp((tonumber(value) or -275) / 1000, -0.4, 0.1)
	end

	combat.SetSweep = function(value)
		sweepRange = math.clamp((tonumber(value) or 60) / 100, 0, 2.5)
	end

	combat.Ragdolled = function(player)
		return getRagdollEndTime(player) > getServerTime()
	end

	combat.SelfRagdolled = function()
		local endTime = getRagdollEndTime(localPlayer)
		if endTime <= getServerTime() then
			return false
		end
		return endTime ~= combatState.SpawnRagdoll
	end

	combat.Humanoid = function(character)
		if not character then
			return nil
		end
		local fallback = nil

		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Humanoid") then
				if child.Health > 0 then
					return child
				end
				fallback = fallback or child
			end
		end

		return fallback
	end

	local function getGearRangeBonus(tool)
		local gears = modules.Gears
		local directory = type(gears) == "table" and gears.Directory or nil
		local gearEntry = type(directory) == "table" and directory[tostring(tool:GetAttribute("GearName") or tool.Name)] or nil
		local controllerData = type(gearEntry) == "table" and gearEntry.BatControllerData or nil
		return type(controllerData) == "table" and tonumber(controllerData.RangeBonus) or 0
	end

	combat.Range = function(tool)
		local dragonMultiplier = workspace:GetAttribute("DragonEggEventActive") == true and 2.5 or 1
		return (baseRange + rangeBonusTotal + (tool and getGearRangeBonus(tool) or 0)) * dragonMultiplier
	end

	combat.PickBat = function(character)
		local equipped = character:FindFirstChildWhichIsA("Tool")
		if equipped and state.IsBatTool(equipped) then
			return equipped
		end
		local containers = { character, localPlayer:FindFirstChildOfClass("Backpack") }
		local bestBonus = -1
		local bestTool = nil

		for _, container in ipairs(containers) do
			if container then
				for _, child in ipairs(container:GetChildren()) do
					if state.IsBatTool(child) then
						local bonus = getGearRangeBonus(child)

						if bestBonus < bonus then
							bestBonus = bonus
							bestTool = child
						end
					end
				end
			end
		end

		return bestTool
	end

	local function equipBat(character, humanoid, tool)
		if tool.Parent == character then
			return true
		end
		if os.clock() - combatState.EquipAt < 0.2 then
			return false
		end
		combatState.EquipAt = os.clock()

		pcall(function()
			humanoid:EquipTool(tool)
		end)

		if tool.Parent ~= character then
			pcall(function()
				tool.Parent = character
			end)
		end

		return tool.Parent == character
	end

	combat.Parts = function(player)
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			return nil, nil
		end
		return character, root
	end

	combat.Hittable = function(player)
		if not player or player == localPlayer or player.Parent ~= Players then
			return false
		end
		local character, root = combat.Parts(player)
		if not character then
			return false
		end

		if character:GetAttribute("IsTrapped") == true or player:GetAttribute("InBossArena") then
			return false
		end
		return not state.InsideBase(root.Position)
	end

	local function collectWalls()
		local cachedAt = combatState.WallsAt
		if os.clock() < cachedAt then
			return combatState.Walls
		end
		combatState.WallsAt = os.clock() + 5
		local walls = {}
		local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
		world = world and world:FindFirstChild("Build")

		if world then
			for _, child in ipairs(world:GetChildren()) do
				local collisions = child:FindFirstChild("COLLISIONS")
				collisions = collisions and collisions:FindFirstChild("GUARD NO COLLIDE")

				if collisions then
					for _, child2 in ipairs(collisions:GetChildren()) do
						if wallSideNames[child2.Name] then
							if child2:IsA("BasePart") then
								table.insert(walls, child2)
							end

							for _, descendant in ipairs(child2:GetDescendants()) do
								if descendant:IsA("BasePart") then
									table.insert(walls, descendant)
								end
							end
						end
					end
				end
			end
		end

		combatState.Walls = walls
		return walls
	end

	local function smallestAxis(size)
		if size.X <= size.Y and size.X <= size.Z then
			return "X", "Y", "Z"
		end

		if size.Y <= size.Z then
			return "Y", "X", "Z"
		end
		return "Z", "X", "Y"
	end

	local function perpendicularAxis(cframe)
		local rightY = math.abs(cframe.RightVector.Y)
		local upY = math.abs(cframe.UpVector.Y)
		local lookY = math.abs(cframe.LookVector.Y)
		if rightY >= upY and rightY >= lookY then
			return "X"
		end

		if upY >= lookY then
			return "Y"
		end
		return "Z"
	end

	local function axisInRange(position, halfSize, firstAxis, secondAxis)
		if firstAxis == secondAxis then
			return true
		end
		local bound = halfSize[firstAxis] + wallMargin
		return math.abs(position[firstAxis]) <= bound
	end

	local function keepOffWallsSingle(reference, target)
		for _, wall in ipairs(collectWalls()) do
			if wall.Parent then
				local cframe = wall.CFrame
				local size = wall.Size
				local mainAxis, secondAxis, thirdAxis = smallestAxis(size)
				local perpendicular = perpendicularAxis(cframe)
				local halfSize = size / 2
				local localTarget = cframe:PointToObjectSpace(target)

				if axisInRange(localTarget, halfSize, secondAxis, perpendicular) and axisInRange(localTarget, halfSize, thirdAxis, perpendicular) then
					local localReference = cframe:PointToObjectSpace(reference)
					local referenceDistance = math.abs(localReference[mainAxis])
					local side = combatState.WallSide[wall]

					if referenceDistance >= halfSize[mainAxis] + wallMargin * 0.5 or side == nil and referenceDistance >= halfSize[mainAxis] then
						side = localReference[mainAxis] >= 0 and 1 or -1
						combatState.WallSide[wall] = side
					elseif side == nil then
						side = localReference[mainAxis] >= 0 and 1 or -1
					end

					local offset = halfSize[mainAxis] + wallMargin

					if localTarget[mainAxis] * side < offset then
						local patched = { X = localTarget.X, Y = localTarget.Y, Z = localTarget.Z, [mainAxis] = side * offset }
						target = cframe:PointToWorldSpace(Vector3.new(patched.X, patched.Y, patched.Z))
					end
				end
			end
		end

		return target
	end

	combat.KeepOffWalls = function(reference, target)
		local single = keepOffWallsSingle(reference, target)
		local delta = single - reference

		if wallMargin < delta.Magnitude then
			local lastGood = reference

			for i = 1, wallSubSteps do
				local step = reference + delta * i / wallSubSteps
				local patched = keepOffWallsSingle(lastGood, step)
				if (patched - step).Magnitude > 0.01 then
					return keepOffWallsSingle(reference, patched)
				end
				lastGood = patched
			end
		end

		return single
	end

	combat.ResetWalls = function()
		table.clear(combatState.WallSide)
	end

	local filterRefreshAt = 0
	local lastCharacter = nil

	local function castRayDown(position)
		local character = localPlayer.Character

		if os.clock() - filterRefreshAt > 0.5 or character ~= lastCharacter then
			filterRefreshAt = os.clock()
			lastCharacter = character
			local excluded = {}

			for _, player in ipairs(Players:GetPlayers()) do
				if player.Character then
					table.insert(excluded, player.Character)
				end
			end

			raycastParams.FilterDescendantsInstances = excluded
		end

		local hit = workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -400, 0), raycastParams)
		if hit and position.Y < hit.Position.Y + groundOffset then
			return Vector3.new(position.X, hit.Position.Y + groundOffset, position.Z)
		end
		return position
	end

	local function trackTarget(player, root)
		local track = combatState.Tracks[player]

		if not track then
			local newTrack = { Samples = {}, Smooth = nil, Heading = nil }
			combatState.Tracks[player] = newTrack
			track = newTrack
		end

		local now = os.clock()
		local samples = track.Samples
		table.insert(samples, { Time = now, Position = root.Position })

		while #samples > 2 and now - samples[1].Time > trackSampleWindow do
			table.remove(samples, 1)
		end

		local liveVelocity = root.AssemblyLinearVelocity
		local oldest = samples[1]
		local span = now - oldest.Time
		local velocity

		if span >= 0.03 then
			velocity = (root.Position - oldest.Position) / span

			if not (velocity.Magnitude <= 1500 and liveVelocity.Magnitude <= velocity.Magnitude * 1.4) then
				velocity = liveVelocity
			end
		else
			velocity = liveVelocity
		end

		local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
		track.Smooth = track.Smooth and track.Smooth:Lerp(horizontal, 0.25) or horizontal
		local smooth = track.Smooth

		if smooth.Magnitude > 1 then
			local heading = track.Heading and track.Heading:Lerp(smooth.Unit, 0.25) or smooth.Unit
			track.Heading = heading.Magnitude > 0.01 and heading.Unit or smooth.Unit
		end

		return velocity, horizontal, smooth, track
	end

	local function pickArmIndex()
		local totalShots = 0

		for _, stat in ipairs(combatState.Stats) do
			totalShots = totalShots + stat.Shots
		end

		local option = combatState.Option
		local bestScore = -math.huge

		for i, stat in ipairs(combatState.Stats) do
			local shots = stat.Shots + 1
			local score = (stat.Hits + 1) / (stat.Shots + 2) + math.sqrt(2 * math.log(totalShots + 2) / shots) * 0.35

			if score > bestScore then
				bestScore = score
				option = i
			end
		end

		combatState.Option = option
		return option
	end

	local function drainPendingHits()
		local now = os.clock()

		for i = #combatState.Pending, 1, -1 do
			local pending = combatState.Pending[i]
			local stat = combatState.Stats[pending.Option]

			if pending.RagdollBefore + 0.01 < getRagdollEndTime(pending.Target) then
				stat.Hits = stat.Hits + 1
				stat.Shots = stat.Shots + 1
				table.remove(combatState.Pending, i)
			elseif pending.Wait < now - pending.At then
				if (pending.Tool and tonumber(pending.Tool:GetAttribute("CooldownEndTime")) or 0) > pending.CooldownBefore + 0.01 then
					stat.Shots = stat.Shots + 1
				end

				table.remove(combatState.Pending, i)
			end
		end
	end

	combat.Plan = function(player, referenceRoot, precomputedRoot, skipWalls)
		if not precomputedRoot then
			local v
			v, precomputedRoot = combat.Parts(player)
		end

		if not precomputedRoot or not precomputedRoot.Parent then
			return nil
		end
		local ping = math.clamp(localPlayer:GetNetworkPing(), 0, 1)
		local adjustedPing = math.clamp(ping + leadTimeBase, 0.05, 0.35)
		local velocity, horizontalVelocity, smoothVelocity, track = trackTarget(player or precomputedRoot, precomputedRoot)
		local armOption = pickArmIndex()
		local armLead = armOptions[armOption]
		local position = precomputedRoot.Position
		local historicalPoint = position + velocity * math.max(0, armLead + ping - adjustedPing)
		local currentPoint = position + velocity * (armLead + ping)
		local smoothMagnitude = smoothVelocity.Magnitude
		local heading = track.Heading

		if not heading then
			local toReference = Vector3.new(referenceRoot.Position.X - position.X, 0, referenceRoot.Position.Z - position.Z)
			heading = toReference.Magnitude > 0.1 and toReference.Unit or Vector3.new(0, 0, 1)
		end

		local character = localPlayer.Character
		local bat = combat.PickBat(character or localPlayer)
		local range = combat.Range(bat)
		local standPoint = position + smoothVelocity * (ping + armLead + leadAhead + leadBias)
			+ (smoothMagnitude > 1 and smoothVelocity.Unit * sweepDistance * sweepRange or Vector3.zero)
		local sweepRadius = math.max(5, math.min(range * 0.7, 6 + smoothMagnitude * 0.07)) * sweepRange
		local now = os.clock()
		local sweepOffset = (math.sin(now * math.pi * 2 / sweepPeriod) * 0.5 + 0.5) * sweepRadius
		local verticalOffset = math.sin(now * math.pi * 2 / verticalPeriod) * verticalAmplitude
		local lateral = Vector3.new(-heading.Z, 0, heading.X)

		if lateral:Dot(referenceRoot.Position - standPoint) < 0 then
			lateral = -lateral
		end

		local rawGoal = standPoint
			+ heading * sweepOffset
			+ lateral * (horizontalVelocity.Magnitude < velocityThreshold and 3 or 1.5)
			+ Vector3.new(0, verticalOffset, 0)
		local goal = referenceRoot.Position

		if not skipWalls then
			goal = combat.KeepOffWalls(referenceRoot.Position, castRayDown(Vector3.new(rawGoal.X, rawGoal.Y, position.Z)))
		end

		return {
			Goal = goal,
			Velocity = Vector3.new(smoothVelocity.X, 0, smoothVelocity.Z),
			Face = currentPoint,
			Current = currentPoint,
			Historical = historicalPoint,
			Option = armOption,
			Distance = (position - referenceRoot.Position).Magnitude,
		}
	end

	combat.Steer = function(root, plan, speed, maxSpeed, deltaTime)
		local stepDelta = math.max(deltaTime, 0.0041666666666666666)
		local velocity = plan.Velocity
		local desired = velocity + (plan.Goal - root.Position) / math.max(0.12, stepDelta)
		local allowedSpeed = math.min(speed + velocity.Magnitude, maxSpeed)

		if desired.Magnitude > allowedSpeed then
			desired = desired.Unit * allowedSpeed
		end

		local position = root.Position
		local nextPosition = position + desired * stepDelta
		local patched = combat.KeepOffWalls(position, nextPosition)

		if (patched - nextPosition).Magnitude > 0.01 then
			desired = (patched - position) / stepDelta
		end

		local selfPatched = combat.KeepOffWalls(position, position)

		if (selfPatched - position).Magnitude > 0.01 then
			desired = (selfPatched - position) / math.max(0.12, stepDelta)
		end

		local finalVelocity = desired + Vector3.new(0, workspace.Gravity * stepDelta * 0.5, 0)

		pcall(function()
			local faceDirection = Vector3.new(plan.Face.X - position.X, 0, plan.Face.Z - position.Z)

			if faceDirection.Magnitude > 0.05 then
				root.CFrame = CFrame.lookAt(position, position + faceDirection.Unit)
			end

			root.AssemblyLinearVelocity = finalVelocity
			root.AssemblyAngularVelocity = Vector3.zero
		end)
	end

	combat.TryHit = function(targetPlayer, plan)
		drainPendingHits()

		if workspace:GetAttribute("PvPDisabled") == true then
			return "Player hits are off right now"
		end
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = combat.Humanoid(character)
		if not root or not humanoid or humanoid.Health <= 0 then
			return "Waiting for your character"
		end
		local bat = combat.PickBat(character)
		if not bat then
			return "No bat found"
		end

		if not equipBat(character, humanoid, bat) then
			return "Equipping " .. tostring(bat:GetAttribute("GearName") or bat.Name)
		end

		if not combat.Hittable(targetPlayer) or combat.Ragdolled(targetPlayer) then
			return nil
		end
		plan = plan or combat.Plan(targetPlayer, root)
		if not plan then
			return nil
		end
		local range = combat.Range(bat) - rangeSafetyMargin
		local estimatedPosition = root.Position - root.AssemblyLinearVelocity * leadAhead
		if (plan.Historical - estimatedPosition).Magnitude > range and (plan.Current - estimatedPosition).Magnitude > range then
			return nil
		end
		local trigger = getTrigger()
		if not trigger then
			return nil
		end
		local ping = math.clamp(localPlayer:GetNetworkPing(), 0, 1)
		local cooldownEnd = tonumber(bat:GetAttribute("CooldownEndTime")) or 0
		if getServerTime() < cooldownEnd - ping * 0.5 then
			return nil
		end

		if os.clock() - combatState.LastFire < math.max(0.12, ping * 1.5) then
			return nil
		end
		combatState.LastFire = os.clock()
		combatState.Trace = combatState.Trace + 1

		table.insert(combatState.Pending, {
			Target = targetPlayer,
			Option = plan.Option,
			At = os.clock(),
			Wait = math.max(0.5, ping * 2 + 0.3),
			RagdollBefore = getRagdollEndTime(targetPlayer),
			CooldownBefore = cooldownEnd,
			Tool = bat,
		})

		local trace = string.format("%d:%d:%d", localPlayer.UserId, combatState.Trace, math.floor(getServerTime() * 1000))

		pcall(function()
			trigger:FireServer(targetPlayer, trace)
		end)

		return "Hitting " .. targetPlayer.DisplayName
	end

	combat.ReadyBat = function()
		local character = localPlayer.Character
		local humanoid = combat.Humanoid(character)
		if not character or not humanoid or humanoid.Health <= 0 then
			return false
		end
		local bat = combat.PickBat(character)
		return bat ~= nil and equipBat(character, humanoid, bat)
	end

	combat.Swing = function()
		if state.Steal.Active or state.Steal.Carrying then
			return false
		end
		local blocked = os.clock() - combatState.LastFire < 0.3

		if not blocked then
			blocked = os.clock() - (combatState.LastSwing or 0) < 0.15
		end

		if blocked then
			return false
		end
		local character = localPlayer.Character
		local humanoid = combat.Humanoid(character)
		if not character or not humanoid or humanoid.Health <= 0 then
			return false
		end
		local bat = combat.PickBat(character)
		if not bat or not equipBat(character, humanoid, bat) then
			return false
		end
		combatState.LastSwing = os.clock()

		pcall(function()
			bat:Activate()
		end)

		return true
	end

	combat.HolderOf = function(uid)
		local model = workspace:FindFirstChild(uid)
		if not model then
			return nil
		end

		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") or descendant:IsA("RigidConstraint") then
				local ok, partA, partB = pcall(function()
					return descendant.Part0, descendant.Part1
				end)

				if ok then
					for _, part in ipairs({ partA, partB }) do
						if typeof(part) == "Instance" and not part:IsDescendantOf(model) then
							local ancestor = part:FindFirstAncestorOfClass("Model")
							local player = ancestor and (Players:GetPlayerFromCharacter(ancestor) or Players:FindFirstChild(ancestor.Name)) or nil
							if player and player ~= localPlayer and player:IsA("Player") then
								return player
							end
						end
					end
				end
			end
		end

		return nil
	end

	task.spawn(function()
		while not state.CombatDisposed do
			local holders = {}

			if state.CombatWantsHolders then
				local eggState = modules.EggState

				if type(eggState) == "table" and type(eggState.ReadFieldEggs) == "function" then
					local ok, result = pcall(eggState.ReadFieldEggs)
					local records = ok and type(result) == "table" and result.Records or nil

					if type(records) == "table" then
						for _, record in pairs(records) do
							if type(record) == "table" and record.State == "Carried" and type(record.Uid) == "string" then
								local holder = combat.HolderOf(record.Uid)

								if holder then
									holders[holder] = true
								end
							end
						end
					end
				end
			end

			combatState.Holders = holders
			task.wait(0.3)
		end
	end)

	combat.IsHolder = function(player)
		return combatState.Holders[player] == true
	end

	local newLifeCallbacks = {}

	combat.OnNewLife = function(callback)
		table.insert(newLifeCallbacks, callback)
	end

	local function resetCombatOnNewLife()
		table.clear(combatState.Pending)
		combatState.LastFire = 0
		combatState.LastSwing = 0
		combatState.EquipAt = 0
		table.clear(combatState.Tracks)
		table.clear(combatState.WallSide)
		combatState.SpawnRagdoll = getRagdollEndTime(localPlayer)

		for _, callback in ipairs(newLifeCallbacks) do
			pcall(callback)
		end
	end

	local lifeConnections = {
		localPlayer.CharacterRemoving:Connect(resetCombatOnNewLife),
		localPlayer.CharacterAdded:Connect(resetCombatOnNewLife),
	}

	registerCleanup(function()
		state.CombatDisposed = true

		for _, connection in ipairs(lifeConnections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
	end)
end

do
	local combat = state.Combat
	local targetModes = { "Nearest", "Egg Holders", "Specific Player" }
	local targetHoldRatio = 0.7
	local noPlayerLabel = "No other players"

	local autoHitState = {
		Handles = {},
		AuraHandle = nil,
		Row = nil,
		Picker = nil,
		TargetMode = targetModes[1],
		Picked = nil,
		LabelToName = {},
		Speed = 400,
		MaxSpeed = 750,
		Target = nil,
		Plan = nil,
		Moving = false,
		Status = "Idle",
		Shown = nil,
		NamesDirty = true,
	}

	local function getActiveMode()
		for index, mode in ipairs(targetModes) do
			if state.Toggle(autoHitState.Handles[index], false) then
				return mode
			end
		end

		return nil
	end

	local function isAuraOn()
		return state.Toggle(autoHitState.AuraHandle, false) == true
	end

	state.CombatActive = function()
		return getActiveMode() ~= nil or isAuraOn()
	end

	local function isTargetable(player)
		if not combat.Hittable(player) then
			return false
		end

		if autoHitState.TargetMode == targetModes[2] then
			return combat.IsHolder(player)
		end

		if autoHitState.TargetMode == targetModes[3] then
			return autoHitState.Picked ~= nil and player.Name == autoHitState.Picked
		end
		return true
	end

	local function pickTarget(referencePosition)
		local currentTarget = autoHitState.Target
		local currentDistance

		if currentTarget and isTargetable(currentTarget) then
			local _, currentRoot = combat.Parts(currentTarget)
			currentDistance = (currentRoot.Position - referencePosition).Magnitude
		else
			currentDistance = math.huge
			currentTarget = nil
		end

		local bestDistance = math.huge
		local bestTarget = nil

		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= currentTarget and isTargetable(player) and not combat.Ragdolled(player) then
				local _, root = combat.Parts(player)
				local distance = (root.Position - referencePosition).Magnitude

				if distance < bestDistance then
					bestDistance = distance
					bestTarget = player
				end
			end
		end

		if currentTarget then
			if bestTarget and not combat.Ragdolled(currentTarget) and bestDistance < currentDistance * targetHoldRatio then
				return bestTarget
			end
			return currentTarget
		end

		return bestTarget
	end

	local function findNearestInRange(referencePosition, maxDistance)
		local bestTarget = nil

		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")

				if root then
					local distance = (root.Position - referencePosition).Magnitude

					if distance < maxDistance and combat.Hittable(player) and not combat.Ragdolled(player) then
						maxDistance = distance
						bestTarget = player
					end
				end
			end
		end

		return bestTarget, maxDistance
	end

	local function stopCombat()
		autoHitState.Plan = nil

		if autoHitState.Moving then
			autoHitState.Moving = false
			state.EndFlight()
			state.GodMode(false)
			state.Shield("combat", false)
			combat.ResetWalls()
		end

		state.ReleaseMovement("combat")
	end

	combat.OnNewLife(function()
		autoHitState.AuraVictim = nil
		autoHitState.Target = nil
		autoHitState.Plan = nil
		pcall(stopCombat)
	end)

	local function isStealBlocking()
		local movement = state.Movement
		return state.Steal.Active
			or state.Steal.Carrying
			or (state.Steal.Wanted and state.Toggle(autoStealToggle, false))
			or (movement.Owner ~= nil and movement.Owner ~= "combat" and movement.Owner ~= "treadmill")
	end

	local function auraAttack(referenceRoot)
		local character = localPlayer.Character
		local range = combat.Range(character and combat.PickBat(character) or nil) + 6
		local victim, distance = findNearestInRange(referenceRoot.Position, range + 24)

		if not victim or distance > range then
			autoHitState.AuraVictim = nil

			if victim then
				combat.ReadyBat()
			end

			autoHitState.Status = "Aura ready, nobody in reach"
			return
		end

		autoHitState.AuraVictim = victim
		autoHitState.Status = combat.TryHit(victim, combat.Plan(victim, referenceRoot, nil, true)) or ("Aura on " .. victim.DisplayName)
	end

	local function combatTick()
		local activeMode = getActiveMode()

		if activeMode and activeMode ~= autoHitState.TargetMode then
			autoHitState.TargetMode = activeMode
			autoHitState.Target = nil
		end

		state.CombatWantsHolders = activeMode == targetModes[2]
		local auraOn = isAuraOn()
		local hasNoMode = not activeMode

		if hasNoMode then
			if autoHitState.Target or autoHitState.Moving then
				autoHitState.Target = nil
				stopCombat()
			end
		end

		if hasNoMode and not auraOn then
			autoHitState.Status = "Idle"
			return
		end

		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = combat.Humanoid(character)

		if not root or not humanoid or humanoid.Health <= 0 then
			autoHitState.Target = nil
			stopCombat()
			autoHitState.Status = "Waiting for your character"
			return
		end

		if hasNoMode then
			auraAttack(root)
			return
		end

		local target = pickTarget(root.Position)
		autoHitState.Target = target

		if not target then
			stopCombat()

			if auraOn then
				auraAttack(root)
				return
			end

			if activeMode == targetModes[2] then
				autoHitState.Status = "Waiting for someone to hold an egg"
			elseif activeMode == targetModes[3] then
				autoHitState.Status = "Picked player is not reachable"
			else
				autoHitState.Status = "No player to hit"
			end

			return
		end

		local plan = combat.Plan(target, root)
		local skipSelfRagdoll = activeMode ~= targetModes[2]

		if not isStealBlocking() and (skipSelfRagdoll or not combat.SelfRagdolled()) and state.ClaimMovement("combat") and not state.AntiGuard.Busy then
			if not autoHitState.Moving then
				autoHitState.Moving = true
				state.Shield("combat", true)
				state.GodMode(true)
				state.BeginFlight()
			end

			state.GodTick()
			autoHitState.Plan = plan
		else
			if autoHitState.Moving then
				stopCombat()
			end

			autoHitState.Plan = nil
		end

		local hitResult = combat.TryHit(target, plan, skipSelfRagdoll)
		local roundedDistance = plan and math.floor(plan.Distance + 0.5) or 0

		if hitResult then
			autoHitState.Status = hitResult .. string.format("  %d studs", roundedDistance)
		elseif isStealBlocking() then
			autoHitState.Status = string.format("Waiting for Auto Steal, near %s", target.DisplayName)
		else
			autoHitState.Status = string.format("Chasing %s  %d studs", target.DisplayName, roundedDistance)
		end
	end

	local function buildPlayerList()
		local players = {}

		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer then
				table.insert(players, player)
			end
		end

		table.sort(players, function(a, b)
			return string.lower(a.DisplayName) < string.lower(b.DisplayName)
		end)

		local nameCounts = {}

		for _, player in ipairs(players) do
			nameCounts[player.DisplayName] = (nameCounts[player.DisplayName] or 0) + 1
		end

		local labels = {}
		local labelToName = {}

		for _, player in ipairs(players) do
			local label = player.DisplayName

			if nameCounts[label] > 1 then
				label = string.format("%s (@%s)", player.DisplayName, player.Name)
			end

			table.insert(labels, label)
			labelToName[label] = player.Name
		end

		if #labels == 0 then
			labels[1] = noPlayerLabel
		end

		return labels, labelToName
	end

	local function findLabelForName(name)
		for label, playerName in pairs(autoHitState.LabelToName) do
			if playerName == name then
				return label
			end
		end

		return nil
	end

	local steerConnection = RunService.PreSimulation:Connect(function(deltaTime)
		local plan = autoHitState.Plan
		if not plan or not autoHitState.Moving then
			return
		end
		local root = state.Root()

		if root then
			combat.Steer(root, plan, autoHitState.Speed, math.max(autoHitState.Speed, autoHitState.MaxSpeed), deltaTime)
		end
	end)

	local auraTickInterval = 0.05
	local nextAuraAt = 0

	local heartbeatConnection = RunService.Heartbeat:Connect(function()
		local hasMode = getActiveMode() ~= nil
		local auraOn = isAuraOn()

		if not auraOn then
			autoHitState.AuraVictim = nil
		end

		local now = os.clock()

		if hasMode or not auraOn or now >= nextAuraAt then
			if auraOn and not hasMode then
				nextAuraAt = now + auraTickInterval
			end

			if not pcall(combatTick) then
				autoHitState.Status = "Retrying"
			end
		end

		if hasMode or (auraOn and autoHitState.AuraVictim ~= nil) then
			pcall(combat.Swing)
		end

		local row = autoHitState.Row

		if row and autoHitState.Shown ~= autoHitState.Status and type(row.Set) == "function" then
			autoHitState.Shown = autoHitState.Status
			pcall(row.Set, row, autoHitState.Status)
		end

		local picker = autoHitState.Picker

		if autoHitState.NamesDirty and picker and type(picker.SetOptions) == "function" then
			autoHitState.NamesDirty = false
			local labels, labelToName = buildPlayerList()
			autoHitState.LabelToName = labelToName
			pcall(picker.SetOptions, picker, labels, autoHitState.Picked and findLabelForName(autoHitState.Picked) or labels[1], false)
		end
	end)

	local playerAddedConnection = Players.PlayerAdded:Connect(function()
		autoHitState.NamesDirty = true
	end)

	local playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		autoHitState.NamesDirty = true

		if autoHitState.Target == player then
			autoHitState.Target = nil
		end
	end)

	registerCleanup(function()
		for _, connection in ipairs({ steerConnection, heartbeatConnection, playerAddedConnection, playerRemovingConnection }) do
			pcall(function()
				connection:Disconnect()
			end)
		end

		autoHitState.Target = nil
		stopCombat()
	end)

	local function handleInvisConflict(handle, label)
		if state.Toggle(handle, false) and state.Toggle(state.InvisibilityHandle, false) then
			state.UiDefer(function()
				pcall(handle.Set, handle, false, false)
				state.Notify(label, "Turn off Invisibility first, both cannot be on at the same time")
			end)

			return true
		end

		return false
	end

	autoHitState.Row = combatSection:CreateText({ Name = "Hit Status", Text = "Idle" })
	local exclusiveGroup = window:CreateExclusiveGroup({ Name = "NexHub Combat Targets", MaxActive = 1 })

	for index, toggleName in ipairs({ "Auto Hit Nearest Player", "Auto Hit Egg Holders", "Auto Hit Specific Player" }) do
		local handle = nil

		handle = combatSection:CreateToggle({
			Name = toggleName,
			Default = false,
			Callback = function()
				handleInvisConflict(handle, toggleName)
			end,
		})

		pcall(handle.JoinExclusiveGroup, handle, exclusiveGroup)
		autoHitState.Handles[index] = handle
	end

	local playerLabels, playerLabelToName = buildPlayerList()
	autoHitState.LabelToName = playerLabelToName

	autoHitState.Picker = combatSection:CreateDropdown({
		Name = "Hit Player",
		Options = playerLabels,
		Default = playerLabels[1],
		SubOf = autoHitState.Handles[3],
		Callback = function(selected)
			autoHitState.Picked = autoHitState.LabelToName[tostring(selected)]
			autoHitState.Target = nil
		end,
	})

	autoHitState.AuraHandle = combatSection:CreateToggle({
		Name = "Hit Aura",
		Default = false,
		Callback = function()
			handleInvisConflict(autoHitState.AuraHandle, "Hit Aura")
		end,
	})

	pcall(autoHitState.AuraHandle.JoinExclusiveGroup, autoHitState.AuraHandle, exclusiveGroup)
	local chaseLabel = combatSection:CreateLabel({ Name = "Chase Settings", Text = "Chase Settings" })

	combatSection:CreateSlider({
		Name = "Hit Tween Speed",
		SubOf = chaseLabel,
		Min = 100,
		Max = 1000,
		Default = 400,
		Increment = 10,
		Unit = "studs/s",
		Callback = function(value)
			autoHitState.Speed = math.clamp(tonumber(value) or 400, 100, 1000)
		end,
	})

	combatSection:CreateSlider({
		Name = "Hit Max Speed",
		SubOf = chaseLabel,
		Min = 100,
		Max = 1000,
		Default = 750,
		Increment = 10,
		Unit = "studs/s",
		Callback = function(value)
			autoHitState.MaxSpeed = math.clamp(tonumber(value) or 750, 100, 1000)
		end,
	})

	combatSection:CreateSlider({
		Name = "Hit Lead",
		SubOf = chaseLabel,
		Note = "Stand further ahead of the target (+) or closer to them (-)",
		Min = -400,
		Max = 100,
		Default = -275,
		Increment = 1,
		Callback = function(value)
			combat.SetLead(value)
		end,
	})

	combatSection:CreateSlider({
		Name = "Hit Sweep",
		SubOf = chaseLabel,
		Note = "How far you move back and forth in front of the target",
		Min = 0,
		Max = 250,
		Default = 60,
		Increment = 1,
		Unit = "%",
		Callback = function(value)
			combat.SetSweep(value)
		end,
	})
end

;(function()
local espHelpers = {}
state.EspHelpers = espHelpers

do
	local function loadFont(path, weight)
		local ok, result = pcall(Font.new, path, weight, Enum.FontStyle.Normal)
		return ok and result or nil
	end

	espHelpers.MainFont = loadFont("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold)
	espHelpers.StatusFont = loadFont("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
	espHelpers.RarityFont = loadFont("rbxassetid://12187365977", Enum.FontWeight.Bold) or loadFont("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)

	espHelpers.Sequence = function(points)
		local keypoints = table.create(#points)

		for i, point in ipairs(points) do
			keypoints[i] = ColorSequenceKeypoint.new(point[1], point[2])
		end

		return ColorSequence.new(keypoints)
	end

	local palettes = {}
	espHelpers.Palettes = palettes

	do
		local gold = {}
		local points = {
			{ 0, Color3.fromRGB(255, 231, 158) },
			{ 0.4, Color3.fromRGB(255, 196, 66) },
			{ 1, Color3.fromRGB(214, 142, 12) },
		}
		gold.Text = espHelpers.Sequence(points)
		local strokePoints = {
			{ 0, Color3.fromRGB(122, 76, 0) },
			{ 0.55, Color3.fromRGB(62, 38, 0) },
			{ 1, Color3.fromRGB(20, 12, 0) },
		}
		gold.Stroke = espHelpers.Sequence(strokePoints)
		gold.Outline = Color3.fromRGB(255, 232, 152)
		palettes.Gold = gold
	end

	do
		local orange = {}
		local points = {
			{ 0, Color3.fromRGB(255, 198, 132) },
			{ 0.4, Color3.fromRGB(255, 146, 40) },
			{ 1, Color3.fromRGB(206, 92, 0) },
		}
		orange.Text = espHelpers.Sequence(points)
		local strokePoints = {
			{ 0, Color3.fromRGB(112, 54, 0) },
			{ 0.55, Color3.fromRGB(56, 27, 0) },
			{ 1, Color3.fromRGB(18, 8, 0) },
		}
		orange.Stroke = espHelpers.Sequence(strokePoints)
		orange.Outline = Color3.fromRGB(255, 194, 112)
		palettes.Orange = orange
	end

	do
		local red = {}
		local points = {
			{ 0, Color3.fromRGB(255, 105, 105) },
			{ 0.4, Color3.fromRGB(255, 28, 40) },
			{ 1, Color3.fromRGB(184, 0, 18) },
		}
		red.Text = espHelpers.Sequence(points)
		local strokePoints = {
			{ 0, Color3.fromRGB(124, 0, 15) },
			{ 0.55, Color3.fromRGB(61, 0, 9) },
			{ 1, Color3.fromRGB(18, 0, 3) },
		}
		red.Stroke = espHelpers.Sequence(strokePoints)
		red.Outline = Color3.fromRGB(255, 128, 138)
		palettes.Red = red
	end

	do
		local accent = {}
		local points = {
			{ 0, Color3.fromRGB(170, 255, 160) },
			{ 0.45, Color3.fromRGB(58, 255, 55) },
			{ 1, Color3.fromRGB(20, 109, 0) },
		}
		accent.Text = espHelpers.Sequence(points)
		local strokePoints = {
			{ 0, Color3.fromRGB(10, 52, 6) },
			{ 1, Color3.fromRGB(3, 16, 0) },
		}
		accent.Stroke = espHelpers.Sequence(strokePoints)
		accent.Outline = Color3.fromRGB(58, 255, 55)
		palettes.Accent = accent
	end

	do
		local sheen = {}
		local points = {
			{ 0, Color3.fromRGB(255, 255, 255) },
			{ 0.5, Color3.fromRGB(222, 222, 222) },
			{ 1, Color3.fromRGB(255, 255, 255) },
		}
		sheen.Text = espHelpers.Sequence(points)
		local strokePoints = {
			{ 0, Color3.fromRGB(8, 8, 8) },
			{ 1, Color3.fromRGB(8, 8, 8) },
		}
		sheen.Stroke = espHelpers.Sequence(strokePoints)
		sheen.Outline = Color3.fromRGB(255, 255, 255)
		palettes.Sheen = sheen
	end

	espHelpers.PaletteFromColor = function(color)
		local white = Color3.new(1, 1, 1)
		local black = Color3.new(0, 0, 0)
		local palette = {}
		local textPoints = {
			{ 0, color:Lerp(white, 0.5) },
			{ 0.4, color:Lerp(white, 0.1) },
			{ 1, color:Lerp(black, 0.25) },
		}
		palette.Text = espHelpers.Sequence(textPoints)
		local strokePoints = {
			{ 0, color:Lerp(black, 0.55) },
			{ 0.55, color:Lerp(black, 0.75) },
			{ 1, color:Lerp(black, 0.92) },
		}
		palette.Stroke = espHelpers.Sequence(strokePoints)
		palette.Outline = color:Lerp(white, 0.25)
		return palette
	end

	espHelpers.SizeScale = 1
	local sizeCallbacks = {}

	espHelpers.OnSizeChanged = function(callback)
		table.insert(sizeCallbacks, callback)
	end

	espHelpers.SetSizeScale = function(scale)
		if espHelpers.SizeScale == scale then
			return
		end
		espHelpers.SizeScale = scale

		for _, callback in ipairs(sizeCallbacks) do
			pcall(callback)
		end
	end

	espHelpers.RowHeight = function(scale)
		local camera = workspace.CurrentCamera
		local base = camera and camera.ViewportSize.Y or 1080
		return math.max(8, math.floor(math.clamp(base * 0.018, 16, 24) * (scale or espHelpers.SizeScale)))
	end

	espHelpers.ScaledWidth = function(width, scale)
		return math.max(30, math.floor(width * (scale or espHelpers.SizeScale)))
	end

	local function resolveEspGuiParent()
		local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			return playerGui
		end
		local ok, result = pcall(function()
			return localPlayer:WaitForChild("PlayerGui", 3)
		end)
		if ok and result then
			return result
		end
		return guiParent or CoreGui
	end

	espHelpers.CreateRuntime = function()
		local parent = resolveEspGuiParent()
		local gui = Instance.new("ScreenGui")
		gui.Name = randomId()
		gui.Archivable = false
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.DisplayOrder = 48
		gui.Parent = parent
		return gui
	end

	espHelpers.CreateTag = function(parent, maxDistance)
		local billboard = Instance.new("BillboardGui")
		billboard.Name = randomId()
		billboard.AlwaysOnTop = true
		billboard.LightInfluence = 0
		billboard.MaxDistance = maxDistance
		local frame = Instance.new("Frame")
		frame.Name = randomId()
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = billboard
		local listLayout = Instance.new("UIListLayout")
		listLayout.Name = randomId()
		listLayout.FillDirection = Enum.FillDirection.Vertical
		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Parent = frame
		billboard.Parent = parent
		return billboard, frame
	end

	espHelpers.CreateTextRow = function(parent, fontFace, layoutOrder, heightScale)
		local row = Instance.new("Frame")
		row.Name = randomId()
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Size = UDim2.fromScale(1, heightScale)
		row.LayoutOrder = layoutOrder
		row.Parent = parent

		local function makeLabel(zIndex)
			local label = Instance.new("TextLabel")
			label.Name = randomId()
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Text = ""
			label.TextScaled = true
			label.TextStrokeTransparency = 1
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextYAlignment = Enum.TextYAlignment.Center
			label.ZIndex = zIndex

			if fontFace then
				label.FontFace = fontFace
			else
				label.Font = Enum.Font.GothamBold
			end

			label.Parent = row
			return label
		end

		local shadow = makeLabel(2)
		shadow.Position = UDim2.fromOffset(1, 1)
		shadow.TextColor3 = Color3.new(0, 0, 0)
		shadow.TextTransparency = 0.1
		local label = makeLabel(3)
		label.TextColor3 = Color3.new(1, 1, 1)
		local stroke = Instance.new("UIStroke")
		stroke.Name = randomId()
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Transparency = 0.05

		stroke.Thickness = pcall(function()
			stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		end) and 0.05 or 1.2

		stroke.Parent = label
		local strokeGradient = Instance.new("UIGradient")
		strokeGradient.Name = randomId()
		strokeGradient.Rotation = 90
		strokeGradient.Parent = stroke
		local textGradient = Instance.new("UIGradient")
		textGradient.Name = randomId()
		textGradient.Rotation = 90
		textGradient.Parent = label
		return {
			Holder = row,
			Shadow = shadow,
			Label = label,
			StrokeGradient = strokeGradient,
			TextGradient = textGradient,
			Palette = nil,
		}
	end

	espHelpers.SetRow = function(row, text, palette)
		if row.Label.Text ~= text then
			row.Label.Text = text
			row.Shadow.Text = text
		end

		if palette and row.Palette ~= palette then
			row.Palette = palette
			if palette.Text then
				row.TextGradient.Color = palette.Text
			end
			row.TextGradient.Rotation = palette.Rotation or 90
			if palette.Stroke then
				row.StrokeGradient.Color = palette.Stroke
			end
		end
	end

	espHelpers.ReadToggle = function(handle, fallback)
		if type(handle) == "table" and type(handle.Value) == "boolean" then
			return handle.Value
		end
		if type(state.Toggle) == "function" then
			return state.Toggle(handle, fallback)
		end
		if type(handle) ~= "table" then
			return fallback == true
		end

		local ok, result = pcall(function()
			local controller = handle._controller
			return type(controller) == "table" and type(controller.GetValue) == "function" and controller.GetValue()
		end)

		if ok and type(result) == "boolean" then
			return result
		end

		for _, methodName in ipairs({ "Get", "GetValue" }) do
			local ok2, methodFn = pcall(function()
				return handle[methodName]
			end)

			if ok2 and type(methodFn) == "function" then
				local ok3, result3 = pcall(methodFn, handle)
				if ok3 and type(result3) == "boolean" then
					return result3
				end
			end
		end

		return fallback == true
	end

	espHelpers.SyncSoon = function(callback)
		callback()
		task.delay(0.35, callback)
	end

	espHelpers.GetGuardAreas = function()
		local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
		local areas = world and world:FindFirstChild("Areas") or workspace:FindFirstChild("Areas")
		local guardAreas = areas and areas:FindFirstChild("GuardAreas")
		if guardAreas then
			return guardAreas
		end
		return workspace:FindFirstChild("GuardAreas", true)
	end

	espHelpers.FindGuardRoot = function(guard)
		if not guard or not guard:IsA("Model") then
			return nil
		end
		local root = guard:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return root
		end

		if guard.PrimaryPart then
			return guard.PrimaryPart
		end
		return guard:FindFirstChildWhichIsA("BasePart", true)
	end

	espHelpers.WatchGuards = function(callback)
		local connections = {}
		local watchedGuards = {}

		local function checkGuard(areaName, guard)
			if guard and guard:IsA("Model") and not watchedGuards[guard] then
				watchedGuards[guard] = true
				callback(areaName, guard)
			end
		end

		local function watchArea(area)
			if not area then
				return
			end
			local guard = area:FindFirstChild("Guard")
			if guard and guard:IsA("Model") then
				checkGuard(area.Name, guard)
			end

			table.insert(connections, area.ChildAdded:Connect(function(child)
				if child.Name == "Guard" and child:IsA("Model") then
					checkGuard(area.Name, child)
				end
			end))
		end

		local guardAreas = espHelpers.GetGuardAreas()
		if guardAreas then
			for _, child in ipairs(guardAreas:GetChildren()) do
				watchArea(child)
			end
			table.insert(connections, guardAreas.ChildAdded:Connect(watchArea))
		end

		local scanThread = task.spawn(function()
			while true do
				task.wait(2)
				local ga = espHelpers.GetGuardAreas()
				if ga then
					for _, child in ipairs(ga:GetChildren()) do
						local g = child:FindFirstChild("Guard")
						if g and g:IsA("Model") then
							checkGuard(child.Name, g)
						end
					end
				end
			end
		end)
		table.insert(connections, {
			Disconnect = function()
				pcall(task.cancel, scanThread)
			end,
		})

		return connections
	end

	espHelpers.DisconnectAll = function(connections)
		for _, connection in ipairs(connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end

		table.clear(connections)
	end
end

local espHighlightMax = 18
local espInfoFieldOptions = {
	"Icon",
	"Name",
	"Rarity",
	"Mutation",
	"Value",
	"Weight",
	"Size",
	"Sell Price",
	"Distance",
	"Area",
	"State",
}

local espInfoDefaults = { "Icon", "Name", "Value" }
local espHighlightModes = { "Off", "Rare Only", "All Shown" }
local espRowHeights = { Icon = 4.2, Name = 1.35, Rarity = 1.2, Mutation = 1, Value = 1.1, Info = 1 }

local espRarityFont
do
	local ok, result = pcall(Font.new, "rbxassetid://12187365977", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	espRarityFont = ok and result or espHelpers.StatusFont
end

local espSecretGradient
do
	local points = {
		{ 0, Color3.fromRGB(255, 255, 255) },
		{ 0.2, Color3.fromRGB(206, 212, 224) },
		{ 0.42, Color3.fromRGB(74, 80, 94) },
		{ 0.58, Color3.fromRGB(42, 46, 56) },
		{ 0.78, Color3.fromRGB(158, 166, 182) },
		{ 1, Color3.fromRGB(250, 252, 255) },
	}
	espSecretGradient = espHelpers.Sequence(points)
end

local espValuePalette = espHelpers.PaletteFromColor(Color3.fromRGB(77, 255, 122))

local espWhitePalette = {}
do
	local points = {
		{ 0, Color3.fromRGB(255, 255, 255) },
		{ 0.5, Color3.fromRGB(222, 238, 255) },
		{ 1, Color3.fromRGB(255, 255, 255) },
	}
	espWhitePalette.Text = espHelpers.Sequence(points)
end

do
	local strokePoints = {
		{ 0, Color3.fromRGB(8, 8, 8) },
		{ 1, Color3.fromRGB(8, 8, 8) },
	}
	espWhitePalette.Stroke = espHelpers.Sequence(strokePoints)
end

espWhitePalette.Outline = Color3.fromRGB(255, 255, 255)

local espIconOffset = 0.8
local espFixedSize = 4.5
local espDistanceScale = 20
local espRefreshGap = 0.002

local espMutationPalettes = { Golden = espHelpers.Palettes.Gold }
do
	local silver = {}
	local points = {
		{ 0, Color3.fromRGB(255, 255, 255) },
		{ 0.45, Color3.fromRGB(214, 222, 232) },
		{ 1, Color3.fromRGB(150, 160, 175) },
	}
	silver.Text = espHelpers.Sequence(points)
	local strokePoints = {
		{ 0, Color3.fromRGB(60, 66, 78) },
		{ 0.55, Color3.fromRGB(30, 33, 40) },
		{ 1, Color3.fromRGB(10, 11, 14) },
	}
	silver.Stroke = espHelpers.Sequence(strokePoints)
	silver.Outline = Color3.fromRGB(214, 222, 232)
	espMutationPalettes.Silver = silver
end

espMutationPalettes.Sakura = espHelpers.PaletteFromColor(Color3.fromRGB(255, 158, 216))
espMutationPalettes.GreatBloom = espHelpers.PaletteFromColor(Color3.fromRGB(124, 255, 196))
espMutationPalettes.Boss = espHelpers.PaletteFromColor(Color3.fromRGB(255, 122, 122))
espMutationPalettes.Monstrous = espHelpers.PaletteFromColor(Color3.fromRGB(192, 139, 255))

do
	local rainbow = {}
	local points = {
		{ 0, Color3.fromRGB(255, 107, 107) },
		{ 0.2, Color3.fromRGB(255, 179, 107) },
		{ 0.4, Color3.fromRGB(255, 240, 107) },
		{ 0.6, Color3.fromRGB(107, 255, 138) },
		{ 0.8, Color3.fromRGB(107, 200, 255) },
		{ 1, Color3.fromRGB(185, 107, 255) },
	}
	rainbow.Text = espHelpers.Sequence(points)
	local strokePoints = {
		{ 0, Color3.fromRGB(20, 20, 30) },
		{ 1, Color3.fromRGB(8, 8, 12) },
	}
	rainbow.Stroke = espHelpers.Sequence(strokePoints)
	rainbow.Outline = Color3.fromRGB(255, 255, 255)
	rainbow.Rotation = 0
	espMutationPalettes.Rainbow = rainbow
end

local espDefaultMutationPalette = espHelpers.PaletteFromColor(Color3.fromRGB(143, 227, 255))

local askFieldEggSnapshotRemote = networking:FindFirstChild("RF/EggWorld/AskFieldEggSnapshot")
local snapshotFallbackAt = 0

local eggEspConfig = {
	Eggs = false,
	MinRarity = 5,
	Specific = {},
	MutationSet = {},
	AnyMutation = false,
	NoMutation = false,
	Info = {},
	Highlight = espHighlightModes[1],
	MinValue = 0,
	HighlightMin = 6,
	MaxDistance = math.huge,
	SizeScale = 0.75,
	FixedSize = false,
	OwnBase = true,
}

for _, fieldName in ipairs(espInfoDefaults) do
	eggEspConfig.Info[fieldName] = true
end

local activeEggRows = {}
local eggEspConnections = {}
local eggRecordsCache = nil
local eggEspRunning = false
local eggEspGeneration = 0
local eggEspRenderVersion = 0
local eggSnapshotBusy = false
local eggEspRuntime = nil
local eggHighlightCount = 0
local eggAssetInfoCache = {}
local onEggEspResize = nil
local scheduleEggRender = nil
local resizeEggRows = nil
local eggEspUiHandles = nil
local parseEspMultiSelection = nil

local function getEggAssetInfo(category)
	local cached = eggAssetInfoCache[category]
	if cached then
		return cached
	end
	local directory = modules.Assets and modules.Assets.Directory
	local assetEntry = type(directory) == "table" and directory[category]
	local rarity = type(assetEntry) == "table" and type(assetEntry.Rarity) == "table" and assetEntry.Rarity or nil
	local color = rarity and typeof(rarity.Color) == "Color3" and rarity.Color or Color3.new(1, 1, 1)
	local palette = espHelpers.PaletteFromColor(color)
	local rarityGradient = rarity and rarity.RarityGradient

	if rarity and typeof(rarityGradient) ~= "Instance" then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		assets = assets and assets:FindFirstChild("UI")
		assets = assets and assets:FindFirstChild("RarityGradients")

		if assets then
			assets = assets:FindFirstChild(tostring(rarity._id or rarity.DisplayName or ""))
		end

		rarityGradient = assets and assets:FindFirstChild("RarityGradient") or nil
	end

	if typeof(rarityGradient) == "Instance" and rarityGradient:IsA("UIGradient") then
		palette.Text = rarityGradient.Color
		palette.Rotation = rarityGradient.Rotation
	end

	local rarityName
	if rarity then
		rarityName = tostring(rarity.DisplayName or rarity._id or "")
	else
		rarityName = rarity
	end
	rarityName = rarityName or ""

	local rarityPalette
	if string.upper(rarityName) ~= "SECRET" then
		rarityPalette = palette
	else
		rarityPalette = { Text = espSecretGradient, Stroke = palette.Stroke, Outline = palette.Outline, Rotation = 90 }
	end

	local info = {}
	local rarityNumber
	if rarity then
		rarityNumber = tonumber(rarity.RarityNumber or rarity.Rank)
	else
		rarityNumber = rarity
	end

	info.Number = rarityNumber or 0
	info.Name = rarityName
	info.Color = color
	info.Palette = palette
	info.RarityPalette = rarityPalette

	local displayName
	if type(assetEntry) == "table" then
		displayName = tostring(assetEntry.DisplayName or category)
	end
	info.DisplayName = displayName or tostring(category)
	info.Icon = type(assetEntry) == "table" and assetEntry.Icon or nil
	info.EarningRate = type(assetEntry) == "table" and tonumber(assetEntry.EarningRate) or 0
	eggAssetInfoCache[category] = info
	return info
end

local findEggSlot
local ensureEggRuntime

do
	local function findAreaEggSlot(uid)
		local container = workspace:FindFirstChild("AreaEggSlotsClient")
		container = container and container:FindFirstChild(uid)

		if container and container:IsA("Model") then
			local hitbox = container:FindFirstChild("Hitbox")
			return container, hitbox and hitbox:IsA("BasePart") and hitbox or nil
		end

		return nil, nil
	end

	findEggSlot = findAreaEggSlot

	ensureEggRuntime = function()
		if not eggEspRuntime or not eggEspRuntime.Parent then
			eggEspRuntime = espHelpers.CreateRuntime()
		end
	end

	local function formatCompact(value)
		local number = tonumber(value) or 0
		local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
		local index = 1

		while math.abs(number) >= 1000 and index < #suffixes do
			number = number / 1000
			index = index + 1
		end

		return string.format(index == 1 and "%.0f%s" or "%.2f%s", number, suffixes[index])
	end

	local function computeMaxDistance(worldSize)
		return eggEspConfig.MaxDistance
	end

	local function layoutEggRows(row)
		local parts = {
			{ row.IconHolder, espRowHeights.Icon, row.ShowIcon },
			{ row.NameRow.Holder, espRowHeights.Name, row.ShowName },
			{ row.RarityRow.Holder, espRowHeights.Rarity, row.ShowRarity },
			{ row.MutationRow.Holder, espRowHeights.Mutation, row.ShowMutation },
			{ row.ValueRow.Holder, espRowHeights.Value, row.ShowValue },
			{ row.ExtraRow.Holder, espRowHeights.Info, row.ShowExtra },
		}

		local totalWeight = 0

		for _, part in ipairs(parts) do
			if part[3] then
				totalWeight = totalWeight + part[2]
			end
		end

		local safeTotal = math.max(totalWeight, 1)

		for _, part in ipairs(parts) do
			part[1].Visible = part[3]
			part[1].Size = UDim2.fromScale(1, part[3] and part[2] / safeTotal or 0)
		end

		local width = espHelpers.ScaledWidth(160, eggEspConfig.SizeScale)
		local height = math.max(1, math.floor(espHelpers.RowHeight(eggEspConfig.SizeScale) * safeTotal))

		if row.Width ~= width or row.Height ~= height or row.Fixed ~= eggEspConfig.FixedSize then
			row.Width = width
			row.Height = height
			row.Fixed = eggEspConfig.FixedSize

			row.Billboard.MaxDistance = eggEspConfig.MaxDistance

			if eggEspConfig.FixedSize then
				row.Billboard.Size = UDim2.fromOffset(width, height)
			else
				local dynScale = (espFixedSize * 0.25) * eggEspConfig.SizeScale
				local minW = math.floor(width * 0.8)
				local minH = math.floor(height * 0.8)
				row.Billboard.Size = UDim2.new(dynScale, minW, dynScale * height / width, minH)
			end
		end
	end

	onEggEspResize = function(row)
		row.Width = nil
		layoutEggRows(row)
	end

	local function createEggRow()
		local billboard, frame = espHelpers.CreateTag(eggEspRuntime, eggEspConfig.MaxDistance)

		local iconHolder = Instance.new("Frame")
		iconHolder.Name = randomId()
		iconHolder.BackgroundTransparency = 1
		iconHolder.BorderSizePixel = 0
		iconHolder.LayoutOrder = 0
		iconHolder.Parent = frame

		local icon = Instance.new("ImageLabel")
		icon.Name = randomId()
		icon.AnchorPoint = Vector2.new(0.5, 1)
		icon.BackgroundTransparency = 1
		icon.Position = UDim2.fromScale(0.5, 1)
		icon.Size = UDim2.fromScale(1, 1)
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = iconHolder

		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Name = randomId()
		aspect.AspectRatio = 1
		aspect.DominantAxis = Enum.DominantAxis.Height
		aspect.Parent = icon

		local row = {
			Billboard = billboard,
			IconHolder = iconHolder,
			Icon = icon,
			NameRow = espHelpers.CreateTextRow(frame, espHelpers.MainFont, 1, 0.4),
			RarityRow = espHelpers.CreateTextRow(frame, espRarityFont, 2, 0.2),
			MutationRow = espHelpers.CreateTextRow(frame, espHelpers.MainFont, 3, 0.2),
			ValueRow = espHelpers.CreateTextRow(frame, espHelpers.MainFont, 4, 0.2),
			ExtraRow = espHelpers.CreateTextRow(frame, espHelpers.MainFont, 5, 0.2),
			Highlight = nil,
			Anchor = nil,
			CFrame = nil,
			Width = nil,
			Height = nil,
			ShowIcon = false,
			ShowName = true,
			ShowRarity = false,
			ShowMutation = false,
			ShowValue = false,
			ShowExtra = false,
		}

		layoutEggRows(row)
		return row
	end

	local function destroyRowHighlight(row)
		if row.Highlight then
			row.Highlight:Destroy()
			row.Highlight = nil
			eggHighlightCount = eggHighlightCount - 1
		end
	end

	local function computeEggIncome(record, info)
		local scale = tonumber(record.AssetScale) or 1
		local scaleFactor = scale > 5 and (scale / 5) ^ 1.2 * 19.637875755794113 or scale ^ 1.85
		local mutationsModule = modules.Mutations
		local hasEarningsFor = type(mutationsModule) == "table" and type(mutationsModule.EarningsFor) == "function"
		local mutationMultiplier = 1

		if hasEarningsFor then
			local ok, result = pcall(mutationsModule.EarningsFor, type(record.Mutations) == "table" and record.Mutations or {})
			mutationMultiplier = ok and type(result) == "number" and result or 1
		end

		return info.EarningRate * scaleFactor * mutationMultiplier
	end

	local function collectBaseEggs()
		local baseList = {}
		local eggState = modules.EggState
		if type(eggState) ~= "table" or type(eggState.ReadOwnerEggs) ~= "function" then
			local client = ReplicatedStorage:FindFirstChild("Client")
			local es = client and client:FindFirstChild("EggState")
			if es and es:IsA("ModuleScript") then
				local okMod, resMod = pcall(require, es)
				if okMod and type(resMod) == "table" then
					modules.EggState = resMod
					eggState = resMod
				end
			end
		end

		if type(eggState) ~= "table" or type(eggState.ReadOwnerEggs) ~= "function" then
			return baseList
		end

		local ok, result = pcall(eggState.ReadOwnerEggs, localPlayer.UserId)
		if not ok or type(result) ~= "table" then
			ok, result = pcall(eggState.ReadOwnerEggs)
		end
		if not ok or type(result) ~= "table" then
			return baseList
		end

		local userIdStr = tostring(localPlayer.UserId)
		local userName = localPlayer.Name

		local containers = {}
		local function addContainer(inst)
			if inst and typeof(inst) == "Instance" and not table.find(containers, inst) then
				table.insert(containers, inst)
			end
		end

		addContainer(workspace:FindFirstChild("PlacedEggRenders"))
		addContainer(workspace:FindFirstChild("PlacedEggRenders", true))
		addContainer(workspace:FindFirstChild("PlacedEggs"))
		addContainer(workspace:FindFirstChild("PlacedEggs", true))
		addContainer(workspace:FindFirstChild("EggRenders"))
		addContainer(workspace:FindFirstChild("EggsClient"))

		local ownPlot = type(state.OwnPlot) == "function" and state.OwnPlot() or nil
		if ownPlot then
			addContainer(ownPlot)
			addContainer(ownPlot:FindFirstChild("PlacedEggRenders", true))
			addContainer(ownPlot:FindFirstChild("PlacedEggs", true))
			addContainer(ownPlot:FindFirstChild("Eggs", true))
			addContainer(ownPlot:FindFirstChild("ToUpdate", true))
		end

		local candidates = {}
		local checkedCandidate = {}

		local function addCandidate(inst)
			if inst and typeof(inst) == "Instance" and not checkedCandidate[inst] then
				checkedCandidate[inst] = true
				table.insert(candidates, inst)
			end
		end

		for _, container in ipairs(containers) do
			local playerFolder = container:FindFirstChild(userIdStr) or container:FindFirstChild(userName)
			if playerFolder then
				for _, child in ipairs(playerFolder:GetChildren()) do
					addCandidate(child)
				end
			end

			for _, child in ipairs(container:GetChildren()) do
				if child ~= ownPlot and child ~= playerFolder then
					addCandidate(child)
				end
			end
		end

		local starterPen = nil
		local penCFrame = nil
		if ownPlot then
			local toUpdate = ownPlot:FindFirstChild("ToUpdate")
			starterPen = (toUpdate and toUpdate:FindFirstChild("StarterPen"))
				or ownPlot:FindFirstChild("CenterPoint")
				or ownPlot:FindFirstChild("StarterPen", true)
			if starterPen then
				local okPivot, pivot = pcall(function()
					return starterPen:IsA("Model") and starterPen:GetPivot() or starterPen.CFrame
				end)
				if okPivot and typeof(pivot) == "CFrame" then
					penCFrame = pivot
				end
			end
			if not penCFrame then
				local okPlotPivot, plotPivot = pcall(function()
					return ownPlot:IsA("Model") and ownPlot:GetPivot() or ownPlot.CFrame
				end)
				if okPlotPivot and typeof(plotPivot) == "CFrame" then
					penCFrame = plotPivot
				end
			end
		end

		if not penCFrame and type(state.PenAnchor) == "function" then
			local okAnchor, anchorPos = pcall(state.PenAnchor)
			if okAnchor and typeof(anchorPos) == "Vector3" then
				penCFrame = CFrame.new(anchorPos)
			end
		end

		local defaultAnchorPart = (starterPen and (starterPen:IsA("BasePart") and starterPen or starterPen.PrimaryPart or starterPen:FindFirstChildWhichIsA("BasePart", true)))
			or (ownPlot and ownPlot:FindFirstChildWhichIsA("BasePart", true))
			or workspace:FindFirstChildOfClass("Terrain")
			or workspace.Terrain

		for key, entry in pairs(result) do
			if type(entry) == "table" and entry.Placement ~= nil then
				local base = tostring(key)
				local category = entry.AssetCategory or entry.Category or entry.EggType or entry.Type or "Basic"
				local matched = nil

				for _, candidate in ipairs(candidates) do
					local candUid = candidate:GetAttribute("Uid") or candidate:GetAttribute("EggUid") or candidate:GetAttribute("Id") or candidate:GetAttribute("Key")
					if candidate.Name == base
						or tostring(candUid) == base
						or candidate.Name == "base:" .. base
						or candidate.Name == "egg_" .. base
						or string.find(candidate.Name, base, 1, true)
					then
						matched = candidate
						break
					end
				end

				if not matched then
					for _, container in ipairs(containers) do
						local found = container:FindFirstChild(base, true)
						if found and (found:IsA("Model") or found:IsA("BasePart")) then
							matched = found
							break
						end
					end
				end

				local eggCFrame = nil
				if matched then
					local okPivot, pivot = pcall(function()
						return matched:IsA("Model") and matched:GetPivot() or matched.CFrame
					end)
					if okPivot and typeof(pivot) == "CFrame" then
						eggCFrame = pivot
					end
				end

				local placement = entry.Placement
				local localCFrame = type(placement) == "table" and placement.LocalCFrame or nil

				if not eggCFrame and typeof(localCFrame) == "CFrame" and penCFrame then
					eggCFrame = penCFrame * localCFrame
				elseif not eggCFrame and type(placement) == "table" and typeof(placement.CFrame) == "CFrame" then
					eggCFrame = placement.CFrame
				elseif not eggCFrame and type(placement) == "table" and typeof(placement.Position) == "Vector3" then
					eggCFrame = CFrame.new(placement.Position)
				elseif not eggCFrame and penCFrame then
					eggCFrame = penCFrame
				end

				local modelInstance = matched or defaultAnchorPart
				local mutations = type(entry.Mutations) == "table" and entry.Mutations or {}

				baseList[#baseList + 1] = {
					Uid = "base:" .. base,
					AssetCategory = category,
					AssetScale = entry.AssetScale or 1,
					Mutations = mutations,
					BaseMutation = entry.BaseMutation or mutations[1],
					State = "Base",
					AreaId = "Your Base",
					BottomCFrame = eggCFrame,
					Model = modelInstance,
					RealModel = matched,
				}
			end
		end

		return baseList
	end

	local function passesEggFilter(record, info)
		if record.State == "Claimed" then
			return false
		end

		local isBaseEgg = record.State == "Base"

		if not isBaseEgg and eggEspConfig.MinRarity > 0 and info.Number < eggEspConfig.MinRarity then
			return false
		end

		local failsValue = eggEspConfig.MinValue > 0

		if failsValue then
			local minValue = eggEspConfig.MinValue
			failsValue = computeEggIncome(record, info) < minValue
		end

		if failsValue then
			return false
		end

		return true
	end

	local function renderEggRow(row, record, info, model)
		local resolvedModel, hitbox

		if typeof(record.Model) == "Instance" then
			resolvedModel = record.Model
			hitbox = resolvedModel:FindFirstChild("Hitbox", true) or resolvedModel:FindFirstChildWhichIsA("BasePart", true)
			hitbox = hitbox and hitbox:IsA("BasePart") and hitbox or (resolvedModel:IsA("BasePart") and resolvedModel or nil)
		else
			resolvedModel, hitbox = findEggSlot(record.Uid)
		end

		local bottomCFrame = record.BottomCFrame
		local terrain = workspace:FindFirstChildOfClass("Terrain") or workspace.Terrain
		local anchorPart = hitbox
			or (resolvedModel and (resolvedModel:IsA("BasePart") and resolvedModel or resolvedModel.PrimaryPart or resolvedModel:FindFirstChildWhichIsA("BasePart", true)))
			or terrain

		if anchorPart then
			if row.Anchor ~= anchorPart or (bottomCFrame and row.CFrame ~= bottomCFrame) then
				row.Anchor = anchorPart
				row.CFrame = bottomCFrame
				row.Billboard.Adornee = anchorPart

				if typeof(bottomCFrame) == "CFrame" then
					local hitboxLift = hitbox and hitbox.Position.Y - bottomCFrame.Position.Y or 1
					row.Billboard.StudsOffsetWorldSpace = bottomCFrame.Position - anchorPart.Position + Vector3.new(0, hitboxLift + espIconOffset, 0)
				else
					row.Billboard.StudsOffsetWorldSpace = Vector3.new(0, 2 + espIconOffset, 0)
				end
			end
		end

		local info_ = eggEspConfig.Info
		local baseMutation = record.BaseMutation
		local showMutation = type(baseMutation) == "string" and baseMutation ~= ""
		local scale = tonumber(record.AssetScale) or 1
		local showIcon = info_.Icon == true and info.Icon ~= nil

		if showIcon and row.Icon.Image ~= tostring(info.Icon) then
			row.Icon.Image = tostring(info.Icon)
		end

		local showName = info_.Name == true

		if showName then
			espHelpers.SetRow(row.NameRow, info.DisplayName, info.Palette or espWhitePalette)
		end

		local showRarity = info_.Rarity == true and info.Name ~= ""

		if showRarity then
			espHelpers.SetRow(row.RarityRow, string.upper(info.Name), info.RarityPalette)
		end

		showMutation = info_.Mutation == true and showMutation

		if showMutation then
			espHelpers.SetRow(row.MutationRow, string.upper(mutationLabel(baseMutation)), espMutationPalettes[baseMutation] or espDefaultMutationPalette)
		end

		local showValue = info_.Value == true

		if showValue then
			espHelpers.SetRow(row.ValueRow, "$" .. formatCompact(computeEggIncome(record, info)) .. "/s", espValuePalette)
		end

		local extraParts = {}
		local eggRecords = modules.EggRecords

		if info_.Weight and type(eggRecords) == "table" and type(eggRecords.WeightKgForScale) == "function" then
			local ok, result = pcall(eggRecords.WeightKgForScale, record.AssetCategory, scale)

			if ok and tonumber(result) then
				table.insert(extraParts, formatCompact(result) .. " kg")
			end
		end

		if info_.Size then
			table.insert(extraParts, string.format("x%.2f", scale))
		end

		if info_["Sell Price"] and type(eggRecords) == "table" and type(eggRecords.SellPrice) == "function" then
			local ok, result = pcall(eggRecords.SellPrice, record)

			if ok and tonumber(result) then
				table.insert(extraParts, "$" .. formatCompact(result))
			end
		end

		if info_.Distance and typeof(bottomCFrame) == "CFrame" then
			local character = localPlayer.Character
			character = character and character:FindFirstChild("HumanoidRootPart")

			if character then
				table.insert(extraParts, string.format("%dm", math.floor((character.Position - bottomCFrame.Position).Magnitude + 0.5)))
			end
		end

		if info_.Area and record.AreaId ~= nil then
			table.insert(extraParts, tostring(record.AreaId))
		end

		if info_.State and record.State ~= nil and record.State ~= "Slot" then
			table.insert(extraParts, tostring(record.State))
		end

		local showExtra = #extraParts > 0

		if showExtra then
			espHelpers.SetRow(row.ExtraRow, table.concat(extraParts, "  |  "), espHelpers.Palettes.Sheen)
		end

		if row.ShowIcon ~= showIcon or row.ShowName ~= showName or row.ShowRarity ~= showRarity or row.ShowMutation ~= showMutation or row.ShowValue ~= showValue or row.ShowExtra ~= showExtra then
			row.ShowIcon = showIcon
			row.ShowName = showName
			row.ShowRarity = showRarity
			row.ShowMutation = showMutation
			row.ShowValue = showValue
			row.ShowExtra = showExtra
			layoutEggRows(row)
		end

		local targetHighlightModel = record.RealModel or (resolvedModel and resolvedModel:IsA("Model") and resolvedModel:IsDescendantOf(workspace) and resolvedModel ~= terrain and resolvedModel)
		if (eggEspConfig.Highlight == espHighlightModes[3] or (eggEspConfig.Highlight == espHighlightModes[2] and info.Number >= eggEspConfig.HighlightMin)) and targetHighlightModel then
			if not row.Highlight and eggHighlightCount < espHighlightMax then
				local highlight = Instance.new("Highlight")
				highlight.Name = randomId()
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.FillTransparency = 0.82
				highlight.OutlineTransparency = 0.05
				highlight.FillColor = info.Color
				highlight.OutlineColor = info.Palette.Outline
				highlight.Adornee = targetHighlightModel
				highlight.Parent = targetHighlightModel
				row.Highlight = highlight
				eggHighlightCount = eggHighlightCount + 1
			end

			if row.Highlight and (row.Highlight.Adornee ~= targetHighlightModel or row.Highlight.Parent ~= targetHighlightModel) then
				row.Highlight.Adornee = targetHighlightModel
				row.Highlight.Parent = targetHighlightModel
			end
		else
			destroyRowHighlight(row)
		end
	end

	local function destroyEggRow(row)
		destroyRowHighlight(row)
		pcall(function() row.Billboard:Destroy() end)
	end

	local function destroyAllEggRows()
		local previousRows = activeEggRows
		local previousRuntime = eggEspRuntime
		activeEggRows = {}
		eggEspRuntime = nil
		eggHighlightCount = 0

		task.spawn(function()
			local now = os.clock()

			for _, row in pairs(previousRows) do
				if row.Highlight then
					row.Highlight:Destroy()
				end

				row.Billboard:Destroy()

				if espRefreshGap < os.clock() - now then
					RunService.Heartbeat:Wait()
					now = os.clock()
				end
			end

			if previousRuntime then
				previousRuntime:Destroy()
			end
		end)
	end

	local function renderEggSnapshot(records, generation, version)
		local function isCurrent()
			return generation == eggEspGeneration and version == eggEspRenderVersion and eggEspRunning
		end

		ensureEggRuntime()
		local visibleUids = {}
		local now = os.clock()

		for _, record in pairs(records) do
			local uid = type(record) == "table" and record.Uid

			if type(uid) == "string" and type(record.AssetCategory) == "string" then
				local info = getEggAssetInfo(record.AssetCategory)

				if eggEspConfig.Eggs and passesEggFilter(record, info) then
					visibleUids[uid] = true
					local row = activeEggRows[uid]

					if not row then
						row = createEggRow()
						activeEggRows[uid] = row
					end

					renderEggRow(row, record, info, info)
				end
			end

			if not (espRefreshGap < os.clock() - now) then
				continue
			end
			RunService.Heartbeat:Wait()
			now = os.clock()
			if not isCurrent() then
				return
			end
		end

		if eggEspConfig.Eggs and eggEspConfig.OwnBase then
			for _, record in ipairs(collectBaseEggs()) do
				local info = getEggAssetInfo(record.AssetCategory)

				if passesEggFilter(record, info) then
					visibleUids[record.Uid] = true
					local row = activeEggRows[record.Uid]

					if not row then
						row = createEggRow()
						activeEggRows[record.Uid] = row
					end

					renderEggRow(row, record, info)
				end
			end
		end

		for uid, row in pairs(activeEggRows) do
			if not visibleUids[uid] then
				activeEggRows[uid] = nil
				destroyEggRow(row)
			end
		end

		return true
	end

	local eggRenderQueued = false
	local eggRenderRunning = false

	scheduleEggRender = function()
		if not eggEspRunning then
			return
		end
		eggRecordsCache = eggRecordsCache or {}
		eggRenderQueued = true
		if eggRenderRunning then
			return
		end
		eggRenderRunning = true

		task.defer(function()
			while eggEspRunning and eggRenderQueued do
				eggRenderQueued = false
				eggEspGeneration = eggEspGeneration + 1
				local ok, result = pcall(renderEggSnapshot, eggRecordsCache or {}, eggEspGeneration, eggEspRenderVersion)

				if ok and result ~= true then
					eggRenderQueued = true
				end

				RunService.Heartbeat:Wait()
			end

			eggRenderRunning = false
		end)
	end

	local function fetchEggSnapshot()
		local version = eggEspRenderVersion

		if eggRecordsCache and next(activeEggRows) == nil then
			scheduleEggRender()
		end
		local eggState = modules.EggState
		local hasReader = type(eggState) == "table" and type(eggState.ReadFieldEggs) == "function"
		local records = nil

		if hasReader then
			local ok, result = pcall(eggState.ReadFieldEggs)
			ok = ok and type(result) == "table" and type(result.Records) == "table"
			records = nil

			if ok then
				records = result.Records
			end
		end

		if records == nil then
			local remote = askFieldEggSnapshotRemote or (networking and networking:FindFirstChild("RF/EggWorld/AskFieldEggSnapshot"))
			if remote and os.clock() >= snapshotFallbackAt then
				snapshotFallbackAt = os.clock() + 30
				local ok, result = pcall(remote.InvokeServer, remote)

				if ok and type(result) == "table" and type(result.Records) == "table" then
					records = result.Records
				end
			end
		end

		if records == nil and not eggRecordsCache then
			local slots = workspace:FindFirstChild("AreaEggSlotsClient")
			if slots then
				local synthetic = {}
				for _, slot in ipairs(slots:GetChildren()) do
					if slot:IsA("Model") then
						local category = slot:GetAttribute("AssetCategory") or slot:GetAttribute("EggType") or "Basic"
						local okPivot, pivot = pcall(function() return slot:GetPivot() end)
						synthetic[slot.Name] = {
							Uid = slot.Name,
							AssetCategory = category,
							AssetScale = slot:GetAttribute("AssetScale") or 1,
							BottomCFrame = okPivot and pivot or (slot.PrimaryPart and slot.PrimaryPart.CFrame),
							State = "Slot",
							Model = slot,
						}
					end
				end
				if next(synthetic) then
					records = synthetic
				end
			end
		end

		if version ~= eggEspRenderVersion or not eggEspRunning then
			return
		end

		if records ~= nil then
			local snapshot = {}

			for key, record in pairs(records) do
				snapshot[key] = record
			end

			eggRecordsCache = snapshot
			if espHelpers then
				espHelpers.GetEggSnapshot = function()
					return eggRecordsCache
				end
			end
		end

		if eggRecordsCache then
			scheduleEggRender()
		end
	end

	local function refreshEggSnapshot()
		task.spawn(pcall, fetchEggSnapshot)
	end

	local eggRefreshDebounceAt = 0

	local function requestSnapshotSync()
		if eggSnapshotBusy then
			return
		end
		eggSnapshotBusy = true

		task.delay(0.5, function()
			eggSnapshotBusy = false

			if eggEspRunning then
				refreshEggSnapshot()
			end
		end)
	end

	resizeEggRows = function()
		for _, row in pairs(activeEggRows) do
			onEggEspResize(row)
		end
	end

	local function stopEggEsp()
		eggEspRunning = false
		eggEspGeneration = eggEspGeneration + 1
		eggEspRenderVersion = eggEspRenderVersion + 1
		espHelpers.DisconnectAll(eggEspConnections)
		destroyAllEggRows()
	end

	local function startEggEsp()
		if eggEspRunning then
			refreshEggSnapshot()
			return
		end
		eggEspRunning = true
		local myGeneration = eggEspGeneration
		local eggState = modules.EggState

		if type(eggState) == "table" then
			for _, signalName in ipairs({ "FieldRefreshed", "FieldShifted", "FieldGone", "FieldClaimed", "SnapshotRefreshed" }) do
				local signal = eggState[signalName]

				if type(signal) == "table" and type(signal.Connect) == "function" then
					local ok, connection = pcall(signal.Connect, signal, requestSnapshotSync)

					if ok and connection then
						table.insert(eggEspConnections, connection)
					end
				end
			end
		end

		for _, containerName in ipairs({ "AreaEggSlotsClient", "PlacedEggRenders", "PlacedEggs" }) do
			local container = workspace:FindFirstChild(containerName) or workspace:FindFirstChild(containerName, true)

			if container then
				table.insert(eggEspConnections, container.ChildAdded:Connect(requestSnapshotSync))
				table.insert(eggEspConnections, container.ChildRemoved:Connect(requestSnapshotSync))
			end
		end

		local ownPlot = type(state.OwnPlot) == "function" and state.OwnPlot() or nil
		if ownPlot then
			table.insert(eggEspConnections, ownPlot.DescendantAdded:Connect(requestSnapshotSync))
			table.insert(eggEspConnections, ownPlot.DescendantRemoved:Connect(requestSnapshotSync))
		end

		task.spawn(function()
			while myGeneration == eggEspGeneration do
				task.wait(10)
				if myGeneration == eggEspGeneration then
					requestSnapshotSync()
					continue
				end
				break
			end
		end)

		task.spawn(function()
			while myGeneration == eggEspGeneration do
				task.wait(1)

				if myGeneration == eggEspGeneration then
					if eggEspConfig.Info.Distance then
						scheduleEggRender()
					end

					continue
				end

				break
			end
		end)

		refreshEggSnapshot()
	end

	local function toggleEggEsp()
		if eggEspConfig.Eggs then
			startEggEsp()
		else
			stopEggEsp()
		end
	end

	eggEspUiHandles = { Eggs = nil }
	local pendingEggToggleState = { Eggs = false }
	local eggEspDisposed = false

	local function syncEggToggle()
		if eggEspDisposed then
			return
		end
		local current = espHelpers.ReadToggle(eggEspUiHandles.Eggs, pendingEggToggleState.Eggs)

		if current == eggEspConfig.Eggs and eggEspRunning == current then
			return
		end
		eggEspConfig.Eggs = current
		toggleEggEsp()
	end

	registerCleanup(function()
		eggEspDisposed = true
		eggEspConfig.Eggs = false
		stopEggEsp()
	end)

	parseEspMultiSelection = function(selection)
		local result = {}

		if type(selection) == "table" then
			for key, value in pairs(selection) do
				local label

				if value == true and type(key) == "string" then
					label = key
				elseif type(value) == "string" then
					label = value
				end

				if label then
					result[label] = true
				end
			end
		end

		return result
	end

	eggEspUiHandles.Eggs = espSection:CreateToggle({
		Name = "ESP Eggs",
		Default = false,
		Callback = function(arg)
			pendingEggToggleState.Eggs = arg == true
			eggEspConfig.Eggs = arg == true
			toggleEggEsp()
			espHelpers.SyncSoon(syncEggToggle)
		end,
	})
end

espSection:CreateToggle({
	Name = "ESP Fixed Size",
	Default = false,
	SubOf = eggEspUiHandles.Eggs,
	Callback = function(arg)
		local fixed = arg == true

		if eggEspConfig.FixedSize ~= fixed then
			eggEspConfig.FixedSize = fixed
			resizeEggRows()
		end
	end,
})

espSection:CreateToggle({
	Name = "ESP Own Base Eggs",
	Note = "Also show the eggs placed in your own base",
	Default = true,
	SubOf = eggEspUiHandles.Eggs,
	Callback = function(arg)
		eggEspConfig.OwnBase = arg ~= false
		scheduleEggRender()
	end,
})

do
	local rarityChoices = { "Any" }
	local rarityNumberLookup = { Any = 0 }
	local specificOptions = {}
	local specificCategoryMap = {}
	local mutationChoices = { "Any Mutation", "No Mutation" }
	local directory = modules.Assets and modules.Assets.Directory
	local rarityNamesByNumber = {}
	local eggList = {}

	if type(directory) == "table" then
		for category, entry in pairs(directory) do
			local rarity = type(entry) == "table" and entry.Rarity or nil
			local rarityNumber = type(rarity) == "table" and tonumber(rarity.RarityNumber or rarity.Rank) or nil

			if rarityNumber then
				local rarityName = tostring(rarity.DisplayName or rarity._id or rarityNumber)
				rarityNamesByNumber[rarityNumber] = rarityNamesByNumber[rarityNumber] or rarityName

				table.insert(eggList, {
					Category = tostring(category),
					Name = tostring(entry.DisplayName or category),
					Rarity = rarityNumber,
					RarityName = rarityName,
				})
			end
		end
	end

	do
		local sortedRarityNumbers = {}

		for rarityNumber in pairs(rarityNamesByNumber) do
			table.insert(sortedRarityNumbers, rarityNumber)
		end

		table.sort(sortedRarityNumbers)

		for _, rarityNumber in ipairs(sortedRarityNumbers) do
			local label = string.format("%d - %s", rarityNumber, rarityNamesByNumber[rarityNumber])
			table.insert(rarityChoices, label)
			rarityNumberLookup[label] = rarityNumber
		end

		table.sort(eggList, function(a, b)
			if a.Rarity ~= b.Rarity then
				return a.Rarity > b.Rarity
			end
			return a.Name < b.Name
		end)

		for _, item in ipairs(eggList) do
			local label = string.format("%s [%s]", item.Name, item.RarityName)

			if specificCategoryMap[label] then
				label = string.format("%s [%s] (%s)", item.Name, item.RarityName, item.Category)
			end

			table.insert(specificOptions, label)
			specificCategoryMap[label] = item.Category
		end
	end

	do
		local mutationIds = {}
		local mutationsModule = modules.Mutations

		if type(mutationsModule) == "table" and type(mutationsModule.IdSet) == "table" then
			for id in pairs(mutationsModule.IdSet) do
				table.insert(mutationIds, tostring(id))
			end
		end

		table.sort(mutationIds)

		for _, id in ipairs(mutationIds) do
			table.insert(mutationChoices, id)
		end
	end

	local function findRarityLabel(rarityNumber)
		for _, label in ipairs(rarityChoices) do
			if rarityNumberLookup[label] == rarityNumber then
				return label
			end
		end

		return rarityChoices[1]
	end

	espSection:CreateDropdown({
		Name = "ESP Min Rarity",
		Note = "Show eggs of the chosen rarity and every rarity above it",
		Options = rarityChoices,
		Default = findRarityLabel(5),
		SubOf = eggEspUiHandles.Eggs,
		Callback = function(arg)
			eggEspConfig.MinRarity = rarityNumberLookup[type(arg) == "table" and arg[1] or arg] or 0
			scheduleEggRender()
		end,
	})

	fixDropdownAll(espSection:CreateMultiDropdown({
		Name = "ESP Specific Eggs",
		Note = "Only show these eggs (empty = all)",
		Options = specificOptions,
		Default = {},
		SubOf = eggEspUiHandles.Eggs,
		Callback = function(arg)
			local filter = {}

			for label in pairs(parseEspMultiSelection(arg)) do
				if specificCategoryMap[label] then
					filter[specificCategoryMap[label]] = true
				end
			end

			eggEspConfig.Specific = filter
			scheduleEggRender()
		end,
	}))

	fixDropdownAll(espSection:CreateMultiDropdown({
		Name = "ESP Mutations",
		Note = "Only show these mutations (empty = all, None = no mutation)",
		Options = mutationChoices,
		Default = {},
		SubOf = eggEspUiHandles.Eggs,
		Callback = function(arg)
			local mutationSet = {}
			local anyMutation = false
			local noMutation = false

			for label in pairs(parseEspMultiSelection(arg)) do
				if label == "Any Mutation" then
					anyMutation = true
				elseif label == "No Mutation" then
					noMutation = true
				else
					mutationSet[label] = true
				end
			end

			eggEspConfig.MutationSet = mutationSet
			eggEspConfig.AnyMutation = anyMutation
			eggEspConfig.NoMutation = noMutation
			scheduleEggRender()
		end,
	}))
end

fixDropdownAll(espSection:CreateMultiDropdown({
	Name = "ESP Show Info",
	Options = espInfoFieldOptions,
	Default = espInfoDefaults,
	SubOf = eggEspUiHandles.Eggs,
	Callback = function(arg)
		eggEspConfig.Info = parseEspMultiSelection(arg)
		scheduleEggRender()
	end,
}))

do
	local valueUnits = {
		["K/s"] = { Min = 0, Max = 1000, Mult = 1000 },
		["M/s"] = { Min = 0, Max = 1000, Mult = 1000000 },
		["B/s"] = { Min = 0, Max = 100, Mult = 1e9 },
	}

	local valueInput = 0
	local valueUnit = "M/s"

	local function applyEspMinValue(value, unit)
		if value ~= nil then
			valueInput = math.max(0, math.floor(tonumber(value) or valueInput))
		end

		if unit ~= nil then
			valueUnit = tostring(unit)
		end

		eggEspConfig.MinValue = valueInput * (valueUnits[valueUnit] or valueUnits["M/s"]).Mult
		scheduleEggRender()
	end

	createValueSlider(espSection, {
		Name = "Min ESP Value",
		SubOf = eggEspUiHandles.Eggs,
		Legacy = "ESP Min Value",
		SectionName = "ESP",
		OnRaw = function(value)
			applyEspMinValue(math.floor(value / 1000), "K/s")
		end,
	})
end

espSection:CreateSlider({
	Name = "ESP Egg Size",
	Min = 50,
	Max = 200,
	Default = 75,
	Increment = 5,
	Unit = "%",
	SubOf = eggEspUiHandles.Eggs,
	Callback = function(arg)
		local num = tonumber(arg)

		if num and eggEspConfig.SizeScale ~= num / 100 then
			eggEspConfig.SizeScale = num / 100
			resizeEggRows()
		end
	end,
})

do
	local guardPaletteMap = {
		Sleeping = espHelpers.Palettes.Accent,
		Waking = espHelpers.Palettes.Gold,
		Chasing = espHelpers.Palettes.Red,
	}

	local guardFallbackPalette = espHelpers.Palettes.Orange
	local guardSize = 0.75
	local guardRootOffset = 1

	local guardRows = {}
	local guardWatchConnections = {}
	local guardWatching = false
	local guardRuntime = nil

	local function getGuardStateLabel(guard)
		local guardState = guard:GetAttribute("GuardState")

		if guardState == "Sleeping" then
			return "Sleeping"
		end

		if guardState == "Waking" then
			return "Waking Up"
		end

		if guardState == "Chasing" then
			local targetPlayerId = guard:GetAttribute("TargetPlayer")

			if targetPlayerId == tostring(localPlayer.UserId) then
				return "Chasing You"
			end

			local targetPlayer = tonumber(targetPlayerId) and Players:GetPlayerByUserId(tonumber(targetPlayerId))
			return targetPlayer and "Chasing " .. targetPlayer.DisplayName or "Chasing"
		end

		return guardState and tostring(guardState) or "Awake"
	end

	local function updateGuardRow(row, guard)
		local palette = guardPaletteMap[guard:GetAttribute("GuardState")] or guardFallbackPalette
		row.Highlight.FillColor = palette.Outline
		row.Highlight.OutlineColor = palette.Outline
		espHelpers.SetRow(row.StateRow, getGuardStateLabel(guard), palette)
	end

	local function resizeGuardTag(row)
		row.Tag.Size = UDim2.fromOffset(espHelpers.ScaledWidth(115, guardSize), math.floor(espHelpers.RowHeight(guardSize) * 1.6))
	end

	local function destroyGuardRow(areaName)
		local row = guardRows[areaName]
		if not row then
			return
		end

		guardRows[areaName] = nil
		espHelpers.DisconnectAll(row.Connections)
		row.Highlight:Destroy()
		row.Tag:Destroy()
	end

	local function createGuardRow(areaName, guard)
		if guardRows[areaName] then
			return
		end
		local guardRoot = espHelpers.FindGuardRoot(guard)
		if not guardRoot then
			return
		end

		if not guardRuntime or not guardRuntime.Parent then
			guardRuntime = espHelpers.CreateRuntime()
		end

		local highlight = Instance.new("Highlight")
		highlight.Name = randomId()
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillTransparency = 0.76
		highlight.OutlineTransparency = 0.02
		highlight.Adornee = guard
		highlight.Parent = guard

		local ok, boundingCFrame, boundingSize = pcall(guard.GetBoundingBox, guard)
		local isBoundingOk = ok and typeof(boundingCFrame) == "CFrame"
		local verticalOffset = 6

		if isBoundingOk then
			verticalOffset = boundingCFrame.Position.Y + boundingSize.Y * 0.5 - guardRoot.Position.Y + guardRootOffset
		end

		local tag, tagFrame = espHelpers.CreateTag(guardRuntime, math.huge)
		tag.Adornee = guardRoot
		tag.StudsOffsetWorldSpace = Vector3.new(0, verticalOffset, 0)

		local nameRow = espHelpers.CreateTextRow(tagFrame, espHelpers.StatusFont, 1, 0.45)
		local stateRow = espHelpers.CreateTextRow(tagFrame, espHelpers.StatusFont, 2, 0.55)
		espHelpers.SetRow(nameRow, tostring(areaName) .. " Guard", espHelpers.Palettes.Sheen)

		local row = {
			Highlight = highlight,
			Tag = tag,
			StateRow = stateRow,
			Connections = {},
		}

		guardRows[areaName] = row
		resizeGuardTag(row)
		updateGuardRow(row, guard)

		local function refresh()
			updateGuardRow(row, guard)
		end

		table.insert(row.Connections, guard:GetAttributeChangedSignal("GuardState"):Connect(refresh))
		table.insert(row.Connections, guard:GetAttributeChangedSignal("TargetPlayer"):Connect(refresh))

		table.insert(row.Connections, guard.AncestryChanged:Connect(function()
			if not guard:IsDescendantOf(workspace) then
				destroyGuardRow(areaName)
			end
		end))
	end

	local function stopGuardsEsp()
		guardWatching = false
		espHelpers.DisconnectAll(guardWatchConnections)

		for areaName in pairs(guardRows) do
			destroyGuardRow(areaName)
		end

		if guardRuntime then
			guardRuntime:Destroy()
			guardRuntime = nil
		end
	end

	local function startGuardsEsp()
		if guardWatching then
			return
		end
		guardWatching = true
		guardWatchConnections = espHelpers.WatchGuards(createGuardRow)
	end

	local guardHandle = nil
	local guardWanted = false
	local guardsEspDisposed = false

	local function syncGuardsEsp()
		if guardsEspDisposed then
			return
		end

		if espHelpers.ReadToggle(guardHandle, guardWanted) then
			startGuardsEsp()
		elseif guardWatching then
			stopGuardsEsp()
		end
	end

	registerCleanup(function()
		guardsEspDisposed = true
		stopGuardsEsp()
	end)

	guardHandle = espSection:CreateToggle({
		Name = "ESP Guards",
		Default = false,
		Callback = function(arg)
			guardWanted = arg == true
			if guardWanted then
				startGuardsEsp()
			else
				stopGuardsEsp()
			end
			espHelpers.SyncSoon(syncGuardsEsp)
		end,
	})

	espSection:CreateSlider({
		Name = "ESP Guard Size",
		Min = 50,
		Max = 200,
		Default = 75,
		Increment = 5,
		Unit = "%",
		SubOf = guardHandle,
		Callback = function(arg)
			local num = tonumber(arg)

			if num and guardSize ~= num / 100 then
				guardSize = num / 100

				for _, row in pairs(guardRows) do
					resizeGuardTag(row)
				end
			end
		end,
	})
end

local textService = game:GetService("TextService")
local playerEspFont
do
	local ok, f = pcall(Font.new, "rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal)
	playerEspFont = ok and f or espHelpers.MainFont or Font.fromEnum(Enum.Font.GothamBold)
end

local playerEspGradient
do
	local keypoints = {
		ColorSequenceKeypoint.new(0, Color3.fromRGB(138, 255, 205)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(125, 225, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 135, 255)),
	}
	playerEspGradient = ColorSequence.new(keypoints)
end

local playerEspStrokeGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(7, 73, 66)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 17, 79)),
})

local playerEspWatching = false
local playerEspRenderVersion = 0
local playerEspRuntime = nil
local playerEspRows = {}
local playerEspConnections = {}
local playerEspAvatarCache = {}
local playerEspInfoFields = { Name = true, Username = false, Avatar = false, Tool = true }
local playerEspSize = 0.75
local playerEspHandle = nil
local playerEspWanted = false
local playerEspDisposed = false

local playerEspTextBoundsCache = {}

local function sanitizeImageId(value)
	local text = tostring(value or "")
	if text:match("^%d+$") then
		return "rbxassetid://" .. text
	end
	return text
end

local function extractToolIcon(tool)
	if not tool or not tool:IsA("Tool") then
		return ""
	end
	local textureId = sanitizeImageId(tool.TextureId)
	if textureId ~= "" then
		return textureId
	end

	for _, attributeName in ipairs({ "Icon", "Image", "Thumbnail", "TextureId" }) do
		local attribute = tool:GetAttribute(attributeName)
		if type(attribute) == "string" and sanitizeImageId(attribute) ~= "" then
			return sanitizeImageId(attribute)
		end
	end

	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("Decal") or descendant:IsA("Texture") then
			textureId = sanitizeImageId(descendant.Texture)
		elseif descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
			textureId = sanitizeImageId(descendant.Image)
		end

		if textureId ~= "" then
			return textureId
		end
	end

	return ""
end

local function getPlayerEspRowHeight()
	local camera = workspace.CurrentCamera
	local base = camera and camera.ViewportSize.Y or 1080
	return math.max(1, math.floor(math.clamp(base * 0.024, 26, 35) * playerEspSize))
end

local function measureText(text, size)
	local cacheKey = text .. "@" .. size
	local cached = playerEspTextBoundsCache[cacheKey]
	if cached then
		return cached
	end

	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Font = playerEspFont
	params.Size = size
	params.Width = 1000

	local ok, bounds = pcall(function()
		return textService:GetTextBoundsAsync(params)
	end)

	params:Destroy()
	ok = ok and bounds.X

	if not ok then
		ok = (utf8.len(text) or #text) * size * 0.56
	end

	playerEspTextBoundsCache[cacheKey] = ok
	return ok
end

local function applyContextualStroke(stroke, color, thickness, fallback)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = color
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Transparency = 0
	stroke.Thickness = fallback or 1.4
end

local function makePlayerEspLabel(parent, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = randomId()
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.BackgroundTransparency = 1
	label.FontFace = playerEspFont
	label.Text = ""
	label.TextScaled = true
	label.TextStrokeTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = zIndex
	label.Parent = parent
	return label
end

local function makePlayerEspImage(parent, zIndex)
	local image = Instance.new("ImageLabel")
	image.Name = randomId()
	image.AnchorPoint = Vector2.new(0, 0.5)
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	image.ZIndex = zIndex
	image.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Name = randomId()
	aspect.AspectRatio = 1
	aspect.Parent = image
	return image
end

local function layoutPlayerEspRow(row)
	local baseHeight = getPlayerEspRowHeight()
	local showName = playerEspInfoFields.Name == true or playerEspInfoFields.Username == true
	local showAvatar = playerEspInfoFields.Avatar == true
	local showTool = playerEspInfoFields.Tool == true and row.ToolIcon.Image ~= ""
	local avatarSize = showAvatar and math.floor(baseHeight * 0.72) or 0
	local toolSize = showTool and math.floor(baseHeight * 0.82) or 0
	local nameFontSize = math.floor(baseHeight * 0.7)
	local gapX = math.max(1, math.floor(baseHeight * 0.04))
	local nameText = playerEspInfoFields.Username == true and row.Player.Name or row.Player.DisplayName
	row.Name.Text = nameText
	row.Shadow.Text = nameText
	local nameWidth = showName and math.floor(math.clamp(measureText(nameText, nameFontSize) + 4, nameFontSize, 230)) or 0
	local cursorX = 0
	local avatarX = 0

	if showAvatar then
		avatarX = 0
		cursorX = avatarSize
	end
	local nameX = 0

	if showName then
		if cursorX > 0 then
			nameX = cursorX + gapX
		else
			nameX = cursorX
		end
		cursorX = nameX + nameWidth
	end
	local toolX = 0

	if showTool then
		if cursorX > 0 then
			toolX = cursorX + gapX
		else
			toolX = cursorX
		end
		cursorX = toolX + toolSize
	end

	local totalWidth = math.max(cursorX, 1)
	local gapXRatio = 1 / totalWidth
	local gapYRatio = 1 / baseHeight
	row.Billboard.Size = UDim2.fromOffset(totalWidth, baseHeight)
	row.Avatar.Visible = showAvatar
	row.Name.Visible = showName
	row.Shadow.Visible = showName
	row.ToolIcon.Visible = showTool
	row.ToolShadow.Visible = showTool
	row.Avatar.Position = UDim2.fromScale(avatarX / totalWidth, 0.5)
	row.Avatar.Size = UDim2.fromScale(avatarSize / totalWidth, avatarSize / baseHeight)
	row.Name.Position = UDim2.fromScale(nameX / totalWidth, 0.5)
	row.Name.Size = UDim2.fromScale(nameWidth / totalWidth, nameFontSize / baseHeight)
	row.Shadow.Position = UDim2.fromScale(nameX / totalWidth + gapXRatio, 0.5 + gapYRatio)
	row.Shadow.Size = row.Name.Size
	row.ToolIcon.Position = UDim2.fromScale(toolX / totalWidth, 0.5)
	row.ToolIcon.Size = UDim2.fromScale(toolSize / totalWidth, toolSize / baseHeight)
	row.ToolShadow.Position = UDim2.fromScale(toolX / totalWidth + gapXRatio, 0.5 + gapYRatio)
	row.ToolShadow.Size = row.ToolIcon.Size
end

local function createPlayerEspRow(player, adornee, headPart, rootPart)
	local highlight = Instance.new("Highlight")
	highlight.Name = randomId()
	highlight.Adornee = adornee
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(0, 67, 148)
	highlight.FillTransparency = 0.76
	highlight.OutlineColor = Color3.fromRGB(72, 207, 255)
	highlight.OutlineTransparency = 0.02
	highlight.Parent = adornee
	local anchor = rootPart or headPart
	local offsetY = 3.1

	if anchor ~= headPart then
		offsetY = math.clamp(headPart.Position.Y - anchor.Position.Y + 3.1, 3.8, 6)
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = randomId()
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = math.huge
	billboard.Size = UDim2.fromOffset(1, 1)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	billboard.Parent = playerEspRuntime

	local frame = Instance.new("Frame")
	frame.Name = randomId()
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = billboard

	local avatar = makePlayerEspImage(frame, 2)
	avatar.ScaleType = Enum.ScaleType.Crop
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.Name = randomId()
	avatarCorner.CornerRadius = UDim.new(1, 0)
	avatarCorner.Parent = avatar

	local shadow = makePlayerEspLabel(frame, 1)
	shadow.TextColor3 = Color3.fromRGB(7, 19, 34)
	shadow.TextTransparency = 0.05

	local name = makePlayerEspLabel(frame, 2)
	name.TextColor3 = Color3.fromRGB(255, 255, 255)

	local nameStroke = Instance.new("UIStroke")
	nameStroke.Name = randomId()
	applyContextualStroke(nameStroke, Color3.fromRGB(255, 255, 255), 0.044, 1.4)
	nameStroke.Parent = name

	local nameStrokeGradient = Instance.new("UIGradient")
	nameStrokeGradient.Name = randomId()
	nameStrokeGradient.Color = playerEspStrokeGradient
	nameStrokeGradient.Rotation = 90
	nameStrokeGradient.Parent = nameStroke

	local nameTextGradient = Instance.new("UIGradient")
	nameTextGradient.Name = randomId()
	nameTextGradient.Color = playerEspGradient
	nameTextGradient.Rotation = 90
	nameTextGradient.Parent = name

	local toolShadow = makePlayerEspImage(frame, 1)
	toolShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	toolShadow.ImageTransparency = 0.35

	local toolIcon = makePlayerEspImage(frame, 2)

	local row = {
		Player = player,
		Highlight = highlight,
		Billboard = billboard,
		Avatar = avatar,
		Shadow = shadow,
		Name = name,
		ToolShadow = toolShadow,
		ToolIcon = toolIcon,
	}

	layoutPlayerEspRow(row)
	return row
end

local function restoreNameDistance(row)
	if row.NameHumanoid and row.NameHumanoid.Parent and row.NameDistance ~= nil then
		pcall(function()
			row.NameHumanoid.NameDisplayDistance = row.NameDistance
		end)
	end

	row.NameHumanoid = nil
	row.NameDistance = nil
end

local function attachNameSuppression(row, character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if row.NameHumanoid ~= humanoid then
		restoreNameDistance(row)
		row.NameHumanoid = humanoid
		row.NameDistance = humanoid.NameDisplayDistance
	end

	pcall(function()
		humanoid.NameDisplayDistance = 0
	end)
end

local function destroyPlayerEspRow(row)
	espHelpers.DisconnectAll(row.CharacterConnections)

	if row.Tag then
		pcall(function()
			row.Tag.Highlight:Destroy()
		end)

		pcall(function()
			row.Tag.Billboard:Destroy()
		end)

		row.Tag = nil
	end

	restoreNameDistance(row)
	row.Character = nil
end

local function refreshPlayerTool(row)
	if not row.Tag or not row.Character then
		return
	end
	local icon = extractToolIcon(row.Character:FindFirstChildOfClass("Tool"))
	row.Tag.ToolIcon.Image = icon
	row.Tag.ToolShadow.Image = icon
	layoutPlayerEspRow(row.Tag)
end

local function loadAvatar(row, player, version)
	local cached = playerEspAvatarCache[player.UserId]

	if cached == nil then
		local ok, result = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)

		cached = ok and result or ""
		playerEspAvatarCache[player.UserId] = cached
	end

	if playerEspWatching and row.Version == version and row.Tag then
		row.Tag.Avatar.Image = cached
	end
end

local function attachPlayerRow(row, player, character)
	destroyPlayerEspRow(row)
	row.Version = row.Version + 1
	local version = row.Version
	if not playerEspWatching or not character then
		return
	end
	row.Character = character

	task.spawn(function()
		local head = character:FindFirstChild("Head") or character:WaitForChild("Head", 5)
		if not playerEspWatching or row.Version ~= version or not head or not head:IsA("BasePart") or not character:IsDescendantOf(workspace) then
			return
		end

		if not playerEspRuntime or not playerEspRuntime.Parent then
			playerEspRuntime = espHelpers.CreateRuntime()
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		row.Tag = createPlayerEspRow(player, character, head, root and root:IsA("BasePart") and root or nil)
		attachNameSuppression(row, character)

		local function scheduleToolRefresh()
			task.defer(function()
				if playerEspWatching and row.Version == version then
					refreshPlayerTool(row)
				end
			end)
		end

		table.insert(row.CharacterConnections, character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				scheduleToolRefresh()
			elseif child:IsA("Humanoid") then
				attachNameSuppression(row, character)
			end
		end))

		table.insert(row.CharacterConnections, character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				scheduleToolRefresh()
			end
		end))

		table.insert(row.CharacterConnections, character.AncestryChanged:Connect(function()
			if row.Version == version and not character:IsDescendantOf(workspace) then
				row.Version = row.Version + 1
				destroyPlayerEspRow(row)
			end
		end))

		refreshPlayerTool(row)
		loadAvatar(row, player, version)
	end)
end

local function removePlayerRow(player)
	local row = playerEspRows[player]
	if not row then
		return
	end
	row.Version = row.Version + 1
	destroyPlayerEspRow(row)
	espHelpers.DisconnectAll(row.PlayerConnections)
	playerEspRows[player] = nil
end

local function addPlayerRow(player)
	if player == localPlayer or playerEspRows[player] then
		return
	end

	local row = {
		Version = 0,
		Character = nil,
		Tag = nil,
		NameHumanoid = nil,
		NameDistance = nil,
		CharacterConnections = {},
		PlayerConnections = {},
	}

	playerEspRows[player] = row

	table.insert(row.PlayerConnections, player.CharacterAdded:Connect(function(character)
		attachPlayerRow(row, player, character)
	end))

	table.insert(row.PlayerConnections, player.CharacterRemoving:Connect(function(character)
		if row.Character == character then
			row.Version = row.Version + 1
			destroyPlayerEspRow(row)
		end
	end))

	attachPlayerRow(row, player, player.Character)
end

local function resizePlayerRows()
	for _, row in pairs(playerEspRows) do
		if row.Tag then
			layoutPlayerEspRow(row.Tag)
		end
	end
end

local function stopPlayerEsp()
	playerEspWatching = false
	playerEspRenderVersion = playerEspRenderVersion + 1
	espHelpers.DisconnectAll(playerEspConnections)

	local players = {}

	for player in pairs(playerEspRows) do
		table.insert(players, player)
	end

	for _, player in ipairs(players) do
		removePlayerRow(player)
	end

	if playerEspRuntime then
		playerEspRuntime:Destroy()
		playerEspRuntime = nil
	end
end

local function startPlayerEsp()
	if playerEspWatching then
		return
	end
	playerEspWatching = true
	playerEspRenderVersion = playerEspRenderVersion + 1
	local version = playerEspRenderVersion
	playerEspRuntime = espHelpers.CreateRuntime()

	for _, player in ipairs(Players:GetPlayers()) do
		addPlayerRow(player)
	end

	table.insert(playerEspConnections, Players.PlayerAdded:Connect(addPlayerRow))
	table.insert(playerEspConnections, Players.PlayerRemoving:Connect(removePlayerRow))
	local camera = workspace.CurrentCamera

	if camera then
		table.insert(playerEspConnections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(resizePlayerRows))
	end

	task.spawn(function()
		while true do
			if playerEspWatching and version == playerEspRenderVersion then
				task.wait(1)

				if not (not playerEspWatching or version ~= playerEspRenderVersion) then
					for player, row in pairs(playerEspRows) do
						local character = player.Character
						local hasAdornee = row.Tag and row.Tag.Billboard.Parent and row.Tag.Billboard.Adornee and row.Tag.Billboard.Adornee:IsDescendantOf(workspace)

						if character and character:IsDescendantOf(workspace) and (row.Character ~= character or not hasAdornee) then
							attachPlayerRow(row, player, character)
						end
					end

					continue
				end
			end

			break
		end
	end)
end

local function syncPlayerEspToggle()
	if playerEspDisposed then
		return
	end

	if espHelpers.ReadToggle(playerEspHandle, playerEspWanted) then
		startPlayerEsp()
	elseif playerEspWatching then
		stopPlayerEsp()
	end
end

registerCleanup(function()
	playerEspDisposed = true
	stopPlayerEsp()
end)

playerEspHandle = espSection:CreateToggle({
	Name = "ESP Players",
	Default = false,
	Callback = function(arg)
		playerEspWanted = arg == true
		if playerEspWanted then
			startPlayerEsp()
		else
			stopPlayerEsp()
		end
		espHelpers.SyncSoon(syncPlayerEspToggle)
	end,
})

fixDropdownAll(espSection:CreateMultiDropdown({
	Name = "ESP Player Info",
	Options = { "Name", "Username", "Avatar", "Tool" },
	Default = { "Name", "Tool" },
	SubOf = playerEspHandle,
	Callback = function(arg)
		local fields = { Name = false, Username = false, Avatar = false, Tool = false }

		if type(arg) == "table" then
			for key, value in pairs(arg) do
				if type(value) == "string" and fields[value] ~= nil then
					fields[value] = true
				elseif type(key) == "string" and value == true and fields[key] ~= nil then
					fields[key] = true
				end
			end
		end

		playerEspInfoFields = fields
		resizePlayerRows()
	end,
}))

espSection:CreateSlider({
	Name = "ESP Player Size",
	Min = 50,
	Max = 200,
	Default = 75,
	Increment = 5,
	Unit = "%",
	SubOf = playerEspHandle,
	Callback = function(arg)
		local num = tonumber(arg)

		if num and playerEspSize ~= num / 100 then
			playerEspSize = math.clamp(num / 100, 0.5, 2)
			resizePlayerRows()
		end
	end,
})
end)()

local progressionSection

do
	progressionSection = window:CreateTab({ Name = "Progress", SectionsExpanded = true }):CreateSection({ Name = "Auto Progression", Expanded = true })

	local remoteCache = {}
	local progression = {}

	progression.Remote = function(name)
		local cached = remoteCache[name]
		if cached ~= nil then
			return cached or nil
		end
		local remote = networking:FindFirstChild(name)
		remoteCache[name] = remote or false
		return remote
	end

	progression.Invoke = function(name, ...)
		local remote = progression.Remote(name)
		if not remote or not remote:IsA("RemoteFunction") then
			return false, nil
		end
		local ok, result = pcall(remote.InvokeServer, remote, ...)
		return ok, result
	end

	progression.Fire = function(name, ...)
		local remote = progression.Remote(name)
		if not remote or not remote:IsA("RemoteEvent") then
			return false
		end
		return pcall(remote.FireServer, remote, ...)
	end

	local function getProgressionSaveData()
		local saveModule = modules.Save
		if type(saveModule) ~= "table" or type(saveModule.Get) ~= "function" then
			return nil
		end
		local ok, result = pcall(saveModule.Get)
		return ok and type(result) == "table" and result or nil
	end

	progression.SaveData = getProgressionSaveData

	local moneyFields = { "Money", "Cash", "Coins", "Currency", "Balance" }

	progression.Money = function()
		local saveData = getProgressionSaveData()

		if saveData then
			for _, field in ipairs(moneyFields) do
				local value = tonumber(saveData[field])
				if value then
					return value
				end
			end
		end

		local leaderstats = localPlayer:FindFirstChild("leaderstats")
		if leaderstats then
			for _, field in ipairs(moneyFields) do
				local stat = leaderstats:FindFirstChild(field)
				if stat and tonumber(stat.Value) then
					return tonumber(stat.Value)
				end
			end
		end

		return nil
	end

	progression.AddWorker = taskScheduler.Add
	progression.Backoff = taskScheduler.Backoff

	local progressionSignalFields = {
		"Money",
		"BaseUpgradeLevel",
		"TreadmillUpgradeLevel",
		"TrailInventory",
		"PendingOfflineMoney",
	}

	local saveModule = modules.Save

	if type(saveModule) == "table" and type(saveModule.FieldSignal) == "function" then
		for _, fieldName in ipairs(progressionSignalFields) do
			local ok, signal = pcall(saveModule.FieldSignal, fieldName)

			if ok and type(signal) == "table" and type(signal.Connect) == "function" then
				local ok2, connection = pcall(signal.Connect, signal, function()
					taskScheduler.Wake()
				end)

				if ok2 and connection then
					registerCleanup(function()
						pcall(function()
							connection:Disconnect()
						end)
					end)
				end
			end
		end
	end

	local autoBuyTrailHandle = nil
	local trailListCache = nil
	local blockedTrailIds = {}

	local function collectTrailList()
		local trailsModule = requireModule(function()
			return ReplicatedStorage.Data.Trails
		end)

		local directory = type(trailsModule) == "table" and trailsModule.Directory or nil
		if type(directory) ~= "table" then
			return {}
		end
		local list = {}

		for key, entry in pairs(directory) do
			if type(entry) == "table" then
				table.insert(list, { Id = tostring(entry._id or key), Price = tonumber(entry.Price) or math.huge })
			end
		end

		table.sort(list, function(a, b)
			return a.Price < b.Price
		end)

		return list
	end

	local function tryBuyTrail()
		if not state.Toggle(autoBuyTrailHandle, false) then
			return false
		end
		trailListCache = trailListCache or collectTrailList()
		local saveData = getProgressionSaveData()
		if not saveData or #trailListCache == 0 then
			return false
		end
		local trailInventory = type(saveData.TrailInventory) == "table" and saveData.TrailInventory or {}
		local money = tonumber(saveData.Money) or 0

		for _, entry in ipairs(trailListCache) do
			if trailInventory[entry.Id] ~= true and not blockedTrailIds[entry.Id] and entry.Price <= money then
				local ok, result = progression.Invoke("RF/Trailwear/AskPurchase", entry.Id)

				if ok and result ~= false then
					return true
				end
				blockedTrailIds[entry.Id] = true
				progression.Backoff()
				return false
			end
		end

		return false
	end

	autoBuyTrailHandle = progressionSection:CreateToggle({
		Name = "Auto Buy Trail",
		Note = "Automatically buy available trails when affordable",
		Default = false,
		Callback = function()
			table.clear(blockedTrailIds)
			trailListCache = nil
		end,
	})

	progression.AddWorker(tryBuyTrail)

	local autoUpgradeBaseHandle = nil

	local function tryUpgradeBase()
		if not state.Toggle(autoUpgradeBaseHandle, false) then
			return false
		end
		local saveData = getProgressionSaveData()
		if not saveData then
			return false
		end

		local basesModule = requireModule(function()
			return ReplicatedStorage.Data.Bases
		end)

		local bases = type(basesModule) == "table" and basesModule.BASES or nil
		if type(bases) ~= "table" then
			return false
		end
		local currentLevel = tonumber(saveData.BaseUpgradeLevel) or 0
		local maxLevel = nil

		if type(basesModule.GetMaxBaseLevel) == "function" then
			local ok, result = pcall(basesModule.GetMaxBaseLevel)
			maxLevel = ok and tonumber(result) or nil
		end

		if maxLevel and currentLevel >= maxLevel then
			return false
		end
		local nextLevel = bases[currentLevel + 1]
		local affordable = type(nextLevel) == "table" and tonumber(nextLevel.Cost) or nil

		if affordable then
			affordable = (tonumber(saveData.Money) or 0) >= affordable
		end

		if affordable then
			return progression.Fire("RE/Homestead/AskBaseTierRaise")
		end
		return false
	end

	autoUpgradeBaseHandle = progressionSection:CreateToggle({
		Name = "Auto Upgrade Base",
		Note = "Automatically upgrade base when money is available",
		Default = false,
	})

	progression.AddWorker(tryUpgradeBase)

	local autoUpgradeTreadmillHandle = nil

	local function tryUpgradeTreadmill()
		if not state.Toggle(autoUpgradeTreadmillHandle, false) then
			return false
		end
		local saveData = getProgressionSaveData()
		if not saveData then
			return false
		end

		local treadmillModule = requireModule(function()
			return ReplicatedStorage.Data.Treadmills
		end)

		if type(treadmillModule) ~= "table" or type(treadmillModule.GetByUpgradeLevel) ~= "function" then
			return false
		end
		local ok, entry = pcall(treadmillModule.GetByUpgradeLevel, (tonumber(saveData.TreadmillUpgradeLevel) or 0) + 1)
		if not ok or type(entry) ~= "table" then
			return false
		end
		local entryId = entry._id
		local price = tonumber(entry.Price) or math.huge
		local affordable = type(entryId) == "string"

		if affordable then
			affordable = (tonumber(saveData.Money) or 0) >= price
		end

		if affordable then
			local ok2, result = progression.Invoke("RF/Treadmill/AskTierRaise", entryId)
			return ok2 and result ~= false
		end
		return false
	end

	autoUpgradeTreadmillHandle = progressionSection:CreateToggle({
		Name = "Auto Upgrade Treadmill",
		Note = "Automatically upgrade treadmill when money is available",
		Default = false,
	})

	progression.AddWorker(tryUpgradeTreadmill)

	local claimCycleSeconds = 15
	local autoClaimHandle = nil
	local claimElapsed = 15
	local lastClaimAt = os.clock()

	local function tryClaimRewards()
		if not state.Toggle(autoClaimHandle, false) then
			return false
		end
		local now = os.clock()
		claimElapsed = claimElapsed + now - lastClaimAt
		lastClaimAt = now
		local saveData = getProgressionSaveData()
		local pendingReward = saveData and tonumber(saveData.PendingOfflineMoney) or nil

		if pendingReward == nil then
			local ok, pendingValue = progression.Invoke("RF/AwayEarnings/PendingCheck")
			pendingReward = ok and pendingValue ~= false and pendingValue ~= nil and 1 or 0
		end

		local claimed = false

		if pendingReward > 0 then
			local ok, result = progression.Invoke("RF/AwayEarnings/AskCollect")
			claimed = ok and result ~= false
		end

		if claimCycleSeconds <= claimElapsed then
			claimElapsed = 0
			local ok, result = progression.Invoke("RF/Codex/AskRedeemAll")
			claimed = claimed or (ok and result ~= false)
			progression.Invoke("RF/Codex/AskRedeemLimitedEgg")
		end

		return claimed
	end

	autoClaimHandle = progressionSection:CreateToggle({
		Name = "Auto Claim",
		Note = "Claim offline money & index rewards",
		Default = false,
		Callback = function()
			claimElapsed = claimCycleSeconds
		end,
	})

	progression.AddWorker(tryClaimRewards)
end

state.IndexClaimHandle = progressionSection:CreateToggle({
	Name = "Auto Claim Index",
	Note = "Claim index rewards as soon as they unlock",
	Default = false,
	Callback = function()
		if type(state.IndexClaimRestart) == "function" then
			state.IndexClaimRestart()
		end
	end,
})

notifyUser = function(title, message)
	if type(nexLibrary.Notify) == "function" then
		pcall(nexLibrary.Notify, title, message, 5)
	end
end

do
	local serverSection = window:CreateTab({ Name = "Server", SectionsExpanded = true }):CreateSection({ Name = "Server", Expanded = true })
	state.ServerSection = serverSection
	local TeleportService = game:GetService("TeleportService")
	local HttpService = game:GetService("HttpService")
	local GuiService2 = game:GetService("GuiService")

	local serverHopMode = "Least Players"
	local hopWaitSeconds = 10
	local lastHopAt = 0
	local hopTargetId = nil
	local blockedServers = {}
	local hopInProgress = false
	local hopGeneration = 0
	local serverListCache = nil
	local serverListMode = ""
	local serverListAt = 0
	local serverListTtl = 60

	local function clearBlockedServer(jobId)
		lastHopAt = 0
		hopTargetId = nil

		if jobId then
			blockedServers[jobId] = true
		end
	end

	pcall(function()
		TeleportService.TeleportInitFailed:Connect(function(_, _, message)
			if not hopTargetId then
				return
			end
			clearBlockedServer(hopTargetId)
			hopInProgress = true

			if not hopInProgress then
				notifyUser("Server Hop Failed", tostring(message ~= "" and message or "Teleport failed"))
			end
		end)
	end)

	local function fetchServerList(mode)
		local currentJobId = tostring(game.JobId or "")
		local servers = {}
		local isRandom = mode == "Random"
		local sortOrder = mode == "Least Players" and "Asc" or "Desc"
		local maxPages = isRandom and 3 or 6
		local cursor = nil

		for _ = 1, maxPages do
			local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100", game.PlaceId, sortOrder)

			if cursor and cursor ~= "" then
				url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
			end

			local ok, result = pcall(function()
				return HttpService:JSONDecode(game:HttpGet(url))
			end)

			if not ok or type(result) ~= "table" then
				return servers, false
			end

			for _, entry in ipairs(result.data or {}) do
				local jobId = tostring(entry.id or "")
				local playing = tonumber(entry.playing) or math.huge
				local maxPlayers = tonumber(entry.maxPlayers) or 0

				if jobId ~= "" and jobId ~= currentJobId and playing < maxPlayers then
					servers[#servers + 1] = { Id = jobId, Playing = playing, Room = maxPlayers - playing }
				end
			end

			if #servers > 0 and not isRandom then
				break
			end
			cursor = result.nextPageCursor
			if not cursor or cursor == "" then
				break
			end
		end

		return servers, true
	end

	local function serverHop(mode)
		local servers

		if serverListCache and serverListMode == mode and os.clock() - serverListAt < serverListTtl then
			servers = serverListCache
		else
			local ok
			servers, ok = fetchServerList(mode)
			if not ok then
				return "fetch"
			end
			serverListCache = servers
			serverListMode = mode
			serverListAt = os.clock()
		end

		local function filterServers(minRoom)
			local list = {}

			for _, entry in ipairs(servers) do
				if not blockedServers[entry.Id] and entry.Room >= minRoom then
					list[#list + 1] = entry
				end
			end

			return list
		end

		local candidates = filterServers(2)

		if #candidates == 0 then
			candidates = filterServers(1)
		end

		if #candidates == 0 and next(blockedServers) ~= nil then
			table.clear(blockedServers)
			candidates = filterServers(1)
		end

		if #candidates == 0 then
			clearBlockedServer(nil)
			serverListCache = nil
			return "empty"
		end

		local targetId

		if mode == "Random" then
			targetId = candidates[math.random(1, #candidates)].Id
		else
			table.sort(candidates, function(a, b)
				if mode == "Least Players" then
					return a.Playing < b.Playing
				end
				return a.Playing > b.Playing
			end)

			targetId = candidates[1].Id
		end

		hopInProgress = false
		hopTargetId = targetId
		lastHopAt = os.clock() + hopWaitSeconds

		if not pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, targetId, localPlayer)
		end) then
			clearBlockedServer(targetId)
			return "failed"
		end

		local deadline = os.clock() + hopWaitSeconds

		while os.clock() < deadline do
			if hopInProgress then
				return "denied"
			end
			task.wait(0.25)
		end

		return "waiting"
	end

	state.ServerHop = serverHop

	serverSection:CreateDropdown({
		Name = "Server Hop Mode",
		Options = { "Most Players", "Random", "Least Players" },
		Default = "Least Players",
		Callback = function(arg)
			serverHopMode = tostring(arg or "Least Players")
		end,
	})

	local hopGenerationCounter = 0

	serverSection:CreateButton({
		Name = "Server Hop",
		ButtonText = "Hop",
		Callback = function()
			hopGenerationCounter = hopGenerationCounter + 1
			local myGeneration = hopGenerationCounter

			task.spawn(function()
				hopInProgress = true
				local tries = 0

				while myGeneration == hopGenerationCounter do
					tries = tries + 1
					local result = serverHop(serverHopMode)

					if not (result == "waiting" or myGeneration ~= hopGenerationCounter) then
						if result == "empty" then
							serverListCache = nil
							table.clear(blockedServers)
						end

						if tries % 10 == 0 then
							notifyUser("Server Hop", string.format("Every server was full so far, %d tries.", tries))
						end

						task.wait(result == "fetch" and 1 or 0.1)
						continue
					end

					break
				end

				if myGeneration == hopGenerationCounter then
					hopInProgress = false
				end
			end)
		end,
	})
end

do
	local serverSection = state.ServerSection
	if not serverSection and window.GetTab then
		local ok, _tab = pcall(function()
			return window:GetTab("Server")
		end)
		if ok and _tab then
			if type(_tab.GetSection) == "function" then
				pcall(function()
					serverSection = _tab:GetSection("Server")
				end)
			elseif type(_tab.CreateSection) == "function" then
				pcall(function()
					serverSection = _tab:CreateSection({ Name = "Server", Expanded = true })
				end)
			end
		end
	end
	local jobCooldownSeconds = 8
	local jobCooldownUntil = 0
	local lastJobId = ""
	local jobInputHandle = nil

	local function isOnCooldown()
		return os.clock() < jobCooldownUntil
	end

	local function setCooldown(enabled)
		jobCooldownUntil = enabled and os.clock() + jobCooldownSeconds or 0
	end

	local function cleanJobId(value)
		local trimmed = tostring(value or ""):match("^%s*(.-)%s*$")
		return trimmed:match("%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x") or trimmed
	end

	local function getJobIdFromInput()
		local fallback = lastJobId
		local current = lastJobId

		if jobInputHandle then
			local ok, result = pcall(function()
				local controller = jobInputHandle._controller
				return controller and controller.GetValue and controller.GetValue()
			end)

			if not (ok and type(result) == "string" and result ~= "") then
				local found = false

				for _, methodName in ipairs({ "Get", "GetValue", "GetText" }) do
					local ok2, methodFn = pcall(function()
						return jobInputHandle[methodName]
					end)

					if ok2 and type(methodFn) == "function" then
						local ok3, result3 = pcall(methodFn, jobInputHandle)
						if ok3 and type(result3) == "string" and result3 ~= "" then
							found = true
							current = result3
							break
						end
					end
				end

				if not found then
					current = fallback
				end
			else
				current = result
			end
		end

		local cleaned = cleanJobId(current)

		if cleaned == "" then
			local ok, clipboard = pcall(function()
				local getter = getclipboard or readclipboard or getrbxclipboard
				return type(getter) == "function" and getter() or nil
			end)

			if ok and type(clipboard) == "string" then
				cleaned = cleanJobId(clipboard)
			end
		end

		return cleaned
	end

	local function setJobId(value)
		if not jobInputHandle then
			return
		end

		pcall(function()
			local controller = jobInputHandle._controller

			if controller and controller.SetValue then
				controller.SetValue(value, false)
			end
		end)

		lastJobId = cleanJobId(value)
	end

	local function rejoinServer(errorTitle)
		setCooldown(true)

		if not pcall(function()
			if game.JobId ~= "" then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, localPlayer)
			else
				TeleportService:Teleport(game.PlaceId, localPlayer)
			end
		end) then
			setCooldown(false)
			notifyUser(errorTitle, "Roblox could not rejoin the server.")
		end
	end

	pcall(function()
		TeleportService.TeleportInitFailed:Connect(function(_, _, message)
			if not isOnCooldown() then
				return
			end
			setCooldown(false)
			notifyUser("Teleport Failed", tostring(message ~= "" and message or "Teleport failed"))
		end)
	end)

	jobInputHandle = serverSection:CreateInput({
		Name = "Job ID",
		Placeholder = "Paste a server Job ID...",
		Default = "",
		MaxLength = 100,
		Callback = function(arg)
			lastJobId = cleanJobId(arg)
		end,
	})

	if jobInputHandle then
		jobInputHandle._configIgnored = true

		if jobInputHandle.State and not jobInputHandle.State._registered then
			jobInputHandle.State._configIgnored = true
		end
	end

	serverSection:CreateButton({
		Name = "Join Job ID",
		ButtonText = "Join",
		Callback = function()
			if isOnCooldown() then
				notifyUser("Join Job ID Failed", "A teleport is already running, try again shortly.")
				return
			end
			local jobId = getJobIdFromInput()

			if jobId == "" then
				notifyUser("Join Job ID Failed", "Paste a valid Job ID first.")
				return
			end
			setCooldown(true)

			if not pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, localPlayer)
			end) then
				setCooldown(false)
				notifyUser("Join Job ID Failed", "Roblox could not join that server.")
			end
		end,
	})

	serverSection:CreateButton({
		Name = "Copy Current Job ID",
		ButtonText = "Copy",
		Callback = function()
			local currentJobId = tostring(game.JobId or "")
			setJobId(currentJobId)
			local setter = setclipboard or toclipboard
			local copied = type(setter) == "function" and pcall(setter, currentJobId) or false
			notifyUser(copied and "Job ID Copied" or "Job ID Shown", currentJobId)
		end,
	})

	serverSection:CreateButton({
		Name = "Rejoin Server",
		ButtonText = "Rejoin",
		Callback = function()
			if isOnCooldown() then
				notifyUser("Rejoin Failed", "A teleport is already running, try again shortly.")
				return
			end
			rejoinServer("Rejoin Failed")
		end,
	})

	local autoRejoinState = { Option = nil, Fired = false, TeleportingAt = 0 }

	local function hasErrorPrompt()
		local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
		promptGui = promptGui and promptGui:FindFirstChild("promptOverlay")
		return promptGui ~= nil and promptGui:FindFirstChild("ErrorPrompt") ~= nil
	end

	pcall(function()
		local connection = localPlayer.OnTeleport:Connect(function(teleportState)
			if teleportState == Enum.TeleportState.Failed then
				autoRejoinState.TeleportingAt = 0
			else
				autoRejoinState.TeleportingAt = os.clock()
			end
		end)

		registerCleanup(function()
			pcall(function()
				connection:Disconnect()
			end)
		end)
	end)

	autoRejoinState.Option = serverSection:CreateToggle({ Name = "Auto Rejoin When Disconnect", Default = true })

	local function attemptAutoRejoin(message)
		if autoRejoinState.Fired or autoRejoinState.Option == nil or not state.Toggle(autoRejoinState.Option, false) or isOnCooldown() then
			return
		end
		local teleporting = autoRejoinState.TeleportingAt > 0

		if teleporting then
			local teleportingAt = autoRejoinState.TeleportingAt
			teleporting = os.clock() - teleportingAt < 60
		end

		if teleporting then
			return
		end
		local lowerMessage = string.lower(tostring(message or ""))
		if lowerMessage == "" or string.find(lowerMessage, "teleport", 1, true) then
			return
		end
		local errorCode = nil

		pcall(function()
			errorCode = GuiService2:GetErrorCode()
		end)

		if errorCode == Enum.ConnectionError.DisconnectDuplicatePlayer or string.find(lowerMessage, "banned", 1, true) or string.find(lowerMessage, "same account", 1, true) then
			return
		end
		autoRejoinState.Fired = true
		local placeId = game.PlaceId
		local currentJobId = tostring(game.JobId or "")
		local serverClosed = string.find(lowerMessage, "shut", 1, true) ~= nil or string.find(lowerMessage, "no longer", 1, true) ~= nil or string.find(lowerMessage, "closed", 1, true) ~= nil
		notifyUser("Auto Rejoin", serverClosed and "Server closed, joining another one." or "Disconnected, rejoining now.")

		task.spawn(function()
			local try = 0

			while true do
				try = try + 1
				local useJobId = not serverClosed and currentJobId ~= "" and try <= 2

				pcall(function()
					if useJobId then
						TeleportService:TeleportToPlaceInstance(placeId, currentJobId, localPlayer)
					else
						TeleportService:Teleport(placeId, localPlayer)
					end
				end)

				task.wait(useJobId and 4 or 5)
			end
		end)
	end

	pcall(function()
		local connection = GuiService2.ErrorMessageChanged:Connect(function(message)
			task.wait(0.3)

			if hasErrorPrompt() then
				attemptAutoRejoin(message)
			end
		end)

		registerCleanup(function()
			pcall(function()
				connection:Disconnect()
			end)
		end)
	end)

	task.spawn(function()
		local promptGui = CoreGui:WaitForChild("RobloxPromptGui", 30)
		promptGui = promptGui and promptGui:WaitForChild("promptOverlay", 30)
		if not promptGui then
			return
		end

		local connection = promptGui.ChildAdded:Connect(function(child)
			if child.Name ~= "ErrorPrompt" then
				return
			end
			task.wait(0.2)
			local message = ""

			for _, descendant in ipairs(child:GetDescendants()) do
				if descendant:IsA("TextLabel") and descendant.Name == "ErrorMessage" then
					message = descendant.Text
				end
			end

			if message == "" then
				pcall(function()
					message = GuiService2:GetErrorMessage()
				end)
			end

			attemptAutoRejoin(message ~= "" and message or "disconnected")
		end)

		registerCleanup(function()
			pcall(function()
				connection:Disconnect()
			end)
		end)
	end)
end

;(function()
local predictorTab, webhookSection, eggPredictorSection, fusePredictorSection
local predictorHelpers
local notifyUserGlobal = notifyUser
local espHelpers = state.EspHelpers or {
	Sequence = function(points)
		local keypoints = table.create(#points)
		for i, point in ipairs(points) do
			keypoints[i] = ColorSequenceKeypoint.new(point[1], point[2])
		end
		return ColorSequence.new(keypoints)
	end,
}

do
	predictorTab = window:CreateTab({ Name = "Predictor", SectionsExpanded = true })
	webhookSection = predictorTab:CreateSection({ Name = "Discord Webhook", Expanded = false })
	eggPredictorSection = predictorTab:CreateSection({ Name = "Egg Predictor", Expanded = true })
	fusePredictorSection = predictorTab:CreateSection({ Name = "Fuse Predictor", Expanded = false })

	local function loadFont(path, weight)
		local ok, result = pcall(Font.new, path, weight, Enum.FontStyle.Normal)
		return ok and result or nil
	end

	predictorHelpers = {
		Ready = type(eggPredictorSection.CreateCanvas) == "function",
		Bullet = utf8.char(8226),
		Color = {
			Text = "#FFFFFF",
			Income = "#4DFF7A",
			Clock = "#FFC24D",
			Ready = "#4DFF7A",
			Growing = "#FFC24D",
			Inventory = "#7FD8FF",
			Weight = "#CDE7FF",
			Scale = "#FFDF8A",
			Separator = "#7A8CC0",
			Hint = "#9FB8FF",
		},
		NameFont = loadFont("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold),
	}

	predictorHelpers.RarityFont = loadFont("rbxassetid://12187365977", Enum.FontWeight.Bold) or loadFont("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)

	do
		local points = {
			{ 0, Color3.fromRGB(255, 255, 255) },
			{ 0.5, Color3.fromRGB(222, 238, 255) },
			{ 1, Color3.fromRGB(255, 255, 255) },
		}
		predictorHelpers.NameGradient = espHelpers.Sequence(points)
	end

	do
		local points = {
			{ 0, Color3.fromRGB(255, 255, 255) },
			{ 0.2, Color3.fromRGB(206, 212, 224) },
			{ 0.42, Color3.fromRGB(74, 80, 94) },
			{ 0.58, Color3.fromRGB(42, 46, 56) },
			{ 0.78, Color3.fromRGB(158, 166, 182) },
			{ 1, Color3.fromRGB(250, 252, 255) },
		}
		predictorHelpers.SecretGradient = espHelpers.Sequence(points)
	end

	predictorHelpers.SecretRotation = 90

	predictorHelpers.Paint = function(color, text)
		return string.format("<font color=\"%s\">%s</font>", color, text)
	end

	predictorHelpers.Bold = function(text)
		return "<b>" .. tostring(text) .. "</b>"
	end

	predictorHelpers.Escape = function(text)
		return (string.gsub(tostring(text), "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
	end

	predictorHelpers.Separator = function()
		return predictorHelpers.Paint(predictorHelpers.Color.Separator, "  " .. predictorHelpers.Bullet .. "  ")
	end

	predictorHelpers.FormatRate = function(value)
		local number = tonumber(value) or 0
		if number >= 1e12 then
			return string.format("%.2fT/s", number / 1e12)
		end

		if number >= 1e9 then
			return string.format("%.2fB/s", number / 1e9)
		end

		if number >= 1000000 then
			return string.format("%.2fM/s", number / 1000000)
		end

		if number >= 1000 then
			return string.format("%.1fK/s", number / 1000)
		end
		return string.format("%d/s", math.floor(number))
	end

	predictorHelpers.FormatWeight = function(value)
		local number = tonumber(value) or 0
		local formatted = number >= 1000 and string.format("%.0f", number) or string.format("%.2f", number)
		local whole, decimal = string.match(formatted, "^(%-?%d+)(%.%d+)$")
		whole = whole or formatted
		local result

		while true do
			local replaced, count
			result, count = string.gsub(whole, "^(%-?%d+)(%d%d%d)", "%1,%2")

			if count ~= 0 then
				whole = result
			else
				break
			end
		end

		return result .. (decimal or "") .. " Kg"
	end

	predictorHelpers.FormatClock = function(value)
		local total = math.max(0, math.floor(tonumber(value) or 0))
		return string.format("%02dh %02dm %02ds", math.floor(total / 3600), math.floor(total % 3600 / 60), total % 60)
	end

	predictorHelpers.ScaleFactor = function(scale)
		if scale > 5 then
			return (scale / 5) ^ 1.2 * 19.637875755794113
		end
		return scale ^ 1.85
	end

	predictorHelpers.MutationMultiplier = function(mutations)
		mutations = type(mutations) == "table" and mutations or {}
		local mutationsModule = modules.Mutations

		if type(mutationsModule) == "table" and type(mutationsModule.EarningsFor) == "function" then
			local ok, result = pcall(mutationsModule.EarningsFor, mutations)
			if ok and type(result) == "number" then
				return result
			end
		end

		return 1
	end

	local mutationColorMap = {
		Golden = "#FFD34D",
		Silver = "#E6EEF7",
		Sakura = "#FF9ED8",
		GreatBloom = "#7CFFC4",
		Boss = "#FF7A7A",
		Monstrous = "#C08BFF",
	}

	local rainbowColors = { "#FF6B6B", "#FFB36B", "#FFF06B", "#6BFF8A", "#6BC8FF", "#B96BFF" }

	predictorHelpers.MutationText = function(mutations)
		local parts = {}

		if type(mutations) == "table" then
			for _, mutation in ipairs(mutations) do
				local upperName = string.upper(mutationLabel(mutation))

				if mutation == "Rainbow" or mutation == "Prismatic" then
					local segments = {}

					for i = 1, #upperName do
						table.insert(segments, predictorHelpers.Paint(rainbowColors[(i - 1) % #rainbowColors + 1], string.sub(upperName, i, i)))
					end

					table.insert(parts, predictorHelpers.Bold(table.concat(segments)))
				else
					table.insert(parts, predictorHelpers.Bold(predictorHelpers.Paint(mutationColorMap[mutation] or "#8FE3FF", predictorHelpers.Escape(upperName))))
				end
			end
		end

		return table.concat(parts, " ")
	end

	local assetGradientCache = nil

	local function findRarityGradient(rarity)
		if type(rarity) == "table" and typeof(rarity.RarityGradient) == "Instance" then
			return rarity.RarityGradient
		end

		if assetGradientCache == nil then
			local assets = ReplicatedStorage:FindFirstChild("Assets")
			assets = assets and assets:FindFirstChild("UI")
			assetGradientCache = assets and assets:FindFirstChild("RarityGradients") or false
		end

		if not assetGradientCache or type(rarity) ~= "table" then
			return nil
		end
		local entry = assetGradientCache:FindFirstChild(tostring(rarity._id or rarity.DisplayName or ""))
		return entry and entry:FindFirstChild("RarityGradient") or nil
	end

	local assetInfoCache = {}

	predictorHelpers.AssetInfo = function(category)
		local key = tostring(category)
		local cached = assetInfoCache[key]
		if cached then
			return cached
		end
		local directory = modules.Assets and modules.Assets.Directory
		local assetEntry = type(directory) == "table" and directory[key] or nil

		if assetEntry == nil and type(directory) == "table" then
			local normalized = string.gsub(string.lower(key), "[^%a%d]", "")

			for k, entry in pairs(directory) do
				if type(entry) == "table" then
					local candidates = {
						tostring(k),
						tostring(entry._id or ""),
						tostring(entry.DisplayName or ""),
					}
					local eggEntry = type(entry.Egg) == "table" and entry.Egg or nil

					if eggEntry ~= nil then
						candidates[#candidates + 1] = tostring(eggEntry.ModelName or "")
					end

					for _, candidate in ipairs(candidates) do
						if candidate ~= "" and string.gsub(string.lower(candidate), "[^%a%d]", "") == normalized then
							assetEntry = entry
							break
						end
					end
				end

				if assetEntry == nil then
					continue
				end
				break
			end
		end

		local rarity = type(assetEntry) == "table" and type(assetEntry.Rarity) == "table" and assetEntry.Rarity or nil
		local icon = type(assetEntry) == "table" and assetEntry.Icon or nil
		local rarityName
		if rarity then
			rarityName = tostring(rarity.DisplayName or rarity._id or "Common")
		else
			rarityName = rarity
		end
		rarityName = rarityName or "Common"
		local color = rarity and typeof(rarity.Color) == "Color3" and rarity.Color or Color3.fromRGB(255, 255, 255)
		local info = {}
		local displayName
		if type(assetEntry) == "table" then
			displayName = tostring(assetEntry.DisplayName or key)
		end
		info.Name = displayName or key
		info.Category = key
		info.Rarity = rarityName
		local rarityNumber
		if rarity then
			rarityNumber = tonumber(rarity.RarityNumber or rarity.Rank)
		else
			rarityNumber = rarity
		end
		info.RarityNumber = rarityNumber or 0
		info.Color = color
		info.Hex = "#" .. string.upper(color:ToHex())
		info.Gradient = findRarityGradient(rarity)
		info.EarningRate = type(assetEntry) == "table" and tonumber(assetEntry.EarningRate) or 0
		info.Icon = type(icon) == "string" and icon ~= "" and icon or nil
		assetInfoCache[key] = info
		return info
	end

	predictorHelpers.Income = function(info, scale, mutations)
		if type(scale) ~= "number" or scale <= 0 then
			return 0
		end
		return math.max(math.round(info.EarningRate * predictorHelpers.ScaleFactor(scale) * predictorHelpers.MutationMultiplier(mutations)), 1)
	end

	local function isShown(instance)
		if typeof(instance) ~= "Instance" or not instance:IsDescendantOf(game) then
			return false
		end

		while instance do
			if instance:IsA("GuiObject") and not instance.Visible then
				return false
			end

			if instance:IsA("LayerCollector") then
				return instance.Enabled
			end
			instance = instance.Parent
		end

		return false
	end

	predictorHelpers.IsShown = isShown

	predictorHelpers.PageVisible = function()
		local ok, page = pcall(function()
			return predictorTab.Page
		end)

		if not ok or typeof(page) ~= "Instance" then
			return true
		end
		return isShown(page) and page.AbsoluteSize.X > 0
	end
end

local predictorSortOptions = { "Value", "Rarity", "Time Left" }
local predictorStatusSections = {
	{ Key = "Ready", Title = "READY TO HATCH", Color = predictorHelpers.Color.Ready },
	{ Key = "Growing", Title = "GROWING", Color = predictorHelpers.Color.Growing },
	{ Key = "Inventory", Title = "IN INVENTORY", Color = predictorHelpers.Color.Inventory },
}

local predictorRefreshInterval = 1
local predictorPaint = predictorHelpers.Paint
local predictorBold = predictorHelpers.Bold
local predictorColor = predictorHelpers.Color

local predictorConfig = { Sort = predictorSortOptions[1], Spotlight = true }
local selectedEggId = nil
local relayoutDebounce = 0.0909
local spotlightCard = nil
local entryRows = {}
local infoRows = {}
local prebuiltRows = {}
local highlightedEgg = nil
local eggDataCache = nil
local lastSortByRarity = 0
local lastSortByTime = 0
local lastSortByValue = 0
local lastCanvasWidth = -1
local lastCanvasHeight = -1
local lastContentLines = -1
local minNameWidth = 4
local minRarityWidth = 3
local forceRelayout = false
local relayoutFramesLeft = 0
local refreshRequested = true
local heatmapInterval = 3
local needsRefresh = false

do
	local function diffWrap(handle)
		if not handle or handle.DiffWrapped then
			return handle
		end
		local originalSet = handle.Set
		handle.DiffWrapped = true

		handle.Set = function(payload)
			if type(payload) ~= "table" then
				return originalSet(payload)
			end
			local spec = handle.Spec
			local diff = nil

			for key, value in pairs(payload) do
				if spec[key] ~= value then
					diff = diff or {}
					diff[key] = value
				end
			end

			if diff then
				originalSet(diff)
			end

			return handle
		end

		return handle
	end

	local function buildRowKey(handle, suffix)
		local shape = string.gsub(tostring(handle.Spec.Text or ""), "%d", "0")
		return tostring(lastSortByTime) .. "|" .. tostring(suffix) .. "|" .. shape
	end

	local function growthSecondsRemaining(record, serverTime)
		local eggRecords = modules.EggRecords
		if type(eggRecords) ~= "table" or type(eggRecords.GrowthSecondsRemaining) ~= "function" then
			return 0, 0
		end
		local speedMultiplier = 1

		if type(eggRecords.GrowthSpeedMultiplier) == "function" then
			local ok, result = pcall(eggRecords.GrowthSpeedMultiplier, record)

			if ok and type(result) == "number" then
				speedMultiplier = result
			end
		end

		local ok, remaining = pcall(eggRecords.GrowthSecondsRemaining, record, serverTime, speedMultiplier)
		ok = ok and type(remaining) == "number"

		if not ok then
			remaining = 0
		end

		local totalDuration = 0

		if type(eggRecords.GrowthDuration) == "function" then
			local ok2, duration = pcall(eggRecords.GrowthDuration, record)
			ok2 = ok2 and type(duration) == "number"

			if not ok2 then
				duration = 0
			end

			totalDuration = duration
		end

		return remaining, totalDuration
	end

	local function weightKg(record)
		local eggRecords = modules.EggRecords

		if type(eggRecords) == "table" and type(eggRecords.WeightKg) == "function" then
			local ok, result = pcall(eggRecords.WeightKg, record)
			if ok and type(result) == "number" then
				return result
			end
		end

		return 0
	end

	local function readOwnerEggs()
		local eggState = modules.EggState
		if type(eggState) ~= "table" or type(eggState.ReadOwnerEggs) ~= "function" then
			return nil
		end
		local ok, result = pcall(eggState.ReadOwnerEggs, localPlayer.UserId)
		if not ok or type(result) ~= "table" then
			return nil
		end
		local serverTime = workspace:GetServerTimeNow()
		local entries = {}

		for uid, record in pairs(result) do
			if type(record) == "table" then
				local info = predictorHelpers.AssetInfo(record.AssetCategory)
				local scale = tonumber(record.AssetScale) or 0
				local mutations = type(record.Mutations) == "table" and record.Mutations or {}

				local entry = {
					Id = uid,
					Info = info,
					Scale = scale,
					Weight = weightKg(record),
					Mutations = mutations,
					Income = predictorHelpers.Income(info, scale, mutations),
					Status = "Inventory",
					Remaining = math.huge,
					Percent = 0,
				}

				if record.Placement ~= nil then
					local ok2, isReady = pcall(eggState.IsReadyToHatch, uid)

					if ok2 and isReady then
						entry.Status = "Ready"
						entry.Remaining = 0
						entry.Percent = 100
					else
						local remaining, duration = growthSecondsRemaining(record, serverTime)
						entry.Status = "Growing"
						entry.Remaining = remaining

						if duration > 0 then
							entry.Percent = math.clamp(math.floor((1 - remaining / duration) * 100), 0, 100)
						end
					end
				end

				table.insert(entries, entry)
			end
		end

		return entries
	end

	local function sortEggs(entries)
		local sort = predictorConfig.Sort

		table.sort(entries, function(a, b)
			if sort == predictorSortOptions[2] and a.Info.RarityNumber ~= b.Info.RarityNumber then
				return a.Info.RarityNumber > b.Info.RarityNumber
			end

			if sort == predictorSortOptions[3] and a.Remaining ~= b.Remaining then
				return a.Remaining < b.Remaining
			end
			return a.Income > b.Income
		end)
	end

	local function describeRowStatus(entry)
		if entry.Status == "Ready" then
			return predictorBold(predictorPaint(predictorColor.Ready, "Ready to hatch"))
		end

		if entry.Status == "Growing" then
			return predictorBold(predictorPaint(predictorColor.Clock, predictorHelpers.FormatClock(entry.Remaining)))
				.. predictorHelpers.Separator()
				.. predictorPaint(predictorColor.Growing, entry.Percent .. "%")
		end
		return predictorPaint(predictorColor.Inventory, "In inventory")
	end

	local function describeRowDetail(entry)
		local parts = {}
		local mutationText = predictorHelpers.MutationText(entry.Mutations)
		table.insert(parts, predictorBold(predictorPaint(predictorColor.Income, predictorHelpers.FormatRate(entry.Income))))
		table.insert(parts, predictorPaint(predictorColor.Scale, string.format("%.2fx", entry.Scale)))
		table.insert(parts, predictorPaint(predictorColor.Weight, predictorHelpers.FormatWeight(entry.Weight)))

		if mutationText ~= "" then
			table.insert(parts, mutationText)
		end

		return table.concat(parts, predictorHelpers.Separator())
	end

	local rowIconSize = 5
	local rowNameX = rowIconSize + 0.8
	local rowTitleHeight = 1.2
	local rowNameScale = 1.2
	local rowRarityScale = 0.936
	local entryIconSize = 2.3
	local entryIconX = 0.25
	local entryIconOffset = entryIconSize + 0.6
	local entryGap = 0.24
	local infoGap = 0.22

	local function pickPalette(info)
		if string.upper(tostring(info.Rarity)) == "SECRET" then
			return predictorHelpers.SecretGradient
		end
		return info.Gradient
	end

	local function pickRarityColor(info)
		return pickPalette(info) ~= nil and Color3.fromRGB(255, 255, 255) or info.Color
	end

	local function pickRarityRotation(info)
		if string.upper(tostring(info.Rarity)) == "SECRET" then
			return predictorHelpers.SecretRotation
		end
		return nil
	end

	local function getHandleText(handle)
		local current = handle and handle.Get()
		if not current or lastSortByTime <= 0 then
			return nil
		end

		if current.Text ~= tostring(handle.Spec.Text or "") then
			return nil
		end
		return current
	end

	local function measureWidth(handle)
		local cacheKey = buildRowKey(handle, "w")
		if handle.WidthKey == cacheKey then
			return handle.WidthUnits
		end
		local current = getHandleText(handle)
		if not current then
			return nil
		end
		local originalSize = current.Size
		local textWrapped = current.TextWrapped
		current.TextWrapped = false
		current.Size = UDim2.fromOffset(100000, math.max(1, originalSize.Y.Offset))
		local measuredWidth = current.TextBounds.X
		current.Size = originalSize
		current.TextWrapped = textWrapped
		if measuredWidth <= 0 then
			return nil
		end
		local units = measuredWidth / lastSortByTime
		handle.WidthKey = cacheKey
		handle.WidthUnits = units
		return handle.WidthUnits
	end

	local function measureHeight(handle, lineHeight)
		local cacheKey = buildRowKey(handle, math.floor(lineHeight * 100 + 0.5))
		if handle.HeightKey == cacheKey then
			return handle.HeightUnits
		end
		local current = getHandleText(handle)
		if not current then
			return nil
		end
		local originalSize = current.Size
		current.Size = UDim2.fromOffset(math.max(1, math.floor(lineHeight * lastSortByTime + 0.5)), 100000)
		local measuredHeight = current.TextBounds.Y
		current.Size = originalSize
		if measuredHeight <= 0 then
			return nil
		end
		local units = measuredHeight / lastSortByTime
		handle.HeightKey = cacheKey
		handle.HeightUnits = units
		return handle.HeightUnits
	end

	local function requestHatch(uid)
		local remote = networking:FindFirstChild("RF/EggWorld/AskHatch")
		if not remote or not remote:IsA("RemoteFunction") then
			return false
		end
		local ok, result = pcall(remote.InvokeServer, remote, uid)
		if not ok or result == false then
			return false
		end
		task.wait(0.35)
		local finishRemote = networking:FindFirstChild("RF/EggWorld/AskFinishHatch")

		if finishRemote and finishRemote:IsA("RemoteFunction") then
			pcall(finishRemote.InvokeServer, finishRemote, uid)
		end

		return true
	end

	local spotlightFlying = false

	local function runEggAction()
		local focus = spotlightCard.Focus
		if type(focus) ~= "table" or focus.Id == nil then
			return
		end
		local uid = tostring(focus.Id)

		if focus.Status == "Inventory" then
			local eggState = modules.EggState
			if type(eggState) == "table" and type(eggState.WearEggTool) == "function" and pcall(eggState.WearEggTool, uid) then
				return
			end
			local remote = networking:FindFirstChild("RF/EggWorld/AskWearTool")

			if remote and remote:IsA("RemoteFunction") then
				pcall(remote.InvokeServer, remote, uid)
			end

			return
		end

		if focus.Status == "Ready" then
			if not spotlightFlying then
				spotlightFlying = true
				pcall(requestHatch, uid)
				spotlightFlying = false
			end

			return
		end

		if state.Flying or type(state.FlyTo) ~= "function" then
			return
		end
		local placedEggRenders = workspace:FindFirstChild("PlacedEggRenders")
		local model = nil

		if placedEggRenders then
			for _, child in ipairs(placedEggRenders:GetChildren()) do
				if string.find(child.Name, uid, 1, true) or child:GetAttribute("Uid") == uid then
					model = child
					break
				end
			end
		end

		if not model then
			return
		end

		local ok, pivot = pcall(function()
			return model:IsA("Model") and model:GetPivot() or model.CFrame
		end)

		if not ok then
			return
		end
		local movement = state.Movement
		if (movement.Owner ~= nil and movement.Owner ~= "treadmill") or movement.PlaceWanted or state.Steal.Active or state.Steal.Wanted or state.Steal.Carrying then
			return
		end
		spotlightFlying = true

		if state.ClaimMovement("predictor") then
			if state.Treadmill.Riding or state.OnBelt() then
				pcall(state.ExitBelt)
			end

			pcall(state.FlyTo, pivot.Position + Vector3.new(0, 3, 0), function()
				return false
			end, "fly")

			state.ReleaseMovement("predictor")
		end

		spotlightFlying = false
	end

	spotlightCard = { RunAction = runEggAction }

	local function buildSpotlight(canvas)
		canvas:SetDock(5, { Gap = infoGap, DividerColor = Color3.fromRGB(170, 174, 184) })
		local dock = canvas:Dock()

		spotlightCard.Icon = canvas:Image({
			Parent = dock,
			X = 0,
			Y = 0,
			Width = rowIconSize,
			Height = rowIconSize,
			Corner = 0.35,
			Background = "#000000",
			BackgroundTransparency = 0.26,
			StrokeThickness = relayoutDebounce,
			StrokeTransparency = 0,
			ZIndex = 8,
		})

		spotlightCard.Name = canvas:Text({
			Parent = dock,
			X = rowNameX,
			Y = 0,
			Height = rowTitleHeight,
			Scale = rowNameScale,
			Wrap = false,
			Gradient = predictorHelpers.NameGradient,
			TextStrokeTransparency = 1,
			ZIndex = 9,
		})

		spotlightCard.Rarity = canvas:Text({
			Parent = dock,
			X = rowNameX,
			Y = 0,
			Height = rowTitleHeight,
			Scale = rowRarityScale,
			Wrap = false,
			Font = predictorHelpers.RarityFont,
			TextStrokeTransparency = 1,
			StrokeTransparency = 0.08,
			ZIndex = 9,
		})

		spotlightCard.Info = canvas:Text({ Parent = dock, X = rowNameX, Y = rowTitleHeight, Height = rowIconSize - rowTitleHeight, Wrap = false, ZIndex = 9 })

		spotlightCard.Action = canvas:Button({
			Parent = dock,
			X = 0,
			Y = 0,
			Width = 5,
			Height = rowTitleHeight - 0.1,
			Text = "",
			Scale = 1,
			Background = "#000000",
			BackgroundTransparency = 0.55,
			HoverTransparency = 0.3,
			PressTransparency = 0.15,
			Corner = 0.35,
			StrokeColor = Color3.fromRGB(255, 255, 255),
			StrokeThickness = relayoutDebounce,
			StrokeTransparency = 0.6,
			Visible = false,
			ZIndex = 10,
			Callback = function()
				if type(spotlightCard.RunAction) == "function" then
					task.spawn(spotlightCard.RunAction)
				end
			end,
		})

		canvas:OnResize(function(_, width, height)
			if width == lastCanvasWidth and height == lastCanvasHeight then
				return
			end
			lastCanvasWidth = width
			lastCanvasHeight = height
			lastSortByRarity = width / math.max(height, 1)
			lastSortByTime = height
			relayoutFramesLeft = 2
			relayoutDebounce = 0.9 / math.max(canvas:TextSize(), 1)
			spotlightCard.Rarity.Set({ StrokeThickness = relayoutDebounce })

			for _, row in ipairs(entryRows) do
				row.Rarity.Set({ StrokeThickness = relayoutDebounce })
			end
		end)

		for _, key in ipairs({ "Icon", "Name", "Rarity", "Info", "Action" }) do
			diffWrap(spotlightCard[key])
		end
	end

	local function getInfoRow(index)
		local row = infoRows[index]

		if not row then
			row = spotlightCard.TempText or predictorHelpers and nil
			row = spotlightCard.Icon and nil
			row = nil
		end

		row = infoRows[index]

		if not row then
			row = predictorHelpers and nil
			row = spotlightCard.Icon and nil
			row = nil
		end

		row = infoRows[index]

		if not row then
			row = nil
		end

		return row
	end

	local function createInfoRow(index)
		local existing = infoRows[index]
		if existing then
			return existing
		end
		local row = spotlightCard.Canvas and spotlightCard.Canvas:Text({ Name = "Line", X = 0, Y = 0, Width = 1, Height = 1, Wrap = true, Visible = false })
		if row then
			row = diffWrap(row)
		end
		infoRows[index] = row
		return row
	end

	local function getEntryRow(index)
		local row = entryRows[index]
		if row then
			return row
		end
		local newRow = {
			Frame = spotlightCard.Canvas:Button({
				Name = "Entry",
				Text = "",
				Background = "#000000",
				BackgroundTransparency = 0.74,
				HoverTransparency = 0.46,
				PressTransparency = 0.3,
				Corner = 0.35,
				X = 0,
				Y = 0,
				Width = 1,
				Height = 1,
				Visible = false,
				Callback = function()
					if newRow.Id ~= nil then
						selectedEggId = newRow.Id
						refreshRequested = true
					end
				end,
			}),
		}

		newRow.Icon = spotlightCard.Canvas:Image({
			Parent = newRow.Frame,
			X = entryIconX,
			Y = 0,
			Width = entryIconSize,
			Height = entryIconSize,
			Corner = 0.35,
			Background = "#000000",
			BackgroundTransparency = 0.45,
			StrokeThickness = relayoutDebounce,
			StrokeTransparency = 0,
		})

		newRow.Name = spotlightCard.Canvas:Text({
			Parent = newRow.Frame,
			X = entryIconX + entryIconOffset,
			Y = 0,
			Width = 1,
			Height = rowTitleHeight,
			Scale = rowNameScale,
			Wrap = false,
			Gradient = predictorHelpers.NameGradient,
			TextStrokeTransparency = 1,
		})

		newRow.Rarity = spotlightCard.Canvas:Text({
			Parent = newRow.Frame,
			X = entryIconX + entryIconOffset,
			Y = 0,
			Width = 1,
			Height = rowTitleHeight,
			Scale = rowRarityScale,
			Wrap = false,
			Font = predictorHelpers.RarityFont,
			TextStrokeTransparency = 1,
			StrokeTransparency = 0.08,
			StrokeThickness = relayoutDebounce,
		})

		newRow.Detail = spotlightCard.Canvas:Text({
			Parent = newRow.Frame,
			X = entryIconX + entryIconOffset,
			Y = rowTitleHeight,
			Width = math.max(1, lastSortByRarity - entryIconOffset - entryIconX * 2),
			Height = 1,
			Wrap = true,
		})

		newRow.Status = spotlightCard.Canvas:Text({ Parent = newRow.Frame, X = 0, Y = 0, Width = 1, Height = rowTitleHeight, Wrap = false, Align = "Right" })

		for _, key in ipairs({ "Frame", "Icon", "Name", "Rarity", "Detail", "Status" }) do
			diffWrap(newRow[key])
		end

		entryRows[index] = newRow
		return newRow
	end

	local function buildSummary(entries)
		local counts = { Ready = 0, Growing = 0, Inventory = 0 }
		local totalIncome = 0
		local bestEntry = nil

		for _, entry in ipairs(entries) do
			counts[entry.Status] = counts[entry.Status] + 1
			totalIncome = totalIncome + entry.Income

			if not bestEntry or entry.Income > bestEntry.Income then
				bestEntry = entry
			end
		end

		return predictorBold(predictorPaint(predictorColor.Text, tostring(#entries) .. " eggs"))
			.. predictorHelpers.Separator()
			.. predictorBold(predictorPaint(predictorColor.Ready, counts.Ready .. " ready"))
			.. predictorHelpers.Separator()
			.. predictorBold(predictorPaint(predictorColor.Growing, counts.Growing .. " growing"))
			.. predictorHelpers.Separator()
			.. predictorBold(predictorPaint(predictorColor.Inventory, counts.Inventory .. " in bag"))
			.. predictorHelpers.Separator()
			.. predictorPaint(predictorColor.Text, "Total")
			.. " "
			.. predictorBold(predictorPaint(predictorColor.Income, predictorHelpers.FormatRate(totalIncome))),
			bestEntry
	end

	local function passesFilter(entry, query)
		if query == "" then
			return true
		end
		local statusSuffix = " " .. entry.Status
		local haystack = string.lower(tostring(entry.Info.Name) .. " " .. tostring(entry.Info.Rarity) .. statusSuffix)

		for _, mutation in ipairs(entry.Mutations) do
			haystack = haystack .. " " .. string.lower(tostring(mutation))
		end

		return string.find(haystack, query, 1, true) ~= nil
	end

	local function buildInfoText(entry)
		local parts = {}
		local income = predictorBold(predictorPaint(predictorColor.Income, predictorHelpers.FormatRate(entry.Income)))
		local metrics = predictorPaint(predictorColor.Scale, string.format("%.2fx", entry.Scale))
			.. predictorHelpers.Separator()
			.. predictorPaint(predictorColor.Weight, predictorHelpers.FormatWeight(entry.Weight))
		parts[1] = income
		parts[2] = metrics

		do
			local values = table.pack(describeRowStatus(entry))
			table.move(values, 1, values.n, 3, parts)
		end

		local mutationText = predictorHelpers.MutationText(entry.Mutations)
		table.insert(parts, mutationText ~= "" and mutationText or predictorPaint(predictorColor.Hint, "Tap an egg below to preview it"))
		return table.concat(parts, "\n")
	end

	local function setSpotlight(entry)
		local shouldShow = predictorConfig.Spotlight and entry ~= nil

		if highlightedEgg ~= shouldShow then
			highlightedEgg = shouldShow
			spotlightCard.Canvas:SetDock(shouldShow and 5 or 0, { Gap = infoGap })
		end

		spotlightCard.Icon.Set({ Visible = shouldShow })
		spotlightCard.Name.Set({ Visible = shouldShow })
		spotlightCard.Rarity.Set({ Visible = shouldShow })
		spotlightCard.Info.Set({ Visible = shouldShow })
		spotlightCard.Action.Set({ Visible = shouldShow })
		spotlightCard.Focus = shouldShow and entry or nil
		if not shouldShow then
			return
		end
		local info = entry.Info

		spotlightCard.Action.Set({
			Text = entry.Status == "Inventory" and predictorBold(predictorPaint(predictorColor.Inventory, "Hold egg"))
				or entry.Status == "Ready" and predictorBold(predictorPaint(predictorColor.Ready, "Hatch egg"))
				or predictorBold(predictorPaint(predictorColor.Growing, "Fly to egg")),
		})

		spotlightCard.Icon.Set({ Visible = info.Icon ~= nil, Image = info.Icon or "", StrokeColor = info.Color })
		spotlightCard.Name.Set({ Text = predictorHelpers.Escape(info.Name) })

		spotlightCard.Rarity.Set({
			Text = string.upper(tostring(info.Rarity)),
			Color = pickRarityColor(info),
			Gradient = pickPalette(info),
			GradientRotation = pickRarityRotation(info),
		})

		spotlightCard.Info.Set({ Text = buildInfoText(entry) })
	end

	local function updateRow(row, entry)
		local info = entry.Info
		row.Id = entry.Id
		row.Frame.Set({ Visible = true, BackgroundTransparency = entry.Id == selectedEggId and 0.12 or 0.74 })
		row.Icon.Set({ Visible = info.Icon ~= nil, Image = info.Icon or "", StrokeColor = info.Color })
		row.Name.Set({ Text = predictorHelpers.Escape(info.Name) })

		row.Rarity.Set({
			Text = string.upper(tostring(info.Rarity)),
			Color = pickRarityColor(info),
			Gradient = pickPalette(info),
			GradientRotation = pickRarityRotation(info),
		})

		row.Detail.Set({ Text = describeRowDetail(entry) })
		row.Status.Set({ Text = describeRowStatus(entry) })
	end

	local function layoutAll()
		if lastSortByRarity <= 0 then
			return
		end
		forceRelayout = false
		local availableWidth = math.max(1, lastSortByRarity - rowNameX)
		local actionUnits = measureWidth(spotlightCard.Action)

		if actionUnits then
			spotlightCard.ActionUnits = actionUnits + 1.4
		else
			forceRelayout = true
		end

		local actionWidth = math.min(spotlightCard.ActionUnits or 5, availableWidth * 0.45)
		local remainingWidth = math.max(1, availableWidth - actionWidth - entryGap)
		spotlightCard.Action.Set({ X = lastSortByRarity - actionWidth, Y = 0.05, Width = actionWidth, Height = rowTitleHeight - 0.1 })
		local rarityWidth = measureWidth(spotlightCard.Rarity)

		if rarityWidth then
			minRarityWidth = rarityWidth + 0.1
		else
			forceRelayout = true
		end

		local nameWidth = measureWidth(spotlightCard.Name)

		if nameWidth then
			minNameWidth = math.min(nameWidth + 0.1, math.max(1, remainingWidth - minRarityWidth - entryGap))
		else
			forceRelayout = true
		end

		spotlightCard.Name.Set({ X = rowNameX, Y = 0, Width = minNameWidth, Height = rowTitleHeight })

		spotlightCard.Rarity.Set({
			X = rowNameX + minNameWidth + entryGap,
			Y = 0,
			Width = math.max(0.5, math.min(minRarityWidth, remainingWidth - minNameWidth - entryGap)),
			Height = rowTitleHeight,
		})

		spotlightCard.Info.Set({ X = rowNameX, Y = rowTitleHeight, Width = availableWidth, Height = math.max(1, rowIconSize - rowTitleHeight) })
		local innerWidth = math.max(1, lastSortByRarity - entryIconOffset - entryIconX * 2)
		local cursorY = 0

		for _, row in ipairs(prebuiltRows) do
			if row.Kind == "text" then
				local handle = row.Handle
				local measured = measureHeight(handle, lastSortByRarity)

				if measured then
					row.Height = measured
				else
					forceRelayout = true
				end

				local height = math.max(1, row.Height or 1)
				handle.Set({ X = 0, Y = cursorY + (row.Gap and 0.5 or 0), Width = lastSortByRarity, Height = height })
				cursorY = cursorY + height + infoGap * 0.5 + (row.Gap and 0.5 or 0)
			else
				local entryRow = row.Item
				local detailHeight = measureHeight(entryRow.Detail, innerWidth)

				if detailHeight then
					entryRow.DetailUnits = detailHeight
				else
					forceRelayout = true
				end

				local detailUnits = math.clamp(entryRow.DetailUnits or 1, 1, 4)
				local statusWidth = measureWidth(entryRow.Status)

				if statusWidth then
					entryRow.StatusUnits = statusWidth + 0.23
				else
					forceRelayout = true
				end

				local statusUnits = math.min(innerWidth * 0.42, math.max(2.73, entryRow.StatusUnits or 2.73))
				local nameArea = math.max(1, innerWidth - statusUnits - entryGap)
				local rarityUnits = measureWidth(entryRow.Rarity)

				if rarityUnits then
					entryRow.RarityUnits = rarityUnits + 0.1
				else
					forceRelayout = true
				end

				local rarityWidth2 = math.min(entryRow.RarityUnits or 3, nameArea * 0.5)
				local nameUnits = measureWidth(entryRow.Name)

				if nameUnits then
					entryRow.NameUnits = nameUnits + 0.1
				else
					forceRelayout = true
				end

				local nameWidth2 = math.min(math.max(1, entryRow.NameUnits or 4), math.max(1, nameArea - rarityWidth2 - entryGap))
				local padding = entryGap * 2
				local totalHeight = math.max(detailUnits + rowTitleHeight, 2.3) + padding
				local verticalPad = (totalHeight - detailUnits - rowTitleHeight) / 2
				entryRow.Frame.Set({ X = 0, Y = cursorY, Width = lastSortByRarity, Height = totalHeight })
				entryRow.Icon.Set({ Y = (totalHeight - entryIconSize) / 2 })
				entryRow.Name.Set({ X = entryIconX + entryIconOffset, Y = verticalPad, Width = nameWidth2 })
				entryRow.Rarity.Set({ X = entryIconX + entryIconOffset + nameWidth2 + entryGap, Y = verticalPad, Width = math.max(0.5, rarityWidth2) })
				entryRow.Detail.Set({ X = entryIconX + entryIconOffset, Y = verticalPad + rowTitleHeight, Width = innerWidth, Height = detailUnits })

				entryRow.Status.Set({
					Visible = row.HasStatus,
					X = entryIconX + entryIconOffset + innerWidth - statusUnits,
					Y = verticalPad,
					Width = math.max(0.5, statusUnits),
				})

				cursorY = cursorY + totalHeight + infoGap
			end
		end

		local totalHeight = math.max(1, cursorY)

		if math.abs(totalHeight - lastContentLines) > 0.01 then
			lastContentLines = totalHeight
			spotlightCard.Canvas:SetContentLines(totalHeight)
		end
	end

	local function refreshEggPredictor()
		if not spotlightCard or not spotlightCard.Canvas then
			return
		end

		relayoutFramesLeft = 2
		local entries = readOwnerEggs()
		table.clear(prebuiltRows)
		local textRowCount = 0

		local function addTextRow(text, gap)
			textRowCount = textRowCount + 1
			local handle = createInfoRow(textRowCount)
			handle.Set({ Visible = true, Text = text })
			table.insert(prebuiltRows, { Kind = "text", Handle = handle, Gap = gap })
		end

		local bestEntry

		if not entries then
			setSpotlight(nil)
			addTextRow(predictorBold(predictorPaint(predictorColor.Hint, "Egg data is not available yet")), false)
			bestEntry = nil
		else
			sortEggs(entries)
			local summaryText, best = buildSummary(entries)
			addTextRow(summaryText, false)
			local selectedEntry = nil

			if selectedEggId ~= nil then
				selectedEntry = nil

				for _, entry in ipairs(entries) do
					if entry.Id == selectedEggId then
						selectedEntry = entry
						break
					else
						selectedEntry = nil
					end
				end
			end

			setSpotlight(selectedEntry or best)
			local query = string.lower(spotlightCard.Canvas:Query())
			local filtered = {}

			for _, entry in ipairs(entries) do
				if passesFilter(entry, query) then
					table.insert(filtered, entry)
				end
			end

			if #filtered == 0 then
				addTextRow(predictorPaint(predictorColor.Hint, #entries == 0 and "No eggs yet" or string.format("No results for \"%s\"", predictorHelpers.Escape(query))), false)
				bestEntry = nil
			else
				bestEntry = 0

				for _, section in ipairs(predictorStatusSections) do
					local sectionEntries = {}

					for _, entry in ipairs(filtered) do
						if entry.Status == section.Key then
							table.insert(sectionEntries, entry)
						end
					end

					if #sectionEntries > 0 then
						local needsGap = #prebuiltRows > 0
						addTextRow(string.format("<b><font color=\"%s\">%s</font></b> <font color=\"#AAAAAA\">(%d)</font>", section.Color, section.Title, #sectionEntries), needsGap)

						for _, entry in ipairs(sectionEntries) do
							bestEntry = bestEntry + 1
							local row = getEntryRow(bestEntry)
							updateRow(row, entry)
							table.insert(prebuiltRows, { Kind = "item", Item = row, HasStatus = true })
						end
					end
				end
			end
		end

		for i = textRowCount + 1, #infoRows do
			infoRows[i].Set({ Visible = false })
		end

		for i = (bestEntry or 0) + 1, #entryRows do
			entryRows[i].Frame.Set({ Visible = false })
		end

		layoutAll()
		relayoutFramesLeft = 2
	end

	predictorHelpers.RequestEggRefresh = function()
		refreshRequested = true
	end

	if not predictorHelpers.Ready then
		eggPredictorSection:CreateText({ Name = "Egg Predictor", Text = "Live predictor card is not available in the ModernV2 UI." })
	else
			eggPredictorSection:CreateDropdown({
				Name = "Sort By",
				Options = predictorSortOptions,
				Default = predictorSortOptions[1],
				Callback = function(sort)
					if table.find(predictorSortOptions, sort) then
						predictorConfig.Sort = sort
						refreshRequested = true
					end
				end,
			})

			eggPredictorSection:CreateToggle({
				Name = "Preview Card",
				Default = true,
				Callback = function(arg)
					predictorConfig.Spotlight = arg == true
					refreshRequested = true
				end,
			})

			local predictorCanvas = eggPredictorSection:CreateCanvas({
				Name = "Egg Predictor",
				Search = true,
				SearchPlaceholder = "Search eggs...",
				Layout = "free",
				Style = {
					TextScale = 0.84,
					LineHeight = 1.1,
					MinLines = 16,
					MaxLines = 32,
					BackgroundTransparency = 0.5,
					ScrollBarColor = Color3.fromRGB(170, 174, 184),
					TextColor = Color3.fromRGB(255, 255, 255),
					TextStrokeTransparency = 0.7,
				},
				Build = function(canvas)
					spotlightCard.Canvas = canvas
					spotlightCard.TempText = nil
					local okBuild, errBuild = pcall(buildSpotlight, canvas)
					if not okBuild then
						debugPrint("[EggPredictor Build Error] " .. tostring(errBuild))
					end
					refreshRequested = true
				end,
			})

			registerCleanup(function()
				predictorCanvas:Destroy()
			end)

			local predictorHeartbeat = RunService.Heartbeat:Connect(function(deltaTime)
				local pageVisible = predictorHelpers.PageVisible()
				local root = spotlightCard and spotlightCard.Canvas and spotlightCard.Canvas:Root()
				local shouldRender

				if pageVisible then
					shouldRender = root == nil or predictorHelpers.IsShown(root) or (root.Parent ~= nil and root.Visible)
				else
					shouldRender = false
				end

				if shouldRender and not needsRefresh then
					refreshRequested = true
				end

				needsRefresh = shouldRender
				if not pageVisible then
					return
				end
				heatmapInterval = heatmapInterval + deltaTime

				if shouldRender and refreshRequested or heatmapInterval >= predictorRefreshInterval then
					heatmapInterval = 0

					if shouldRender then
						refreshRequested = false
						local okRefresh, errRefresh = pcall(refreshEggPredictor)
						if not okRefresh then
							debugPrint("[EggPredictor Refresh Error] " .. tostring(errRefresh))
						end
					end

					if predictorHelpers.RefreshFuse then
						pcall(predictorHelpers.RefreshFuse)
					end
				end

				if shouldRender and (relayoutFramesLeft > 0 or forceRelayout) then
					if relayoutFramesLeft > 0 then
						relayoutFramesLeft = relayoutFramesLeft - 1
					end

					pcall(layoutAll)
				end

				if predictorHelpers.PlaceFuse then
					predictorHelpers.PlaceFuse()
				end
			end)

			registerCleanup(function()
				predictorHeartbeat:Disconnect()
			end)
		end
	end

local paint2, bold2, color3

do
	local scaleBandTable = {
		{ min = 0.85, max = 1.05, weight = 2000 },
		{ min = 1.45, max = 1.55, weight = 250 },
		{ min = 1.9, max = 2.1, weight = 125 },
		{ min = 2.85, max = 3.15, weight = 62.5 },
		{ min = 3.8, max = 4.2, weight = 31.25 },
		{ min = 0.3, max = 0.45, weight = 18 },
		{ min = 0.1, max = 0.2, weight = 5 },
		{ min = 5.8, max = 6.2, weight = 15.625 },
		{ min = 9.5, max = 12.5, weight = 3 },
		{ min = 12, max = 17, weight = 0.05 },
		{ min = 20, max = 35, weight = 0.0001 },
	}

	paint2 = predictorHelpers.Paint
	bold2 = predictorHelpers.Bold
	color3 = predictorHelpers.Color

	local fuseRowIconSize = 5
	local fuseRowNameX = fuseRowIconSize + 0.8
	local fuseRowTitleHeight = 1.2
	local fuseRowNameScale = 1.2
	local fuseRowRarityScale = 0.936
	local fuseEntryIconSize = 2.3
	local fuseEntryIconX = 0.25
	local fuseEntryIconOffset = fuseEntryIconSize + 0.6
	local fuseEntryGap = 0.24
	local fuseInfoGap = 0.22
	local fuseStrokeThickness = 0.0909

	local fuseCanvas = nil
	local fuseSpotlight = {}
	local fuseEntryRows = {}
	local fuseInfoRows = {}
	local fusePrebuiltRows = {}
	local fuseRelayoutFrames = 0
	local fuseMinNameWidth = 4
	local fuseMinRarityWidth = 3
	local fuseForceRelayout = false
	local fuseCanvasRatio = -1
	local fuseCanvasHeight = -1
	local fuseMaxContentHeight = -1
	local fuseLayoutWidth = 4
	local fuseLayoutHeight = 3
	local fuseRenderBusy = false
	local fuseRenderVersion = 0
	local fuseCache = nil
	local scaleBandCache = nil

	local scaleBandColors = {
		{ Min = 0, Color = "#8F98A8" },
		{ Min = 0.3, Color = "#C6CDDA" },
		{ Min = 0.85, Color = "#FFFFFF" },
		{ Min = 1.45, Color = "#7CFF9E" },
		{ Min = 1.9, Color = "#4FE0FF" },
		{ Min = 2.85, Color = "#6FA0FF" },
		{ Min = 3.8, Color = "#C08BFF" },
		{ Min = 5.8, Color = "#FF9A3D" },
		{ Min = 9.5, Color = "#FF5C5C" },
		{ Min = 12, Color = "#FFD34D" },
		{ Min = 20, Color = "#FF4DE8" },
	}

	local function colorForScale(scale)
		local best = -math.huge
		local chosen = "#FFFFFF"

		for _, band in ipairs(scaleBandColors) do
			if scale + 0.001 >= band.Min and band.Min > best then
				chosen = band.Color
				best = band.Min
			end
		end

		return chosen
	end

	local function weightForScale(category, scale)
		local eggRecords = modules.EggRecords
		if type(eggRecords) ~= "table" or type(eggRecords.WeightKgForScale) ~= "function" then
			return nil
		end
		local ok, result = pcall(eggRecords.WeightKgForScale, category, scale)
		if ok and type(result) == "number" and result > 0 then
			return result
		end
		return nil
	end

	local function bestMutationFor(mutations)
		if type(mutations) ~= "table" or #mutations == 0 then
			return nil
		end
		local bestMultiplier = -math.huge
		local bestName = nil

		for _, mutation in ipairs(mutations) do
			local multiplier = predictorHelpers.MutationMultiplier({ mutation })

			if multiplier > bestMultiplier then
				bestMultiplier = multiplier
				bestName = mutation
			end
		end

		return bestName
	end

	local function getScaleBands()
		if scaleBandCache then
			return scaleBandCache
		end
		local eggRecords = modules.EggRecords
		local getUpvaluesFn = type(debug) == "table" and debug.getupvalues or getupvalues

		if type(eggRecords) == "table" and type(eggRecords.DrawAssetScale) == "function" and type(getUpvaluesFn) == "function" then
			local ok, upvalues = pcall(getUpvaluesFn, eggRecords.DrawAssetScale)

			if ok and type(upvalues) == "table" then
				for _, value in pairs(upvalues) do
					if type(value) == "table" and type(value[1]) == "table" and value[1].min and value[1].weight then
						scaleBandCache = value
						break
					end
				end
			end
		end

		scaleBandCache = scaleBandCache or scaleBandTable
		return scaleBandCache
	end

	local function computeBandWeight(scales, bandMin, bandMax)
		local fuseKernel = modules.FuseKernel

		if type(fuseKernel) == "table" and type(fuseKernel.BandWeightBias) == "function" then
			local ok, result = pcall(fuseKernel.BandWeightBias, scales, bandMin, bandMax)
			if ok and type(result) == "number" then
				return result
			end
		end

		return math.exp(math.log((scales[1] + scales[2] + scales[3]) / 3) / 0.69314718055994529 * math.log((bandMin + bandMax) / 2) / 0.69314718055994529 * 0.6)
	end

	local function readFuseState()
		local saveModule = modules.Save
		if type(saveModule) ~= "table" or type(saveModule.Get) ~= "function" then
			return nil
		end
		local ok, result = pcall(saveModule.Get)
		if not ok or type(result) ~= "table" then
			return nil
		end
		local fusionSlots = type(result.FusionSlots) == "table" and result.FusionSlots or {}
		local inventory = type(result.Inventory) == "table" and result.Inventory or {}
		local items = {}

		for i = 1, 3 do
			local slotUid = fusionSlots[i]
			local entry = slotUid ~= nil and inventory[slotUid] or nil

			if type(entry) == "table" then
				table.insert(items, {
					Category = entry.Category,
					Scale = tonumber(entry.Scale) or 1,
					Mutations = type(entry.Mutations) == "table" and entry.Mutations or {},
				})
			end
		end

		return {
			Items = items,
			Locked = result.FusionLocked == true,
			Duration = tonumber(result.FusionDuration) or 0,
			Reward = result.FusionEggReward ~= nil and result.FusionEggReward ~= false,
		}
	end

	local function pickFusePalette(info)
		if string.upper(tostring(info.Rarity)) == "SECRET" then
			return predictorHelpers.SecretGradient
		end
		return info.Gradient
	end

	local function pickFuseRarityColor(info)
		return pickFusePalette(info) ~= nil and Color3.fromRGB(255, 255, 255) or info.Color
	end

	local function pickFuseRotation(info)
		if string.upper(tostring(info.Rarity)) == "SECRET" then
			return predictorHelpers.SecretRotation
		end
		return nil
	end

	local function buildFuseSpotlight(canvas)
		fuseSpotlight.Canvas = canvas
		canvas:SetDock(5, { Gap = fuseInfoGap, DividerColor = Color3.fromRGB(170, 174, 184) })
		local dock = canvas:Dock()

		fuseSpotlight.Icon = canvas:Image({
			Parent = dock,
			X = 0,
			Y = 0,
			Width = fuseRowIconSize,
			Height = fuseRowIconSize,
			Corner = 0.35,
			Background = "#000000",
			BackgroundTransparency = 0.26,
			StrokeThickness = fuseStrokeThickness,
			StrokeTransparency = 0,
			ZIndex = 8,
		})

		fuseSpotlight.Name = canvas:Text({
			Parent = dock,
			X = fuseRowNameX,
			Y = 0,
			Height = fuseRowTitleHeight,
			Scale = fuseRowNameScale,
			Wrap = false,
			Gradient = predictorHelpers.NameGradient,
			TextStrokeTransparency = 1,
			ZIndex = 9,
		})

		fuseSpotlight.Rarity = canvas:Text({
			Parent = dock,
			X = fuseRowNameX,
			Y = 0,
			Height = fuseRowTitleHeight,
			Scale = fuseRowRarityScale,
			Wrap = false,
			Font = predictorHelpers.RarityFont,
			TextStrokeTransparency = 1,
			StrokeTransparency = 0.08,
			ZIndex = 9,
		})

		fuseSpotlight.Info = canvas:Text({ Parent = dock, X = fuseRowNameX, Y = fuseRowTitleHeight, Height = fuseRowIconSize - fuseRowTitleHeight, Wrap = false, ZIndex = 9 })

		canvas:OnResize(function(_, width, height)
			if width == fuseCanvasRatio and height == fuseCanvasHeight then
				return
			end
			fuseCanvasRatio = width
			fuseCanvasHeight = height
			fuseLayoutWidth = width / math.max(height, 1)
			fuseLayoutHeight = height
			fuseRelayoutFrames = 2
			fuseStrokeThickness = 0.9 / math.max(canvas:TextSize(), 1)
			fuseSpotlight.Rarity.Set({ StrokeThickness = fuseStrokeThickness })

			for _, row in ipairs(fuseEntryRows) do
				row.Rarity.Set({ StrokeThickness = fuseStrokeThickness })
			end
		end)
	end

	local function getFuseHandleText(handle)
		local current = handle and handle.Get()
		if not current or fuseLayoutHeight <= 0 then
			return nil
		end

		if current.Text ~= tostring(handle.Spec.Text or "") then
			return nil
		end
		return current
	end

	local function measureFuseWidth(handle)
		local current = getFuseHandleText(handle)
		if not current then
			return nil
		end
		local originalSize = current.Size
		local textWrapped = current.TextWrapped
		current.TextWrapped = false
		current.Size = UDim2.fromOffset(100000, math.max(1, originalSize.Y.Offset))
		local measured = current.TextBounds.X
		current.Size = originalSize
		current.TextWrapped = textWrapped
		if measured <= 0 then
			return nil
		end
		return measured / fuseLayoutHeight
	end

	local function measureFuseHeight(handle, lineHeight)
		local current = getFuseHandleText(handle)
		if not current then
			return nil
		end
		local originalSize = current.Size
		current.Size = UDim2.fromOffset(math.max(1, math.floor(lineHeight * fuseLayoutHeight + 0.5)), 100000)
		local measured = current.TextBounds.Y
		current.Size = originalSize
		if measured <= 0 then
			return nil
		end
		return measured / fuseLayoutHeight
	end

	local function getFuseInfoRow(index)
		local row = fuseInfoRows[index]

		if not row then
			row = fuseSpotlight.Canvas:Text({ Name = "Line", X = 0, Y = 0, Width = 1, Height = 1, Wrap = true, Visible = false })
			fuseInfoRows[index] = row
		end

		return row
	end

	local function getFuseEntryRow(index)
		local row = fuseEntryRows[index]
		if row then
			return row
		end
		local newRow = {
			Frame = fuseSpotlight.Canvas:Frame({
				Name = "Slot",
				Background = "#000000",
				BackgroundTransparency = 0.74,
				Corner = 0.35,
				X = 0,
				Y = 0,
				Width = 1,
				Height = 1,
				Visible = false,
			}),
		}

		newRow.Icon = fuseSpotlight.Canvas:Image({
			Parent = newRow.Frame,
			X = fuseEntryIconX,
			Y = 0,
			Width = fuseEntryIconSize,
			Height = fuseEntryIconSize,
			Corner = 0.35,
			Background = "#000000",
			BackgroundTransparency = 0.45,
			StrokeThickness = fuseStrokeThickness,
			StrokeTransparency = 0,
		})

		newRow.Name = fuseSpotlight.Canvas:Text({
			Parent = newRow.Frame,
			X = fuseEntryIconX + fuseEntryIconOffset,
			Y = 0,
			Width = 1,
			Height = fuseRowTitleHeight,
			Scale = fuseRowNameScale,
			Wrap = false,
			Gradient = predictorHelpers.NameGradient,
			TextStrokeTransparency = 1,
		})

		newRow.Rarity = fuseSpotlight.Canvas:Text({
			Parent = newRow.Frame,
			X = fuseEntryIconX + fuseEntryIconOffset,
			Y = 0,
			Width = 1,
			Height = fuseRowTitleHeight,
			Scale = fuseRowRarityScale,
			Wrap = false,
			Font = predictorHelpers.RarityFont,
			TextStrokeTransparency = 1,
			StrokeTransparency = 0.08,
			StrokeThickness = fuseStrokeThickness,
		})

		newRow.Detail = fuseSpotlight.Canvas:Text({
			Parent = newRow.Frame,
			X = fuseEntryIconX + fuseEntryIconOffset,
			Y = fuseRowTitleHeight,
			Width = math.max(1, fuseLayoutWidth - fuseEntryIconOffset - fuseEntryIconX * 2),
			Height = 1,
			Wrap = true,
		})

		newRow.Status = fuseSpotlight.Canvas:Text({
			Parent = newRow.Frame,
			X = 0,
			Y = 0,
			Width = 1,
			Height = fuseRowTitleHeight,
			Wrap = false,
			Align = "Right",
			Color = color3.Hint,
		})

		fuseEntryRows[index] = newRow
		return newRow
	end

	local function layoutFuse()
		if fuseLayoutWidth <= 0 then
			return
		end
		fuseForceRelayout = false
		local availableWidth = math.max(1, fuseLayoutWidth - fuseRowNameX)
		local rarityWidth = measureFuseWidth(fuseSpotlight.Rarity)

		if rarityWidth then
			fuseMinRarityWidth = rarityWidth + 0.1
		else
			fuseForceRelayout = true
		end

		local nameWidth = measureFuseWidth(fuseSpotlight.Name)

		if nameWidth then
			fuseMinNameWidth = math.min(nameWidth + 0.1, math.max(1, availableWidth - fuseMinRarityWidth - fuseEntryGap))
		else
			fuseForceRelayout = true
		end

		fuseSpotlight.Name.Set({ X = fuseRowNameX, Y = 0, Width = fuseMinNameWidth, Height = fuseRowTitleHeight })

		fuseSpotlight.Rarity.Set({
			X = fuseRowNameX + fuseMinNameWidth + fuseEntryGap,
			Y = 0,
			Width = math.max(0.5, math.min(fuseMinRarityWidth, availableWidth - fuseMinNameWidth - fuseEntryGap)),
			Height = fuseRowTitleHeight,
		})

		fuseSpotlight.Info.Set({ X = fuseRowNameX, Y = fuseRowTitleHeight, Width = availableWidth, Height = math.max(1, fuseRowIconSize - fuseRowTitleHeight) })
		local innerWidth = math.max(1, fuseLayoutWidth - fuseEntryIconOffset - fuseEntryIconX * 2)
		local cursorY = 0

		for _, row in ipairs(fusePrebuiltRows) do
			if row.Kind == "text" then
				local handle = row.Handle
				local measured = measureFuseHeight(handle, fuseLayoutWidth)

				if measured then
					row.Height = measured
				else
					fuseForceRelayout = true
				end

				local height = math.max(1, row.Height or 1)
				handle.Set({ X = 0, Y = cursorY + (row.Gap and 0.5 or 0), Width = fuseLayoutWidth, Height = height })
				cursorY = cursorY + height + fuseInfoGap * 0.5 + (row.Gap and 0.5 or 0)
			else
				local slot = row.Slot
				local detailHeight = measureFuseHeight(slot.Detail, innerWidth)

				if detailHeight then
					slot.DetailUnits = detailHeight
				else
					fuseForceRelayout = true
				end

				local detailUnits = math.clamp(slot.DetailUnits or 1, 1, 4)
				local statusWidth = measureFuseWidth(slot.Status)

				if statusWidth then
					slot.StatusUnits = statusWidth + 0.23
				else
					fuseForceRelayout = true
				end

				local statusUnits = math.min(innerWidth * 0.42, math.max(2.73, slot.StatusUnits or 2.73))
				local nameArea = math.max(1, innerWidth - statusUnits - fuseEntryGap)
				local rarityUnits = measureFuseWidth(slot.Rarity)

				if rarityUnits then
					slot.RarityUnits = rarityUnits + 0.1
				else
					fuseForceRelayout = true
				end

				local rarityWidth2 = math.min(slot.RarityUnits or 3, nameArea * 0.5)
				local nameUnits = measureFuseWidth(slot.Name)

				if nameUnits then
					slot.NameUnits = nameUnits + 0.1
				else
					fuseForceRelayout = true
				end

				local nameWidth2 = math.min(math.max(1, slot.NameUnits or 4), math.max(1, nameArea - rarityWidth2 - fuseEntryGap))
				local padding = fuseInfoGap * 2
				local totalHeight = math.max(detailUnits + fuseRowTitleHeight, 2.3) + padding
				local verticalPad = (totalHeight - detailUnits - fuseRowTitleHeight) / 2
				slot.Frame.Set({ X = 0, Y = cursorY, Width = fuseLayoutWidth, Height = totalHeight })
				slot.Icon.Set({ Y = (totalHeight - fuseEntryIconSize) / 2 })
				slot.Name.Set({ X = fuseEntryIconX + fuseEntryIconOffset, Y = verticalPad, Width = nameWidth2 })
				slot.Rarity.Set({ X = fuseEntryIconX + fuseEntryIconOffset + nameWidth2 + fuseEntryGap, Y = verticalPad, Width = math.max(0.5, rarityWidth2) })
				slot.Detail.Set({ X = fuseEntryIconX + fuseEntryIconOffset, Y = verticalPad + fuseRowTitleHeight, Width = innerWidth, Height = detailUnits })
				slot.Status.Set({ X = fuseEntryIconX + fuseEntryIconOffset + innerWidth - statusUnits, Y = verticalPad, Width = math.max(0.5, statusUnits) })
				cursorY = cursorY + totalHeight + fuseInfoGap
			end
		end

		local totalHeight = math.max(1, cursorY)

		if math.abs(totalHeight - fuseMaxContentHeight) > 0.01 then
			fuseMaxContentHeight = totalHeight
			fuseSpotlight.Canvas:SetContentLines(totalHeight)
		end
	end

	local function renderFusePredictor()
		if not fuseSpotlight.Canvas then
			return
		end
		fuseRelayoutFrames = 2
		table.clear(fusePrebuiltRows)
		local textRowCount = 0

		local function addTextRow(text, gap)
			textRowCount = textRowCount + 1
			local handle = getFuseInfoRow(textRowCount)
			handle.Set({ Visible = true, Text = text })
			table.insert(fusePrebuiltRows, { Kind = "text", Handle = handle, Gap = gap })
		end

		local function addHeader(text, color)
			local hasGap = #fusePrebuiltRows > 0
			addTextRow(string.format("<b><font color=\"%s\">%s</font></b>", color, text), hasGap)
		end

		local fuseState = readFuseState()
		local rowCount = 0

		if not fuseState then
			fuseSpotlight.Canvas:SetDock(0, { Gap = fuseInfoGap })
			fuseSpotlight.Icon.Set({ Visible = false })
			fuseSpotlight.Name.Set({ Visible = false })
			fuseSpotlight.Rarity.Set({ Visible = false })
			fuseSpotlight.Info.Set({ Visible = false })
			fuseSpotlight.Focus = nil
			addTextRow(bold2(paint2(color3.Hint, "Fuse machine data is not available yet")), false)
			rowCount = 0
		elseif #fuseState.Items == 0 then
			fuseSpotlight.Canvas:SetDock(0, { Gap = fuseInfoGap })
			fuseSpotlight.Icon.Set({ Visible = false })
			fuseSpotlight.Name.Set({ Visible = false })
			fuseSpotlight.Rarity.Set({ Visible = false })
			fuseSpotlight.Info.Set({ Visible = false })
			fuseSpotlight.Focus = nil
			addTextRow(bold2(paint2(color3.Text, "Machine is empty")), false)
			addTextRow(paint2(color3.Hint, "Load 3 pets of the same species to see the result odds"), false)
			rowCount = 0
		else
			local items = fuseState.Items
			local info = predictorHelpers.AssetInfo(items[1].Category)
			fuseSpotlight.Canvas:SetDock(5, { Gap = fuseInfoGap })
			fuseSpotlight.Icon.Set({ Visible = info.Icon ~= nil, Image = info.Icon or "", StrokeColor = info.Color })
			fuseSpotlight.Name.Set({ Text = predictorHelpers.Escape(info.Name) })

			fuseSpotlight.Rarity.Set({
				Text = string.upper(tostring(info.Rarity)),
				Color = pickFuseRarityColor(info),
				Gradient = pickFusePalette(info),
				GradientRotation = pickFuseRotation(info),
			})

			local statusText

			if fuseState.Reward then
				statusText = bold2(paint2(color3.Ready, "Fuse finished, claim your egg"))
			elseif fuseState.Locked then
				local remaining = fuseState.Duration > 1e9 and fuseState.Duration - workspace:GetServerTimeNow() or 0
				statusText = bold2(paint2(color3.Clock, remaining > 0 and "Fusing" .. predictorHelpers.Separator() .. predictorHelpers.FormatClock(remaining) or "Fusing"))
			end

			local firstItem = items[1]
			fuseSpotlight.Info.Set({
				Text = table.concat({
					bold2(paint2(color3.Income, predictorHelpers.FormatRate(predictorHelpers.Income(info, firstItem.Scale, firstItem.Mutations)))),
					paint2(color3.Text, string.format("%d/3 loaded", #items)),
					statusText or "",
				}, "\n"),
			})

			fuseSpotlight.Focus = info
			local textColor = color3.Text
			addHeader(string.format("FUSE MACHINE STATUS (%d/3 PETS)", #items), textColor)
			addTextRow(paint2(color3.Hint, "Species") .. "  " .. bold2(paint2(info.Hex, "[" .. string.upper(tostring(info.Rarity)) .. "]")) .. " " .. bold2(paint2(color3.Text, predictorHelpers.Escape(info.Name))), false)
			rowCount = 0

			for i = 1, 3 do
				local item = items[i]
				rowCount = rowCount + 1
				local slot = getFuseEntryRow(rowCount)
				slot.Frame.Set({ Visible = true })
				slot.Status.Set({ Text = "SLOT " .. i })

				if item then
					slot.Icon.Set({ Visible = info.Icon ~= nil, Image = info.Icon or "", StrokeColor = info.Color })
					slot.Name.Set({ Text = predictorHelpers.Escape(info.Name) })

					slot.Rarity.Set({
						Text = string.upper(tostring(info.Rarity)),
						Color = pickFuseRarityColor(info),
						Gradient = pickFusePalette(info),
						GradientRotation = pickFuseRotation(info),
					})

					local weight = weightForScale(item.Category, item.Scale)
					local weightText = bold2(paint2(color3.Scale, string.format("%.2fx", item.Scale)))

					if weight then
						weightText = weightText .. predictorHelpers.Separator() .. paint2(color3.Weight, predictorHelpers.FormatWeight(weight))
					end

					local detailText = weightText .. predictorHelpers.Separator() .. bold2(paint2(color3.Income, predictorHelpers.FormatRate(predictorHelpers.Income(info, item.Scale, item.Mutations))))
					local mutationText = predictorHelpers.MutationText(item.Mutations)
					slot.Detail.Set({
						Text = detailText .. predictorHelpers.Separator() .. (mutationText ~= "" and mutationText or paint2(color3.Hint, "Normal")),
					})
				else
					slot.Icon.Set({ Visible = false })
					slot.Name.Set({ Text = paint2(color3.Hint, "Empty") })
					slot.Rarity.Set({ Text = "", Gradient = nil })
					slot.Detail.Set({ Text = paint2(color3.Hint, "Add a pet to this slot") })
				end

				table.insert(fusePrebuiltRows, { Kind = "slot", Slot = slot })
			end

			local totalScale = 0

			for _, item in ipairs(items) do
				totalScale = totalScale + item.Scale
			end

			local averageScale = totalScale / #items
			local averageWeight = weightForScale(items[1].Category, averageScale)
			local scaleText = paint2(color3.Hint, "Average Scale") .. "  " .. bold2(paint2(color3.Scale, string.format("%.2fx", averageScale)))

			if averageWeight then
				scaleText = scaleText .. predictorHelpers.Separator() .. paint2(color3.Weight, predictorHelpers.FormatWeight(averageWeight))
			end

			addTextRow(scaleText, false)
			local bestMutation = nil

			for _, item in ipairs(items) do
				local candidate = bestMutationFor(item.Mutations)

				if candidate then
					if (bestMutation and predictorHelpers.MutationMultiplier({ bestMutation }) or 0) < predictorHelpers.MutationMultiplier({ candidate }) then
						bestMutation = candidate
					end
				end
			end

			local bestMutationList = bestMutation and { bestMutation } or {}
			addHeader("PREDICTED SIZE PROBABILITIES", color3.Income)

			if #items == 3 then
				local scales = { items[1].Scale, items[2].Scale, items[3].Scale }
				local weighted = {}
				local totalWeight = 0

				for _, band in ipairs(getScaleBands()) do
					local weight = band.weight * computeBandWeight(scales, band.min, band.max)
					totalWeight = totalWeight + weight
					table.insert(weighted, { Min = band.min, Max = band.max, Weight = weight, Color = colorForScale(band.min) })
				end

				table.sort(weighted, function(a, b)
					return a.Weight > b.Weight
				end)

				local topBand = weighted[1]

				for _, band in ipairs(weighted) do
					local percent = totalWeight > 0 and band.Weight / totalWeight * 100 or 0
					local bandText = bold2(paint2(band.Color, string.format("%.2fx - %.2fx", band.Min, band.Max)))
					local minWeight = weightForScale(items[1].Category, band.Min)
					local maxWeight = weightForScale(items[1].Category, band.Max)

					if minWeight and maxWeight then
						bandText = bandText .. predictorHelpers.Separator() .. paint2(color3.Weight, string.format("%s - %s", predictorHelpers.FormatWeight(minWeight), predictorHelpers.FormatWeight(maxWeight)))
					end

					local percentColor = percent >= 10 and color3.Income or percent >= 1 and color3.Clock or color3.Hint
					addTextRow(bandText .. predictorHelpers.Separator() .. bold2(paint2(percentColor, string.format(percent >= 1 and "%.1f%%" or "%.3f%%", percent))), false)
				end

				addHeader("RESULT PREDICTION", color3.Text)
				addTextRow(paint2(color3.Hint, "Predicted Mutation") .. "  " .. (bestMutation and predictorHelpers.MutationText(bestMutationList) or paint2(color3.Text, "Normal")), false)

				if topBand then
					addTextRow(
						paint2(color3.Hint, "Estimated Value")
							.. "  "
							.. bold2(paint2(color3.Income, predictorHelpers.FormatRate(predictorHelpers.Income(info, topBand.Min, bestMutationList)) .. " ~ " .. predictorHelpers.FormatRate(predictorHelpers.Income(info, topBand.Max, bestMutationList))))
							.. predictorHelpers.Separator()
							.. paint2(color3.Hint, "at ")
							.. bold2(paint2(topBand.Color, string.format("%.2fx - %.2fx", topBand.Min, topBand.Max))),
						false
					)
				end

				local bestCase = nil

				for _, band in ipairs(weighted) do
					if not bestCase or band.Max > bestCase.Max then
						bestCase = band
					end
				end

				if bestCase then
					addTextRow(
						paint2(color3.Hint, "Best Case")
							.. "  "
							.. bold2(paint2(bestCase.Color, string.format("%.2fx - %.2fx", bestCase.Min, bestCase.Max)))
							.. "  "
							.. bold2(paint2(color3.Income, predictorHelpers.FormatRate(predictorHelpers.Income(info, bestCase.Max, bestMutationList)))),
						false
					)
				end
			else
				addTextRow(paint2(color3.Hint, string.format("Load %d more of the same species to see the odds", 3 - #items)), false)
			end
		end

		for i = textRowCount + 1, #fuseInfoRows do
			fuseInfoRows[i].Set({ Visible = false })
		end

		for i = rowCount + 1, #fuseEntryRows do
			fuseEntryRows[i].Frame.Set({ Visible = false })
		end

		layoutFuse()
		fuseRelayoutFrames = 2
	end

	if not predictorHelpers.Ready then
		fusePredictorSection:CreateText({
			Name = "Fuse Predictor",
			Text = "Live predictor card is not available in the ModernV2 UI.",
		})
	else
		local canvas = fusePredictorSection:CreateCanvas({
			Name = "Fuse Predictor",
			Layout = "free",
			Style = {
				TextScale = 0.84,
				LineHeight = 1.1,
				MinLines = 16,
				MaxLines = 34,
				BackgroundTransparency = 0.5,
				ScrollBarColor = Color3.fromRGB(170, 174, 184),
				TextColor = Color3.fromRGB(255, 255, 255),
				TextStrokeTransparency = 0.7,
			},
			Build = function(innerCanvas)
				buildFuseSpotlight(innerCanvas)

				if type(predictorHelpers.RequestEggRefresh) == "function" then
					predictorHelpers.RequestEggRefresh()
				end
			end,
		})

		predictorHelpers.RefreshFuse = renderFusePredictor

		predictorHelpers.PlaceFuse = function()
			if fuseRelayoutFrames > 0 or fuseForceRelayout then
				if fuseRelayoutFrames > 0 then
					fuseRelayoutFrames = fuseRelayoutFrames - 1
				end

				pcall(layoutFuse)
			end
		end

		registerCleanup(function()
			canvas:Destroy()
		end)
	end
end

do
	local HttpService = game:GetService("HttpService")
	local function getHttpRequest()
		return (syn and syn.request)
			or (http and http.request)
			or (fluxus and fluxus.request)
			or (krnl and krnl.request)
			or http_request
			or request
			or (getgenv and (getgenv().request or getgenv().http_request or (getgenv().syn and getgenv().syn.request) or (getgenv().http and getgenv().http.request)))
	end

	local function extractStatusCode(result)
		if type(result) ~= "table" then
			return nil
		end
		return tonumber(result.StatusCode or result.status_code or result.Status)
	end

	local function normalizeWebhookUrl(url)
		if type(url) ~= "string" then
			return ""
		end
		url = string.gsub(url, "^%s+", "")
		url = string.gsub(url, "%s+$", "")
		url = string.gsub(url, "%?.*$", "")
		url = string.gsub(url, "/+$", "")
		return url
	end

	local function isValidWebhookUrl(url)
		url = normalizeWebhookUrl(url)
		if url == "" then
			return false
		end
		if string.find(url, "/api/webhooks/%d+/[%w%-_]+") then
			return true
		end
		if string.match(url, "^https?://[%w%.%-_]+/api/webhooks/") then
			return true
		end
		return false
	end

	local webhookState = {
		Url = "",
		Stolen = false,
		PingEveryone = false,
		Queue = {},
		Sending = false,
		Notified = {},
		Icons = {},
		Known = nil,
		Carry = nil,
		Avatar = nil,
		Disposed = false,
		Path = "NexHubLibrary/SAE_Webhook.txt",
		Saved = "",
		LoadedAt = os.clock(),
		Input = nil,
		Dot = "  " .. utf8.char(183) .. "  ",
		Logo = "https://tr.rbxcdn.com/180DAY-ff594a7e213b41ba999197d55416bc2e/420/420/Image/Png/noFilter",
		LogoAssetId = 82006436469351,
		LogoUrl = nil,
		Emoji = {
			Value = "<:sae_value:1551645680718581871>",
			Size = "<:sae_size:1551645444285800558>",
			Mutation = "<:sae_mutation:1551677914146275478>",
			Area = "<:sae_area:1551675973328441416>",
		},
	}

	local function loadSavedWebhookUrl()
		local paths = { "NexHubLibrary/SAE_Webhook.txt", "ChilliLibrary/SAE_Webhook.txt" }
		for _, p in ipairs(paths) do
			if type(readfile) == "function" and (type(isfile) ~= "function" or isfile(p)) then
				local ok, content = pcall(readfile, p)
				if ok and type(content) == "string" then
					local cleaned = normalizeWebhookUrl(content)
					if cleaned ~= "" then
						return cleaned
					end
				end
			end
		end
		return ""
	end

	local function saveWebhookUrl(url)
		if type(writefile) ~= "function" then
			return
		end
		pcall(function()
			if type(makefolder) == "function" and (type(isfolder) ~= "function" or not isfolder("NexHubLibrary")) then
				pcall(makefolder, "NexHubLibrary")
			end
			writefile(webhookState.Path, url)
		end)
	end

	local savedUrl = loadSavedWebhookUrl()
	webhookState.Saved = savedUrl
	webhookState.Url = savedUrl

	local function jsonDecode(str)
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(tostring(str))
		end)
		return ok and decoded or nil
	end

	local function jsonEncode(data)
		local ok, encoded = pcall(function()
			return HttpService:JSONEncode(data)
		end)
		return ok and encoded or nil
	end

	local function httpGetJson(url)
		local httpFn = getHttpRequest()
		if type(httpFn) ~= "function" then
			return nil
		end
		local ok, result = pcall(httpFn, { Url = url, Method = "GET" })
		if not ok or type(result) ~= "table" or extractStatusCode(result) ~= 200 then
			return nil
		end
		return jsonDecode(result.Body)
	end

	local function parseThumbnailResponse(response)
		local entry = type(response) == "table" and type(response.data) == "table" and response.data[1] or nil
		if type(entry) ~= "table" or entry.state ~= "Completed" or type(entry.imageUrl) ~= "string" or entry.imageUrl == "" then
			return nil
		end
		return entry.imageUrl
	end

	local function getAssetThumbnail(assetId)
		if webhookState.Icons[assetId] == nil then
			webhookState.Icons[assetId] = parseThumbnailResponse(
				httpGetJson("https://thumbnails.roblox.com/v1/assets?assetIds=" .. tostring(assetId) .. "&returnPolicy=PlaceHolder&size=420x420&format=Png&isCircular=false")
			) or false
		end
		return webhookState.Icons[assetId] or nil
	end

	local function getAvatarUrl()
		if webhookState.Avatar == nil then
			webhookState.Avatar = parseThumbnailResponse(
				httpGetJson("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. tostring(localPlayer.UserId) .. "&size=150x150&format=Png&isCircular=false")
			) or false
		end
		return webhookState.Avatar or nil
	end

	local function getNexHubLogoUrl()
		if webhookState.LogoUrl then
			return webhookState.LogoUrl
		end
		local resolved = getAssetThumbnail(webhookState.LogoAssetId or 82006436469351)
		if type(resolved) == "string" and resolved ~= "" then
			webhookState.LogoUrl = resolved
			return resolved
		end
		return webhookState.Logo
	end

	local function colorToDiscordInt(color, isSecret)
		if isSecret then
			return 13686498
		end
		if typeof(color) ~= "Color3" then
			return 5793266
		end
		return math.floor(color.R * 255 + 0.5) * 65536 + math.floor(color.G * 255 + 0.5) * 256 + math.floor(color.B * 255 + 0.5)
	end

	local function formatMutationList(mutations)
		local parts = {}
		if type(mutations) == "table" then
			for _, mutation in ipairs(mutations) do
				parts[#parts + 1] = mutationLabel(mutation)
			end
		end
		return #parts > 0 and table.concat(parts, ", ") or "None"
	end

	local function formatAreaName(areaId)
		local areas = modules.Areas
		local directory = type(areas) == "table" and (areas.Directory or areas) or nil
		local name = tostring(areaId or "")
		local entry = type(directory) == "table" and name ~= "" and directory[name] or nil
		if type(entry) == "table" then
			return tostring(entry.DisplayName or name)
		end
		return name ~= "" and name or "Field"
	end

	local function buildWebhookPayload(title, category, scale, mutations, areaId, preferEggIcon)
		local categoryKey = tostring(category)
		local info = predictorHelpers.AssetInfo(categoryKey)
		local numericScale = tonumber(scale) or 1
		mutations = type(mutations) == "table" and mutations or {}
		local income = predictorHelpers.Income(info, numericScale, mutations)
		local dot = webhookState.Dot
		local scaleText = string.format("x%.2f", numericScale)
		local eggRecords = modules.EggRecords
		local sizeText

		if type(eggRecords) == "table" and type(eggRecords.WeightKgForScale) == "function" then
			local ok, weight = pcall(eggRecords.WeightKgForScale, categoryKey, numericScale)
			if ok and tonumber(weight) then
				sizeText = scaleText .. dot .. predictorHelpers.FormatWeight(weight)
			else
				sizeText = scaleText
			end
		else
			sizeText = scaleText
		end

		local emoji = webhookState.Emoji
		local description = {}
		description[1] = "**" .. tostring(info.Name) .. "**" .. dot .. tostring(info.Rarity)
		description[2] = emoji.Value .. " **Value:** $" .. predictorHelpers.FormatRate(income)
		description[3] = emoji.Size .. " **Size:** " .. sizeText
		description[4] = emoji.Mutation .. " **Mutation:** " .. formatMutationList(mutations)
		description[5] = emoji.Area .. " **Area:** " .. formatAreaName(areaId)

		local logo = getNexHubLogoUrl()
		local embed = {
			author = { name = localPlayer.DisplayName .. " (@" .. localPlayer.Name .. ")", icon_url = getAvatarUrl() },
			title = title,
			description = table.concat(description, "\n"),
			color = colorToDiscordInt(info.Color, string.upper(tostring(info.Rarity)) == "SECRET"),
			footer = { text = "NexHub" .. dot .. "Steal An Egg", icon_url = logo },
			timestamp = DateTime.now():ToIsoDate(),
		}

		local icon = info.Icon
		if preferEggIcon then
			local directory = modules.Assets and modules.Assets.Directory
			local assetEntry = type(directory) == "table" and directory[categoryKey] or nil
			local eggEntry = type(assetEntry) == "table" and type(assetEntry.Egg) == "table" and assetEntry.Egg or nil
			if eggEntry and eggEntry.Icon ~= nil then
				icon = eggEntry.Icon
			end
		end

		local iconId = tonumber(string.match(tostring(icon or ""), "(%d+)"))
		local iconUrl = iconId and getAssetThumbnail(iconId) or nil
		if iconUrl then
			embed.thumbnail = { url = iconUrl }
		end

		local payload = {
			username = "NexHub",
			avatar_url = logo,
			embeds = { embed },
		}
		return payload
	end

	local function pumpWebhookQueue()
		if webhookState.Sending then
			return
		end
		webhookState.Sending = true

		task.spawn(function()
			while #webhookState.Queue > 0 and not webhookState.Disposed do
				local item = table.remove(webhookState.Queue, 1)
				local url = normalizeWebhookUrl(webhookState.Url)
				local httpFn = getHttpRequest()

				if isValidWebhookUrl(url) and type(httpFn) == "function" then
					local encodedBody = jsonEncode(item.Payload)
					if encodedBody then
						local requestBody = {
							Url = url,
							Method = "POST",
							Headers = { ["Content-Type"] = "application/json" },
							Body = encodedBody,
						}

						local ok, result = pcall(httpFn, requestBody)
						local statusCode = ok and extractStatusCode(result) or nil

						if statusCode == 429 and item.Tries < 3 then
							item.Tries = item.Tries + 1
							table.insert(webhookState.Queue, 1, item)
							task.wait(3)
						elseif statusCode ~= 200 and statusCode ~= 204 then
							debugPrint("[Webhook] Failed to send, status: " .. tostring(statusCode))
						end
					end
				end

				task.wait(1.2)
			end

			webhookState.Sending = false
		end)
	end

	local function isWebhookReady()
		local httpFn = getHttpRequest()
		return type(httpFn) == "function" and isValidWebhookUrl(webhookState.Url)
	end

	local function enqueueWebhook(payload)
		if #webhookState.Queue >= 20 then
			table.remove(webhookState.Queue, 1)
		end

		if webhookState.PingEveryone and type(payload) == "table" then
			payload.content = "@everyone"
			payload.allowed_mentions = { parse = { "everyone" } }
		end

		table.insert(webhookState.Queue, { Payload = payload, Tries = 0 })
		pumpWebhookQueue()
	end

	local carryConnected = false
	local function connectCarryChanged(carrySignal)
		if carryConnected or type(carrySignal) ~= "table" or type(carrySignal.Connect) ~= "function" then
			return
		end
		local ok, connection = pcall(carrySignal.Connect, carrySignal, function(payload)
			if type(payload) ~= "table" then
				return
			end

			if payload.IsCarrying then
				webhookState.Carry = {
					Category = tostring(payload.AssetCategory),
					Uid = tostring(payload.Uid),
					Area = tostring(payload.AreaId or "Field"),
					EndedAt = nil,
				}
			elseif webhookState.Carry then
				webhookState.Carry.EndedAt = os.clock()
			end
		end)
		if ok and connection then
			carryConnected = true
			registerCleanup(function()
				pcall(function()
					connection:Disconnect()
				end)
			end)
		end
	end

	local eggStateInit = modules.EggState
	if type(eggStateInit) == "table" and eggStateInit.CarryChanged then
		connectCarryChanged(eggStateInit.CarryChanged)
	end

	registerCleanup(function()
		webhookState.Disposed = true
	end)

	task.spawn(function()
		while not webhookState.Disposed do
			local currentEggState = modules.EggState
			if not carryConnected and type(currentEggState) == "table" and currentEggState.CarryChanged then
				connectCarryChanged(currentEggState.CarryChanged)
			end

			local canRead = type(currentEggState) == "table" and type(currentEggState.ReadOwnerEggs) == "function"
			local readOk = false
			local result = nil

			if canRead then
				readOk, result = pcall(currentEggState.ReadOwnerEggs, localPlayer.UserId)
			end

			if readOk and type(result) == "table" then
				local known = webhookState.Known
				local newEntries = {}
				local knownSet = {}

				for uid, entry in pairs(result) do
					local key = tostring(uid)
					knownSet[key] = true

					if known and not known[key] and type(entry) == "table" then
						newEntries[#newEntries + 1] = { Uid = key, Record = entry }
					end
				end

				webhookState.Known = knownSet
				local carry = webhookState.Carry

				if webhookState.Stolen and #newEntries > 0 then
					for _, item in ipairs(newEntries) do
						local record = item.Record
						local area = (carry and carry.Area) or (state.Steal and state.Steal.CarryAreaId) or "Field"
						local mutations = type(record.Mutations) == "table" and record.Mutations or {}

						local isStolen = false
						if carry then
							local withinWindow = carry.EndedAt == nil or (os.clock() - carry.EndedAt < 25)
							if withinWindow and (item.Uid == carry.Uid or tostring(record.AssetCategory) == carry.Category) then
								isStolen = true
								area = carry.Area or area
								webhookState.Carry = nil
							end
						end

						if not isStolen and state.Steal and (state.Steal.Active or state.Steal.Carrying or (state.Steal.LastFinishedAt and os.clock() - state.Steal.LastFinishedAt < 25)) then
							isStolen = true
							if state.Steal.CarryAreaId then
								area = state.Steal.CarryAreaId
							end
						end

						if not isStolen then
							isStolen = true
						end

						if isStolen then
							task.spawn(function()
								if isWebhookReady() then
									enqueueWebhook(buildWebhookPayload("Egg Stolen!", record.AssetCategory, record.AssetScale, mutations, area))
								end
							end)
						end
					end
				end
			end

			task.wait(1.5)
		end
	end)

	local function setWebhookInput(value)
		local input = webhookState.Input
		if type(input) ~= "table" then
			return
		end

		for _, methodName in ipairs({ "Set", "SetValue" }) do
			local ok, methodFn = pcall(function()
				return input[methodName]
			end)

			if ok and type(methodFn) == "function" and pcall(methodFn, input, value, false) then
				return
			end
		end
	end

	webhookState.Input = webhookSection:CreateInput({
		Name = "Webhook URL",
		Placeholder = "https://discord.com/api/webhooks/...",
		Default = webhookState.Saved,
		MaxLength = 512,
		Callback = function(arg)
			local cleaned = normalizeWebhookUrl(arg)
			local isStaleDefault = cleaned == "" and webhookState.Saved ~= ""

			if isStaleDefault then
				local loadedAt = webhookState.LoadedAt
				isStaleDefault = os.clock() - loadedAt < 5
			end

			if isStaleDefault then
				webhookState.Url = webhookState.Saved
				task.defer(setWebhookInput, webhookState.Saved)
				return
			end

			webhookState.Url = cleaned

			if (cleaned == "" or isValidWebhookUrl(cleaned)) and cleaned ~= webhookState.Saved then
				saveWebhookUrl(cleaned)
				webhookState.Saved = cleaned
			end
		end,
	})

	webhookSection:CreateButton({
		Name = "Test Webhook",
		Callback = function()
			local url = normalizeWebhookUrl(webhookState.Url)
			if not isValidWebhookUrl(url) then
				notifyUserGlobal("Webhook", "Invalid or empty Webhook URL!")
				return
			end
			local httpFn = getHttpRequest()
			if type(httpFn) ~= "function" then
				notifyUserGlobal("Webhook", "Your executor does not support HTTP requests!")
				return
			end

			notifyUserGlobal("Webhook", "Sending test message to Discord...")
			task.spawn(function()
				local dot = webhookState.Dot
				local logo = getNexHubLogoUrl()
				local testEmbed = {
					author = { name = localPlayer.DisplayName .. " (@" .. localPlayer.Name .. ")", icon_url = getAvatarUrl() },
					title = "NexHub Webhook Test",
					description = "Webhook connection is working successfully!\nNotifications will appear here when you steal eggs.",
					color = 4376442,
					fields = {
						{ name = "Player", value = localPlayer.DisplayName, inline = true },
						{ name = "User ID", value = tostring(localPlayer.UserId), inline = true },
						{ name = "Status", value = "Connected", inline = true },
					},
					footer = { text = "NexHub" .. dot .. "Steal An Egg", icon_url = logo },
					timestamp = DateTime.now():ToIsoDate(),
				}

				local payload = {
					username = "NexHub",
					avatar_url = logo,
					embeds = { testEmbed },
				}
				if webhookState.PingEveryone then
					payload.content = "@everyone"
					payload.allowed_mentions = { parse = { "everyone" } }
				end

				local encodedBody = jsonEncode(payload)
				if not encodedBody then
					notifyUserGlobal("Webhook Failed", "Failed to encode payload JSON")
					return
				end

				local requestBody = {
					Url = url,
					Method = "POST",
					Headers = { ["Content-Type"] = "application/json" },
					Body = encodedBody,
				}
				local ok, result = pcall(httpFn, requestBody)
				local code = ok and extractStatusCode(result)
				if code == 200 or code == 204 then
					notifyUserGlobal("Webhook Success", "Test message sent to Discord!")
				else
					notifyUserGlobal("Webhook Failed", "Discord returned code: " .. tostring(code or "Connection Error"))
				end
			end)
		end,
	})

	webhookSection:CreateToggle({
		Name = "Ping @everyone",
		Default = false,
		Callback = function(arg)
			webhookState.PingEveryone = arg == true
		end,
	})

	webhookSection:CreateToggle({
		Name = "Notify Stolen Eggs",
		Note = "Post every egg you bring home",
		Default = false,
		Callback = function(arg)
			webhookState.Stolen = arg == true
		end,
	})
end
end)()

local miscTab = window:CreateTab({ Name = "Misc", SectionsExpanded = true })
local performanceSection = miscTab:CreateSection({ Name = "Performance", Expanded = true })
local fpsCapWarned = false

performanceSection:CreateSlider({
	Name = "FPS Cap",
	Min = 30,
	Max = 1000,
	Default = 240,
	AllowDecimals = false,
	Increment = 1,
	Unit = " FPS",
	Callback = function(arg)
		local target = math.clamp(math.floor(tonumber(arg) or 240), 30, 1000)

		if type(setfpscap) == "function" and pcall(setfpscap, target) then
			fpsCapWarned = false
			return
		end

		if not fpsCapWarned then
			fpsCapWarned = true
			notifyUser("FPS Cap Unavailable", "This environment does not support setfpscap.")
		end
	end,
})

do
	local Lighting = game:GetService("Lighting")
	local saved = nil

	local function boost(on)
		if on then
			if saved then
				return
			end
			saved = { emitters = {}, lighting = {}, terrain = {} }
			pcall(function()
				saved.lighting.GlobalShadows = Lighting.GlobalShadows
				saved.lighting.FogEnd = Lighting.FogEnd
				saved.lighting.Brightness = Lighting.Brightness
				Lighting.GlobalShadows = false
				Lighting.FogEnd = 1e6
			end)
			pcall(function()
				local t = workspace:FindFirstChildOfClass("Terrain")
				if t then
					saved.terrain.Decoration = t.Decoration
					saved.terrain.WaterWaveSize = t.WaterWaveSize
					saved.terrain.WaterReflectance = t.WaterReflectance
					t.Decoration = false
					t.WaterWaveSize = 0
					t.WaterReflectance = 0
				end
			end)
			pcall(function()
				settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
			end)
			pcall(function()
				for _, d in ipairs(workspace:GetDescendants()) do
					if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke")
						or d:IsA("Fire") or d:IsA("Sparkles") or d:IsA("Beam") then
						if d.Enabled then
							saved.emitters[#saved.emitters + 1] = d
							d.Enabled = false
						end
					end
				end
				for _, d in ipairs(Lighting:GetDescendants()) do
					if d:IsA("PostEffect") and d.Enabled then
						saved.emitters[#saved.emitters + 1] = d
						d.Enabled = false
					end
				end
			end)
			if type(notifyUser) == "function" then
				notifyUser("FPS Boost", string.format("FPS Boost ON: %d effects disabled", #saved.emitters))
			end
		else
			if not saved then
				return
			end
			pcall(function()
				for k, v in pairs(saved.lighting) do
					Lighting[k] = v
				end
			end)
			pcall(function()
				local t = workspace:FindFirstChildOfClass("Terrain")
				if t then
					for k, v in pairs(saved.terrain) do
						t[k] = v
					end
				end
			end)
			pcall(function()
				for _, d in ipairs(saved.emitters) do
					if d and d.Parent then
						d.Enabled = true
					end
				end
			end)
			if type(notifyUser) == "function" then
				notifyUser("FPS Boost", "FPS Boost OFF: effects restored")
			end
			saved = nil
		end
	end

	registerCleanup(function()
		if saved then
			pcall(boost, false)
		end
	end)

	performanceSection:CreateToggle({
		Name = "FPS Boost",
		Note = "Turns off effects and shadows - nothing is deleted",
		Default = false,
		Callback = function(arg)
			pcall(boost, arg == true)
		end,
	})
end

do
	local Stats = game:GetService("Stats")
	local hudWidth = 132
	local hudFontScale = 0.085
	local hudUpdateInterval = 0.2
	local hudSmoothFactor = 8
	local hudPositionState = window:CreateState({ Name = "FPS and Ping Position", Default = {} })

	local function getHudPosition()
		local position = hudPositionState:Get()
		if type(position) == "table" and type(position.XOffset) == "number" and type(position.YOffset) == "number" then
			return UDim2.new(tonumber(position.XScale) or 0, position.XOffset, tonumber(position.YScale) or 0, position.YOffset)
		end
		return UDim2.new(0, 16, 0, 16)
	end

	local function saveHudPosition(position)
		hudPositionState:Set({ XScale = position.X.Scale, XOffset = position.X.Offset, YScale = position.Y.Scale, YOffset = position.Y.Offset })
	end

	local green = Color3.fromRGB(58, 255, 55)
	local yellow = Color3.fromRGB(255, 214, 84)
	local red = Color3.fromRGB(255, 96, 96)
	local grey = Color3.fromRGB(150, 150, 158)
	local hudEnabled = true
	local hudConnections = {}
	local hudScreen = nil
	local hudFrame = nil
	local hudScale = nil
	local fpsLabel = nil
	local pingLabel = nil
	local hudSizeScale = 1
	local smoothedFps = 0
	local nextPingUpdateAt = 0
	local lastFpsText = nil
	local lastPingText = nil
	local hudFont = nil

	pcall(function()
		hudFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal)
	end)

	local function fpsColor(fps)
		if fps >= 100 then
			return green
		end

		if fps >= 50 then
			return yellow
		end
		return red
	end

	local function pingColor(ping)
		if ping <= 90 then
			return green
		end

		if ping <= 180 then
			return yellow
		end
		return red
	end

	local function updateHudScale()
		if not hudScale then
			return
		end
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)

		if viewport.X < 1 then
			viewport = Vector2.new(1280, 720)
		end

		hudScale.Scale = math.clamp(viewport.X * hudFontScale / hudWidth, 0.7, 1.4) * hudSizeScale
	end

	local function destroyHud()
		for _, connection in ipairs(hudConnections) do
			pcall(function()
				connection:Disconnect()
			end)
		end

		table.clear(hudConnections)

		if hudScreen then
			pcall(function()
				hudScreen:Destroy()
			end)
		end

		hudScreen = nil
		hudFrame = nil
		hudScale = nil
		fpsLabel = nil
		pingLabel = nil
		smoothedFps = 0
	end

	local function makeHudLabel(parent, x, width, textColor)
		local label = Instance.new("TextLabel")
		label.Name = randomId()
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(x, 9)
		label.Size = UDim2.fromOffset(width, 16)
		label.Text = ""
		label.TextColor3 = textColor
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left

		if hudFont then
			label.FontFace = hudFont
		else
			label.Font = Enum.Font.GothamBold
		end

		label.Parent = parent
		return label
	end

	local function createHud()
		destroyHud()

		hudScreen = Instance.new("ScreenGui")
		hudScreen.Name = randomId()
		hudScreen.Archivable = false
		hudScreen.DisplayOrder = 58
		hudScreen.IgnoreGuiInset = true
		hudScreen.ResetOnSpawn = false
		hudScreen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

		hudFrame = Instance.new("Frame")
		hudFrame.Name = randomId()
		hudFrame.Active = true
		hudFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
		hudFrame.BackgroundTransparency = 0.28
		hudFrame.BorderSizePixel = 0
		hudFrame.Position = getHudPosition()
		hudFrame.Size = UDim2.fromOffset(132, 34)
		hudFrame.Parent = hudScreen

		local corner = Instance.new("UICorner")
		corner.Name = randomId()
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = hudFrame

		local stroke = Instance.new("UIStroke")
		stroke.Name = randomId()
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Thickness = 1
		stroke.Transparency = 0.9
		stroke.Parent = hudFrame

		hudScale = Instance.new("UIScale")
		hudScale.Name = randomId()
		hudScale.Parent = hudFrame
		updateHudScale()

		fpsLabel = makeHudLabel(hudFrame, 12, 34, green)
		makeHudLabel(hudFrame, 48, 22, grey).Text = "FPS"

		local separator = Instance.new("Frame")
		separator.Name = randomId()
		separator.AnchorPoint = Vector2.new(0.5, 0.5)
		separator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		separator.BackgroundTransparency = 0.85
		separator.BorderSizePixel = 0
		separator.Position = UDim2.new(0, 74, 0.5, 0)
		separator.Size = UDim2.fromOffset(1, 14)
		separator.Parent = hudFrame

		pingLabel = makeHudLabel(hudFrame, 82, 30, green)
		makeHudLabel(hudFrame, 113, 14, grey).Text = "ms"
		hudScreen.Parent = guiParent

		local camera = workspace.CurrentCamera

		if camera then
			hudConnections[#hudConnections + 1] = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateHudScale)
		end

		local dragging = false
		local touchInput = nil
		local dragStart = Vector2.zero
		local startPosition = nil

		hudConnections[#hudConnections + 1] = hudFrame.InputBegan:Connect(function(input)
			if dragging or input.UserInputState ~= Enum.UserInputState.Begin then
				return
			end
			local isTouch = input.UserInputType == Enum.UserInputType.Touch
			if not (input.UserInputType == Enum.UserInputType.MouseButton1) and not isTouch then
				return
			end
			dragging = true
			touchInput = isTouch and input or nil
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startPosition = hudFrame.Position
		end)

		hudConnections[#hudConnections + 1] = UserInputService.InputChanged:Connect(function(input)
			if not dragging or not hudFrame or not startPosition then
				return
			end

			if not (touchInput and input == touchInput or not touchInput and input.UserInputType == Enum.UserInputType.MouseMovement) then
				return
			end
			local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
			hudFrame.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
		end)

		hudConnections[#hudConnections + 1] = UserInputService.InputEnded:Connect(function(input)
			if not dragging then
				return
			end

			if touchInput and input == touchInput or not touchInput and input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
				touchInput = nil
				startPosition = nil

				if hudFrame then
					saveHudPosition(hudFrame.Position)
				end
			end
		end)

		hudConnections[#hudConnections + 1] = RunService.RenderStepped:Connect(function(deltaTime)
			if not hudEnabled or not fpsLabel then
				return
			end
			local clampedDelta = math.clamp(deltaTime, 0.001, 1)
			local instantFps = 1 / clampedDelta

			if smoothedFps <= 0 then
				smoothedFps = instantFps
			else
				smoothedFps = smoothedFps + (instantFps - smoothedFps) * (1 - math.exp(-clampedDelta * hudSmoothFactor))
			end

			local now = os.clock()
			if now < nextPingUpdateAt then
				return
			end
			nextPingUpdateAt = now + hudUpdateInterval
			local roundedFps = math.floor(smoothedFps + 0.5)
			local fpsText = tostring(roundedFps)

			if fpsText ~= lastFpsText then
				lastFpsText = fpsText
				fpsLabel.Text = fpsText
				fpsLabel.TextColor3 = fpsColor(roundedFps)
			end

			local pingValue = 0

			pcall(function()
				pingValue = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
			end)

			local roundedPing = math.floor(pingValue + 0.5)
			local pingText = tostring(roundedPing)

			if pingText ~= lastPingText then
				lastPingText = pingText
				pingLabel.Text = pingText
				pingLabel.TextColor3 = pingColor(roundedPing)
			end
		end)
	end

	local fpsPingToggle = performanceSection:CreateToggle({
		Name = "FPS and Ping",
		Default = true,
		Callback = function(arg)
			hudEnabled = arg == true

			if hudEnabled then
				createHud()
			else
				destroyHud()
			end
		end,
	})

	performanceSection:CreateSlider({
		Name = "FPS and Ping Size",
		Min = 60,
		Max = 160,
		Default = 100,
		AllowDecimals = false,
		Increment = 1,
		Unit = "%",
		SubOf = fpsPingToggle,
		Callback = function(arg)
			hudSizeScale = math.clamp((tonumber(arg) or 100) / 100, 0.6, 1.6)
			updateHudScale()
		end,
	})

	task.spawn(function()
		task.wait(0.2)
		if fpsPingToggle:Get() == true and not hudScreen then
			hudEnabled = true
			createHud()
		end
	end)

	registerCleanup(destroyHud)
end

do
	local utilitySection = miscTab:CreateSection({ Name = "Utility", Expanded = true })
	local antiAfkState = { Enabled = true, Alive = true, Silenced = {} }

	local function getIdledConnections()
		if type(getconnections) ~= "function" then
			return {}
		end
		local ok, result = pcall(getconnections, localPlayer.Idled)
		return ok and type(result) == "table" and result or {}
	end

	local function silenceIdled()
		for _, connection in ipairs(getIdledConnections()) do
			if pcall(function()
				connection:Disable()
			end) then
				antiAfkState.Silenced[#antiAfkState.Silenced + 1] = connection
			end
		end
	end

	local function restoreIdled()
		local silenced = antiAfkState.Silenced

		if #silenced == 0 then
			silenced = getIdledConnections()
		end

		for _, connection in ipairs(silenced) do
			pcall(function()
				connection:Enable()
			end)
		end

		table.clear(antiAfkState.Silenced)
	end

	local antiAfkStub = setmetatable({}, {
		__index = function()
			return function()
			end
		end,
	})

	local patchedClosures = {}

	local function findAntiAfkClosures()
		local found = {}
		if type(getgc) ~= "function" or type(debug) ~= "table" or type(debug.getupvalues) ~= "function" then
			return found
		end
		local ok, gcList = pcall(getgc, false)
		if not ok or type(gcList) ~= "table" then
			return found
		end

		for _, closure in ipairs(gcList) do
			if type(closure) == "function" and islclosure(closure) then
				local ok2, source = pcall(debug.info, closure, "s")

				if ok2 and type(source) == "string" and string.find(source, "AntiAFK", 1, true) then
					local ok3, upvalues = pcall(debug.getupvalues, closure)

					if ok3 and type(upvalues) == "table" then
						for key, value in pairs(upvalues) do
							if typeof(value) == "Instance" and value.ClassName == "TeleportService" then
								found[#found + 1] = { Fn = closure, Index = key, Original = value }
							end
						end
					end
				end
			end
		end

		return found
	end

	local function replaceTeleportService()
		for _, entry in ipairs(findAntiAfkClosures()) do
			local ok, current = pcall(debug.getupvalue, entry.Fn, entry.Index)

			if ok and typeof(current) == "Instance" then
				if pcall(debug.setupvalue, entry.Fn, entry.Index, antiAfkStub) then
					patchedClosures[#patchedClosures + 1] = entry
				end
			end
		end
	end

	local function restoreTeleportService()
		for _, entry in ipairs(patchedClosures) do
			pcall(debug.setupvalue, entry.Fn, entry.Index, entry.Original)
		end

		table.clear(patchedClosures)
	end

	local function enforceAntiAfk()
		silenceIdled()

		if #patchedClosures == 0 then
			replaceTeleportService()
		end
	end

	local characterAddedConnection = localPlayer.CharacterAdded:Connect(function()
		task.delay(1, function()
			if antiAfkState.Alive and antiAfkState.Enabled then
				table.clear(antiAfkState.Silenced)
				pcall(enforceAntiAfk)
			end
		end)
	end)

	registerCleanup(function()
		pcall(function()
			characterAddedConnection:Disconnect()
		end)
	end)

	registerCleanup(function()
		antiAfkState.Alive = false
		restoreIdled()
		restoreTeleportService()
	end)

	task.spawn(function()
		while antiAfkState.Alive do
			if antiAfkState.Enabled then
				enforceAntiAfk()
			end

			task.wait(600)
		end
	end)

	utilitySection:CreateToggle({
		Name = "Anti AFK",
		Default = true,
		Callback = function(arg)
			antiAfkState.Enabled = arg ~= false

			if antiAfkState.Enabled then
				enforceAntiAfk()
			else
				restoreIdled()
				restoreTeleportService()
			end
		end,
	})

	utilitySection:CreateToggle({
		Name = "Hide Game Debug",
		Description = "Mutes spammy [Trace] and [Debug] console logs from the game",
		Default = true,
		Callback = function(arg)
			local env = (type(getgenv) == "function" and getgenv()) or _G
			if env.__NEX_LOG_HOOK then
				env.__NEX_LOG_HOOK.enabled = arg ~= false
			end
		end,
	})
end

;(function()
local antiGuardPalette = {
	Card = Color3.fromRGB(10, 8, 16),
	CardTop = Color3.fromRGB(18, 14, 28),
	Stroke = Color3.fromRGB(42, 34, 62),
	Text = Color3.fromRGB(240, 238, 248),
	AccentA = Color3.fromRGB(140, 80, 255),
	AccentB = Color3.fromRGB(180, 120, 255),
	Good = Color3.fromRGB(80, 220, 140),
	Work = Color3.fromRGB(160, 120, 255),
	Bad = Color3.fromRGB(240, 90, 90),
	Off = Color3.fromRGB(48, 44, 60),
	WeldScanGap = 0.1,
	BusyLimit = 6,
	ReleaseAt = 1,
}

local antiGuardFrameHeight = 52
local antiGuardDisposed = true
local antiGuardConnections = {}
local antiGuardState = {
	AreaId = nil,
	SignalCarrying = false,
	WeldCarrying = false,
	Carrying = false,
	Active = false,
	Disguise = nil,
	FlashRequest = nil,
	FlashUntil = 0,
}

local function randomSuffix()
	local chars = {}

	for i = 1, math.random(10, 16) do
		chars[i] = string.char(math.random(97, 122))
	end

	return table.concat(chars)
end

local antiGuardHui = nil
pcall(function()
	antiGuardHui = gethui()
end)

antiGuardHui = antiGuardHui or CoreGui
local TweenService = game:GetService("TweenService")

local function makeInstance(className, parent, properties)
	local instance = Instance.new(className)
	instance.Name = randomSuffix()

	if type(properties) == "table" then
		for key, value in pairs(properties) do
			instance[key] = value
		end
	end

	instance.Parent = parent
	return instance
end

local function tweenInstance(instance, duration, properties, easingStyle)
	local ok, tween = pcall(function()
		local style = easingStyle or Enum.EasingStyle.Quint
		return TweenService:Create(instance, TweenInfo.new(duration, style, Enum.EasingDirection.Out), properties)
	end)

	if ok and tween then
		tween:Play()
	end
end

local antiGuardScreen = makeInstance("ScreenGui", nil, {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = -100,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local antiGuardRoot = makeInstance("Frame", antiGuardScreen, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 1, -120),
	Size = UDim2.fromOffset(226, antiGuardFrameHeight),
	BackgroundTransparency = 1,
})

local antiGuardScaleOuter = makeInstance("UIScale", antiGuardRoot, { Scale = 1 })

local antiGuardCard = makeInstance("Frame", antiGuardRoot, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = antiGuardPalette.Card,
	BorderSizePixel = 0,
	Active = true,
})

makeInstance("UICorner", antiGuardCard, { CornerRadius = UDim.new(0, 14) })

local antiGuardScaleInner = makeInstance("UIScale", antiGuardCard, { Scale = 0.86 })

makeInstance("UIGradient", antiGuardCard, {
	Color = ColorSequence.new(antiGuardPalette.CardTop, antiGuardPalette.Card),
	Rotation = 90,
})

local antiGuardStrokeGradient, antiGuardIconFrame, renderAntiGuardPanel, requestAntiGuardFlash

do
	local cardStroke = makeInstance("UIStroke", antiGuardCard, {
		Thickness = 1.5,
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	antiGuardStrokeGradient = makeInstance("UIGradient", cardStroke, {
		Color = ColorSequence.new(antiGuardPalette.Stroke, antiGuardPalette.Stroke),
	})

	antiGuardIconFrame = makeInstance("Frame", antiGuardCard, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Color3.fromRGB(14, 10, 22),
		BorderSizePixel = 0,
		ZIndex = 2,
	})

	makeInstance("UICorner", antiGuardIconFrame, { CornerRadius = UDim.new(0, 11) })

	local iconStroke = makeInstance("UIStroke", antiGuardIconFrame, {
		Thickness = 1.5,
		Color = antiGuardPalette.Off,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	local iconImage = makeInstance("ImageLabel", antiGuardIconFrame, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
		BackgroundTransparency = 1,
		Image = "rbxassetid://82006436469351",
		ImageTransparency = 0.35,
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 3,
	})

	makeInstance("UICorner", iconImage, { CornerRadius = UDim.new(0, 8) })
	local iconScale = makeInstance("UIScale", iconImage, { Scale = 1 })

	makeInstance("UIGradient", makeInstance("TextLabel", antiGuardCard, {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 56, 0, 7),
		Size = UDim2.new(1, -112, 0, 15),
		Font = Enum.Font.BuilderSansExtraBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Text = "NexHub",
		ZIndex = 2,
	}), {
		Color = ColorSequence.new(Color3.fromRGB(140, 80, 255), Color3.fromRGB(180, 120, 255)),
	})

	makeInstance("TextLabel", antiGuardCard, {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 56, 0, 22),
		Size = UDim2.new(1, -112, 0, 20),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = antiGuardPalette.Text,
		Text = "Anti Guard",
		ZIndex = 2,
	})

	local toggleTrack = makeInstance("TextButton", antiGuardCard, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(42, 22),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		ZIndex = 2,
	})

	makeInstance("UICorner", toggleTrack, { CornerRadius = UDim.new(1, 0) })

	local toggleGradient = makeInstance("UIGradient", toggleTrack, {
		Color = ColorSequence.new(antiGuardPalette.Off, antiGuardPalette.Off),
	})

	local toggleKnob = makeInstance("Frame", toggleTrack, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.fromRGB(245, 245, 250),
		BorderSizePixel = 0,
		ZIndex = 3,
	})

	makeInstance("UICorner", toggleKnob, { CornerRadius = UDim.new(1, 0) })

	local function getAntiGuardStrokeColor()
		return state.AntiGuard.Enabled and antiGuardPalette.AccentA or antiGuardPalette.Off
	end

	renderAntiGuardPanel = function(isImmediate)
		local duration = isImmediate and 0 or 0.28

		if state.AntiGuard.Enabled then
			toggleGradient.Color = ColorSequence.new(antiGuardPalette.AccentA, antiGuardPalette.AccentB)

			antiGuardStrokeGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, antiGuardPalette.Stroke),
				ColorSequenceKeypoint.new(0.45, antiGuardPalette.AccentA),
				ColorSequenceKeypoint.new(0.55, antiGuardPalette.AccentB),
				ColorSequenceKeypoint.new(1, antiGuardPalette.Stroke),
			})

			tweenInstance(toggleKnob, duration, { Position = UDim2.new(1, -19, 0.5, 0) }, Enum.EasingStyle.Back)
			tweenInstance(iconImage, duration, { ImageTransparency = 0 })
			tweenInstance(cardStroke, 0.3, { Transparency = 0 })
		else
			toggleGradient.Color = ColorSequence.new(antiGuardPalette.Off, antiGuardPalette.Off)
			antiGuardStrokeGradient.Color = ColorSequence.new(antiGuardPalette.Stroke, antiGuardPalette.Stroke)
			tweenInstance(toggleKnob, duration, { Position = UDim2.new(0, 3, 0.5, 0) }, Enum.EasingStyle.Back)
			tweenInstance(iconImage, duration, { ImageTransparency = 0.35 })
			tweenInstance(cardStroke, 0.3, { Transparency = 0.2 })
		end

		if antiGuardState.FlashUntil <= os.clock() then
			tweenInstance(iconStroke, duration, { Color = getAntiGuardStrokeColor() })
		end
	end

	requestAntiGuardFlash = function(color, holdDuration)
		antiGuardState.FlashRequest = { Color = color, Hold = holdDuration }
	end

	local function processFlashRequest()
		local request = antiGuardState.FlashRequest
		if not request then
			return
		end
		antiGuardState.FlashRequest = nil
		antiGuardState.FlashUntil = os.clock() + (request.Hold or 0)
		tweenInstance(iconStroke, 0.2, { Color = request.Color })

		if request.Hold then
			task.delay(request.Hold, function()
				local shouldRestore = antiGuardDisposed

				if antiGuardDisposed then
					local flashUntil = antiGuardState.FlashUntil
					shouldRestore = os.clock() >= flashUntil
				end

				if shouldRestore then
					tweenInstance(iconStroke, 0.3, { Color = getAntiGuardStrokeColor() })
				end
			end)
		end
	end

	local function setAntiGuardHandle(value)
		local handle = state.AntiGuard.Handle
		if type(handle) ~= "table" then
			return
		end

		for _, methodName in ipairs({ "Set", "SetValue" }) do
			local ok, methodFn = pcall(function()
				return handle[methodName]
			end)

			if ok and type(methodFn) == "function" and pcall(methodFn, handle, value) then
				return
			end
		end
	end

	state.AntiGuard.Render = renderAntiGuardPanel

	local overlayButton = makeInstance("TextButton", antiGuardCard, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 10,
	})

	antiGuardConnections[#antiGuardConnections + 1] = overlayButton.MouseButton1Click:Connect(function()
		state.AntiGuard.Enabled = not state.AntiGuard.Enabled
		renderAntiGuardPanel(false)
		setAntiGuardHandle(state.AntiGuard.Enabled)
		tweenInstance(iconScale, 0.12, { Scale = 1.15 })

		task.delay(0.12, function()
			if antiGuardDisposed then
				tweenInstance(iconScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end)
	end)

	local baseTrackSize = toggleTrack.Size

	antiGuardConnections[#antiGuardConnections + 1] = overlayButton.MouseEnter:Connect(function()
		tweenInstance(toggleTrack, 0.15, { Size = baseTrackSize + UDim2.fromOffset(2, 2) })
	end)

	antiGuardConnections[#antiGuardConnections + 1] = overlayButton.MouseLeave:Connect(function()
		tweenInstance(toggleTrack, 0.15, { Size = baseTrackSize })
	end)

	local hotbarNameSet = {
		Hotbar = true,
		HotBar = true,
		Toolbar = true,
		ToolBar = true,
		Backpack = true,
		Inventory = true,
	}

	local hotbarRefs = {}
	local scanAccumulator = math.huge
	local layoutAccumulator = math.huge
	local gradientRotation = 0
	local cachedBottomOffset = nil

	local function isFullyShown(gui)
		while gui do
			if gui:IsA("GuiObject") and not gui.Visible then
				return false
			end

			if gui:IsA("LayerCollector") then
				return gui.Enabled
			end
			gui = gui.Parent
		end

		return false
	end

	local function getGuiInsetY()
		local ok, inset = pcall(function()
			return GuiService:GetGuiInset().Y
		end)

		return ok and inset or 0
	end

	local function getTopEdgeY(gui)
		local topY = nil

		for _, descendant in ipairs(gui:GetDescendants()) do
			if descendant:IsA("GuiButton") and descendant.Visible and descendant.AbsoluteSize.Y > 8 and descendant.AbsoluteSize.X > 8 then
				local y = descendant.AbsolutePosition.Y

				if not topY or y < topY then
					topY = y
				end
			end
		end

		return topY or gui.AbsolutePosition.Y
	end

	local function collectHotbarRefs()
		table.clear(hotbarRefs)
		local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
		if not playerGui then
			return
		end

		for _, descendant in ipairs(playerGui:GetDescendants()) do
			if descendant:IsA("GuiObject") and hotbarNameSet[descendant.Name] then
				hotbarRefs[#hotbarRefs + 1] = descendant
			end
		end
	end

	local function collectVisibleButtonRoots()
		local roots = {}

		pcall(function()
			if not StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) then
				return
			end

			for _, child in ipairs(CoreGui.RobloxGui.Backpack:GetChildren()) do
				if child:IsA("GuiObject") then
					roots[#roots + 1] = child
				end
			end
		end)

		for _, ref in ipairs(hotbarRefs) do
			if ref.Parent then
				roots[#roots + 1] = ref
			end
		end

		return roots
	end

	local function layoutAntiGuardPanel()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		if viewport.X < 10 or viewport.Y < 10 then
			return
		end
		local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local baseScale = math.min(viewport.X / 1280, viewport.Y / 720)
		local scale = isMobile and math.clamp(baseScale * 1.05, 0.6, 0.8) * 0.97 or math.clamp(baseScale, 0.8, 1.1)
		antiGuardScaleOuter.Scale = scale
		local cardTransparency = isMobile and 0.3 or 0

		if antiGuardCard.BackgroundTransparency ~= cardTransparency then
			antiGuardCard.BackgroundTransparency = cardTransparency
			antiGuardIconFrame.BackgroundTransparency = cardTransparency
		end

		local bottomEdge = viewport.Y - 8 * scale
		local foundHotbar = false

		for _, ref in ipairs(collectVisibleButtonRoots()) do
			local ok, visible = pcall(isFullyShown, ref)

			if ok and visible then
				local absoluteSize = ref.AbsoluteSize
				local topY = ref.AbsolutePosition.Y

				if absoluteSize.X > 20 and absoluteSize.Y > 20 and absoluteSize.Y < viewport.Y * 0.4 and topY + absoluteSize.Y / 2 > viewport.Y * 0.5 then
					local ok2, measuredTop = pcall(getTopEdgeY, ref)
					topY = ok2 and measuredTop or topY
					foundHotbar = true
					bottomEdge = math.min(bottomEdge, topY + getGuiInsetY(ref))
				end
			end
		end

		if foundHotbar then
			cachedBottomOffset = viewport.Y - bottomEdge
		elseif cachedBottomOffset then
			bottomEdge = viewport.Y - cachedBottomOffset
		end

		local positionY = math.max(bottomEdge - (isMobile and 4 or 6) * scale - antiGuardFrameHeight * scale / 2, antiGuardFrameHeight * scale / 2 + 8)
		antiGuardRoot.Position = UDim2.new(0.5, 0, 0, positionY)
	end

	antiGuardConnections[#antiGuardConnections + 1] = RunService.RenderStepped:Connect(function(deltaTime)
		processFlashRequest()
		scanAccumulator = scanAccumulator + deltaTime
		layoutAccumulator = layoutAccumulator + deltaTime

		if scanAccumulator >= 3 then
			scanAccumulator = 0
			pcall(collectHotbarRefs)
		end

		if layoutAccumulator >= 0.2 then
			layoutAccumulator = 0
			pcall(layoutAntiGuardPanel)
		end

		if state.AntiGuard.Enabled then
			gradientRotation = (gradientRotation + deltaTime * (antiGuardState.Active and 360 or 90)) % 360
			antiGuardStrokeGradient.Rotation = gradientRotation
		end
	end)
end

renderAntiGuardPanel(true)

state.AntiGuard.ShowPanel = function(shown)
	antiGuardScreen.Enabled = shown == true
end

antiGuardScreen.Enabled = state.AntiGuard.PanelShown == true
antiGuardScreen.Parent = antiGuardHui
tweenInstance(antiGuardScaleInner, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

local findHeldEgg

findHeldEgg = function()
	local root = state.Root()
	if not root then
		return nil
	end

	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Model") and child:FindFirstChild("Hitbox") then
			for _, descendant in ipairs(child:GetDescendants()) do
				if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") or descendant:IsA("RigidConstraint") then
					local ok, partA, partB = pcall(function()
						return descendant.Part0, descendant.Part1
					end)

					if ok and (partA == root or partB == root) then
						return child
					end
				end
			end
		end
	end

	return nil
end

do
	local function cloneCharacterForDisguise(source, parent)
		local savedArchivable = {}

		for _, descendant in ipairs(source:GetDescendants()) do
			savedArchivable[descendant] = descendant.Archivable

			pcall(function()
				descendant.Archivable = true
			end)
		end

		local sourceArchivable = source.Archivable
		source.Archivable = true

		local ok, clone = pcall(function()
			return source:Clone()
		end)

		source.Archivable = sourceArchivable

		for instance, archivable in pairs(savedArchivable) do
			pcall(function()
				instance.Archivable = archivable
			end)
		end

		if not ok or not clone then
			return nil
		end
		clone.Name = randomSuffix()

		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("LuaSourceContainer")
				or descendant:IsA("Sound")
				or descendant:IsA("ForceField")
				or descendant:IsA("JointInstance")
				or descendant:IsA("Constraint")
				or descendant:IsA("WeldConstraint")
				or descendant:IsA("BodyMover")
				or descendant:IsA("ProximityPrompt")
				or descendant:IsA("BillboardGui")
			then
				pcall(function()
					descendant:Destroy()
				end)
			elseif descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			elseif descendant:IsA("Humanoid") then
				descendant.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				descendant.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			end
		end

		clone.Parent = parent
		return clone
	end

	local function applyCharacterDisguise(character, offset)
		local camera = workspace.CurrentCamera
		if not character or not camera or antiGuardState.Disguise then
			return
		end
		offset = offset or Vector3.zero
		local disguise = { Camera = camera, CameraType = camera.CameraType, CameraCFrame = camera.CFrame, Copies = {}, Hidden = {} }
		antiGuardState.Disguise = disguise
		local sources = { character }
		local ok, held = pcall(findHeldEgg)

		if ok and held then
			sources[#sources + 1] = held
		end

		for _, source in ipairs(sources) do
			for _, descendant in ipairs(source:GetDescendants()) do
				if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
					disguise.Hidden[#disguise.Hidden + 1] = descendant
				end
			end
		end

		local function updateCamera()
			for _, part in ipairs(disguise.Hidden) do
				pcall(function()
					part.LocalTransparencyModifier = 1
				end)
			end

			pcall(function()
				if camera.CameraType ~= Enum.CameraType.Scriptable then
					camera.CameraType = Enum.CameraType.Scriptable
				end

				camera.CFrame = disguise.CameraCFrame
			end)
		end

		updateCamera()
		disguise.BindName = randomSuffix()

		if not pcall(function()
			RunService:BindToRenderStep(disguise.BindName, Enum.RenderPriority.Last.Value + 1, updateCamera)
		end) then
			disguise.BindName = nil
			disguise.Link = RunService.RenderStepped:Connect(updateCamera)
		end

		disguise.Beat = RunService.Heartbeat:Connect(updateCamera)

		for _, source in ipairs(sources) do
			local ok2, copy = pcall(cloneCharacterForDisguise, source, camera)

			if ok2 and copy then
				if offset.Magnitude > 0.01 then
					for _, descendant in ipairs(copy:GetDescendants()) do
						if descendant:IsA("BasePart") then
							pcall(function()
								descendant.CFrame = descendant.CFrame + offset
							end)
						end
					end
				end

				disguise.Copies[#disguise.Copies + 1] = copy
			end
		end
	end

	local function removeCharacterDisguise()
		local disguise = antiGuardState.Disguise
		if not disguise then
			return
		end
		antiGuardState.Disguise = nil

		if disguise.BindName then
			pcall(function()
				RunService:UnbindFromRenderStep(disguise.BindName)
			end)
		end

		if disguise.Link then
			pcall(function()
				disguise.Link:Disconnect()
			end)
		end

		if disguise.Beat then
			pcall(function()
				disguise.Beat:Disconnect()
			end)
		end

		for _, part in ipairs(disguise.Hidden) do
			pcall(function()
				part.LocalTransparencyModifier = 0
			end)
		end

		pcall(function()
			disguise.Camera.CameraType = disguise.CameraType
		end)

		for _, copy in ipairs(disguise.Copies) do
			pcall(function()
				copy:Destroy()
			end)
		end
	end

	local antiGuardHomePaths = {
		{ Path = { "GearGiver_Slap", "Podium" }, Offset = Vector3.new(-16.415, 21.072, -6.106) },
		{
			Path = { "World", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" },
			Offset = Vector3.new(-26.776, 1.75, 18.665),
		},
		{
			Path = { "__OBJECTS", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" },
			Offset = Vector3.new(-26.776, 1.75, 18.665),
		},
	}

	local function getHomePosition()
		for _, candidate in ipairs(antiGuardHomePaths) do
			local current = workspace

			for _, segment in ipairs(candidate.Path) do
				current = current and current:FindFirstChild(segment) or nil
			end

			if current and current:IsA("BasePart") then
				return current.CFrame:PointToWorldSpace(candidate.Offset)
			end
		end

		return Vector3.new(528.7, 70.57, -364.11)
	end

	local function moveCharacterTo(character, root, position, rotation, freeze)
		local cframe = CFrame.new(position) * rotation

		pcall(function()
			character:PivotTo(cframe)
		end)

		if (root.Position - position).Magnitude > 3 then
			pcall(function()
				root.CFrame = cframe
			end)
		end

		if freeze == false then
			return
		end

		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:IsA("BasePart") then
				pcall(function()
					descendant.AssemblyLinearVelocity = Vector3.zero
					descendant.AssemblyAngularVelocity = Vector3.zero
				end)
			end
		end
	end

	local function getCurrentAreaId()
		local areaId = antiGuardState.AreaId

		if type(areaId) ~= "string" or areaId == "" then
			areaId = type(state.Steal) == "table" and state.Steal.CarryAreaId or nil
		end

		if type(areaId) ~= "string" or areaId == "" then
			local attribute = localPlayer:GetAttribute("AreaId")
			areaId = type(attribute) == "string" and attribute or nil
		end

		return areaId
	end

	local nexHubAntiGuard = {
		Default = {
			Target    = "edge",
			LineOffset = 8,
			StartAt   = 0.08,
			ReleaseAt = 2.2,
			Steps     = {
				{ At = 0.08, To = "final" },
				{ At = 1.60, To = "start" },
			},
		},

		EnchantedForest = {
			Target    = "edge",
			LineOffset = 6,
			StartAt   = 0.05,
			ReleaseAt = 1.8,
			BusyLimit = 7,
			Steps     = {
				{ At = 0.05, To = "final", Glide = {0.25, 0.5, 0.75, 1.0} },
				{ At = 1.30, To = "start", Glide = {0.5, 1.0} },
			},
		},

		LightDark = {
			Target    = "edge",
			LineOffset = 6,
			StartAt   = 0.05,
			ReleaseAt = 1.9,
			BusyLimit = 7,
			Steps     = {
				{ At = 0.05, To = "final", Glide = {0.3, 0.6, 0.9, 1.0} },
				{ At = 1.35, To = "start", Glide = {0.5, 1.0} },
			},
		},
	}

	local presetAliases = { lightdark = "LightDark", enchantedforest = "EnchantedForest" }

	local function normalizeAreaId(areaId)
		if type(areaId) ~= "string" then
			return "Default"
		end
		local lower = string.lower
		local stripped = string.gsub(areaId, "[^%a]", "")
		return presetAliases[lower(stripped)] or "Default"
	end

	local function getAntiGuardPreset()
		local ok, result = pcall(function()
			return getgenv().NexHubAntiGuard
		end)

		if ok and type(result) == "table" then
			if type(result.Steps) == "table" then
				return result
			end
			local default = result[normalizeAreaId(getCurrentAreaId())] or result.Default
			if type(default) == "table" then
				return default
			end
		end

		local defaultPreset = type(nexHubAntiGuard) == "table" and nexHubAntiGuard[normalizeAreaId(getCurrentAreaId())] or nil
		return defaultPreset or antiGuardPalette
	end

	local function getEffectiveAntiGuardPreset()
		local preset = getAntiGuardPreset()
		local options = state.AntiGuard.Options
		if type(options) ~= "table" or (options.Destination == "Safe Zone" and not options.Stay) then
			return preset
		end
		local merged = {}

		for key, value in pairs(preset) do
			merged[key] = value
		end

		if options.Destination == "Next To Line" then
			merged.Target = "edge"
			merged.LineOffset = 6
			merged.Height = 0
			merged.OffsetX = 0
			merged.OffsetZ = 0
		elseif options.Destination == "Saved Spot" and typeof(options.Spot) == "Vector3" then
			merged.Target = "point"
			merged.Point = options.Spot
			merged.Height = 0
			merged.OffsetX = 0
			merged.OffsetZ = 0
		end

		if options.Stay and type(preset.Steps) == "table" then
			local steps = {}

			for _, step in ipairs(preset.Steps) do
				if type(step) == "table" and step.To ~= "start" then
					steps[#steps + 1] = step
				end
			end

			merged.Steps = steps
		end

		return merged
	end

	local function computeLinePoint(preset, referencePosition)
		local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
		world = world and world:FindFirstChild("Areas")
		world = world and world:FindFirstChild("SeparationLine")

		if world and world:IsA("BasePart") then
			local cframe = world.CFrame
			local referenceAxis = world.Size.X >= world.Size.Z and cframe.RightVector or cframe.LookVector
			local cross = Vector3.new(0, 1, 0):Cross(referenceAxis)
			local horizontal = Vector3.new(cross.X, 0, cross.Z)

			if horizontal.Magnitude > 0.001 then
				local direction = horizontal.Unit
				local signedDistance = (referencePosition - cframe.Position):Dot(direction)
				local offsetDirection = signedDistance >= 0 and -direction or direction
				local linePoint = cframe.Position + offsetDirection * (tonumber(preset.LineOffset) or 8)
				return Vector3.new(linePoint.X, referencePosition.Y + 0.5, linePoint.Z)
			end
		end

		return nil
	end

	local function computeTargetPoint(preset, referencePosition)
		local targetKind = tostring(preset.Target or "home")
		if targetKind == "sky" then
			return referencePosition
		end

		if targetKind == "point" then
			if typeof(preset.Point) == "Vector3" then
				return preset.Point
			end
			return referencePosition
		end

		if targetKind == "line" then
			local linePoint = computeLinePoint(preset, referencePosition)
			if linePoint then
				return linePoint
			end
		end

		if targetKind == "edge" then
			local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
			world = world and world:FindFirstChild("Areas")
			world = world and world:FindFirstChild("SeparationLine")

			if world and world:IsA("BasePart") then
				local cframe = world.CFrame
				local referenceAxis = world.Size.X >= world.Size.Z and cframe.RightVector or cframe.LookVector
				local forward = Vector3.new(referenceAxis.X, 0, referenceAxis.Z)
				local cross = Vector3.new(0, 1, 0):Cross(forward)
				local lateral = Vector3.new(cross.X, 0, cross.Z)

				if lateral.Magnitude > 0.001 and forward.Magnitude > 0.001 then
					local forwardUnit = forward.Unit
					local lateralUnit = lateral.Unit
					local relative = referencePosition - cframe.Position
					local minExtent = -world.Size.Magnitude / 2
					local maxExtent = world.Size.Magnitude / 2
					local along = math.clamp(relative:Dot(forwardUnit), minExtent, maxExtent)
					local side = relative:Dot(lateralUnit) >= 0 and lateralUnit or -lateralUnit
					local edgePoint = cframe.Position + forwardUnit * along + side * (tonumber(preset.LineOffset) or 6)
					local home = getHomePosition()
					return Vector3.new(edgePoint.X, (home and home.Y or referencePosition.Y) + 3, edgePoint.Z)
				end
			end
		end

		return getHomePosition()
	end

	local function computeFinalPoint(preset, referencePosition)
		return computeTargetPoint(preset, referencePosition)
			+ Vector3.new(tonumber(preset.OffsetX) or 0, tonumber(preset.Height) or 0, tonumber(preset.OffsetZ) or 0)
	end

	local function clearAntiGuardState()
		antiGuardState.Active = false
		state.AntiGuard.Busy = false
	end

	local function randomJitter(amount)
		local range = math.max(tonumber(amount) or 0, 0)
		if range <= 0 then
			return 0
		end
		return (math.random() * 2 - 1) * range
	end

	local function buildStepsFromConfig(preset)
		local steps = type(preset.Steps) == "table" and preset.Steps or {}
		local releaseAt = tonumber(preset.ReleaseAt) or 0
		local startAt = math.max(tonumber(preset.StartAt) or 0, 0)
		local startRandom = math.max(tonumber(preset.StartRandom) or 0, 0)
		local hopRandom = math.max(tonumber(preset.HopRandom) or 0, 0)
		local holdRandom = math.max(tonumber(preset.HoldRandom) or 0, 0)

		if startRandom <= 0 and hopRandom <= 0 and holdRandom <= 0 then
			return steps, releaseAt, startAt
		end
		local currentAt = math.max(startAt + randomJitter(startRandom), 0)
		local built = {}
		local lastAt = 0
		local finalAt = 0

		for i, step in ipairs(steps) do
			if type(step) == "table" then
				local stepAt = math.max(tonumber(step.At) or 0, 0)
				local jitter = step.To == "start" and holdRandom or hopRandom
				finalAt = math.max(finalAt + math.max(stepAt - lastAt, 0) + randomJitter(jitter), currentAt)
				built[i] = { At = finalAt, To = step.To, Glide = step.Glide }
				lastAt = stepAt
				continue
			end

			break
		end

		return built, finalAt + math.max(releaseAt - lastAt, 0), currentAt
	end

	local function runAntiGuardFakeSteps(triggerTime)
		local character = localPlayer.Character
		local root = state.Root()
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if not root or not humanoid or humanoid.Health <= 0 then
			clearAntiGuardState()
			requestAntiGuardFlash(antiGuardPalette.Bad, 1.6)
			return
		end

		local function isStillValid()
			return antiGuardDisposed
				and root.Parent ~= nil
				and humanoid.Parent ~= nil
				and humanoid.Health > 0
		end

		local originalPlatformStand = humanoid.PlatformStand
		local originalCFrame = root.CFrame
		local originalPosition = originalCFrame.Position
		local preset = getEffectiveAntiGuardPreset()
		local steps, releaseAt, startAt = buildStepsFromConfig(preset)
		local shouldFreeze = preset.Freeze ~= false
		local facingMode = tostring(preset.Facing or "Keep")
		local jitterAmount = math.max(tonumber(preset.Jitter) or 0, 0)
		local baseRotation = facingMode == "Zero" and CFrame.new() or originalCFrame.Rotation

		local function getCurrentRotation()
			if facingMode == "Spin" then
				return CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
			end
			return baseRotation
		end

		local function applyJitter(position)
			if jitterAmount <= 0 then
				return position
			end
			return position + Vector3.new((math.random() * 2 - 1) * jitterAmount, 0, (math.random() * 2 - 1) * jitterAmount)
		end

		local finalPoint = computeFinalPoint(preset, originalPosition)

		local function waitUntil(targetTime)
			while isStillValid() and os.clock() - triggerTime < targetTime do
				RunService.Heartbeat:Wait()

				if shouldFreeze then
					pcall(function()
						root.AssemblyLinearVelocity = Vector3.zero
						root.AssemblyAngularVelocity = Vector3.zero
					end)
				end
			end

			return isStillValid()
		end

		local function hopTo(position, rotation)
			moveCharacterTo(character, root, position, rotation, shouldFreeze)
			RunService.PreSimulation:Wait()

			if isStillValid() and (root.Position - position).Magnitude > 3 then
				moveCharacterTo(character, root, position, rotation, shouldFreeze)
			end
		end

		pcall(function()
			humanoid.BreakJointsOnDeath = false
		end)

		if preset.Disguise ~= false then
			pcall(applyCharacterDisguise, character, Vector3.zero)
		end

		requestAntiGuardFlash(antiGuardPalette.Work)

		if waitUntil(startAt) and preset.Limp ~= false then
			humanoid.PlatformStand = true
		end

		local lastPosition = originalPosition

		for _, step in ipairs(steps) do
			local shouldBreak = type(step) ~= "table"

			if not shouldBreak then
				shouldBreak = not waitUntil(tonumber(step.At) or 0)
			end

			if not shouldBreak then
				local stepDestination = step.To == "start" and originalPosition or applyJitter(finalPoint)
				local stepRotation = getCurrentRotation()

				if type(step.Glide) == "table" and #step.Glide > 0 then
					for _, alpha in ipairs(step.Glide) do
						if isStillValid() then
							local clamped = math.clamp(tonumber(alpha) or 1, 0, 1)
							moveCharacterTo(character, root, lastPosition:Lerp(stepDestination, clamped), stepRotation, shouldFreeze)
							RunService.Heartbeat:Wait()
							continue
						end

						break
					end

					lastPosition = stepDestination
				else
					hopTo(stepDestination, stepRotation)
					lastPosition = stepDestination
				end

				continue
			end

			break
		end

		waitUntil(releaseAt)

		pcall(function()
			humanoid.PlatformStand = originalPlatformStand
		end)

		removeCharacterDisguise()
		clearAntiGuardState()

		if isStillValid() and antiGuardState.Carrying then
			requestAntiGuardFlash(antiGuardPalette.Good, 1.6)
		else
			requestAntiGuardFlash(antiGuardPalette.Bad, 1.6)
		end
	end

	local function runAntiGuardSafely(triggerTime)
		if not pcall(runAntiGuardFakeSteps, triggerTime) then
			pcall(function()
				local humanoid = localPlayer.Character
				humanoid = humanoid and humanoid:FindFirstChildOfClass("Humanoid")

				if humanoid then
					humanoid.PlatformStand = false
				end
			end)

			removeCharacterDisguise()
			clearAntiGuardState()
			requestAntiGuardFlash(antiGuardPalette.Bad, 1.6)
		end
	end

	local antiGuardHitWindow = 25

	local function isHitArmed()
		if state.AntiGuard.HitArms <= 0 then
			return false
		end

		if antiGuardHitWindow < os.clock() - (state.AntiGuard.HitArmedAt or 0) then
			state.AntiGuard.HitArms = 0
			return false
		end

		return true
	end

	local function maybeTriggerAntiGuard()
		local alreadyCarrying = antiGuardState.Carrying
		antiGuardState.Carrying = antiGuardState.SignalCarrying or antiGuardState.WeldCarrying
		local shouldTrigger = antiGuardState.Carrying and not alreadyCarrying and antiGuardDisposed and state.AntiGuard.Enabled
		local allowed

		if shouldTrigger then
			allowed = not (state.SafeCarry.LineDrop and state.Steal.Active)
		else
			allowed = shouldTrigger
		end

		if allowed and not antiGuardState.Active and not isHitArmed() then
			antiGuardState.Active = true
			state.AntiGuard.Busy = true
			state.AntiGuard.BusySince = os.clock()
			task.spawn(runAntiGuardSafely, os.clock())
		end
	end

	local eggState = modules.EggState
	local carryChanged = type(eggState) == "table" and eggState.CarryChanged or nil

	if type(carryChanged) == "table" and type(carryChanged.Connect) == "function" then
		local ok, connection = pcall(carryChanged.Connect, carryChanged, function(payload)
			local signalCarrying = type(payload) == "table" and payload.IsCarrying == true

			if signalCarrying and payload.GuardDisabled == true then
				signalCarrying = false
			end

			if signalCarrying and type(payload.AreaId) == "string" then
				antiGuardState.AreaId = payload.AreaId
			end

			if not signalCarrying then
				antiGuardState.AreaId = nil
			end

			antiGuardState.SignalCarrying = signalCarrying
			maybeTriggerAntiGuard()
		end)

		if ok and connection then
			antiGuardConnections[#antiGuardConnections + 1] = connection
		end
	end

	local weldScanAccumulator = 0

	antiGuardConnections[#antiGuardConnections + 1] = RunService.Heartbeat:Connect(function(deltaTime)
		local isBusy = state.AntiGuard.Busy or antiGuardState.Active
		local isStuck

		if isBusy then
			local busySince = state.AntiGuard.BusySince
			isStuck = os.clock() - busySince > math.max(tonumber(getEffectiveAntiGuardPreset().BusyLimit) or antiGuardPalette.BusyLimit or 6, (tonumber(getEffectiveAntiGuardPreset().ReleaseAt) or 0) + 1)
		else
			isStuck = isBusy
		end

		if isStuck then
			removeCharacterDisguise()
			local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")

			if humanoid and humanoid.PlatformStand and localPlayer:GetAttribute("RaceId") == nil then
				pcall(function()
					humanoid.PlatformStand = false
				end)
			end

			clearAntiGuardState()
		end

		isHitArmed()
		weldScanAccumulator = weldScanAccumulator + deltaTime
		if weldScanAccumulator < (antiGuardPalette.WeldScanGap or 0.1) then
			return
		end
		weldScanAccumulator = 0
		local weldCarrying = findHeldEgg() ~= nil

		if weldCarrying ~= antiGuardState.WeldCarrying then
			antiGuardState.WeldCarrying = weldCarrying
			maybeTriggerAntiGuard()
		end
	end)

	registerCleanup(function()
		antiGuardDisposed = false

		for _, connection in ipairs(antiGuardConnections) do
			pcall(function()
				connection:Disconnect()
			end)
		end

		table.clear(antiGuardConnections)
		removeCharacterDisguise()
		clearAntiGuardState()
		state.AntiGuard.Render = nil
		state.AntiGuard.ShowPanel = nil

		pcall(function()
			antiGuardScreen:Destroy()
		end)
	end)
end
end)()

do
	local TweenService = game:GetService("TweenService")
	local floatingIcon = HUB_LOGO
	local iconBaseSize = 56
	local iconScaleFactor = 0.035
	local dragThreshold = 8
	local pressTweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local releaseTweenInfo = TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local floatingConnections = {}
	local floatingScreen = nil
	local floatingScaleOuter = nil
	local floatingScaleInner = nil

	local function openWindow()
		for _, methodName in ipairs({ "Toggle", "Open" }) do
			local ok, methodFn = pcall(function()
				return window[methodName]
			end)

			if ok and type(methodFn) == "function" then
				pcall(methodFn, window)
				return
			end
		end
	end

	local function updateFloatingScale()
		if not floatingScaleOuter then
			return
		end
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)

		if viewport.X < 1 then
			viewport = Vector2.new(1280, 720)
		end

		floatingScaleOuter.Scale = math.clamp(viewport.X * iconScaleFactor / iconBaseSize, 0.7, 1.4)
	end

	local function destroyFloatingButton()
		for _, connection in ipairs(floatingConnections) do
			pcall(function()
				connection:Disconnect()
			end)
		end

		table.clear(floatingConnections)

		if floatingScreen then
			pcall(function()
				floatingScreen:Destroy()
			end)
		end

		floatingScreen = nil
		floatingScaleOuter = nil
		floatingScaleInner = nil
	end

	local function createFloatingButton()
		destroyFloatingButton()

		floatingScreen = Instance.new("ScreenGui")
		floatingScreen.Name = randomId()
		floatingScreen.Archivable = false
		floatingScreen.DisplayOrder = 59
		floatingScreen.IgnoreGuiInset = true
		floatingScreen.ResetOnSpawn = false
		floatingScreen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

		local floatingFrame = Instance.new("Frame")
		floatingFrame.Name = randomId()
		floatingFrame.AnchorPoint = Vector2.new(0, 0.5)
		floatingFrame.Position = UDim2.new(0, 16, 0.3, 0)
		floatingFrame.Size = UDim2.fromOffset(56, 56)
		floatingFrame.BackgroundTransparency = 1
		floatingFrame.BorderSizePixel = 0
		floatingFrame.Parent = floatingScreen

		floatingScaleOuter = Instance.new("UIScale")
		floatingScaleOuter.Name = randomId()
		floatingScaleOuter.Parent = floatingFrame
		updateFloatingScale()

		local imageButton = Instance.new("ImageButton")
		imageButton.Name = randomId()
		imageButton.AnchorPoint = Vector2.new(0.5, 0.5)
		imageButton.Position = UDim2.fromScale(0.5, 0.5)
		imageButton.Size = UDim2.fromScale(1, 1)
		imageButton.BackgroundTransparency = 1
		imageButton.BorderSizePixel = 0
		imageButton.AutoButtonColor = false
		imageButton.Image = floatingIcon
		imageButton.ScaleType = Enum.ScaleType.Fit
		imageButton.Active = true
		imageButton.Parent = floatingFrame

		floatingScaleInner = Instance.new("UIScale")
		floatingScaleInner.Name = randomId()
		floatingScaleInner.Parent = imageButton

		local floatingCorner = Instance.new("UICorner")
		floatingCorner.Name = randomId()
		floatingCorner.CornerRadius = UDim.new(0.28, 0)
		floatingCorner.Parent = imageButton

		local function tweenButtonScale(targetScale, tweenInfo)
			if floatingScaleInner and TweenService then
				pcall(function()
					TweenService:Create(floatingScaleInner, tweenInfo, { Scale = targetScale }):Play()
				end)
			end
		end

		local function clampPositionToViewport(position)
			local screenSize = floatingScreen.AbsoluteSize
			local buttonSize = floatingFrame.AbsoluteSize
			if screenSize.X <= 0 or screenSize.Y <= 0 then
				return position
			end
			local offsetY = position.Y.Offset + position.Y.Scale * screenSize.Y
			local offsetX = math.clamp(position.X.Offset + position.X.Scale * screenSize.X, 0, math.max(0, screenSize.X - buttonSize.X))
			local clampedY = math.clamp(offsetY, buttonSize.Y * 0.5, math.max(buttonSize.Y * 0.5, screenSize.Y - buttonSize.Y * 0.5))
			return UDim2.fromOffset(offsetX, clampedY)
		end

		local activeInput = nil
		local dragStartPosition = nil
		local startFramePosition = nil
		local isDragging = false
		local didDrag = false

		local function matchesInput(input, isMotion)
			if activeInput == "mouse" then
				return input.UserInputType == (isMotion and Enum.UserInputType.MouseMovement or Enum.UserInputType.MouseButton1)
			end
			return input == activeInput
		end

		floatingConnections[#floatingConnections + 1] = imageButton.InputBegan:Connect(function(input)
			local isTouch = input.UserInputType == Enum.UserInputType.Touch
			if not (input.UserInputType == Enum.UserInputType.MouseButton1) and not isTouch or input.UserInputState ~= Enum.UserInputState.Begin or activeInput then
				return
			end
			activeInput = isTouch and input or "mouse"
			dragStartPosition = Vector2.new(input.Position.X, input.Position.Y)
			startFramePosition = floatingFrame.Position
			isDragging = false
			didDrag = false
			tweenButtonScale(0.9, pressTweenInfo)
		end)

		floatingConnections[#floatingConnections + 1] = UserInputService.InputChanged:Connect(function(input)
			if not activeInput or not matchesInput(input, true) then
				return
			end
			local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStartPosition

			if not isDragging then
				if delta.Magnitude < dragThreshold then
					return
				end
				isDragging = true
				didDrag = true
				tweenButtonScale(1, releaseTweenInfo)
			end

			floatingFrame.Position = clampPositionToViewport(UDim2.new(startFramePosition.X.Scale, startFramePosition.X.Offset + delta.X, startFramePosition.Y.Scale, startFramePosition.Y.Offset + delta.Y))
		end)

		floatingConnections[#floatingConnections + 1] = UserInputService.InputEnded:Connect(function(input)
			if activeInput and matchesInput(input, false) then
				activeInput = nil
				isDragging = false
				tweenButtonScale(1, releaseTweenInfo)
			end
		end)

		floatingConnections[#floatingConnections + 1] = imageButton.Activated:Connect(function()
			if didDrag then
				didDrag = false
				return
			end
			openWindow()
		end)

		local camera = workspace.CurrentCamera

		if camera then
			floatingConnections[#floatingConnections + 1] = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateFloatingScale)
		end

		floatingScreen.Parent = guiParent
	end

	registerCleanup(destroyFloatingButton)
end

nexLibrary:Finalize({ Window = window, MainTab = defaultTab, ShowMainTab = true })
registerCleanup(nexLibrary.Unload)

task.defer(function()
	if #registeredSliders == 0 or type(readfile) ~= "function" then
		return
	end
	local HttpService = game:GetService("HttpService")

	local function readJsonFile(path)
		if type(isfile) == "function" then
			local ok, exists = pcall(isfile, path)

			if ok and not exists then
				return nil
			end
		end

		local ok, content = pcall(readfile, path)
		if not ok or type(content) ~= "string" or content == "" then
			return nil
		end
		local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, content)
		return ok2 and type(decoded) == "table" and decoded or nil
	end

	local configState = readJsonFile("ChilliLibrary/config_state.json") or {}

	if configState.AutoLoad == false then
		return
	end
	local selectedName

	if type(configState.StartupConfig) == "string" and configState.StartupConfig ~= "" then
		selectedName = configState.StartupConfig
	elseif type(configState.SelectedConfig) == "string" and configState.SelectedConfig ~= "" then
		selectedName = configState.SelectedConfig
	else
		selectedName = "Default"
	end
	local configJson = readJsonFile("ChilliLibrary/configs/" .. selectedName .. ".json")

	if type(configJson) ~= "table" or type(configJson.Values) ~= "table" then
		return
	end
	local unitMultipliers = { ["K/s"] = 1000, ["M/s"] = 1000000, ["B/s"] = 1e9 }
	local sliderRestores = {}

	for _, sliderSpec in ipairs(registeredSliders) do
		local hasValue = false
		local legacyEntry = nil

		for _, value in pairs(configJson.Values) do
			local sectionEntry = type(value) == "table" and value[sliderSpec.Section] or nil

			if type(sectionEntry) == "table" then
				if sectionEntry[sliderSpec.Name] ~= nil then
					hasValue = true
				end

				local legacy = sectionEntry[sliderSpec.Legacy]

				if type(legacy) == "table" and tonumber(legacy.Value) then
					legacyEntry = legacy
				end
			end
		end

		if legacyEntry and not hasValue then
			local rawValue = math.max(0, tonumber(legacyEntry.Value)) * (unitMultipliers[tostring(legacyEntry.Unit)] or 1000000)

			if rawValue > 0 then
				table.insert(sliderRestores, { Handle = sliderSpec.Handle, Step = sliderSpec.StepOf(rawValue) })
			end
		end
	end

	for _, delay in ipairs({ 0.1, 1, 2 }) do
		if #sliderRestores == 0 then
			return
		end
		task.wait(delay)

		for _, restore in ipairs(sliderRestores) do
			local ok, current = pcall(restore.Handle.Get, restore.Handle)

			if ok then
				ok = (tonumber(current) or 0) <= 0
			end

			if ok then
				pcall(restore.Handle.Set, restore.Handle, restore.Step)
			end
		end
	end
end)

task.defer(function()
	for _ = 1, 3 do
		RunService.Heartbeat:Wait()
	end

	if type(state.RestoreStealPanel) == "function" then
		pcall(state.RestoreStealPanel)
	end
end)
