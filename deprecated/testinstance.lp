%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DOCUMENTATION: DEFINITIONS REQUIRED BY ENCODING.LP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Static Entities ---
% item(I).                  % Define an item name (e.g., stone, ore).
% building(B).              % Define a building name (e.g., miner).
% process(B).               % (Optional) If defined, the building has 'slack' (can run at <100% efficiency).
                            % If not defined, the building always runs at full capacity if active.

% --- Building/Production Logic ---
% building_in(B, I, Q).     % Building B requires Q amount of Item I per tick to run.
% building_out(B, I, Q).    % Building B produces Q amount of Item I per tick when running.
                            % NOTE: For infinite ground resources, define OUT but not IN.

% --- Construction & Crafting Recipes ---
% buildtime(B, D).          % Time (D steps) to construct building B.
% buildingredient(B, I, Q). % Cost (Q items of I) to construct building B.

% crafttime(I, D).          % Time (D steps) to hand-craft/hand-mine item I.
% craftingredient(Io, I, Q).% Cost to hand-craft Item Io. 
                            % NOTE: If Io has NO ingredients, it is "free" (hand-mined).

% --- Initial State (Optional - Defaults to 0) ---
% globalstock_init(I, N).       % Player inventory at T=0.
% localstock_init(I, Z, N).     % Zone Z inventory at T=0.
% buildingcount_init(B, Z, N).  % Buildings existing at T=0.

% --- Constraints/Limits (Optional) ---
% importcap(I, Z, Cap).         % Max import of item I into zone Z per step.
% localstockcap(I, Z, Cap).     % Max storage of item I in zone Z.

% --- Goals (Must be met at T=horizon) ---
% goalbuilding(B, Qty).         % Total buildings required across all zones.
% goalitem(I, Qty).             % Total items required (Global + Local stocks).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SAMPLE INSTANCE: "The First Miner"
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 1. Items
item(stone).
item(ore).

% 2. Buildings
building(burner_miner).
process(burner_miner). % Allows the miner to have slack if needed (though not strictly necessary here).

% 3. "Hand Mining" Logic (Player Action)
% We define stone as craftable, but give it NO ingredients.
% This allows the 'craft' action to generate stone from nothing (digging the ground).
crafttime(stone, 2). 

% 4. "Miner Building" Logic (Infinite Resource Building)
% It produces Ore, but consumes nothing (Input list is empty).
building_out(burner_miner, ore, 1).

% 5. Construction Costs
% To build a miner, you need 10 stone. It takes 5 steps to build.
buildtime(burner_miner, 5).
buildingredient(burner_miner, stone, 10).

% 6. Initial State
% We start with stone to allow immediate building of the miner.
globalstock_init(ore, 0).

% 7. Goals
% We want 50 Ore. 
% To get this, the solver MUST:
%   1. Hand-mine Stone (via 'craft').
%   2. Use Stone to build a 'burner_miner' (via 'build').
%   3. Wait for the miner to produce Ore (via 'runspeed'/'production').
goalbuilding(burner_miner, 1).
goalitem(ore, 10).

globalstock_init(stone, 10).

% (Optional) Force the miner to be built in Zone 1 explicitly, or let solver decide.
% Here we let the solver decide, but the ore must exist somewhere.
