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

type 
  Cell = enum 
    # convention: when B captures a LiveA cell, it becomes a LockedB cell
    Empty = "\e[1;37m.\e[0m"
    LiveA = "\e[1;31mA\e[0m"
    LockedA = "\e[3;31ma\e[0m"
    LiveB = "\e[1;32mB\e[0m"
    LockedB = "\e[3;32mb\e[0m"
    Invalid = "!"
  Player = enum A, B
  Loc = tuple
    r: uint8
    c: uint8
  # Cells change ownership.
  Board* = object
    width: uint8
    height: uint8
    board: seq[Cell]
  LocSet = set[uint16]
  LocDeque = object
    data: array[81, Loc]
    first: int16 = 0
    last: int16 = 0
    

# Sets of locations
proc ravel(l: Loc): uint16 = uint16(l.r) * 16 + uint16(l.c)
proc hash(l: Loc): Hash = l.r.int * 16 + l.c.int
proc incl(lset: var LocSet, l: Loc) = lset.incl l.ravel
proc contains(lset: var LocSet, l: Loc): bool = l.ravel in lset

# Small queue of locations
proc len(ld: LocDeque): int = ld.last - ld.first
proc popFirst(ld: var LocDeque): Loc =
    result = ld.data[ld.first]
    ld.first += 1
proc addLast(ld: var LocDeque, l: Loc) =
    ld.data[ld.last] = l
    ld.last += 1
proc makeDeque(arr: seq[Loc]): LocDeque =
    var ld = LocDeque(data: arrayWith((255'u8, 255'u8), 81),
                      first: 0,
                      last: 0)
    for x in arr:
        ld.addLast x
    return ld


proc `~>`(c: Cell, t: Player): Cell =
    if (c,t) == (Cell.Empty, Player.A): Cell.LiveA
    elif (c,t) == (Cell.Empty, Player.B): Cell.LiveB
    elif (c,t) == (Cell.LiveA, Player.B): Cell.LockedB
    elif (c,t) == (Cell.LiveB, Player.A): Cell.LockedA
    else: Cell.Invalid
proc ownedByA(c:Cell): bool = (c == Cell.LiveA or c == Cell.LockedA)
proc ownedByB(c:Cell): bool = (c == Cell.LiveB or c == Cell.LockedB)
proc ownedBy(t: Player): (Cell)->bool =
    case t:
    of Player.A: ownedByA
    of Player.B: ownedByB
proc ownedBy(c: Cell, t: Player): bool = ownedBy(t)(c)
proc isLive(c: Cell): bool = (c == Cell.LiveA or c== Cell.LiveB)
proc isLocked(c: Cell): bool = (c == Cell.LockedA or c == Cell.LockedB)
proc isValid(c: Cell): bool = (c in [Cell.Empty, Cell.LiveA, Cell.LiveB, Cell.LockedA, Cell.LockedB])
proc other(t: Player):Player =
     if t==Player.A: Player.B
     else: Player.A
proc isCapturableBy(c: Cell, p: Player): bool =
    c.isLive and c.ownedBy(p.other) or c == Cell.Empty

proc `[]`(b: Board, r: Loc): Cell =
    b.board[r.r*b.width + r.c]
proc `[]=`(b: var Board, r: Loc, v:Cell) =
    b.board[r.r*b.width + r.c] = v
proc `[]=`(b: var Board, r: uint8, c:uint8, v:Cell) =
    b[(r,c)] = v
proc `$`(b: Board): string =
    for r in uint8(0)..<b.height:
        result &= join(b.board[r*b.width ..< (r+1)*b.width], " ")
        result &= "\n"
proc `+`(a: Loc, b: Loc): Loc =
    return (a.r+b.r, a.c+b.c)
proc `+`(a: Loc, b: (int, int)): Loc =
    return (a.r+uint8(b[0]), a.c+uint8(b[1])) # two's complement?
proc contains(b: Board, c: Loc): bool =
    result = (c.r >= 0 and c.r < b.height and
              c.c >= 0 and c.c < b.width)
proc board(width: uint8, height: uint8): Board =
    var board = Board(
        width: width,
        height: height,
        board: (uint8(0)..<width * height).mapIt(Cell.Empty)
    )
    board[0,width-1] = Cell.LiveB
    board[height-1, 0] = Cell.LiveA
    return board
iterator neighbors(board: Board, c: Loc): Loc =
    for dc in [-1, 0, 1]:
        for dr in [-1,0,1]:
            if dr != 0 or dc != 0:
                if c+(dr,dc) in board:
                    yield c+(dr,dc)
#iterator neighbors(board: Board, c: Loc): Loc =
#    if c+(-1,-1) in board: yield c+(-1, -1)
#    if c+(-1, 0) in board: yield c+(-1,  0)
#    if c+(-1, 1) in board: yield c+(-1,  1)
#    if c+( 0,-1) in board: yield c+( 0, -1)
#    if c+( 0, 0) in board: yield c+( 0,  0)
#    if c+( 0, 1) in board: yield c+( 0,  1)
#    if c+( 1,-1) in board: yield c+( 1, -1)
#    if c+( 1, 0) in board: yield c+( 1,  0)
#    if c+( 1, 1) in board: yield c+( 1,  1)
iterator items(b:Board): Loc =
    for r in 0'u8..<b.width:
        for c in 0'u8..<b.height:
            yield (r.uint8,c.uint8)
iterator liveCellGroups(board: Board, t: Player): Loc =
    #pred: (Cell)->bool, horizon: var Deque[Loc]): Loc =
    var seen: LocSet
    var horizon: Deque[Loc]
    var addedToHorizon: LocSet
    for loc in board:
     if board[loc].isLive and board[loc].ownedBy t:
        horizon.addLast loc
        addedToHorizon.incl loc

    while horizon.len > 0:
        let
            loc: Loc = horizon.popFirst
            cell = board[loc]
        if loc notin seen and cell.ownedBy t:
            yield loc
            for n in board.neighbors(loc):
                if n notin seen and n notin addedToHorizon:
                    horizon.addLast n
                    addedToHorizon.incl n
        seen.incl loc

iterator possibleMovesFor(board: Board, player: Player): Loc =
    var seen: LocSet
    for loc in board.liveCellGroups player:
        seen.incl loc
        for neighbor in board.neighbors loc:
            if neighbor notin seen:
                if board[neighbor].isCapturableBy player:
                    yield neighbor
            seen.incl neighbor
    
proc withPlay(b: Board, loc: Loc, player: Player): Board =
    var newBoard:Board = b
    newBoard[loc] = newBoard[loc] ~> player
    return newBoard

#iterator liveCells(board: Board, player: Player): Loc =
#    var seen: HashSet[Loc]
#    var horizon: seq[Loc]
#    for cref in board:
        #if cref.isLive and cref.ownedBy player:

if true:
    randomize()
    var
        depths: seq[int]
        choices: seq[int]
        n_trials = 2500
    for trial in 0..<n_trials:
        var
            b2 = board(9,9)
            max_depth = 900
            player = Player.A
        for depth in 0..<max_depth:
            #echo trial, ", ", depth
            #echo b2
            #echo "Cell groups for A: ", b2.liveCellGroups(Player.A).toSeq
            #echo "Cell groups for B: ", b2.liveCellGroups(Player.B).toSeq
            var moves = b2.possibleMovesFor(player).toSeq
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