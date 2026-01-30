% instance must define horizon, num_zones, num_slots
#const max_val = 10000. 

time(0..horizon).
step(0..horizon-1).
zone(1..num_zones).
slot(1..num_slots).

next_slot(S, S+1) :- slot(S).
next_zone(Z, Z+1) :- zone(Z), zone(Z+1).

available_index(1..num_slots+1).

% assign max 1 building to slot
0 { slot_map(Z, S, B) : building(B) } 1 :- zone(Z), slot(S).
:- slot_map(Z, S1, B), slot_map(Z, S2, B), S1 != S2. % max 1 slot per building/zone

% force used slots to left (right unused)
has_assignment(Z, S) :- slot_map(Z, S, _). 
:- has_assignment(Z, S+1), not has_assignment(Z, S), slot(S).

% Helper for build actions
can_build(B, Z) :- building(B), zone(Z), slot_map(Z, _, B).

&dom{0..max_val} = stock(I,Z,T) :- item(I), zone(Z), time(T).
&dom{0..max_val} = global_stock(I,T) :- item(I), time(T).
&dom{0..max_val} = buildingcount(B, Z, T) :- building(B), zone(Z), time(T), slot_map(Z, _, B).

% max 1 build, 1 craft / step
0{ act(craft(I), STEP) : item(I), dur(I, _)}1 :- step(STEP), not busy(craft, STEP). 
0{ act(build(B, Z), STEP) : building(B), zone(Z), dur(B, _), can_build(B, Z)}1 :- step(STEP), not busy(build,STEP).

% we cannot start another action if we are not yet done with the current.
busy(craft, STEP) :- step(STEP), act(craft(I), STEPSTART), dur(I, DUR), STEP > STEPSTART, STEP < STEPSTART + DUR.
busy(build, STEP) :- step(STEP), act(build(B,Z), STEPSTART), dur(B, DUR), STEP > STEPSTART, STEP < STEPSTART + DUR.

uses_build_resource(I, T) :- act(build(B, _), T), build_cost(B, I, _).
uses_craft_resource(I, T) :- act(craft(Product), T), craft_cost(Product, I, _).

% cost of building/crafting
&dom{0..max_val} = cost_build(I, T) :- item(I), step(T).
&dom{0..max_val} = cost_craft(I, T) :- item(I), step(T).
&sum { cost_build(I, T) } = Qty :- step(T), item(I), act(build(B, _), T), build_cost(B, I, Qty).
&sum { cost_build(I, T) } = 0 :- step(T), item(I), not uses_build_resource(I, T).
&sum { cost_craft(I, T) } = Qty :- step(T), item(I), act(craft(Product), T), craft_cost(Product, I, Qty).
&sum { cost_craft(I, T) } = 0 :- step(T), item(I), not uses_craft_resource(I, T).

% finish action if we started action DUR steps ago
finish(craft(I), TIME) :- time(TIME), act(craft(I), TIMESTART), dur(I, DUR), TIME = TIMESTART + DUR.
finish(build(B, Z), TIME) :- time(TIME), act(build(B, Z), TIMESTART), dur(B, DUR), TIME = TIMESTART + DUR.
finish_any_craft_for(I, T) :- finish(craft(Product), T), craft_out(Product, I, _).

% add one to buildingcount if build action finishes
&sum { buildingcount(B, Z, T+1); -buildingcount(B, Z, T)} = 1 :- building(B), zone(Z), step(T), slot_map(Z, _, B), finish(build(B, Z), T).
&sum { buildingcount(B, Z, T+1); -buildingcount(B, Z, T)} = 0 :- building(B), zone(Z), step(T), slot_map(Z, _, B), not finish(build(B, Z), T).

% items we gain at step T if craft completes
&dom{0..max_val} = yield_craft(I, T) :- item(I), step(T).
&sum { yield_craft(I, T) } = Qty :- time(T), item(I), finish(craft(P), T), craft_out(P, I, Qty). 
&sum { yield_craft(I, T) } = 0 :- time(T), item(I), not finish_any_craft_for(I, T).

