const fs = require('fs')
const https = require('https')
const fetch = (...args) => import('node-fetch').then(({
    default: fetch
}) => fetch(...args));

let databaseLanguages = [];
let frontendLanguages = [];
let gfbio_apikey = '';
let endpointurl = '';

let info = {}

let access_token = '';

if (process.argv.length >= 3) {
        info = JSON.parse(process.argv[2])
}

function hasChanges(objectOne, objectTwo) {
    var len;
    const ref = ["conceptName", "conceptURI", "conceptSource", "_standard", "_fulltext", "conceptAncestors", "frontendLanguage"];
    for (let i = 0, len = ref.length; i < len; i++) {
        let key = ref[i];
        if (!GFBIOUtilities.isEqual(objectOne[key], objectTwo[key])) {
            return true;
        }
    }
    return false;
}

function getConfigFromAPI() {
                return new Promise((resolve, reject) => {
                                var url = 'http://fylr.localhost:8081/api/v1/config?access_token=' + access_token
                                fetch(url, {
                                                                headers: {
                                                                                'Accept': 'application/json'
                                                                },
                                                })
                                                .then(response => {
                                                                if (response.ok) {
                                                                                resolve(response.json());
                                                                } else {
                                                                                console.error("DANTE-Updater: Fehler bei der Anfrage an /config ");
                                                                }
                                                })
                                                .catch(error => {
                                                                console.error(error);
                                                                console.error("DANTE-Updater: Fehler bei der Anfrage an /config");
                                                });
                });
}

