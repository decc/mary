require 'sinatra'
require 'pg'
require 'json'
require 'bigdecimal'
require 'date'

# Configure Sinatra and libraries
db = PG::Connection.open(dbname: 'mary')

def convert_to_ruby_types(hash) 
  hash.keys.each do |key|
    value = hash[key]
    if value
      case key
      when 'uid', 'aid'; hash[key] = value.to_i
      when 'created_at'; hash[key] = DateTime.parse(value)
      when 'deleted'; hash[key] = value == 't'
      when 'value'; hash[key] = BigDecimal.new(value)
      end
    end
  end
  hash
end


get %r{/a(\d+)}, provides: :json do |id|
  r = db.exec_params("SELECT * FROM latest_assumptions WHERE aid = $1", [id.to_i])
  if r.ntuples == 0
    return 404
  else
    return convert_to_ruby_types(r.first).to_json
  end
end

get '/assumptions' do
  r = db.exec_params("SELECT * FROM latest_assumptions",[])
  return r.map { |row| convert_to_ruby_types(row) }.to_json
end

get %r{/u(\d+)}, provides: :json do |id|
  r = db.exec_params("SELECT * FROM assumptions WHERE uid = $1", [id.to_i])
  if r.ntuples == 0
    return 404
  else
    return convert_to_ruby_types(r.first).to_json
  end
end

get '/' do
  send_file 'public/index.html'
end

post '/' do
  sql = "INSERT INTO assumptions (#{params.keys.map { |k| db.escape_identifier(k) }.join(',')}) VALUES (#{(1..params.size).map { |i| "$#{i}" }.join(',')}) RETURNING uid"
  r = db.exec_params(sql, params.values)
  redirect to("/u#{r[0]['uid']}")
end

