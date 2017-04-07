###*
 * @fileoverview MODを適応/解除するメソッド群
 ###

{app} = require "electron"
path = require "path"
Promise = require "Promise"
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
_getFromRemote = (folder, mod) ->
  return request("#{mod.repo.name}/#{folder}/#{mod.name}.zip")
    .pipe(unzip.Parse())

###*
 * ローカルからとってくる
 ###
_getFromLocal = (folder, mod) ->
  dirpath = path.join(mod.repo.name, folder, mod.name)
  zippath = path.join(mod.repo.name, folder, mod.name + ".zip")
  if util.isDirectory(dirpath)
    return readdirp(root: dirpath)
  else if util.isFile(zippath)
    return fs.createReadStream(zippath).pipe(unzip.Parse())
  return

###*
 * dataイベントから適応する
 *###
_applyFromData = (outputFolder, entry) ->
  fstream
    .Reader(entry.fullPath)
    .pipe(fstream.Writer(path.join(outputFolder, entry.path)))
  return

###*
 * entryイベントから適応する
 *###
_applyFromEntry = (outputFolder, entry) ->
  entry.pipe(fstream.Writer(path: path.join(outputFolder, entry.path)))
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
    fs.ensureDirSync(outputFolder)
    switch type
      when "add" then folder = "install"
      when "delete" then folder = "remove"
      else reject("Unknown type")
    if mod.repo.type is "remote"
      stream = _getFromRemote(folder, mod)
    else if mod.repo.type is "local"
      stream = _getFromLocal(folder, mod)
      unless stream? then reject("No Folder and Zip in Path")
    else
      reject("Unknown RepoType")

    stream
      .on("data", (entry) ->
        _applyFromData(outputFolder, entry)
        return
      )
      .on("entry", (entry) ->
        return if entry.type is "Directory"
        _applyFromEntry(outputFolder, entry)
        return
      )
      .on("error", (err) ->
        reject(err)
        return
      )
      .on("end", ->
        resolve()
        return
      )
      .on("close", ->
        resolve()
        return
      )
    return
  ).then( ->
    return new Promise( (resolve, reject) ->
      if pathType is "file"
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
    fs.remove(TEMP_FOLDER)
    callback(true, type, mod)
    return
  ).catch( (err) ->
    fs.remove(TEMP_FOLDER)
    callback(false, type, mod, err)
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
  deleteDeferArray = []
  for dmod in deleteMods
    deleteDeferArray.push(applyMod("delete", dmod, callback))
  addDeferArray = []
  for amod in addMods
    addDeferArray.push(applyMod("add", amod, callback))
  dLen = deleteDeferArray.length
  aLen = addDeferArray.length
  if dLen > 0 and aLen > 0
    return Promise.all(deleteDeferArray).then( ->
      return Promise.all(addDeferArray)
    )
  else if dLen > 0
    return Promise.all(deleteDeferArray)
  else if aLen > 0
    return Promise.all(addDeferArray)
  else
    return Promise.resolve()

module.exports =
  applyMod: applyMod
  applyMods: applyMods
