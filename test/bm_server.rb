# frozen_string_literal: true

require 'httparty'

def t(url)
  HTTParty.get(url)
end

def m(x=1)
  t0 = Time.now
  x.times { yield }
  e = Time.now - t0
  p [x, e, e/x, x/e]
end
  
m(10000) { t('http://localhost:1234/') }
