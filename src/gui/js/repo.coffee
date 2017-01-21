{remote} = require "electron"
plist = remote.require("./plist")
util = remote.require("./util")
config = remote.require("./config")
applyMod = remote.require("./applyMod")

params = new URLSearchParams(document.location.search)
path = decodeURIComponent(params.get("path"))
repo = {type: params.get("type"), name: path}
lang = config.get("lang")
appliedMods = ->
  return config.get("appliedMods")

lang = config.get("lang")
langList = config.LANG_LIST
for l in langList when l isnt lang
  $(".#{l}").addClass("hidden")

Vue.component("big-category",
  template: """
            <div class="col-xs">
              <div class="card card-block">
                <h4 class="card-title">{{escapedName}}</h4>
                <ul class="list-group">
                  <li is="small-category" v-for="(v, k) in val" :parentname="name" :name="k" :val="v"></li>
                </ul>
              </div>
            </div>
            """
  props: ["name", "val"]
  computed:
    escapedName: ->
      return util.escape(@name)
)
Vue.component("small-category",
  template: """
            <li class="list-group-item">
              <a data-toggle="collapse" :href="id">{{escapedName}}</a>
              <div class="collapse" :id="idName">
                <ul class="list-group">
                  <li is="mod" v-for="(v, k) in val" :name="k" :val="v"></li>
                </ul>
              </div>
            </li>
            """
  props: ["parentname", "name", "val"]
  computed:
    escapedName: ->
      return util.escape(@name)
    id: ->
      return "#"+@idName
    idName: ->
      return "category-"+btoa(unescape(encodeURIComponent(@parentname+@name))).replace(/=|\+|\//g, "")
)
Vue.component("mod",
  template: """
            <li class="list-group-item">
              <div class="form-check">
                <label class="form-check-label">
                  <input type="checkbox" class="form-check-input" :class="{applied: applied}" :data-path="val" v-model="checked">
                  {{escapedName}}
                </label>
              </div>
            </li>
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
    escapedName: ->
      return util.escape(@name)
)
r = new Vue(
  el: "#root"
  data:
    loading: false
    error: false
    plist: {}
  methods:
    get: ->
      @loading = true
      @error = false
      plist.get(repo, lang).then( (obj) =>
        return plist.filter(obj)
      ).then( (obj) =>
        @loading = false
        @plist = obj
      ).catch( =>
        @loading = false
        @error = true
      )
      return
)
r.get()

Vue.component("modal-body",
  template: """
            <div class="modal-body">
            <div class="modal-main">
              <p>{{message}}</p>
              <progress v-show="!finished" />
              <progress v-show="finished" value="100" max="100" />
            </div>
            <div class="modal-progress">
              {{log}}
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
          if lang is "ja"
            return "適応中..."
          if lang is "en"
            return "Applying..."
        when "done"
          if lang is "ja"
            return "適応完了"
          if lang is "en"
            return "Applied Successfully"
        when "failed"
          if lang is "ja"
            return "適応失敗"
          if lang is "en"
            return "Failed to Apply"
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
        @log = s
      else
        @log += "\n#{s}"
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
  r.get()
  return
)
document.getElementById("apply").addEventListener("click", ->
  addMods = []
  deleteMods = []
  for $mod in $("input:checked").not(".applied")
    addMods.push({repo: repo, name: $mod.getAttribute("data-path")})
  for $mod in $("input.applied").not(":checked")
    deleteMods.push({repo: repo, name: $mod.getAttribute("data-path")})

  $("#progress").modal({ keyboard: false, backdrop: "static" })
  applyMod.applyMods(addMods, deleteMods, (done, type, mod, err) ->
    $checkbox = $("input[data-path=\"#{mod.name}\"]")
    if done
      switch type
        when "add"
          $checkbox.addClass("applied")
          if lang is "ja"
            p.addLog("#{mod.name} - 適応完了")
          else if lang is "en"
            p.addLog("#{mod.name} - Applied Successfully")
        when "delete"
          $checkbox.removeClass("applied")
          if lang is "ja"
            p.addLog("#{mod.name} - 解除完了")
          else if lang is "en"
            p.addLog("#{mod.name} - Removed Successfully")
    else
      switch type
        when "add"
          if lang is "ja"
            p.addLog("#{mod.name} - 適応失敗(#{err})")
          else if lang is "en"
            p.addLog("#{mod.name} - Failed to Apply(#{err})")
        when "delete"
          if lang is "ja"
            p.addLog("#{mod.name} - 解除失敗(#{err})")
          else if lang is "en"
            p.addLog("#{mod.name} - Failed to Remove(#{err})")
    return
  ).then( ->
    p.changePhase("done")
  ).catch( ->
    p.changePhase("failed")
  )
  return
)
