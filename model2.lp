#const horizon = 20. 
#const num_zones = 3.
#const num_slots = 15.
#const max_val = 1000. 

time(0..horizon).
step(0..horizon-1).
zone(1..num_zones).
slot(1..num_slots).


1{slot_map(Z, S, B) : building(B)}1 :- zone(Z), slot(S). % force structure once
:- slot_map(Z, S1, B), slot_map(Z, S2, B), S1 != S2. % only one slot max per building per zone

can_build(B, Z) :- building(B), zone(Z), slot_map(Z, _, B).

%setup variables for stocks and buildings
&dom{0..max_val} = stock(I,Z,T) :- item(I), zone(Z), time(T).
&dom{0..max_val} = buildingcount(B, Z, T) :- building(B), zone(Z), time(T), slot_map(Z, _, B).

busy(craft, STEP) :- step(STEP), act(craft(I), STEPSTART), dur(I, DUR), STEP > STEPSTART, STEP < STEPSTART + DUR.
busy(build, STEP) :- step(STEP), act(build(B,Z), STEPSTART), dur(B, DUR), STEP > STEPSTART, STEP < STEPSTART + DUR.

%can start a craft and/or build per step (not time)
0{ act(craft(I), STEP) : item(I), dur(I, _)}1 :- step(STEP), not busy(craft, STEP). 
0{ act(build(B, Z), STEP) : building(B), zone(Z), dur(B, _), can_build(B, Z)}1 :- step(STEP), not busy(build,STEP).

finish(craft(I), TIME) :- time(TIME), act(craft(I), TIMESTART), dur(I, DUR), TIME = TIMESTART + DUR.
finish(build(B, Z), TIME) :- time(TIME), act(build(B, Z), TIMESTART), dur(B, DUR), TIME = TIMESTART + DUR.

&sum { buildingcount(B, Z, T+1); -buildingcount(B, Z, T)} = 1 :- 
    building(B), zone(Z), step(T), slot_map(Z, _, B), finish(build(B, Z), T).
&sum { buildingcount(B, Z, T+1); -buildingcount(B, Z, T)} = 0 :- 
    building(B), zone(Z), step(T), slot_map(Z, _, B), not finish(build(B, Z), T).

% amount of running factories at step
&dom{0..max_val} = run(B,Z,T) :- building(B), zone(Z), step(T), slot_map(Z, _, B).

% run <= buildingcount
&sum { run(B,Z,T); -buildingcount(B,Z,T) } <= 0 :- building(B), zone(Z), step(T), slot_map(Z,_,B).