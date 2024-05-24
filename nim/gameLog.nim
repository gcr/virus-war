import sugar
import strutils
import norm/[model, sqlite, pragmas]
import times
import tables
import os
import random
import sets
import sequtils
import std/[options, logging]
import board
import mcts
import algorithm
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
dbConn.exec(sql("""
create view if not exists winners (id, winner, loser) as
select id, descA, descB from games where winner=='A'
union all
select id, descB, descA from games where winner=='B';
"""))
dbConn.exec(sql("""
create view if not exists methods as
select descA method from games union select descB from games;
"""))

# Add a view
dbConn.exec(sql("""
create view if not exists matchup_counts as
with normalized_contestants as (
    select iif(winner >= loser, winner, loser) a,
    iif(winner >= loser, loser, winner) b
    from winners
),
methodPairs as (
    select m1.method a, m2.method b from methods m1 join methods m2 where a >= b
),
occurrences as (
    select a, b, count(*) c from normalized_contestants group by a,b
)
select mp.a, mp.b, coalesce(o.c, 0) count from methodPairs mp left join occurrences o on (mp.a == o.a and mp.b == o.b) order by count;
"""))

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

proc getUncommonMatchup*(): (string, string) =
    type M = object
      a: string
      b: string
      count: int
    var results: seq[ref M]
    let methods = getMCTSTags()
    results.add new M
    dbConn.rawSelect(("select a, b, count from matchup_counts order by count"), results)
    echo "Getting uncommon matchup"
    results = results.filterIt(
        it.a in methods and it.b in methods
    )
    # Sometimes we may have a new method for us
    # but isn't reflected in the sqlite table.
    # We'll have to populate all pairs ourselves.
    var counts: CountTable[(string, string)]
    for i in methods:
        for j in methods:
            if i < j:
                counts[(i,j)] = 1
    for r in results:
        if r.a < r.b:
            counts.inc (r.a,r.b), r.count
        else:
            counts.inc (r.b,r.a), r.count
        echo r[]
    let (pair, c) = counts.pairs.toSeq.sortedByIt(it[1])[0..<20].sample
    echo counts
    echo "Selected ", pair
    echo counts[pair]
    if rand(1.0) > 0.5:
        return pair
    else:
        return (pair[1], pair[0])
