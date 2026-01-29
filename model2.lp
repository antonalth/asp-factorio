% =========================================================
% MODEL: Factorio-style Waterfall Resource Distribution
% =========================================================

% --- CONSTANTS & DOMAINS ---
%#const horizon = 20. 
%#const num_zones = 3.
%#const num_slots = 15.
#const max_val = 1000. 

time(0..horizon).
step(0..horizon-1).
zone(1..num_zones).
slot(1..num_slots).

% FIX: We need an index that goes one past the last slot for the output flow
flow_index(1..num_slots+1).

% --- STRUCTURE & LAYOUT (Static) ---

% 1. Assign Buildings to Slots (0 or 1 building per slot)
0 { slot_map(Z, S, B) : building(B) } 1 :- zone(Z), slot(S).

% 2. Constraint: No duplicate building types in the same zone
:- slot_map(Z, S1, B), slot_map(Z, S2, B), S1 != S2. 

% 3. Symmetry Breaking: Force buildings to pack to the left (1, 2, 3...)
has_assignment(Z, S) :- slot_map(Z, S, _).
:- has_assignment(Z, S+1), not has_assignment(Z, S), slot(S).

% Helper for build actions
can_build(B, Z) :- building(B), zone(Z), slot_map(Z, _, B).

% --- STATE VARIABLES ---
&dom{0..max_val} = stock(I,Z,T) :- item(I), zone(Z), time(T).
&dom{0..max_val} = globalstock(I,T) :- item(I), time(T).
&dom{0..max_val} = buildingcount(B, Z, T) :- building(B), zone(Z), time(T), slot_map(Z, _, B).

% --- ACTION LOGIC (Build & Craft) ---
busy(craft, STEP) :- step(STEP), act(craft(I), STEPSTART), dur(I, DUR), STEP > STEPSTART, STEP < STEPSTART + DUR.
busy(build, STEP) :- step(STEP), act(build(B,Z), STEPSTART), dur(B, DUR), STEP > STEPSTART, STEP < STEPSTART + DUR.

0{ act(craft(I), STEP) : item(I), dur(I, _)}1 :- step(STEP), not busy(craft, STEP). 
0{ act(build(B, Z), STEP) : building(B), zone(Z), dur(B, _), can_build(B, Z)}1 :- step(STEP), not busy(build,STEP).

finish(craft(I), TIME) :- time(TIME), act(craft(I), TIMESTART), dur(I, DUR), TIME = TIMESTART + DUR.
finish(build(B, Z), TIME) :- time(TIME), act(build(B, Z), TIMESTART), dur(B, DUR), TIME = TIMESTART + DUR.

% Update Building Counts
&sum { buildingcount(B, Z, T+1); -buildingcount(B, Z, T)} = 1 :- 
    building(B), zone(Z), step(T), slot_map(Z, _, B), finish(build(B, Z), T).
&sum { buildingcount(B, Z, T+1); -buildingcount(B, Z, T)} = 0 :- 
    building(B), zone(Z), step(T), slot_map(Z, _, B), not finish(build(B, Z), T).


% =========================================================
% === THE WATERFALL RESOURCE MODEL ===
% =========================================================

% 1. Topology
next_slot(S, S+1) :- slot(S).
next_zone(Z, Z+1) :- zone(Z), zone(Z+1).

% 2. Flow Variables (The "Conveyor Belt")
&dom{0..max_val} = local_flow(I, Z, IDX, T)  :- item(I), zone(Z), flow_index(IDX), step(T).
&dom{0..max_val} = global_flow(I, Z, IDX, T) :- item(I), zone(Z), flow_index(IDX), step(T).
&dom{0..max_val} = local_space(I, Z, IDX, T)  :- item(I), zone(Z), flow_index(IDX), step(T).
&dom{0..max_val} = global_space(I, Z, IDX, T) :- item(I), zone(Z), flow_index(IDX), step(T).

% 3. Run Variables
&dom{0..max_val} = run_slot(Z, S, T) :- zone(Z), slot(S), step(T).

% Constraint: Cannot run more than existing buildings
% (If slot is empty, buildingcount is undefined/0, so run_slot becomes 0)
&sum { run_slot(Z, S, T); -buildingcount(B, Z, T) } <= 0 :- slot_map(Z, S, B), step(T).
&sum { run_slot(Z, S, T) } = 0 :- zone(Z), slot(S), step(T), not has_assignment(Z, S).

% 4. INITIALIZATION (Stream Heads)

% A. Local Start (Slot 1): Gets Zone Stock & Space
&sum { local_flow(I, Z, 1, T); -stock(I, Z, T) } = 0 :- item(I), zone(Z), step(T).

% Space = Capacity - Stock
&sum { local_space(I, Z, 1, T); stock(I, Z, T) } = Cap :- item(I), zone(Z), step(T), stock_cap(I, Z, Cap).
&sum { local_space(I, Z, 1, T) } = max_val :- item(I), zone(Z), step(T), not stock_cap(I, Z, _).

% B. Global Start (Zone 1, Slot 1): Gets Global Stock & Space
&sum { global_flow(I, 1, 1, T); -globalstock(I, T) } = 0 :- item(I), step(T).
&sum { global_space(I, 1, 1, T); globalstock(I, T) } = Cap :- item(I), step(T), global_cap(I, Cap).
&sum { global_space(I, 1, 1, T) } = max_val :- item(I), step(T), not global_cap(I, _).

% C. Global Chain (Zone Z -> Zone Z+1): Connects Output of Z to Input of Z+1
&sum { global_flow(I, Znext, 1, T); -global_flow(I, Z, num_slots+1, T) } = 0 :- 
    item(I), next_zone(Z, Znext), step(T). 
