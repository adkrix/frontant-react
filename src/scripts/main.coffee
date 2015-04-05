`/** @jsx React.DOM */`

if __PRODUCTION__
  require("script!react/react-with-addons.min.js")
else
  require("script!react/react-with-addons.js")


require("script!jquery/dist/jquery.js")

StarterApp = require('./components/StarterApp.coffee')

githubUrl = 'https://github.com/arthur-creek/frontant-react'
React.renderComponent(`<StarterApp githubUrl={githubUrl}/>`, document.getElementById('app'))