main = (payload) => {
    switch (payload.action) {
        case "start_update":
            outputData({
                "state": {
                    "personal": 2
                },
                "log": ["started logging"]
            })
            break
        case "update":

            ////////////////////////////////////////////////////////////////////////////
            // run gfbio-api-call for every given uri
            ////////////////////////////////////////////////////////////////////////////

            // collect URIs
            let URIList = [];
            for (var i = 0; i < payload.objects.length; i++) {
                URIList.push(payload.objects[i].data.conceptURI);
            }
            // unique urilist
            URIList = [...new Set(URIList)]

            let requestUrls = [];
            let requests = [];

            URIList.forEach((uri) => {
                let dataRequestUrl = endpointurl + '/ontologies/' + GFBIOUtilities.getVocNotationFromURI(uri) + '/classes/' + encodeURIComponent(uri) + '?apikey=' + gfbio_apikey
                let hierarchieRequestUrl = endpointurl + '/ontologies/' + GFBIOUtilities.getVocNotationFromURI(uri) + '/classes/' + encodeURIComponent(uri) + '/ancestors' + '?apikey=' + gfbio_apikey

                let dataRequest = fetch(dataRequestUrl);
                let hierarchieRequest = fetch(hierarchieRequestUrl);
                requests.push({
                    url: dataRequestUrl,
                    uri: uri,
                    request: dataRequest
                });
                requests.push({
                    url: hierarchieRequestUrl,
                    uri: uri,
                    request: hierarchieRequest
                });
                requestUrls.push(dataRequest);
                requestUrls.push(hierarchieRequest);
            });

            Promise.all(requestUrls).then(function(responses) {
                let results = [];
                // Get a JSON object from each of the responses
                responses.forEach((response, index) => {
                    let url = requests[index].url;
                    let uri = requests[index].uri;
                    let requestType = (url.includes('ancestors?apikey')) ? 'broader' : 'data';
                    let result = {
                        url: url,
                        requestType: requestType,
                        uri: uri,
                        data: null,
                        error: null
                    };
                    if (response.ok) {
                        result.data = response.json();
                    } else {
                        result.error = "Error fetching data from " + url + ": " + response.status + " " + response.statusText;
                    }
                    results.push(result);
                });
                return Promise.all(results.map(result => result.data));
            }).then(function(data) {
                let results = [];
                data.forEach((data, index) => {
                    let url = requests[index].url;
                    let uri = requests[index].uri;
                    let requestType = (url.includes('ancestors?apikey')) ? 'broader' : 'data';
                    let result = {
                        url: url,
                        requestType: requestType,
                        uri: uri,
                        data: data,
                        error: null
                    };
                    if (data instanceof Error) {
                        result.error = "Error parsing data from " + url + ": " + data.message;
                    }
                    results.push(result);
                });

                // build cdata from all api-request-results
                let cdataList = [];
                payload.objects.forEach((result, index) => {
                    let originalCdata = payload.objects[index].data;
                    let newCdata = {};
                    let originalURI = originalCdata.conceptURI;

                    const matchingRecordData = results.find(record => record.uri === originalURI && record.requestType === 'data');
                    const matchingRecordHierarchy = results.find(record => record.uri === originalURI && record.requestType === 'broader');

                    if (matchingRecordData) {
                        // rematch uri, because maybe uri changed / rewrites ..
                        let uri = matchingRecordData.uri;

                        ///////////////////////////////////////////////////////
                        // conceptName, conceptURI, _standard, _fulltext, facet, frontendLanguage
                        if (matchingRecordData.requestType == 'data') {
                            resultJSON = matchingRecordData.data;
                            if (resultJSON) {
                                // get desired language for preflabel. This is frontendlanguage from original data...
                                let desiredLanguage = 'de';
                                if(originalCdata?.frontendLanguage?.length == 2) {
                                    desiredLanguage = originalCdata.frontendLanguage;
                                }
                                // save conceptName
                                newCdata.conceptName = resultJSON.prefLabel;
                                // save conceptURI
                                newCdata.conceptURI = resultJSON['@id'];
                                // save conceptSource
                                newCdata.conceptSource = GFBIOUtilities.getVocNotationFromURI(uri);
                                // save _fulltext
                                newCdata._fulltext = GFBIOUtilities.getFullTextFromJSONObject(resultJSON, databaseLanguages);
                                // save _standard
                                newCdata._standard = GFBIOUtilities.getStandardFromJSONObject(resultJSON, databaseLanguages);
                                // save facet
                                newCdata.facetTerm = GFBIOUtilities.getFacetTermFromJSONObject(resultJSON, databaseLanguages);
                                // save frontend language (same as given)
                                newCdata.frontendLanguage = desiredLanguage;
                            }
                        }

                        ///////////////////////////////////////////////////////
                        // ancestors
                        if (matchingRecordHierarchy.requestType == 'broader') {
                            let hierarchyJSON = matchingRecordHierarchy.data
                            if (hierarchyJSON) {
                                // save ancestors if treeview, add ancestors
                                newCdata.conceptAncestors = [];

                                for (hierarchyKey = i = 0, len = hierarchyJSON.length; i < len; hierarchyKey = ++i) {
                                    hierarchyValue = hierarchyJSON[hierarchyKey];
                                    if (hierarchyKey !== resultJSON['@id']) {
                                        newCdata.conceptAncestors.push(hierarchyValue['@id']);
                                    }
                                }
                                // add own uri to ancestor-uris
                                newCdata.conceptAncestors.push(resultJSON['@id']);

                                // merge ancestors to string
                                newCdata.conceptAncestors = newCdata.conceptAncestors.join(' ');
                            }

                            if (newCdata.conceptURI) {
                                if (hasChanges(payload.objects[index].data, newCdata)) {
                                    console.error("_________________________has changes!!________________");
                                    payload.objects[index].data = newCdata;
                                }
                            } else {
                                console.error("_________________________updatedata is empty!!________________");
                            }
                        }
                    } else {
                        console.error('No matching record found');
                    }
                });
                outputData({
                    "payload": payload.objects,
                    "log": [payload.objects.length + " objects in payload"]
                });
            });
            // send data back for update
            break;
        case "end_update":
            outputData({
                "state": {
                    "theend": 2,
                    "log": ["done logging"]
                }
            });
            break;
        default:
            outputErr("Unsupported action " + payload.action);
    }
}

