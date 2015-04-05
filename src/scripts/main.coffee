`/** @jsx React.DOM */`

if __PRODUCTION__
  require("script!react/react-with-addons.min.js")
else
  require("script!react/react-with-addons.js")


require("script!jquery/dist/jquery.js")

App = require('./components/App.coffee')

React.renderComponent(`<App />`, document.getElementById('app'))

