item(wood).
item(coal).
item(stone).
item(stone_brick).
item(iron).
item(copper).
item(uranium).
item(iron_plate).
item(iron_gear).
item(pipe).
item(copper_plate).
item(steel_plate).
item(copper_cable).
item(green_circuit).
item(red_circuit).
item(blue_circuit).
item(solid_fuel).
item(plastic_bar).
item(sulfur).
item(battery).
item(explosive).
item(engine).
item(electric_engine).
item(robot_frame).
item(low_density_structure).
item(rocket_fuel).
item(uranium_235).
item(uranium_238).
item(concrete).
item(uranium_fuel_cell).
item(red_science).
item(green_science).
item(gray_science).
item(blue_science).
item(pink_science).
item(yellow_science).
item(space_science).

item(water).
item(crude_oil).
item(petroleum).
item(light_oil).
item(heavy_oil).
item(lubricant).
item(sulfuric_acid).
item(electricity). %abstraction

item(assembler).
item(boiler).
item(steam_engine).
item(stone_furnace).
item(steel_furnace).
item(burner_miner).
item(electric_miner).
item(pumpjack).
item(oil_refinery).
item(chemical_plant).
item(centrifuge).
item(nuclear_reactor).
item(heat_exchanger).
item(steam_turbine).

% handcrafting materials

crafting(wood).
dur(wood,1).
crafting_out(wood, wood, 120). 

crafting(coal).
dur(coal,1).
crafting_out(coal, coal, 60).

crafting(iron).
dur(iron,1).
crafting_out(iron, iron, 60).

crafting(copper).
dur(copper,1).
crafting_out(copper, copper, 60).

crafting(copper_cable).
dur(copper_cable,1).
crafting_cost(copper_cable, copper_plate, 30).
crafting_out(copper_cable, copper_cable, 60).

crafting(iron_gear).
dur(iron_gear,1).
crafting_cost(iron_gear, iron_plate, 60).
crafting_out(iron_gear, iron_gear, 30).

crafting(pipe).
dur(pipe,1).
crafting_cost(pipe, iron_plate, 60).
crafting_out(pipe, pipe, 60).

crafting(green_circuit).
dur(green_circuit,1).
crafting_cost(green_circuit, iron, 30).
crafting_cost(green_circuit, copper_cable, 90).
crafting_out(green_circuit,green_circuit,30).

%% handcrafting buildings

crafting(assembler).
dur(assembler,1).
crafting_cost(assembler, iron_plate, 100).
crafting_cost(assembler, iron_gear, 50 ).
crafting_cost(assembler, green_circuit, 30).
crafting_out(assembler, assembler, 10).

crafting(boiler).
dur(boiler, 1).
crafting_cost(boiler, pipe, 40).
crafting_cost(boiler, stone_furnace, 10).
crafting_out(boiler, boiler, 10).

crafting(steam_engine).
dur(steam_engine, 1).
crafting_cost(steam_engine, iron_plate, 100).
crafting_cost(steam_engine, iron_gear, 80).
crafting_cost(steam_engine, pipe, 50).
crafting_out(steam_engine,steam_engine, 10).

crafting(stone_furnace).
dur(stone_furnace,1).
crafting_cost(stone_furnace, stone, 60).
crafting_out(stone_furnace, stone_furnace, 12).

crafting(steel_furnace).
dur(steel_furnace,1).
crafting_cost(steel_furnace, steel_plate, 60).
crafting_cost(steel_furnace, stone_brick, 100).
crafting_out(steel_furnace, steel_furnace, 10).

crafting(burner_miner).
dur(burner_miner,1).
crafting_cost(burner_miner, iron_plate, 30).
crafting_cost(burner_miner, iron_gear, 30).
crafting_cost(burner_miner, stone_furnace, 10).
crafting_out(burner_miner, burner_miner, 10).

crafting(electric_miner).
dur(electric_miner,1).
crafting_cost(electric_miner, iron_plate, 100).
crafting_cost(electric_miner, iron_gear, 50).
crafting_cost(electric_miner, green_circuit, 30).
crafting_out(electric_miner, electric_miner, 10).

%crafting(offshore_pump). just build instead out of raw

crafting(pumpjack).
dur(pumpjack,1).
crafting_cost(pumpjack, steel_plate, 25).
crafting_cost(pumpjack, iron_gear, 50).
crafting_cost(pumpjack, green_circuit, 25).
crafting_cost(pumpjack, pipe, 50).
crafting_out(pumpjack,pumpjack,5).

