import main
import mcts
import terminal
import tables
import random
import strformat
import strutils
import streams
import sugar
import sequtils
import gameLog

type RGB = tuple 
    r: float
    g: float
    b: float
proc `+`(a: RGB, b: RGB): RGB = (a.r+b.r, a.g+b.g, a.b+b.b)
proc `*`(a: float, b: RGB): RGB = (a*b.r, a*b.g, a*b.b)
proc bg(col: RGB): string =
    result &= $(col.r * 255.0).int & ";"
    result &= $(col.g * 255.0).int & ";"
    result &= $(col.b * 255.0).int & "m"
    result = "\e[48;2;" & result


proc nodeToBgcolor(forest: MCTSForest, node: MCTSNode, root_node: MCTSNode): RGB =
    const
        Awinning: RGB = (0.8, 0.0, 0.0)
        Bwinning: RGB = (0.0, 0.8, 0.0)
        Nwinning: RGB = (1.0, 1.0, 0.0)
        Novisited: RGB = (0.99, 0.96, 0.89)
    var
        totalVisits = root_node.nVisits.float
        fracAWin = node.nWinsA.float / node.nVisits.float
    if fracAWin >= 0.5:
        let alpha = (fracAWin - 0.5) * 2
        result = alpha * Awinning + (1-alpha) * Nwinning
    else:
        let alpha = (0.5 - fracAwin) * 2
        result = alpha * Bwinning + (1-alpha) * Nwinning

    var alpha = node.nVisits.float / totalVisits
    #alpha = 0.8*alpha + 0.2
    result = alpha * result + (1-alpha) * Novisited

proc show_board(forest: MCTSForest, state: State) =
    const
        white = "\e[1;37m"
        reset = "\e[0m"
    var result: string
    let b = state.board
    result = white
    result &= "   1 2 3 4 5 6 7 8 9 a b c d e f g"[0..< (b.width*2+3)]
    let pWin = forest[state].descendants.mapIt(
        forest[state.next it][]
    ).mapIt(it.winFraction(state.whoseTurn)).max
    result &= " p(win for {state.whoseTurn}) = {pwin:0.3f}".fmt
    let avgDepth = forest[state].depthSum.float / forest[state].nVisits.float
    result &= "\n" & reset
    const alpha="abcdefghijklmnopqrstuvwxyz"
    for r in uint8(0)..<b.height:
        result &= white & $alpha[r] & reset & "  "
        for c in uint8(0)..<b.width:
            if (r,c) in forest[state].descendants:
                let node = forest[state.next (r,c)]
                result &= bg(nodeToBgcolor(forest, node[], forest[state][]))
            result &= $b[(r,c)] & " "
        if r == 0:   
            result &= white & " brain strength = {forest[state].nVisits} kg".fmt
        if r == 1:
            result &= white & " futures foretold = {avgDepth:0.3f}".fmt
        result &= "\n"
    stdout.write result
    stdout.flushFile()

proc clear_board(forest: MCTSForest, state: State) =
    stdout.flushFile()
    stderr.flushFile()
    for _ in 0 ..< state.board.height.int:
        eraseLine()
        cursorUp()
    stdout.flushFile()
    stderr.flushFile()

proc mctsWithFeedback*(forest: var MCTSForest, current_state: State, n_trials: int = 100000, h: HeuristicCallable, move: LoggedMove, blockSize: int = 500): Action =
    var i=0
    var n_trials = n_trials
    while i < n_trials:
        result = forest.mcts(current_state, blockSize, h)
        if i == 0:
            stdout.write current_state.board
        else:
            eraseLine()
            cursorUp()
            clear_board(forest, current_state)
            show_board(forest, current_state)
        i += blockSize
        write(stdout, fmt "...thinking... {100.0*i.float/n_trials.float:2.1f}%")
        flushFile(stdout)

        move.logTree(forest, current_state, i)

    stdout.write("\r")
    stdout.flushFile()
    echo "Pondered to average depth of {forest[current_state].depthSum.float / forest[current_state].nVisits.float:.2f}".fmt
    dump forest[current_state][]
    var possible_actions = forest[current_state].descendants.toSeq
    for action in possible_actions:
        echo " -- ", action, "-> ", forest[current_state.next action][]
    echo "\nSelecting ", result, ": ", forest[current_state.next result][]
    move.logChosenSquare $result, n_trials


when isMainModule:
    randomize()
    var forest: MCTSForest
    var forestB: MCTSForest
    var current_state = State(
        board: board(9,9),
        whoseTurn: Player.A,
        capturesToMake: 1
    )
    #for loc in [(10, 1)]:
    #    current_state.board[loc] = Cell.LiveA
    #for loc in [(0, 9), (1,8), (2,7)]:
    #    current_state.board[loc] = Cell.LiveB

    var game = logGame(current_state,
    "A: slow heuristic and slow rollout, B: fast select heuristic and fast rollout"
    )

    #echo "You're player ", Cell.LiveB
    #if current_state.whoseTurn == Player.B:
    #    echo "You have the first move."
    var moveNum = 0
    while true:
        echo current_state
        var move = game.logMove(moveNum, current_state)
        moveNum += 1
        if current_state.isTerminal:
            echo "...but {current_state.whoseTurn} can't move!".fmt
            echo "Good game! {current_state.whoseTurn.other} wins!".fmt
            game.logWinner current_state.whoseTurn.other
            break
        if current_state.whoseTurn == Player.A:
            #echo "My turn!"
            var best_action = forest.mctsWithFeedback(
                current_state,
                100000,
                heuristic,
                move,
            )
            current_state = current_state.next best_action
        else:
            #echo "Your turn!"
            #var loc = current_state.board.readLocFromStdin(Player.B)
            #current_state = current_state.next loc
            var best_action = forestB.mctsWithFeedback(
                current_state,
                100000,
                fastHeuristic,
                move,
            )
            current_state = current_state.next best_action