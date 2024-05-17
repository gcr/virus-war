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
import bitops

type Bitmask = array[11, uint16]
const nBits = sizeof(uint16) * 8

proc `$`*(bm: Bitmask): string =
    for row in bm:
        var row = row.reverseBits
        for c in 0 ..< nBits:
            result &= $bitand(row, 1)
            row = row shr 1
        result &= "\n"

proc `[]`*(bm: Bitmask, r: uint8, c: uint8): bool =
    return bm[r].shr(nBits-1 - c).bitand(1) == 1
proc `[]`*(bm: Bitmask, r: int, c: int): bool = bm[r.uint8, c.uint8]
proc `[]=`*(bm: var Bitmask, r: uint8, c: uint8, v: bool) =
    if v:
        bm[r].setBit(nBits-1 - c)
    else:
        bm[r].clearBit(nBits-1 - c)

proc setUnion*(bm: var Bitmask, other: Bitmask) =
    for i in 0..bm.high:
        bm[i] = bitor(bm[i], other[i])
proc setIntersect*(bm: var Bitmask, other: Bitmask) =
    for i in 0..bm.high:
        bm[i] = bitand(bm[i], other[i])
proc setSubtract*(bm: var Bitmask, other: Bitmask) =
    for i in 0..bm.high:
        bm[i] = bitand(bm[i], bitxor(0xffff'u16, other[i]))

proc dilate*(bm: var Bitmask) =
    template dilateCols(x): typeof(bm[0]) = bitor(x, (x.shr 1), (x.shl 1))
    # dilate cols
    for i in 0 .. bm.high:
        bm[i] = bm[i].dilateCols
    # dilate rows
    var prev = bm[0]
    for i in 0 .. bm.high-1:
        let tmp = bm[i]
        bm[i] = bitor(prev, bm[i], bm[i+1])
        prev = tmp
    bm[bm.high] = bitor(bm[bm.high], prev)

proc countTrue*(bm: Bitmask): int =
    for row in bm:
        result += row.popcount

iterator items*(bm: Bitmask): (uint8, uint8) =
    for ri in 0..bm.high:
        var tmp = bm[ri].reverseBits
        while tmp > 0:
            yield(ri.uint8, uint8(tmp.firstSetBit - 1))
            tmp = bitand(tmp, tmp-1)




when isMainModule:
    var b: Bitmask
    b[5,7] = true
    b.dilate
    var c = b
    b.dilate
    b.setSubtract(c)
    b[5,7] = true
    echo b

    dump sizeof b
    for loc in b:
        echo(loc)
    dump b.countTrue

    b.dilate
    echo b
    dump b.countTrue