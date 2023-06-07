local Translate = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable


local cache = {}
local i18nDataset = 'Module:Translate/i18n.json'


--- Loads a dataset and saves it to the cache
---
--- @param dataset string
--- @return table { data = "The dataset", keys = "Translation key mapped to index" }
local function load( dataset )
    if cache[ dataset ] ~= nil then
        return cache[ dataset ]
    end

    local data = mw.loadJsonData( dataset ).data
    local keys = {}
    for index, row in ipairs( data ) do
        keys[ row[ 1 ] ] = index
    end

    cache[ dataset ] = {
        data = data,
        keys = keys
    }

    return cache[ dataset ]
end


--- Retrieves a message from a dataset and formats it according to parameters and language
---
--- @param dataset string
--- @param key string
--- @param params table
--- @param lang string
local function formatMessage( dataset, key, params, lang )
    local data = load( dataset )

    if data.keys[ key ] == nil then
        error( formatMessage( i18nDataset, 'error_bad_msgkey', { key, i18nDataset } ) )
    end

    local msg = data.data[ data.keys[ key ] ][ 2 ]

    msg = msg[ lang ] or error( string.format( 'Language "%s" not found for key "%s"', lang, key ) )

    local result = mw.message.newRawMessage( msg, unpack( params or {} ) )

    return result:plain()
end


--- Translates a message
---
--- @param dataset string
--- @param key string
--- @return string
function methodtable.format( dataset, key, ... )
    local checkType = require('libraryUtil').checkType

    checkType('format', 1, dataset, 'string')
    checkType('format', 2, key, 'string')

    local lang = mw.getContentLanguage():getCode()

    return formatMessage( dataset, key, {...}, lang )
end


--- Translates a message in a given language
---
--- @param lang string
--- @param dataset string
--- @param key string
--- @return string
function methodtable.formatInLanguage( lang, dataset, key, ... )
    local checkType = require('libraryUtil').checkType

    checkType('formatInLanguage', 1, lang, 'string')
    checkType('formatInLanguage', 2, dataset, 'string')
    checkType('formatInLanguage', 3, key, 'string')

    return formatMessage( dataset, key, {...}, lang )
end


--- New Instance
---
--- @return table Translate
function Translate.new( self )
    local instance = {}

    setmetatable( instance, metatable )

    return instance
end


return Translate