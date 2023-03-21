##################################################################################
#  1. Class for use of ListViewTree
#   - uses the GFBIO-API as source for the treeview
#
#  2. extends CUI.ListViewTreeNode
#   - offers preview and selection of GFBIO-records for treeview-nodes
##################################################################################

class GFBIO_ListViewTree

    #############################################################################
    # construct
    #############################################################################
    constructor: (@popover = null, @editor_layout = null, @cdata = null, @cdata_form = null, @context = null, @gfbio_opts = {}, @vocParameter = 'yso', @apikey = '') ->

        options =
          class: "gfbioPlugin_Treeview"
          cols: ["maximize", "auto"]
          fixedRows: 0
          fixedCols: 0
          no_hierarchy : false

        that = @

        treeview = new CUI.ListViewTree(options)
        treeview.render()
        treeview.root.open()

        # append loader-row
        row = new CUI.ListViewRow()
        column = new CUI.ListViewColumn(
          colspan: 2
          element: new CUI.Label(icon: "spinner", appearance: "title",text: $$("custom.data.type.gfbio.modal.form.popup.loadingstringtreeview"))
        )
        row.addColumn(column)
        treeview.appendRow(row)
        treeview.root.open()

        @treeview = treeview
        @treeview

    #############################################################################
    # get top hierarchy
    #############################################################################
    getTopTreeView: (vocName) ->

        dfr = new CUI.Deferred()

        that = @
        topTree_xhr = { "xhr" : undefined }

        # start new request to GFBIO-API and get topconcepts of vocabulary
        url = 'https://data.bioontology.org/ontologies/' + vocName + '/classes/roots' + '?apikey=' + that.apikey + '&include=hasChildren,prefLabel&pagesize=1000'
        topTree_xhr.xhr = new (CUI.XHR)(url: url)
        topTree_xhr.xhr.start().done((data, status, statusText) ->
          # remove loading row (if there is one)
          if that.treeview.getRow(0)
            that.treeview.removeRow(0)

          # sort by preflabel
          data.sort (a, b) ->
            labelA = a.prefLabel.toUpperCase()
            labelB = b.prefLabel.toUpperCase()
            if labelA < labelB
              return -1
            if labelA > labelB
              return 1
            0

          # sort by alphabet

          # add lines from request
          for json, key in data
            prefLabel = json.prefLabel

            # narrower?
            if json.hasChildren == true
              hasNarrowers = true
            else
              hasNarrowers = false

            newNode = new GFBIO_ListViewTreeNode
                selectable: false
                prefLabel: prefLabel
                uri: json['@id']
                hasNarrowers: hasNarrowers
                popover: that.popover
                cdata: that.cdata
                cdata_form: that.cdata_form
                guideTerm: GFBIO_ListViewTreeNode.prototype.isGuideTerm(json)
                context: that.context
                vocParameter: that.vocParameter
                gfbio_opts: that.gfbio_opts
                editor_layout: that.editor_layout
                apikey: that.apikey

            that.treeview.addNode(newNode)
          # refresh popup, because its content has changed (new height etc)
          CUI.Events.trigger
            node: that.popover
            type: "content-resize"
          dfr.resolve()
          dfr.promise()
        )

        dfr


