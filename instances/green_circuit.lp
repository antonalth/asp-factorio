#const horizon = 15.
#const num_zones = 2.
#const num_slots = 8.

init_global_stock(electricity, 500).
init_global_stock(coal, 500).
init_building_count(offshore_pump, 1, 1, 1).
init_building_count(power_plant_small, 1, 2, 2).
init_building_count(coal_mine, 1, 3, 1).
init_building_count(iron_mine, 1, 4, 1).
init_building_count(copper_mine, 1, 5, 1).
init_building_count(stone_mine, 1, 6, 1).

goal_item(green_circuit, 100).
goal_building(green_circuit_assembler, 1).

init_local_cap(I, Z, 50) :- item(I), zone(Z).
init_global_cap(I, Z, 10000) :- item(I), zone(Z).