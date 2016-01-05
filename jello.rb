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

def trello
  @_trello ||= Faraday.new(:url => 'https://api.trello.com') do |faraday|
    # faraday.response :logger                  # log requests to STDOUT
    faraday.request  :url_encoded
    faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
    faraday.params = { key: config['trello']['apiKey'], token: config['trello']['token'] }
  end
end

def myIssues
  return @_myIssues if @_myIssues
  res = jira.get '/rest/api/latest/search' do |req|
    req.params['jql'] = '(assignee = currentUser() OR reporter = currentUser() OR creator = currentUser() OR issue in watchedIssues()) AND resolution = Unresolved ORDER BY updatedDate DESC'
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

def trelloBoardInfo
  return @_boardInfo if @_boardInfo
  res = trello.get "/1/boards/#{config['trello']['boardId']}" do |req|
    req.params['lists'] = 'open'
    req.params['labels'] = 'all'
  end
  res = JSON.parse res.body
  @_boardInfo = {
    id: config['trello']['boardId'],
    jiraLabelId: res['labels'].select {|l| l['name'].downcase == 'jira'} .first['id'],
    inboxListId: res['lists'].select {|l| l['name'].downcase == 'inbox'} .first['id']
  }
end

def myTrelloCards
  return @_myTrelloCards if @_myTrelloCards
  res = trello.get "/1/boards/#{config['trello']['boardId']}/cards/all" do |req|
    req.params['attachments'] = true
    req.params['attachment_fields'] = 'url'
  end
  @_myTrelloCards = (JSON.parse res.body).map do |c|
    {
      id: c['id'],
      jiraKey: c['attachments'].map {|a| /#{jiraBaseUrl}\/browse\/(.*)/.match( a['url'] )[1] } .first,
      closed: c['closed']
    }
  end
end

def pull
  gotKeys = myTrelloCards.map {|c| c[:jiraKey]} .select {|k| k} .to_set
  toAdd = myIssues.reject {|i| gotKeys.include? i[:key] }
  return if toAdd.empty?

  count = toAdd.length
  cards = Hash[ toAdd.map { |i|
    [
      i[:key],
      {
        name: i[:summary],
        desc: i[:description],
        idList: trelloBoardInfo[:inboxListId],
        idLabels: trelloBoardInfo[:jiraLabelId],
        due: nil
      }
    ]
  }]
  n = 0
  cards.each do |jiraKey, cardParams|
    n += 1
    puts jiraKey + ": " + cardParams[:name]

    print "(#{n}/#{count}) adding… "
    res = trello.post "/1/cards", cardParams
    id = (JSON.parse res.body)['id']

    print "attaching… "
    trello.post "/1/cards/#{id}/attachments", {url: "#{jiraBaseUrl}/browse/#{jiraKey}"}

    puts
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

when 'pull'
  pull

else
  puts 'try again.'
end
