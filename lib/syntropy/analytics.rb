require 'digest/sha2'

module Syntropy
  class Analytics
    def initialize(connection_pool)
      @connection_pool = connection_pool

      setup_schema_SQL
    end

    def process_request(req)
      status = req.response_headers[':status']
      
      return if req.http_method != 'get'
      return if status && status != HTTP::OK
      return if req.response_headers['Content-Type'] !~ /^text\/html/

      process_impression(req, Time.now)
    end

    def get_metrics(period)
      t1 = Time.now.to_i - period
      collect_metrics(t1)
    end

    private

    SCHEMA_SQL = <<~SQL
      create table if not exists impressions (
        stamp integer not null,
        url text not null,
        referrer text,
        user_agent text,
        client_hash text
      ) strict;

      create index if not exists idx_impressions_stamp
        on impressions (stamp);
    SQL

    def setup_schema_SQL
      @connection_pool.with_db do |db|
        db.execute(SCHEMA_SQL)
      end
    end

    INSERT_IMPRESSION_SQL = <<~SQL
      insert into impressions (stamp, url, referrer, user_agent, client_hash)
        values (:stamp, :url, :referrer, :user_agent, :client_hash)
    SQL

    def process_impression(req, stamp)
      stamp = stamp.to_i
      ua = req.headers['user-agent']
      record = {
        stamp:        stamp,
        url:          clean_url(req.full_uri),
        referrer:     req.headers['referer'],
        user_agent:   ua,
        client_hash:  calc_client_hash(stamp, req.forwarded_for, ua)
      }

      @connection_pool.with_db { |db|
        db.execute(INSERT_IMPRESSION_SQL, **record)
      }
    end

    def calc_client_hash(stamp, ip, ua)
      ip ? Digest::SHA256.hexdigest("#{stamp/86400}:#{ip}:#{ua}") : nil
    end

    def clean_url(url)
      (m = url.match(/^(.+)\?(.*)$/)) ? m[1] : url
    end

    TOTAL_PAGE_VIEWS_SQL = <<~SQL
      select count(stamp) from impressions
      where stamp >= ?
    SQL

    TOTAL_UNIQUE_VISITORS_SQL = <<~SQL
      with unique as (
        select distinct client_hash from impressions
        where stamp >= ?
      )
      select count(client_hash) from unqiue;
    SQL

    TOP_PAGES_BY_VIEWS_SQL = <<~SQL
      select url, count(url) from impressions
      where stamp >= ?
      group by url limit 15
    SQL

    TOP_REFERRERS_SQL = <<~SQL
      select referrer, count(referrer) from impressions
      where stamp >= ?
      group by referrer limit 15
    SQL

    def collect_metrics(t1)
      @connection_pool.with_db { |db|
        {
          total_page_views:
            db.query_single_splat(TOTAL_PAGE_VIEWS_SQL, t1),
          total_unique_visitors:
            db.query_single_splat(TOTAL_UNIQUE_VISITORS_SQL, t1),
          top_pages_by_views:
            db.query(TOP_PAGES_BY_VIEWS_SQL, t1),
          top_referrers:
            db.query(TOP_REFERRERS_SQL, t1)
        }
      }
    end
  end
end