crafting(oil_refinery).
dur(oil_refinery,1).
crafting_cost(oil_refinery, steel_plate, 45).
crafting_cost(oil_refinery, iron_gear, 30).
crafting_cost(oil_refinery, green_circuit, 30).
crafting_cost(oil_refinery, pipe, 30).
crafting_cost(oil_refinery, stone_brick, 30).
crafting_out(oil_refinery, oil_refinery, 3).

crafting(chemical_plant).
dur(chemical_plant,1).
crafting_cost(chemical_plant, steel_plate, 25).
crafting_cost(chemical_plant, iron_gear, 25).
crafting_cost(chemical_plant, green_circuit, 25).
crafting_cost(chemical_plant, pipe, 25).
crafting_out(chemical_plant, chemical_plant, 5).

crafting(centrifuge).
dur(centrifuge, 1).
crafting_cost(centrifuge, steel_plate, 250).
crafting_cost(centrifuge, iron_gear, 500).
crafting_cost(centrifuge, red_circuit, 500).
crafting_cost(centrifuge, concrete, 500).
crafting_out(centrifuge, centrifuge, 5).

crafting(nuclear_reactor).
dur(nuclear_reactor,1).
crafting_cost(nuclear_reactor, copper_plate, 500).
crafting_cost(nuclear_reactor, steel_plate, 500).
crafting_cost(nuclear_reactor, red_circuit, 500).
crafting_cost(nuclear_reactor, concrete, 500).
crafting_out(nuclear_reactor, nuclear_reactor, 1).

crafting(heat_exchanger).
dur(heat_exchanger, 1).
crafting_cost(heat_exchanger,copper_plate, 1000).
crafting_cost(heat_exchanger,steel_plate, 100).
crafting_cost(heat_exchanger,pipe,100).
crafting_out(heat_exchanger, heat_exchanger, 10).

crafting(steam_turbine).
dur(steam_turbine,1).
crafting_cost(steam_turbine,copper_plate, 500).
crafting_cost(steam_turbine,iron_gear, 500).
crafting_cost(steam_turbine,pipe,200).
crafting_out(steam_turbine, steam_turbine, 10).

building(offshore_pump).
dur(offshore_pump,1).
building_cost(offshore_pump, iron_gear, 2).
building_cost(offshore_pump, pipe, 3).
building_out(offshore_pump, water, 3600).

% Small Power Plant: two boilers, 4 steam engine
building(power_plant_small).
dur(power_plant_small, 1).
building_cost(power_plant_small, boiler, 2).
building_cost(power_plant_small, steam_engine, 4).
building_in(power_plant_small, water, 36).
building_in(power_plant_small, coal, 30).
building_out(power_plant_small, electricity, 360). % 3.6MW

building(nuclear_power_plant).
dur(nuclear_power_plant, 1).
building_cost(nuclear_power_plant, nuclear_reactor, 1).
building_cost(nuclear_power_plant, heat_exchanger, 8).
building_cost(nuclear_power_plant, steam_turbine, 16).
building_in(nuclear_power_plant, water, 247).
building_in(nuclear_power_plant, uranium_fuel_cell, 1).
building_out(nuclear_power_plant, electricity, 10000). % 100MW

building(coal_mine).
dur(coal_mine, 1).
building_cost(coal_mine, electric_miner, 10).
building_in(coal_mine, electricity, 90).
building_out(coal_mine, coal, 150).

building(coal_mine_burner).
dur(coal_mine_burner,1).
building_cost(coal_mine_burner, burner_miner, 5).
building_in(coal_mine_burner, coal, 7).
building_out(coal_mine_burner, coal, 38).

building(iron_mine).
dur(iron_mine, 1).
building_cost(iron_mine, electric_miner, 10).
building_in(iron_mine, electricity, 90).
building_out(iron_mine, iron, 150).

building(iron_mine_burner).
dur(iron_mine_burner,1).
building_cost(iron_mine_burner, burner_miner, 5).
building_in(iron_mine_burner, iron, 7).
building_out(iron_mine_burner, iron, 38).

building(copper_mine).
dur(copper_mine, 1).
building_cost(copper_mine, electric_miner, 10).
building_in(copper_mine, electricity, 90).
building_out(copper_mine, copper, 150).

