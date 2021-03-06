Pictures = new Meteor.Collection 'pictures'
Devices = new Meteor.Collection 'devices'

getDevicesByPictureId = (pictureId) ->
  Devices.find({pictureId: pictureId})

getPictureUrlById = (pictureId) ->
  port = if window.location.port then ":" + window.location.port else ''
  "http://#{window.location.hostname}#{port}/#{pictureId}"

updateDeviceInfo = (pictureId) ->
  devices = getDevicesByPictureId(pictureId).fetch()

uploadFile = (file) ->
  AV.initialize("5m9xcgs9px1w68dfhoixe3px9ol7kjzbhdbo30mvbybzx5ht", "q9bhxqjx4nlm4sq8vcqbucot7l9e19p47s8elywqn34fchtj")
  avFile = new AV.File("dummy_file", file)
  avFile.save().then (saved_file) ->
    url = saved_file.url()
    pictureId = Pictures.insert
      url: url
      createdAt: Date.now()
  , (error) ->
    alert("error")

getDeviceIconByUserAgent = (userAgent) ->
  if userAgent.indexOf("iPad") isnt -1
    return "/images/pad@2x.png"
  if userAgent.indexOf("iOS") isnt -1
    return "/images/phone@2x.png"
  if userAgent.indexOf("Android") isnt -1
    return "/images/phone@2x.png"
  else
    return "/images/mac@2x.png"

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
        Meteor.clearInterval(intervalId) if intervalId
        Session.set 'myDeviceId', undefined

    @route 'about',
        path: '/about'
        template: 'about'

    @route 'share',
      waitOn: ->
       Meteor.subscribe('picture', @params.picture_id) and
       Meteor.subscribe('devices', @params.picture_id)
      path: '/:picture_id/share'
      template: 'share'
      data: ->
        currentPictureId = @params.picture_id
        Template.qr.rendered = ->
          picUrl = getPictureUrlById currentPictureId
          $('#qrcode').qrcode
            text: picUrl
            width: 240
            height: 240

        Template.share.helpers
          picture: ->
            Pictures.findOne currentPictureId
          devices: ->
            getDevicesByPictureId currentPictureId

      Template.device.helpers
        iconUrl: ->
          getDeviceIconByUserAgent @userAgent

    @route 'picture',
      waitOn: ->
       Meteor.subscribe('picture', @params.picture_id) and
       Meteor.subscribe('devices', @params.picture_id)
      path: '/:picture_id'
      template: 'picture'
      data: ->
        currentPictureId = @params.picture_id

        unless Session.get 'myDeviceId'
          myDeviceId = Devices.insert
            pictureId: currentPictureId
            width: jQuery(window).width()
            height: jQuery(window).height()
            top: 0
            left: 0
            userAgent: window.navigator.userAgent
          Session.set 'intervalId', Meteor.setInterval ->
            Meteor.call('heartbeat', myDeviceId)
          , 200
          Session.set 'myDeviceId', myDeviceId

        isMouseDown = false
        startX = startY = lastX = lastY = 0
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
            Pictures.findOne(currentPictureId)

          getLeft: ->
            -getMyDevice().left or 0

          getTop: ->
            getMyDevice().top or 0

        Template.picture.events
          'dragstart img': (event) ->
            event.preventDefault()
          'mousedown img': (event) ->
            isMouseDown = true
            left = parseCssInt(event.target, 'left')
            top = parseCssInt(event.target, 'top')
            lastX = event.screenX - left
            lastY = event.screenY - top
          'mouseup img': (event)->
            isMouseDown = false
            device = getMyDevice()
            Devices.update
              _id: device._id
            ,
              $set:
                mouseUp: true
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
                  shouldChange: true
                  mouseUp: false

        Template.pictures.rendered = ->
            $('body').css("overflow", "auto")
        Template.picture.rendered = ->
            $('body').css("overflow", "hidden")

        Devices.find({}).observe
          changed: (newDevice, oldDevice) ->
            if oldDevice and newDevice.mouseUp isnt oldDevice.mouseUp and newDevice.mouseUp
              device = getMyDevice()
              if newDevice._id isnt device._id
                Devices.update
                  _id: device._id
                ,
                  $set:
                    shouldChange: false
                    mouseUp: false
                    left: -parseInt(getComputedStyle(fullsize).left)
                    top: parseInt(getComputedStyle(fullsize).top)

            if oldDevice and (newDevice.top isnt oldDevice.top or newDevice.left isnt oldDevice.left) and newDevice.shouldChange
              device = getMyDevice()
              if newDevice._id isnt device._id
                if device.shouldChange is true
                  Devices.update
                    _id: device._id
                  ,
                    $set:
                      shouldChange: false
                else
                  leftOffset = newDevice.left - oldDevice.left
                  topOffset = newDevice.top - oldDevice.top
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
                  Devices.update
                    _id: device._id
                  ,
                    $set:
                      left: parseInt(getComputedStyle(fullsize).left)
                      shouldChange: false

      Template.upload.events
        "change .file-input": (event, template) ->
          uploadFile(event.target.files[0])
        "click form": (event) ->
          target = event.target
          $('input', target).trigger "click"
        "click p": (event) ->
          target = event.target
          $(target).next().trigger "click"

  Template.pictures.helpers
    all: ->
      Pictures.find({})

  Template.pictures.events
    "click img.delete": ->
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

      newDevice.ts = Date.now()
      newDevice.top = top
      newDevice.left = left
      true

    update: -> true

  Meteor.publish "pictures", ->
    Pictures.find({}, sort: {createdAt: -1})

  Meteor.publish "picture", (pictureId) ->
    Pictures.find(pictureId)

  Meteor.publish "devices", (pictureId) ->
    getDevicesByPictureId pictureId

  Meteor.startup ->
    Meteor.setInterval ->
      Devices.remove {ts: {$lt: Date.now() - 1000}}
      console.log Devices.find({}).fetch()
    , 1000