&sum { global_space(I, Znext, 1, T); -global_space(I, Z, num_slots+1, T) } = 0 :- 
    item(I), next_zone(Z, Znext), step(T).


% 5. CONSUMPTION & PRODUCTION (Internal Logic)

% FIX: Define variables for ALL slots statically to appease Clingcon
&dom{0..max_val} = use_local(I, Z, S, T)  :- item(I), zone(Z), slot(S), step(T).
&dom{0..max_val} = use_global(I, Z, S, T) :- item(I), zone(Z), slot(S), step(T).
&dom{0..max_val} = fill_local(I, Z, S, T) :- item(I), zone(Z), slot(S), step(T).
&dom{0..max_val} = fill_global(I, Z, S, T) :- item(I), zone(Z), slot(S), step(T).

% --- ZEROING RULES (Force unused variables to 0) ---
% Case 1: Slot is empty
&sum { use_local(I, Z, S, T) } = 0  :- item(I), zone(Z), slot(S), step(T), not has_assignment(Z, S).
&sum { use_global(I, Z, S, T) } = 0 :- item(I), zone(Z), slot(S), step(T), not has_assignment(Z, S).
&sum { fill_local(I, Z, S, T) } = 0 :- item(I), zone(Z), slot(S), step(T), not has_assignment(Z, S).
&sum { fill_global(I, Z, S, T) } = 0 :- item(I), zone(Z), slot(S), step(T), not has_assignment(Z, S).

% Case 2: Slot has building, but recipe does not match
&sum { use_local(I, Z, S, T) } = 0  :- slot_map(Z, S, B), not building_in(B, I, _), step(T), item(I).
&sum { use_global(I, Z, S, T) } = 0 :- slot_map(Z, S, B), not building_in(B, I, _), step(T), item(I).
&sum { fill_local(I, Z, S, T) } = 0 :- slot_map(Z, S, B), not building_out(B, I, _), step(T), item(I).
&sum { fill_global(I, Z, S, T) } = 0 :- slot_map(Z, S, B), not building_out(B, I, _), step(T), item(I).

% --- ACTIVE LOGIC (Only applies if recipe matches) ---

% Input Ratio: Total Consumption = Qty * Runspeed
&sum { use_local(I, Z, S, T); use_global(I, Z, S, T); -Qty*run_slot(Z, S, T) } = 0 :-
    slot_map(Z, S, B), building_in(B, I, Qty), step(T).

% Input Availability: Consumption <= Incoming Flow
&sum { use_local(I, Z, S, T); -local_flow(I, Z, S, T) } <= 0 :- item(I), zone(Z), slot(S), step(T).
&sum { use_global(I, Z, S, T); -global_flow(I, Z, S, T) } <= 0 :- item(I), zone(Z), slot(S), step(T).

% Output Ratio: Total Production = Qty * Runspeed
&sum { fill_local(I, Z, S, T); fill_global(I, Z, S, T); -Qty*run_slot(Z, S, T) } = 0 :-
    slot_map(Z, S, B), building_out(B, I, Qty), step(T).

% Output Capacity: Production <= Incoming Space
&sum { fill_local(I, Z, S, T); -local_space(I, Z, S, T) } <= 0 :- item(I), zone(Z), slot(S), step(T).
&sum { fill_global(I, Z, S, T); -global_space(I, Z, S, T) } <= 0 :- item(I), zone(Z), slot(S), step(T).


% 6. FLOW UPDATES (S -> S+1)
% Note: Since we force use/fill to 0 for empty slots/unrelated items,
% we can use a SINGLE rule for all cases.
% Next = Current - Consumed (or + Produced for space)

% Item Flow: Decreases by Usage
&sum { local_flow(I, Z, S+1, T); -local_flow(I, Z, S, T); use_local(I, Z, S, T) } = 0 :-
    item(I), zone(Z), next_slot(S, _), step(T).

&sum { global_flow(I, Z, S+1, T); -global_flow(I, Z, S, T); use_global(I, Z, S, T) } = 0 :-
    item(I), zone(Z), next_slot(S, _), step(T).

% Space Flow: Decreases by Production (Filling)
&sum { local_space(I, Z, S+1, T); -local_space(I, Z, S, T); fill_local(I, Z, S, T) } = 0 :-
    item(I), zone(Z), next_slot(S, _), step(T).

&sum { global_space(I, Z, S+1, T); -global_space(I, Z, S, T); fill_global(I, Z, S, T) } = 0 :-
    item(I), zone(Z), next_slot(S, _), step(T).


% 7. TIME UPDATE (Closing the Loop)
% FIX: Sum over ALL slots unconditionally.
% Since 'fill' vars are 0 for empty slots, this sum is correct and valid in Clingcon.

% Local Stock T+1 = Flow leaving slot 15 + All Production (Fill)
&sum { stock(I, Z, T+1); 
       -local_flow(I, Z, num_slots+1, T); 
       -fill_local(I, Z, S, T) : slot(S)
} = 0 :- item(I), zone(Z), step(T).

% Global Stock T+1 = Flow leaving LAST Zone + All Exports (Fill Global)
&sum { globalstock(I, T+1);
       -global_flow(I, num_zones, num_slots+1, T); 
       -fill_global(I, Z, S, T) : zone(Z), slot(S)
} = 0 :- item(I), step(T).


% 8. OPTIMIZATION
&maximize {
    % Primary: Run as many factories as possible
    run_slot(Z, S, T) * 100 : zone(Z), slot(S), step(T), has_assignment(Z, S);
    
    % Secondary: Prefer Local Resources (Minimize Imports/Global Use)
    use_global(I, Z, S, T) * -1 : item(I), zone(Z), slot(S), step(T)
}.