local Vehicle = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local TNT = require( 'Module:Translate' ):new()
local common = require( 'Module:Common' )
local api = require( 'Module:Common/Api' )
local log = require( 'Module:Log' )
local manufacturer = require( 'Module:Manufacturer' )._manufacturer
local data = mw.loadJsonData( 'Module:Vehicle/data.json' )

local lang = mw.getContentLanguage()


--- Calls TNT with the given key
---
--- @param key string The translation key
--- @param addSuffix boolean Adds a language suffix if data.smw_multilingual_text is true
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, addSuffix )
    addSuffix = addSuffix or false
    local success, translation

    local function multilingualIfActive( input )
        if addSuffix and data.smw_multilingual_text == true then
            return string.format( '%s@%s', input, data.module_lang or mw.getContentLanguage():getCode() )
        end

        return input
    end

    if data.module_lang ~= nil then
        success, translation = pcall( TNT.formatInLanguage, data.module_lang, 'Module:Vehicle/i18n.json', key or '' )
    else
        success, translation = pcall( TNT.format, 'Module:Vehicle/i18n.json', key or '' )
    end

    if not success or translation == nil then
        return multilingualIfActive( key )
    end

    return multilingualIfActive( translation )
end


--- Request Api Data
--- Using current subpage name without vehicle type suffix
--- @return table or nil
function methodtable.getApiDataForCurrentPage( self )
	local query = self.frameArgs.uuid or self.frameArgs[ translate( 'ARG_name' ) ] or common.removeTypeSuffix(
        mw.title.getCurrentTitle().rootText,
        { 'ship', 'ground vehicle' }
    )

    local json = mw.text.jsonDecode( mw.ext.Apiunto.get_raw( 'v2/vehicles/' .. query, {
        include = data.includes,
        locale = data.api_locale
    } ) )

    if api.checkResponseStructure( json, true, false ) == false then return end

    self.apiData = json[ 'data' ]
    self.apiData = api.makeAccessSafe( self.apiData )

    return self.apiData
end


--- Base Properties that are shared across all Vehicles
--- @return table SMW Result
function methodtable.setSemanticProperties( self )
	local setData = {}

	for _, datum in ipairs( data.smw_data ) do
		local smwKey, from = next( datum )
		smwKey = translate( smwKey )

		if type( from ) ~= 'table' then
			from = { from }
		end

		for _, key in ipairs( from ) do
			local parts = mw.text.split( key, '_', true )
			local value

			if #parts == 2 then
				-- Retrieve data from frameArgs
				if parts[ 1 ] == 'ARG' then
					local argKey = translate( key )

					-- Numbered parameters
					if datum.type == 'range' and type( datum.max ) == 'number' then
						value = {}

						for i = 1, datum.max do
							local argValue = self.frameArgs[ argKey .. i ]
							if argValue then table.insert( value, argValue ) end
						end
					else
						value = self.frameArgs[ key ]
					end
				-- Retrieve data from API
				elseif parts[ 1 ] == 'API' then
					value = self.apiData:get( parts[ 2 ] )
				end
			end

			-- Transform value
			if value ~= nil then
				if type( value ) ~= 'table' then
					value = { value }
				end

				for index, val in ipairs( value ) do
					-- Format number for SMW
					if datum.type == 'number' then
						val = common.formatNum( val )
					-- String format
					elseif type( datum.format ) == 'string' then
						if string.find( datum.format, '%', 1, true  ) then
							val = string.format( datum.format, val )
						elseif datum.format == 'ucfirst' then
							val = lang:ucfirst( val )
						end
					end

					table.remove( value, index )
					table.insert( value, index, val )
				end

				setData[ smwKey ] = value
			end
		end
	end

	setData[ translate( 'SMW_Name' ) ] = self.frameArgs[ translate( 'ARG_name' ) ] or common.removeTypeSuffix(
		mw.title.getCurrentTitle().rootText,
		data.name_suffixes
	)

	if type( setData[ translate( 'SMW_Manufacturer' ) ] ) == 'string' then
		setData[ translate( 'SMW_Manufacturer' ) ] = manufacturer( setData[ translate( 'SMW_Manufacturer' ) ] ).name or setData[ translate( 'SMW_Manufacturer' ) ]
	end

    -- Set properties with API data
    if self.apiData ~= nil then
		-- Flight ready vehicles
		--- Override template parameter with in-game data
		if self.apiData.uuid ~= nil then
			--- Components
			if self.apiData.hardpoints ~= nil and type( self.apiData.hardpoints ) == 'table' and #self.apiData.hardpoints > 0 then
				local hardpoint = require( 'Module:VehicleHardpoint' ):new( self.frameArgs[ translate( 'ARG_name' ) ] or mw.title.getCurrentTitle().fullText )
				hardpoint:setHardPointObjects( self.apiData.hardpoints )
				hardpoint:setParts( self.apiData.parts )
			end

			--- Commodity
			local commodity = require( 'Module:Commodity' ):new()
			commodity:addShopData( self.apiData )
		end
	end

	return mw.smw.set( setData )
