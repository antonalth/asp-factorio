% ========================================================
% INSTANCE: simple_factory.lp
% ========================================================

% --- 1. CONFIGURATION ---
% Overwrite constants if necessary (passed via command line usually, but explicit here for clarity)
#const horizon = 10.
#const num_zones = 2.
#const num_slots = 5. % Kept small for testing
%#const max_val = 100.

% --- 2. DEFINITIONS ---
item(iron_ore).
item(iron_plate).

building(miner).
building(furnace).

% --- 3. MECHANICS (Recipes & Time) ---

% Building Durations (How long 'busy(build)' lasts)
dur(miner, 2).
dur(furnace, 2).
dur(I, 1) :- item(I). % Dummy for craft action if used

% Recipe: Miner
% Uses nothing, Creates 1 Ore
building_out(miner, iron_ore, 1).

% Recipe: Furnace
% Uses 1 Ore, Creates 1 Plate
building_in(furnace, iron_ore, 1).
building_out(furnace, iron_plate, 1).

% --- 4. CAPACITIES (The Logic Trigger) ---

% Zone 1: Can store Ore, but CANNOT store Plates.
% This tests the "Space" logic. If a furnace is placed here, it MUST export immediately.
stock_cap(iron_ore,   1, 50).
stock_cap(iron_plate, 1, 0). 

% Zone 2: Can store Plates, has limited Ore space (buffer).
stock_cap(iron_ore,   2, 10).
stock_cap(iron_plate, 2, 50).

% Global: The "Transit" network capability
global_cap(iron_ore, 100).
global_cap(iron_plate, 100).

% --- 5. INITIALIZATION ---
% Start with nothing
stock(I, Z, 0) = 0 :- item(I), zone(Z).
globalstock(I, 0) = 0 :- item(I).

% --- 6. GOALS ---

% Goal 1: Structure
% We want at least one miner in Zone 1 and one Furnace in Zone 2
:- not buildingcount(miner, 1, horizon) >= 1.
:- not buildingcount(furnace, 2, horizon) >= 1.

% Goal 2: Production
% We want 5 Iron Plates in the Global Stock (or Zone 2 stock) by the end.
% This proves the chain: Miner(Z1) -> Flow(Z1) -> Global -> Flow(Z2) -> Furnace(Z2) -> Plate.
:- &sum{ stock(iron_plate, 2, horizon); globalstock(iron_plate, horizon) } < 5.

% Optional: Hide unrelated output for cleaner viewing
#show.
#show buildingcount/3.
#show stock/3.
#show slot_map/3.
#show global_flow/4. % Useful to debug if Ore is moving between zones