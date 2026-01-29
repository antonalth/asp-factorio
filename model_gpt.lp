%#const horizon = 20. 
%#const num_zones = 3.
%#const num_slots = 15.
%#const max_val = 1000. 

time(0..horizon).
step(0..horizon-1).
zone(1..num_zones).
slot(1..num_slots).

% We need indices 1..16 because the flow leaves slot 15 and lands in "16" (the output buffer)
flow_index(1..num_slots+1).

% Building Assignments
0{slot_map(Z, S, B) : building(B)}1 :- zone(Z), slot(S). 
:- slot_map(Z, S1, B), slot_map(Z, S2, B), S1 != S2. 

% Force slots to the left (Symmetry Breaking)
has_assignment(Z, S) :- slot_map(Z, S, _).
:- has_assignment(Z, S+1), not has_assignment(Z, S), slot(S).

can_build(B, Z) :- building(B), zone(Z), slot_map(Z, _, B).

% Stock and Building Counts
% Note: Initialization of stock at Time 0 is required (assuming provided in separate setup file)
&dom{0..max_val} = stock(I,Z,T) :- item(I), zone(Z), time(T).
&dom{0..max_val} = globalstock(I,T) :- item(I), time(T).
&dom{0..max_val} = buildingcount(B, Z, T) :- building(B), zone(Z), time(T), slot_map(Z, _, B).

% --- ACTION LOGIC ---
busy(craft, STEP) :- step(STEP), act(craft(I), STEPSTART), dur(I, DUR), STEP > STEPSTART, STEP < STEPSTART + DUR.
busy(build, STEP) :- step(STEP), act(build(B,Z), STEPSTART), dur(B, DUR), STEP > STEPSTART, STEP < STEPSTART + DUR.

0{ act(craft(I), STEP) : item(I), dur(I, _)}1 :- step(STEP), not busy(craft, STEP). 
0{ act(build(B, Z), STEP) : building(B), zone(Z), dur(B, _), can_build(B, Z)}1 :- step(STEP), not busy(build,STEP).

finish(craft(I), TIME) :- time(TIME), act(craft(I), TIMESTART), dur(I, DUR), TIME = TIMESTART + DUR.
finish(build(B, Z), TIME) :- time(TIME), act(build(B, Z), TIMESTART), dur(B, DUR), TIME = TIMESTART + DUR.

&sum { buildingcount(B, Z, T+1); -buildingcount(B, Z, T)} = 1 :- building(B), zone(Z), step(T), slot_map(Z, _, B), finish(build(B, Z), T).
&sum { buildingcount(B, Z, T+1); -buildingcount(B, Z, T)} = 0 :- building(B), zone(Z), step(T), slot_map(Z, _, B), not finish(build(B, Z), T).

next_slot(S, S+1) :- slot(S).
next_zone(Z, Z+1) :- zone(Z), zone(Z+1).
next_step(T, T+1) :- step(T), step(T+1).
last_step(T) :- step(T), T = horizon-1.

% Total order for items (for accumulation)
item_index(I, N) :- item(I), N = #count { I2 : item(I2), I2 <= I }.
item_count(N) :- N = #count { I : item(I) }.
item_pos(1..N) :- item_count(N).
item_at(N, I) :- item_index(I, N).
next_item(N, N+1) :- item_pos(N), item_pos(N+1).

% 2. Flow Variables (Using flow_index instead of slot)
&dom{0..max_val} = local_flow(I, Z, IDX, T)  :- item(I), zone(Z), flow_index(IDX), step(T).
&dom{0..max_val} = global_flow(I, Z, IDX, T) :- item(I), zone(Z), flow_index(IDX), step(T).
&dom{0..max_val} = local_space(I, Z, IDX, T)  :- item(I), zone(Z), flow_index(IDX), step(T).
&dom{0..max_val} = global_space(I, Z, IDX, T) :- item(I), zone(Z), flow_index(IDX), step(T).

% 3. Run Variable (defined for all slots; forced to 0 when not applicable)
&dom{0..max_val} = run_slot(Z, S, T) :- zone(Z), slot(S), step(T).
&sum { run_slot(Z, S, T) } = 0 :- zone(Z), slot(S), step(T), not has_assignment(Z, S).

% Constraint: Cannot run more than existing buildings
&sum { run_slot(Z, S, T); -buildingcount(B, Z, T) } <= 0 :- slot_map(Z, S, B), step(T).