end


--- Queries the SMW Store
--- @return table
function methodtable.getSmwData( self )
	-- Cache multiple calls
    if self.smwData ~= nil and self.smwData[ 'Name' ] ~= nil then
        return self.smwData
    end

    local queryName = self.frameArgs[ translate( 'ARG_smwqueryname' ) ] or mw.title.getCurrentTitle().fullText

    local smwData = mw.smw.ask( {
        '[[ ' .. queryName .. ' ]]',
        '?Name#-',
        '?Manufacturer#-',
        '?Production state#-',
        '?Role#-',
        '?Ship matrix size#-',
        '?Size#-',
        '?Series#-',
        '?Loaner vehicle',
        '?Minimum crew#-',
        '?Maximum crew#-',
        '?Cargo capacity',
        '?Vehicle inventory',
        '?Pledge price',
        '?Original pledge price',
        '?Warbond pledge price',
        '?Original warbond pledge price',
        '?Pledge availability#-',
        '?Insurance claim time#-n',
        '?Insurance expedite time#-n',
        '?Insurance expedite cost',
        '?Entity length',
        '?Retracted length',
        '?Entity width',
        '?Retracted width',
        '?Entity height',
        '?Retracted height',
        '?Mass',
        '?SCM speed',
        '?Zero to SCM speed time',
        '?SCM speed to zero time',
        '?Maximum speed',
        '?Zero to Maximum speed time',
        '?Maximum speed to zero time',
        '?Reverse speed',
        '?Roll rate',
        '?Pitch rate',
        '?Yaw rate',
        '?Hydrogen fuel capacity',
        '?Hydrogen fuel intake rate',
        '?Quantum fuel capacity',
        '?Cross section signature modifier',
        '?Electromagnetic signature modifier',
        '?Infrared signature modifier',
        '?Physical damage modifier',
        '?Energy damage modifier',
        '?Distortion damage modifier',
        '?Thermal damage modifier',
        '?Biochemical damage modifier',
        '?Stun damage modifier',
        '?Health point',
        '?Lore release date',
        '?Lore retirement date',
        '?Concept announcement date',
        '?Concept sale date',
        '?Galactapedia URL#-',
        '?Pledge store URL#-',
        '?Presentation URL#-',
        '?Portfolio URL#-',
        '?Whitleys Guide URL#-',
        '?Brochure URL#-',
        '?Trailer URL#-',
        '?Q and A URL#-',
        '?UUID',
        '?Class name',
        '?Ship matrix name',
    } )

    if smwData == nil or smwData[ 1 ] == nil then
		return string.format(
			'[[%s]]%s',
			translate( 'error_script_error_cat' ),
			log.info( translate( 'error_no_data_text' ) )
		)
    end

    self.smwData = smwData[ 1 ]

    return self.smwData
end