##############################################################################
# custom tree-view-node
##############################################################################
class GFBIO_ListViewTreeNode extends CUI.ListViewTreeNode

    prefLabel = ''
    uri = ''

    initOpts: ->
       super()

       @addOpts
          prefLabel:
             check: String
          uri:
             check: String
          vocParameter:
             check: String
          children:
             check: Array
          guideTerm:
             check: Boolean
             default: false
          hasNarrowers:
             check: Boolean
             default: false
          popover:
             check: CUI.Popover
          cdata:
             check: "PlainObject"
             default: {}
          cdata_form:
             check: CUI.Form
          context:
             check: CustomDataTypeGFBIO
          gfbio_opts:
             check: "PlainObject"
             default: {}
          editor_layout:
             check: CUI.HorizontalLayout
          apikey:
             check: String

    readOpts: ->
       super()


    #########################################
    # function isGuideTerm (always false, but this is for future)
    isGuideTerm: (json) =>
      return false


    #########################################
    # function getChildren
    getChildren: =>
        that = @
        dfr = new CUI.Deferred()
        children = []

        # start new request to GFBIO-API
        # https://data.bioontology.org/ontologies/NCBITAXON/classes/http%3A%2F%2Fpurl.bioontology.org%2Fontology%2FNCBITAXON%2F10239/children
        url = ' https://data.bioontology.org/ontologies/' + @_vocParameter + '/classes/' + encodeURIComponent(@_uri) + '/children?apikey=' + that.opts.apikey + '&include=hasChildren,prefLabel&pagesize=1000'
        getChildren_xhr ={ "xhr" : undefined }
        getChildren_xhr.xhr = new (CUI.XHR)(url: url)
        getChildren_xhr.xhr.start().done((data, status, statusText) ->
          data = data.collection

          # sort by preflabel
          data.sort (a, b) ->
            labelA = a.prefLabel.toUpperCase()
            labelB = b.prefLabel.toUpperCase()
            if labelA < labelB
              return -1
            if labelA > labelB
              return 1
            0

          for json, key in data
            prefLabel = json.prefLabel

            # narrowers?
            if json.hasChildren == true
              hasNarrowers = true
            else
              hasNarrowers = false

            newNode = new GFBIO_ListViewTreeNode
                selectable: false
                prefLabel: prefLabel
                uri: json['@id']
                vocParameter: that._vocParameter
                hasNarrowers: hasNarrowers
                popover: that._popover
                cdata: that._cdata
                cdata_form: that._cdata_form
                guideTerm: that.isGuideTerm(json)
                context: that._context
                gfbio_opts: that._gfbio_opts
                editor_layout: that._editor_layout
                apikey: that.opts.apikey
            children.push(newNode)
          dfr.resolve(children)
        )

        dfr.promise()

    #########################################
    # function isLeaf
    isLeaf: =>
        if @opts.hasNarrowers == true
            return false
        else
          return true

    #########################################
    # function renderContent
    renderContent: =>
        that = @
        extendedInfo_xhr = { "xhr" : undefined }
        d = CUI.dom.div()

        buttons = []

        # '+'-Button
        icon = 'fa-plus-circle'
        tooltipText = $$('custom.data.type.gfbio.modal.form.popup.add_choose')
        if that._guideTerm
          icon = 'fa-sitemap'
          tooltipText = $$('custom.data.type.gfbio.modal.form.popup.add_sitemap')

        plusButton =  new CUI.Button
                            text: ""
                            icon_left: new CUI.Icon(class: icon)
                            active: false
                            group: "default"
                            tooltip:
                              text: tooltipText
                            onClick: =>
                              allDataAPIPath = 'https://data.bioontology.org/ontologies/' + that.opts.vocParameter + '/classes/' + encodeURIComponent(that.opts.uri) + '?apikey=' + that.opts.apikey
                              # XHR for basic information
                              dataEntry_xhr = new (CUI.XHR)(url: allDataAPIPath)
                              dataEntry_xhr.start().done((resultJSON, status, statusText) ->
                                # xhr for hierarchy-informations to fill "conceptAncestors"
                                hierarchyLink = resultJSON.links.ancestors
                                allHierarchyAPIPath = hierarchyLink + '?apikey=' + that.opts.apikey
                                dataHierarchy_xhr = new (CUI.XHR)(url: allHierarchyAPIPath)
                                dataHierarchy_xhr.start().done((hierarchyJSON, status, statusText) ->

                                  databaseLanguages = Object.assign({}, ez5.loca.getLanguageControl().getLanguages())
                                  frontendLanguages = Object.assign({}, ez5.session.getConfigFrontendLanguages())
                                  desiredLanguage = CustomDataTypeGFBIO.prototype.getLanguageParameterForRequests()

                                  # save conceptName
                                  that._cdata.conceptName = resultJSON.prefLabel
                                  # save conceptURI
                                  that._cdata.conceptURI = resultJSON['@id']
                                  # save conceptSource
                                  that._cdata.conceptSource = resultJSON.links.ontology.split('/').pop()
                                  # save _fulltext
                                  that._cdata._fulltext = GFBIOUtilities.getFullTextFromJSONObject(resultJSON, databaseLanguages)
                                  # save _standard
                                  that._cdata._standard = GFBIOUtilities.getStandardFromJSONObject(resultJSON, databaseLanguages)
                                  # save facet
                                  that._cdata.facetTerm = GFBIOUtilities.getFacetTermFromJSONObject(resultJSON, databaseLanguages)
                                  # save frontendlanguage
                                  that._cdata.frontendLanguage = CustomDataTypeGFBIO.prototype.getLanguageParameterForRequests()

                                  # save ancestors if treeview, add ancestors
                                  that._cdata.conceptAncestors = []
                                  for hierarchyValue, hierarchyKey  in hierarchyJSON
                                    if hierarchyKey != resultJSON['@id']
                                      that._cdata.conceptAncestors.push hierarchyValue['@id']

                                  # add own uri to ancestor-uris
                                  that._cdata.conceptAncestors.push resultJSON['@id']
                                  # merge ancestors to string
                                  that._cdata.conceptAncestors = that._cdata.conceptAncestors.join(' ')

                                  console.log "that._cdata", that._cdata

                                  # is this from exact search and user has to choose exact-search-mode?!
                                  if that._gfbio_opts?.callFromExpertSearch == true
                                    CustomDataTypeGFBIO.prototype.__chooseExpertHierarchicalSearchMode(that._cdata, that._editor_layout, resultJSON, that._editor_layout, that._gfbio_opts)

                                  # update form
                                  CustomDataTypeGFBIO.prototype.__updateResult(that._cdata, that._editor_layout, that._gfbio_opts)
                                  # hide popover
                                  that._popover.hide()
                                )
                              )


        # add '+'-Button, if not guideterm
        plusButton.setEnabled(!that._guideTerm)

        buttons.push(plusButton)

        # infoIcon-Button
        infoButton = new CUI.Button
                        text: ""
                        icon_left: new CUI.Icon(class: "fa-info-circle")
                        active: false
                        group: "default"
                        tooltip:
                          markdown: true
                          placement: "e"
                          content: (tooltip) ->
                            # show infopopup
                            CustomDataTypeGFBIO.prototype.__getAdditionalTooltipInfo(encodeURIComponent(that._uri), tooltip, extendedInfo_xhr, that._context)
                            new CUI.Label(icon: "spinner", text: $$('custom.data.type.gfbio.modal.form.popup.loadingstring'))
        buttons.push(infoButton)

        # button-bar for each row
        buttonBar = new CUI.Buttonbar
                          buttons: buttons

        CUI.dom.append(d, CUI.dom.append(CUI.dom.div(), buttonBar.DOM))

        @addColumn(new CUI.ListViewColumn(element: d, colspan: 1))

        CUI.Events.trigger
          node: that._popover
          type: "content-resize"

        new CUI.Label(text: @_prefLabel)
