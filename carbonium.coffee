Pictures = new Meteor.Collection 'pictures'
Devices = new Meteor.Collection 'devices'

if Meteor.isClient
  Router.configure {}
  Router.map ->
    @route 'welcome',
      path: '/'
      template: 'pictures'
    @route 'picture',
      path: '/:picture_id'
      template: 'picture'
      data: ->
        currentPictureId = @params.picture_id
        Template.picture.helpers
          picture: ->
            currentPicture = Pictures.findOne(currentPictureId)
            unless Session.get 'myDeviceId'
              myDeviceId = Devices.insert
                pictureId: currentPictureId
                online: true
              Session.set 'myDeviceId', myDeviceId
              Meteor.setInterval ->
                Meteor.call('heartbeat', myDeviceId)
              , 500
            return currentPicture

          myDevices: ->
            Devices.findOne({_id: Session.get('myDeviceId')})

  Template.pictures.helpers
    all: ->
      Pictures.find({})


if Meteor.isServer
  Meteor.methods
    heartbeat: (deviceId) ->
      Devices.update
        _id: deviceId,
        {$set:
          ts: Date.now()
        }

  Meteor.setInterval ->
    Devices.remove {ts: {$lt: Date.now() - 2000}}
    console.log Devices.find({}).fetch().length
  , 1000
