import ballerina/http;
import ballerina/io;
import ballerina/jwt;
import ballerina/log;
import ballerina/oauth2;
import ballerina/regex;
import ballerina/time;

# Default private key file path
const string PRIVATE_KEY_PATH = "./private.key";

# Service Account record type
public type ServiceAccount record {|
    # Service account type
    string 'type;
    # Google Cloud project ID
    string project_id;
    # Private key ID
    string private_key_id;
    # Private key
    string private_key;
    #
    string client_email;
    #
    string client_id;
    #
    string auth_uri;
    #
    string token_uri;
    #
    string auth_provider_x509_cert_url;
    # Client X.509 certificate URL
    string client_x509_cert_url;
    # Universe domain
    string universe_domain;
|};

# Firebase configuration record type
public type FirebaseConfig record {|
    #
    string? apiKey = ();
    #
    string? authDomain = ();
    #
    string? databaseURL = ();
    #
    string? projectId = ();
    #
    string? storageBucket = ();
    #
    string? messagingSenderId = ();
    #
    string? appId = ();
    #
    string? measurementId = ();
|};

# JWT configuration record type
public type JWTConfig record {|
    #
    string scope;
    #
    decimal expTime;
|};

# Authentication configuration record type
public type AuthConfig record {|
    # Service account file path
    string serviceAccountPath;
    # Firebase config
    readonly & FirebaseConfig? firebaseConfig = ();
    # JWT config
    readonly & JWTConfig jwtConfig;
    # Private key file path
    string privateKeyPath = PRIVATE_KEY_PATH;
|};

# Client error type
public type ClientError distinct error;

# Firestore client for authentication and token management
public client isolated class Client {
    private ServiceAccount? serviceAccount;
    private FirebaseConfig? firebaseConfig;
    private JWTConfig? jwtConfig;
    private string? jwt = ();
    private string PRIVATE_KEY_PATH;

    # Initialize the Firestore client
    #
    # + authConfig - Authentication configuration
    # + return - Error if initialization fails
    public isolated function init(AuthConfig authConfig) returns error? {
        self.serviceAccount = ();
        self.firebaseConfig = ();
        self.jwtConfig = ();
        self.PRIVATE_KEY_PATH = PRIVATE_KEY_PATH;
        self.serviceAccount = check self.getServiceAccount(authConfig.serviceAccountPath.cloneReadOnly());
        self.firebaseConfig = self.getFirebaseConfig(authConfig.firebaseConfig.cloneReadOnly());
        self.jwtConfig = authConfig.jwtConfig;
        self.PRIVATE_KEY_PATH = authConfig.privateKeyPath;
        check self.createPrivateKey();
        return;
    }

    # Load service account from JSON file
    #
    # + path - Path to service account JSON file
    # + return - ServiceAccount record or error
    isolated function getServiceAccount(string path) returns ServiceAccount|error {
        json serviceAccountFileInput = check io:fileReadJson(path);
        return check serviceAccountFileInput.cloneWithType(ServiceAccount);
    }

    # Create private key file from service account
    #
    # + return - Error if creation fails
    isolated function createPrivateKey() returns error? {
        lock {
            ServiceAccount? serviceAccount = self.serviceAccount;
            if serviceAccount is () {
                return error("Service Account is not provided");
            }
            string[] privateKeyLine = regex:split(serviceAccount.private_key, "\n");
            stream<string, io:Error?> lineStream = privateKeyLine.toStream();
            check io:fileWriteLinesFromStream(self.PRIVATE_KEY_PATH, lineStream);
        }
    }

    # Get Firebase configuration
    #
    # + firebaseConfig - Firebase configuration
    # + return - FirebaseConfig or null
    isolated function getFirebaseConfig(FirebaseConfig? firebaseConfig) returns FirebaseConfig|() {
        if (firebaseConfig is FirebaseConfig) {
            return firebaseConfig;
        }
        return ();
    }

    # Generate JWT token
    #
    # + serviceAccount - Service account configuration
    # + return - JWT token string or error
    isolated function generateJWT(ServiceAccount serviceAccount) returns string|error {
        lock {
            JWTConfig? jwtConfig = self.jwtConfig;
            if jwtConfig is () {
                return error("JWT Config is not provided");
            }
            int timeNow = time:utcNow()[0];
            int expTime = timeNow + <int>jwtConfig.expTime;
            jwt:IssuerConfig issuerConfig = {
                issuer: serviceAccount.client_email,
                audience: serviceAccount.token_uri,
                expTime: jwtConfig.expTime,
                signatureConfig: {
                    algorithm: jwt:RS256,
                    config: {
                        keyFile: self.PRIVATE_KEY_PATH
                    }
                },
                customClaims: {
                    iss: serviceAccount.client_email,
                    scope: jwtConfig.scope,
                    aud: serviceAccount.token_uri,
                    iat: timeNow,
                    exp: expTime
                }
            };
            string jwt = check jwt:issue(issuerConfig);
            self.jwt = jwt;
            return jwt;
        }
    }

    # Check if JWT token is expired
    #
    # + jwt - JWT token to check
    # + return - True if expired, false otherwise, or error
    isolated function isJWTExpired(string jwt) returns boolean|error {
        [jwt:Header, jwt:Payload] [_, payload] = check jwt:decode(jwt);
        int? exp = payload.exp;
        if (exp is int) {
            int timeNow = time:utcNow()[0];
            return exp < timeNow;
        }
        return error("Error in decoding JWT");
    }

    # Generate OAuth2 access token for Firestore API
    #
    # + return - Access token string or error
    public isolated function generateToken() returns string|error {
        string jwt = "";
        lock {
            ServiceAccount? serviceAccount = self.serviceAccount.cloneReadOnly();
            if serviceAccount is () {
                return error("Service Account is not provided");
            }
            if self.jwt is () {
                jwt = check self.generateJWT(serviceAccount);
            }

            boolean|error isExpired = self.isJWTExpired(jwt);

            if isExpired is error {
                error er = isExpired;
                log:printError(er.message());
                return er;
            }

            if isExpired {
                jwt = check self.generateJWT(serviceAccount);
            }

            oauth2:JwtBearerGrantConfig jwtBearerGrantConfig = {
                tokenUrl: serviceAccount.token_uri,
                assertion: jwt
            };
            oauth2:ClientOAuth2Provider oauth2Provider = new (jwtBearerGrantConfig);
            string|error response = oauth2Provider.generateToken();

            if (response is error) {
                log:printError(response.message());
                return response;
            }

            return response;
        }
    }
}

