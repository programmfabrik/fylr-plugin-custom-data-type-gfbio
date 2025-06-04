class CustomDataTypeGFBIO extends CustomDataTypeWithCommonsAsPlugin

  #######################################################################
  # configure used facet
  getFacet: (opts) ->
      opts.field = @
      new CustomDataTypeGFBIOFacet(opts)

  #######################################################################
  # return name of plugin
  getCustomDataTypeName: ->
    "custom:base.custom-data-type-gfbio.gfbio"

  #######################################################################
  # overwrite getCustomMaskSettings
  getCustomMaskSettings: ->
    if @ColumnSchema
      return @FieldSchema.custom_settings || {};
    else
      return {}

  #######################################################################
  # overwrite getCustomSchemaSettings
  getCustomSchemaSettings: ->
    if @ColumnSchema
      return @ColumnSchema.custom_settings || {};
    else
      return {}

  #######################################################################
  # overwrite getCustomSchemaSettings
  name: (opts = {}) ->
    if ! @ColumnSchema
      return "noNameSet"
    else
      return @ColumnSchema?.name

  #######################################################################
  # return name (l10n) of plugin
  getCustomDataTypeNameLocalized: ->
    $$("custom.data.type.gfbio.name")

  #######################################################################
  # returns name of the given vocabulary from datamodel
  getVocabularyNameFromDatamodel: (opts = {}) ->
    # if vocnotation is given in mask, use from masksettings
    fromMask = @getCustomMaskSettings()?.overwrite_ontology_configuration?.value
    if fromMask
      return fromMask

    # else use from datamodel-config
    vocNotation = @getCustomSchemaSettings().vocabulary_notation?.value
    return vocNotation

  #######################################################################
  # returns api-key from baseconfig
  getApiKeyFromBaseconfig: ->
    baseConfig = ez5.session.getBaseConfig("plugin", "custom-data-type-gfbio")
    apikey = baseConfig?.apikey?.apikey
    return apikey

  #######################################################################
  # returns api-key from baseconfig
  getApiEndpointFromBaseconfig: ->
    baseConfig = ez5.session.getBaseConfig("plugin", "custom-data-type-gfbio")
    endpointurl = baseConfig?.endpointurl?.endpointurl
    if endpointurl.charAt(endpointurl.length - 1) == '/'
      endpointurl = endpointurl.slice(0, -1)
    return endpointurl

  #######################################################################
  # returns name of the needed or configures language for the labels of api-requests
  getLanguageParameterForRequests: () ->
    # best case: "lang" is configured in db-modell
    language = @getCustomSchemaSettings()?.lang?.value
    # if not configures in db-modell, use frontendlanguage
    if !language
      desiredLanguage = ez5.loca.getLanguage()
      desiredLanguage = desiredLanguage.split('-')
      language = desiredLanguage[0]

    return language

  #######################################################################
  # returns the databaseLanguages
  getDatabaseLanguages: () ->
    databaseLanguages = ez5.loca.getLanguageControl().getLanguages().slice()

    return databaseLanguages

  #######################################################################
  # returns the frontendLanguages
  getFrontendLanguages: () ->
    frontendLanguages = ez5.session.getConfigFrontendLanguages().slice()

    return frontendLanguages

  #######################################################################
  # render popup as treeview?
  renderPopupAsTreeview: ->
    result = false
    if @.getCustomMaskSettings().editor_style?.value == 'popover_treeview'
      result = true
    result


  #######################################################################
  # get the active vocabular
  #   a) from vocabulary-dropdown (POPOVER)
  #   b) return all given vocs (inline)
  getActiveVocabularyName: (cdata) ->
    that = @
    # is the voc set in dropdown?
    if cdata.gfbio_PopoverVocabularySelect && that.popover?.isShown()
      vocParameter = cdata.gfbio_PopoverVocabularySelect
    else
      # else all given vocs
      vocParameter = that.getVocabularyNameFromDatamodel();
    vocParameter

  #######################################################################
  # returns markup to display in expert search
  #######################################################################
  renderSearchInput: (data, opts) ->
      that = @
      if not data[@name()]
          data[@name()] = {}

      that.callFromExpertSearch = true

      form = @renderEditorInput(data, '', {})

      CUI.Events.listen
            type: "data-changed"
            node: form
            call: =>
                CUI.Events.trigger
                    type: "search-input-change"
                    node: form
                CUI.Events.trigger
                    type: "editor-changed"
                    node: form
                CUI.Events.trigger
                    type: "change"
                    node: form
                CUI.Events.trigger
                    type: "input"
                    node: form

      form.DOM

  needsDirectRender: ->
    return true

  #######################################################################
  # make searchfilter for expert-search
  #######################################################################
  getSearchFilter: (data, key=@name()) ->
      that = @

      objecttype = @path()
      objecttype = objecttype.split('.')
      objecttype = objecttype[0]

      # search for empty values
      if data[key+":unset"]
          filter =
              type: "in"
              fields: [ @fullName()+".conceptName" ]
              in: [ null ]
          filter._unnest = true
          filter._unset_filter = true
          return filter

      # dropdown or popup without tree or use of searchbar: use sameas
      if ! that.renderPopupAsTreeview() || ! data[key]?.experthierarchicalsearchmode
        filter =
            type: "complex"
            search: [
                type: "in"
                mode: "fulltext"
                bool: "must"
                phrase: false
                fields: [ @path() + '.' + @name() + ".conceptURI" ]
            ]
        if ! data[@name()]
            filter.search[0].in = [ null ]
        else if data[@name()]?.conceptURI
            filter.search[0].in = [data[@name()].conceptURI]
        else
            filter = null

      # popup with tree: 3 Modes
      if that.renderPopupAsTreeview()
        # 1. find all records which have the given uri in their ancestors
        if data[key].experthierarchicalsearchmode == 'include_children'
          filter =
              type: "complex"
              search: [
                  type: "match"
                  mode: "token"
                  bool: "must",
                  phrase: true
                  fields: [ @path() + '.' + @name() + ".conceptAncestors" ]
              ]
          if ! data[@name()]
              filter.search[0].string = null
          else if data[@name()]?.conceptURI
              filter.search[0].string = data[@name()].conceptURI
          else
              filter = null
        # 2. find all records which have exact that match
        if data[key].experthierarchicalsearchmode == 'exact'
          filter =
              type: "complex"
              search: [
                  type: "in"
                  mode: "fulltext"
                  bool: "must"
                  phrase: true
                  fields: [ @path() + '.' + @name() + ".conceptURI" ]
              ]
          if ! data[@name()]
              filter.search[0].in = [ null ]
          else if data[@name()]?.conceptURI
              filter.search[0].in = [data[@name()].conceptURI]
          else
              filter = null

      filter


  #######################################################################
  # make tag for expert-search
  #######################################################################
  getQueryFieldBadge: (data) ->
      if ! data[@name()]
          value = $$("field.search.badge.without")
      else if ! data[@name()]?.conceptURI
          value = $$("field.search.badge.without")
      else
          value = data[@name()].conceptName

      if data[@name()]?.experthierarchicalsearchmode == 'exact' || data[@name()]?.experthierarchicalsearchmode == 'include_children'
        searchModeAddition = $$("custom.data.type.gfbio.modal.form.popup.choose_expertsearchmode_." + data[@name()].experthierarchicalsearchmode + "_short")
        value = searchModeAddition + ': ' + value


      name: @nameLocalized()
      value: value

  #######################################################################
  # choose search mode for the hierarchical expert search
  #   ("exact" or "with children")
  #######################################################################
  __chooseExpertHierarchicalSearchMode: (cdata,  layout, resultJSON, anchor, opts) ->
      that = @

      ConfirmationDialog = new CUI.ConfirmationDialog
        text: $$('custom.data.type.gfbio.modal.form.popup.choose_expertsearchmode_label2') + '\n\n' +  $$('custom.data.type.gfbio.modal.form.popup.choose_expertsearchmode_label3') + ': ' + cdata.conceptURI +  '\n'
        title: $$('custom.data.type.gfbio.modal.form.popup.choose_expertsearchmode_label')
        icon: "question"
        cancel: false
        buttons: [
          text: $$('custom.data.type.gfbio.modal.form.popup.choose_expertsearchmode_.exact')
          onClick: =>
            # lock choosen searchmode in savedata
            cdata.experthierarchicalsearchmode = 'exact'
            # update the layout in form
            that.__updateResult(cdata, layout, opts)
            ConfirmationDialog.destroy()
        ,
          text: $$('custom.data.type.gfbio.modal.form.popup.choose_expertsearchmode_.include_children')
          primary: true
          onClick: =>
            # lock choosen searchmode in savedata
            cdata.experthierarchicalsearchmode = 'include_children'
            # update the layout in form
            that.__updateResult(cdata, layout, opts)
            ConfirmationDialog.destroy()
        ]
      ConfirmationDialog.show()

  #######################################################################
  # handle suggestions-menu  (POPOVER)
  #######################################################################
  __updateSuggestionsMenu: (cdata, cdata_form, gfbio_searchstring, input, suggest_Menu, searchsuggest_xhr, layout, opts) ->
    that = @

    delayMillisseconds = 50

    # show loader
    menu_items = [
        text: $$('custom.data.type.gfbio.modal.form.loadingSuggestions')
        icon_left: new CUI.Icon(class: "fa-spinner fa-spin")
        disabled: true
    ]
    itemList =
      items: menu_items
    suggest_Menu.setItemList(itemList)

    setTimeout ( ->

        gfbio_searchstring = gfbio_searchstring.replace /^\s+|\s+$/g, ""
        if gfbio_searchstring.length == 0
          return

        suggest_Menu.show()

        # maxhits-Parameter
        if cdata_form
          gfbio_countSuggestions = cdata_form.getFieldsByName("gfbio_countSuggestions")[0].getValue()
        else
          gfbio_countSuggestions = 10

        # run autocomplete-search via xhr
        if searchsuggest_xhr.xhr != undefined
            # abort eventually running request
            searchsuggest_xhr.xhr.abort()

        # voc parameter
        vocParameter = that.getActiveVocabularyName(cdata)

        # start request
        url = that.getApiEndpointFromBaseconfig() + '/search?q=' + gfbio_searchstring + '&ontologies=' + vocParameter + '&apikey=' + that.getApiKeyFromBaseconfig() + '&suggest=true&pagesize=' + gfbio_countSuggestions
        searchsuggest_xhr.xhr = new (CUI.XHR)(url: url)
        searchsuggest_xhr.xhr.start().done((data, status, statusText) ->

            extendedInfo_xhr = { "xhr" : undefined }

            if data.collection
              data = data.collection
            else
              data = []

            # show voc-headlines in selectmenu? default: no headlines
            showHeadlines = false;

            # are there multible vocs in datamodel?
            multibleVocs = false
            vocTest = that.getVocabularyNameFromDatamodel()
            vocTestArr = vocTest.split(',')

            if vocTestArr.length > 1
              multibleVocs = true

            # conditions for headings in searchslot (for documentation reasons very detailed)

            #A. If only search slot (inlineform, popup invisible)
            if ! that.popover?.isShown()
              # A.1. If only 1 vocabulary, then no subheadings
              if multibleVocs == false
                showHeadlines = false
              else
              # A.2. If several vocabularies, then necessarily and always subheadings
              if multibleVocs == true
                showHeadlines = true
            #B. When popover (popup visible)
            else if that.popover?.isShown()
              # B.1. If several vocabularies
              if multibleVocs == true
                # B.1.1 If vocabulary selected from dropdown, then no subheadings
                if cdata?.gfbio_PopoverVocabularySelect != '' && cdata?.gfbio_PopoverVocabularySelect != vocTest
                  showHeadlines = false
                else
                # B.2.2 If "All vocabularies" in dropdown, then necessarily and always subheadings
                if cdata?.gfbio_PopoverVocabularySelect == vocTest
                  showHeadlines = true
              else
                # B.2. If only one vocabulary
                if multibleVocs == false
                  # B.2.1 Don't show subheadings
                  showHeadlines = false

            # the actual vocab (if multible, add headline + divider)
            actualVocab = ''
            # sort by voc/uri-part in tmp-array
            tmp_items = []
            # a list of the unique text suggestions for treeview-suggest
            unique_text_suggestions = []
            unique_text_items = []
            for recordKey, record of data
              vocab = 'default'
              vocabNotation = record.links.ontology.split('/').pop()
              if showHeadlines
                vocab = vocabNotation
              if ! Array.isArray tmp_items[vocab]
                tmp_items[vocab] = []
              do(record) ->
                # new item
                item =
                  text: record.prefLabel
                  value: record['@id'] + '@' + vocabNotation
                  tooltip:
                    markdown: true
                    placement: "ne"
                    content: (tooltip) ->
                      # show infopopup
                      encodedURI = encodeURIComponent(record['@id'])
                      that.__getAdditionalTooltipInfo(encodedURI, tooltip, extendedInfo_xhr)
                      new CUI.Label(icon: "spinner", text: $$('custom.data.type.gfbio.modal.form.popup.loadingstring'))
                tmp_items[vocab].push item
                # unique item for treeview
                if suggestion not in unique_text_suggestions
                  unique_text_suggestions.push suggestion
                  item =
                    text: suggestion
                    value: suggestion
                  unique_text_items.push item
            # create new menu with suggestions
            menu_items = []
            actualVocab = ''
            for vocab, part of tmp_items
              if showHeadlines
                if ((actualVocab == '' || actualVocab != vocab) && vocab != 'default')
                     actualVocab = vocab
                     item =
                          divider: true
                     menu_items.push item
                     item =
                          label: actualVocab
                     menu_items.push item
                     item =
                          divider: true
                     menu_items.push item
              for suggestion,key2 in part
                menu_items.push suggestion

            # set new items to menu
            itemList =
              onClick: (ev2, btn) ->
                searchUri = btn.getOpt("value")
                # if inline or treeview without popup
                if ! that.renderPopupAsTreeview() || ! that.popover?.isShown()
                  if that.popover
                    # put a loader to popover
                    newLoaderPanel = new CUI.Pane
                        class: "cui-pane"
                        center:
                            content: [
                                new CUI.HorizontalLayout
                                  maximize: true
                                  left: null
                                  center:
                                    content:
                                      new CUI.Label
                                        centered: true
                                        size: "big"
                                        icon: "spinner"
                                        text: $$('custom.data.type.gfbio.modal.form.popup.loadingstring')
                                  right: null
                            ]
                    that.popover.setContent(newLoaderPanel)

                  # if treeview in popup also get the ancestors
                  ancestors = '';
                  #if that.renderPopupAsTreeview() && ! that.popover
                  if that.renderPopupAsTreeview()
                    ancestors = ',ancestors'

                  # get full record to get correct preflabel in desired language
                  # load the record itself and also the hierarchie of the record
                  uriInfoParts = searchUri.split('@')
                  searchUri = uriInfoParts[0]
                  vocNotation = uriInfoParts[1]
                  allDataAPIPath = that.getApiEndpointFromBaseconfig() + '/ontologies/' + vocNotation + '/classes/' + encodeURIComponent(searchUri) + '?apikey=' + that.getApiKeyFromBaseconfig()
                  # XHR for basic information
                  dataEntry_xhr = new (CUI.XHR)(url: allDataAPIPath)
                  dataEntry_xhr.start().done((resultJSON, status, statusText) ->
                    # xhr for hierarchy-informations to fill "conceptAncestors"
                    hierarchyLink = resultJSON.links.ancestors
                    allHierarchyAPIPath = hierarchyLink + '?apikey=' + that.getApiKeyFromBaseconfig()
                    dataHierarchy_xhr = new (CUI.XHR)(url: allHierarchyAPIPath)
                    dataHierarchy_xhr.start().done((hierarchyJSON, status, statusText) ->
                      databaseLanguages = that.getDatabaseLanguages()
                      frontendLanguages = that.getFrontendLanguage()
                      desiredLanguage = that.getLanguageParameterForRequests()

                      # save conceptName
                      cdata.conceptName = resultJSON.prefLabel
                      # save conceptURI
                      cdata.conceptURI = resultJSON['@id']
                      # save conceptSource
                      cdata.conceptSource = resultJSON.links.ontology.split('/').pop()
                      # save _fulltext
                      cdata._fulltext = GFBIOUtilities.getFullTextFromJSONObject(resultJSON, databaseLanguages)
                      # save _standard
                      cdata._standard = GFBIOUtilities.getStandardFromJSONObject(resultJSON, databaseLanguages)
                      # save facet
                      cdata.facetTerm = GFBIOUtilities.getFacetTermFromJSONObject(resultJSON, databaseLanguages)
                      # save frontendlanguage
                      cdata.frontendLanguage = that.getLanguageParameterForRequests()

                      # save ancestors if treeview, add ancestors
                      cdata.conceptAncestors = []
                      for hierarchyValue, hierarchyKey  in hierarchyJSON
                        if hierarchyKey != resultJSON['@id']
                          cdata.conceptAncestors.push hierarchyValue['@id']

                      # add own uri to ancestor-uris
                      cdata.conceptAncestors.push resultJSON['@id']
                      # merge ancestors to string
                      cdata.conceptAncestors = cdata.conceptAncestors.join(' ')

                      if resultJSON.prefLabel.length > 0
                        # update the layout in form
                        that.__updateResult(cdata, layout, opts)
                        # close popover
                        if that.popover
                          that.popover.hide()
                        @

                      # is this from exact search and user has to choose exact-search-mode?!
                      if that._gfbio_opts?.callFromExpertSearch == true
                        CustomDataTypeGFBIO.prototype.__chooseExpertHierarchicalSearchMode(that._cdata, that._editor_layout, resultJSON, that._editor_layout, that._gfbio_opts)
                    )
                  )

                # if treeview: set choosen suggest-entry to searchbar
                if that.renderPopupAsTreeview() && that.popover
                  if cdata_form
                    cdata_form.getFieldsByName("searchbarInput")[0].setValue(btn.getText())

              items: menu_items

            # if treeview in popup: use unique suggestlist (only one voc and text-search)
            if that.renderPopupAsTreeview() && that.popover?.isShown()
              itemList.items = unique_text_items

            # if no suggestions: set "empty" message to menu
            if itemList.items.length == 0
              itemList =
                items: [
                  text: $$('custom.data.type.gfbio.modal.form.popup.suggest.nohit')
                  value: undefined
                ]
            suggest_Menu.setItemList(itemList)
            suggest_Menu.show()
        )
    ), delayMillisseconds


  #######################################################################
  # render editorinputform
  renderEditorInput: (data, top_level_data, opts) ->
    that = @

    if not data[@name()]
        cdata = {
            conceptName : ''
            conceptURI : ''
        }
        data[@name()] = cdata
    else
        cdata = data[@name()]

    @__renderEditorInputPopover(data, cdata, opts)


  #######################################################################
  # get frontend-language
  getFrontendLanguage: () ->
    # language
    desiredLanguage = ez5?.loca?.getLanguage()
    if desiredLanguage
      desiredLanguage = desiredLanguage.split('-')
      desiredLanguage = desiredLanguage[0]
    else
      desiredLanguage = false

    desiredLanguage


  #######################################################################
  # show tooltip with loader and then additional info (for extended mode)
  __getAdditionalTooltipInfo: (uri, tooltip, extendedInfo_xhr, context = null) ->
    that = @

    if context
      that = context

    # abort eventually running request
    if extendedInfo_xhr.xhr != undefined
      extendedInfo_xhr.xhr.abort()

    # start new requests to GFBIO-API
    uriParts = decodeURIComponent(uri).split('/')
    vocNotation = uriParts[uriParts.length-2]
    # check, if vocNotation is in given datamodell-notations
    splittedVocs = that.getVocabularyNameFromDatamodel()
    splittedVocs = splittedVocs.split(',')
    if splittedVocs.includes vocNotation
      allDataAPIPath = that.getApiEndpointFromBaseconfig() + '/ontologies/' + vocNotation + '/classes/' + uri + '?apikey=' + that.getApiKeyFromBaseconfig()
      extendedInfo_xhr.xhr = new (CUI.XHR)(url: allDataAPIPath)
      extendedInfo_xhr.xhr.start()
      .done((resultJSON, status, statusText) ->
        hierarchyLink = resultJSON.links.ancestors
        allHierarchyAPIPath = hierarchyLink + '?apikey=' + that.getApiKeyFromBaseconfig()
        dataHierarchy_xhr = new (CUI.XHR)(url: allHierarchyAPIPath)
        dataHierarchy_xhr.start().done((hierarchyJSON, status, statusText) ->
            resultJSON.ancestors = hierarchyJSON
            htmlContent = GFBIOUtilities.getJSONPreview(resultJSON, decodeURIComponent(uri), that.getLanguageParameterForRequests(), that.getFrontendLanguages())
            tooltip.DOM.innerHTML = htmlContent
            tooltip.autoSize()
        )
      )

      return

  #######################################################################
  # build treeview-Layout with treeview
  buildAndSetTreeviewLayout: (popover, layout, cdata, cdata_form, that, returnDfr = false, opts) ->
    # is this a call from expert-search? --> save in opts..
    if @?.callFromExpertSearch
      opts.callFromExpertSearch = @.callFromExpertSearch
    else
      opts.callFromExpertSearch = false

    # get vocparameter from dropdown, if available...
    popoverVocabularySelectTest = cdata_form.getFieldsByName("gfbio_PopoverVocabularySelect")[0]
    if popoverVocabularySelectTest?.getValue()
      vocParameter = popoverVocabularySelectTest?.getValue()
    else
      # else get first voc from given voclist (1-n)
      vocParameter = that.getActiveVocabularyName(cdata)
      vocParameter = vocParameter.split(',')
      vocParameter = vocParameter[0]

    apikey = that.getApiKeyFromBaseconfig()
    endpointurl = that.getApiEndpointFromBaseconfig()
    treeview = new GFBIO_ListViewTree(popover, layout, cdata, cdata_form, that, opts, vocParameter, apikey, endpointurl)

    # maybe deferred is wanted?
    if returnDfr == false
      treeview.getTopTreeView(vocParameter, 1)
    else
      treeviewDfr = treeview.getTopTreeView(vocParameter, 1)

    treeviewPane = new CUI.Pane
        class: "cui-pane gfbio_treeviewPane"
        center:
            content: [
                cdata_form
              ,
                treeview.treeview
            ]

    @popover.setContent(treeviewPane)

    # maybe deferred is wanted?
    if returnDfr == false
      return treeview
    else
      return treeviewDfr

  #######################################################################
  # show popover and fill it with the form-elements
  showEditPopover: (btn, data, cdata, layout, opts) ->
    that = @

    suggest_Menu
    cdata_form

    # init popover
    @popover = new CUI.Popover
      element: btn
      placement: "wn"
      class: "commonPlugin_Popover"
      pane:
        padded: true
        header_left: new CUI.Label(text: $$('custom.data.type.gfbio.modal.form.popup.choose'))
        header_right: new CUI.EmptyLabel
                        text: that.getVocabularyNameFromDatamodel(opts)
      onHide: =>
        # reset voc-dropdown
        delete cdata.gfbio_PopoverVocabularySelect
        vocDropdown = cdata_form.getFieldsByName("gfbio_PopoverVocabularySelect")[0]
        if vocDropdown
          vocDropdown.reload()
        # reset searchbar
        searchbar = cdata_form.getFieldsByName("searchbarInput")[0]
        if searchbar
          searchbar.reset()
    # init xhr-object to abort running xhrs
    searchsuggest_xhr = { "xhr" : undefined }
    cdata_form = new CUI.Form
      class: "gfbioFormWithPadding"
      data: cdata
      fields: that.__getEditorFields(cdata)
      onDataChanged: (data, elem) =>
        that.__updateResult(cdata, layout, opts)
        # update tree, if voc changed
        if elem.opts.name == 'gfbio_PopoverVocabularySelect' && that.renderPopupAsTreeview()
          @buildAndSetTreeviewLayout(@popover, layout, cdata, cdata_form, that, false, opts)
        that.__setEditorFieldStatus(cdata, layout)
        if elem.opts.name == 'searchbarInput' || elem.opts.name == 'gfbio_countSuggestions'
          that.__updateSuggestionsMenu(cdata, cdata_form, data.searchbarInput, elem, suggest_Menu, searchsuggest_xhr, layout, opts)
    .start()

    # init suggestmenu
    if ! that.renderPopupAsTreeview()
      suggest_Menu = new CUI.Menu
          element : cdata_form.getFieldsByName("searchbarInput")[0]
          use_element_width_as_min_width: true

    # treeview?
    if that.renderPopupAsTreeview()
      # do search-request for all the top-entrys of vocabulary
      @buildAndSetTreeviewLayout(@popover, layout, cdata, cdata_form, that, false, opts)
    # else not treeview, but default search-popup
    else
      defaultPane = new CUI.Pane
          class: "cui-pane"
          center:
              content: [
                  cdata_form
              ]

      @popover.setContent(defaultPane)

    @popover.show()

  #######################################################################
  # create form (POPOVER)
  #######################################################################
  __getEditorFields: (cdata) ->
    that = @
    fields = []
    # dropdown for vocabulary-selection if more then 1 voc
    splittedVocs = that.getVocabularyNameFromDatamodel()
    splittedVocs = splittedVocs.split(',')
    if splittedVocs.length > 1 or splittedVocs == '*'
      select =  {
          type: CUI.Select
          undo_and_changed_support: false
          name: 'gfbio_PopoverVocabularySelect'
          form:
            label: $$("custom.data.type.gfbio.modal.form.dropdown.selectvocabularyLabel")
          # read select-items from gfbio-api
          options: (thisSelect) =>
            dfr = new CUI.Deferred()
            # download labels for all the given vocabularys
            select_items = []
            chunkWorkPromise = CUI.chunkWork.call(@,
              items: splittedVocs
              chunk_size: 1
              call: (items) =>
                #for uri in items
                vocnotation = items[0]
                originalDANTEUri = uri
                uri = that.getApiEndpointFromBaseconfig() + '/ontologies/' + vocnotation + '?apikey=' + that.getApiKeyFromBaseconfig()
                deferred = new CUI.Deferred()
                extendedInfo_xhr = new (CUI.XHR)(url: uri)
                extendedInfo_xhr.start()
                .done((data, status, statusText) ->
                  # add as item to select
                  item = (
                    text: data.name
                    value: data.acronym
                  )
                  select_items.push item

                  deferred.resolve()
                ).fail( =>
                 deferred.reject()
                )
                return deferred.promise()
            )

            chunkWorkPromise.done(=>
              thisSelect.enable()
              dfr.resolve(select_items);
            )

            dfr.promise()

      }
      fields.push select

    # maxhits
    maxhits = {
        type: CUI.Select
        class: "commonPlugin_Select"
        name: 'gfbio_countSuggestions'
        undo_and_changed_support: false
        form:
            label: $$('custom.data.type.gfbio.modal.form.text.count')
        options: [
          (
              value: 10
              text: '10 ' + $$('custom.data.type.gfbio.modal.form.text.count_short')
          )
          (
              value: 20
              text: '20 ' + $$('custom.data.type.gfbio.modal.form.text.count_short')
          )
          (
              value: 50
              text: '50 ' + $$('custom.data.type.gfbio.modal.form.text.count_short')
          )
          (
              value: 100
              text: '100 ' + $$('custom.data.type.gfbio.modal.form.text.count_short')
          )
        ]
      }
    if ! that.renderPopupAsTreeview()
      fields.push maxhits

    # searchfield (autocomplete)
    option =  {
          type: CUI.Input
          class: ""
          undo_and_changed_support: false
          form:
              label: $$("custom.data.type.gfbio.modal.form.text.searchbar")
          placeholder: $$("custom.data.type.gfbio.modal.form.text.searchbar.placeholder")
          name: "searchbarInput"
        }
    if ! that.renderPopupAsTreeview()
      fields.push option

    fields


  #######################################################################
  # renders the "resultmask" (outside popover)
  __renderButtonByData: (cdata) ->
    that = @
    # when status is empty or invalid --> message

    switch @getDataStatus(cdata)
      when "empty"
        return new CUI.EmptyLabel(text: $$("custom.data.type.gfbio.edit.no_gfbio")).DOM
      when "invalid"
        return new CUI.EmptyLabel(text: $$("custom.data.type.gfbio.edit.no_valid_gfbio")).DOM

    extendedInfo_xhr = { "xhr" : undefined }

    # output Button with Name of picked gfbio-Entry and URI
    encodedURI = encodeURIComponent(cdata.conceptURI)
    new CUI.HorizontalLayout
      maximize: true
      left:
        content:
          new CUI.Label
            centered: false
            text: cdata.conceptName
      center:
        content:
          new CUI.ButtonHref
            name: "outputButtonHref"
            class: "pluginResultButton"
            appearance: "link"
            size: "normal"
            href: that.getApiEndpointFromBaseconfig() + '/?uri=' + encodedURI
            target: "_blank"
            class: "cdt_gfbio_smallMarginTop"
            tooltip:
              markdown: true
              placement: 'nw'
              content: (tooltip) ->
                # get details-data
                that.__getAdditionalTooltipInfo(encodedURI, tooltip, extendedInfo_xhr)
                # loader, until details are xhred
                new CUI.Label(icon: "spinner", text: $$('custom.data.type.gfbio.modal.form.popup.loadingstring'))
      right: null
    .DOM


  #######################################################################
  # zeige die gewählten Optionen im Datenmodell unter dem Button an
  getCustomDataOptionsInDatamodelInfo: (custom_settings) ->
    tags = []

    if custom_settings.vocabulary_notation?.value
      tags.push $$("custom.data.type.gfbio.name") + ': ' + custom_settings.vocabulary_notation.value
    else
      tags.push $$("custom.data.type.gfbio.setting.schema.no_vocabulary_notation")

    tags


CustomDataType.register(CustomDataTypeGFBIO)
