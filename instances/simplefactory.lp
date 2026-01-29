% ========================================================
% INSTANCE: simple_factory.lp
% ========================================================

#const horizon = 10.
#const num_zones = 2.
#const num_slots = 15. % Match model definition
%#const max_val = 1000.

item(iron_ore).
item(iron_plate).

building(miner).
building(furnace).

dur(miner, 2).
dur(furnace, 2).
dur(I, 1) :- item(I).

% Recipe: Miner
building_out(miner, iron_ore, 1).

% Recipe: Furnace
building_in(furnace, iron_ore, 1).
building_out(furnace, iron_plate, 1).

% Capacities
stock_cap(iron_ore,   1, 50).
stock_cap(iron_plate, 1, 0). 
stock_cap(iron_ore,   2, 10).
stock_cap(iron_plate, 2, 50).

global_cap(iron_ore, 100).
global_cap(iron_plate, 100).

% --- INITIALIZATION (FIXED) ---
% Use &sum constraints to initialize theory variables to 0
&sum { stock(I, Z, 0) } = 0 :- item(I), zone(Z).
&sum { globalstock(I, 0) } = 0 :- item(I).

% --- GOALS ---
:- not buildingcount(miner, 1, horizon) >= 1.
:- not buildingcount(furnace, 2, horizon) >= 1.
:- &sum{ stock(iron_plate, 2, horizon); globalstock(iron_plate, horizon) } < 5.