building(copper_mine_burner).
dur(copper_mine_burner,1).
building_cost(copper_mine_burner, burner_miner, 5).
building_in(copper_mine_burner, copper, 7).
building_out(copper_mine_burner, copper, 38).

building(stone_mine).
dur(stone_mine, 1).
building_cost(stone_mine, electric_miner, 10).
building_in(stone_mine, electricity, 90).
building_out(stone_mine, stone, 150).

building(uranium_mine).
dur(uranium_mine, 1).
building_cost(uranium_mine, electric_miner, 10).
building_in(uranium_mine, sulfuric_acid, 8).
building_in(uranium_mine, electricity, 90).
building_out(uranium_mine, uranium, 75).

building(oil_mine).
dur(oil_mine, 1).
building_cost(oil_mine, pumpjack, 5).
building_in(oil_mine, electricity, 45).
building_out(oil_mine, crude_oil, 375).

building(iron_smelter).
dur(iron_smelter,1).
building_cost(iron_smelter, stone_furnace, 12).
building_in(iron_smelter, iron, 120).
building_in(iron_smelter, coal, 18).
building_out(iron_smelter, iron_plate, 120).

building(copper_smelter).
dur(copper_smelter,1).
building_cost(copper_smelter, stone_furnace, 12).
building_in(copper_smelter, copper, 120).
building_in(copper_smelter, coal, 18).
building_out(copper_smelter, copper_plate, 120).

building(steel_smelter).
dur(steel_smelter,1).
building_cost(steel_smelter, stone_furnace, 12).
building_in(steel_smelter, iron, 120).
building_in(steel_smelter, coal, 18).
building_out(steel_smelter, steel_plate, 24).

building(stone_smelter).
dur(stone_smelter,1).
building_cost(stone_smelter, stone_furnace, 12).
building_in(stone_smelter, stone, 240).
building_in(stone_smelter, coal, 18).
building_out(stone_smelter, stone_brick, 120).

%%upgraded versions
building(iron_smelter_v2).
dur(iron_smelter_v2,1).
building_cost(iron_smelter_v2, steel_furnace, 10).
building_in(iron_smelter_v2, iron, 200).
building_in(iron_smelter_v2, coal, 15).
building_out(iron_smelter_v2, iron_plate, 200).

building(copper_smelter_v2).
dur(copper_smelter_v2,1).
building_cost(copper_smelter_v2, steel_furnace, 10).
building_in(copper_smelter_v2, copper, 200).
building_in(copper_smelter_v2, coal, 15).
building_out(copper_smelter_v2, copper_plate, 200).

building(steel_smelter_v2).
dur(steel_smelter_v2,1).
building_cost(steel_smelter_v2, steel_furnace, 10).
building_in(steel_smelter_v2, iron, 200).
building_in(steel_smelter_v2, coal, 15).
building_out(steel_smelter_v2, steel_plate, 40).

building(stone_smelter_v2).
dur(stone_smelter_v2,1).
building_cost(stone_smelter_v2, steel_furnace, 10).
building_in(stone_smelter_v2, stone, 400).
building_in(stone_smelter_v2, coal, 15).
building_out(stone_smelter_v2, stone_brick, 200).

building(pipe_assembler).
dur(pipe_assembler,1).
building_cost(pipe_assembler, assembler, 5).
building_in(pipe_assembler, iron_plate, 100).
building_in(pipe_assembler, electricity, 78).
building_out(pipe_assembler, pipe, 100).

building(iron_gear_assembler).
dur(iron_gear_assembler,1).
building_cost(iron_gear_assembler, assembler, 5).
building_in(iron_gear_assembler, iron_plate, 200).
building_in(iron_gear_assembler, electricity, 78).
building_out(iron_gear_assembler, iron_gear, 100).

building(copper_cable_assembler).
dur(copper_cable_assembler, 1).
building_cost(copper_cable_assembler, assembler, 5).
building_in(copper_cable_assembler, copper_plate, 100).
building_in(copper_cable_assembler, electricity, 78).
building_out(copper_cable_assembler, copper_cable, 200).

building(green_circuit_assembler).
dur(green_circuit_assembler, 1).
building_cost(green_circuit_assembler, assembler, 5).
building_in(green_circuit_assembler, iron_plate, 100).
building_in(green_circuit_assembler, copper_cable, 300).
building_in(green_circuit_assembler, electricity, 78).
building_out(green_circuit_assembler, green_circuit, 100).