% vars of how much of each item are available from local stock & avail from global stock via import.
&dom{0..max_val} = local_available(I, Z, IDX, T)  :- item(I), zone(Z), available_index(IDX), step(T).
&dom{0..max_val} = global_available(I, Z, IDX, T) :- item(I), zone(Z), available_index(IDX), step(T).

% space for output is also something we need to model for the scenario that the output logistic channels are full (common scenario)
&dom{0..max_val} = local_space(I, Z, IDX, T)  :- item(I), zone(Z), available_index(IDX), step(T).
&dom{0..max_val} = global_space(I, Z, IDX, T) :- item(I), zone(Z), available_index(IDX), step(T).

% actual utilization a factory with a set capacity (amount of built) runs, constrained by available resources
&dom{0..max_val} = slot_utilization(Z, S, T) :- zone(Z), slot(S), step(T).

% bulding util <= capacity (0 if not assigned to building type)
&sum { slot_utilization(Z, S, T); -buildingcount(B, Z, T) } <= 0 :- slot_map(Z, S, B), step(T).
&sum { slot_utilization(Z, S, T) } = 0 :- zone(Z), slot(S), step(T), not has_assignment(Z, S).

% in each zone, first slot has all of stock available as resource
&sum { local_available(I, Z, 1, T); -stock(I, Z, T) } = 0 :- item(I), zone(Z), step(T).

% if stock has cap limit, then available space for outputs = cap - stock
% Equation: local_space = maximum_local_capacity - local_stock
&sum { local_space(I, Z, 1, T); stock(I, Z, T) } = Cap :- item(I), zone(Z), step(T), stock_cap(I, Z, Cap).
&sum { local_space(I, Z, 1, T) } = max_val :- item(I), zone(Z), step(T), not stock_cap(I, Z, _).

% first zone, first slot in first zone has available = stock - (buildcost + craftcost) (both based on actions, taken from global stock)
% since dom of global_avail >= 0, this enforces build+craftcosts <= global_stock
% Equation: global_available = global_stock - cost_build - cost_craft
&sum { global_available(I, 1, 1, T); -global_stock(I, T); cost_build(I, T); cost_craft(I, T) } = 0 :- item(I), step(T).

% global_space calculation same as with local_space
&sum { global_space(I, 1, 1, T); global_stock(I, T) } = Cap :- item(I), step(T), global_cap(I, Cap).
&sum { global_space(I, 1, 1, T) } = max_val :- item(I), step(T), not global_cap(I, _).

% connect available from global stock/space from zoneX last slot -> zoneX+1 first slot
&sum { global_available(I, Znext, 1, T); -global_available(I, Z, num_slots+1, T) } = 0 :- 
    item(I), next_zone(Z, Znext), step(T). 
&sum { global_space(I, Znext, 1, T); -global_space(I, Z, num_slots+1, T) } = 0 :- 
    item(I), next_zone(Z, Znext), step(T).

% inputs/output vars for each item for each slot for each step for both local/global
&dom{0..max_val} = input_from_local(I, Z, S, T)  :- item(I), zone(Z), slot(S), step(T).
&dom{0..max_val} = input_from_global(I, Z, S, T) :- item(I), zone(Z), slot(S), step(T).
&dom{0..max_val} = output_to_local(I, Z, S, T) :- item(I), zone(Z), slot(S), step(T).
&dom{0..max_val} = output_to_global(I, Z, S, T) :- item(I), zone(Z), slot(S), step(T).

% if slot is empty, we consume/produce nothing
&sum { input_from_local(I, Z, S, T) } = 0  :- item(I), zone(Z), slot(S), step(T), not has_assignment(Z, S).
&sum { input_from_global(I, Z, S, T) } = 0 :- item(I), zone(Z), slot(S), step(T), not has_assignment(Z, S).
&sum { output_to_local(I, Z, S, T) } = 0 :- item(I), zone(Z), slot(S), step(T), not has_assignment(Z, S).
&sum { output_to_global(I, Z, S, T) } = 0 :- item(I), zone(Z), slot(S), step(T), not has_assignment(Z, S).

