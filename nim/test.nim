import unittest
import bitmask
import sequtils
import sets

suite "Bitmask":

  setup:
    var bm: Bitmask
    var bmA, bmB: Bitmask
    bmA[5] = 0xfa0a'u16
    bmB[5] = 0x020f'u16

  test "begins empty":
    check bm.len == 0
    for i in bm.low..bm.high:
      check bm[i] == 0'u16

  test "can't be indexed out of bounds":
    expect(IndexDefect):
      echo bm[5, 19]

  test "can be changed":
    bm[3, 5] = true
    bm[5, 9] = true

    check bm[3,5] == true
    check bm[5,9] == true
    check bm[3] == 0b0000010000000000
    check bm[5] == 0b0000000001000000
    check bm.len == 2

  test "dilate":
    bm[3, 5] = true
    bm[5, 9] = true
    bm.dilate
    check bm[2] == 0b0000111000000000
    check bm[3] == 0b0000111000000000
    check bm[4] == 0b0000111011100000
    check bm[5] == 0b0000000011100000
    check bm[6] == 0b0000000011100000
    bm.dilate
    check bm[1] == 0b0001111100000000
    check bm[2] == 0b0001111100000000
    check bm[3] == 0b0001111111110000
    check bm[4] == 0b0001111111110000
    check bm[5] == 0b0001111111110000
    check bm[6] == 0b0000000111110000
    check bm[7] == 0b0000000111110000
    check bm.len == 47
    for _ in 0..100:
      bm.dilate
    for i in 0..bm.high:
      check bm[i] == 0xffff

  test "unions, intersections, subtractions work":
    bm.setUnion bmA
    bm.setIntersect bmB
    check bmA.len == 8
    check bmB.len == 5
    check bm[5] == 0x020a'u16
    check bm.len == 3

    bm[5] = 0
    bm.setUnion bmA
    bm.setSubtract bmB
    check bm[5] == 0xf800

  test "can be iterated over":
    bm[2,3] = true
    bm[5,9] = true
    # array iteration
    check bm.toSeq == @[(2'u8,3'u8), (5'u8,9'u8)]
    # index iteration
    for i in 0..bm.high:
      case i:
      of 2: check bm[2] == 0x1000
      of 5: check bm[5] == 0x0040
      else: check bm[i] == 0

  test "floodfill":
    var bmMask, bmSources: Bitmask
    bmMask[3] =    0b0000011000000000
    bmMask[4] =    0b1111110001111000
    bmMask[5] =    0b1111110001111000
    bmMask[6] =    0b0000000000000000
    bmSources[3] = 0b0000000000000010
    bmSources[4] = 0b0000000000000010
    bmSources[5] = 0b0000000000000010
    bmSources[6] = 0b0000100000000000
    bm = floodFill(bmSources, bmMask)
    check bm[3] == 0b0000011000000010
    check bm[4] == 0b1111110000000010
    check bm[5] == 0b1111110000000010
    check bm[6] == 0b0000100000000000

    # Longgggg winding path, notably longer than the size of the bitmask
    bmMask[3] =    0b1111111111111110
    bmMask[4] =    0b0000000000000001
    bmMask[5] =    0b1111111111111111
    bmMask[6] =    0b1000000000000000
    bmMask[7] =    0b1111111111111101
    bmSources[3] = 0b0000000000000001
    bmSources[4] = 0b0000000000000000
    bmSources[5] = 0b0000000000000000
    bmSources[6] = 0b0000000000000000
    bmSources[7] = 0b0000000000000000
    bm = floodFill(bmSources, bmMask)
    check bm[3] == 0b1111111111111111
    check bm[4] == 0b0000000000000001
    check bm[5] == 0b1111111111111111
    check bm[6] == 0b1000000000000000
    check bm[7] == 0b1111111111111100

  test "random samples":
    var testSet: HashSet[(uint8, uint8)]
    bm[3,5] = true
    bm[5,9] = true
    bm[2,12] = true
    for i in 0..100:
      testSet.incl bm.sample
    check testSet == toHashSet [(3'u8, 5'u8), (5'u8, 9'u8), (2'u8, 12'u8)]

    var bm2: Bitmask
    bm2[2,2] = true
    for i in 0..100:
      check bm2.sample == (2'u8, 2'u8)

    var bm3: Bitmask
    expect(AssertionDefect):
      discard bm3.sample
