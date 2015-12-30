require 'faraday'
require 'json'
require 'pp'

def config
  return @_config if @_config
  require 'yaml'
  @_config = YAML.load_file "#{__dir__}/config.yml"
end

def jiraBaseUrl
  config['jira']['baseUrl']
end

def jiraCreds
  [config['jira']['user'], config['jira']['pass']]
end

def jira
  @_jira ||= Faraday.new(:url => jiraBaseUrl) do |faraday|
    faraday.basic_auth *jiraCreds
    # faraday.response :logger                  # log requests to STDOUT
    faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
  end
end

def myIssues
  return @_myIssues if @_myIssues
  res = jira.get '/rest/api/latest/search' do |req|
    req.params['jql'] = '(assignee = currentUser() OR reporter = currentUser()) AND resolution = Unresolved ORDER BY updatedDate DESC'
  end
  @_myIssues = (JSON.parse res.body)['issues'].map do |i|
    {
      key: i['key'],
      summary: i['fields']['summary'],
      description: i['fields']['description'],
      project: i['fields']['project']['name'],
      type: i['fields']['issuetype']['name'],
      status: i['fields']['status']['name']
      # rawdata: i
    }
  end
end

case ARGV[0]
when 'list'
  myIssues.each do |i|
    puts i[:key] + "\t" + i[:status] + "\t" + i[:summary]
  end

when /([a-z]+)-?([0-9]+)/i
  # open issue in browser if given a ticket key
  # our ticket keys always look like e.g. PE-93; this will accept pe93 as i am lazy
  `open #{jiraBaseUrl}/browse/#{$~[1].upcase}-#{$~[2]}`

else
  puts 'try again.'
end
