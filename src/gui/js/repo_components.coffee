{remote} = require "electron"
config = remote.require("./config")
request = remote.require("./request")
lang = remote.require("./lang")

isDebugRepo = location.pathname.includes("debug_repo.html")
langTable = lang.get()
appliedMods = ->
  return config.get("appliedMods")

Vue.component("description",
  template: """
            <div class="col-12">
              <div class="card border border-primary">
                <div class="card-body">
                  <h4 class="card-title" v-if="hasinfo">{{name}}</h4>
                  <h6 class="card-subtitle text-muted" v-if="hasinfo">{{version}}</h6>
                  <p class="card-text" v-if="hasinfo">#{langTable.REPO_MAINTAINER}: {{maintainer}}</p>
                  <button type="button" class="btn btn-info" v-if="hasChangelog" data-toggle="collapse" data-target="#changelog">#{langTable.REPO_CHANGELOG}</button>
                  <div class="collapse" id="changelog">
                    <div class="card card-body" v-html="changelogHtml"></div>
                  </div>
                </div>
              </div>
            </div>
            """
  props: ["hasinfo", "name", "version", "maintainer", "changelog"]
  computed:
    hasChangelog: ->
      return (@changelog isnt "")
    changelogHtml: ->
      return @changelog.replace(/\n/g, "<br>")
)
Vue.component("big-category",
  template: """
            <div class="col-md-6">
              <div class="card">
                <h4 class="card-header">{{name}}</h4>
                <ul class="list-group list-group-flush-this">
                  <li is="small-category" v-for="(v, k) in val" :parentname="name" :name="k" :val="v"></li>
                </ul>
              </div>
            </div>
            """
  props: ["name", "val"]
)
Vue.component("small-category",
  template: """
            <li class="list-group-item">
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
            <button type="button" class="list-group-item list-group-item-action inside-list-item" :class="{applied: applied}" :data-path="val.name" @click="show">
              <div class="form-check mb-0">
                <label class="form-check-label checkbox_text">
                  <input type="checkbox" class="form-check-input checkbox" :data-path="val.name" :data-name="name"v-model="checked">
                  {{name}}
                  <br>
                  <span class="debug-info font-italic text-secondary">(Ver: {{val.version}}, Plat: {{val.platform}})</span>
                </label>
              </div>
            </button>
            """
  props: ["name", "val"]
  data: ->
    applied = (do =>
      for mod in appliedMods() when mod.repo is path
        if mod.name is @val.name
          return true
      return false
    )
    return {
      checked: applied
      applied
    }
  computed:
    link: ->
      return request.getDetailUrl(repo, @val.name)
  methods:
    show: ({target}) ->
      t = target.classList
      return if t.contains("form-check-label")
      return if t.contains("form-check-input")

      detail = $("#detail")
      webview = detail.find("webview")[0]
      code = await request.getUrlStatus(@link)
      return if code is 404
      if firstExec
        webview.addEventListener("dom-ready", ready = =>
          webview.removeEventListener("dom-ready", ready)
          firstExec = false
          webview.loadURL(@link)
          return
        )
      else
        detail.on("shown.bs.modal", ready = =>
          detail.off("shown.bs.modal", ready)
          webview.loadURL(@link)
          return
        )
      detail.modal("show")
      return
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
  r.getChangelog()
  return
)

webview = document.getElementById("detailweb")
webview.addEventListener("new-window", ({url}) ->
  shell.openExternal(url)
)
webview.addEventListener("will-navigate", ({url}) ->
  shell.openExternal(url)
  webview.stop()
)
