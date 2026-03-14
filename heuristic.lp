%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Phase 2: optional search hints from a phase-1 dependency graph
%
% Usage:
%   clingcon model2.lp heuristic.lp game.lp instances/<instance>.lp <hint-file>.lp ...
%
% The hint file is generated from a phase-1 graph solve and contains facts like:
% - hint_depth_building(B, D)
% - hint_depth_craft(C, D)
% - hint_depth_item(I, D)
% - hint_max_depth(D)
%
% Lower depth means closer to the base resources. These heuristics prefer
% low-depth layers earlier in the search, while staying purely advisory.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#const default_build_hint_limit = 1.
#const large_goal_item_threshold = 20.

has_graph_hints :- hint_max_depth(_).

hinted_building(B) :- hint_depth_building(B, _).
hinted_craft(C) :- hint_depth_craft(C, _).

large_goal_item(I) :- goal_item(I, Q), Q >= large_goal_item_threshold.
large_goal_craft(C) :-
    crafting_out(C, I, _),
    large_goal_item(I).

below_build_hint_limit(B, T) :-
    has_graph_hints,
    building(B), step(T),
    &sum { building_count(B, Z, T) : zone(Z) } < default_build_hint_limit.

#heuristic slot_map(Z, S, B) :
    has_graph_hints,
    hint_depth_building(B, D),
    zone(Z), slot(S). [200 - 5 * D@60, true]

#heuristic act(build(B, Z), T) :
    has_graph_hints,
    hint_depth_building(B, D),
    below_build_hint_limit(B, T),
    zone(Z), step(T). [300 - 10 * D@80, true]

#heuristic act(craft(C), T) :
    has_graph_hints,
    hint_depth_craft(C, D),
    not large_goal_craft(C),
    step(T). [300 - 10 * D@80, true]

#heuristic act(build(B, Z), T) :
    has_graph_hints,
    hinted_building(B),
    below_build_hint_limit(B, T),
    zone(Z), step(T). [(horizon - T)@70, true]

#heuristic act(craft(C), T) :
    has_graph_hints,
    hinted_craft(C),
    not large_goal_craft(C),
    step(T). [(horizon - T)@70, true]

#heuristic act(craft(C), T) :
    has_graph_hints,
    large_goal_craft(C),
    step(T). [50@80, false]

#heuristic slot_map(Z, S, B) :
    has_graph_hints,
    building(B),
    not hinted_building(B),
    zone(Z), slot(S). [20@20, false]

#heuristic act(build(B, Z), T) :
    has_graph_hints,
    building(B),
    not hinted_building(B),
    zone(Z), step(T). [20@20, false]

#heuristic act(craft(C), T) :
    has_graph_hints,
    crafting(C),
    not hinted_craft(C),
    step(T). [20@20, false]
