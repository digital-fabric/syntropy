export(
  storage: {
    path: ENV['DATABASE_PATH'] || File.join(__dir__, '../storage/production.db')
  }
)
