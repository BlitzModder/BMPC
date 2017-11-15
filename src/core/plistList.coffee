###*
 * @fileoverview 言語.plistの読み込み
 ###
plist = require "plist"
semver = require "semver"
request = require "./request"
config = require "./config"
util = require "./util"

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
        version = version.replace(/^(\d+\.\d+)$/, "$1.9")
        version = "" unless /^(?:\d+\.\d+\.\d+)?$/.test(version)
        platform = "" unless /^(?:[iawm]+)?$/.test(platform)
        obj[name][n][n_] =
          name: "#{id}.#{i}.#{i_}"
          version: version
          platform: platform
  return obj

###*
 * plistを取得できるまで取得(言語順)
 * @param {type: "remote"|"local", name: string} repo
 * @param {string} lang
 * @param {boolean} force キャッシュを無視して元ファイルを取得するか 既定値は"false"
 * @return {Object} plistのオブジェクト
 ###
getUntilDone = (repo, lang, force = false) ->
  try
    return await get(repo, lang, force)
  if lang.includes("_")
    try
      return await get(repo, lang.split("_")[0], force)
  try
    return await get(repo, "en", force)
  try
    return await get(repo, "ja", force)
  try
    return await get(repo, "ru", force)

###*
 * plistを取得してパースしたものを返します
 * @param {"remote"|"local"} repoType
 * @param {string} repoName
 * @param {string} lang
 * @param {boolean} force キャッシュを無視して元ファイルを取得するか 既定値は"false"
 * @return {Object} plistのオブジェクト
 ###
get = (repo, lang, force = false) ->
  {name} = repo
  if data[name]?[lang]? and !force
    return data[name][lang]
  res = await request.getWithCache(repo, "plist/#{lang}.plist", force)
  data[name] ?= {}
  data[name][lang] = parse(plist.parse(res))
  return data[name][lang]

_isNeeded = (ver, plat, {version: ov, platform: op}) ->
  if (
    (ver is "" or ov is "" or semver.gte(ov, ver)) and
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
  try
    ver = await util.getVersion(useCache)
  catch
    ver = ""
  plat = config.get("platform")
  obj = {}
  for k1, v1 of parsedObj
    for k2, v2 of v1
      for k3, v3 of v2 when _isNeeded(ver, plat, v3)
        obj[k1] = {} if !obj[k1]?
        obj[k1][k2] = {} if !obj[k1][k2]?
        obj[k1][k2][k3] = v3
  return obj

module.exports = {
  getUntilDone
  get
  filter
}
