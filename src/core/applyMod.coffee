###*
 * @fileoverview MODを適応/解除するメソッド群
 ###

{app} = require "electron"
path = require "path"
Promise = require "promise"
fs = require "fs-extra"
fstream = require "fstream"
jszip = require "jszip"
readdirp = require "readdirp"
request = require "request"
unzip = require "unzipper"
config = require "./config"
util = require "./util"

readFile = Promise.denodeify(fs.readFile)

TEMP_FOLDER = path.join(app.getPath("temp"), "BlitzModderPC")

###*
 * リモートからとってくる
 ###
_getFromRemote = (folder, mod, log) ->
  log("download")
  return request("#{mod.repo.name}/#{folder}/#{mod.name}.zip")
    .on("response", ->
      log("downloaded")
      log("zipextract")
    )
    .pipe(
      unzip.Parse()
        .on("end", ->
          log("zipextracted")
        )
    )

###*
 * ローカルからとってくる
 ###
_getFromLocal = (folder, mod, log) ->
  dirpath = path.join(mod.repo.name, folder, mod.name)
  zippath = path.join(mod.repo.name, folder, mod.name + ".zip")
  if util.isDirectory(dirpath)
    log("copydir")
    return readdirp(root: dirpath)
  else if util.isFile(zippath)
    log("zipextract")
    return fs.createReadStream(zippath).pipe(unzip.Parse())
  return

###*
 * dataイベントから適応する
 *###
_applyFromData = (outputFolder, entry, pathList, cb) ->
  pathList.add(entry.path)
  fstream
    .Reader(entry.fullPath)
    .pipe(fstream.Writer(path.join(outputFolder, entry.path)))
    .on("err", (err) ->
      cb(false, err)
    )
    .on("close", ->
      cb(true, entry.path)
      return
    )
  return

###*
 * entryイベントから適応する
 *###
_applyFromEntry = (outputFolder, entry, pathList, cb) ->
  pathList.add(entry.path)
  entry
    .pipe(fstream.Writer(path: path.join(outputFolder, entry.path)))
    .on("err", (err) ->
      cb(false, err)
    )
    .on("close", ->
      cb(true, entry.path)
      return
    )
  return

###*
 * 終了確認
 *###
_isEnd = (resolve, reject, pathList) ->
  return (ok, data) ->
    reject(data) unless ok
    pathList.delete(data)
    if pathList.size is 0
      resolve()
    return

###*
 * MODを適応します
 * @param {"add"|"delete"} type 適応するか解除するか
 * @param {string} mod "{repo: {type: repoType, name: repo}, name: name}"
 * @param {Function} callback 適応完了時に実行
 * @return {Promise}
 ###
applyMod = (type, mod, callback) ->
  pathType = config.get("blitzPathType")
  if pathType is "folder"
    outputFolder = path.normalize(config.get("blitzPath"))
  else
    outputFolder = TEMP_FOLDER
  return new Promise( (resolve, reject) ->
    pathList = new Set()
    fs.ensureDirSync(outputFolder)
    switch type
      when "add" then folder = "install"
      when "delete" then folder = "remove"
      else reject("Unknown type")

    log = (phase) ->
      return callback(phase, type, mod)

    if mod.repo.type is "remote"
      stream = _getFromRemote(folder, mod, log)
    else if mod.repo.type is "local"
      stream = _getFromLocal(folder, mod)
      unless stream? then reject("No Folder and Zip in Path")
    else
      reject("Unknown RepoType")

    hasFile = false
    stream
      .on("data", (entry) ->
        hasFile = true
        _applyFromData(outputFolder, entry, pathList, _isEnd(resolve, reject, pathList))
        return
      )
      .on("entry", (entry) ->
        return if entry.type is "Directory"
        hasFile = true
        _applyFromEntry(outputFolder, entry, pathList, _isEnd(resolve, reject, pathList))
        return
      )
      .on("error", (err) ->
        reject(err)
        return
      )
      .on("end", ->
        resolve() unless hasFile
        return
      )
    return
  ).then( ->
    return new Promise( (resolve, reject) ->
      if pathType is "file"
        callback("tempdone", type, mod)
        callback("zipcompress", type, mod)
        blitzPath = path.normalize(config.get("blitzPath"))
        switch config.get("platform")
          when "a" then prefix = "assets"
          when "i" then prefix = "Payload/wotblitz.app"
          else prefix = ""
        return readFile(blitzPath).then( (data) ->
          return jszip.loadAsync(data)
        ).then( (zip) ->
          readdirp(root: outputFolder)
            .on("data", (entry) ->
              zip.file(path.join(prefix, entry.path), fs.readFileSync(entry.fullPath))
              return
            )
            .on("end", ->
              zip
                .generateNodeStream(streamFiles: true)
                .pipe(fs.createWriteStream(blitzPath))
                .on("finish", ->
                  callback("zipcompressed", type, mod)
                  resolve()
                  return
                )
              return
            )
        ).catch((err) ->
          reject(err)
        )
      else
        resolve()
      return
    )
  ).then( ->
    switch type
      when "add" then config.add("appliedMods", {repo: mod.repo.name, name: mod.name})
      when "delete" then config.remove("appliedMods", {repo: mod.repo.name, name: mod.name})
    callback("done", type, mod)
    fs.remove(TEMP_FOLDER)
    return
  ).catch( (err) ->
    fs.remove(TEMP_FOLDER)
    callback("fail", type, mod, err)
    return
  )

###*
 * 複数のMODを適応します
 * @param {Array[Object]} addMods "{repo: {type: repoType, name: repo}, name: name}"
 *     適応するMODの配列
 * @param {Array[Object]} deleteMods "{repo: {type: repoType, name: repo}, name: name}"
 *     解除するMODの配列
 * @param {Function} callback 適応完了時に実行
 * @return {Promise}
 ###
applyMods = (addMods, deleteMods, callback) ->
  return Promise.all(applyMod("delete", dmod, callback) for dmod in deleteMods).then( ->
    return Promise.all(applyMod("add", amod, callback) for amod in addMods)
  )

module.exports =
  applyMod: applyMod
  applyMods: applyMods
