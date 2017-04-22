{remote} = require "electron"
{shell} = remote
plistList = remote.require("./plistList")
plistInfo = remote.require("./plistInfo")
util = remote.require("./util")
config = remote.require("./config")
applyMod = remote.require("./applyMod")
request = remote.require("./request")
lang = remote.require("./lang")

params = new URLSearchParams(document.location.search)
path = decodeURIComponent(params.get("path"))
repo = {type: params.get("type"), name: path}
langName = config.get("lang")

langTable = lang.get()
transEle = document.getElementsByClassName("translate")
for te in transEle
  te.textContent = langTable[te.dataset.key]

appliedMods = ->
  return config.get("appliedMods")

Vue.component("description",
  template: """
            <div class="col-12">
              <div class="card card-outline-primary card-block">
                <h4 class="card-title">{{name}}</h4>
                <h6 class="card-subtitle text-muted">{{version}}</h4>
                <p class="card-text">#{langTable.REPO_MAINTAINER}: {{maintainer}}</p>
              </div>
            </div>
            """
  props: ["name", "version", "maintainer"]
)
Vue.component("big-category",
  template: """
            <div class="col-md-6">
              <div class="card card-block">
                <h4 class="card-title">{{name}}</h4>
                <ul class="list-group">
                  <li is="small-category" v-for="(v, k) in val" :parentname="name" :name="k" :val="v"></li>
                </ul>
              </div>
            </div>
            """
  props: ["name", "val"]
)
Vue.component("small-category",
  template: """
            <li class="list-group-item flex-column align-items-start">
              <a data-toggle="collapse" :href="id">{{name}}</a>
              <div class="category collapse" :id="idName">
                <div class="list-group">
                  <button is="mod" type="button" v-for="(v, k) in val" :name="k" :val="v"></button>
                </div>
              </div>
            </li>
            """
  props: ["parentname", "name", "val"]
  computed:
    id: ->
      return "#"+@idName
    idName: ->
      return "category-"+btoa(unescape(encodeURIComponent(@parentname+@name))).replace(/=|\+|\//g, "")
)
firstExec = true
Vue.component("mod",
  template: """
            <button type="button" class="list-group-item list-group-item-action flex-column align-items-start" :class="{applied: applied}" :data-path="val" @click="show">
              <div class="form-check mb-0">
                <label class="form-check-label checkbox_text">
                  <input type="checkbox" class="form-check-input checkbox" :data-path="val" :data-name="name" v-model="checked">
                  {{name}}
                </label>
              </div>
            </button>
            """
  props: ["name", "val"]
  data: ->
    applied = (do =>
      for mod in appliedMods() when mod.repo is path
        if mod.name is @val
          return true
      return false
    )
    return {
      checked: applied
      applied: applied
    }
  computed:
    link: ->
      return request.getDetailUrl(repo, @val)
  methods:
    show: (e) ->
      t = e.target.classList
      return if t.contains("form-check-label")
      return if t.contains("form-check-input")

      detail = $("#detail")
      webview = detail.find("webview")[0]
      request.getUrlStatus(@link).then( (code) =>
        return if code is 404
        if firstExec
          webview.addEventListener("dom-ready", ready = =>
            webview.removeEventListener("dom-ready", ready)
            firstExec = false
            webview.loadURL(@link)
            return
          )
        else
          webview.loadURL(@link)
        detail.modal("show")
        return
      )
      return
)
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
  created: ->
    @getPlist().then( ->
      return r.getPlistWithOutBlackout(true)
    )
    @getInfo()
    return
  methods:
    getPlist: (force = false) ->
      @loading = true
      @error = false
      return plistList.getUntilDone(repo, langName, force).then( (obj) =>
        return plistList.filter(obj)
      ).then( (obj) =>
        @loading = false
        @plist = obj
      ).catch( (err) =>
        @loading = false
        @error = true
        @errorMsg = err
      )
    getPlistWithOutBlackout: (force = false) ->
      @error = false
      return plistList.getUntilDone(repo, langName, force).then( (obj) =>
        return plistList.filter(obj, true)
      ).then( (obj) =>
        if JSON.stringify(@plist) isnt JSON.stringify(obj)
          @plist = obj
      ).catch( (err) =>
        @error = true
        @errorMsg = err
      )
    getInfo: (force = false) ->
      return plistInfo.get(repo, force).then( (obj) =>
        @hasinfo = true
        @infoname = obj.name
        @infoversion = obj.version
        @infomaintainer = obj.maintainer
        return
      ).catch( (err) =>
        @hasinfo = false
      )
)



Vue.component("modal-body",
  template: """
            <div class="modal-body">
            <div class="modal-main">
              <p>{{message}}</p>
              <progress v-show="!finished" />
              <progress v-show="finished" value="100" max="100" />
            </div>
            <div class="modal-progress">
              <p v-html="log"></p>
            </div>
            </div>
            """
  props: ["phase", "log", "finished"]
  computed:
    message: ->
      switch @phase
        when "standby", "doing"
          return langTable.MODAL_TITLE_APPLYING
        when "done"
          return langTable.MODAL_TITLE_APPLIED
        when "failed"
          return langTable.MODAL_TITLE_FAILED
)
p = new Vue(
  el: "#progress"
  data:
    phase: "standby" #"standby"|"done"|"failed"
    log: ""
  computed:
    finished: ->
      return @phase is "done" or @phase is "failed"
  methods:
    addLog: (m, d) ->
      if @log is ""
        @log = "<b>#{util.escape(m)}</b> - #{util.escape(d)}"
      else
        @log += "<br><b>#{util.escape(m)}</b> - #{util.escape(d)}"
      return
    nextLog: ->
      @log += "<br>"
      return
    deleteLog: ->
      @log = ""
      return
    changePhase: (s) ->
      @phase = s
      return
    reset: ->
      $("#progress").modal("hide")
      @phase = "standby"
      @log = ""
      return
)

document.getElementById("reload").addEventListener("click", ->
  r.getPlist(true)
  r.getInfo(true)
  return
)

onBeforeClose = (e) ->
  if !confirm(langTable.CONFIRM_APPLY_CLOSE_STRING)
    e.returnValue = false
  return

document.getElementById("apply").addEventListener("click", ->
  if confirm(langTable.CONFIRM_APPLY_STRING)
    # 閉じる防止
    window.addEventListener("beforeunload", onBeforeClose)

    addMods = []
    deleteMods = []
    for $mod in $("button:not(.applied) input:checked")
      addMods.push({repo: repo, name: $mod.getAttribute("data-path"), showname: $mod.getAttribute("data-name")})
    for $mod in $("button.applied input:not(:checked)")
      deleteMods.push({repo: repo, name: $mod.getAttribute("data-path"), showname: $mod.getAttribute("data-name")})

    $("#progress").modal({ keyboard: false, focus: true, backdrop: "static" })
    errored = false
    applyMod.applyMods(addMods, deleteMods, (phase, type, mod, err) ->
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
    ).then( ->
      if !errored
        p.changePhase("done")
      else
        p.changePhase("failed")
      # 閉じる防止解除
      window.removeEventListener("beforeunload", onBeforeClose)
      return
    )
  return
)

webview = document.getElementById("detailweb")
webview.addEventListener("new-window", (e) ->
  shell.openExternal(e.url)
)
webview.addEventListener("will-navigate", (e) ->
  shell.openExternal(e.url)
  webview.stop()
)
