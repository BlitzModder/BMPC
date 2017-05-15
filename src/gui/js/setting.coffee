{remote} = require "electron"
{app, dialog, BrowserWindow, shell} = remote
fs = remote.require("fs")
path = remote.require("path")
os = remote.require("os")
config = remote.require("./config")
cache = remote.require("./cache")
util = remote.require("./util")
lang = remote.require("./lang")

langTable = lang.get()
setLang = ->
  langTable = lang.get()
  transEle = document.getElementsByClassName("translate")
  for te in transEle
    te.textContent = langTable[te.dataset.key]
setLang()

getFolderByWindow = (func) ->
  focusedWindow = BrowserWindow.getFocusedWindow()
  dialog.showOpenDialog(focusedWindow, properties: ["openDirectory"], (directory) ->
    if directory?
      directory = directory[0] if Array.isArray(directory)
      func(directory)
  )
  return
getFileByWindow = (func) ->
  focusedWindow = BrowserWindow.getFocusedWindow()
  dialog.showOpenDialog(focusedWindow,{
    filters: [
      {name: "App Files", extensions: ["ipa", "apk", "zip"] }
      {name: "iOS App Files", extensions: ["ipa"] }
      {name: "Android App Files", extensions: ["apk"] }
      {name: "All Files", extensions: ["*"] }
    ]
    properties: ["openFile"]
  }, (file) ->
    if file?
      file = file[0] if Array.isArray(file)
      func(file)
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
  template: "<li class=\"list-group-item\"><span class=\"mr-auto\">{{formatedName}}</span><removeRepoButton @remove=\"removeRepo\"></li>"
  props: ["name", "num", "repos"]
  computed:
    formatedName: ->
      return formatRepoName(@name)
  methods:
    removeRepo: ->
      if confirm(langTable.CONFIRM_DELETE_STRING)
        @repos.splice(@num, 1)
      return
)
Vue.component("debug-repo",
  template: "<div class=\"card card-block p-1\" id=\"debugRepo\"><span class=\"mr-auto\">{{formatedName}}</span><removeRepoButton @remove=\"remove\"></div>"
  props: ["name"]
  computed:
    formatedName: ->
      return formatRepoName(@name)
  methods:
    remove: ->
      if confirm(langTable.CONFIRM_DELETE_STRING)
        @name = ""
        config.set("debugRepo", "")
      return
)
Vue.component("blitz-path",
  template: "<div class=\"card card-block p-1\" id=\"blitzFolder\">{{formatedName}}</div>"
  props: ["name"]
  computed:
    formatedName: ->
      return formatRepoName(@name)
)
Vue.component("removeRepoButton",
  template: "<button type=\"button\" class=\"close\" @click=\"$emit('remove')\"><span>&times;</span></button>"
)
new Vue(
  el: "#setting"
  data:
    remoteRepos: config.get("repos")
    localRepos: config.get("localRepos")
    debugRepo: config.get("debugRepo")
    blitzPath: config.get("blitzPath")
    blitzPathRadio: config.get("blitzPathRadio")
    blitzPathType: config.get("blitzPathType")
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
    setBlitzPathFolder: ->
      getFolderByWindow( (dir) =>
        toBlitz = dir.split(path.sep)
        if toBlitz[toBlitz.length-1] is "Data"
          toBlitz.pop()
          dir = toBlitz.join(path.sep)
        @blitzPath = dir
        @blitzPathType = "folder"
        return
      )
      return
    setBlitzPathFile: ->
      getFileByWindow( (file) =>
        @blitzPath = file
        @blitzPathType = "file"
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
      if confirm(langTable.CONFIRM_RESET_STRING)
        config.reset()
        @remoteRepos = config.get("repos")
        @localRepos = config.get("localRepos")
        @debugRepo = config.get("debugRepo")
        @blitzPath = config.get("blitzPath")
        @blitzPathType = config.get("blitzPathType")
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
    blitzPathType: (val) ->
      config.set("blitzPathType", val)
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
      setLang()
      return
)

$("#applyInfo").find("textarea").on("click", ->
  @select()
)
