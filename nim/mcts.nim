import main
import tables
import hashes
import sugar
import random
import strutils
import sequtils
import strformat
import algorithm
import options
import hashes
import sugar
import sets
import deques
import random
import strformat
import rdstdin
import math


type
    State* = object
      board*: Board
      whoseTurn*: Player
      capturesToMake*: uint8 
      # how many moves this player has yet to make on this turn.
      # typically starts at 3, and when it's 0, play ends

    Action* = Loc
proc `$`*(s: State): string =
    result = $s.board
    if s.whoseTurn == Player.A:
        result &= "\e[1;31m"
    else:
        result &= "\e[1;32m"
    result &= "»\e[0m"
    result &= " It's {s.whoseTurn}'s turn to place ".fmt
    result &= "{s.capturesToMake} more cell".fmt
    if s.capturesToMake > 1:
        result &= "s"

iterator actions*(state: State): Action =
    for loc in state.board.possibleMovesFor(state.whoseTurn):
        yield loc

proc isTerminal*(state: State): bool =
    for action in state.actions:
        return false
    return true

proc next*(state: State, a: Action): State =
    result = state
    result.board[a] = result.board[a] ~> result.whoseTurn
    result.capturesToMake -= 1
    if result.capturesToMake == 0:
        result.capturesToMake = 3
        result.whoseTurn = result.whoseTurn.other


type
    MCTSNode* = object
        descendants*: seq[Action]
        definitelyExpanded: bool
        nWinsA*: uint
        nWinsB*: uint
        nVisits*: uint
        depthSum*: int
        parent*: State

    MCTSForest* = Table[State, MCTSNode]
proc `$`*(node: MCTSNode): string =
    fmt "Node(wins for A: {node.nWinsA.float/node.nVisits.float:0.3f}, ratio: {node.nWinsA} / {node.nWinsB} / {node.nVisits}, children: {node.descendants.len})"

proc winAFraction*(node: MCTSNode): float =
    node.nWinsA.float / node.nVisits.float
proc winBFraction*(node: MCTSNode): float =
    node.nWinsB.float / node.nVisits.float
proc winFraction*(node: MCTSNode, player: Player): float =
    if player == Player.A:
        node.winAFraction
    else:
        node.winBFraction
proc bestAction*(forest: MCTSForest, state: State): Loc =
    let actions = forest[state].descendants
    actions[actions.mapIt(forest[state.next it].nVisits).maxIndex]
proc avgDepth*(forest: MCTSForest, node: MCTSNode): float =
    node.depthSum.float / node.nVisits.float

proc score*(node: MCTSNode, parent_n: float, player: Player): float =
    let c_param = 1.0
    # 0.75 is a good value
    # exploitation
    if player == Player.A:
        result = node.nWinsA.float / (node.nVisits.float)
    else:
        result = node.nWinsB.float / (node.nVisits.float)
    # exploration
    result += c_param * sqrt(2.0 * ln(parent_n) / (node.nVisits.float))

proc isTerminal*(node: MCTSNode): bool = node.descendants.len == 0

proc isFullyExpanded*(forest: var MCTSForest, state: State): bool =
    if forest[state].definitelyExpanded:
        return true
    for action in forest[state].descendants:
        if state.next(action) notin forest:
            return false
    forest[state].definitelyExpanded = true
    return true

type HeuristicCallable* = (State, Action) -> float

var NMOVES_MEMOIZED: Table[(Board, Player), int]
proc memoizedNMoves*(b: Board, p: Player): int =
    if (b,p) notin NMOVES_MEMOIZED:
        NMOVES_MEMOIZED[(b, p)] = b.possibleMovesFor(p).toSeq.len
    return NMOVES_MEMOIZED[(b,p)]
proc heuristic*(state: State, action: Action): float =
    var 
        proposedState = state.next action
        nMyMoves = memoizedNMoves(proposedState.board, state.whoseTurn)
        nYourMoves = memoizedNMoves(proposedState.board, state.whoseTurn.other)
        #nMyMoves = proposedState.board.possibleMovesFor(state.whoseTurn).toSeq.len
        #nYourMoves = proposedState.board.possibleMovesFor(state.whoseTurn.other).toSeq.len
        nDiff = (nMyMoves - nYourMoves)
    return nDiff.float

proc noHeuristic*(state: State, action: Action): float =
    return 0.0

proc fastHeuristic*(state: State, action: Action): float =
    if state.board[action].isLive:
        return 10.0
    return 0.0
    #var 
    #    proposedState = state.next action
    #    nMyMoves = memoizedNMoves(proposedState.board, state.whoseTurn)
    #    nYourMoves = memoizedNMoves(proposedState.board, state.whoseTurn.other)
    #    #nMyMoves = proposedState.board.possibleMovesFor(state.whoseTurn).toSeq.len
    #    #nYourMoves = proposedState.board.possibleMovesFor(state.whoseTurn.other).toSeq.len
    #    nDiff = (nMyMoves - nYourMoves)
    #return nDiff.float


