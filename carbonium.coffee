Pictures = new Meteor.Collection 'pictures'

if Meteor.isClient
  Router.configure {}
  Router.map ->
    @route 'welcome',
      path: '/'
      template: 'pictures'
    @route 'picture',
      path: '/:picture_id'
      template: 'picture'

  Template.pictures.helpers
    all: ->
      Pictures.find({})



if Meteor.isServer
  if Pictures.find({}).fetch().length is 0
    Pictures.insert
      url: "http://en.wikipedia.org/wiki/File:Helvellyn_Striding_Edge_360_Panorama,_Lake_District_-_June_09.jpg"

