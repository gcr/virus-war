import main
import bitmask
import mcts
import sugar
import argmax
import random
import options
import mcts_library
import sets

proc allStonePlacements(whoseTurn: Player, s: State, cb: (State)->void) =
    if s.whoseTurn != whoseTurn:
        cb(s)
    else:
        for action in s.actions:
            allStonePlacements(whoseTurn, s.next action, cb)

proc bestNextState(s: State): State =
    ## pick the best state
    var states: seq[State]
    allStonePlacements(s.whoseTurn, s, (s:State) => states.add s)
    dump states.len
    return argmax(s, states):
        -s.board.possibleMovesFor(s.whoseTurn).len.float + rand(1.0)


when isMainModule:
    randomize()
    var cs = State(
        board: board(9,9),
        whoseTurn: Player.A,
        capturesToMake: 1
    )
    cs = cs.bestNextState
    cs = cs.bestNextState
    cs = cs.bestNextState
    cs = cs.bestNextState
    cs = cs.bestNextState
    cs = cs.bestNextState
    cs = cs.bestNextState
    cs = cs.bestNextState
    var possibleStates: HashSet[State]
    echo cs.board
    echo cs
    allStonePlacements(cs.whoseTurn, cs, (s:State)=>possibleStates.incl s)
    var possibleReplies: HashSet[State]
    dump possibleStates.len
    for s in possibleStates:
        allStonePlacements(s.whoseTurn, s, (s2:State)=>possibleReplies.incl s2)
    var possibleResponses: HashSet[State]
    dump possibleReplies.len
    var count = 0
    for s in possibleReplies:
        count += 1
        if count mod 10000 == 0:
            echo count
        allStonePlacements(s.whoseTurn, s, (s2:State)=>possibleResponses.incl s2)
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