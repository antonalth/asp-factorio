%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Abstract dependency graph / minimal grounded subgraph
%
% Usage:
%   clingcon graph.lp game.lp <goal-file>.lp --opt-mode=opt --quiet=1
%
% This file ignores instance state and solves only over the abstract game
% dependency hypergraph:
% - item nodes
% - build(B) producer nodes
% - craft(C) producer nodes
%
% A minimal grounded support graph is selected such that:
% - all goal items/buildings are included
% - each needed non-source item has at least one support producer
% - selected producers pull in all of their incoming requirements
% - the resulting subgraph is reachable from source-resource items
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Source items
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
% Full global hypergraph
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

full_item(I) :- item(I).
full_building(B) :- building(B).
full_craft(C) :- crafting(C).

full_produces_building(B, I) :- building_out(B, I, _).
full_produces_craft(C, I) :- crafting_out(C, I, _).

% Treat build and runtime requirements identically for build nodes.
full_requires_building(B, I) :- building_cost(B, I, _).
full_requires_building(B, I) :- building_in(B, I, _).
full_requires_craft(C, I) :- crafting_cost(C, I, _).

full_building_req_count(B, N) :- building(B), N = #count { I : full_requires_building(B, I) }.
full_craft_req_count(C, N) :- crafting(C), N = #count { I : full_requires_craft(C, I) }.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Selected minimal grounded subgraph
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

need_item(I) :- goal_item(I, _).
need_building(B) :- goal_building(B, _).

{ support_building(I, B) : full_produces_building(B, I) } :-
    need_item(I), not source_item(I).

{ support_craft(I, C) : full_produces_craft(C, I) } :-
    need_item(I), not source_item(I).

:- need_item(I), not source_item(I),
   not support_building(I, _),
   not support_craft(I, _).

need_building(B) :- support_building(_, B).
need_craft(C) :- support_craft(_, C).

need_item(I) :- need_building(B), full_requires_building(B, I).
need_item(I) :- need_craft(C), full_requires_craft(C, I).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Grounding in source resources
%
% Cycles are allowed in the global graph, but the selected subgraph must still
% have a derivation from source items. This rules out self-supporting SCCs that
% never bottom out in raw resources.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

reachable_item(I) :- need_item(I), source_item(I).

reachable_building(B) :-
    need_building(B),
    full_building_req_count(B, N),
    N = #count { I : full_requires_building(B, I), reachable_item(I) }.

reachable_craft(C) :-
    need_craft(C),
    full_craft_req_count(C, N),
    N = #count { I : full_requires_craft(C, I), reachable_item(I) }.

reachable_item(I) :- support_building(I, B), reachable_building(B).
reachable_item(I) :- support_craft(I, C), reachable_craft(C).

:- need_item(I), not reachable_item(I).
:- need_building(B), not reachable_building(B).
:- need_craft(C), not reachable_craft(C).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Minimize the selected subgraph
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#minimize { 100@2, B : need_building(B), not goal_building(B, _) }.
#minimize { 100@2, C : need_craft(C) }.
#minimize {   1@1, I : need_item(I), not source_item(I), not goal_item(I, _) }.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Helpful producer-choice heuristics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

large_goal_item(I) :- goal_item(I, Q), Q >= 20.

#heuristic support_building(I, B) :
    need_item(I),
    full_produces_building(B, I),
    full_building_req_count(B, N). [100 - N@50, true]

#heuristic support_craft(I, C) :
    need_item(I),
    full_produces_craft(C, I),
    full_craft_req_count(C, N). [100 - N@50, true]

#heuristic support_building(I, B) :
    large_goal_item(I),
    full_produces_building(B, I). [30@60, true]

#heuristic support_craft(I, C) :
    large_goal_item(I),
    full_produces_craft(C, I). [30@60, false]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Debug / inspection
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#show source_item/1.
% Preserve the goal facts in the output so graph logs are self-contained.
#show goal_item/2.
#show goal_building/2.

#show full_produces_building/2.
#show full_produces_craft/2.
#show full_requires_building/2.
#show full_requires_craft/2.

#show need_item/1.
#show need_building/1.
#show need_craft/1.

#show support_building/2.
#show support_craft/2.

#show reachable_item/1.
#show reachable_building/1.
#show reachable_craft/1.
