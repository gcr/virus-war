import mcts
import tables
import sugar
import options
import sequtils
import re
import random
import sets

type Strategy* = ref object of RootObj
    tag*: string
    description*: string
    selectOnRandom*: bool = false

type StrategyMoveCallback* = (n_playouts: int) -> void

proc noCallback*(n_playouts: int) = discard

method nextMove*(strat: Strategy, currentState: State, cb: StrategyMoveCallback): Action {.base.} =
    discard

################################################################################
## MCTS Strategies
type MCTSStrategy* = ref object of Strategy
    selectHeuristic*: HeuristicCallable
    rolloutHeuristic*: HeuristicCallable
    stoppingCriterion*: StoppingCriterion
    cParam*: float = 1.0
    useLogScoreVisitHeuristicNormalization*: bool = false
    finalSelection*: FinalSelectHeuristicCallable = mostVisitedNode
    forest*: MCTSForest

method nextMove*(
        strat: MCTSStrategy,
        currentState: State,
        cb: StrategyMoveCallback = noCallback,
        ): Action =
    const blockSize = 100
    var i = 0
    while not strat.stoppingCriterion(strat.forest, currentState, i):
        for j in 0 ..< blockSize:
            let selectedState = strat.forest.selectAndExpand(
                currentState,
                strat.selectHeuristic,
                strat.cParam,
                strat.useLogScoreVisitHeuristicNormalization
            )
            strat.forest.rollout(selectedState, strat.rolloutHeuristic)
            i += 1
        cb(i)
    strat.finalSelection(strat.forest, currentState)


var STRATEGY_REGISTRY: seq[Strategy]
proc register*(strategy: Strategy) =
    for other in STRATEGY_REGISTRY:
        if strategy.tag == other.tag:
            raise newException(ValueError, "Duplicate tag")
        if strategy.description != "" and strategy.description == other.description:
            raise newException(ValueError, "Duplicate description")
    STRATEGY_REGISTRY.add strategy

proc getStrategy*(tag: string): Option[Strategy] =
    var matches = STRATEGY_REGISTRY.filterIt(
        find(it.tag, re(tag)) != -1
    )
    if matches.len == 1:
        # Player wants this one,
        # can select it by commandline arg
        return some(matches[0])
    # Else: select some random one
    matches = matches.filterIt(it.selectOnRandom)
    if matches.len > 0:
        return some(matches.sample)

proc strategies*(): HashSet[string] = STRATEGY_REGISTRY.mapIt(it.tag).toHashSet
