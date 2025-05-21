ZIP_NAME ?= "customDataTypeGfbio.zip"
PLUGIN_NAME = "custom-data-type-gfbio"

# coffescript-files to compile
COFFEE_FILES = commons.coffee \
	GFBIOUtilities.coffee \
	CustomDataTypeGFBIO.coffee \
	CustomDataTypeGFBIOFacet.coffee \
	CustomDataTypeGFBIOTreeview.coffee

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

all: build ## build all

build: clean ## clean, compile, copy files to build folder

					npm install --save node-fetch # install needed node-module

					mkdir -p build
					mkdir -p build/$(PLUGIN_NAME)
					mkdir -p build/$(PLUGIN_NAME)/webfrontend
					mkdir -p build/$(PLUGIN_NAME)/updater
					mkdir -p build/$(PLUGIN_NAME)/l10n

					mkdir -p src/tmp # build code from coffee
					cp easydb-library/src/commons.coffee src/tmp
					cp src/webfrontend/*.coffee src/tmp
					cd src/tmp && coffee -b --compile ${COFFEE_FILES} # bare-parameter is obligatory!
                    
					cat src/tmp/commons.js >> build/$(PLUGIN_NAME)/webfrontend/customDataTypeGfbio.js
                    
					cat src/tmp/CustomDataTypeGFBIO.js >> build/$(PLUGIN_NAME)/webfrontend/customDataTypeGfbio.js
					cat src/tmp/CustomDataTypeGFBIOFacet.js >> build/$(PLUGIN_NAME)/webfrontend/customDataTypeGfbio.js
					cat src/tmp/CustomDataTypeGFBIOTreeview.js >> build/$(PLUGIN_NAME)/webfrontend/customDataTypeGfbio.js
					cat src/tmp/GFBIOUtilities.js >> build/$(PLUGIN_NAME)/webfrontend/customDataTypeGfbio.js

					cp src/updater/GFBIOUpdater.js build/$(PLUGIN_NAME)/updater/GfbioUpdater.js # build updater
					cat src/tmp/GFBIOUtilities.js >> build/$(PLUGIN_NAME)/updater/GfbioUpdater.js
					cp package.json build/$(PLUGIN_NAME)/package.json
					cp -r node_modules build/$(PLUGIN_NAME)/
					rm -rf src/tmp # clean tmp

					cp l10n/customDataTypeGfbio.csv build/$(PLUGIN_NAME)/l10n/customDataTypeGfbio.csv # copy l10n
					tail -n+2 easydb-library/src/commons.l10n.csv >> build/$(PLUGIN_NAME)/l10n/customDataTypeGfbio.csv # copy commons

					cp src/webfrontend/css/main.css build/$(PLUGIN_NAME)/webfrontend/customDataTypeGfbio.css # copy css
					cp manifest.master.yml build/$(PLUGIN_NAME)/manifest.yml # copy manifest

clean: ## clean
				rm -rf build

zip: build ## build zip file
			cd build && zip ${ZIP_NAME} -r $(PLUGIN_NAME)/
