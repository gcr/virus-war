import godot
import board
import mcts
import options

type CpuPlayer* = ref object of Node
  forest: MCTSForest
  state: State

proc runMcts*(self: CpuPlayer, n_rounds: int): PackedByteArray {.exportGd: "run_mcts".} =
  echo "Running MCTS ..."
  let bestAction = mcts(self.forest, self.state, n_rounds, minOpponentOptionsHeuristic)
  echo bestAction
  discard result.append(Int(bestAction.r))
  discard result.append(Int(bestAction.c))
  echo "Result: ", result

proc resetState*(self: CpuPlayer, whoseTurn: int, capturesToMake: int, bSize: int, board: PackedByteArray) {.exportGd: "reset_state".} =
  self.forest = MCTSForest()
  if whoseTurn == 0:
    self.state.whoseTurn = Player.A
  else:
    self.state.whoseTurn = Player.B
  self.state.capturesToMake = capturesToMake.uint8
  self.state.board = board(bSize.uint8,bSize.uint8)
  if board.size == bSize*bSize:
    for i in 0 ..< board.size:
      let r = i div bSize
      let c = i mod bSize
      case board[i]:
      of 1: self.state.board[r,c] = Cell.LiveA
      of 2: self.state.board[r,c] = Cell.LiveB
      of 3: self.state.board[r,c] = Cell.LockedA
      of 4: self.state.board[r,c] = Cell.LockedB
      else: discard
  else:
    echo "Uh oh, wrong size"



CpuPlayer.isInheritanceOf Node

#method ready(self: CpuPlayer) =
#  discard
#
#method process(self: CpuPlayer; delta: float64) =
#  discard

# Executed when this library is loaded (the godot project is executed)
proc initialize(lvl: InitializationLevel): void =
  echo "HELLO FROM NIM"
  register_class CpuPlayer

# Executed when this library is unloaded (the godot project is terminated)
proc terminate(lvl: InitializationLevel): void =
  discard

let cfg = GDExtensionConfig(
  initializer: initialize,
  terminator: terminate,
)

GDExtension_EntryPoint name=init_library, config=cfg