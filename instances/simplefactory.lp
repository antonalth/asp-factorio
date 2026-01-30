% ========================================================
% INSTANCE: dependency_test.lp
% Tests: 0-start, Building Construction, and Cross-Zone Flow
% ========================================================

#const horizon = 15.
#const num_zones = 2.
#const num_slots = 40. % Smaller scale for faster debugging

item(iron_ore).
item(iron_plate).

building(miner).
building(furnace).

% Construction Times
dur(miner, 3).
dur(furnace, 3).

% Crafting Speeds (for the 'craft' action, though mostly time-delay)
dur(iron_ore, 1).
dur(iron_plate, 1).

% --- RECIPES ---
% Miner: Produces 2 Ore per tick
building_out(miner, iron_ore, 2).

% Furnace: Consumes 2 Ore, Produces 1 Plate per tick
building_in(furnace, iron_ore, 2).
building_out(furnace, iron_plate, 1).

% --- CAPACITIES ---
% Zone 1 is a mining outpost (high ore capacity, no plate capacity)
stock_cap(iron_ore,   1, 20).
stock_cap(iron_plate, 1, 0).

% Zone 2 is a factory (low ore capacity, high plate capacity)
stock_cap(iron_ore,   2, 5).
stock_cap(iron_plate, 2, 20).

% Global Belt Capacity
global_cap(iron_ore, 50).
global_cap(iron_plate, 50).

% --- INITIAL STATE (CRITICAL FIXES) ---

% 1. Start with NO resources
&sum { stock(I, Z, 0) } = 0 :- item(I), zone(Z).
&sum { globalstock(I, 0) } = 0 :- item(I).

% 2. Start with NO buildings (Solver must build them)
&sum { buildingcount(B, Z, 0) } = 0 :- building(B), zone(Z), slot_map(Z, _, B).

% --- TARGET GOALS ---

% By the end of the horizon, we want to have produced 5 iron plates in Zone 2.
% To do this, the solver MUST:
% 1. Build a miner in Zone 1 (takes 3 steps).
% 2. Mine ore into Zone 1 stock.
% 3. Export ore to the Global Belt.
% 4. Build a furnace in Zone 2 (takes 3 steps).
% 5. Import ore from the Global Belt into Zone 2.
% 6. Smelt the ore into plates.

:- not &sum{ stock(iron_plate, 2, horizon) } >= 5.

% Optional: Help the solver by pre-assigning the layout 
% (or leave it out to let the solver find the best spots)
slot_map(1, 1, miner).
slot_map(2, 1, furnace).