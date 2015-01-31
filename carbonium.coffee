Pictures = new Meteor.Collection 'pictures'

if Meteor.isClient
  Template.pictures.helper
    all: Pictures.find {}

if Meteor.isServer
  console.log "is server side"

