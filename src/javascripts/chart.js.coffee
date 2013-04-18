data = {}
nested_data = {}

d3.json("/category/Nuclear%20power/parameter/load%20factor", (error, json) ->
  return console.warn(error) if error
  timeFormat = d3.time.format("%Y-%m-%dT%H:%M:%S+00:00")
  json.forEach( (d) ->
    d.created_at = timeFormat.parse(d.created_at)
    d.period[0] = timeFormat.parse(d.period[0])
    d.period[1]= timeFormat.parse(d.period[1])
    d.value = +d.value
  )
  nested_data = d3.nest()
    .key((d) -> d.source)
    .key((d) -> d.label)
    .sortValues((a,b) -> d3.ascending(a.period[0], b.period[1]))
    .entries(json)
  data = json
  visualise()
)

visualise = () ->
  createLineChart()
  updateLineChart()

line = d3.svg.line()
svg = undefined

createLineChart = () ->
  margin = {top: 20, right: 20, bottom: 30, left: 90}
  width = 960 - margin.left - margin.right
  height = 500 - margin.top - margin.bottom
    
  x = d3.time.scale()
    .domain(d3.extent(data, (d) -> d.period[0]))
    .range([0, width])

  window.x = x

  y = d3.scale.linear()
    .domain([0, d3.max(data, (d) -> d.value)])
    .range([height, 0])
    .nice()

  xAxis = d3.svg.axis()
    .scale(x)
    .orient("bottom")

  yAxis = d3.svg.axis()
    .scale(y)
    .orient("left")

  line.x( (d) -> x(d.period[0]) )
  line.y( (d) -> y(d.value) )
  
  svg = d3.select("#chart").append("svg")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
  .append("g")
    .attr("transform", "translate(" + margin.left + "," + margin.top + ")")
  
  svg.append("text").attr("x",-margin.left).attr("y",4).text("ktoe/yr").classed("axis-title",true)
  
  svg.append("g")
    .attr("class", "x axis")
    .attr("transform", "translate(0," + height + ")")
    .call(xAxis)
  
  svg.append("g")
    .attr("class", "y axis")
    .call(yAxis)
  

updateLineChart = () ->
  sources = svg.selectAll("g.source")
    .data(nested_data)

  sources.enter().append("g")
    .attr('class','source')
    .attr('data-source', (d) -> d.key)

  sources.exit().remove()


  series = sources.selectAll("g.series")
    .data((d,i) -> d.values)

  series.enter()
    .append("g")
    .attr('class','series')
    .attr('data-series', (d) -> d.key)
    .append("path")
    .datum((d,i) -> d.values)
    .attr('class','data-line')
    .attr('d', line)

  series.exit().remove()
