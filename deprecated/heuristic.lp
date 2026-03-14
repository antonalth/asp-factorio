%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Minimal dependency hypergraph heuristics
%
% Usage:
%   clingcon model2.lp game.lp instances/<instance>.lp heuristic.lp ...
%
% This file builds an exact support graph:
% - item nodes
% - producer nodes: craft(C) and build(B)
% - one supporting producer is chosen for each needed non-source item
% - selected nodes are derived only from goals and support dependencies
%
% Build costs and runtime inputs are treated identically for building nodes.
% The support graph is used only for heuristics and debugging.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#const heuristic_depth_limit = 24.
#const heuristic_goal_qty_large = 20.

depth_level(0..heuristic_depth_limit).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Base source items
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

source_item(wood).
source_item(coal).
source_item(stone).
source_item(iron).
source_item(copper).
source_item(uranium).
source_item(water).
source_item(crude_oil).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Hypergraph structure
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

graph_target_item(I) :- goal_item(I, _).
graph_target_building(B) :- goal_building(B, _).

graph_produces_building(B, I) :- building_out(B, I, _).
graph_produces_craft(C, I) :- crafting_out(C, I, _).

% Treat build costs and runtime inputs identically.
graph_requires_building(B, I) :- building_cost(B, I, _).
graph_requires_building(B, I) :- building_in(B, I, _).
graph_requires_craft(C, I) :- crafting_cost(C, I, _).

graph_building_req_count(B, N) :- building(B), N = #count { I : graph_requires_building(B, I) }.
graph_craft_req_count(C, N) :- crafting(C), N = #count { I : graph_requires_craft(C, I) }.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Exact support graph
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

graph_need_item(I) :- graph_target_item(I).
graph_need_building(B) :- graph_target_building(B).

% Every needed non-source item must pick exactly one supporting producer.
1 {
    graph_support_building(I, B) : graph_produces_building(B, I);
    graph_support_craft(I, C) : graph_produces_craft(C, I)
} 1 :- graph_need_item(I), not source_item(I).

graph_need_building(B) :- graph_support_building(_, B).
graph_need_craft(C) :- graph_support_craft(_, C).

graph_need_item(I) :- graph_need_building(B), graph_requires_building(B, I).
graph_need_item(I) :- graph_need_craft(C), graph_requires_craft(C, I).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Grounding from source resources
%
% Cycles are allowed in the selected graph, but every chosen node must still be
% reachable from source-resource items through fully justified requirements.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

graph_reachable_item(I) :- graph_need_item(I), source_item(I).

graph_reachable_building(B) :-
    graph_need_building(B),
    graph_building_req_count(B, N),
    N = #count { I : graph_requires_building(B, I), graph_reachable_item(I) }.

graph_reachable_craft(C) :-
    graph_need_craft(C),
    graph_craft_req_count(C, N),
    N = #count { I : graph_requires_craft(C, I), graph_reachable_item(I) }.

graph_reachable_item(I) :- graph_support_building(I, B), graph_reachable_building(B).
graph_reachable_item(I) :- graph_support_craft(I, C), graph_reachable_craft(C).

:- graph_need_item(I), not graph_reachable_item(I).
:- graph_need_building(B), not graph_reachable_building(B).
:- graph_need_craft(C), not graph_reachable_craft(C).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Minimal support preferences
%
% The exact graph above removes dangling branches. These heuristics bias the
% remaining producer choices toward smaller local fronts.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

large_goal_item(I) :- goal_item(I, Q), Q >= heuristic_goal_qty_large.

#heuristic graph_support_building(I, B) :
    graph_need_item(I),
    graph_produces_building(B, I),
    graph_building_req_count(B, N). [100 - N@95, true]

#heuristic graph_support_craft(I, C) :
    graph_need_item(I),
    graph_produces_craft(C, I),
    graph_craft_req_count(C, N). [100 - N@95, true]

#heuristic graph_support_building(I, B) :
    large_goal_item(I),
    graph_produces_building(B, I). [30@100, true]

