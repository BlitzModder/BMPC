fs = require "fs-extra"
path = require "path"
plist = require "plist"
Promise = require "promise"
request = require "./request"
cache = require "./cache"
config = require "./config"
util = require "./util"

readFile = Promise.denodeify(fs.readFile)

###*
 * データ
 ###
data = {}

###*
 * エラー出力
 * @private
 ###
_outputError = (err) ->
  console.error("Error: #{err}") if err?
  return

###*
 * 使いやすいように変形します
 * @param {Object} plist.parse()で変換したもの
 * @return {Object}
 ###
parse = (plistObj) ->
  obj = {}
  for key, val of plistObj
    [name, id] = key.split(":")
    obj[name] = {}
    for k, v of val
      [n, i] = k.split(":")
      obj[name][n] = {}
      for k_, v_ of v
        [n_, i_] = k_.split(":")
        if v_? and v_ isnt ""
          [version, platform] = v_.split(":")
        else
          [version, platform] = ["", ""]
        obj[name][n][n_] =
          name: "#{id}.#{i}.#{i_}"
          version: version
          platform: platform
  return obj

###*
 * plistを取得してパースしたものを返します
 * @param {"remote"|"local"} repoType
 * @param {string} repoName
 * @param {string} lang
 * @param {boolean} force キャッシュを無視して元ファイルを取得するか 既定値は"false"
 * @return {Object} plistのオブジェクト
 ###
get = ({type: repoType, name: repoName}, lang, force = false) ->
  return new Promise( (resolve, reject) ->
    if data[repoName]?[lang]? and !force
      resolve(data[repoName][lang])
      return
    cache.getStringFile(repoName, "#{lang}.plist", force).then( (content) ->
      data[repoName] = {} if !data[repoName]?
      data[repoName][lang] = parse(plist.parse(content))
      resolve(data[repoName][lang])
      return
    , (err) ->
      if repoType is "remote"
        request.getFromGitHub(repoName, "#{lang}.plist").then( (content) ->
          string = content.toString()
          cache.setStringFile(repoName, "#{lang}.plist", string)
          data[repoName] = {} if !data[repoName]?
          data[repoName][lang] = parse(plist.parse(string))
          resolve(data[repoName][lang])
          return
        , (err) ->
          reject(err)
          return
        )
      else if repoType is "local"
        readFile(path.join(repoName, "#{lang}.plist"), "utf8").then( (res) ->
          cache.setStringFile(repoName, "#{lang}.plist", res)
          data[repoName] = {} if !data[repoName]?
          data[repoName][lang] = parse(plist.parse(res))
          resolve(data[repoName][lang])
          return
        , (err) ->
          reject(err)
          return
        )
      else
        reject()
      return
    )
  )

###*
 * バージョン/端末でフィルタをかけます
 * @param {Object} parse()で変換したもの
 * @return {Object}
 ###
filter = (parsedObj) ->
  return new Promise( (resolve, reject) ->
    util.getVersion().then( (ver) ->
      return {ok: true, ver}
    , (err) ->
      return {ok: false}
    ).then( ({ok, ver}) ->
      plat = config.get("platform")
      obj = {}
      for k1, v1 of parsedObj
        for k2, v2 of v1
          for k3, v3 of v2
            if (
              (!ok or v3.version is ver) and
              v3.platform.includes(plat)
            )
              obj[k1] = {} if !obj[k1]?
              obj[k1][k2] = {} if !obj[k1][k2]?
              obj[k1][k2][k3] = v3.name
      resolve(obj)
      return
    ).catch( (err) ->
      reject(err)
      return
    )
    return
  )

module.exports =
  get: get
  filter: filter

