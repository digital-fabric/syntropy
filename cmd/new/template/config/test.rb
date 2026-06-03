export({
  storage: {
    path: ENV['DATABASE_PATH'] || Syntropy.tmp_path('test-db')
  }
})
