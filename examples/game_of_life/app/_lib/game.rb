export self

SIZE = 50
IDX_RANGE = 0...(SIZE * SIZE)
ROW_COL_RANGE = 0...SIZE

def size
  SIZE
end

def board
  @board
end

def board_updates
  @board_updates
end

def fill_cross(idx, value)
  return if !(idx in IDX_RANGE)

  row = idx / SIZE
  col = idx % SIZE

  set_cell(@board, row - 1, col, value)
  set_cell(@board, row + 1, col, value)
  set_cell(@board, row, col, value)
  set_cell(@board, row, col - 1, value)
  set_cell(@board, row, col + 1, value)
end

private

def set_cell(board, row, col, value)
  return if !(row in ROW_COL_RANGE) || !(col in ROW_COL_RANGE)

  @board[row * SIZE + col] = value
end

def setup_board
  board = [nil] * (SIZE * SIZE)
end

def next_generation(board)
  new_board = Array.new(SIZE * SIZE)
  IDX_RANGE.each do |idx|
    live_neighbors = get_live_neighbors(board, idx)
    if board[idx] && (live_neighbors.size in 2..3)
      new_board[idx] = live_neighbors.sample
    elsif !board[idx] && live_neighbors.size == 3
      new_board[idx] = live_neighbors.sample
    else
      # board[idx] = nil
    end
  end
  new_board
end

def get_live_neighbors(board, idx)
  row = idx / SIZE
  col = idx % SIZE
  live = []
  ((row - 1)..(row + 1)).each do |r|
    ((col - 1)..(col + 1)).each do |c|
      next if !(r in ROW_COL_RANGE) || !(c in ROW_COL_RANGE)
      next if r == row && c == col

      live << board[r * SIZE + c] if board[r * SIZE + c]
    end
  end
  live
end

@board_updates = @machine.broadcaster
@board = setup_board
@machine.spin do
  @machine.periodically(0.1) {
    @board = next_generation(@board)
    @board_updates.broadcast(@board)
  }
rescue => e
  p e
  p e.backtrace
  exit!
end

5.times { fill_cross(rand(SIZE * SIZE), 'blue') }