import system/iterators

template argmax*(sym: untyped, arr: untyped, scoreBody: untyped): untyped =
    when compiles(typeof(arr[0])):
        var sym: typeof(arr[0])
    else:
        var sym: typeof(arr, typeOfIter)
    var bestScore = typeof(scoreBody).low
    var bestElt: typeof(sym)
    for sym in arr:
        let score = scoreBody
        if score > bestScore:
            bestScore = score
            bestElt = sym
    bestElt



when isMainModule:
    iterator foo(): int =
        yield 60
        yield 1
        yield 99
        yield 32
    let myArr = [60, 1, 99, 32]
    let foobar = argmax(x, myArr):
        var y: int
        for i in 0..x:
            y -= 1
        -y
    echo foobar
    let foobar2 = argmax(z, foo()):
        var w: int
        for i in 0..z:
            w -= 1
        -w
    echo foobar2