local constants = require("constants")
local gnomes = constants.gnomes
local recipes = constants.recipes
local ingredients = constants.ingredients

local gnome_helper_view, mapWindow
local currentStep = 1

function check_for_restaurant_task(varTransmitEvent)
	local name = varTransmitEvent.var.configName
	if name == "ALUFT_MINIGAME" then update_helper() end
end

function has_active_order()
	local gnome_id = var.VarPlayer.ALUFT_CURRENT_CUSTOMER.value
	local recipe_id = var.VarPlayer.ALUFT_CURRENT_ORDER.value
	return gnome_id ~= 0 and recipe_id ~= 0
end

-- Highlight items the player needs to buy
function checkShop()
	local shop = ui.Interfaces:GetComponent(id.Component.SHOP_MAIN__LIST_ICON)
	local shopbg = ui.Interfaces:GetComponent(id.Component.SHOP_MAIN__LIST_BACKGROUND)
	local shopName = var.VarPlayer.SHOP.value.configName
	if shopName ~= "GNOMESHOP_HECK" and shopName ~= "GNOMESHOP_HUDO" then return end

	if shop and has_active_order() then
		local orderID = var.VarPlayer.ALUFT_CURRENT_ORDER.value
		if not recipes[orderID] then return end
		ingreds = getIngredients()
		local index = 0
		local inv = Inventory.Find(config.Inv.INV)
		shop:IterateDynamicComponents(function(component,_)
			local bg = shopbg:GetChild(0, index)
			currentIngredient = ingreds[component.associatedObjectID]
			if currentIngredient then
				local amountInInv = inv:GetTotal(currentIngredient[1])
				local amountNeeded = currentIngredient[2]
				local hasEnough = amountInInv >= amountNeeded
				if not hasEnough then
					component.outlineWidth = 3
				else
					bg.fill = false
				end
			else -- Replace items' icons we don't need with a red X
				component.spriteID = 13166
				component.associatedObjectID = -1
				bg.fill = false
			end
			index = index + 1
		end)
	end
end

