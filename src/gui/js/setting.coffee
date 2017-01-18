{remote} = require "electron"
{dialog, BrowserWindow} = remote
config = remote.require("./config")
util = remote.require("./util")
fs = require "fs"


lang = config.get("lang")
langList = config.LANG_LIST
for l in langList when l isnt lang
  $(".#{l}").addClass("hidden")

getFolderByWindow = (func) ->
  focusedWindow = BrowserWindow.getFocusedWindow()
  dialog.showOpenDialog(focusedWindow, properties: ["openDirectory"], (directory) ->
    if directory?
      directory = directory[0] if Array.isArray(directory)
      func(directory)
  )
  return

Vue.component("repo",
  template: "<li class=\"list-group-item\">{{escapedName}}<removeRepoButton @remove=\"removeRepo\"></li>"
  props: ["name", "num", "repos"]
  computed:
    escapedName: ->
      return util.escape(@name)
  methods:
    removeRepo: ->
      if confirm("本当に削除してよろしいですか？")
        @repos.splice(@num, 1)
      return
)
Vue.component("debug-repo",
  template: "<div class=\"card card-block\" id=\"debugRepo\">{{escapedName}}<removeRepoButton @remove=\"remove\"></div>"
  props: ["name"]
  computed:
    escapedName: ->
      return util.escape(@name)
  methods:
    remove: ->
      if confirm("本当に削除してよろしいですか？")
        @name = ""
        config.set("debugRepo", "")
      return
)
Vue.component("blitz-path",
  template: "<div class=\"card card-block\" id=\"blitzFolder\">{{escapedName}}</div>"
  props: ["name"]
  computed:
    escapedName: ->
      return util.escape(@name)
)
Vue.component("removeRepoButton",
  template: "<button type=\"button\" class=\"remove close\" @click=\"$emit('remove')\"><span>&times;</span></button>"
)
new Vue(
  el: "#setting"
  data:
    remoteRepos: config.get("repos")
    localRepos: config.get("localRepos")
    debugRepo: config.get("debugRepo")
    blitzPath: config.get("blitzPath")
    lang: config.get("lang")
    remoteRepoAddStr: ""
    remoteRepoAddStrErr: false
  methods:
    addRemoteRepo: ->
      str = @remoteRepoAddStr
      if str isnt ""
        unless /.+\/.+\/.+/.test(str)
          @remoteRepoAddStrErr = true
          return
        @remoteRepos.push(str)
        @remoteRepoAddStr = ""
        @remoteRepoAddStrErr = false
      return
    addLocalRepo: ->
      getFolderByWindow( (dir) =>
        @localRepos.push(dir)
        return
      )
      return
    setDebugRepo: ->
      getFolderByWindow( (dir) =>
        @debugRepo = dir
        return
      )
      return
    setBlitzPath: ->
      getFolderByWindow( (dir) =>
        @blitzPath = dir
        return
      )
      return
    reset: ->
      if confirm("本当にリセットしてよろしいですか？")
        config.reset()
        @remoteRepos = config.get("repos")
        @localRepos = config.get("localRepos")
        @debugRepo = config.get("debugRepo")
        @blitzPath = config.get("blitzPath")
        @remoteRepoAddStr = ""
        @remoteRepoAddStrErr = false
      return
  watch:
    remoteRepos: (val) ->
      config.set("repos", val)
      return
    localRepos: (val) ->
      config.set("localRepos", val)
      return
    debugRepo: (val) ->
      config.set("debugRepo", val)
      return
    blitzPath: (val) ->
      config.set("blitzPath", val)
      return
    lang: (val) ->
      config.set("lang", val)
      lang = val
      $(".#{lang}").removeClass("hidden")
      for l in langList when l isnt lang
        $(".#{l}").addClass("hidden")
      return
)
