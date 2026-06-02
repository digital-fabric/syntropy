require 'securerandom'

db_path = @app.env[:test_mode] ?
  "/tmp/blog-#{SecureRandom.hex}.db" :
  File.join(@app.root_dir, '../blog.db')

@app.setup_db(
  db_path:      db_path,
  schema_root:  '_schema'
)