% 4. INITIALIZATION (The Head of the Streams)

% A. Local Start: Slot 1 gets Stock
&sum { local_flow(I, Z, 1, T); -stock(I, Z, T) } = 0 :- item(I), zone(Z), step(T).
% Space Calculation: Capacity - Current Stock
&sum { local_space(I, Z, 1, T); stock(I, Z, T) } = Cap :- item(I), zone(Z), step(T), stock_cap(I, Z, Cap).
% Fallback if no cap defined (Infinite space logic):
&sum { local_space(I, Z, 1, T) } = max_val :- item(I), zone(Z), step(T), not stock_cap(I, Z, _).

% B. Global Start: Zone 1 Slot 1 gets Global Stock
&sum { global_flow(I, 1, 1, T); -globalstock(I, T) } = 0 :- item(I), step(T).
&sum { global_space(I, 1, 1, T); globalstock(I, T) } = Cap :- item(I), step(T), global_cap(I, Cap).
&sum { global_space(I, 1, 1, T) } = max_val :- item(I), step(T), not global_cap(I, _).

% C. Global Chain: Zone Z+1 Start gets Zone Z End (Slot 16)
&sum { global_flow(I, Znext, 1, T); -global_flow(I, Z, num_slots+1, T) } = 0 :- 
    item(I), next_zone(Z, Znext), step(T). 
&sum { global_space(I, Znext, 1, T); -global_space(I, Z, num_slots+1, T) } = 0 :- 
    item(I), next_zone(Z, Znext), step(T).


% 5. SLOT CONSUMPTION (Only defined if has_assignment)

% Decision variables (defined for all slots; forced to 0 when not applicable)
&dom{0..max_val} = use_local(I, Z, S, T) :- item(I), zone(Z), slot(S), step(T).
&dom{0..max_val} = use_global(I, Z, S, T) :- item(I), zone(Z), slot(S), step(T).

&sum { use_local(I, Z, S, T) } = 0 :- item(I), zone(Z), slot(S), step(T), not has_assignment(Z, S).
&sum { use_global(I, Z, S, T) } = 0 :- item(I), zone(Z), slot(S), step(T), not has_assignment(Z, S).

&sum { use_local(I, Z, S, T) } = 0 :-
    item(I), zone(Z), slot(S), step(T), slot_map(Z, S, B), not building_in(B, I, _).
&sum { use_global(I, Z, S, T) } = 0 :-
    item(I), zone(Z), slot(S), step(T), slot_map(Z, S, B), not building_in(B, I, _).

% Inputs
&sum { use_local(I, Z, S, T); use_global(I, Z, S, T); -Qty*run_slot(Z, S, T) } = 0 :-
    slot_map(Z, S, B), building_in(B, I, Qty), step(T).

% Availability (Must satisfy flow)
&sum { use_local(I, Z, S, T); -local_flow(I, Z, S, T) } <= 0 :- slot_map(Z, S, B), building_in(B,I,_), step(T).
&sum { use_global(I, Z, S, T); -global_flow(I, Z, S, T) } <= 0 :- slot_map(Z, S, B), building_in(B,I,_), step(T).

% Outputs (defined for all slots; forced to 0 when not applicable)
&dom{0..max_val} = fill_local(I, Z, S, T) :- item(I), zone(Z), slot(S), step(T).
&dom{0..max_val} = fill_global(I, Z, S, T) :- item(I), zone(Z), slot(S), step(T).

&sum { fill_local(I, Z, S, T) } = 0 :- item(I), zone(Z), slot(S), step(T), not has_assignment(Z, S).
&sum { fill_global(I, Z, S, T) } = 0 :- item(I), zone(Z), slot(S), step(T), not has_assignment(Z, S).

&sum { fill_local(I, Z, S, T) } = 0 :-
    item(I), zone(Z), slot(S), step(T), slot_map(Z, S, B), not building_out(B, I, _).
&sum { fill_global(I, Z, S, T) } = 0 :-
    item(I), zone(Z), slot(S), step(T), slot_map(Z, S, B), not building_out(B, I, _).

&sum { fill_local(I, Z, S, T); fill_global(I, Z, S, T); -Qty*run_slot(Z, S, T) } = 0 :-
    slot_map(Z, S, B), building_out(B, I, Qty), step(T).

