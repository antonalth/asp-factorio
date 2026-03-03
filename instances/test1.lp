#const horizon = 15.
#const num_zones = 2.
#const num_slots = 8.

%       init_global_stock(I, Amount).
%        init_building_count(B, Z, S, Count).

init_global_stock(electricity, 500).
init_global_stock(coal, 500).
init_building_count(offshore_pump, 0, 0, 1).
init_building_count(power_plant_small, 0, 1, 2).
init_building_count(coal_mine, 0, 2, 1).
init_building_count(iron_mine, 0, 3, 1).
init_building_count(copper_mine, 0, 4, 1).
init_building_count(stone_mine, 0, 5, 1).

goal_building(iron_smelter, 1).
%goal_building(iron_gear_assembler, 1).
%goal_building(pipe_assembler, 1).

init_local_cap(I, Z, 5) :- item(I), zone(Z).