--- Creates the infobox
function methodtable.getInfobox( self )
	local smwData = self:getSmwData()

	local infobox = require( 'Module:InfoboxNeue' ):new( {
		placeholderImage = data.placeholder_image
	} )
	local tabber = require( 'Module:Tabber' ).renderTabber
	local sectionTable = {}

	--- SMW Data load error
	--- Infobox data should always have Name property
	if type( smwData ) ~= 'table' then
		return infobox:renderInfobox( infobox:renderMessage( {
			title = translate( 'error_no_data_title' ),
			desc = translate( 'error_no_data_text' ),
		} ) )
	end

	local function getIndicatorClass()
		if smwData[ 'Production state' ] == nil then return end

		local classMap = {
			[ 'Flight ready' ] = 'green',
			[ 'In production' ] = 'yellow',
			[ 'Active for Squadron 42' ] = 'yellow',
			[ 'In concept' ] = 'red'
		}

		for matcher, class in pairs( classMap ) do
			if string.match( smwData[ 'Production state' ], matcher ) ~= nil then
				return 'infobox__indicator--' .. class
			end
		end
	end

	local function getManufacturer()
		if smwData[ 'Manufacturer' ] == nil then return end

		local mfu = manufacturer( smwData[ 'Manufacturer' ] )
		if mfu == nil then return smwData[ 'Manufacturer' ] end

		return infobox.showDescIfDiff(
			table.concat( { '[[', smwData[ 'Manufacturer' ], '|', mfu.name , ']]' } ),
			mfu.code
		)
	end

	infobox:renderImage( self.frameArgs[ translate( 'ARG_image' ) ] )
	infobox:renderIndicator( {
		data = smwData[ 'Production state' ],
		desc = self.frameArgs[ translate( 'ARG_productionstatedesc' ) ],
		class = getIndicatorClass()
	} )
	infobox:renderHeader( {
		title = smwData[ 'Name' ],
		--- e.g. Aegis Dynamics (AEGS)
		subtitle = getManufacturer()
	} )

	local function getSize()
		if smwData[ 'Size' ] == nil then return smwData[ 'Ship matrix size' ] end
		local codes = { 'XXS', 'XS', 'S', 'M', 'L', 'XL' }
		return infobox.showDescIfDiff(
			smwData[ 'Ship matrix size' ],
			table.concat( { 'S', smwData[ 'Size' ], '/', codes[ smwData[ 'Size' ] ] } )
		)
	end

	local function getSeries()
		if smwData[ 'Series' ] == nil then return end
		return string.format(
			'[[:Category:%s series|%s]]',
			smwData[ 'Series' ], smwData[ 'Series' ]
		)
	end

	infobox:renderItem( {
		label = 'Role',
		data = infobox.tableToCommaList( smwData[ 'Role' ] ),
	} )
	infobox:renderItem( {
		label = 'Size',
		data = getSize(),
	} )
	infobox:renderItem( {
		label = 'Series',
		data = getSeries(),
	} )
	infobox:renderItem( {
		label = 'Loaner',
		data = infobox.tableToCommaList( smwData[ 'Loaner vehicle' ] ),
	} )

	infobox:renderSection( { content = sectionTable, col = 2 } )

	--- Capacity section
	local function getCrew()
		if smwData[ 'Minimum crew' ] and smwData[ 'Maximum crew' ] == nil then return end
		if smwData[ 'Minimum crew' ] and smwData[ 'Maximum crew' ] and smwData[ 'Minimum crew' ] ~= smwData[ 'Maximum crew' ] then
			return table.concat( { smwData[ 'Minimum crew' ], ' – ', smwData[ 'Maximum crew' ] } )
		end

		return smwData[ 'Minimum crew' ] or smwData[ 'Maximum crew' ]
	end

	infobox:renderItem( {
		label = 'Crew',
		data = getCrew(),
	} )
	infobox:renderItem( {
		label = 'Cargo',
		data = smwData[ 'Cargo capacity' ],
	} )
	infobox:renderItem( {
		label = 'Stowage',
		data = smwData[ 'Vehicle inventory' ],
	} )

	infobox:renderSection( { content = sectionTable, title = 'Capacity', col = 3 } )

	--- Cost section
	local function getCostSection()
		local tabberData = {}
		local section

		tabberData['label1'] = 'Pledge'
		section = {
			infobox:renderItem( {
				label = 'Standalone',
				data = infobox.showDescIfDiff( smwData[ 'Pledge price' ], smwData[ 'Original pledge price' ] ),
			} ),
			infobox:renderItem( {
				label = 'Warbond',
				data = infobox.showDescIfDiff( smwData[ 'Warbond pledge price' ], smwData[ 'Original warbond pledge price' ] ),
			} ),
			infobox:renderItem( {
				label = 'Avaliblity',
				data = smwData[ 'Pledge availability' ],
			} ),
		}
		tabberData['content1'] = infobox:renderSection( { content = section, col = 2 }, true )

		tabberData['label2'] = 'Insurance'

		local function makeTimeReadable( t )
			if t ~= nil then
				t = lang:formatDuration( t * 60 )

				local regex = {
					[ '%shours*' ] = 'h',
					[ '%sminutes*' ] = 'm',
					[ '%sseconds*' ] = 's',
					[ ','] = '',
					[ 'and%s'] = ''
				}
				for pattern, replace in pairs( regex ) do
					t = string.gsub( t, pattern, replace )
				end
			end
			return t
		end

		section = {
			infobox:renderItem( {
				label = 'Claim',
				data = makeTimeReadable( smwData[ 'Insurance claim time' ] ),
			} ),
			infobox:renderItem( {
				label = 'Expedite',
				data = makeTimeReadable( smwData[ 'Insurance expedite time' ] ),
			} ),
			infobox:renderItem( {
				label = 'Expedite fee',
				data = smwData[ 'Insurance expedite cost' ],
				colspan = 2
			} ),
		}
		tabberData['content2'] = infobox:renderSection( { content = section, col = 4 }, true )

		--- TODO: Move this back up to the first tab when we fix universe cost
		section = {}

		--- Show message on where the game price data are
		if smwData[ 'UUID' ] ~= nil then
			tabberData['label3'] = 'Universe'
			tabberData['content3'] = infobox:renderMessage( {
				title = 'Persistent Universe data has moved',
				desc = 'Buy and rent information are now at the [[{{FULLPAGENAMEE}}#Universe_availability|universe availability]] section on the page.'
			} )
		end

		return tabber( tabberData )
	end

	sectionTable = { getCostSection() }

	infobox:renderSection( {
		content = sectionTable,
		title = 'Cost',
		class = 'infobox__section--tabber'
	} )

	--- Specifications section
	local function getSpecificationsSection()
		local tabberData = {}
		local section

		tabberData['label1'] = 'Dimensions'
		section = {
			infobox:renderItem( {
				label = 'Length',
				data = infobox.showDescIfDiff( smwData[ 'Entity length' ], smwData[ 'Retracted length' ] ),
			} ),
			infobox:renderItem( {
				label = 'Width',
				data = infobox.showDescIfDiff( smwData[ 'Entity width' ], smwData[ 'Retracted width' ] ),
			} ),
			infobox:renderItem( {
				label = 'Height',
				data = infobox.showDescIfDiff( smwData[ 'Entity height' ], smwData[ 'Retracted height' ] ),
			} ),
			infobox:renderItem( {
				label = 'Mass',
				data = smwData[ 'Mass' ],
			} ),
		}

		tabberData['content1'] = infobox:renderSection( { content =section, col = 3 }, true )

		tabberData['label2'] = 'Speed'
		section = {
			infobox:renderItem( {
				label = 'SCM speed',
				data = smwData[ 'SCM speed' ]
			} ),
			infobox:renderItem( {
				label = '0 to SCM',
				data = smwData[ 'Zero to SCM speed time' ]
			} ),
			infobox:renderItem( {
				label = 'SCM to 0',
				data = smwData[ 'SCM speed to zero time' ]
			} ),
			infobox:renderItem( {
				label = 'Max speed',
				data = smwData[ 'Maximum speed' ]
			} ),
			infobox:renderItem( {
				label = '0 to max',
				data = smwData[ 'Zero to Maximum speed time' ]
			} ),
			infobox:renderItem( {
				label = 'Max to 0',
				data = smwData[ 'Maximum speed to zero time' ]
			} ),
			infobox:renderItem( {
				label = 'Reverse speed',
				data = smwData[ 'Reverse speed' ]
			} ),
			infobox:renderItem( {
				label = 'Roll rate',
				data = smwData[ 'Roll rate' ]
			} ),
			infobox:renderItem( {
				label = 'Pitch rate',
				data = smwData[ 'Pitch rate' ]
			} ),
			infobox:renderItem( {
				label = 'Yaw rate',
				data = smwData[ 'Yaw rate' ]
			} ),
		}
		tabberData['content2'] = infobox:renderSection( { content = section, col = 3 }, true )

		tabberData['label3'] = 'Fuel'
		section = {
			infobox:renderItem( {
				label = 'Hydrogen capacity',
				data = smwData[ 'Hydrogen fuel capacity' ],
			} ),
			infobox:renderItem( {
				label = 'Hydrogen intake',
				data = smwData[ 'Hydrogen fuel intake rate' ],
			} ),
			infobox:renderItem( {
				label = 'Quantum capacity',
				data = smwData[ 'Quantum fuel capacity' ],
			} ),
		}
		tabberData['content3'] = infobox:renderSection( { content = section, col = 2 }, true )

		tabberData['label4'] = 'Hull'

		--- FIXME: This should go to somewhere else, like Module:Common
		--- TODO: Should we color code this for buff and debuff?
		local function formatModifier( x )
			if x == nil then return end
			local diff = x - 1
			local sign = ''
			if diff == 0 then
				--- Display 'None' instead of 0 % for better readability
				return 'None'
			elseif diff > 0 then
				--- Extra space for formatting
				sign = '+ '
			elseif diff < 0 then
				sign = '- '
			end
			return sign .. tostring( math.abs( diff ) * 100 ) .. ' %'
		end

		section = {
			infobox:renderItem( {
				label = 'Cross section',
				data = formatModifier( smwData[ 'Cross section signature modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Electromagnetic',
				data = formatModifier( smwData[ 'Electromagnetic signature modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Infrared',
				data = formatModifier( smwData[ 'Infrared signature modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Physical',
				data = formatModifier( smwData[ 'Physical damage modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Energy',
				data = formatModifier( smwData[ 'Energy damage modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Distortion',
				data = formatModifier( smwData[ 'Distortion damage modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Thermal',
				data = formatModifier( smwData[ 'Thermal damage modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Biochemical',
				data = formatModifier( smwData[ 'Biochemical damage modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Stun',
				data = formatModifier( smwData[ 'Stun damage modifier' ] ),
			} ),
			infobox:renderItem( {
				label = 'Health',
				data = smwData[ 'Health point' ],
			} ),
		}
		tabberData['content4'] = infobox:renderSection( { content = section, col = 3 }, true )

		return tabber( tabberData )
	end

	sectionTable = { getSpecificationsSection() }

	infobox:renderSection( {
		content = sectionTable,
		title = 'Specifications',
	 	class = 'infobox__section--tabber'
	} )

	--- Lore section
	sectionTable = {
		infobox.renderItem( {
				label = 'Released',
				data = smwData[ 'Lore release date' ]
		} ),
		infobox.renderItem( {
				label = 'Retired',
				data = smwData[ 'Lore retirement date' ]
		} ),
	}

	infobox:renderSection( {
		content = sectionTable,
		title = 'Lore',
		col = 2
	} )

	--- Development section
	sectionTable = {
		infobox:renderItem( {
			label = 'Announced',
			data = smwData[ 'Concept announcement date' ]
		} ),
		infobox:renderItem( {
			label = 'Concept sale',
			data = smwData[ 'Concept sale date' ]
		} ),
	}

	infobox:renderSection( {
		content = sectionTable,
		title = 'Development',
		col = 2
	} )

	--- Other sites
	local function getOfficialSites()
		return {
			infobox:renderLinkButton( {
				label = 'Galactapedia',
				link = smwData[ 'Galactapedia URL' ]
			} ),
			infobox:renderLinkButton( {
				label = 'Pledge store',
				link = smwData[ 'Pledge store URL' ]
			} ),
			infobox:renderLinkButton( {
				label = 'Presentation',
				link = smwData[ 'Presentation URL' ]
			} ),
			infobox:renderLinkButton( {
				label = 'Portfolio',
				link = smwData[ 'Portfolio URL' ]
			} ),
			infobox:renderLinkButton( {
				label = 'Whitley\'s Guide',
				link = smwData[ 'Whitleys Guide URL' ]
			} ),
			infobox:renderLinkButton( {
				label = 'Brochure',
				link = smwData[ 'Brochure URL' ]
			} ),
			infobox:renderLinkButton( {
				label = 'Trailer',
				link = smwData[ 'Trailer URL' ]
			} ),
			infobox:renderLinkButton( {
				label = 'Q&A',
				link = smwData[ 'Q and A URL' ]
			} ),
		}
	end

	local function getCommunitySites()
		local links = {}
		local query

		if smwData[ 'UUID' ] ~= nil then
			table.insert( links, infobox:renderLinkButton( {
				label = 'Universal Item Finder',
				link = string.format(
					'https://finder.cstone.space/search/%s',
					smwData[ 'UUID' ]
				)
			} ) )
		end

		if smwData[ 'Class name' ] ~= nil then
			query = smwData[ 'Class name' ]:lower()
			table.insert( links, infobox:renderLinkButton( {
				label = '#DPSCalculator',
				link = string.format( 'https://www.erkul.games/ship/%s', query )
			} ) )
			table.insert( links, infobox:renderLinkButton( {
				label = 'SPViewer',
				link = string.format( 'https://www.spviewer.eu/pages/ship-performances.html?ship=%s', query )
			} ) )
			table.insert( links, infobox:renderLinkButton( {
				label = 'TIS Ship Map',
				link = string.format( 'https://tradein.space/#/ship_maps/%s', query )
			} ) )
		end

		if smwData[ 'Ship matrix name' ] ~= nil then
			query = mw.uri.encode( smwData[ 'Ship matrix name' ], 'PATH' )
			table.insert( links, infobox:renderLinkButton( {
				label = 'StarShip 42',
				link = string.format( 'https://www.starship42.com/fleetview/single/?source=Star%%20Citizen%%20Wiki&type=matrix&style=colored&s=%s', query )
			} ) )
			table.insert( links, infobox:renderLinkButton( {
				label = 'FleetYards',
				link = string.format( 'https://fleetyards.net/ships/%s', query )
			} ) )
		end

		return links
	end

	sectionTable = {
		infobox:renderItem( {
			label = 'Official sites',
			data = getOfficialSites()
		} ),
		infobox:renderItem( {
			label = 'Community sites',
			data = getCommunitySites()
		} ),
	}

	infobox:renderFooterButton( {
		icon = 'WikimediaUI-Globe.svg',
		label = 'Other sites',
		type = 'popup',
		content = infobox.renderSection( {
			content = table.concat( sectionTable ),
			class = 'infobox__section--linkButtons'
		} )
	} )

	return infobox:renderInfobox( nil, smwData[ 'name' ] )
end


--- Set the frame and load args
--- @param frame table
function methodtable.setFrame( self, frame )
	self.currentFrame = frame
	self.frameArgs = require( 'Module:Arguments' ).getArgs( frame )
end


--- Save Api Data to SMW store
function methodtable.saveApiData( self )
    local apiData = self:getApiDataForCurrentPage()

    self:setSemanticProperties()

    return apiData
end


--- New Instance
--- @param type string Term used remove suffix from page title
function Vehicle.new( self )
    local instance = {
        categories = {}
    }
    setmetatable( instance, metatable )
    return instance
end


return Vehicle