-- Highlight items the player needs to make
function checkMakeX()
	local makeXWindow = ui.Interfaces:GetComponent(id.Component.MAKEX2012_CONTROLS__ITEMS_LIST)
	if not makeXWindow or not has_active_order() then return end

	local orderID = var.VarPlayer.ALUFT_CURRENT_ORDER.value
	if not recipes[orderID] then return end

	local itemsNeeded = {}
	for _,step in ipairs(recipes[orderID]["Steps"]) do
		itemsNeeded[step[2].id] = true
	end

	local inv = Inventory.Find(config.Inv.INV)
	local redoChildren = {}
	makeXWindow:IterateDynamicComponents(function(component,_) -- Go over everything in the Make-X window
		isIngredientNeeded = itemsNeeded[component.associatedObjectID] or false
		if isIngredientNeeded then
			redoChildren[#redoChildren+1] = component.dynamicID
			local amountInInv = inv:GetTotal(component.associatedObjectID)
			if amountInInv < 1 then
				component.outlineWidth = 3
			else -- Distinguish items we already have enough of
				local firstBg = makeXWindow:GetChild(0, component.dynamicID - 2)
				local secondBg = makeXWindow:GetChild(0, component.dynamicID - 1)
				component.alpha = 0.35
				firstBg.alpha = 0.35
				secondBg.alpha = 0.35
			end
		else -- Replace items' icons we don't need with a red X
			if component.dynamicID % 4 == 1 then
				component.spriteID = 25889
			elseif component.dynamicID % 4 == 2 then
				component.associatedObjectID = -1
			elseif component.dynamicID % 4 == 0 then
				component.spriteID = 13987
			end
		end
	end)
	for i=1, #redoChildren do -- Unchange these elements that got caught in the previous loop
		local firstChild = makeXWindow:GetChild(0, redoChildren[i] - 2)
		local secondChild = makeXWindow:GetChild(0, redoChildren[i] - 1)
		local thirdChild = makeXWindow:GetChild(0, redoChildren[i] + 1)
		firstChild.spriteID, secondChild.spriteID, thirdChild.spriteID = 15199, 15199, -1
	end
end

-- Check inventory to know when we've reached a new step in the recipe
function checkInventory(event)
	if event then
		if event.inv.configName ~= "INV" then return end
	end

	playerInv = Inventory.Find(config.Inv.INV)
	local recipe_id = var.VarPlayer.ALUFT_CURRENT_ORDER.value
	if not has_active_order() then return end
	itemNeeded = recipes[recipe_id]["Steps"][currentStep][2]
	if playerInv:GetTotal(itemNeeded) > 0 then
		currentStep = currentStep + 1
		checkInventory() -- Recursion to check if we have the next step done too
		update_helper()
	end
end

-- Get a list of required ingredients & tools
function getIngredients()
	local ingreds = {}
	local recipe_ingreds = recipes[var.VarPlayer.ALUFT_CURRENT_ORDER.value]["Ingredients"]
	local recipe_tools = recipes[var.VarPlayer.ALUFT_CURRENT_ORDER.value]["Tools"]
	for _, val in ipairs(recipe_ingreds) do
		ingreds[ingredients[val[1]].id] = {ingredients[val[1]], val[2]}
	end
	for _, val in ipairs(recipe_tools) do
		ingreds[ingredients[val].id] = {ingredients[val], 1}
	end
	return ingreds
end

-- Main function that updates the UI
function update_helper()
	local parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
	local gnome_id = var.VarPlayer.ALUFT_CURRENT_CUSTOMER.value
	local recipe_id = var.VarPlayer.ALUFT_CURRENT_ORDER.value
	local activeOrder = has_active_order()

	local gnome = gnomes[gnome_id]
	local dish = recipes[recipe_id]
	local items = {}
	local tools = {}
	local gnomeName, gnomeLoc, dishName, dishID, step, currentStepIndicator, mapResource
		
	if gnome_helper_view then
		gnome_helper_view:Destroy()
		gnome_helper_view = nil
	end

	if activeOrder then
		gnomeName = gnome[1]
		gnomeLoc = gnome[2]
		mapResource = gnome[4]
		dishName = dish["Name"]
		dishID = dish["Id"]
		step = dish["Steps"][currentStep][1]
		currentStepIndicator = string.format("Step %d of %d", currentStep, #dish["Steps"])
		for _, ingredient in ipairs(dish["Ingredients"]) do
			table.insert(items, {
				object = ingredients[ingredient[1]],
				quantity = ingredient[2],
				tooltip = ingredients[ingredient[1]].name
			})
		end
		tools[1] = ingredients[dish["Tools"][1]]
		tools[2] = ingredients[dish["Tools"][2]]
	else
		gnomeName = "NOBODY"
		gnomeLoc = "NOWHERE"
		dishName = "NO DISH"
		step = "NOTHING"
		dishID = config.Obj.SPINNING_PLATE_BROKEN
		currentStep = 1
		currentStepIndicator = "Step 0 of 0"
		closeMapIfOpen()
	end

	gnome_helper_view = prettyui.Window.new(parent,	{
		title = "Gnome Restaurant Helper",
		x = 80,
		y = 80,
		width = 450,
		height = 325,
		scrollable = false,
		resizable = true,
		onClose = function()
			if mapWindow then
				mapWindow:Destroy()
				mapWindow = nil
			end
		end
	})
	gnome_helper_view:AddText("GNOME: " .. "<col=ffffff>" .. gnomeName .. "</col>")
	gnome_helper_view:AddSpriteButton("PIN", function() showMap(mapResource) end, { inline = true, tooltip = "Show on map"})
	gnome_helper_view:AddText("WHERE: " .. "<col=ffffff>" .. gnomeLoc .. "</col>")
	gnome_helper_view:AddText({text = "ORDER: " .. "<col=ffffff>" .. dishName .. "</col>", marginTop = 5})
	gnome_helper_view:AddItemSlot(dishID, {size = 24, inline = true, offsetY = -8})
	gnome_helper_view:AddText({text = "TOOLS:",marginTop = 5})
	local toolGrid = gnome_helper_view:AddItemGrid(tools, {
		columns = 2,
		rows = 1,
		tooltip = true,
		inline = true,
		offsetY = -8
	})
	gnome_helper_view:AddText({text = "INGREDIENTS:", marginTop = 5})
	local grid = gnome_helper_view:AddItemGrid(items, {
		columns = #items,
		rows = 1,
		tooltip = true,
		inline = true,
		quantityMode = 1,
		offsetY = -8
	})

	-- Display the current step in the recipe
	gnome_helper_view:AddText("CURRENT STEP: " .. "<col=ffffff>" .. step .. "</col>")
	local previousStepButton = gnome_helper_view:AddSimpleButton("<sprite=17066>", function()
		if currentStep > 1 then
			currentStep = currentStep - 1
			update_helper()
		end
	end, {marginTop = 2})
	gnome_helper_view:AddText({text = currentStepIndicator, inline = true})
	local nextStepButton = gnome_helper_view:AddSimpleButton("<sprite=17072>", function()
		if dish and currentStep < #dish["Steps"] then
			currentStep = currentStep + 1
			update_helper()
		end
	end, {inline = true})
end

-- Show location of current customer
function showMap(spriteResource)
	if not spriteResource then return end
	if mapWindow then closeMapIfOpen() return end
	local parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
	local helper = gnome_helper_view.root
	local startX = helper.x + helper.width
	mapWindow = prettyui.Window.new(parent, { title = "Gnome Location", x = startX, y = helper.y, width = 330, height = 355, scrollable = false })
	spriteResource:Load()
	mapWindow:AddSprite(spriteResource, {size = 289})
	mapWindow.onClose = function() mapWindow = nil end
end

function closeMapIfOpen()
	if mapWindow then
		mapWindow:Destroy()
		mapWindow = nil
	end
end

-- Highlight the current customer's location
local highlightShape = ShapeData.new()
	highlightShape.positions = {
		Vector3.new(-250, 0, -250),
		Vector3.new(250, 0, -250),
		Vector3.new(250, 0, 250),
		Vector3.new(-250, 0, 250)
	}
	highlightShape.lines = {0, 1, 1, 2, 2, 3, 3, 0}
	highlightShape.tris = {0, 1, 2, 0, 2, 3}
	
Event.Draw.Subscribe("highlightNPCEvent", function(drawEvent)
	local customerID = var.VarPlayer.ALUFT_CURRENT_CUSTOMER.value
	if customerID == 0 then return end

	local gnome = gnomes[customerID]
	if not gnome then return end

	local npcConfig = gnome[3]
	if not npcConfig then return end

	local npcName = npcConfig.name
	local localNPCs = NPCList.ByName(npcName)
	for _, npc in pairs(localNPCs) do
		local coordGrid = npc.coordGrid
		local tilePos = coordGrid:ToCoordFine(true).position
		tilePos.y = World.GetGroundHeight(coordGrid.level, tilePos.x, tilePos.z) + 100.0
		ShapeList.Draw({
			shapeData = highlightShape,
			translation = tilePos,
			colour = 0x00FF00CF,
			ignoreDepth = true,
			lineWidth = 3
		})
	end
end)

Event.VarTransmit.Subscribe("restaurantMinigame", check_for_restaurant_task)
Event.ServerLogic.Subscribe("uiWatcher", checkShop)
Event.InventoryUpdated.Subscribe("inventoryWatcher", checkInventory)
Event.ServerLogic.Subscribe("makeXWatcher", checkMakeX)

function PluginShutdown()
	if gnome_helper_view then
		gnome_helper_view:Destroy()
		gnome_helper_view = nil
	end
	if mapWindow then
		mapWindow:Destroy()
		mapWindow = nil
	end
end

update_helper()