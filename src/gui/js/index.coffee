{remote, shell} = require "electron"
{app} = remote
semver = remote.require("semver")
plistInfo = remote.require("./plistInfo")
config = remote.require("./config")
request = remote.require("./request")
lang = remote.require("./lang")
util = remote.require("./util")

langTable = lang.get()
transEle = document.getElementsByClassName("translate")
for te in transEle
  te.textContent = langTable[te.dataset.key]

Vue.component("repo",
  template: """
            <li class=\"list-group-item\">
              <a :href=\"url\">
                <span v-if="hasinfo">{{infoname}} <sub><small>{{infomaintainer}}</small></sub> ({{formatedName}})</span>
                <span v-else>{{formatedName}}</span>
              </a>
            </li>
            """
  props: ["name", "repotype", "hasinfo", "infoname", "infomaintainer"]
  computed:
    formatedName: ->
      return util.formatRepoName(@name)
    url: ->
      return "./repo.html?type=#{@repotype}&path=#{encodeURIComponent(@name)}"
  created: ->
    @getInfo()
    return
  methods:
    getInfo: ->
      try
        {name, maintainer} = await plistInfo.get(type: @repotype, name: @name)
        @hasinfo = true
        @infoname = name
        @infomaintainer = maintainer
      catch
        @hasinfo = false
      return
)
Vue.component("debug-repo",
  template: "<a href=\"./debug_repo.html\">{{formatedName}}</a>"
  props: ["name"]
  computed:
    formatedName: ->
      return util.formatRepoName(@name)
)
new Vue(
  el: "#repo"
  data:
    remoteRepos: config.get("repos")
    localRepos: config.get("localRepos")
    debugRepo: config.get("debugRepo")
)

do ->
  newVer = await request.getLastestVersion()
  if semver.gt(newVer, app.getVersion())
    for tag in document.getElementsByClassName("newVersion")
      tag.textContent = newVer
    $("#update").removeClass("hidden")
  return
$("#updateLink").on("click", ->
  shell.openExternal("https://github.com/BlitzModder/BMPC/releases")
  return
)

do ->
  if config.get("blitzPathType") is "file" or !(await util.blitzExists())
    $("#play").remove()
  else
    document.getElementById("play").addEventListener("click", ->
      util.openBlitz()
      return
    )
  return
