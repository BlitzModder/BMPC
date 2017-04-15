{remote, shell} = require "electron"
plistList = remote.require("./plistList")
plistInfo = remote.require("./plistInfo")
util = remote.require("./util")
config = remote.require("./config")
applyMod = remote.require("./applyMod")
request = remote.require("./request")

params = new URLSearchParams(document.location.search)
path = decodeURIComponent(params.get("path"))
repo = {type: params.get("type"), name: path}
lang = config.get("lang")
switch lang
  when "ja"
    CONFIRM_APPLY_STRING = "本当に適用してよろしいですか？"
  when "en"
    CONFIRM_APPLY_STRING = "Really want to apply?"
  when "ru"
    CONFIRM_APPLY_STRING = "На самом деле хотите, чтобы подать заявление?"
  else
    CONFIRM_APPLY_STRING = "UNLOCALIZED_CONFIRM_APPLY_STRING"
appliedMods = ->
  return config.get("appliedMods")

lang = config.get("lang")
langList = config.LANG_LIST
for l in langList when l isnt lang
  $(".#{l}").addClass("hidden")

Vue.component("description",
  template: """
            <div class="col-12">
              <div class="card card-outline-primary card-block">
                <h4 class="card-title">{{name}}</h4>
                <h6 class="card-subtitle text-muted">{{version}}</h4>
                <p class="card-text">Maintainer: {{maintainer}}</p>
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
          webview.addEventListener("dom-ready",ready = =>
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
      return plistList.getUntilDone(repo, lang, force).then( (obj) =>
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
      return plistList.getUntilDone(repo, lang, force).then( (obj) =>
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
  props: ["phase", "log"]
  computed:
    finished: ->
      return @phase is "done" or @phase is "failed"
    message: ->
      switch @phase
        when "standby", "doing"
          switch lang
            when "ja" then return "適用中..."
            when "en" then return "Applying..."
            when "ru" then return "Применение..."
        when "done"
          switch lang
            when "ja" then return "適用完了"
            when "en" then return "Applied Successfully"
            when "ru" then return "Применено успешно"
        when "failed"
          switch lang
            when "ja" then return "適用失敗"
            when "en" then return "Failed to Apply"
            when "ru" then return "Не удалось применить"
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
    addLog: (s) ->
      if @log is ""
        @log = util.escape(s)
      else
        @log += "<br>#{util.escape(s)}"
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
      @phase = "standby"
      @log = ""
      return
)

document.getElementById("reload").addEventListener("click", ->
  r.getPlist(true)
  r.getInfo(true)
  return
)
document.getElementById("apply").addEventListener("click", ->
  if confirm(CONFIRM_APPLY_STRING)
    addMods = []
    deleteMods = []
    for $mod in $("button:not(.applied) input:checked")
      addMods.push({repo: repo, name: $mod.getAttribute("data-path"), showname: $mod.getAttribute("data-name")})
    for $mod in $("button.applied input:not(:checked)")
      deleteMods.push({repo: repo, name: $mod.getAttribute("data-path"), showname: $mod.getAttribute("data-name")})

    $("#progress").modal({ keyboard: false, backdrop: "static" })
    errored = false
    applyMod.applyMods(addMods, deleteMods, (phase, type, mod, err) ->
      if phase is "done"
        $button = $("button[data-path=\"#{mod.name}\"]")
        switch type
          when "add"
            $button.addClass("applied")
            switch lang
              when "ja" then p.addLog("#{mod.showname} - 適用完了")
              when "en" then p.addLog("#{mod.showname} - Applied Successfully")
              when "ru" then p.addLog("#{mod.showname} - Применено успешно")
          when "delete"
            $button.removeClass("applied")
            switch lang
              when "ja" then p.addLog("#{mod.showname} - 解除完了")
              when "en" then p.addLog("#{mod.showname} - Removed Successfully")
              when "ru" then p.addLog("#{mod.showname} - Удалено успешно")
      else if phase is "fail"
        $button = $("button[data-path=\"#{mod.name}\"]")
        errored = true
        switch type
          when "add"
            switch lang
              when "ja" then p.addLog("#{mod.showname} - 適用失敗(#{err})")
              when "en" then p.addLog("#{mod.showname} - Failed to Apply(#{err})")
              when "ru" then p.addLog("#{mod.showname} - Не удалось применить(#{err})")
          when "delete"
            switch lang
              when "ja" then p.addLog("#{mod.showname} - 解除失敗(#{err})")
              when "en" then p.addLog("#{mod.showname} - Failed to Remove(#{err})")
              when "ru" then p.addLog("#{mod.showname} - Не удалось удалить(#{err})")
      return
    ).then( ->
      if !errored
        p.changePhase("done")
      else
        p.changePhase("failed")
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
