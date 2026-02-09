% ========================================================
% INSTANCE: factorio_burner_to_green.lp
% Scenario: From Hand-Mining to Green Circuits
% Step Size: ~30 Seconds
% ========================================================

% Horizon: 25 steps (Given the manual labor, we need time)
#const horizon = 25.
#const num_zones = 4. 
#const num_slots = 3.

% --- ITEMS ---
% Raw
item(stone).
item(coal).
item(iron_ore).
item(copper_ore).
% Intermediates
item(iron_plate).
item(copper_plate).
item(copper_cable).
% Final
item(green_circuit).
% Abstract "Actions" (items produced by manual labor)
crafting(hand_stone).
crafting(hand_coal).
crafting(hand_iron).
crafting(hand_copper).
crafting(hand_cable).
crafting(hand_circuit).
crafting(action_mine). 


% --- BUILDINGS ---
% 1. Burner Drill (Coal): Self-feeding (simplified), outputs coal.
building(drill_burner_coal).
% 2. Burner Drill (Iron/Copper): Needs Coal to run.
building(drill_burner_iron).
building(drill_burner_copper).
% 3. Stone Furnace: Needs Coal to smelt.
building(furnace_stone_iron).
building(furnace_stone_copper).
% 4. Electric Assembler (Assumed unlocked for goal)
building(assembler_cable).
building(assembler_circuit).

% --- 1. PLAYER HAND ACTIONS (Modeled as Crafting) ---
% These represent the player spending 30s hitting rocks with a pickaxe.

% Hand Mining Stone
dur(hand_stone, 1).
crafting_out(hand_stone, stone, 10). 

% Hand Mining Coal
dur(hand_coal, 1).
crafting_out(hand_coal, coal, 10).

% Hand Mining Ores
dur(hand_iron, 1).
crafting_out(hand_iron, iron_ore, 10).
dur(hand_copper, 1).
crafting_out(hand_copper, copper_ore, 10).

% Hand Crafting Intermediate: Copper Cable (Player can do this)
dur(hand_cable, 1).
crafting_cost(hand_cable, copper_plate, 1).
crafting_out(hand_cable, copper_cable, 2).

% Hand Crafting Final: Green Circuit (Player can do this)
dur(hand_circuit, 1).
crafting_cost(hand_circuit, iron_plate, 1).
crafting_cost(hand_circuit, copper_cable, 3).
crafting_out(hand_circuit, green_circuit, 1).

% --- 2. CONSTRUCTION COSTS (What you need to build machines) ---

% Stone Furnace: Costs 5 Stone.
dur(furnace_stone_iron, 1).
dur(furnace_stone_copper, 1).
building_cost(furnace_stone_iron, stone, 5).
building_cost(furnace_stone_copper, stone, 5).

% Burner Drill: Costs 10 Iron Plates + 5 Stone.
% (Simplified recipe: Iron Gear Wheel and Furnace included in this cost)
dur(drill_burner_coal, 1).
dur(drill_burner_iron, 1).
dur(drill_burner_copper, 1).
building_cost(drill_burner_coal, iron_plate, 10).
building_cost(drill_burner_coal, stone, 5).
building_cost(drill_burner_iron, iron_plate, 10).
building_cost(drill_burner_iron, stone, 5).
building_cost(drill_burner_copper, iron_plate, 10).
building_cost(drill_burner_copper, stone, 5).

% Assembler: Costs 10 Iron, 5 Copper.
dur(assembler_cable, 1).
dur(assembler_circuit, 1).
building_cost(assembler_cable, iron_plate, 10).
building_cost(assembler_cable, copper_plate, 5).
building_cost(assembler_circuit, iron_plate, 10).
building_cost(assembler_circuit, copper_plate, 5).

% --- 3. BUILDING RECIPES (Inputs/Outputs per 30s) ---

% -- COAL DRILL --
% In Factorio, burner drills on coal feed themselves.
% Output: 15 Coal (Net gain after self-fuel).
building_out(drill_burner_coal, coal, 15).

% -- ORE DRILLS (Iron/Copper) --
% Input: 2 Coal (Fuel).
% Output: 15 Ore.
building_in(drill_burner_iron, coal, 2).
building_out(drill_burner_iron, iron_ore, 15).

building_in(drill_burner_copper, coal, 2).
building_out(drill_burner_copper, copper_ore, 15).

% -- STONE FURNACES --
% Input: 2 Coal (Fuel) + 15 Ore.
% Output: 15 Plates.
building_in(furnace_stone_iron, coal, 2).
building_in(furnace_stone_iron, iron_ore, 15).
building_out(furnace_stone_iron, iron_plate, 15).

building_in(furnace_stone_copper, coal, 2).
building_in(furnace_stone_copper, copper_ore, 15).
building_out(furnace_stone_copper, copper_plate, 15).

% -- ASSEMBLERS (Assumed Electric/Powered for simplicity of model) --
% Cable: 10 Copper Plates -> 20 Cables
building_in(assembler_cable, copper_plate, 10).
building_out(assembler_cable, copper_cable, 20).

% Circuit: 5 Iron Plates + 15 Cables -> 5 Circuits
building_in(assembler_circuit, iron_plate, 5).
building_in(assembler_circuit, copper_cable, 15).
building_out(assembler_circuit, green_circuit, 5).

% --- 4. ZONES & CAPACITIES ---

% Zone 1: The Coal & Stone Patch
init_local_cap(coal, 1, 200).
init_local_cap(stone, 1, 200).

% Zone 2: The Iron Patch
init_local_cap(iron_ore, 2, 100).
init_local_cap(iron_plate, 2, 100).
init_local_cap(coal, 2, 50). % Needs coal buffer for fuel

% Zone 3: The Copper Patch
init_local_cap(copper_ore, 3, 100).
init_local_cap(copper_plate, 3, 100).
init_local_cap(coal, 3, 50). % Needs coal buffer for fuel

% Zone 4: Assembly Area
init_local_cap(copper_cable, 4, 200).
init_local_cap(green_circuit, 4, 100).

% Global Belt Limits
init_global_cap(coal, 100).
init_global_cap(stone, 100).
init_global_cap(iron_plate, 100).
init_global_cap(copper_plate, 100).
init_global_cap(copper_cable, 100).
init_global_cap(green_circuit, 100).

% --- 5. INITIAL STATE ---
% Player starts with NOTHING (except ability to work).
% No stocks. 

% --- 6. GOALS ---
% Goal: Produce 10 Green Circuits.
goal_item(green_circuit, 10).

% Goal: Must have automated mining and smelting.
goal_building(drill_burner_iron, 1).
goal_building(furnace_stone_iron, 1).
