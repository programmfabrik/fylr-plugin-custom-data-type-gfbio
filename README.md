> This Plugin / Repo is being maintained by a community of developers.
There is no warranty given or bug fixing guarantee; especially not by
Programmfabrik GmbH. Please use the github issue tracking to report bugs
and self organize bug fixing. Feel free to directly contact the committing
developers.

# fylr-custom-data-type-gfbio

This is a plugin for [fylr](https://documentation.fylr.cloud/docs) with Custom Data Type `CustomDataTypeGFBIO` for references to entities of the [GFBio Terminology Service](https://terminologies.gfbio.org/api/).

The Plugins uses <https://terminologies.gfbio.org/api/> for the communication with GFBIO.

## installation

The latest version of this plugin can be found [here](https://github.com/programmfabrik/fylr-plugin-custom-data-type-gfbio/releases/latest/download/customDataTypeGfbio.zip).

The ZIP can be downloaded and installed using the plugin manager, or used directly (recommended).

Github has an overview page to get a list of [all release](https://github.com/programmfabrik/fylr-plugin-custom-data-type-gfbio/releases/).

## requirements
This plugin requires https://github.com/programmfabrik/fylr-plugin-commons-library. In order to use this Plugin, you need to add the [commons-library-plugin](https://github.com/programmfabrik/fylr-plugin-commons-library) to your pluginmanager.

## configuration

As defined in `manifest.yml` this datatype can be configured:

### Schema options
The plugin appears as a separate data type in the data model of object types and can be selected as a data type for a column.

* vocabulary-notation:
  * which vocabulary-notation to use. List of Vocabularys [in GFBIO](https://data.bioontology.org/ontologies/)
  * repeatable. Multiple vocabularies can be used simultaneously in pop-up mode (comma-separated list)
  * e.g. "NCBITAXON", "NCIT", "GO,NCIT"
  * mandatory parameter


### Mask options
* Editor-style:
  * popup
  * popup with treeview
* Overwrite ontology-configuration from schema


### baseconfiguration
The update mechanism for the plugin data can be configured here.
* endpointurl
* apikey
  * GFBio-Apikey (if needed)
* days between updates
  * The data stored in fylr is compared with the data from the GFBIO API and then updated and re-indexed in fylr if necessary. This creates a corresponding load on the GFBIO API.


## saved data
* conceptName
    * Preferred label of the linked record
* conceptURI
    * URI to linked record
* conceptSource
    * Source of the related authority data
       * Example: NCBITAXON
* conceptAncestors
    * List of URI’s of the ancestors records plus the records URI itself
* frontendLanguage
  * Includes a language. Either the language configured in the field in the data model is used here, or the front-end language as a fallback. The label is preferred and if not set manually in this language. The updater needs this information.
* _fulltext
    * Label, URI, source and skos-notes are aggregated
* _standard
    * List of preferred labels in different languages
* _facet
    * URI combined with preferred label



## updater
* An automatic update mechanism is integrated. In the baseconfiguration, you can configure how often the update mechanism runs in the background (1 to 7 times a week). The updater iterates over each occurrence of the new data type and requests the GFBIO API with the given URI. The result of this query is compared with the content in the fylr-database. If necessary, the status of the field content is updated.


## sources

The source code of this plugin is managed in a git repository at <https://github.com/programmfabrik/fylr-plugin-custom-data-type-gfbio>.
