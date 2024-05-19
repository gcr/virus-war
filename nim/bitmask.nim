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
import neon

type Bitmask* = array[16, uint16]
const nBits = sizeof(uint16) * 8

proc `$`*(bm: Bitmask): string =
    for row in bm:
        var row = row.reverseBits
        for c in 0 ..< nBits:
            result &= $bitand(row, 1)
            row = row shr 1
        result &= "\n"

proc hash*(bm: Bitmask): Hash =
    var hsh = 0
    for row in bm:
        hsh *= 5
        hsh += row.int
    return hsh.hash

{.push inline, checks: off.}
#{.push.}
proc `[]`*(bm: Bitmask, r: uint8, c: uint8): bool =
    return bm[r].shr(nBits-1 - c).bitand(1) == 1
proc `[]`*(bm: Bitmask, r: int, c: int): bool = bm[r.uint8, c.uint8]
proc `[]=`*(bm: var Bitmask, r: uint8, c: uint8, v: bool) =
    if v:
        bm[r].setBit(nBits-1 - c)
    else:
        bm[r].clearBit(nBits-1 - c)

proc setUnion*(bm: var Bitmask, other: Bitmask) =
    #for i in 0..bm.high:
    #    bm[i] = bitor(bm[i], other[i])
    var vec1A: uint8x16 = vld1q_u8(addr bm[0])
    var vec1B: uint8x16 = vld1q_u8(addr bm[8])
    var vec2A: uint8x16 = vld1q_u8(addr other[0])
    var vec2B: uint8x16 = vld1q_u8(addr other[8])
    vec1A = vorrq_u8(vec1A, vec2A)
    vec1B = vorrq_u8(vec1B, vec2B)
    vst1q_u8(addr bm[0], vec1A)
    vst1q_u8(addr bm[8], vec1B)


proc setIntersect*(bm: var Bitmask, other: Bitmask) =
    #for i in 0..bm.high:
    #    bm[i] = bitand(bm[i], other[i])
    var vec1A: uint8x16 = vld1q_u8(addr bm[0])
    var vec1B: uint8x16 = vld1q_u8(addr bm[8])
    var vec2A: uint8x16 = vld1q_u8(addr other[0])
    var vec2B: uint8x16 = vld1q_u8(addr other[8])
    vec1A = vandq_u8(vec1A, vec2A)
    vec1B = vandq_u8(vec1B, vec2B)
    vst1q_u8(addr bm[0], vec1A)
    vst1q_u8(addr bm[8], vec1B)
proc setSubtract*(bm: var Bitmask, other: Bitmask) =
    #for i in 0..bm.high:
    #    bm[i] = bitand(bm[i], bitxor(0xffff'u16, other[i]))
    var vec1A: uint8x16 = vld1q_u8(addr bm[0])
    var vec1B: uint8x16 = vld1q_u8(addr bm[8])
    var vec2A: uint8x16 = vld1q_u8(addr other[0])
    var vec2B: uint8x16 = vld1q_u8(addr other[8])
    vec1A = vbicq_u8(vec1A, vec2A)
    vec1B = vbicq_u8(vec1B, vec2B)
    vst1q_u8(addr bm[0], vec1A)
    vst1q_u8(addr bm[8], vec1B)

proc dilate*(bm: var Bitmask) =
    var vecA: uint16x8 = vld1q_u16(addr bm[0])
    var vecB: uint16x8 = vld1q_u16(addr bm[8])
    template dilateCols(x): typeof(bm[0]) = bitor(x, (x.shr 1), (x.shl 1))
    # dilate cols
    #for i in 0 .. bm.high:
    #    bm[i] = bm[i].dilateCols
    var vecAl = vshlq_n_u16(vecA, 1)
    var vecBl = vshlq_n_u16(vecB, 1)
    var vecAr = vshrq_n_u16(vecA, 1)
    var vecBr = vshrq_n_u16(vecB, 1)
    vecA = vorrq_u16(vecA, vecAl)
    vecB = vorrq_u16(vecB, vecBl)
    vecA = vorrq_u16(vecA, vecAr)
    vecB = vorrq_u16(vecB, vecBr)
    vst1q_u16(addr bm[0], vecA)
    vst1q_u16(addr bm[8], vecB)

    # dilate rows
    var prev = bm[0]
    for i in 0 .. bm.high-1:
        let tmp = bm[i]
        bm[i] = bitor(prev, bm[i], bm[i+1])
        prev = tmp
    bm[bm.high] = bitor(bm[bm.high], prev)

proc len*(bm: Bitmask): int =
    #for row in bm: result += row.popcount
    var vecA: uint8x16 = vld1q_u8(addr bm[0])
    var vecB: uint8x16 = vld1q_u8(addr bm[8])
    vecA = vcntq_u8(vecA)
    vecB = vcntq_u8(vecB)
    result += vaddvq_u8(vecA).int
    result += vaddvq_u8(vecB).int

proc clipSize*(bm: var Bitmask, width: uint8, height: uint8) =
    for r in 0'u8..<height:
        #bm[r] = bm[r].bitand((1'u16.shl(width)-1).reverseBits)
        bm[r] = bm[r].bitand(bitxor(0xffff'u16, (1'u16 shl (nBits - width) - 1)))
    for r in height.int..bm.high:
        bm[r] = 0

var COUNT_FF* = 0

proc floodFill*(sources: Bitmask, mask: Bitmask): Bitmask =
    COUNT_FF += 1
    result = sources
    var oldCount = 0
    var newCount = sources.len
    while newCount != oldCount:
        result.dilate
        result.setIntersect mask
        result.setUnion sources
        oldCount = newCount
        newCount = result.len

{.pop.}


proc sample*(bm: Bitmask): (uint8, uint8) =
    var numNonzero = 0
    for row in bm:
        if row > 0'u16:
            numNonzero+=1
    assert numNonzero > 0
    var randomRow = rand(numNonzero-1)
    for row in 0..bm.high:
        if bm[row] > 0:
            if randomRow == 0:
                # this row!
                # pick a random col (indexing from the RIGHT)
                var tmp = bm[row].reverseBits
                var randomCol = rand(tmp.popcount-1)
                while true:
                    if randomCol == 0:
                        return (row.uint8, uint8(tmp.firstSetBit - 1))
                    tmp = bitand(tmp, tmp-1)
                    randomCol -= 1
            randomRow -= 1
            
    
iterator items*(bm: Bitmask): (uint8, uint8) {.inline.} =
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
    dump b.len

    b.dilate
    echo b
    dump b.len

    b.clipSize(7, 5)
    echo b

    echo "---- Samples"
    var a: Bitmask
    a[3, 5] = true
    a[5, 7] = true
    var myset: HashSet[(uint8, uint8)]
    for i in 0..100:
        let s = b.sample
        if s notin mySet:
            mySet.incl s
    echo myset