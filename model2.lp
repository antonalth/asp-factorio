#const horizon = 20. 
#const num_zones = 3.
#const num_slots = 15.
#const max_val = 1000. 

time(0..horizon).
step(0..horizon-1).
zone(1..num_zones).
slot(1..num_slots).

% === FIX 1: Flow Index Domain ===
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


% =========================================================
% === WATERFALL RESOURCE MODEL ===
% =========================================================

next_slot(S, S+1) :- slot(S).
next_zone(Z, Z+1) :- zone(Z), zone(Z+1).

% 2. Flow Variables (Using flow_index instead of slot)
&dom{0..max_val} = local_flow(I, Z, IDX, T)  :- item(I), zone(Z), flow_index(IDX), step(T).
&dom{0..max_val} = global_flow(I, Z, IDX, T) :- item(I), zone(Z), flow_index(IDX), step(T).
&dom{0..max_val} = local_space(I, Z, IDX, T)  :- item(I), zone(Z), flow_index(IDX), step(T).
&dom{0..max_val} = global_space(I, Z, IDX, T) :- item(I), zone(Z), flow_index(IDX), step(T).

% 3. Run Variable
&dom{0..max_val} = run_slot(Z, S, T) :- zone(Z), slot(S), step(T), has_assignment(Z, S).

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

% Decision variables
&dom{0..max_val} = use_local(I, Z, S, T) :- item(I), zone(Z), step(T), has_assignment(Z, S), building_in(B, I, _), slot_map(Z,S,B).
&dom{0..max_val} = use_global(I, Z, S, T) :- item(I), zone(Z), step(T), has_assignment(Z, S), building_in(B, I, _), slot_map(Z,S,B).

% Inputs
&sum { use_local(I, Z, S, T); use_global(I, Z, S, T); -Qty*run_slot(Z, S, T) } = 0 :-
    slot_map(Z, S, B), building_in(B, I, Qty), step(T).

% Availability (Must satisfy flow)
&sum { use_local(I, Z, S, T); -local_flow(I, Z, S, T) } <= 0 :- slot_map(Z, S, B), building_in(B,I,_), step(T).
&sum { use_global(I, Z, S, T); -global_flow(I, Z, S, T) } <= 0 :- slot_map(Z, S, B), building_in(B,I,_), step(T).

% Outputs
&dom{0..max_val} = fill_local(I, Z, S, T) :- item(I), zone(Z), step(T), has_assignment(Z, S), building_out(B, I, _), slot_map(Z,S,B).
&dom{0..max_val} = fill_global(I, Z, S, T) :- item(I), zone(Z), step(T), has_assignment(Z, S), building_out(B, I, _), slot_map(Z,S,B).

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

% Local Stock T+1 = Flow Leaving Slot 15 + All Production added to Local
&sum { stock(I, Z, T+1); 
       -local_flow(I, Z, num_slots+1, T); 
       -fill_local(I, Z, S, T) : slot(S), has_assignment(Z, S), building_out(B, I, _), slot_map(Z,S,B)
} = 0 :- item(I), zone(Z), step(T).

% Global Stock T+1 = Flow Leaving LAST Zone + All Exports
&sum { globalstock(I, T+1);
       -global_flow(I, num_zones, num_slots+1, T); 
       -fill_global(I, Z, S, T) : zone(Z) : slot(S) : has_assignment(Z, S) : building_out(B, I, _) : slot_map(Z,S,B)
} = 0 :- item(I), step(T).

% 8. OPTIMIZATION
&maximize {
    run_slot(Z, S, T) * 100 : zone(Z), slot(S), step(T), has_assignment(Z, S);
    use_global(I, Z, S, T) * -1 : item(I), zone(Z), slot(S), step(T)
}.