$       = require 'cheerio'
_       = require 'underscore'
request = require 'request'
async   = require 'async'
mongoose = require 'mongoose'
baseUrl = 'http://www.sports-reference.com'

Schema = mongoose.Schema
ObjectId = Schema.ObjectId

TeamSchema = new Schema
  name          : String
  year          : String
  seed          : Number
  wins          : Number
  url           : String
  three         : Number
  games         : Number
  steals        : Number
  avgHeight     : Number
  stealsPer     : Number
  stealsP       : Number
  awScore       : Number
  year          : Number
  players       : [ { name: String, height: Number } ]

Team = mongoose.model 'Team', TeamSchema

grabTeamStats = (team, html) ->
  wholeTeamData = html('#all_team_stats').find('tr').slice(1,2)
  team.three  = wholeTeamData.find('td').slice(8,9).text()
  team.games  = wholeTeamData.find('td').slice(1,2).text()
  team.steals = wholeTeamData.find('td').slice(16,17).text()
  return team

reqPlayer = (row, cb) ->
  link = baseUrl + row.find('td').slice(1,2).children().attr('href')
  request link, (err, resp, html, height) =>
    player = {}
    playerPage = $.load html
    player.name = playerPage('#info_box').find('h1').slice(0,1).text()
    vitals = playerPage('#info_box').find('p').slice(0,1).text()
    height = vitals.match(/(?:Height:.)([\s\S]+?)(?:..Weight)/i)[1]
    feet = parseInt height[0]
    inches = parseInt height.slice(2).replace(/\s+/g, '')
    totalInches = feet*12 + inches
    player.height = totalInches
    cb null, player

getTeamHeight = (team, cb) ->
  request team.url, (err, resp, html) =>

    perTeam = 3
    teamPage = $.load html
    team = grabTeamStats team, teamPage

    async.parallel

      players: (cb) ->
        players = []
        p = []
        for x in [1...4]
          row = teamPage('#div_totals').find('tr').slice(x, x+1)
          p.push row
        async.map p, reqPlayer, (err, results) =>
          players = results
          cb null, players

      wins: (cb) ->
        url = team.url
        schUrl = url.slice(0, url.length-5) + '-schedule.html'

        request schUrl, (err, resp, html) =>

          schPage  = $.load html
          noRanker = schPage('#all_schedule').find('.no_ranker').last()
          tr       = noRanker.next()

          wins = 0
          wins = getPlayoffs tr, wins

          cb null, wins

      (err, results) ->
        team.players = results.players
        team.wins    = results.wins

        team.save()
        cb team


getPlayoffs = (tr, wins) ->
  WL = null
  WL = tr.find('td').slice(6,7).text()
  date = tr.find('td').slice(1,2).text()
  if WL is 'W'
    wins++
  tr2 = tr.next()
  date2 = tr2.find('td').slice(1,2).text()
  if date2 is date
    return wins
  else
    getPlayoffs tr2, wins

getAllTeamHeights = (teams) ->
  async.forEach teams, getTeamHeight, (team) =>
    console.log "Got All Teams"

getTeamList = (err, resp, html) ->
  return console.log err if err
  tourneyTeamPage = $.load html
  year = tourneyTeamPage('#info_box').find('h1').text().slice(0,4)
  #regionIds = ['#East']
  regionIds = ['#East', '#Midwest', '#South', '#West']
  #regionIds = ['#East', '#Southeast', '#Southwest', '#West']
  badRows = [2, 5, 8, 11, 14, 17, 20]
  teams = []
  for id in regionIds
    region = tourneyTeamPage(id).find('tr')
    region.each (i, elem) ->
      team = new Team
      if badRows.indexOf(i) < 0
        team.seed = this.find('td').slice(0,1).text()
        team.name = this.find('td').slice(1,2).find('a').slice(0,1).text()
        console.log team.name
        team.url  = baseUrl + this.find('td').slice(1,2).find('a').slice(0,1).attr('href')
        team.year = year
        teams.push team
  getAllTeamHeights teams

exports.index = (req, res) ->
  Team.find {}, (err, teams) ->
    for team in teams
      total = 0
      team.stealsPer = Math.round((parseInt(team.steals) / parseInt(team.games))*100)/100
      team.stealsP = team.stealsPer * 100
      for player in team.players
        total = total + player.height
      team.avgHeight = Math.round(total/3*100)/100

      if team.avgHeight > 77
        awHeight = team.avgHeight - 72.5
      else
        awHeight = 0

      if team.stealsPer > 6
        awSteals = team.stealsPer - 3
      else
        awSteals = 0

      if team.three > .37
        awThree = (team.three * 5)
      else
        awThree = 0

      if team.seed < 4
        awSeed = 1.4
      else
        awSeed = 1

      # if team.three < .35 and team.seed > 5
      #   awthreePenalty = 50
      # else
      #   awthreePenalty = 0

      team.awScore = (Math.pow(awHeight, 3) + Math.pow(awSteals, 3) + Math.pow(awThree, 3))

      # if team.seed is 16
      #   team.awScore = 0
      #team.awScore = Math.round(team.awScore*100)/100

    res.render 'index', { title: "NCAA", teams: teams }

exports.scrape = (req, res) ->
  url = 'http://www.sports-reference.com/cbb/schools/harvard/2012.html'
  team = request url, gotTeam

exports.teams = (req, res) ->
  year = '2014'
  url  = baseUrl + '/cbb/postseason/' + year + '-ncaa.html'
  request url, getTeamList