#const horizon = 20. 
#const num_zones = 3.
#const num_slots = 15.
#const max_val = 1000. 

time(0..horizon).
step(0..horizon-1).
zone(1..num_zones).
slot(1..num_slots).

%setup variables for stocks and buildings
&dom{0..max_val} = globalstock(I, T) :- item(I), time(T).
&dom{0..max_val} = localstock(I,Z,T) :- item(I), zone(Z), time(T).
&dom{0..max_val} = buildingcount(B, Z, T) :- building(B), zone(Z), time(T).

% Init either to set val or zero (depending on instance)
&sum{ globalstock(I,0)} = N*scale :- globalstock_init(I, N).
&sum{ globalstock(I, 0)} = 0 :- item(I), not globalstock_init(I, _).
&sum{ localstock(I, Z, 0)} = N*scale :- localstock_init(I, Z, N).
&sum{ localstock(I, Z, 0)} = 0 :- item(I), zone(Z), not localstock_init(I, Z, _).

&sum{ buildingcount(B, Z, 0)} = N :- buildingcount_init(B, Z, N).
&sum{ buildingcount(B, Z, 0)} = 0 :- building(B), zone(Z), not buildingcount_init(B, Z, _).

%can start a craft and/or build per step (not time)
0{ craft(I, T) : item(I), crafttime(I, _)}1 :- step(T), not busycraft(T).
0{ build(B, Z, T) : building(B), zone(Z), buildtime(B,_)}1 :- step(T), not busybuild(T).

% set busy crafting or building if in timeframe(relative in steps)
busycraft(T) :- step(T), craft(I, Tx), crafttime(I, D), T > Tx, T < Tx + D.
busybuild(T) :- step(T), build(B, _, Tx), buildtime(B, D), T > Tx, T < Tx + D.

% finishcraft is regarding a timestep (the one after the final step required)
finishcraft(I, T) :- time(T), craft(I, T0), crafttime(I, D), T = T0 + D. 
finishbuild(B, Z, T) :- time(T), build(B, Z, T0), buildtime(B, D), T = T0 + D.

% Check if new building is built
&dom{0..1} = newbuilding_amnt(B, Z, T) :- building(B), zone(Z), time(T).
&sum{ newbuilding_amnt(B, Z, T)} = 1 :- finishbuild(B,Z,T).
&sum{ newbuilding_amnt(B, Z, T)} = 0 :- building(B), zone(Z), time(T), not finishbuild(B,Z,T).

% Add new building in zone if building is finished
&sum { buildingcount(B, Z, T+1); -buildingcount(B, Z, T); -newbuilding_amnt(B, Z, T+1)} = 0 :- building(B), zone(Z), step(T).

&sum { buildingcount(B, Z, T+1); -buildingcount(B, Z, T)} = 1 :- 
    building(B), zone(Z), step(T), finishbuild(B, Z, T).
&sum { buildingcount(B, Z, T+1); -buildingcount(B, Z, T)} = 0 :- 
    building(B), zone(Z), step(T), not finishbuild(B, Z, T).

% runspeed controls speed of a factory
&dom{0..max_val} = runspeed(B,Z,T)   :- building(B), zone(Z), step(T).

% runspeed <= number of factories (scaled)
:- building(B), zone(Z), step(T), &sum{ runspeed(B, Z, T); -scale*buildingcount(B, Z, T)} >= 1.

% set to zero if no buildings active
&sum { runspeed(B,Z,T) } = 0 :- building(B), zone(Z), step(T), &sum{ buildingcount(B, Z, T)} = 0.

% consumption and production variables of each item in each zone
&dom{0..max_val} = consumption(I,Z,T)   :- item(I), zone(Z), step(T).
&dom{0..max_val} = production(I,Z,T) :- item(I), zone(Z), step(T).

% set consumption and production based on runspeed of each factory type in each zone
&sum{ consumption(I, Z, T); -Q*runspeed(B, Z, T) : building(B), building_in(B, I, Q)} = 0 :- item(I), zone(Z), step(T).
&sum{ production(I, Z, T); -Q*runspeed(B, Z, T) : building(B), building_out(B, I, Q)} = 0 :- item(I), zone(Z), step(T).

