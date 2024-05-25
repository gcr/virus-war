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
import strategyUtils


for size in [("10k", 10000), ("50k", 50000), ("100k", 100000)]:
    let rolloutstr = size[0]
    let n_trials = size[1]
    register MCTSStrategy(
        tag:               "fastest/{rolloutstr}".fmt,
        selectHeuristic:   noHeuristic,
        rolloutHeuristic:  noHeuristic,
        stoppingCriterion: stopAtNTrials n_trials,
        selectOnRandom:    true,
    )
    register MCTSStrategy(
        tag:               "fast/{rolloutstr}".fmt,
        selectHeuristic:   fastHeuristic,
        rolloutHeuristic:  fastHeuristic,
        stoppingCriterion: stopAtNTrials n_trials,
        selectOnRandom:    true,
    )
    register MCTSStrategy(
        tag:               "od/{rolloutstr}".fmt,
        selectHeuristic:   optionsDiffHeuristic,
        rolloutHeuristic:  optionsDiffHeuristic,
        stoppingCriterion: stopAtNTrials n_trials,
        selectOnRandom:    true,
    )
    #[
    register MCTSStrategy(
        tag:               "odLog/{rolloutstr}".fmt,
        selectHeuristic:   optionsDiffHeuristic,
        rolloutHeuristic:  optionsDiffHeuristic,
        stoppingCriterion: stopAtNTrials n_trials,
        useLogScoreVisitHeuristicNormalization: true,
        selectOnRandom:    true,
    )
    ]#
    register MCTSStrategy(
        tag:               "hybrid/{rolloutstr}".fmt,
        selectHeuristic:   optionsDiffHeuristic,
        rolloutHeuristic:  fastHeuristic,
        stoppingCriterion: stopAtNTrials n_trials,
        selectOnRandom:    true,
    )
    #[
    register MCTSStrategy(
        tag:               "hybridlog/{rolloutstr}".fmt,
        selectHeuristic:   optionsDiffHeuristic,
        rolloutHeuristic:  fastHeuristic,
        stoppingCriterion: stopAtNTrials n_trials,
        useLogScoreVisitHeuristicNormalization: true,
        selectOnRandom:    true,
    )
    ]#
    register MCTSStrategy(
        tag:               "woo/{rolloutstr}".fmt,
        selectHeuristic:   weightOpponentOptionsHeuristic,
        rolloutHeuristic:  weightOpponentOptionsHeuristic,
        stoppingCriterion: stopAtNTrials n_trials,
        selectOnRandom:    true,
    )
    register MCTSStrategy(
        tag:               "moo/{rolloutstr}".fmt,
        selectHeuristic:   minOpponentOptionsHeuristic,
        rolloutHeuristic:  minOpponentOptionsHeuristic,
        stoppingCriterion: stopAtNTrials n_trials,
        selectOnRandom:    true,
    )
    register MCTSStrategy(
        tag:               "fastMoo/{rolloutstr}".fmt,
        selectHeuristic:   minOpponentOptionsHeuristic,
        rolloutHeuristic:  fastHeuristic,
        stoppingCriterion: stopAtNTrials n_trials,
        selectOnRandom:    true,
    )

for (rolloutstr, n_trials) in [("10k", 10000), ("25k", 25000), ("50k", 50000)]:
    for c in [1.0, 0.75, 1.5, 2.0, 0.1]:
        register MCTSStrategy(
            tag:               "moo/c={c}/{rolloutstr}".fmt,
            selectHeuristic:   minOpponentOptionsHeuristic,
            rolloutHeuristic:  minOpponentOptionsHeuristic,
            stoppingCriterion: stopAtNTrials n_trials,
            cParam:            c,
            selectOnRandom:    true,
        )
