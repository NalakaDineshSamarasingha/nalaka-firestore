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

# Document not found error
public type DocumentNotFoundError distinct error;

# Authentication error
public type AuthenticationError distinct error;

# Query error
public type QueryError distinct error;

# Validation error
public type ValidationError distinct error;

# Operation result type
public type OperationResult record {|
    # Success status of the operation
    boolean success;
    # Document ID if applicable
    string? documentId = ();
    # Additional message about the operation
    string? message = ();
|};

# Document metadata
public type DocumentMetadata record {|
    # Document ID
    string id;
    # Full document path
    string name;
    # Document creation timestamp
    string createTime;
    # Document last update timestamp
    string updateTime;
|};

# Complete document with metadata
public type Document record {|
    # Document ID
    string id;
    # Full document path
    string name;
    # Document creation timestamp
    string createTime;
    # Document last update timestamp
    string updateTime;
    # Document field values
    map<json> fields;
|};

# Query options
public type QueryOptions record {|
    # Maximum number of results to return
    int? 'limit = ();
    # Number of results to skip
    int? offset = ();
    # Ordering specification (field -> "asc" | "desc")
    map<string>? orderBy = ();
    # Field paths to select in results
    string[]? selectedFields = ();
|};

# Update options
public type UpdateOptions record {|
    # Whether to merge with existing data or replace
    boolean merge = true;
    # Specific fields to update
    string[]? updateMask = ();
|};

# Batch operation type
public type BatchOperation record {|
    # Operation type: "create" | "update" | "delete"
    string operation;
    # Collection name
    string collection;
    # Document ID (optional for create operations)
    string? documentId = ();
    # Document data for create/update operations
    map<json>? data = ();
    # Update options for update operations
    UpdateOptions? options = ();
|};

