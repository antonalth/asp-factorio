#const horizon = 18.
#const num_zones = 2.
#const num_slots = 8.

%       init_global_stock(I, Amount).
%        init_building_count(B, Z, S, Count).
init_global_stock(assembler, 50).
init_global_stock(stone_furnace, 50).
init_global_stock(electricity, 500).
init_global_stock(coal, 50).
init_building_count(offshore_pump, 1, 1, 1).
init_building_count(power_plant_small, 1, 2, 2).
init_building_count(coal_mine, 1, 3, 1).
init_building_count(iron_mine, 1, 4, 1).
init_building_count(copper_mine, 1, 5, 1).
init_building_count(stone_mine, 1, 6, 1).
init_building_count(copper_smelter, 1, 7, 1).
init_building_count(iron_smelter, 1, 8, 1).
%init_building_count(steel_smelter, 2, 1, 1).
%init_building_count(stone_smelter, 2, 2, 1).
%init_building_count(green_circuit_assembler, 2, 3, 1).
%init_building_count(oil_mine, 2, 4, 1).

goal_item(red_circuit, 1).

init_local_cap(I, Z, 50) :- item(I), zone(Z).