% slot is not empty, but the building type in slot does not consume or produce respective items
&sum { input_from_local(I, Z, S, T) } = 0  :- slot_map(Z, S, B), not building_in(B, I, _), step(T), item(I).
&sum { input_from_global(I, Z, S, T) } = 0 :- slot_map(Z, S, B), not building_in(B, I, _), step(T), item(I).
&sum { output_to_local(I, Z, S, T) } = 0 :- slot_map(Z, S, B), not building_out(B, I, _), step(T), item(I).
&sum { output_to_global(I, Z, S, T) } = 0 :- slot_map(Z, S, B), not building_out(B, I, _), step(T), item(I).

% Amount taken/input from local + global is exactly the amount required by the recipe * utilzation amount
% Equation: input_local + input_global = building_input_amnt * building_utilization
&sum { input_from_local(I, Z, S, T); input_from_global(I, Z, S, T); -Qty*slot_utilization(Z, S, T) } = 0 :- slot_map(Z, S, B), building_in(B, I, Qty), step(T).

% We can only consume what we actually have at the point we are at down the chain of zones/slots
% Equation: input_local + input_global <= available for consumption at zone Z, slot S, at step T
&sum { input_from_local(I, Z, S, T); -local_available(I, Z, S, T) } <= 0 :- item(I), zone(Z), slot(S), step(T).
&sum { input_from_global(I, Z, S, T); -global_available(I, Z, S, T) } <= 0 :- item(I), zone(Z), slot(S), step(T).

% Same as inputs, but for outputs
% Equation: output of resource to local + output to global = output Qty of recipe * utilization
&sum { output_to_local(I, Z, S, T); output_to_global(I, Z, S, T); -Qty*slot_utilization(Z, S, T) } = 0 :-
    slot_map(Z, S, B), building_out(B, I, Qty), step(T).

% We can only produce as much as we have space available at our point in the chain
% Equation: Output produced <= space available
&sum { output_to_local(I, Z, S, T); -local_space(I, Z, S, T) } <= 0 :- item(I), zone(Z), slot(S), step(T).
&sum { output_to_global(I, Z, S, T); -global_space(I, Z, S, T) } <= 0 :- item(I), zone(Z), slot(S), step(T).


% Remove consumed local resouces from the amount available for next step in chain
% Equation: local available at slot+1 = local_available at slot - consumed
&sum { local_available(I, Z, S+1, T); -local_available(I, Z, S, T); input_from_local(I, Z, S, T) } = 0 :-
    item(I), zone(Z), next_slot(S, _), step(T).

% same for global from slot -> slot+1
&sum { global_available(I, Z, S+1, T); -global_available(I, Z, S, T); input_from_global(I, Z, S, T) } = 0 :-
    item(I), zone(Z), next_slot(S, _), step(T).

% same as local/global available
&sum { local_space(I, Z, S+1, T); -local_space(I, Z, S, T); output_to_local(I, Z, S, T) } = 0 :-
    item(I), zone(Z), next_slot(S, _), step(T).

% same as local space
&sum { global_space(I, Z, S+1, T); -global_space(I, Z, S, T); output_to_global(I, Z, S, T) } = 0 :-
    item(I), zone(Z), next_slot(S, _), step(T).

% NOTE: connection from zoneX -> zoneX+1 for global stock happened above

% For T->T+1, local stock is what we had left in last slot in previous timestep + what we produced into local stock at prev
&sum { stock(I, Z, T+1); 
       -local_available(I, Z, num_slots+1, T); 
       -output_to_local(I, Z, S, T) : slot(S)
} = 0 :- item(I), zone(Z), step(T).

% global stock T->T+1 same as local stock update, but we also add the items we gained by finishing craft (consumed by crafting included in global_available above)
&sum { 
    global_stock(I, T+1);
    -global_available(I, num_zones, num_slots+1, T); 
    -output_to_global(I, Z, S, T) : zone(Z), slot(S);
    -yield_craft(I, T+1)
} = 0 :- item(I), step(T).

% want factories to run as much as possible, consume local resources first
&maximize {
    100*slot_utilization(Z, S, T) : zone(Z), slot(S), step(T); %want increase
    -1 * input_from_global(I, Z, S, T) : item(I), zone(Z), slot(S), step(T) %want decrease
}.