Storage = import '/_lib/storage'

class PostStore
  def initialize(cp)
    @cp = cp
  end
  
  # @return [Integer] post id
  def create(title, body)
    @cp.query_single_value <<~SQL, title:, body:
      insert into posts (title, body)
      values (:title, :body)
      returning id;
    SQL
  end

  # @return [void]
  def update(id, title, body)
    @cp.execute <<~SQL, id:, title:, body:
      update posts
      set title = :title, body = :body
      where id = :id
    SQL
  end

  # @return [void]
  def delete(id)
    @cp.execute <<~SQL, id:
      delete from posts
      where id = :id
    SQL
  end

  # return [Hash]
  def get(id)
    @cp.query_single_row <<~SQL, id:
      select id, title, body
      from posts
      where id = :id
    SQL
  end

  # return [Array<Hash>]
  def get_all
    @cp.query <<~SQL
      select id, title, body
      from posts
      order by id desc
    SQL
  end
end

export PostStore.new(Storage.connection_pool)