# Create a new document in Firestore collection
#
# + projectId - Google Cloud project ID
# + accessToken - OAuth2 access token
# + collection - Firestore collection name
# + documentData - Document data as map of JSON values
# + return - Error if operation fails
public function createFirestoreDocument(
    string projectId, 
    string accessToken, 
    string collection, 
    map<json> documentData
) returns error? {
    string firestoreUrl = string `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}`;
    
    http:Client firestoreClient = check new(firestoreUrl);
    http:Request request = new;
    
    request.setHeader("Authorization", string `Bearer ${accessToken}`);
    request.setHeader("Content-Type", "application/json");
    
    map<map<json>> firestoreFields = {};
    foreach var [key, value] in documentData.entries() {
        firestoreFields[key] = processFirestoreValue(value);
    }

    json payload = {
        fields: firestoreFields
    };

    request.setJsonPayload(payload);

    http:Response response = check firestoreClient->post("", request);

    io:println(response);
}

# Convert Ballerina value to Firestore format
#
# + value - JSON value to convert
# + return - Firestore formatted value
public function processFirestoreValue(json value) returns map<json> {
    if value is string {
        return {"stringValue": value};
    } else if value is int {
        return {"integerValue": value};
    } else if value is boolean {
        return {"booleanValue": value};
    } else if value is () {
        return {"nullValue": null};
    } else if value is float {
        return {"doubleValue": value};
    } else if value is map<json> {
        map<map<json>> convertedMap = {};
        foreach var [key, val] in value.entries() {
            convertedMap[key] = processFirestoreValue(val);
        }
        return {"mapValue": {"fields": convertedMap}};
    } else if value is json[] {
        json[] convertedArray = value.map(processFirestoreValue);
        return {"arrayValue": {"values": convertedArray}};
    } else {
        return {"stringValue": value.toJsonString()};
    }
}

# Extract value from Firestore format to Ballerina format
#
# + firestoreValue - Firestore formatted value
# + return - Extracted JSON value or error
public function extractFirestoreValue(json firestoreValue) returns json|error {
    if (!(firestoreValue is map<json>)) {
        return error("Invalid Firestore value format");
    }
    
    map<json> valueMap = <map<json>>firestoreValue;
    
    if valueMap.hasKey("stringValue") {
        return valueMap["stringValue"];
    } else if valueMap.hasKey("integerValue") {
        json integerValueJson = valueMap["integerValue"];
        if (integerValueJson is string) {
            return check int:fromString(integerValueJson);
        } else if (integerValueJson is int) {
            return integerValueJson;
        } else {
            return error("Invalid integer value format");
        }
    } else if valueMap.hasKey("booleanValue") {
        return valueMap["booleanValue"];
    } else if valueMap.hasKey("nullValue") {
        return null;
    } else if valueMap.hasKey("doubleValue") {
        json doubleValueJson = valueMap["doubleValue"];
        if (doubleValueJson is string) {
            return check float:fromString(doubleValueJson);
        } else if (doubleValueJson is float) {
            return doubleValueJson;
        } else {
            return error("Invalid double value format");
        }
    } else if valueMap.hasKey("mapValue") {
        map<json> result = {};
        json mapValueJson = valueMap["mapValue"];
        
        if (mapValueJson is map<json> && mapValueJson.hasKey("fields")) {
            map<json> fields = <map<json>>mapValueJson["fields"];
            
            foreach var [key, val] in fields.entries() {
                result[key] = check extractFirestoreValue(val);
            }
        }
        
        return result;
    } else if valueMap.hasKey("arrayValue") {
        json[] result = [];
        json arrayValueJson = valueMap["arrayValue"];
        
        if (arrayValueJson is map<json> && arrayValueJson.hasKey("values")) {
            json valuesJson = arrayValueJson["values"];
            if (valuesJson is json[]) {
                foreach var item in valuesJson {
                    result.push(check extractFirestoreValue(item));
                }
            }
        }
        
        return result;
    } else {
        log:printError("Unknown Firestore value type: " + firestoreValue.toJsonString());
        return "UNKNOWN_TYPE";
    }
}

