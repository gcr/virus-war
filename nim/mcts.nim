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
      board: Board
      whoseTurn: Player
      capturesToMake: uint8 
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

proc isTerminal(state: State): bool =
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
        descendants: seq[Action]
        #isExpanded: seq[bool]
        nWinsA: uint
        nWinsB: uint
        nVisits: uint
        parent: State
    MCTSForest* = Table[State, MCTSNode]
proc `$`*(node: MCTSNode): string =
    fmt "Node(wins for A: {node.nWinsA.float/node.nVisits.float:0.3f}, ratio: {node.nWinsA} / {node.nWinsB} / {node.nVisits}, children: {node.descendants.len})"

proc score*(node: MCTSNode, parent_n: float, player: Player): float =
    let c_param = 0.5
    # exploitation
    if player == Player.A:
        result = node.nWinsA.float / (node.nVisits.float)
    else:
        result = node.nWinsB.float / (node.nVisits.float)
    # exploration
    result += c_param * sqrt(2.0 * ln(parent_n) / (node.nVisits.float))
    
proc isFullyExpanded*(forest: MCTSForest, state: State): bool =
    for action in forest[state].descendants:
        if state.next(action) notin forest:
            return false
    return true


proc selectAndExpand*(forest: var MCTSForest, state: State, total_playouts: float): State =
    result = state
    var parent_state: State = state
    while result in forest:
        # update parent
        forest[result].parent = parent_state
        parent_state = result
        if result.isTerminal:
            #echo "WARNING: returning terminal state"
            break
        if forest.isFullyExpanded(result):
            var
                best_score = -999.0
                best_action = forest[result].descendants[0]
            # select according to utility
            #let scores = forest[result].descendants.mapIt(
            #    score(forest[result.next it], forest[result].nVisits.float)
            #)
            #echo scores
            for action in forest[result].descendants:
                let node = forest[result.next action]
                let whoseTurn = result.whoseTurn
                let score = score(node, forest[result].nVisits.float, whoseTurn)
                if best_score < score:
                    best_score = score
                    best_action = action
            #echo "best score: ", best_score
            result = result.next best_action
            #if forest[result].parent != parent_state:
            #    echo "WARNING: parent state doesn't match"
            #    echo "Current state:"
            #    echo result
            #    echo "Parent in forest:"
            #    echo forest[result].parent
            #    echo "My parent state:"
            #    echo parent_state
        else:
            # select one of the unexpanded nodes
            var possible_actions = forest[result].descendants.filterIt(
                result.next(it) notin forest
            )
            result = result.next possible_actions.sample
    var actions = result.actions.toSeq
    if result notin forest:
        forest[result] = MCTSNode(
            descendants: actions,
            #isExpanded: actions.mapIt(false),
            nWinsA: 0,
            nWinsB: 0,
            nVisits: 0,
            parent: parent_state,
        )

proc rollout*(forest: var MCTSForest, startState: State) =
    var state: State = startState
    while not state.isTerminal:
        # Get actions
        var action = state.actions.toSeq.sample
        #rolloutState.board[action] ~> rolloutState.whoseTurn
        state = state.next action
    # Update nodes
    var winner = state.whoseTurn.other
    state = startState
    while true:
        if winner == Player.A:
            forest[state].nWinsA += 1
        else:
            forest[state].nWinsB += 1
        forest[state].nVisits += 1
        if forest[state].parent == state:
            break
        state = forest[state].parent

proc readLocFromStdin*(board: Board, forPlayer: Player): Loc =
    let str = readLineFromStdin "Pick a move> "
    let
        row = "abcdefghijklmnopqrstuvwxyz".find(str[0])
        col = "123456789abc".find(str[1])
    #if row == -1 or col == -1:
    #    continue
    result = (row.uint8, col.uint8)
    if result notin board:
        return board.readLocFromStdin forPlayer
    if (board[result] ~> forPlayer) == Invalid:
        return board.readLocFromStdin forPlayer
    if result notin board.possibleMovesFor(forPlayer).toSeq:
        return board.readLocFromStdin forPlayer


proc showLines(forest: MCTSForest, state: State) =
    echo "Current lines:"
    for action in forest[state].descendants:
        echo " -- ", action, "-> ", forest[state.next action]

proc mcts*(current_state: State, n_trials: int = 100000): Action =
    var forest: MCTSForest
    for i in 0 ..< n_trials:
        if i mod 500 == 0:
            #echo " ... MCTS expansion ", i
            write(stdout, fmt "\r...thinking... {100.0*i.float/n_trials.float:2.1f}%")
            flushFile(stdout)
        #if i > 0 and i mod (n_trials div 5) == 0:
        #    stdout.write "\r"
        #    showLines(forest, current_state)
        let state = forest.selectAndExpand(current_state, i.float)
        forest.rollout(state)
    stdout.write("\r")
    dump forest[current_state]
    var possible_actions = forest[current_state].descendants.toSeq
    for action in possible_actions:
        echo " -- ", action, "-> ", forest[current_state.next action]
    var best_idx = possible_actions.mapIt(
        forest[current_state.next it].nVisits
    ).maxIndex
    result = possible_actions[best_idx]
    echo "\nSelecting ", result, ": ", forest[current_state.next result]

        
when isMainModule:
    randomize()
    var current_state = State(
        board: board(5,5),
        whoseTurn: Player.A,
        capturesToMake: 1
    )

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
            var best_action = mcts(current_state)
            current_state = current_state.next best_action
        else:
            echo "Your turn!"
            var best_action = mcts(current_state)
            current_state = current_state.next best_action
            #current_state = current_state.next readLocFromStdin(current_state.board, Player.B)