% init import and export variables (in/out of zones)
&dom{0..max_val} = import(I, Z, T) :- item(I), zone(Z), step(T).
&dom{0..max_val} = export(I, Z, T) :- item(I), zone(Z), step(T).

% if importcap is set for zone, prevent from importing more than limit
:- item(I), zone(Z), step(T), importcap(I, Z, Cap), &sum{import(I, Z, T); -scale*Cap} >= 1.

% Availability constraint: consumption + exports <= stock + production + imports (for each item)
:- item(I), zone(Z), step(T), &sum{ consumption(I, Z, T); export(I, Z, T); -localstock(I, Z, T); -production(I, Z, T); -import(I, Z, T)} >= 1.

% All flows must sum to zero: lstock(T+1) = lstock(T) - consumption + production + imports - exports
&sum{ localstock(I, Z, T+1); -localstock(I, Z, T); consumption(I, Z, T); -production(I, Z, T); -import(I, Z, T); export(I, Z, T)} = 0 :- item(I), zone(Z), time(T), T < horizon.

% if localstockcap is set, force localstock of item to be less than or equal -> forces exports after certain point
:- item(I), zone(Z), time(T), T>0, localstockcap(I,Z,C), &sum{ localstock(I,Z,T); -scale*C } >= 1.

% craft and build consumption variable init
&dom{0..max_val} = craft_cost(I, T) :- item(I), step(T).
&dom{0..max_val} = craft_gain(I, T) :- item(I), time(T).
&dom{0..max_val} = build_cost(I, T) :- item(I), step(T).

% if craft at step T, set booleans 
craftcostset(I, T) :- craft(Io, T), craftingredient(Io, I, _). 
buildcostset(I, T) :- build(B, _, T), buildingredient(B, I, _).

%set cost for build/craft and craftgain to zero if no crafts/builds
&sum{ craft_cost(I, T)} = 0 :- item(I), step(T), not craftcostset(I, T).
&sum{ craft_gain(I, T)} = 0 :- item(I), time(T), not finishcraft(I, T).
&sum{ build_cost(I, T)} = 0 :- item(I), step(T), not buildcostset(I, T).

% set craft cost in step if craft started and requires Qty of item
&sum{ craft_cost(I, T); -scale*Qty} = 0 :- 
    item(I), step(T), craft(Io, T), craftingredient(Io, I, Qty).

%if craft is finished, add 1(scale) items to global stock
&sum{ craft_gain(I, T); -scale*1 } = 0 :- finishcraft(I, T).

% same for build cost
&sum{ build_cost(I, T); -scale*Qty} = 0 :- item(I), step(T), build(B, _, T), buildingredient(B, I, Qty).

% buildcost + craftcost + all imports <= global stock (enforce continuity)
:- item(I), step(T), &sum{ build_cost(I, T); craft_cost(I, T); import(I, Z, T) : zone(Z); -globalstock(I, T) } >= 1.

%globalstock calculation
&sum{ globalstock(I, T+1); 
        -globalstock(I, T); 
        -export(I, Z, T) : zone(Z);
        import(I, Z, T) : zone(Z);
        craft_cost(I, T);
        build_cost(I, T);
        -craft_gain(I, T+1) %available at step T+1
} = 0 :- item(I), time(T), T < horizon.

%% now we want to maximize runspeed of all factories in all zones
%% then avoid imports and exports as much as possible (typically resources stay in each zone)
&maximize {
    runspeed(B,Z,T) * 100000 : building(B), zone(Z), step(T);
    export(I,Z,T)   * -1     : item(I), zone(Z), step(T);
    import(I,Z,T)   * -1     : item(I), zone(Z), step(T)
}.

% we must reach our targets
:- goalbuilding(B, Qty), &sum{ buildingcount(B, Z, horizon) : zone(Z)} < Qty.
:- goalitem(I, Qty), &sum{ globalstock(I, horizon); localstock(I, Z, horizon): zone(Z)} < Qty.