export ->(db) {
  db.execute <<~SQL
    update posts
    set body = 'baz'
    where title = 'foo';
  SQL
}