proc selectAndExpand*(forest: var MCTSForest, state: State, total_playouts: float, h: HeuristicCallable): State =
    result = state
    var parent_state: State = state
    while result in forest:
        forest[result].parent = parent_state
        parent_state = result
        if forest[result].isTerminal:
            break
        if forest.isFullyExpanded(result):
            # use policy to select one of the expanded nodes
            var
                best_score = -999.0
                best_action = forest[result].descendants[0]
            for action in forest[result].descendants:
                let nextState = result.next action
                let node = forest[nextState]
                let whoseTurn = result.whoseTurn
                var score = score(node, forest[result].nVisits.float, whoseTurn)

                # AMAF?
                #score += 0.1 * amafScores[action.ravel] / (forest[result].nVisits.float + 1)
                # prefer captures?

                #if state.board[action].isLive:
                #    score += 500.0 / (forest[result].nVisits.float + 1)
                #    #score += 1.0 / ln(forest[result].nVisits.float + 1)
                score += h(result, action) / (forest[result].nVisits.float + 1)

                if best_score < score:
                    best_score = score
                    best_action = action
            result = result.next best_action
            #amafScores[best_action.ravel] += 1
        else:
            # select one of the unexpanded nodes
            var possible_actions = forest[result].descendants.filterIt(
                result.next(it) notin forest
            )
            possible_actions.shuffle
            let best_idx = possible_actions.mapIt(h(result, it)).maxIndex
            let action = possible_actions[best_idx]
            result = result.next action
            #amafScores[action.ravel] += 1
    var actions = result.actions.toSeq
    if result notin forest:
        forest[result] = MCTSNode(
            descendants: actions,
            parent: parent_state,
        )

proc rollout*(forest: var MCTSForest, startState: State, h: HeuristicCallable) =
    var state: State = startState
    while true:
        var actions = state.actions.toSeq
        if actions.len == 0: # terminal state
            break
        let capture_actions = actions.filterIt(state.board[it].isLive)
        if capture_actions.len > 0 and rand(1.0) > 0.2:
            state = state.next capture_actions.sample
        #if rand(1.0) > 0.1:
        #    actions.shuffle
        #    let best_idx = actions.mapIt(h(state, it)).maxIndex
        #    state = state.next actions[best_idx]
        else:
            # random
            state = state.next actions.sample
    # Update nodes
    var winner = state.whoseTurn.other
    state = startState
    var depth = 0
    while true:
        if winner == Player.A:
            forest[state].nWinsA += 1
        else:
            forest[state].nWinsB += 1
        forest[state].nVisits += 1
        forest[state].depthSum += depth
        depth += 1
        if forest[state].parent == state:
            break
        state = forest[state].parent

proc readLocFromStdin*(board: Board, forPlayer: Player): Loc =
    let str = readLineFromStdin "Pick a move> "
    let
        row = "abcdefghijklmnopqrstuvwxyz".find(str[0])
        col = "123456789abc".find(str[1])
    result = (row.uint8, col.uint8)
    if result notin board:
        return board.readLocFromStdin forPlayer
    if (board[result] ~> forPlayer) == Invalid:
        return board.readLocFromStdin forPlayer
    if result notin board.possibleMovesFor(forPlayer).toSeq:
        return board.readLocFromStdin forPlayer

proc nothing(f: var MCTSForest) = discard

proc mcts*(forest: var MCTSForest, current_state: State, n_trials: int = 100000, h: HeuristicCallable, cb: (var MCTSForest)->void = nothing): Action =
    #var amafScores: array[maxLocDeque, float]
    for i in 0 ..< n_trials:
        let state = forest.selectAndExpand(current_state, i.float, h)
        forest.rollout(state, h)
        cb(forest)
    var possible_actions = forest[current_state].descendants.toSeq
    var best_idx = possible_actions.mapIt(
        forest[current_state.next it].nVisits
    ).maxIndex
    return possible_actions[best_idx]

proc mcts_verbose*(forest: var MCTSForest, current_state: State, n_trials: int = 100000): Action =
    var i=0
    proc cb(forest: var MCTSForest) =
        i += 1
        if i mod 500 == 0:
            write(stdout, fmt "\r...thinking... {100.0*i.float/n_trials.float:2.1f}%")
            flushFile(stdout)

    result = mcts(forest, current_state, n_trials, heuristic, cb)
    stdout.write("\r")
    dump forest[current_state]
    var possible_actions = forest[current_state].descendants.toSeq
    for action in possible_actions:
        echo " -- ", action, "-> ", forest[current_state.next action]
    echo "\nSelecting ", result, ": ", forest[current_state.next result]
        
when isMainModule:
    randomize()
    var current_state = State(
        board: board(5,5),
        whoseTurn: Player.A,
        capturesToMake: 1
    )
    var forest: MCTSForest

    if current_state.whoseTurn == Player.B:
        echo "You have the first move."
    while true:
        echo current_state
        if current_state.isTerminal:
            echo "...but {current_state.whoseTurn} can't move!".fmt
            echo "Good game! {current_state.whoseTurn.other} wins!".fmt
            break
        if current_state.whoseTurn == Player.A:
            echo "My turn!"
            var best_action = forest.mcts_verbose(current_state)
            current_state = current_state.next best_action
        else:
            echo "Your turn!"
            break
            var best_action = forest.mcts_verbose(current_state)
            current_state = current_state.next best_action