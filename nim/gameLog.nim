import sugar
import strutils
import norm/[model, sqlite, pragmas]
import times
import tables
import os
import random

import std/[options, logging]
import main
import mcts
addHandler newConsoleLogger(fmtStr = "")


type
    LoggedGame* {.tableName: "games".} = ref object of Model
        boardSize*: int
        date*: int
        winner*: string
        descA*: string
        descB*: string


    LoggedMove* {.tableName: "moves".} = ref object of Model
        game*: LoggedGame
        moveNum*: int
        board*: string
        chosenSquare*: string
        player*: string
        time*: float
        thinkDuration*: float

    LoggedTreeSearch* {.tableName: "treeSearches".} = ref object of Model
        ## Each move has several tree objects, at least
        ## one for each root of the child
        move*: LoggedMove
        playouts*: int

        thisNodeDepth*: int
        averageDepthFromHere*: float

        cell*: string
        nVisits*: int
        nWinsA*: int
        nWinsB*: int



sleep(int(rand(1000.0)))
var dbConn* = open("game-log.sqlite", "", "", "")
dbConn.exec(sql("PRAGMA busy_timeout = 2500"))
dbConn.exec(sql("PRAGMA journal_mode = WAL"))

dbConn.createTables(LoggedTreeSearch(move: LoggedMove(game: LoggedGame())))

proc logGame*(state: State, descA, descB: string): LoggedGame =
    result = LoggedGame(
        boardSize: state.board.width.int,
        date: getTime().toUnix,
        winner: "",
        descA: descA,
        descB: descB,
    )
    dbConn.insert result

proc dumpBoard(board: Board): string =
    for r in 0'u8..<board.height:
        for c in 0'u8..<board.width:
            case board[(r,c)]:
                of Cell.LiveA: result &= "A"
                of Cell.LiveB: result &= "B"
                of Cell.LockedA: result &= "a"
                of Cell.LockedB: result &= "b"
                of Cell.Empty: result &= "."
                of Cell.Invalid: result &= "!"
        result &= "\n"


proc logMove*(game: LoggedGame, moveNum: int, state: State): LoggedMove =
    result = LoggedMove(
        game: game,
        moveNum: moveNum,
        board: dumpBoard(state.board),
        chosenSquare: "",
        player: if state.whoseTurn == Player.A: "A" else: "B",
        time: getTime().toUnixFloat(),
    )
    dbConn.insert result

proc logChosenSquare*(move: LoggedMove, chosen: string) =
    var newMove = move
    newMove.chosenSquare = chosen
    newMove.thinkDuration = getTime().toUnixFloat() - newMove.time
    dbConn.update newMove

proc logWinner*(game: var LoggedGame, winner: Player) =
    game.winner = $winner
    dbConn.update game

proc logTree*(move: LoggedMove, forest: MCTSForest, state: mcts.State, playoutNum: int) =
    for action in forest[state].descendants:
        if state.next(action) notin forest:
            continue
        var nextNode: MCTSNode = forest[state.next action][]
        var tree = LoggedTreeSearch(
            move: move,
            playouts: playoutNum,

            thisNodeDepth: 0,
            averageDepthFromHere: forest.avgDepth(nextNode),
            cell: $action,
            nVisits: nextNode.nVisits.int,
            nWinsA: nextNode.nWinsA.int,
            nWinsB: nextNode.nWinsB.int,
        )
        dbConn.insert tree