# Firestore client for authentication and token management
public client isolated class Client {
    private ServiceAccount? serviceAccount;
    private FirebaseConfig? firebaseConfig;
    private JWTConfig? jwtConfig;
    private string? jwt = ();
    private string PRIVATE_KEY_PATH;
    private string? projectId = ();
    private string? cachedAccessToken = ();
    private time:Utc? tokenExpiry = ();

    # Initialize the Firestore client
    #
    # + authConfig - Authentication configuration
    # + return - Error if initialization fails
    public isolated function init(AuthConfig authConfig) returns error? {
        self.serviceAccount = ();
        self.firebaseConfig = ();
        self.jwtConfig = ();
        self.PRIVATE_KEY_PATH = PRIVATE_KEY_PATH;
        self.projectId = ();
        self.cachedAccessToken = ();
        self.tokenExpiry = ();
        
        lock {
            ServiceAccount serviceAccount = check self.getServiceAccount(authConfig.serviceAccountPath.cloneReadOnly());
            self.serviceAccount = serviceAccount.cloneReadOnly();
            self.projectId = serviceAccount.project_id;
        }
        
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

    # Get cached access token or generate new one if expired
    #
    # + return - Access token string or error
    public isolated function getAccessToken() returns string|error {
        lock {
            // Check if we have a cached token that's still valid
            if self.cachedAccessToken is string && self.tokenExpiry is time:Utc {
                time:Utc currentTime = time:utcNow();
                time:Utc tokenExpiry = <time:Utc>self.tokenExpiry;
                
                if currentTime[0] < tokenExpiry[0] {
                    return <string>self.cachedAccessToken;
                }
            }
            
            // Generate new token
            string newToken = check self.generateToken();
            self.cachedAccessToken = newToken;
            
            // Set expiry time (tokens are usually valid for 1 hour, we'll refresh 5 minutes early)
            time:Utc currentTime = time:utcNow();
            self.tokenExpiry = [currentTime[0] + 3300, currentTime[1]]; // 55 minutes from now
            
            return newToken;
        }
    }

    # Get the project ID
    #
    # + return - Project ID string or error
    public isolated function getProjectId() returns string|error {
        lock {
            if self.projectId is string {
                return <string>self.projectId;
            }
            return error("Project ID not available");
        }
    }

    # ===== CLIENT CRUD OPERATIONS =====

    # Create a document with auto-generated ID
    #
    # + collection - Firestore collection name
    # + documentData - Document data
    # + return - Operation result with document ID or error
    public isolated function add(string collection, map<json> documentData) returns OperationResult|error {
        string accessToken = check self.getAccessToken();
        string projectId = check self.getProjectId();
        return addDocument(projectId, accessToken, collection, documentData);
    }

    # Set a document with specific ID (create or replace)
    #
    # + collection - Firestore collection name
    # + documentId - Document ID to set
    # + documentData - Document data
    # + return - Operation result or error
    public isolated function set(string collection, string documentId, map<json> documentData) returns OperationResult|error {
        string accessToken = check self.getAccessToken();
        string projectId = check self.getProjectId();
        return setDocument(projectId, accessToken, collection, documentId, documentData);
    }

    # Get a single document by ID
    #
    # + collection - Firestore collection name
    # + documentId - Document ID to retrieve
    # + return - Document data or error
    public isolated function get(string collection, string documentId) returns map<json>|DocumentNotFoundError|error {
        string accessToken = check self.getAccessToken();
        string projectId = check self.getProjectId();
        return getDocument(projectId, accessToken, collection, documentId);
    }

    # Update an existing document
    #
    # + collection - Firestore collection name
    # + documentId - Document ID to update
    # + documentData - Document data to update
    # + options - Update options
    # + return - Operation result or error
    public isolated function update(string collection, string documentId, map<json> documentData, UpdateOptions options = {}) returns OperationResult|error {
        string accessToken = check self.getAccessToken();
        string projectId = check self.getProjectId();
        return updateDocument(projectId, accessToken, collection, documentId, documentData, options);
    }

    # Delete a document
    #
    # + collection - Firestore collection name
    # + documentId - Document ID to delete
    # + return - Operation result or error
    public isolated function delete(string collection, string documentId) returns OperationResult|error {
        string accessToken = check self.getAccessToken();
        string projectId = check self.getProjectId();
        return deleteDocument(projectId, accessToken, collection, documentId);
    }

    # Query documents with filters
    #
    # + collection - Firestore collection name
    # + filter - Filter conditions
    # + return - Array of documents or error
    public isolated function query(string collection, map<json> filter = {}) returns map<json>[]|error {
        string accessToken = check self.getAccessToken();
        string projectId = check self.getProjectId();
        return queryFirestoreDocuments(projectId, accessToken, collection, filter);
    }

    # Get all documents from a collection
    #
    # + collection - Firestore collection name
    # + options - Query options for pagination and ordering
    # + return - Array of documents or error
    public isolated function getAll(string collection, QueryOptions options = {}) returns map<json>[]|error {
        string accessToken = check self.getAccessToken();
        string projectId = check self.getProjectId();
        return getAllDocuments(projectId, accessToken, collection, options);
    }

    # Enhanced query with advanced filtering options
    #
    # + collection - Firestore collection name
    # + filter - Filter conditions with advanced operators
    # + options - Query options
    # + return - Array of documents or error
    public isolated function find(string collection, map<anydata> filter = {}, QueryOptions options = {}) returns map<json>[]|error {
        string accessToken = check self.getAccessToken();
        string projectId = check self.getProjectId();
        return findDocuments(projectId, accessToken, collection, filter, options);
    }

    # Count documents in a collection with optional filters
    #
    # + collection - Firestore collection name
    # + filter - Optional filter conditions
    # + return - Document count or error
    public isolated function count(string collection, map<json> filter = {}) returns int|error {
        string accessToken = check self.getAccessToken();
        string projectId = check self.getProjectId();
        return countDocuments(projectId, accessToken, collection, filter);
    }

    # Batch write operations (create, update, delete multiple documents)
    #
    # + operations - Array of batch operations
    # + return - Array of operation results or error
    public isolated function batchWrite(BatchOperation[] operations) returns OperationResult[]|error {
        string accessToken = check self.getAccessToken();
        string projectId = check self.getProjectId();
        return batchWrite(projectId, accessToken, operations);
    }

    # Create a document (convenience method for backward compatibility)
    #
    # + collection - Firestore collection name
    # + documentData - Document data
    # + return - Error if operation fails
    public isolated function createDocument(string collection, map<json> documentData) returns error? {
        OperationResult result = check self.add(collection, documentData);
        if !result.success {
            return error(result.message ?: "Failed to create document");
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
public isolated function createFirestoreDocument(
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
public isolated function processFirestoreValue(json value) returns map<json> {
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
public isolated function extractFirestoreValue(json firestoreValue) returns json|error {
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
public isolated function buildFirestoreFilter(map<json> filter) returns json {
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
public isolated function queryFirestoreDocuments(
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

# ===== COMPREHENSIVE CRUD OPERATIONS =====

# Get a single document by ID
#
# + projectId - Google Cloud project ID
# + accessToken - OAuth2 access token
# + collection - Firestore collection name
# + documentId - Document ID to retrieve
# + return - Document data or error
public isolated function getDocument(
    string projectId,
    string accessToken,
    string collection,
    string documentId
) returns map<json>|DocumentNotFoundError|error {
    string firestoreUrl = string `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}/${documentId}`;
    
    http:Client firestoreClient = check new(firestoreUrl);
    http:Request request = new;
    
    request.setHeader("Authorization", string `Bearer ${accessToken}`);
    
    http:Response response = check firestoreClient->get("");
    
    if response.statusCode == 404 {
        return error DocumentNotFoundError(string `Document with ID '${documentId}' not found in collection '${collection}'`);
    }
    
    if response.statusCode == 200 {
        json responsePayload = check response.getJsonPayload();
        
        if responsePayload is map<json> && responsePayload.hasKey("fields") {
            map<json> document = {};
            map<json> fields = <map<json>>responsePayload["fields"];
            
            foreach var [key, value] in fields.entries() {
                json|error extractedValue = extractFirestoreValue(value);
                if extractedValue is error {
                    log:printError("Error extracting field " + key, extractedValue);
                    continue;
                }
                document[key] = extractedValue;
            }
            
            // Only add document ID, not the metadata fields
            document["id"] = documentId;
            
            return document;
        }
    }
    
    string errorBody = check response.getTextPayload();
    string errorMessage = string `Failed to get document. Status code: ${response.statusCode} Error: ${errorBody}`;
    log:printError(errorMessage);
    return error(errorMessage);
}

# Update an existing document
#
# + projectId - Google Cloud project ID
# + accessToken - OAuth2 access token
# + collection - Firestore collection name
# + documentId - Document ID to update
# + documentData - Document data to update
# + options - Update options
# + return - Operation result or error
public isolated function updateDocument(
    string projectId,
    string accessToken,
    string collection,
    string documentId,
    map<json> documentData,
    UpdateOptions options = {}
) returns OperationResult|error {
    string firestoreUrl = string `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}/${documentId}`;
    
    http:Client firestoreClient = check new(firestoreUrl);
    http:Request request = new;
    
    request.setHeader("Authorization", string `Bearer ${accessToken}`);
    request.setHeader("Content-Type", "application/json");
    
    // Build query parameters
    string[] queryParams = [];
    
    if !options.merge {
        // Replace entire document
        queryParams.push("updateMask.fieldPaths=*");
    } else if options.updateMask is string[] {
        // Use explicit update mask
        string[] updateMask = <string[]>options.updateMask;
        foreach string fieldPath in updateMask {
            queryParams.push("updateMask.fieldPaths=" + fieldPath);
        }
    } else {
        // Default: merge mode - only update the fields provided in documentData
        foreach string fieldPath in documentData.keys() {
            queryParams.push("updateMask.fieldPaths=" + fieldPath);
        }
    }
    
    string queryString = queryParams.length() > 0 ? "?" + string:'join("&", ...queryParams) : "";
    
    map<map<json>> firestoreFields = {};
    foreach var [key, value] in documentData.entries() {
        firestoreFields[key] = processFirestoreValue(value);
    }

    json payload = {
        fields: firestoreFields
    };

    request.setJsonPayload(payload);

    http:Response response = check firestoreClient->patch(queryString, request);

    if response.statusCode == 200 {
        return {
            success: true,
            documentId: documentId,
            message: "Document updated successfully"
        };
    } else {
        string errorBody = check response.getTextPayload();
        string errorMessage = string `Failed to update document. Status code: ${response.statusCode} Error: ${errorBody}`;
        log:printError(errorMessage);
        return error(errorMessage);
    }
}

# Delete a document
#
# + projectId - Google Cloud project ID
# + accessToken - OAuth2 access token
# + collection - Firestore collection name
# + documentId - Document ID to delete
# + return - Operation result or error
public isolated function deleteDocument(
    string projectId,
    string accessToken,
    string collection,
    string documentId
) returns OperationResult|error {
    string firestoreUrl = string `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}/${documentId}`;
    
    http:Client firestoreClient = check new(firestoreUrl);
    http:Request request = new;
    
    request.setHeader("Authorization", string `Bearer ${accessToken}`);
    
    http:Response response = check firestoreClient->delete("");
    
    if response.statusCode == 200 {
        return {
            success: true,
            documentId: documentId,
            message: "Document deleted successfully"
        };
    } else if response.statusCode == 404 {
        return error DocumentNotFoundError(string `Document with ID '${documentId}' not found in collection '${collection}'`);
    } else {
        string errorBody = check response.getTextPayload();
        string errorMessage = string `Failed to delete document. Status code: ${response.statusCode} Error: ${errorBody}`;
        log:printError(errorMessage);
        return error(errorMessage);
    }
}

# Create a document with auto-generated ID
#
# + projectId - Google Cloud project ID
# + accessToken - OAuth2 access token
# + collection - Firestore collection name
# + documentData - Document data
# + return - Operation result with document ID or error
public isolated function addDocument(
    string projectId,
    string accessToken,
    string collection,
    map<json> documentData
) returns OperationResult|error {
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

    if response.statusCode == 200 {
        json responsePayload = check response.getJsonPayload();
        
        if responsePayload is map<json> && responsePayload.hasKey("name") {
            string documentPath = <string>responsePayload["name"];
            string[] pathParts = regex:split(documentPath, "/");
            string documentId = pathParts[pathParts.length() - 1];
            
            return {
                success: true,
                documentId: documentId,
                message: "Document created successfully with auto-generated ID"
            };
        }
    }
    
    string errorBody = check response.getTextPayload();
    string errorMessage = string `Failed to create document. Status code: ${response.statusCode} Error: ${errorBody}`;
    log:printError(errorMessage);
    return error(errorMessage);
}

# Set a document with specific ID (create or replace)
#
# + projectId - Google Cloud project ID
# + accessToken - OAuth2 access token
# + collection - Firestore collection name
# + documentId - Document ID to set
# + documentData - Document data
# + return - Operation result or error
public isolated function setDocument(
    string projectId,
    string accessToken,
    string collection,
    string documentId,
    map<json> documentData
) returns OperationResult|error {
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

    // Use documentId as query parameter for setting specific ID
    http:Response response = check firestoreClient->post(string `?documentId=${documentId}`, request);

    if response.statusCode == 200 {
        return {
            success: true,
            documentId: documentId,
            message: "Document set successfully"
        };
    } else {
        string errorBody = check response.getTextPayload();
        string errorMessage = string `Failed to set document. Status code: ${response.statusCode} Error: ${errorBody}`;
        log:printError(errorMessage);
        return error(errorMessage);
    }
}

# Get all documents from a collection
#
# + projectId - Google Cloud project ID
# + accessToken - OAuth2 access token
# + collection - Firestore collection name
# + options - Query options for pagination and ordering
# + return - Array of documents or error
public isolated function getAllDocuments(
    string projectId,
    string accessToken,
    string collection,
    QueryOptions options = {}
) returns map<json>[]|error {
    string firestoreUrl = string `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
    
    http:Client firestoreClient = check new(firestoreUrl);
    http:Request request = new;
    
    request.setHeader("Authorization", string `Bearer ${accessToken}`);
    request.setHeader("Content-Type", "application/json");
    
    map<json> structuredQuery = {
        "from": [{"collectionId": collection}]
    };
    
    // Add ordering
    if options.orderBy is map<string> {
        map<string> orderBy = <map<string>>options.orderBy;
        json[] orderByArray = [];
        
        foreach var [fieldName, direction] in orderBy.entries() {
            json orderClause = {
                "field": {"fieldPath": fieldName},
                "direction": direction.toUpperAscii()
            };
            orderByArray.push(orderClause);
        }
        
        structuredQuery["orderBy"] = orderByArray;
    }
    
    // Add limit
    if options.'limit is int {
        structuredQuery["limit"] = <int>options.'limit;
    }
    
    // Add offset
    if options.offset is int {
        structuredQuery["offset"] = <int>options.offset;
    }
    
    // Add field selection
    if options.selectedFields is string[] {
        string[] selectedFields = <string[]>options.selectedFields;
        json[] projectionFields = [];
        
        foreach string fieldPath in selectedFields {
            projectionFields.push({"fieldPath": fieldPath});
        }
        
        structuredQuery["select"] = {"fields": projectionFields};
    }

    json queryPayload = {
        "structuredQuery": structuredQuery
    };
    
    request.setJsonPayload(queryPayload);
    
    http:Response response = check firestoreClient->post("", request);

    log:printInfo("Response status code: " + response.statusCode.toString());
    
    if response.statusCode == 200 {
        json responsePayload = check response.getJsonPayload();
        
        json[] responseArray = [];
        if responsePayload is json[] {
            responseArray = responsePayload;
        } else if responsePayload is json {
            responseArray = [responsePayload];
        } 
        
        map<json>[] results = [];
        
        foreach json item in responseArray {
            if item is map<json> && item.hasKey("document") {
                map<json> documentWrapper = <map<json>>item["document"];
                
                if documentWrapper.hasKey("fields") {
                    map<json> document = {};
                    map<json> fields = <map<json>>documentWrapper["fields"];
                    
                    foreach var [key, value] in fields.entries() {
                        json|error extractedValue = extractFirestoreValue(value);
                        if extractedValue is error {
                            log:printError("Error extracting field " + key, extractedValue);
                            continue;
                        }
                        document[key] = extractedValue;
                    }
                    
                    // Add document ID
                    if documentWrapper.hasKey("name") {
                        string documentPath = <string>documentWrapper["name"];
                        string[] pathParts = regex:split(documentPath, "/");
                        document["id"] = pathParts[pathParts.length() - 1];
                    }
                    
                    results.push(document);
                }
            }
        }
        
        return results;
        
    } else {
        string errorBody = check response.getTextPayload();
        string errorMessage = string `Failed to get all documents. Status code: ${response.statusCode} Error: ${errorBody}`;
        log:printError(errorMessage);
        return error(errorMessage);
    }
}

# ===== ADVANCED OPERATIONS =====

# Count documents in a collection with optional filters
#
# + projectId - Google Cloud project ID
# + accessToken - OAuth2 access token
# + collection - Firestore collection name
# + filter - Optional filter conditions
# + return - Document count or error
public isolated function countDocuments(
    string projectId,
    string accessToken,
    string collection,
    map<json> filter = {}
) returns int|error {
    string firestoreUrl = string `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runAggregationQuery`;
    
    http:Client firestoreClient = check new(firestoreUrl);
    http:Request request = new;
    
    request.setHeader("Authorization", string `Bearer ${accessToken}`);
    request.setHeader("Content-Type", "application/json");
    
    map<json> structuredAggregationQuery = {
        "structuredQuery": {
            "from": [{"collectionId": collection}]
        },
        "aggregations": [
            {
                "count": {},
                "alias": "total_count"
            }
        ]
    };
    
    // Add where clause if filter is provided
    if filter.length() > 0 {
        json whereFilter = buildFirestoreFilter(filter);
        map<json> structuredQuery = <map<json>>structuredAggregationQuery["structuredQuery"];
        structuredQuery["where"] = whereFilter;
    }
    
    request.setJsonPayload(structuredAggregationQuery);
    
    http:Response response = check firestoreClient->post("", request);
    
    if response.statusCode == 200 {
        json responsePayload = check response.getJsonPayload();
        
        if responsePayload is json[] && responsePayload.length() > 0 {
            json firstResult = responsePayload[0];
            if firstResult is map<json> && firstResult.hasKey("result") {
                map<json> result = <map<json>>firstResult["result"];
                if result.hasKey("aggregateFields") {
                    map<json> aggregateFields = <map<json>>result["aggregateFields"];
                    if aggregateFields.hasKey("total_count") {
                        map<json> countValue = <map<json>>aggregateFields["total_count"];
                        if countValue.hasKey("integerValue") {
                            json integerValueJson = countValue["integerValue"];
                            if integerValueJson is string {
                                return check int:fromString(integerValueJson);
                            } else if integerValueJson is int {
                                return integerValueJson;
                            }
                        }
                    }
                }
            }
        }
        
        return 0; // Default to 0 if count not found
    } else {
        string errorBody = check response.getTextPayload();
        string errorMessage = string `Failed to count documents. Status code: ${response.statusCode} Error: ${errorBody}`;
        log:printError(errorMessage);
        return error(errorMessage);
    }
}

# Batch write operations (create, update, delete multiple documents)
#
# + projectId - Google Cloud project ID
# + accessToken - OAuth2 access token
# + operations - Array of batch operations
# + return - Array of operation results or error
public isolated function batchWrite(
    string projectId,
    string accessToken,
    BatchOperation[] operations
) returns OperationResult[]|error {
    if operations.length() == 0 {
        return [];
    }
    
    if operations.length() > 500 {
        return error ValidationError("Batch operations cannot exceed 500 operations");
    }
    
    string firestoreUrl = string `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:batchWrite`;
    
    http:Client firestoreClient = check new(firestoreUrl);
    http:Request request = new;
    
    request.setHeader("Authorization", string `Bearer ${accessToken}`);
    request.setHeader("Content-Type", "application/json");
    
    json[] writes = [];
    
    foreach BatchOperation operation in operations {
        json write = {};
        
        if operation.operation == "create" || operation.operation == "update" {
            if operation.data is () {
                return error ValidationError(string `Data is required for ${operation.operation} operation`);
            }
            
            map<json> documentData = <map<json>>operation.data;
            map<map<json>> firestoreFields = {};
            
            foreach var [key, value] in documentData.entries() {
                firestoreFields[key] = processFirestoreValue(value);
            }
            
            string documentPath = string `projects/${projectId}/databases/(default)/documents/${operation.collection}`;
            if operation.documentId is string {
                documentPath = documentPath + "/" + <string>operation.documentId;
            }
            
            if operation.operation == "create" {
                write = {
                    "update": {
                        "name": documentPath,
                        "fields": firestoreFields
                    },
                    "currentDocument": {
                        "exists": false
                    }
                };
            } else { // update
                write = {
                    "update": {
                        "name": documentPath,
                        "fields": firestoreFields
                    }
                };
                
                // Add update mask if specified
                if operation.options is UpdateOptions {
                    UpdateOptions updateOptions = <UpdateOptions>operation.options;
                    if updateOptions.updateMask is string[] {
                        map<json> writeMap = <map<json>>write;
                        writeMap["updateMask"] = {
                            "fieldPaths": updateOptions.updateMask
                        };
                        write = writeMap;
                    }
                }
            }
            
        } else if operation.operation == "delete" {
            if operation.documentId is () {
                return error ValidationError("Document ID is required for delete operation");
            }
            
            string documentPath = string `projects/${projectId}/databases/(default)/documents/${operation.collection}/${<string>operation.documentId}`;
            write = {
                "delete": documentPath
            };
        } else {
            return error ValidationError(string `Unknown operation: ${operation.operation}`);
        }
        
        writes.push(write);
    }
    
    json batchPayload = {
        "writes": writes
    };
    
    request.setJsonPayload(batchPayload);
    
    http:Response response = check firestoreClient->post("", request);
    
    if response.statusCode == 200 {
        json responsePayload = check response.getJsonPayload();
        OperationResult[] results = [];
        
        if responsePayload is map<json> && responsePayload.hasKey("writeResults") {
            json[] writeResults = <json[]>responsePayload["writeResults"];
            
            foreach int i in 0 ..< writeResults.length() {
                BatchOperation operation = operations[i];
                json writeResult = writeResults[i];
                
                OperationResult result = {
                    success: true,
                    message: string `${operation.operation} operation completed successfully`
                };
                
                // Extract document ID from the result if available
                if writeResult is map<json> && writeResult.hasKey("updateTime") {
                    result.documentId = operation.documentId;
                } else if operation.operation == "create" && writeResult is map<json> && writeResult.hasKey("transformResults") {
                    // For auto-generated IDs, we might need to extract from the response
                    result.documentId = operation.documentId;
                }
                
                results.push(result);
            }
        }
        
        return results;
        
    } else {
        string errorBody = check response.getTextPayload();
        string errorMessage = string `Failed to execute batch write. Status code: ${response.statusCode} Error: ${errorBody}`;
        log:printError(errorMessage);
        return error(errorMessage);
    }
}

# Enhanced query with advanced filtering options
#
# + projectId - Google Cloud project ID
# + accessToken - OAuth2 access token
# + collection - Firestore collection name
# + filter - Filter conditions with advanced operators
# + options - Query options
# + return - Array of documents or error
public isolated function findDocuments(
    string projectId,
    string accessToken,
    string collection,
    map<anydata> filter = {},
    QueryOptions options = {}
) returns map<json>[]|error {
    string firestoreUrl = string `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
    
    http:Client firestoreClient = check new(firestoreUrl);
    http:Request request = new;
    
    request.setHeader("Authorization", string `Bearer ${accessToken}`);
    request.setHeader("Content-Type", "application/json");
    
    map<json> structuredQuery = {
        "from": [{"collectionId": collection}]
    };
    
    // Build advanced where clause
    if filter.length() > 0 {
        json whereFilter = buildAdvancedFilter(filter);
        structuredQuery["where"] = whereFilter;
    }
    
    // Add ordering
    if options.orderBy is map<string> {
        map<string> orderBy = <map<string>>options.orderBy;
        json[] orderByArray = [];
        
        foreach var [fieldName, direction] in orderBy.entries() {
            json orderClause = {
                "field": {"fieldPath": fieldName},
                "direction": direction.toUpperAscii()
            };
            orderByArray.push(orderClause);
        }
        
        structuredQuery["orderBy"] = orderByArray;
    }
    
    // Add limit
    if options.'limit is int {
        structuredQuery["limit"] = <int>options.'limit;
    }
    
    // Add offset
    if options.offset is int {
        structuredQuery["offset"] = <int>options.offset;
    }
    
    // Add field selection
    if options.selectedFields is string[] {
        string[] selectedFields = <string[]>options.selectedFields;
        json[] projectionFields = [];
        
        foreach string fieldPath in selectedFields {
            projectionFields.push({"fieldPath": fieldPath});
        }
        
        structuredQuery["select"] = {"fields": projectionFields};
    }

    json queryPayload = {
        "structuredQuery": structuredQuery
    };
    
    request.setJsonPayload(queryPayload);
    
    http:Response response = check firestoreClient->post("", request);
    
    if response.statusCode == 200 {
        json responsePayload = check response.getJsonPayload();
        return extractDocumentsFromResponse(responsePayload);
    } else {
        string errorBody = check response.getTextPayload();
        string errorMessage = string `Failed to find documents. Status code: ${response.statusCode} Error: ${errorBody}`;
        log:printError(errorMessage);
        return error(errorMessage);
    }
}

# Build advanced filter with multiple operators
#
# + filter - Filter conditions with advanced operators
# + return - Firestore formatted filter
isolated function buildAdvancedFilter(map<anydata> filter) returns json {
    if filter.length() == 0 {
        return {};
    }
    
    json[] filters = [];
    
    foreach var [key, value] in filter.entries() {
        if value is map<anydata> {
            // Advanced filter with operators like {"age": {">=": 18}}
            map<anydata> conditions = <map<anydata>>value;
            foreach var [operator, operandValue] in conditions.entries() {
                json fieldFilter = {
                    "fieldFilter": {
                        "field": {"fieldPath": key},
                        "op": getFirestoreOperator(operator),
                        "value": processFirestoreValue(<json>operandValue)
                    }
                };
                filters.push(fieldFilter);
            }
        } else {
            // Simple equality filter
            json fieldFilter = {
                "fieldFilter": {
                    "field": {"fieldPath": key},
                    "op": "EQUAL",
                    "value": processFirestoreValue(<json>value)
                }
            };
            filters.push(fieldFilter);
        }
    }
    
    if filters.length() == 1 {
        return filters[0];
    } else {
        return {
            "compositeFilter": {
                "op": "AND",
                "filters": filters
            }
        };
    }
}

# Convert operator to Firestore format
#
# + operator - Operator string
# + return - Firestore operator string
isolated function getFirestoreOperator(string operator) returns string {
    match operator {
        ">" => { return "GREATER_THAN"; }
        ">=" => { return "GREATER_THAN_OR_EQUAL"; }
        "<" => { return "LESS_THAN"; }
        "<=" => { return "LESS_THAN_OR_EQUAL"; }
        "!=" => { return "NOT_EQUAL"; }
        "==" => { return "EQUAL"; }
        "array-contains" => { return "ARRAY_CONTAINS"; }
        "array-contains-any" => { return "ARRAY_CONTAINS_ANY"; }
        "in" => { return "IN"; }
        "not-in" => { return "NOT_IN"; }
        _ => { return "EQUAL"; }
    }
}

# Extract documents from Firestore response
#
# + responsePayload - Firestore response payload
# + return - Array of extracted documents or error
isolated function extractDocumentsFromResponse(json responsePayload) returns map<json>[]|error {
    json[] responseArray = [];
    if responsePayload is json[] {
        responseArray = responsePayload;
    } else if responsePayload is json {
        responseArray = [responsePayload];
    }
    
    map<json>[] results = [];
    
    foreach json item in responseArray {
        if item is map<json> && item.hasKey("document") {
            map<json> documentWrapper = <map<json>>item["document"];
            
            if documentWrapper.hasKey("fields") {
                map<json> document = {};
                map<json> fields = <map<json>>documentWrapper["fields"];
                
                foreach var [key, value] in fields.entries() {
                    json|error extractedValue = extractFirestoreValue(value);
                    if extractedValue is error {
                        log:printError("Error extracting field " + key, extractedValue);
                        continue;
                    }
                    document[key] = extractedValue;
                }
                
                // Add only document ID, not metadata
                if documentWrapper.hasKey("name") {
                    string documentPath = <string>documentWrapper["name"];
                    string[] pathParts = regex:split(documentPath, "/");
                    document["id"] = pathParts[pathParts.length() - 1];
                }
                
                results.push(document);
            }
        }
    }
    
    return results;
}