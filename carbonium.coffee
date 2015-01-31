Pictures = new Meteor.Collection 'pictures'
Devices = new Meteor.Collection 'devices'

getDevicesByPictureId = (pictureId) ->
  Devices.find({pictureId: pictureId})

getPictureUrlById = (pictureId) ->
  "http://#{window.location.hostname}:#{window.location.port}/#{pictureId}"

upload_file = (file) ->
  AV.initialize("5m9xcgs9px1w68dfhoixe3px9ol7kjzbhdbo30mvbybzx5ht", "q9bhxqjx4nlm4sq8vcqbucot7l9e19p47s8elywqn34fchtj")
  avFile = new AV.File("dummy_file", file)
  avFile.save().then (saved_file) ->
    url = saved_file.url()
    pictureId = Pictures.insert
      url: url
  , (error) ->
    alert("error")

if Meteor.isClient
  Router.configure {}
  Router.map ->
    @route 'welcome',
      waitOn: ->
       Meteor.subscribe('pictures')
      path: '/'
      template: 'pictures'
      data: ->
        intervalId = Session.get 'intervalId'
        meteor.clearInterval(intervalId) if intervalId
        Session.set 'mydeviceId', undefined
    @route 'share',
      waitOn: ->
       Meteor.subscribe('picture', @params.picture_id) and
       Meteor.subscribe('devices', @params.picture_id)
      path: '/:picture_id/share'
      template: 'share'
      data: ->
        currentPictureId = @params.picture_id
        window.qr = Template.qr
        Template.qr.rendered = ->
          picUrl = getPictureUrlById currentPictureId
          $('#qrcode').qrcode
            text: picUrl

        Template.share.helpers
          picture: ->
            Pictures.findOne currentPictureId
          devices: ->
            getDevicesByPictureId currentPictureId


    @route 'picture',
      waitOn: ->
       Meteor.subscribe('picture', @params.picture_id) and
       Meteor.subscribe('devices', @params.picture_id)
      path: '/:picture_id'
      template: 'picture'
      data: ->
        isMouseDown = false
        startX = startY = lastX = lastY = 0
        currentPictureId = @params.picture_id
        parseCssInt = (target, selector) ->
          parseInt(getComputedStyle(target)[selector])
        getMyDevice = ->
          Devices.findOne({_id: Session.get('myDeviceId')})

        touchHandler = (event) ->
          touches = event.changedTouches
          first = touches[0]
          type = ""
          switch event.type
            when "touchstart"
              type = "mousedown"
            when "touchmove"
              type = "mousemove"
            when "touchend"
              type = "mouseup"
            else
              return
          simulatedEvent = document.createEvent("MouseEvent")
          simulatedEvent.initMouseEvent type, true, true, window, 1, first.screenX, first.screenY, first.clientX, first.clientY, false, false, false, false, 0, null #left
          first.target.dispatchEvent simulatedEvent
          event.preventDefault()
          return

        document.addEventListener("touchstart", touchHandler, true)
        document.addEventListener("touchmove", touchHandler, true)
        document.addEventListener("touchend", touchHandler, true)
        document.addEventListener("touchcancel", touchHandler, true)

        Template.picture.helpers
          picture: ->
            currentPicture = Pictures.findOne(currentPictureId)
            unless Session.get 'myDeviceId'
              myDeviceId = Devices.insert
                pictureId: currentPictureId
                online: true
                width: jQuery(window).width()
                height: jQuery(window).height()
                top: 0
                left: 0
                ts: Date.now()
                userAgent: window.navigator.userAgent
              Session.set 'intervalId', Meteor.setInterval ->
                Meteor.call('heartbeat', myDeviceId)
              , 200
              Session.set 'myDeviceId', myDeviceId
            return currentPicture

          getLeft: ->
            -getMyDevice().left or 0

          getTop: ->
            getMyDevice().top or 0

          myDevice: getMyDevice

        Template.picture.events
          'dragstart img': (event) ->
            event.preventDefault()
          'mousedown img': (event) ->
            isMouseDown = true
            left = parseCssInt(event.target, 'left')
            top = parseCssInt(event.target, 'top')
            lastX = event.screenX - left
            lastY = event.screenY - top
            #console.log left, top, lastX, lastY
          'mouseup img': (event)->
            isMouseDown = false
            console.log "mouseup"
          'mousemove img': (event) ->
            if isMouseDown
              left = lastX - event.screenX
              top = event.screenY - lastY
              device = getMyDevice()
              Devices.update
                _id: device._id
              ,
                $set:
                  top: top
                  left: left
                  lastestMoved: true
        Devices.find({}).observe
          changed: (newDevice, oldDevice) ->
            if oldDevice and (newDevice.top isnt oldDevice.top or newDevice.left isnt oldDevice.left)
              device = getMyDevice()
              if newDevice._id isnt device._id
                if device.lastestMoved is true
                  Devices.update
                    _id: device._id
                  ,
                    $set:
                      lastestMoved: false
                else
                  leftOffset = newDevice.left - oldDevice.left
                  topOffset = newDevice.top - oldDevice.top
                  console.log leftOffset, topOffset
                  $('#fullsize').css
                    left: parseInt(getComputedStyle(fullsize).left) - leftOffset
                    top: parseInt(getComputedStyle(fullsize).top) + topOffset
          removed: (removedDevice) ->
            device = getMyDevice()
            if removedDevice._id isnt device._id and device.left > removedDevice.left
              $('#fullsize').animate
                left: parseInt(getComputedStyle(fullsize).left) + removedDevice.width
              ,
                done: ->
                  console.log 1
                  Devices.update
                    _id: device._id
                  ,
                  $set:
                    left: parseInt(getComputedStyle(fullsize).left)
                    lastestMoved: true



      Template.upload.events
        "change .file-input": (event, template) ->
          upload_file(event.target.files[0])

  Template.pictures.helpers
    all: ->
      Pictures.find({})

  Template.pictures.events
    "click .delete-button": ->
      Pictures.remove this._id

if Meteor.isServer
  Meteor.methods
    heartbeat: (deviceId) ->
      Devices.update
        _id: deviceId
      ,
        $set:
          ts: Date.now()

  Devices.allow
    insert: (userId, newDevice) ->
      devices = getDevicesByPictureId(newDevice.pictureId).fetch()
      if devices.length is 0
        top = 0
        left = 0
      else
        top = _.min(devices.map (d) -> d.top)
        left = _.min(devices.map (d) -> d.left)
        left += _.reduce((devices.map (d) -> d.width), ((a,b) -> a + b), 0) #sum
      newDevice.top = top
      newDevice.left = left
      true

  Meteor.publish "pictures", ->
    Pictures.find({})

  Meteor.publish "picture", (pictureId) ->
    Pictures.find(pictureId)

  Meteor.publish "devices", (pictureId) ->
    getDevicesByPictureId pictureId

  Meteor.startup ->
    Meteor.setInterval ->
      Devices.remove {ts: {$lt: Date.now() - 1000}}
      console.log Devices.find({}).fetch()
    , 1000

