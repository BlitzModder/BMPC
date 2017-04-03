{remote} = require "electron"
{app, dialog, BrowserWindow, shell} = remote
config = remote.require("./config")
cache = remote.require("./cache")
util = remote.require("./util")
fs = require "fs"
os = require "os"
path = remote.require("path")

lang = config.get("lang")
langList = config.LANG_LIST
for l in langList when l isnt lang
  $(".#{l}").addClass("hidden")
switch lang
  when "ja"
    CONFIRM_DELETE_STRING = "本当に削除してよろしいですか？"
    CONFIRM_RESET_STRING = "本当にリセットしてよろしいですか？"
  when "en"
    CONFIRM_DELETE_STRING = "Really want to delete?"
    CONFIRM_RESET_STRING = "Really want to reset?"
  when "ru"
    CONFIRM_DELETE_STRING = "Действительно хотите удалить?"
    CONFIRM_RESET_STRING = "На самом деле хотите сбросить?"
  else
    CONFIRM_DELETE_STRING = "UNLOCALIZED_CONFIRM_DELETE_STRING"
    CONFIRM_RESET_STRING = "UNLOCALIZED_RESET_DELETE_STRING"

getFolderByWindow = (func) ->
  focusedWindow = BrowserWindow.getFocusedWindow()
  dialog.showOpenDialog(focusedWindow, properties: ["openDirectory"], (directory) ->
    if directory?
      directory = directory[0] if Array.isArray(directory)
      func(directory)
  )
  return

formatRepoName = (name) ->
  m = /^https?:\/\/github\.com\/(.+?)\/(.+?)\/raw\/master$/.exec(name)
  if m?
    return "#{m[1]}/#{m[2]} (#{name})"
  m = /^https?:\/\/(.+?)\.github\.io\/(.+?)$/.exec(name)
  if m?
    return "#{m[1]}/#{m[2]} (#{name})"
  m = /^https?:\/\/(.+?)$/.exec(name)
  if m?
    return "#{m[1]} (#{name})"
  return name

Vue.component("repo",
  template: "<li class=\"list-group-item\">{{formatedName}}<removeRepoButton @remove=\"removeRepo\"></li>"
  props: ["name", "num", "repos"]
  computed:
    formatedName: ->
      return formatRepoName(@name)
  methods:
    removeRepo: ->
      if confirm(CONFIRM_DELETE_STRING)
        @repos.splice(@num, 1)
      return
)
Vue.component("debug-repo",
  template: "<div class=\"card card-block\" id=\"debugRepo\">{{formatedName}}<removeRepoButton @remove=\"remove\"></div>"
  props: ["name"]
  computed:
    formatedName: ->
      return formatRepoName(@name)
  methods:
    remove: ->
      if confirm(CONFIRM_DELETE_STRING)
        @name = ""
        config.set("debugRepo", "")
      return
)
Vue.component("blitz-path",
  template: "<div class=\"card card-block\" id=\"blitzFolder\">{{formatedName}}</div>"
  props: ["name"]
  computed:
    formatedName: ->
      return formatRepoName(@name)
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
    blitzPathRadio: config.get("blitzPathRadio")
    platform: config.get("platform")
    lang: config.get("lang")
    remoteRepoAddStr: ""
    remoteRepoAddStrErr: false
    appName: app.getName()
    version: app.getVersion()
  methods:
    addRemoteRepo: ->
      str = @remoteRepoAddStr
      err = false
      if str isnt ""
        if str.startsWith("http:") or str.startsWith("https:")
          if str.endsWith("/")
            @remoteRepos.push(str.slice(0, -1))
          else
            @remoteRepos.push(str)
        else
          s = str.split("/")
          switch s.length
            when 1
              @remoteRepos.push("https://github.com/#{str}/BMRepository/raw/master")
            when 2
              @remoteRepos.push("https://github.com/#{str}/raw/master")
            else
              err = true
        if err
          @remoteRepoAddStrErr = true
        else
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
        toBlitz = dir.split(path.sep)
        if toBlitz[toBlitz.length-1] is "Data"
          toBlitz.pop()
          dir = toBlitz.join(path.sep)
        @blitzPath = dir
        return
      )
      return
    clearCache: ->
      cache.clear()
      return
    openConfigFolder: ->
      shell.showItemInFolder(config.GENERAL_CONFIG_PATH)
      return
    reset: ->
      if confirm(CONFIRM_RESET_STRING)
        config.reset()
        @remoteRepos = config.get("repos")
        @localRepos = config.get("localRepos")
        @debugRepo = config.get("debugRepo")
        @blitzPath = config.get("blitzPath")
        @remoteRepoAddStr = ""
        @remoteRepoAddStrErr = false
      return
    applyInfo: ->
      $("#applyInfo").find("textarea").val(
        "---BlitzModderPC ApplyInformation---\n"+
        "+DeviceInformation\n"+
        "BlitzModderVersion: #{app.getVersion()}\n"+
        "OS: #{os.platform()}\n"+
        "Arch: #{os.arch()}\n"+
        "UserAgent: #{window.navigator.userAgent}\n"+
        "ApplyPlatform: #{config.get("platform")}\n"+
        "+AppliedMods\n"+
        JSON.stringify(config.get("appliedMods"))
      )
      $("#applyInfo").modal()
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
    blitzPathRadio: (val) ->
      config.set("blitzPathRadio", val)
      if val isnt "other"
        switch val
          when "win" then path = config.getDefaultWinBlitzPath()
          when "macsteam" then path = config.BLITZ_PATH.MACSTEAM
          when "macapp" then path = config.BLITZ_PATH.MACSTORE
        config.set("blitzPath", path)
        @blitzPath = path
      return
    platform: (val) ->
      config.set("platform", val)
      return
    lang: (val) ->
      config.set("lang", val)
      lang = val
      $(".#{lang}").removeClass("hidden")
      for l in langList when l isnt lang
        $(".#{l}").addClass("hidden")
      return
)

$("#applyInfo").find("textarea").on("click", ->
  @select()
)