&sum { fill_local(I, Z, S, T); -local_space(I, Z, S, T) } <= 0 :- slot_map(Z, S, B), building_out(B,I,_), step(T).
&sum { fill_global(I, Z, S, T); -global_space(I, Z, S, T) } <= 0 :- slot_map(Z, S, B), building_out(B,I,_), step(T).


% 6. FLOW UPDATES (Mutually Exclusive Logic)

% CASE A: Slot IS Assigned -> Subtract Usage / Add Production
&sum { local_flow(I, Z, S+1, T); -local_flow(I, Z, S, T); use_local(I, Z, S, T) } = 0 :-
    slot_map(Z, S, B), building_in(B, I, _), step(T).
&sum { local_flow(I, Z, S+1, T); -local_flow(I, Z, S, T) } = 0 :-
    slot_map(Z, S, B), not building_in(B, I, _), item(I), step(T). % Pass through if ingredient not used

&sum { global_flow(I, Z, S+1, T); -global_flow(I, Z, S, T); use_global(I, Z, S, T) } = 0 :-
    slot_map(Z, S, B), building_in(B, I, _), step(T).
&sum { global_flow(I, Z, S+1, T); -global_flow(I, Z, S, T) } = 0 :-
    slot_map(Z, S, B), not building_in(B, I, _), item(I), step(T).

% Space Update
&sum { local_space(I, Z, S+1, T); -local_space(I, Z, S, T); fill_local(I, Z, S, T) } = 0 :-
    slot_map(Z, S, B), building_out(B, I, _), step(T).
&sum { local_space(I, Z, S+1, T); -local_space(I, Z, S, T) } = 0 :-
    slot_map(Z, S, B), not building_out(B, I, _), item(I), step(T).

&sum { global_space(I, Z, S+1, T); -global_space(I, Z, S, T); fill_global(I, Z, S, T) } = 0 :-
    slot_map(Z, S, B), building_out(B, I, _), step(T).
&sum { global_space(I, Z, S+1, T); -global_space(I, Z, S, T) } = 0 :-
    slot_map(Z, S, B), not building_out(B, I, _), item(I), step(T).


% CASE B: Slot is EMPTY -> Pure Pass-through
&sum { local_flow(I, Z, S+1, T); -local_flow(I, Z, S, T) } = 0 :- 
    item(I), zone(Z), step(T), next_slot(S, _), not has_assignment(Z, S).

&sum { global_flow(I, Z, S+1, T); -global_flow(I, Z, S, T) } = 0 :- 
    item(I), zone(Z), step(T), next_slot(S, _), not has_assignment(Z, S).

&sum { local_space(I, Z, S+1, T); -local_space(I, Z, S, T) } = 0 :- 
    item(I), zone(Z), step(T), next_slot(S, _), not has_assignment(Z, S).

&sum { global_space(I, Z, S+1, T); -global_space(I, Z, S, T) } = 0 :- 
    item(I), zone(Z), step(T), next_slot(S, _), not has_assignment(Z, S).


% 7. TIME UPDATE

% Accumulate fill_local across slots (zone-local)
&dom{0..max_val} = fill_local_acc(I, Z, S, T) :- item(I), zone(Z), slot(S), step(T).
&sum { fill_local_acc(I, Z, 1, T); -fill_local(I, Z, 1, T) } = 0 :- item(I), zone(Z), step(T).
&sum { fill_local_acc(I, Z, Snext, T); -fill_local_acc(I, Z, S, T); -fill_local(I, Z, Snext, T) } = 0 :-
    item(I), zone(Z), step(T), next_slot(S, Snext), slot(Snext).

% Accumulate fill_global across slots, then across zones
&dom{0..max_val} = fill_global_acc_slot(I, Z, S, T) :- item(I), zone(Z), slot(S), step(T).
&sum { fill_global_acc_slot(I, Z, 1, T); -fill_global(I, Z, 1, T) } = 0 :- item(I), zone(Z), step(T).
&sum { fill_global_acc_slot(I, Z, Snext, T); -fill_global_acc_slot(I, Z, S, T); -fill_global(I, Z, Snext, T) } = 0 :-
    item(I), zone(Z), step(T), next_slot(S, Snext), slot(Snext).

&dom{0..max_val} = fill_global_acc_zone(I, Z, T) :- item(I), zone(Z), step(T).
&sum { fill_global_acc_zone(I, 1, T); -fill_global_acc_slot(I, 1, num_slots, T) } = 0 :- item(I), step(T).
&sum { fill_global_acc_zone(I, Znext, T); -fill_global_acc_zone(I, Z, T); -fill_global_acc_slot(I, Znext, num_slots, T) } = 0 :-
    item(I), next_zone(Z, Znext), step(T).

