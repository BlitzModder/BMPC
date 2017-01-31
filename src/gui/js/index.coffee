{remote, shell} = require "electron"
{app} = remote
semver = remote.require("semver")
config = remote.require("./config")
request = remote.require("./request")
util = remote.require("./util")

lang = config.get("lang")
langList = config.LANG_LIST
for l in langList when l isnt lang
  $(".#{l}").addClass("hidden")

formatRepoName = (name) ->
  m = /^https?:\/\/github\.com\/(.+?)\/(.+?)\/raw\/master$/.exec(name)
  if m?
    return "#{m[1]}/#{m[2]}"
  m = /^https?:\/\/(.+?)\.github\.io\/(.+?)$/.exec(name)
  if m?
    return "#{m[1]}/#{m[2]}"
  return name

Vue.component("repo",
  template: "<li class=\"list-group-item\"><a :href=\"url\">{{formatedName}}</a></li>"
  props: ["name", "repotype"]
  computed:
    formatedName: ->
      return formatRepoName(@name)
    url: ->
      return "./repo.html?type=#{@repotype}&path=#{encodeURIComponent(@name)}"
)
Vue.component("debug-repo",
  template: "<a href=\"./debug_repo.html\">{{formatedName}}</a>"
  props: ["name"]
  computed:
    formatedName: ->
      return formatRepoName(@name)
)
new Vue(
  el: "#repo"
  data:
    remoteRepos: config.get("repos")
    localRepos: config.get("localRepos")
    debugRepo: config.get("debugRepo")
)

request.getLastestVersion().then( (newVer) ->
  if semver.gt(newVer, app.getVersion())
    for tag in document.getElementsByClassName("newVersion")
      tag.textContent = newVer
    $("#update").removeClass("hidden")
  return
)
$("#updateLink").on("click", ->
  shell.openExternal("https://github.com/BlitzModder/BMPC/releases")
  return
)
