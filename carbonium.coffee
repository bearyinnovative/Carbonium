Pictures = new Meteor.Collection 'pictures'

if Meteor.isClient
  Template.pictures.helper
    all: [
        {url:"1"},
        {url:"2"},
        {url:"3"},
        {url:"4"}
      ]

if Meteor.isServer
  console.log "is server side"

