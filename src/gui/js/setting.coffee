{remote} = require "electron"
{app, dialog, BrowserWindow, shell, clipboard} = remote
fs = remote.require("fs")
path = remote.require("path")
os = remote.require("os")
config = remote.require("./config")
cache = remote.require("./cache")
util = remote.require("./util")
lang = remote.require("./lang")

langTable = lang.get()
do setLang = ->
  langTable = lang.get()
  transEle = document.getElementsByClassName("translate")
  for te in transEle
    te.textContent = langTable[te.dataset.key]

getFolderByWindow = ->
  return new Promise( (resolve, reject) ->
    focusedWindow = BrowserWindow.getFocusedWindow()
    dialog.showOpenDialog(focusedWindow, properties: ["openDirectory"], (directory) ->
      if directory?
        directory = directory[0] if Array.isArray(directory)
        resolve(directory)
      else
        reject()
      return
    )
    return
  )
getFileByWindow = ->
  return new Promise( (resolve, reject) ->
    focusedWindow = BrowserWindow.getFocusedWindow()
    dialog.showOpenDialog(focusedWindow, {
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
        resolve(file)
      else
        reject()
      return
    )
  )

Vue.component("repo",
  template: "<li class=\"list-group-item\"><span class=\"mr-auto\">{{formatedName}}</span><removeRepoButton @remove=\"removeRepo\"></li>"
  props: ["name", "num", "repos"]
  computed:
    formatedName: ->
      return util.formatRepoName(@name)
  methods:
    removeRepo: ->
      if confirm(langTable.CONFIRM_DELETE_STRING)
        @repos.splice(@num, 1)
      return
)
Vue.component("debug-repo",
  template: "<div class=\"card p-1\" id=\"debugRepo\"><div class=\"card-body\"><span class=\"mr-auto\">{{formatedName}}</span><removeRepoButton @remove=\"remove\"></div></div>"
  props: ["name"]
  computed:
    formatedName: ->
      return util.formatRepoName(@name)
  methods:
    remove: ->
      if confirm(langTable.CONFIRM_DELETE_STRING)
        @name = ""
        config.set("debugRepo", "")
      return
)
Vue.component("blitz-path",
  template: "<div class=\"card\" id=\"blitzFolder\"><div class=\"card-body\">{{formatedName}}</div></div>"
  props: ["name"]
  computed:
    formatedName: ->
      return util.formatRepoName(@name)
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
      return if str is ""
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
      try
        @localRepos.push(await getFolderByWindow())
      return
    setDebugRepo: ->
      try
        @debugRepo = await getFolderByWindow()
      return
    setBlitzPathFolder: ->
      try
        dir = await getFolderByWindow()
        toBlitz = dir.split(path.sep)
        if toBlitz[toBlitz.length-1] is "Data"
          toBlitz.pop()
          dir = toBlitz.join(path.sep)
        @blitzPath = dir
        @blitzPathType = "folder"
      return
    setBlitzPathFile: ->
      try
        @blitzPath = await getFileByWindow()
        @blitzPathType = "file"
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
    copyInfo: ->
      clipboard.writeText($("#applyInfo").find("textarea").val(), "selection")
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
      return if val is "other"
      path =
        switch val
          when "win" then config.getDefaultWinBlitzPath()
          when "macsteam" then config.BLITZ_PATH.MACSTEAM
          when "macapp" then config.BLITZ_PATH.MACSTORE
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
