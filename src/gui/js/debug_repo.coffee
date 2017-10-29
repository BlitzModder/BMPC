{remote} = require "electron"
{shell} = remote
plistList = remote.require("./plistList")
plistInfo = remote.require("./plistInfo")
util = remote.require("./util")
config = remote.require("./config")
applyMod = remote.require("./applyMod")
request = remote.require("./request")
lang = remote.require("./lang")

path = config.get("debugRepo")
repo =
  type: "local"
  name: path
langName = config.get("lang")

langTable = lang.get()
transEle = document.getElementsByClassName("translate")
for te in transEle
  te.textContent = langTable[te.dataset.key]

r = new Vue(
  el: "#root"
  data:
    loading: false
    error: false
    errorMsg: ""
    plist: {}
    hasinfo: false
    infoname: ""
    infoversion: ""
    infomaintainer: ""
    changelog: ""
  created: ->
    do =>
      await @getPlist()
      await r.getPlistWithOutBlackout(true)
      return
    @getInfo()
    @getChangelog()
    return
  methods:
    getPlist: (force = false) ->
      @loading = true
      @error = false
      try
        obj = await plistList.getUntilDone(repo, langName, force)
        @loading = false
        @plist = obj
      catch err
        @loading = false
        @error = true
        @errorMsg = err
      return
    getPlistWithOutBlackout: (force = false) ->
      @error = false
      try
        obj = await plistList.getUntilDone(repo, langName, force)
        if JSON.stringify(@plist) isnt JSON.stringify(obj)
          @plist = obj
      catch err
        @error = true
        @errorMsg = err
      return
    getInfo: (force = false) ->
      try
        {name, version, maintainer} = await plistInfo.get(repo, force)
        @hasinfo = true
        @infoname = name
        @infoversion = version
        @infomaintainer = maintainer
      catch
        @hasinfo = false
      return
    getChangelog: ->
      @changelog = await request.getChangelog(repo)
      return
)

onBeforeClose = (e) ->
  if !confirm(langTable.CONFIRM_APPLY_CLOSE_STRING)
    e.returnValue = false
  return

document.getElementById("apply").addEventListener("click", ->
  return unless confirm(langTable.CONFIRM_APPLY_STRING)
  # 閉じる防止
  window.addEventListener("beforeunload", onBeforeClose)

  addMods = []
  deleteMods = []
  for $mod in $("button:not(.applied) input:checked")
    addMods.push({repo, name: $mod.dataset.path, showname: $mod.dataset.name})
  for $mod in $("button.applied input:not(:checked)")
    deleteMods.push({repo, name: $mod.dataset.path, showname: $mod.dataset.name})

  $("#progress").modal({ keyboard: false, focus: true, backdrop: "static" })
  errored = false
  await applyMod.applyMods(addMods, deleteMods, (phase, type, mod, err) ->
    if phase is "done"
      $button = $("button[data-path=\"#{mod.name}\"]")
      switch type
        when "add"
          $button.addClass("applied")
          p.addLog(mod.showname, langTable.MODAL_LOG_APPLIED)
        when "delete"
          $button.removeClass("applied")
          p.addLog(mod.showname, langTable.MODAL_LOG_REMOVED)
    else if phase is "fail"
      $checkbox = $("button[data-path=\"#{mod.name}\"]").find("input")
      errored = true
      switch type
        when "add"
          p.addLog(mod.showname, langTable.MODAL_LOG_FAILED_APPLY+"(#{err})")
          $checkbox.prop("checked", false)
        when "delete"
          p.addLog(mod.showname, langTable.MODAL_LOG_FAILED_REMOVE+"(#{err})")
          $checkbox.prop("checked", true)
    else
      switch phase
        when "download"
          p.addLog(mod.showname, langTable.MODAL_LOG_DOWNLOAD_START)
        when "downloaded"
          p.addLog(mod.showname, langTable.MODAL_LOG_DOWNLOAD_FINISH)
        when "copydir"
          p.addLog(mod.showname, langTable.MODAL_LOG_COPY_START)
        when "zipextract"
          p.addLog(mod.showname, langTable.MODAL_LOG_EXTRACT_START)
        when "zipextracted"
          p.addLog(mod.showname, langTable.MODAL_LOG_EXTRACT_FINISH)
        when "tempdone"
          p.addLog(mod.showname, langTable.MODAL_LOG_TEMP_DONE)
        when "zipcompress"
          p.addLog(mod.showname, langTable.MODAL_LOG_COMPRESS_START)
        when "zipcompressed"
          p.addLog(mod.showname, langTable.MODAL_LOG_COMPRESS_FINISH)
    return
  )
  if !errored
    p.changePhase("done")
  else
    p.changePhase("failed")
  # 閉じる防止解除
  window.removeEventListener("beforeunload", onBeforeClose)
  return
)
