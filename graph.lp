%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Phase 1: global dependency graph and minimal grounded subgraph
%
% Usage:
%   clingcon graph.lp game.lp instances/<instance>.lp --opt-mode=opt --quiet=1
%
% The instance file is used only for goal facts. This model builds:
% - the global dependency graph from game.lp
% - a minimal grounded subgraph that still contains every goal node
%
% Node kinds:
% - items
% - buildings
% - craft recipes
%
% Edge directions follow production flow:
% - required item -> producer node
% - producer node -> produced item
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

time(0..horizon).
step(0..horizon-1).
zone(1..num_zones).
slot(1..num_slots).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Base map resources
%
% These are the abstract raw resources available on the map. They are the
% starting layer for the dependency graph even if the game abstraction models
% a building or zero-cost craft for extracting them.
%
% Instances can extend the source set with:
%   heuristic_source(item_name).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

base_item(wood).
base_item(coal).
base_item(stone).
base_item(iron).
base_item(copper).
base_item(uranium).
base_item(water).
base_item(crude_oil).

source_item(I) :- base_item(I).
source_item(I) :- heuristic_source(I).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Global graph extracted from game.lp
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

graph_item(I) :- item(I).
graph_building(B) :- building(B).
graph_craft(C) :- crafting(C).

graph_produces_building(B, I) :- building_out(B, I, _).
graph_produces_craft(C, I) :- crafting_out(C, I, _).

graph_requires_building(B, I) :- building_cost(B, I, _).
graph_requires_building(B, I) :- building_in(B, I, _).
graph_requires_craft(C, I) :- crafting_cost(C, I, _).

graph_building_req_count(B, N) :-
    graph_building(B),
    N = #count { I : graph_requires_building(B, I) }.

graph_craft_req_count(C, N) :-
    graph_craft(C),
    N = #count { I : graph_requires_craft(C, I) }.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Minimal grounded subgraph
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

need_item(I) :- goal_item(I, _).
need_building(B) :- goal_building(B, _).

has_building_producer(I) :- graph_produces_building(_, I).
has_craft_producer(I) :- graph_produces_craft(_, I).

dual_path_item(I) :-
    has_building_producer(I),
    has_craft_producer(I).

1 { support_building(I, B) : graph_produces_building(B, I) } 1 :-
    need_item(I),
    not source_item(I),
    has_building_producer(I),
    not dual_path_item(I).

1 { support_craft(I, C) : graph_produces_craft(C, I) } 1 :-
    need_item(I),
    not source_item(I),
    has_craft_producer(I),
    not dual_path_item(I),
    not has_building_producer(I).

1 { support_building(I, B) : graph_produces_building(B, I) } 1 :-
    need_item(I),
    not source_item(I),
    dual_path_item(I).

1 { support_craft(I, C) : graph_produces_craft(C, I) } 1 :-
    need_item(I),
    not source_item(I),
    dual_path_item(I).

need_building(B) :- support_building(_, B).
need_craft(C) :- support_craft(_, C).

need_item(I) :- need_building(B), graph_requires_building(B, I).
need_item(I) :- need_craft(C), graph_requires_craft(C, I).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Grounding from base resources
%
% The selected subgraph may still contain cycles, but every selected node must
% be supported by a derivation that bottoms out in source items.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

reachable_item(I) :- need_item(I), source_item(I).

reachable_building(B) :-
    need_building(B),
    graph_building_req_count(B, N),
    N = #count { I : graph_requires_building(B, I), reachable_item(I) }.

reachable_craft(C) :-
    need_craft(C),
    graph_craft_req_count(C, N),
    N = #count { I : graph_requires_craft(C, I), reachable_item(I) }.

reachable_item(I) :- support_building(I, B), reachable_building(B).
reachable_item(I) :- support_craft(I, C), reachable_craft(C).

:- need_item(I), not reachable_item(I).
:- need_building(B), not reachable_building(B).
:- need_craft(C), not reachable_craft(C).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Optimization
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#minimize { 100@3, B : need_building(B), not goal_building(B, _) }.
#minimize { 100@3, C : need_craft(C) }.
#minimize {   1@2, I : need_item(I), not source_item(I), not goal_item(I, _) }.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Mild producer-choice heuristics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#heuristic support_building(I, B) :
    graph_produces_building(B, I),
    graph_building_req_count(B, N). [100 - N@20, true]

#heuristic support_craft(I, C) :
    graph_produces_craft(C, I),
    graph_craft_req_count(C, N). [100 - N@20, true]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#show base_item/1.
#show source_item/1.
#show heuristic_source/1.

#show goal_item/2.
#show goal_building/2.

#show graph_item/1.
#show graph_building/1.
#show graph_craft/1.

#show graph_produces_building/2.
#show graph_produces_craft/2.
#show graph_requires_building/2.
#show graph_requires_craft/2.

#show need_item/1.
#show need_building/1.
#show need_craft/1.

#show support_building/2.
#show support_craft/2.

#show reachable_item/1.
#show reachable_building/1.
#show reachable_craft/1.
