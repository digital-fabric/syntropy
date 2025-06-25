layout = import('_layout/default')

poem_body = [
  ['      in ten&nbsp;', 'M', 'inutes']
  ['                  ', 'C', 'ome back: you will']
  ['have taught me chi', 'N', 'ese']
  ['                (s', 'A', 'tie).']
  ['       shall I ret', 'U', 'rn the favor?']
  ['                  ', 'G', 'ive you']
  ['                ot', 'H', 'er lessons']
  ['                 (', 'T', 'ing!)?']
  ['                  ', 'O', 'r would you prefer']
  ['              sile', 'N', 'ce?']
]

template = layout.apply {
  article {
    h2 'For William McN. who studied with Ezra Pound'

    line(_for: poem_body) { |l|
      span(_for: l) { text it }
    }

    author {
      span '-'
      a 'John cage', href: 'https://en.wikipedia.org/wiki/John_Cage'
    }
  }
}

export template
