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
      data: ->
        currentPicture = Pictures.findOne({_id: @params.picture_id})
        Template.picture.helpers
          picture: ->
            currentPicture

  Template.pictures.helpers
    all: ->
      Pictures.find({})


if Meteor.isServer
  Pictures.remove {}
  Pictures.insert
    url: "http://bbs.c114.net/uploadImages/200412912265686500.jpg"
  Pictures.insert
    url: "http://image.tianjimedia.com/uploadImages/2012/353/4Q530MU50I69_glaciers1.jpg"
  Pictures.insert
    url: "http://pic.putaojiayuan.com/uploadfile/tuku/WuFengQuanGing/12190330244885.jpg"

