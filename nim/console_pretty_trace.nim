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
import argmax
import gameLog

type ConsoleOutput* = object
    isFirst*: bool = true
    nPlayouts*: int = 0
    message*: string = "...thinking..."


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
    var bestAction = (255'u8, 255'u8)
    if state in forest:
        bestAction = argmax(a, forest[state].descendants):
          forest[state.next a].nVisits
        let pWin = forest[state].descendants.mapIt(
            forest[state.next it][]
        ).mapIt(it.winFraction(state.whoseTurn)).max
        result &= " p(win for {state.whoseTurn}) = {pwin:0.3f}".fmt
    result &= "\n" & reset
    const alpha="abcdefghijklmnopqrstuvwxyz"
    for r in uint8(0)..<b.height:
        result &= white & $alpha[r] & reset & "  "
        for c in uint8(0)..<b.width:
            if state in forest:
                if (r,c) in forest[state].descendants:
                    let node = forest[state.next (r,c)]
                    result &= bg(nodeToBgcolor(forest, node[], forest[state][]))
            result &= $b[(r,c)]
            if (r,c) == best_action:
                result &= white & "<"
            else:
                result &= " "
        if state in forest:
            if r == 0:
                result &= white & " brain strength = {forest[state].nVisits} kg".fmt
            if r == 1:
                let avgDepth = forest[state].depthSum.float / forest[state].nVisits.float
                result &= white & " futures foretold = {avgDepth:0.3f}".fmt
        result &= "\n"
    result &= $state & "\n"
    stderr.write result
    stderr.flushFile()

proc clear_board(forest: MCTSForest, state: State) =
    stdout.flushFile()
    stderr.flushFile()
    for _ in 0 ..< state.board.height.int:
        eraseLine()
        cursorUp()
    stdout.flushFile()
    stderr.flushFile()


proc show*(
        console: var ConsoleOutput,
        forest: var MCTSForest,
        playouts: int,
        state: State,
        ) =
    console.nPlayouts = playouts
    if console.isFirst:
        show_board(forest, state)
        console.isFirst = false
    else:
        eraseLine()
        cursorUp()
        eraseLine()
        cursorUp()
        clearBoard(forest, state)
        showBoard(forest, state)
    stderr.write "{console.message} {playouts.float / 1000.0:.1f}k playouts... ".fmt
    flushFile(stdout)

proc done*(
        console: var ConsoleOutput,
        forest: var MCTSForest,
        state: State,
        action: Action,
        ) =
    console.isFirst = true
    stderr.write("\r")
    stderr.flushFile()
    stderr.write "Pondered to average depth of {forest[state].depthSum.float / forest[state].nVisits.float:.2f}\n".fmt
    stderr.write $forest[state][] & "\n"
    var possible_actions = forest[state].descendants.toSeq
    for aa in possible_actions:
        stderr.write " - {aa} -> {forest[state.next aa][]}\n".fmt
    stderr.write "Selecting {action} -> {forest[state.next action][]}\n".fmt
    stderr.flushFile()

proc mctsWithFeedback*(forest: var MCTSForest, current_state: State, n_trials: int = 100000, h: HeuristicCallable, move: LoggedMove, blockSize: int = 500): Action =
    var i=0
    var n_trials = n_trials
    var console = ConsoleOutput()
    while i < n_trials:
        console.show(forest, i, current_state)
        result = forest.mcts(current_state, blockSize, h)
        i += blockSize

        move.logTree(forest, current_state, i)
    console.done(forest, current_state, result)

    move.logChosenSquare $result


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
                optionsDiffHeuristic,
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