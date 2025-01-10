# Virus Wars

Virus Wars (a.k.a. Война Вирусов, "Paper Tactics") is a pen-and-paper game played by students at Saint Petersburg State University and at various schools in Kyiv in the 1980s.

This repository contains:

1. A Godot 4.0 app implementing this game for Android eInk devices, intended for pass-and-play between two players;
2. A first stab at an implementation of an MCTS-based AI opponent (written in nim).

Both projects are "just for fun;" I don't really intend to complete them further.

**To play with the CLI bot:**

First, make sure you have `nim` installed with `brew install nim` or `apt install nim`. Tested with `nim --version` =2.0.8, but should work with any nim > 2.0.

```sh
git clone https://github.com/gcr/virus-war.git
cd virus-war/nim

# Dependencies
nimble install norm
nimble install db_connector
nimble install cligen
nimble install fusion

# Compilation:
# ...for arm64 devices with NEON intrinsics (~2x speedup on mac):
nim c runArenaMatch.nim
# ...for PC and x86-64 devices:
nim c -d:useNeon=false runArenaMatch.nim

# Play: human vs human
./runArenaMatch -A=player -B=player
# Human vs CPU (strong)
./runArenaMatch -A=player -B=moo/50k
# Human vs CPU (moderate)
./runArenaMatch -A=player -B=od/50k
# Human vs CPU (weak)
./runArenaMatch -A=player -B=hybrid/10k

# Enter your moves in chess notation, like "f3" or "a2".
# Player A moves once, then each player trades off three times.
```

**To play against a human player on your eInk tablet:** switch to commit `79d1630d2587dbf83c9db9ea203ebd07f9bba26a`, the last commit before I integrated the CPU player into the Godot game.

**To play against the CPU on your eInk tablet:** figure out how to compile the bot Godot extension in `nim/extension`. Good luck! I'm abandoning this because performance on my hardware takes minutes per ply.

## Game Rules
The goal is to "surround" your opponent and deny their moves. The player who can't move loses.

Play begins on a square board (typically 11x11) with X and O having one cell in opposite corners.

To compensate for first-player advantage, the first player makes one move on their first turn. Their opponent responds with three moves, and play continues from there with each palyer making three moves per turn.

If a player can't finish all three of their three moves, they lose.

**Turn actions:** Each move, you can either:
- Capture a blank cell for yourself, OR
- Steal one of your opponent's "live" cells. The stolen cell becomes yours and is considered "dead"; it cannot be captured again.

**Ajdacency rule:** Each cell you capture or steal steal must be next to one of your "*live groups*." To elaborate:

- Groups of cells can be connected through any of eight neighbors. Only cells you own (or have captured) count as part of your group.
- If a group of your cells still has at least one live cell in it, it's considered "live". Groups containing only dead cells are "dead."
- You can still place cells (or capture cells) next to one of your dead cells IF it's part of a live group (i.e. the group of cells has at least one live one).

If all of the cells in your group are dead (i.e. because your opponent cut them off), you can't place next to that group.

Groups can connect diagonally. This also implies that your groups and your opponent's groups can crisscross on the board diagonally.

As the game progresses, it's common for you and your opponent to fight over which groups you cut off.

## Strategy examples
- Disconnected groups of dead cells become walls that cannot be traversed.
- If your opponent placed a bunch of live cells next to you, you can easily take them over if you don't get cut off.
- A live cell surrounded by that owner's dead cells is impossible to capture, and these groups are always reachable

These simple rules admit some rather complex strategies. New players are often overconfident and play too offensively. Here are some rules of thumb:
- It's generally better to steal cells from your opponent than to capture new cells.
- In hotly-contested areas, every new cell you place is one turn away from becoming an impenetrable stepping stone for your opponent.
  - Likewise, when your opponent places a new cell instead of capturing one of yours, they're rolling out a red carpet for you to capture and punish.
- Horizontal and vertical walls of dead cells are stronger defense than diagonal walls.
- Diagonal walls offer more possibilities for incursion than horizontal/vertical walls.
- It's best to stay at least two squares away from your opponent if you can. If you dare to venture closer than this, your opponent can capture and punish on their turn, earning themselves a crucial inroad to your live groups.



## See Also
There's not much English-language content about this game.
- [On Hacker News](https://news.ycombinator.com/item?id=38472333)
- [Pencil and Paper Games Wiki](http://www.papg.com/show?5SB0)
- [On Russian Wikipedia article](https://ru.wikipedia.org/wiki/%D0%92%D0%BE%D0%B9%D0%BD%D0%B0_%D0%B2%D0%B8%D1%80%D1%83%D1%81%D0%BE%D0%B2) (basic strategy)
- [Play an online variant](https://www.paper-tactics.com/)
