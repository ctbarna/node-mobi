mobi = require 'node-mobi'
chai = require 'chai'
chai.should()

describe "Mobi", ->
  it "should exist", ->
    mobi.should.exist
