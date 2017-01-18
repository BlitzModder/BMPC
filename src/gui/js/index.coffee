{remote} = require "electron"
config = remote.require("./config")
util = remote.require("./util")

lang = config.get("lang")
langList = config.LANG_LIST
for l in langList when l isnt lang
  $(".#{l}").addClass("hidden")

Vue.component("repo",
  template: "<li class=\"list-group-item\"><a :href=\"url\">{{escapedName}}</a></li>"
  props: ["name", "repotype"]
  computed:
    escapedName: ->
      return util.escape(@name)
    url: ->
      return "./repo.html?type=#{@repotype}&path=#{encodeURIComponent(@name)}"
)
Vue.component("debug-repo",
  template: "<a href=\"./debug_repo.html\">{{name}}</a>"
  props: ["name"]
)
new Vue(
  el: "#repo"
  data:
    remoteRepos: config.get("repos")
    localRepos: config.get("localRepos")
    debugRepo: config.get("debugRepo")
)
