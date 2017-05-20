###*
 * @fileoverview 翻訳関連
 ###
{app} = require "electron"
config = require "./config"

_langname = ""
_table = null

###*
 * 取得
 ###
get = ->
  lang = config.get("lang")
  if lang is _langname and _table isnt null
    return _table
  try
    _table = require("../lang/#{lang}.json")
    _langname = lang
    return _table
  catch e
    console.error e
    return {}

module.exports =
  get: get
