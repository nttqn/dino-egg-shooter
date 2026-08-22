/// Clearing the board no longer ends a round in any mode — it just starts a
/// fresh one (advancing the level in Normal mode). A round only ends by
/// losing, or, in Time Trial, by the clock running out.
enum GameStatus { playing, lost, timeUp }
