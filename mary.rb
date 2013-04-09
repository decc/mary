require 'sinatra'
require 'pg'
require 'json'
require 'bigdecimal'
require 'date'

# Configure Sinatra and libraries
$db = PG::Connection.open(dbname: 'mary')

# This is used to execute sql and get a single value back
def single(sql, values = [])
  r = $db.exec_params(sql, values)
  return nil if r.ntuples == 0
  convert_to_ruby_types(r.first)
end

# This is used to execute sql and get an array of records back
def multiple(sql, values = [])
  r = $db.exec_params(sql, values)
  return [] if r.ntuples == 0
  r.map { |row| convert_to_ruby_types(row) }
end

# This is used to escape identifiers
# values should be escaped automatically
# because we are using exec_params
# FIXME: Check this.
def escape(value)
  $db.escape_identifier(value)
end

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
    when 'count'; hash[key] = value.to_i
    end
  end
  hash
end

# This is used to check whether a record has created a new category, name or source
# If one has, then warns about it.
def check_for_new_fields(hash)
  if new_value?('category', hash['category'])
    note(hash['uid'], "You have created a new category '#{hash['category']}'. Did you mean to?") 
  elsif new_value?('name', hash['name'])
    note(hash['uid'], "You have created a new property of '#{hash['category']}', '#{hash['name']}'. Did you mean to?") 
  end
  if new_value?('source', hash['source'])
    note(hash['uid'], "You have created a new source '#{hash['source']}'. Did you mean to?")
  end 
end

# It does this by counting whether it has ocurred more than once in latest_assumptions
# More than once, because it is likely to have been saved in this hash
# Latest assumptions, because the history of assumptions is likely to include spelling mistakes
def new_value?(field, value)
  result = single("SELECT COUNT(aid) FROM latest_assumptions WHERE lower(#{escape(field)}) = lower($1)", [value])
  result['count'] <= 1
end

# This is used to add a note to a specific assumption
def note(uid, note)
  single("INSERT INTO notes (assumption_uid, content) VALUES ($1, $2)", [uid, note])
end

# The url for getting the latest version of a specific assumption
# e.g., /a123
get %r{/a(\d+).json}, provides: :json do |id|
  assumption = single("SELECT * FROM latest_assumptions WHERE aid = $1", [id.to_i])
  return 404 unless assumption
  assumption.to_json
end

# The url for getting the latest version of all assumptiokns
get '/assumptions.json' do
  assumptions = multiple("SELECT * FROM latest_assumptions",[])
  assumptions.to_json
end

# The url for getting a specific version of a specific assumption
# e.g., /u438
get %r{/u(\d+).json}, provides: :json do |id|
  assumption = single("SELECT * FROM assumptions WHERE uid = $1", [id.to_i])
  return 404 unless assumption
  assumption.to_json
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
  params.delete('uid') # No rewriting history!
  sql = "INSERT INTO assumptions (#{params.keys.map { |k| escape(k) }.join(',')}) VALUES (#{(1..params.size).map { |i| "$#{i}" }.join(',')}) RETURNING *"
  assumption = single(sql, params.values)
  # FIXME: Check that the insert succeeded
  check_for_new_fields(assumption)
  redirect to("/u#{assumption['uid']}.json")
end

