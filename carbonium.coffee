Pictures = new Meteor.Collection 'pictures'
Devices = new Meteor.Collection 'devices'

getDevicesByPicture = (picture) ->
  Devices.find({pictureId: picture._id})

if Meteor.isClient
  Template.upload.events
    "change .file-input": (event, template) ->
      upload_file(event.target)
  Router.configure {}
  Router.map ->
    @route 'welcome',
      path: '/'
      template: 'pictures'
    @route 'picture',
      path: '/:picture_id'
      template: 'picture'
      data: ->
        isMouseDown = false
        startX = startY = lastX = lastY = 0
        currentPictureId = @params.picture_id
        parseCssInt = (target, selector) ->
          parseInt $(target).css(selector).replace("px", "").replace("auto", "0")

        Template.picture.helpers
          picture: ->
            currentPicture = Pictures.findOne(currentPictureId)
            unless Session.get 'myDeviceId'
              myDeviceId = Devices.insert
                pictureId: currentPictureId
                online: true
                width: jQuery(window).width()
                height: jQuery(window).height()
                top: null
                left: null
              Session.set 'myDeviceId', myDeviceId
              Meteor.setInterval ->
                Meteor.call('heartbeat', myDeviceId)
              , 500
            return currentPicture

          myDevices: ->
            Devices.findOne({_id: Session.get('myDeviceId')})
        Template.picture.helpers
          picture: ->
            Pictures.findOne _id: currentPictureId
        Template.picture.events
          'dragstart img': (event) ->
            event.preventDefault()
          'mousedown img': (event) ->
            isMouseDown = true
            left = parseCssInt(event.target, 'left')
            top = parseCssInt(event.target, 'top')
            lastX = event.screenX - left
            lastY = event.screenY - top
            console.log left, top, lastX, lastY
          'mouseup img': (event)->
            isMouseDown = false
            console.log "mouseup"
          'mousemove img': (event) ->
            if isMouseDown
              left = event.screenX - lastX
              top = event.screenY - lastY
              target = event.target
              $(target).css
                left:  left + 'px'
                top: top + 'px'

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
  if Pictures.find({}).fetch().length is 0
    Pictures.insert
      url: "http://bbs.c114.net/uploadImages/200412912265686500.jpg"
    Pictures.insert
      url: "http://image.tianjimedia.com/uploadImages/2012/353/4Q530MU50I69_glaciers1.jpg"
    Pictures.insert
      url: "http://pic.putaojiayuan.com/uploadfile/tuku/WuFengQuanGing/12190330244885.jpg"

  Meteor.setInterval ->
    Devices.remove {ts: {$lt: Date.now() - 2000}}
    console.log Devices.find({}).fetch()
  , 1000

upload_file = (target) ->
  file = target.files[0]
  AV.initialize("5m9xcgs9px1w68dfhoixe3px9ol7kjzbhdbo30mvbybzx5ht", "q9bhxqjx4nlm4sq8vcqbucot7l9e19p47s8elywqn34fchtj")
  avFile = new AV.File("dummy_file", file);
  window.avFile = avFile
  avFile.save().then (saved_file) ->
    Pictures.insert
      url: saved_file.url()
  , (error) ->
    alert("error")
