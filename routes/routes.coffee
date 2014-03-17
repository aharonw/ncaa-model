express = require 'express'
http    = require 'http'
path    = require 'path'
stylus  = require 'stylus'
routes  = require __dirname
mongoose = require 'mongoose'

dbUrl = 'mongodb://localhost/ncaa'

app = express()

mongoose.connect dbUrl

app.configure ->
  app.set 'port', process.env.PORT || 3000
  app.set 'views', './views'
  app.set 'view engine', 'jade'
  app.use express.favicon()
  app.use express.logger('dev')
  app.use express.bodyParser()
  app.use express.methodOverride() 
  app.use app.router
  app.use stylus.middleware('./public')
  app.use express.static(path.join('public'))

app.configure 'development', ->
  app.use express.errorHandler()

app.get '/', routes.index

app.get '/scrape', routes.scrape
app.get '/teams', routes.teams

http.createServer(app).listen app.get('port'), ->
  console.log("Express server listening on port " + app.get('port'));
