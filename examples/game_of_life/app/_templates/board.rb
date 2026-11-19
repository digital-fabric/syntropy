export template { |board|
  div(id: 'board', "data-on:pointerdown" => "@post(`/tap?idx=${evt.target.dataset.idx}`)") {
    board.each_with_index { |value, idx|
      cell(class: value || 'empty', data_idx: idx)
    }
  }
}
