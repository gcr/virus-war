import main
import tables
import hashes
import sugar
import random
import strutils
import sequtils
import strformat
import options
import math
import bitmask
import argmax
import mcts


for size in [("10k", 10000), ("100k", 100000)]:
    let rolloutstr = size[0]
    let n_trials = size[1]
    register MCTSStrategy(
        tag:               "fast/{rolloutstr}".fmt,
        selectHeuristic:   fastHeuristic,
        rolloutHeuristic:  fastHeuristic,
        stoppingCriterion: stopAtNTrials n_trials,
    )
    register MCTSStrategy(
        tag:               "od/{rolloutstr}".fmt,
        selectHeuristic:   optionsDiffHeuristic,
        rolloutHeuristic:  optionsDiffHeuristic,
        stoppingCriterion: stopAtNTrials n_trials,
    )
    register MCTSStrategy(
        tag:               "hybrid/{rolloutstr}".fmt,
        selectHeuristic:   optionsDiffHeuristic,
        rolloutHeuristic:  fastHeuristic,
        stoppingCriterion: stopAtNTrials n_trials,
    )
    register MCTSStrategy(
        tag:               "hybridlog/{rolloutstr}".fmt,
        selectHeuristic:   optionsDiffHeuristic,
        rolloutHeuristic:  fastHeuristic,
        stoppingCriterion: stopAtNTrials n_trials,
        useLogScoreVisitHeuristicNormalization: true,
    )

when isMainModule:
    var
        strat_A = get(getMCTSStrategy "fast/10k")
        forest_A: MCTSForest
        strat_B = get(getMCTSStrategy "fast/10k")
        forest_B: MCTSForest
        currentState = State(
            board: board(9,9),
            whoseTurn: if rand(1.0) > 0.5: Player.A else: Player.B,
            capturesToMake: 1
        )
    while true:
        echo current_state
        if current_state.isTerminal:
            echo "Good game!"
            break
        case current_state.whoseTurn:
        of Player.A:
            let best_action = mcts(strat_A, forest_A, current_state)
            current_state = current_state.next best_action
        of Player.B:
            let best_action = (
                mcts(strat_B, forest_B, current_state)
            )
            current_state = current_state.next best_action