% Local Stock T+1 = Flow Leaving Slot 15 + All Production added to Local
&sum { stock(I, Z, T+1);
       -local_flow(I, Z, num_slots+1, T);
       -fill_local_acc(I, Z, num_slots, T)
} = 0 :- item(I), zone(Z), step(T).

% Global Stock T+1 = Flow Leaving LAST Zone + All Exports
&sum { globalstock(I, T+1);
       -global_flow(I, num_zones, num_slots+1, T);
       -fill_global_acc_zone(I, num_zones, T)
} = 0 :- item(I), step(T).

% 8. OPTIMIZATION
% Accumulate run_slot across slots, zones, and time
&dom{0..max_val} = run_slot_acc_slot(Z, S, T) :- zone(Z), slot(S), step(T).
&sum { run_slot_acc_slot(Z, 1, T); -run_slot(Z, 1, T) } = 0 :- zone(Z), step(T).
&sum { run_slot_acc_slot(Z, Snext, T); -run_slot_acc_slot(Z, S, T); -run_slot(Z, Snext, T) } = 0 :-
    zone(Z), step(T), next_slot(S, Snext), slot(Snext).

&dom{0..max_val} = run_slot_acc_zone(Z, T) :- zone(Z), step(T).
&sum { run_slot_acc_zone(1, T); -run_slot_acc_slot(1, num_slots, T) } = 0 :- step(T).
&sum { run_slot_acc_zone(Znext, T); -run_slot_acc_zone(Z, T); -run_slot_acc_slot(Znext, num_slots, T) } = 0 :-
    next_zone(Z, Znext), step(T).

&dom{0..max_val} = run_slot_acc_time(T) :- step(T).
&sum { run_slot_acc_time(0); -run_slot_acc_zone(num_zones, 0) } = 0.
&sum { run_slot_acc_time(Tnext); -run_slot_acc_time(T); -run_slot_acc_zone(num_zones, Tnext) } = 0 :-
    next_step(T, Tnext).

&dom{0..max_val} = run_slot_total.
&sum { run_slot_total; -run_slot_acc_time(T) } = 0 :- last_step(T).

% Accumulate use_global across slots, zones, items, and time
&dom{0..max_val} = use_global_acc_slot(I, Z, S, T) :- item(I), zone(Z), slot(S), step(T).
&sum { use_global_acc_slot(I, Z, 1, T); -use_global(I, Z, 1, T) } = 0 :- item(I), zone(Z), step(T).
&sum { use_global_acc_slot(I, Z, Snext, T); -use_global_acc_slot(I, Z, S, T); -use_global(I, Z, Snext, T) } = 0 :-
    item(I), zone(Z), step(T), next_slot(S, Snext), slot(Snext).

&dom{0..max_val} = use_global_acc_zone(I, Z, T) :- item(I), zone(Z), step(T).
&sum { use_global_acc_zone(I, 1, T); -use_global_acc_slot(I, 1, num_slots, T) } = 0 :- item(I), step(T).
&sum { use_global_acc_zone(I, Znext, T); -use_global_acc_zone(I, Z, T); -use_global_acc_slot(I, Znext, num_slots, T) } = 0 :-
    item(I), next_zone(Z, Znext), step(T).

&dom{0..max_val} = use_global_acc_item(N, T) :- item_pos(N), step(T).
&sum { use_global_acc_item(1, T); -use_global_acc_zone(I, num_zones, T) } = 0 :-
    item_at(1, I), step(T).
&sum { use_global_acc_item(Nnext, T); -use_global_acc_item(N, T); -use_global_acc_zone(I, num_zones, T) } = 0 :-
    item_pos(N), next_item(N, Nnext), item_at(Nnext, I), step(T).

&dom{0..max_val} = use_global_acc_time(T) :- step(T).
&sum { use_global_acc_time(0); -use_global_acc_item(N, 0) } = 0 :- item_count(N).
&sum { use_global_acc_time(Tnext); -use_global_acc_time(T); -use_global_acc_item(N, Tnext) } = 0 :-
    item_count(N), next_step(T, Tnext).

&dom{0..max_val} = use_global_total.
&sum { use_global_total; -use_global_acc_time(T) } = 0 :- last_step(T).

&maximize {
    run_slot_total * 100;
    use_global_total * -1
}.
