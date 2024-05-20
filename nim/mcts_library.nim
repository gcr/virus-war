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
import console_pretty_trace


for size in [("10k", 10000), ("100k", 100000)]:
    let rolloutstr = size[0]
    let n_trials = size[1]
    register MCTSStrategy(
        tag:               "fastest/{rolloutstr}".fmt,
        selectHeuristic:   noHeuristic,
        rolloutHeuristic:  noHeuristic,
        stoppingCriterion: stopAtNTrials n_trials,
    )
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
        tag:               "odLog/{rolloutstr}".fmt,
        selectHeuristic:   optionsDiffHeuristic,
        rolloutHeuristic:  optionsDiffHeuristic,
        stoppingCriterion: stopAtNTrials n_trials,
        useLogScoreVisitHeuristicNormalization: true,
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


proc runMatch(A_strategy="", B_strategy="", size=9) =
    randomize()
    var
        console = ConsoleOutput()
        strat_A = get(getMCTSStrategy A_strategy)
        forest_A: MCTSForest
        strat_B = get(getMCTSStrategy B_strategy)
        forest_B: MCTSForest
        currentState = State(
            board: board(size.uint8, size.uint8),
            whoseTurn: if rand(1.0) > 0.5: Player.A else: Player.B,
            capturesToMake: 1
        )
        strats = [Player.A: strat_A, Player.B: strat_B]
        forests = [Player.A: forest_A, Player.B: forest_B]
    echo strat_A
    echo strat_B
    while not currentState.isTerminal:
        let p = currentState.whoseTurn
        let bestAction = mcts(strats[p], forests[p], currentState, cb=(i:int)=>
            console.show(forests[p], i, currentState))
        console.done(forests[p], currentState, bestAction)
        currentState = currentState.next bestAction
        echo currentState.board
    echo currentState

when isMainModule:
    import cligen; dispatch runMatch