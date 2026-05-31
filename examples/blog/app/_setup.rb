@app.setup_db(
  db_path:      File.join(@app.root_dir, '../blog.db'),
  schema_root:  '_schema'
)
