class GFBIOUtilities

  # from https://github.com/programmfabrik/coffeescript-ui/blob/fde25089327791d9aca540567bfa511e64958611/src/base/util.coffee#L506
  # has to be reused here, because cui not be used in updater
  @isEqual: (x, y, debug) ->
    #// if both are function
    if x instanceof Function
      if y instanceof Function
        return x.toString() == y.toString()
      return false

    if x == null or x == undefined or y == null or y == undefined
      return x == y

    if x == y or x.valueOf() == y.valueOf()
      return true

    # if one of them is date, they must had equal valueOf
    if x instanceof Date
      return false

    if y instanceof Date
      return false

    # if they are not function or strictly equal, they both need to be Objects
    if not (x instanceof Object)
      return false

    if not (y instanceof Object)
      return false

    p = Object.keys(x)
    if Object.keys(y).every( (i) -> return p.indexOf(i) != -1 )
      return p.every((i) =>
        eq = @isEqual(x[i], y[i], debug)
        if not eq
          if debug
            console.debug("X: ",x)
            console.debug("Differs to Y:", y)
            console.debug("Key differs: ", i)
            console.debug("Value X:", x[i])
            console.debug("Value Y:", y[i])
          return false
        else
          return true
      )
    else
      return false


  ########################################################################
  # generates the fulltext for a given graph-record
  ########################################################################
  @getFullTextFromJSONObject: (object, databaseLanguages = false) ->

    shortenedDatabaseLanguages = databaseLanguages.map((value, key, array) ->
      value.split('-').shift()
    )

    _fulltext = {}
    fullTextString = ''
    l10nObject = {}
    l10nObjectWithShortenedLanguages = {}

    # init l10nObject for fulltext
    for language in databaseLanguages
      l10nObject[language] = ''

    for language in shortenedDatabaseLanguages
      l10nObjectWithShortenedLanguages[language] = ''

    objectKeys = [
      'prefLabel'
      'synonym'
      '@id'
      'definition'
      'note'
    ]

    # parse all object-keys and add all values to fulltext
    for key, value of object
      if objectKeys.includes(key)
        propertyType = typeof value

        # string
        if propertyType == 'string'
          fullTextString += value + ' '
          # add to each language in l10n
          for l10nObjectWithShortenedLanguagesKey, l10nObjectWithShortenedLanguagesValue of l10nObjectWithShortenedLanguages
            l10nObjectWithShortenedLanguages[l10nObjectWithShortenedLanguagesKey] = l10nObjectWithShortenedLanguagesValue + value + ' '

        # object / array
        if propertyType == 'object'
          # make each object an array, if it isn't
          if ! Array.isArray(value)
            value = [value]

          for arrayValue in value
            if typeof arrayValue == 'object'
              if l10nObjectWithShortenedLanguages.hasOwnProperty arrayValue.lang
                l10nObjectWithShortenedLanguages[arrayValue.lang] += arrayValue.value + ' '
              fullTextString += arrayValue.value + ' '

    # finally give l10n-languages the easydb-language-syntax
    for l10nObjectKey, l10nObjectValue of l10nObject
      # get shortened version
      shortenedLanguage = l10nObjectKey.split('-')[0]
      # add to l10n
      if l10nObjectWithShortenedLanguages[shortenedLanguage]
        l10nObject[l10nObjectKey] = l10nObjectWithShortenedLanguages[shortenedLanguage]

    _fulltext.text = fullTextString
    _fulltext.l10ntext = l10nObject
    return _fulltext


  ########################################################################
  # generates the _standard-object for a given graph-record from preflabels
  ########################################################################
  @getStandardFromJSONObject: (json, databaseLanguages = false) ->

    shortenedDatabaseLanguages = databaseLanguages.map((value, key, array) ->
      value.split('-').shift()
    )

    _standard = {}
    l10nObject = {}

    # init l10nObject for fulltext
    for language in databaseLanguages
      l10nObject[language] = ''

    hasl10n = false

    for l10nObjectKey, l10nObjectValue of l10nObject
      # add to l10n
      if json.prefLabel.length > 0
          l10nObject[l10nObjectKey] =  json.prefLabel

    # if l10n-object is not empty
    _standard.l10ntext = l10nObject
    return _standard


  ########################################################################
  #generates a json-structure, which is only used for facetting (aka filter) in frontend
  ########################################################################
  @getFacetTermFromJSONObject: (json, databaseLanguages) ->

    shortenedDatabaseLanguages = databaseLanguages.map((value, key, array) ->
      value.split('-').shift()
    )

    _facet_term = {}

    l10nObject = {}

    # init l10nObject
    for language in databaseLanguages
      l10nObject[language] = ''

    # build facetTerm upon prefLabels and uri!

    hasl10n = false

    #  give l10n-languages the easydb-language-syntax
    for l10nObjectKey, l10nObjectValue of l10nObject
      # add to l10n
        l10nObject[l10nObjectKey] = json.prefLabel

    # if l10n, yet not in all languages
    #   --> fill the other languages with something as fallback
    for l10nObjectKey, l10nObjectValue of l10nObject
      if l10nObject[l10nObjectKey] == ''
        l10nObject[l10nObjectKey] = json.prefLabel

      l10nObject[l10nObjectKey] = l10nObject[l10nObjectKey] + '@$@' + json['@id']

    _facet_term = l10nObject

    return _facet_term


  #############################################################################
  # generates a html-preview for a given json-record
  #############################################################################
  @getJSONPreview = (data, uri, desiredLanguage, frontendLanguages) ->
    that = @
    html = ''

    # get record from graph
    if data['@id'] == uri
      prefLabel = $$('custom.data.type.finto.modal.form.popup.jsonpreview.nopreflabel')
      if data?.prefLabel
        prefLabel = data.prefLabel

      html += '<div style="font-size: 12px; color: #999;"><span class="cui-label-icon"><i class="fa  fa-external-link"></i></span>&nbsp;' + data['@id'] + '</div>'

      html += '<h3><span class="cui-label-icon"><i class="fa  fa-info-circle"></i></span>&nbsp;' + prefLabel + '</h3>'

      # build ancestors-hierarchie
      namewithpath = ''
      ancestors = ''
      if data.ancestors
        data.ancestors = data.ancestors.reverse()
        for val, key in data.ancestors
          if val != null
            tmpPrefLabel = val.prefLabel
            spaces = ''
            i = 0
            while i < key
              spaces += '&nbsp;&nbsp;'
              i++
            namewithpath += tmpPrefLabel + ' > '
            ancestors += spaces + '<span class="gfbioTooltipAncestors"><span class="cui-label-icon"><i class="fa fa-sitemap" aria-hidden="true"></i></span> ' + tmpPrefLabel + '</span><br />'
      if ancestors != ''
        html += ancestors + spaces + '<span class="gfbioTooltipAncestors">&nbsp;&nbsp;<span class="cui-label-icon"><i class="fa fa-arrow-circle-o-right" aria-hidden="true"></i></span> ' + prefLabel + '</span><br />'
        namewithpath += prefLabel

      # Alternative Labels (any language)
      ###
      synonymLabels = ''
      if data.synonym
        if Array.isArray(data.synonym)
          for key, val of data.synonym
            altLabels = ' - ' + val.value + ' (' + val.lang + ')<br />' + altLabels
        else if data.synonym instanceof Object
            altLabels = ' - ' + data.synonym.value + ' (' + data.synonym.lang + ')<br />' + synonymLabels
      if synonymLabels
        html += '<h4>' + $$('custom.data.type.finto.modal.form.popup.jsonpreview.altterms') + '</h4>' + synonymLabels
      ###

      # Definition
      ###
      definition = ''
      if record['skos:definition']
        # if only one text
        if ! Array.isArray record['skos:definition']
          if record['skos:definition'].value
            definition += record['skos:definition'].value + '<br />'
        # if multiple texts in different languages
        if Array.isArray record['skos:definition']
          for key, value of record['skos:definition']
            if value.lang == desiredLanguage
              definition += value.value + '<br />'
        if definition
          html += '<h4>' + $$('custom.data.type.finto.modal.form.popup.jsonpreview.definition') + '</h4>' + definition
      ###
      html = '<style>.gfbioTooltip { padding: 10px; min-width:200px; }  .gfbioTooltip h3 { margin-top: 10px; } .gfbioTooltip h4 { margin-top: 14px; margin-bottom: 4px; }</style><div class="gfbioTooltip">' + html + '</div>'
    return html


  ############################################################################
  # get vocabulary-notation from finto-uri
  ############################################################################

  @isURIEncoded: (str) ->
      return typeof str == "string" && decodeURIComponent(str) != str;


  @getVocNotationFromURI: (uri) ->
    if @.isURIEncoded
      uriParts = decodeURIComponent(uri).split('/')
    else
      uriParts = uri.split('/')

    vocNotation = uriParts[uriParts.length-2]

    return vocNotation


  #############################################################################
  # get prefLabel from json (preferred in active Frontend-Language)
  #############################################################################
  @getPrefLabelFromDataResult = (json, desiredLanguage, frontendLanguages) ->
      if typeof $$ != "undefined"
        prefLabelFallback = $$("custom.data.type.finto.modal.form.popup.treeview.nopreflabel")
      else
        prefLabelFallback = 'no label found'

      if !json.prefLabel
        return prefLabelFallback

      prefLabel = prefLabelFallback;

      for key, value of frontendLanguages
        tmp = value.split('-')
        tmp = tmp[0]
        frontendLanguages[key] = tmp

      # if only 1 preflabel, than as object
      if ! Array.isArray json.prefLabel
        if json.prefLabel.value
          return json.prefLabel.value

      # try to find label in given frontend-language
      for key, value of json.prefLabel
        if value.lang == desiredLanguage
          return value.value

      # if no preflabel in active frontendlanguage, choose a random label from configured frontendlanguages
      for key, value of json.prefLabel
        if frontendLanguages.includes value.lang
          return value.value

      # else a random language
      if json.prefLabel[0]
        return json.prefLabel[0].value

      prefLabel
