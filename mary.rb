require 'sinatra'
require 'pg'
require 'json'
require 'bigdecimal'
require 'date'

# Configure Sinatra and libraries
db = PG::Connection.open(dbname: 'mary')

# This is used when retrieving records from the database
# The postgres driver returns strings. We take a look at
# which field is being returned, and turn the value into
# the appropriate Ruby type.
def convert_to_ruby_types(hash) 
  hash.keys.each do |key|
    value = hash[key]
    next unless value # Leave nils as nils
    case key
    when 'uid', 'aid'; hash[key] = value.to_i
    when 'created_at'; hash[key] = DateTime.parse(value)
    when 'deleted'; hash[key] = value == 't'
    when 'value'; hash[key] = BigDecimal.new(value)
    end
  end
  hash
end


# The url for getting the latest version of a specific assumption
# e.g., /a123
get %r{/a(\d+).json}, provides: :json do |id|
  r = db.exec_params("SELECT * FROM latest_assumptions WHERE aid = $1", [id.to_i])
  if r.ntuples == 0
    return 404
  else
    return convert_to_ruby_types(r.first).to_json
  end
end

# The url for getting the latest version of all assumptiokns
get '/assumptions.json' do
  r = db.exec_params("SELECT * FROM latest_assumptions",[])
  return r.map { |row| convert_to_ruby_types(row) }.to_json
end

# The url for getting a specific version of a specific assumption
# e.g., /u438
get %r{/u(\d+).json}, provides: :json do |id|
  r = db.exec_params("SELECT * FROM assumptions WHERE uid = $1", [id.to_i])
  if r.ntuples == 0
    return 404
  else
    return convert_to_ruby_types(r.first).to_json
  end
end

# The root url. Just returns index.html at the moment
get '/' do
  send_file 'public/index.html'
end

# This can be used to insert new assumptions into the database
# expects a set of key values. Only inserts the passed key values
# into the database. Returns a redirect to the json form of the 
# submitted data.
# FIXME: currently no security
post '/' do
  sql = "INSERT INTO assumptions (#{params.keys.map { |k| db.escape_identifier(k) }.join(',')}) VALUES (#{(1..params.size).map { |i| "$#{i}" }.join(',')}) RETURNING uid"
  r = db.exec_params(sql, params.values)
  redirect to("/u#{r[0]['uid']}.json")
end

