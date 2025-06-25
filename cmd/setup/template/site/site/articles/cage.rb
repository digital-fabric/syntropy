layout = import('_layout/default')

poem = [
  "        in ten\xA0", 'M', 'inutes',
  '                  ', 'C', 'ome back: you will',
  'have taught me chi', 'N', 'ese',
  '                (s', 'A', 'tie).',
  '       shall I ret', 'U', 'rn the favor?',
  '                  ', 'G', 'ive you',
  '                ot', 'H', 'er lessons',
  '                 (', 'T', 'ing!)?',
  '                  ', 'O', 'r would you prefer',
  '              sile', 'N', 'ce?',
]

export layout.apply {
  article(class: 'mesostic') {
    h2 'For William McN. who studied with Ezra Pound'

    content {
      span(_for: poem) { text it }
    }

    author {
      span "-\xA0"
      a 'John cage', href: 'https://en.wikipedia.org/wiki/John_Cage'
    }
  }
}