building(red_circuit_assembler).
dur(red_circuit_assembler, 1).
building_cost(red_circuit_assembler, assembler, 5).
building_in(red_circuit_assembler, plastic_bar, 40).
building_in(red_circuit_assembler, copper_cable, 80).
building_in(red_circuit_assembler, green_circuit, 40).
building_in(red_circuit_assembler, electricity, 78).
building_out(red_circuit_assembler, red_circuit, 20).

building(blue_circuit_assembler).
dur(blue_circuit_assembler,1).
building_cost(blue_circuit_assembler, assembler, 5).
building_in(blue_circuit_assembler, green_circuit, 240).
building_in(blue_circuit_assembler, red_circuit, 24).
building_in(blue_circuit_assembler, sulfuric_acid, 6).
building_in(blue_circuit_assembler, electricity, 78).
building_out(blue_circuit_assembler, blue_circuit, 12).

building(engine_assembler).
dur(engine_assembler, 1).
building_cost(engine_assembler, assembler, 5).
building_in(engine_assembler, steel_plate, 12).
building_in(engine_assembler, iron_gear, 12).
building_in(engine_assembler, pipe, 24).
building_in(engine_assembler, electricity, 78).
building_out(engine_assembler, engine, 12).

building(electric_engine_assembler).
dur(electric_engine_assembler,1).
building_cost(electric_engine_assembler, assembler, 5).
building_in(electric_engine_assembler, green_circuit, 24).
building_in(electric_engine_assembler, engine, 12).
building_in(electric_engine_assembler, lubricant, 18).
building_in(electric_engine_assembler, electricity, 78).
building_out(electric_engine_assembler, electric_engine, 12).

building(robot_frame_assembler).
dur(robot_frame_assembler,1).
building_cost(robot_frame_assembler, assembler, 5).
building_in(robot_frame_assembler, steel_plate, 6).
building_in(robot_frame_assembler, battery, 12).
building_in(robot_frame_assembler, green_circuit, 18).
building_in(robot_frame_assembler, electric_engine, 6).
building_in(robot_frame_assembler, electricity, 78).
building_out(robot_frame_assembler, robot_frame, 6).

building(low_density_structure_assembler).
dur(low_density_structure_assembler,1).
building_cost(low_density_structure_assembler, assembler, 5).
building_in(low_density_structure_assembler, copper_plate, 160).
building_in(low_density_structure_assembler, steel_plate, 16).
building_in(low_density_structure_assembler, plastic_bar, 40).
building_in(low_density_structure_assembler, electricity, 78).
building_out(low_density_structure_assembler, low_density_structure, 8).

building(concrete_assembler).
dur(concrete_assembler, 1).
building_cost(concrete_assembler, assembler, 5).
building_in(concrete_assembler, iron, 15).
building_in(concrete_assembler, stone_brick, 75).
building_in(concrete_assembler, water, 150).
building_out(concrete_assembler, concrete, 150).

%building(rocket_fuel_assembler).
%building(concrete_assembler).
%building(solid_fuel_chemical_plant).
building(sulfur_chemical_plant).
dur(sulfur_chemical_plant, 1).
building_cost(sulfur_chemical_plant, chemical_plant, 5).
building_in(sulfur_chemical_plant, water, 450).
building_in(sulfur_chemical_plant, petroleum, 450).
building_in(sulfur_chemical_plant, electricity, 109).
building_out(sulfur_chemical_plant, sulfur, 300).

building(plastic_bar_chemical_plant).
dur(plastic_bar_chemical_plant,1).
building_cost(plastic_bar_chemical_plant, chemical_plant, 5).
building_in(plastic_bar_chemical_plant, coal, 150).
building_in(plastic_bar_chemical_plant, petroleum, 300).
building_in(plastic_bar_chemical_plant, electricity, 109).
building_out(plastic_bar_chemical_plant, plastic_bar, 200).

building(battery_chemical_plant).
dur(battery_chemical_plant,1).
building_cost(battery_chemical_plant, chemical_plant, 5).
building_in(battery_chemical_plant, iron_plate, 35).
building_in(battery_chemical_plant, copper_plate, 35).
building_in(battery_chemical_plant, sulfuric_acid, 70).
building_in(battery_chemical_plant, electricity, 109).
building_out(battery_chemical_plant, battery, 7).

building(explosive_chemical_plant).
dur(explosive_chemical_plant,1).
building_cost(explosive_chemical_plant, chemical_plant, 5).
building_in(explosive_chemical_plant, coal, 35).
building_in(explosive_chemical_plant, sulfur, 35).
building_in(explosive_chemical_plant, water, 35).
building_in(explosive_chemical_plant, electricity, 109).
building_out(explosive_chemical_plant, explosive, 7).

