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
import tables
import bitmask

const 
    maxSize* = 16
    maxLocDeque* = 195
type 
  Cell* = enum
    # convention: when B captures a LiveA cell, it becomes a LockedB cell
    Empty = "\e[1;37m·\e[0m"
    LiveA = "\e[1;31mA\e[0m"
    LockedA = "\e[3;31ma\e[0m"
    LiveB = "\e[1;32mB\e[0m"
    LockedB = "\e[3;32mb\e[0m"
    Invalid = "!"
  Player* = enum A, B
proc `~>`*(c: Cell, t: Player): Cell =
    if (c,t) == (Cell.Empty, Player.A): Cell.LiveA
    elif (c,t) == (Cell.Empty, Player.B): Cell.LiveB
    elif (c,t) == (Cell.LiveA, Player.B): Cell.LockedB
    elif (c,t) == (Cell.LiveB, Player.A): Cell.LockedA
    else: Cell.Invalid
proc ownedByA*(c:Cell): bool = (c == Cell.LiveA or c == Cell.LockedA)
proc ownedByB*(c:Cell): bool = (c == Cell.LiveB or c == Cell.LockedB)
proc ownedBy*(t: Player): (Cell)->bool =
    case t:
    of Player.A: ownedByA
    of Player.B: ownedByB
proc ownedBy*(c: Cell, t: Player): bool = ownedBy(t)(c)
proc isLive*(c: Cell): bool = (c == Cell.LiveA or c== Cell.LiveB)
proc isLocked*(c: Cell): bool = (c == Cell.LockedA or c == Cell.LockedB)
proc isValid*(c: Cell): bool = (c in [Cell.Empty, Cell.LiveA, Cell.LiveB, Cell.LockedA, Cell.LockedB])
proc other*(t: Player):Player =
     if t==Player.A: Player.B
     else: Player.A
proc isCapturableBy*(c: Cell, p: Player): bool =
    c.isLive and c.ownedBy(p.other) or c == Cell.Empty

type
  Loc* = tuple
    r: uint8
    c: uint8
  # Cells change ownership.
  Board* = object
    width*: uint8
    height*: uint8
    
    liveA: Bitmask
    liveB: Bitmask
    lockedA: Bitmask
    lockedB: Bitmask

proc `[]`*(b: Board, r: Loc): Cell {.inline.} =
    if b.lockedA[r.r, r.c]: Cell.LockedA
    elif b.lockedB[r.r, r.c]: Cell.LockedB
    elif b.liveA[r.r, r.c]: Cell.LiveA
    elif b.liveB[r.r, r.c]: Cell.LiveB
    else: Cell.Empty
proc `[]`*(b:Board, r:uint8, c:uint8): Cell {.inline.} = b[(r,c)]
proc `[]=`*(b: var Board, r: Loc, v:Cell) {.inline.} =
    b.liveA[r.r, r.c] = (v == Cell.LiveA)
    b.lockedA[r.r, r.c] = (v == Cell.LockedA)
    b.liveB[r.r, r.c] = (v == Cell.LiveB)
    b.lockedB[r.r, r.c] = (v == Cell.LockedB)
proc `[]=`*(b: var Board, r: uint8, c:uint8, v:Cell) {.inline.} =
    b[(r,c)] = v
proc `[]=`*(b: var Board, r: int, c:int, v:Cell) {.inline.} =
    b[(r.uint8,c.uint8)] = v
proc `[]=`*(b: var Board, loc: (int, int), v:Cell) {.inline.} =
    b[loc[0], loc[1]] = v
proc `$`*(b: Board): string =
    const
        white = "\e[1;37m"
        reset = "\e[0m"
    result = white
    result &= "   1 2 3 4 5 6 7 8 9 a b c d e f g"[0..< (b.width*2+3)]
    result &= "\n" & reset
    const alpha="abcdefghijklmnopqrstuvwxyz"
    for r in uint8(0)..<b.height:
        result &= white & $alpha[r] & reset & "  "
        for c in uint8(0)..<b.width:
            result &= $b[r, c] & " "
        result &= "\n"
proc `$`*(l: Loc): string =
    "abcdefghijklmnopqrstuvwxyz"[l.r] & "123456789abcdefg"[l.c]
proc `+`*(a: Loc, b: Loc): Loc {.inline.} =
    return (a.r+b.r, a.c+b.c)
proc `+`*(a: Loc, b: (int, int)): Loc {.inline.} =
    return (a.r+uint8(b[0]), a.c+uint8(b[1])) # two's complement?
proc contains*(b: Board, c: Loc): bool {.inline.} =
    result = (c.r >= 0 and c.r < b.height and
              c.c >= 0 and c.c < b.width)
proc board*(width: uint8, height: uint8): Board =
    var board = Board(
        width: width,
        height: height
    )
    board[0,width-1] = Cell.LiveB
    board[height-1, 0] = Cell.LiveA
    return board
iterator items*(b:Board): Loc {.inline.} =
    for r in 0'u8..<b.width:
        for c in 0'u8..<b.height:
            yield (r.uint8,c.uint8)

proc liveCellsFor*(board: Board, player: Player): Bitmask {.inline.} =
    case player:
    of Player.A: board.liveA
    of Player.B: board.liveB
proc lockedCellsFor*(board: Board, player: Player): Bitmask {.inline.} =
    case player:
    of Player.A: board.lockedA
    of Player.B: board.lockedB

proc possibleMovesFor*(board: Board, player: Player): Bitmask =
    let deadCells = board.lockedCellsFor player
    let liveCells = board.liveCellsFor player
    let otherDeadCells = board.lockedCellsFor player.other
    # tmp represents whichever cells border live groups
    result = floodFill(sources = liveCells, mask = deadCells)
    # once we find a fixpoint, we can be done
    result.dilate
    result.setSubtract liveCells
    result.setSubtract deadCells
    result.setSubtract otherDeadCells
    result.clipSize(board.width, board.height)
    


when isMainModule:
    randomize()
    var
        total_steps = 0
        depths: seq[int]
        choices: seq[int]
        n_trials = 2500
    for trial in 0..<n_trials:
        var
            b2 = board(9,9)
            max_depth = 900
            player = Player.A
        for depth in 0..<max_depth:
            total_steps += 1
            var moves = b2.possibleMovesFor(player)
            choices.add moves.len
            if moves.len == 0:
                depths.add depth
                if trial mod 100 == 0:
                    echo "Trial ", trial, " resulting in depth ", depth
                break
            var move = moves.sample
            b2[move] = b2[move] ~> player
            player = player.other

    echo "Done"
    echo total_steps