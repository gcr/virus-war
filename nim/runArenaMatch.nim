import board
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
import fancy_console_output
import gameLog
import mcts_library

proc runMatch(A_strategy="", B_strategy="", size=9) =
    randomize()
    var A=A_strategy
    var B=B_strategy
    if A == "" and B == "":
        (A, B) = getUncommonMatchup()
        dump A
        dump B
    var
        console = ConsoleOutput()
        strat_A = get(getMCTSStrategy A)
        forest_A: MCTSForest
        strat_B = get(getMCTSStrategy B)
        forest_B: MCTSForest
        currentState = State(
            board: board(size.uint8, size.uint8),
            whoseTurn: if rand(1.0) > 0.5: Player.A else: Player.B,
            capturesToMake: 1
        )
        strats = [Player.A: strat_A, Player.B: strat_B]
        forests = [Player.A: forest_A, Player.B: forest_B]
        nMoves = 0
    echo strat_A
    echo strat_B
    var game = logGame(currentState, strat_A.tag, strat_B.tag)
    while not currentState.isTerminal:
        var move = game.logMove(nMoves, currentState)
        nMoves += 1
        let p = currentState.whoseTurn
        let bestAction = mcts(strats[p], forests[p], currentState, cb=proc (i:int) =
            console.show(forests[p], i, currentState)
            move.logTree(forests[p], currentState, i)
        )
        console.done(forests[p], currentState, bestAction)
        currentState = currentState.next bestAction
        echo currentState.board
        move.logChosenSquare($bestAction)
    echo currentState
    game.logWinner(currentState.whoseTurn.other)

when isMainModule:
    import cligen; dispatch runMatch