# Build Firestore query filter from map
#
# + filter - Filter conditions as key-value pairs
# + return - Firestore formatted filter
public function buildFirestoreFilter(map<json> filter) returns json {
    if filter.length() == 0 {
        return {};
    }
    
    if filter.length() == 1 {
        string key = filter.keys()[0];
        json value = filter[key];
        
        return {
            "fieldFilter": {
                "field": {"fieldPath": key},
                "op": "EQUAL",
                "value": processFirestoreValue(value)
            }
        };
    }
    
    // For multiple conditions, create a composite filter
    json[] filters = [];
    
    foreach var [key, value] in filter.entries() {
        json singleFilter = {
            "fieldFilter": {
                "field": {"fieldPath": key},
                "op": "EQUAL",
                "value": processFirestoreValue(value)
            }
        };
        
        filters.push(singleFilter);
    }
    
    return {
        "compositeFilter": {
            "op": "AND",
            "filters": filters
        }
    };
}

# Query Firestore documents with filters
#
# + projectId - Google Cloud project ID
# + accessToken - OAuth2 access token
# + collection - Firestore collection name
# + filter - Filter conditions
# + return - Array of documents or error
public function queryFirestoreDocuments(
    string projectId,
    string accessToken,
    string collection,
    map<json> filter
) returns map<json>[]|error {
    string firestoreUrl = string `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
    
    http:Client firestoreClient = check new(firestoreUrl);
    http:Request request = new;
    
    request.setHeader("Authorization", string `Bearer ${accessToken}`);
    request.setHeader("Content-Type", "application/json");
    
    json whereFilter = buildFirestoreFilter(filter);

    json queryPayload = {
        "structuredQuery": {
            "from": [{"collectionId": collection}],
            "where": whereFilter
        }
    };
    
    request.setJsonPayload(queryPayload);
    
    http:Response response = check firestoreClient->post("", request);

    log:printInfo("Response status code: " + response.statusCode.toString());
    
    if (response.statusCode == 200) {
        json responsePayload = check response.getJsonPayload();
        
        // Handle both array and single object responses
        json[] responseArray = [];
        if (responsePayload is json[]) {
            responseArray = responsePayload;
        } else if (responsePayload is json) {
            // If it's a single object, wrap it in an array
            responseArray = [responsePayload];
        } 
        map<json>[] results = [];
        
        log:printInfo("Processing " + responseArray.length().toString() + " documents");
        
        foreach json item in responseArray {
            // Check if the item has a document field
            if (item is map<json> && item.hasKey("document")) {
                map<json> documentWrapper = <map<json>>item["document"];
                
                if (documentWrapper.hasKey("fields")) {
                    map<json> document = {};
                    map<json> fields = <map<json>>documentWrapper["fields"];
                    
                    // Extract each field
                    foreach var [key, value] in fields.entries() {
                        json|error extractedValue = extractFirestoreValue(value);
                        if (extractedValue is error) {
                            log:printError("Error extracting field " + key, extractedValue);
                            continue;
                        }
                        document[key] = extractedValue;
                    }
                    
                    // Add the document ID from the name field
                    if (documentWrapper.hasKey("name")) {
                        string documentPath = <string>documentWrapper["name"];
                        string[] pathParts = regex:split(documentPath, "/");
                        document["id"] = pathParts[pathParts.length() - 1];
                    }
                    
                    results.push(document);
                } else {
                    log:printError("Document does not have fields property");
                }
            } else {
                log:printError("Item does not have document property");
                log:printError("Item structure: " + item.toJsonString());
            }
        }
        
        log:printInfo("Successfully processed " + results.length().toString() + " documents");
        return results;
        
    } else {
        string errorBody = check response.getTextPayload();
        string errorMessage = "Failed to query documents. Status code: " + response.statusCode.toString() + " Error: " + errorBody;
        log:printError(errorMessage);
        return error(errorMessage);
    }
}