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
import bitmask


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

proc actions*(state: State): Bitmask =
    state.board.possibleMovesFor(state.whoseTurn)

proc isTerminal*(state: State): bool =
    return state.actions.len == 0

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
        parent*: ref MCTSNode

    MCTSForest* = Table[State, ref MCTSNode]
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

proc heuristic*(state: State, action: Action): float =
    var
        proposedState = state.next action
        nMyMoves = proposedState.board.possibleMovesFor(state.whoseTurn).len
        nYourMoves = proposedState.board.possibleMovesFor(state.whoseTurn.other).len
        nDiff = (nMyMoves - nYourMoves)
    return nDiff.float + rand(1.0)

proc noHeuristic*(state: State, action: Action): float =
    return 0.0 + rand(1.0)

proc fastHeuristic*(state: State, action: Action): float =
    if state.board[action].isLive and rand(1.0) > 0.2:
        return 1.0 + rand(1.0)
    return 0.0 + rand(1.0)
    #var
    #    proposedState = state.next action
    #    nMyMoves = memoizedNMoves(proposedState.board, state.whoseTurn)
    #    nYourMoves = memoizedNMoves(proposedState.board, state.whoseTurn.other)
    #    #nMyMoves = proposedState.board.possibleMovesFor(state.whoseTurn).toSeq.len
    #    #nYourMoves = proposedState.board.possibleMovesFor(state.whoseTurn.other).toSeq.len
    #    nDiff = (nMyMoves - nYourMoves)
    #return nDiff.float


proc selectAndExpand*(forest: var MCTSForest, state: State, h: HeuristicCallable): State =
    result = state
    var parent_state: State = state
    while result in forest:
        let thisNode: ref MCTSNode = forest[result]
        thisNode.parent = forest[parent_state]
        parent_state = result
        if thisNode[].isTerminal:
            break
        if forest.isFullyExpanded(result):
            # use policy to select one of the expanded nodes
            var
                best_score = -999.0
                best_action = thisNode.descendants[0]
            for action in thisNode.descendants:
                let nextState = result.next action
                let node = forest[nextState][]
                let whoseTurn = result.whoseTurn
                var score = score(node, thisNode.nVisits.float, whoseTurn)

                # AMAF?
                #score += 0.1 * amafScores[action.ravel] / (forest[result].nVisits.float + 1)
                # prefer captures?

                #if state.board[action].isLive:
                #    score += 500.0 / (forest[result].nVisits.float + 1)
                #    #score += 1.0 / ln(forest[result].nVisits.float + 1)
                score += h(result, action) / (thisNode.nVisits.float + 1)

                if best_score < score:
                    best_score = score
                    best_action = action
            result = result.next best_action
            #amafScores[best_action.ravel] += 1
        else:
            # select one of the unexpanded nodes
            var possible_actions = thisNode.descendants.filterIt(
                result.next(it) notin forest
            )
            possible_actions.shuffle
            let best_idx = possible_actions.mapIt(h(result, it)).maxIndex
            let action = possible_actions[best_idx]
            result = result.next action
            #amafScores[action.ravel] += 1
    var actions = result.actions.toSeq
    if result notin forest:
        var node = new MCTSNode
        forest[result] = node
        node.descendants = actions
        node.parent = forest[parent_state]

proc rollout*(forest: var MCTSForest, startState: State, h: HeuristicCallable) =
    var state: State = startState
    while true:
        var actions = state.actions
        if actions.len == 0: # terminal state
            break

        #state = state.next actions.sample
        #var captureActions = actions
        #captureActions.setIntersect state.board.liveCellsFor state.whoseTurn.other
        #if captureActions.len > 0 and rand(1.0) > 0.1:
        #    state = state.next captureActions.sample
        #else:
        #    state = state.next actions.sample

        var best_score = -99.0
        var best_action: Action
        for action in actions:
            let score = h(state, action)
            if score > best_score:
                best_score=score
                best_action=action
        state = state.next best_action

    # Update nodes
    var winner = state.whoseTurn.other
    state = startState
    var depth = 0
    var node = forest[state]
    while true:
        if winner == Player.A:
            node.nWinsA += 1
        else:
            node.nWinsB += 1
        node.nVisits += 1
        node.depthSum += depth
        depth += 1
        if node.parent == node:
            break
        node = node.parent

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

proc mcts*(
        forest: var MCTSForest,
        current_state: State,
        n_trials: int = 100000,
        h: HeuristicCallable,
        ): Action =
    ## Run MCTS a certain number of times, using the given heuristic

    #var amafScores: array[maxLocDeque, float]
    for i in 0 ..< n_trials:
        let state = forest.selectAndExpand(current_state, h)
        forest.rollout(state, h)
    var possible_actions = forest[current_state].descendants
    var best_idx = possible_actions.mapIt(
        forest[current_state.next it].nVisits
    ).maxIndex
    return possible_actions[best_idx]




################################################################################
when isMainModule:
    randomize()
    var current_state = State(
        board: board(5,5),
        whoseTurn: Player.A,
        capturesToMake: 1
    )
    var forest: MCTSForest

    dump sizeof MCTSForest
    dump sizeof MCTSNode
    dump sizeof State
    dump sizeof Board
    dump sizeof Cell

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
            var best_action = forest.mcts(current_state, 100000, heuristic)
            dump forest[current_state][]
            var possible_actions = forest[current_state].descendants
            for action in possible_actions:
                echo " -- ", action, "-> ", forest[current_state.next action][]
            current_state = current_state.next best_action
        else:
            echo "Your turn!"
            break
            var best_action = forest.mcts(current_state, 100000, heuristic)
            current_state = current_state.next best_action