building(heavy_to_light_cracking_chemical_plant).
dur(heavy_to_light_cracking_chemical_plant, 1).
building_cost(heavy_to_light_cracking_chemical_plant, chemical_plant, 5).
building_in(heavy_to_light_cracking_chemical_plant, water, 225).
building_in(heavy_to_light_cracking_chemical_plant, heavy_oil, 300).
building_in(heavy_to_light_cracking_chemical_plant, electricity, 109).
building_out(heavy_to_light_cracking_chemical_plant, light_oil, 225).

building(light_to_petroleum_cracking_chemical_plant).
dur(light_to_petroleum_cracking_chemical_plant, 1).
building_cost(light_to_petroleum_cracking_chemical_plant, chemical_plant, 5).
building_in(light_to_petroleum_cracking_chemical_plant, water, 225).
building_in(light_to_petroleum_cracking_chemical_plant, light_oil, 225).
building_in(light_to_petroleum_cracking_chemical_plant, electricity, 109).
building_out(light_to_petroleum_cracking_chemical_plant, petroleum, 150).

building(lubricant_chemical_plant).
dur(lubricant_chemical_plant, 1).
building_cost(lubricant_chemical_plant, chemical_plant, 5).
building_in(lubricant_chemical_plant, heavy_oil, 150).
building_in(lubricant_chemical_plant, electricity, 109).
building_out(lubricant_chemical_plant, lubricant, 150).

building(sulfuric_acid_chemical_plant).
dur(sulfuric_acid_chemical_plant, 1).
building_cost(sulfuric_acid_chemical_plant, chemical_plant, 5).
building_in(sulfuric_acid_chemical_plant, iron_plate, 150).
building_in(sulfuric_acid_chemical_plant, sulfur, 750).
building_in(sulfuric_acid_chemical_plant, electricity, 109).
building_in(sulfuric_acid_chemical_plant, water, 1500).
building_out(sulfuric_acid_chemical_plant, sulfuric_acid, 750).

building(advanced_oil_processing_oil_refinery).
dur(advanced_oil_processing_oil_refinery, 1).
building_cost(advanced_oil_processing_oil_refinery, oil_refinery, 5).
building_in(advanced_oil_processing_oil_refinery, water, 150).
building_in(advanced_oil_processing_oil_refinery, crude_oil, 300).
building_in(advanced_oil_processing_oil_refinery, electricity, 217).
building_out(advanced_oil_processing_oil_refinery, heavy_oil, 75).
building_out(advanced_oil_processing_oil_refinery, light_oil, 135).
building_out(advanced_oil_processing_oil_refinery, petroleum, 165).

building(uranium_processing_centrifuge).
dur(uranium_processing_centrifuge, 1).
building_cost(uranium_processing_centrifuge, centrifuge, 20).
building_in(uranium_processing_centrifuge, uranium, 460).
building_in(uranium_processing_centrifuge, electricity, 724).
building_out(uranium_processing_centrifuge, uranium_238, 45).
building_out(uranium_processing_centrifuge, uranium_235, 1).

%simplified the math to fit abstraction
building(kovarex_enrichment_centrifuge).
dur(kovarex_enrichment_centrifuge,1).
building_cost(kovarex_enrichment_centrifuge, centrifuge, 8).
building_in(kovarex_enrichment_centrifuge, uranium_235, 40).
building_in(kovarex_enrichment_centrifuge, uranium_238, 12).
building_in(kovarex_enrichment_centrifuge, electricity, 290).
building_out(kovarex_enrichment_centrifuge, uranium_235, 44).

building(uranium_fuel_cell_assembler).
dur(uranium_fuel_cell_assembler, 1).
building_cost(uranium_fuel_cell_assembler, assembler, 1).
building_in(uranium_fuel_cell_assembler, iron_plate, 30).
building_in(uranium_fuel_cell_assembler, uranium_235, 3).
building_in(uranium_fuel_cell_assembler, uranium_238, 57).
building_in(uranium_fuel_cell_assembler, electricity, 16).
building_out(uranium_fuel_cell_assembler, uranium_fuel_cell, 30).

%init_local_cap(copper_cable, Z, 500) :- zone(Z).
%init_global_cap(copper_cable, 500).