#heuristic graph_support_craft(I, C) :
    large_goal_item(I),
    graph_produces_craft(C, I). [30@100, false]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Goal distance on the selected support graph
%
% Larger depth means farther upstream from the goals. We use bounded shortest
% reverse distance from the goal nodes, which remains well-defined even when
% the selected graph contains cycles.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

graph_candidate_item_depth(I, 0) :- graph_target_item(I).
graph_candidate_building_depth(B, 0) :- graph_target_building(B).

graph_candidate_building_depth(B, D+1) :-
    depth_level(D),
    graph_support_building(I, B),
    graph_candidate_item_depth(I, D).

graph_candidate_craft_depth(C, D+1) :-
    depth_level(D),
    graph_support_craft(I, C),
    graph_candidate_item_depth(I, D).

graph_candidate_item_depth(I, D+1) :-
    depth_level(D),
    graph_need_building(B),
    graph_requires_building(B, I),
    graph_candidate_building_depth(B, D).

graph_candidate_item_depth(I, D+1) :-
    depth_level(D),
    graph_need_craft(C),
    graph_requires_craft(C, I),
    graph_candidate_craft_depth(C, D).

graph_better_item_depth(I, D) :-
    graph_candidate_item_depth(I, D),
    graph_candidate_item_depth(I, D2),
    D2 < D.

graph_better_building_depth(B, D) :-
    graph_candidate_building_depth(B, D),
    graph_candidate_building_depth(B, D2),
    D2 < D.

graph_better_craft_depth(C, D) :-
    graph_candidate_craft_depth(C, D),
    graph_candidate_craft_depth(C, D2),
    D2 < D.

graph_item_depth(I, D) :-
    graph_candidate_item_depth(I, D),
    not graph_better_item_depth(I, D).

graph_building_depth(B, D) :-
    graph_candidate_building_depth(B, D),
    not graph_better_building_depth(B, D).

graph_craft_depth(C, D) :-
    graph_candidate_craft_depth(C, D),
    not graph_better_craft_depth(C, D).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Main-model heuristics driven by the support graph
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#heuristic slot_map(Z, S, B) :
    graph_need_building(B),
    graph_building_depth(B, D),
    zone(Z), slot(S). [25 + D@40, true]

#heuristic slot_map(Z, S, B) :
    building(B),
    not graph_need_building(B),
    zone(Z), slot(S). [5@30, false]

#heuristic act(build(B, Z), T) :
    graph_need_building(B),
    graph_building_depth(B, D),
    zone(Z), step(T). [35 + D@50, true]

#heuristic act(craft(C), T) :
    graph_need_craft(C),
    graph_craft_depth(C, D),
    step(T). [35 + D@50, true]

#heuristic act(build(B, Z), T) :
    graph_need_building(B),
    zone(Z), step(T). [(horizon - T)@35, true]

#heuristic act(craft(C), T) :
    graph_need_craft(C),
    step(T). [(horizon - T)@35, true]

#heuristic act(build(B, Z), T) :
    building(B),
    not graph_need_building(B),
    zone(Z), step(T). [10@25, false]

#heuristic act(craft(C), T) :
    crafting(C),
    not graph_need_craft(C),
    step(T). [10@25, false]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Debug / inspection
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#show source_item/1.
#show graph_target_item/1.
#show graph_target_building/1.

#show graph_produces_building/2.
#show graph_produces_craft/2.
#show graph_requires_building/2.
#show graph_requires_craft/2.

#show graph_need_item/1.
#show graph_need_building/1.
#show graph_need_craft/1.

#show graph_support_building/2.
#show graph_support_craft/2.

#show graph_reachable_item/1.
#show graph_reachable_building/1.
#show graph_reachable_craft/1.

#show graph_item_depth/2.
#show graph_building_depth/2.
#show graph_craft_depth/2.

#show graph_building_req_count/2.
#show graph_craft_req_count/2.

#show large_goal_item/1.
