import board
import bitmask
import mcts
import sugar
import argmax
import random
import options
import mcts_library
import sets
import strategyUtils
import strformat

proc allStonePlacements(whoseTurn: Player, s: State, cb: (State, seq[Action])->void, path: seq[Action]= @[]) =
    if s.whoseTurn != whoseTurn:
        cb(s, path)
    else:
        for action in s.actions:
            allStonePlacements(whoseTurn, s.next action, cb, path & @[action])

proc bestNextAction(ss: State): Action =
    ## pick the best state
    var states: seq[(State, seq[Action])]
    allStonePlacements(ss.whoseTurn, ss, (s:State, path: seq[Action]) => states.add (s, path))
    dump states.len
    let bestTup = argmax(s, states):
        -s[0].board.possibleMovesFor(ss.whoseTurn.other).len.float + rand(1.0)
    echo "Selecting best state with {bestTup[0].board.possibleMovesFor(ss.whoseTurn.other).len} moves for opponent".fmt
    #echo bestTup[0].board
    #echo bestTup[0]
    bestTup[1][0]

# Implementation
type SimpleMooStrategy = ref object of Strategy
method nextMove*(strat: Strategy, currentState: State, cb: StrategyMoveCallback): Action =
    return bestNextAction(currentState)

register SimpleMooStrategy(
    tag: "moo/one",
    selectOnRandom: true,
)



when isMainModule:
    randomize()
    var cs = State(
        board: board(9,9),
        whoseTurn: Player.A,
        capturesToMake: 1
    )
    cs = cs.next cs.bestNextAction
    echo "--"
    cs = cs.next cs.bestNextAction
    cs = cs.next cs.bestNextAction
    cs = cs.next cs.bestNextAction
    cs = cs.next cs.bestNextAction
    cs = cs.next cs.bestNextAction
    cs = cs.next cs.bestNextAction
    cs = cs.next cs.bestNextAction
    cs = cs.next cs.bestNextAction
    var possibleStates: HashSet[State]
    echo cs.board
    echo cs
    allStonePlacements(cs.whoseTurn, cs, (s:State, a:seq[Action])=>possibleStates.incl s)
    var possibleReplies: HashSet[State]
    dump possibleStates.len
    for s in possibleStates:
        allStonePlacements(s.whoseTurn, s, (s2:State, a:seq[Action])=>possibleReplies.incl s2)
    var possibleResponses: HashSet[State]
    dump possibleReplies.len
    var count = 0
    for s in possibleReplies:
        count += 1
        if count mod 10000 == 0:
            echo count
        allStonePlacements(s.whoseTurn, s, (s2:State, a:seq[Action])=>possibleResponses.incl s2)
    dump possibleResponses.len



#[
when isMainModule:
    randomize()
    var current_state = State(
        board: board(9,9),
        whoseTurn: Player.A,
        capturesToMake: 1
    )
    var strat = get(getMCTSStrategy "moo/50k")
    var forest: MCTSForest
    while not current_state.isTerminal:
        if current_state.whoseTurn == Player.B:
            let bestAction = mcts(strat, forest, current_state)
            current_state = current_state.next bestAction
        else:
            current_state = current_state.bestNextState
        echo current_state.board
        echo current_state
]#