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

  Template.picture.helpers
    picture: ->
      Pictures.find({}).fetch()[1]


if Meteor.isServer
  if Pictures.find({}).fetch().length < 2
    Pictures.insert
      url: "http://bbs.c114.net/uploadImages/200412912265686500.jpg"

