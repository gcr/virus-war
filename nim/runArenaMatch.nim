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
import strategyUtils
import norm/[model, sqlite, pragmas]
import sets
import simpleStrategies
import algorithm

proc getUncommonMatchup*(): (string, string) =
    type M = object
      a: string
      b: string
      count: int
    var results: seq[ref M]
    let methods = strategies()
    results.add new M
    dbConn.rawSelect(("select a, b, count from matchup_counts order by count"), results)
    echo "Getting uncommon matchup"
    results = results.filterIt(it.a in methods and it.b in methods)
    # Sometimes we may have a new method for us
    # but isn't reflected in the sqlite table.
    # We'll have to populate all pairs ourselves.
    var counts: CountTable[(string, string)]
    for i in methods:
        for j in methods:
            if get(getStrategy(i)).selectOnRandom and get(getStrategy(j)).selectOnRandom:
                if i < j:
                    counts[(i,j)] = 1
    for r in results:
        if get(getStrategy(r.a)).selectOnRandom and get(getStrategy(r.b)).selectOnRandom:
            if r.a < r.b:
                counts.inc (r.a,r.b), r.count
            else:
                counts.inc (r.b,r.a), r.count
            #echo r[]
    let (pair, c) = counts.pairs.toSeq.sortedByIt(it[1])[0..<min(counts.len, 20)].sample
    echo "Counts"
    echo counts
    echo "Selected ", pair
    echo counts[pair]
    if rand(1.0) > 0.5:
        return pair
    else:
        return (pair[1], pair[0])

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
        strat_A = get(getStrategy A)
        strat_B = get(getStrategy B)
        currentState = State(
            board: board(size.uint8, size.uint8),
            whoseTurn: if rand(1.0) > 0.5: Player.A else: Player.B,
            capturesToMake: 1
        )
        strats = [Player.A: strat_A, Player.B: strat_B]
        nMoves = 0
    echo strat_A[]
    echo strat_B[]
    var game = logGame(currentState, strat_A.tag, strat_B.tag)
    while not currentState.isTerminal:
        var move = game.logMove(nMoves, currentState)
        nMoves += 1
        let p = currentState.whoseTurn
        let bestAction = nextMove(strats[p], currentState, proc(n_playouts: int) =
            if strats[p] of MCTSStrategy:
                move.logTree(MCTSStrategy(strats[p]).forest, currentState, n_playouts)
                console.show(MCTSStrategy(strats[p]).forest, currentState, n_playouts)
        )
        if strats[p] of MCTSStrategy:
            console.done(MCTSStrategy(strats[p]).forest, currentState, bestAction)
        currentState = currentState.next bestAction
        echo currentState.board
        echo currentState
        move.logChosenSquare($bestAction)
    echo currentState
    game.logWinner(currentState.whoseTurn.other)

when isMainModule:
    import cligen; dispatch runMatch