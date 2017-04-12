fs = require "fs-extra"
path = require "path"
plist = require "plist"
Promise = require "promise"
semver = require "semver"
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
 * plistを取得できるまで取得(言語順)
 * @param {repo: "remote"|"local", name: string} repo
 * @param {string} lang
 * @param {boolean} force キャッシュを無視して元ファイルを取得するか 既定値は"false"
 * @return {Object} plistのオブジェクト
 ###
getUntilDone = (repo, lang, force = false) ->
  return get(repo, lang, force).catch( ->
    return get(repo, "en", force)
  ).catch( ->
    return get(repo, "ja", force)
  ).catch( ->
    return get(repo, "ru", force)
  )

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
    cache.getStringFile(repoName, "plist/#{lang}.plist", force).then( (content) ->
      data[repoName] = {} if !data[repoName]?
      data[repoName][lang] = parse(plist.parse(content))
      resolve(data[repoName][lang])
      return
    , (err) ->
      if repoType is "remote"
        request.getFromRemote(repoName, "plist/#{lang}.plist").then( (content) ->
          string = content.toString()
          cache.setStringFile(repoName, "plist/#{lang}.plist", string)
          data[repoName] = {} if !data[repoName]?
          data[repoName][lang] = parse(plist.parse(string))
          resolve(data[repoName][lang])
          return
        , (err) ->
          reject(err)
          return
        )
      else if repoType is "local"
        readFile(path.join(repoName, "plist/#{lang}.plist"), "utf8").then( (res) ->
          cache.setStringFile(repoName, "plist/#{lang}.plist", res)
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

_is_needed = (ok, ver, plat, obj) ->
  ov = obj.version
  op = obj.platform
  if (
    (!ok or ov is "" or semver.gte(ov, ver)) and
    (op is "" or op.includes(plat))
  )
    return true
  return false

###*
 * バージョン/端末でフィルタをかけます
 * @param {Object} parse()で変換したもの
 * @return {Object}
 ###
filter = (parsedObj, useCache = false) ->
  return new Promise( (resolve, reject) ->
    util.getVersion(useCache).then( (ver) ->
      return {ok: true, ver}
    , (err) ->
      return {ok: false}
    ).then( ({ok, ver}) ->
      plat = config.get("platform")
      obj = {}
      for k1, v1 of parsedObj
        for k2, v2 of v1
          for k3, v3 of v2
            if _is_needed(ok, ver, plat, v3)
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
  getUntilDone: getUntilDone
  get: get
  filter: filter