outputData = (data) => {
    out = {
        "status_code": 200,
        "body": data
    }
    process.stdout.write(JSON.stringify(out))
    process.exit(0);
}

outputErr = (err2) => {
    let err = {
        "status_code": 400,
        "body": {
            "error": err2.toString()
        }
    }
    console.error(JSON.stringify(err))
    process.stdout.write(JSON.stringify(err))
    process.exit(0);
}

(() => {

    let data = ""

    process.stdin.setEncoding('utf8');

    ////////////////////////////////////////////////////////////////////////////
    // check if hour-restriction is set
    ////////////////////////////////////////////////////////////////////////////

    if (info?.config?.plugin?.['custom-data-type-gfbio']?.config?.update_gfbio?.restrict_time === true) {
        gfbio_config = info.config.plugin['custom-data-type-gfbio'].config.update_gfbio;
        // check if hours are configured
        if (gfbio_config?.from_time !== false && gfbio_config?.to_time !== false) {
            const now = new Date();
            const hour = now.getHours();
            // check if hours do not match
            if (hour < gfbio_config.from_time && hour >= gfbio_config.to_time) {
                // exit if hours do not match
                outputData({
                    "state": {
                        "theend": 2,
                        "log": ["hours do not match, cancel update"]
                    }
                });
            }
        }
    }
        
    access_token = info && info.plugin_user_access_token;

    if(access_token) {

        ////////////////////////////////////////////////////////////////////////////
        // get config and read the languages
        ////////////////////////////////////////////////////////////////////////////

        getConfigFromAPI().then(config => {
            databaseLanguages = config.system.config.languages.database;
            databaseLanguages = databaseLanguages.map((value, key, array) => {
                return value.value;
            });

            frontendLanguages = config.system.config.languages.frontend;

            // apikey from baseconfig
            gfbio_apikey = info.config['plugin']['custom-data-type-gfbio'].config.apikey.apikey;

            // endpointurl from baseconfig
            endpointurl = info.config['plugin']['custom-data-type-gfbio'].config.endpointurl.endpointurl;

            if (endpointurl.charAt(endpointurl.length - 1) === '/') {
                endpointurl = endpointurl.slice(0, -1);
            }

            ////////////////////////////////////////////////////////////////////////////
            // availabilityCheck for gfbio-api
            ////////////////////////////////////////////////////////////////////////////
            let testURL = endpointurl + '/ontologies/ITIS?apikey=' + gfbio_apikey;
            https.get(testURL, res => {
                let testData = [];
                res.on('data', chunk => {
                    testData.push(chunk);
                });
                res.on('end', () => {
                    const testVocab = JSON.parse(Buffer.concat(testData).toString());
                    if (testVocab.acronym == 'ITIS') {
                        ////////////////////////////////////////////////////////////////////////////
                        // test successfull --> continue with custom-data-type-update
                        ////////////////////////////////////////////////////////////////////////////
                        process.stdin.on('readable', () => {
                            let chunk;
                            while ((chunk = process.stdin.read()) !== null) {
                                data = data + chunk
                            }
                        });
                        process.stdin.on('end', () => {
                            ///////////////////////////////////////
                            // continue with update-routine
                            ///////////////////////////////////////
                            try {
                                let payload = JSON.parse(data)
                                main(payload)
                            } catch (error) {
                                console.error("caught error", error)
                                outputErr(error)
                            }
                        });
                    } else {
                        console.error('Error while interpreting data from GFBIO-API.');
                    }
                });
            }).on('error', err => {
                console.error('Error while receiving data from GFBIO-API: ', err.message);
            });
        }).catch(error => {
            console.error('Es gab einen Fehler beim Laden der Konfiguration:', error);
        });
    }
    else {
        console.error("kein Accesstoken gefunden");
    }
})();