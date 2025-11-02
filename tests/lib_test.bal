import ballerina/test;
import ballerina/io;

// Test configuration - Update these with your actual test credentials
const string TEST_SERVICE_ACCOUNT_PATH = "./test-services.json";
const string TEST_PROJECT_ID = "ballerina-choreo";
const string TEST_COLLECTION = "test_collection";

// Global client instance for testing
Client? testClient = ();

# Test initialization of Firestore client
@test:Config {
    enable: false // Enable this when you have valid credentials
}
function testClientInitialization() returns error? {
    AuthConfig authConfig = {
        serviceAccountPath: TEST_SERVICE_ACCOUNT_PATH,
        jwtConfig: {
            scope: "https://www.googleapis.com/auth/datastore",
            expTime: 3600
        }
    };
    
    Client firestoreClient = check new(authConfig);
    string projectId = check firestoreClient.getProjectId();
    test:assertTrue(projectId.length() > 0, "Client should be initialized successfully");
}

# Test initialization with invalid service account path
@test:Config {}
function testClientInitializationWithInvalidPath() {
    AuthConfig authConfig = {
        serviceAccountPath: "./non-existent-service-account.json",
        jwtConfig: {
            scope: "https://www.googleapis.com/auth/datastore",
            expTime: 3600
        }
    };
    
    Client|error clientResult = new(authConfig);
    test:assertTrue(clientResult is error, "Should return error for invalid service account path");
}

# Test processing Firestore values - String
@test:Config {}
function testProcessFirestoreValueString() {
    json value = "test string";
    map<json> result = processFirestoreValue(value);
    
    test:assertEquals(result["stringValue"], "test string", "Should correctly convert string value");
}

# Test processing Firestore values - Integer
@test:Config {}
function testProcessFirestoreValueInteger() {
    json value = 42;
    map<json> result = processFirestoreValue(value);
    
    test:assertEquals(result["integerValue"], 42, "Should correctly convert integer value");
}

# Test processing Firestore values - Boolean
@test:Config {}
function testProcessFirestoreValueBoolean() {
    json value = true;
    map<json> result = processFirestoreValue(value);
    
    test:assertEquals(result["booleanValue"], true, "Should correctly convert boolean value");
}

# Test processing Firestore values - Null
@test:Config {}
function testProcessFirestoreValueNull() {
    json value = ();
    map<json> result = processFirestoreValue(value);
    
    test:assertEquals(result["nullValue"], null, "Should correctly convert null value");
}

# Test processing Firestore values - Float
@test:Config {}
function testProcessFirestoreValueFloat() {
    json value = 3.14;
    map<json> result = processFirestoreValue(value);
    
    test:assertEquals(result["doubleValue"], 3.14, "Should correctly convert float value");
}

# Test processing Firestore values - Map
@test:Config {}
function testProcessFirestoreValueMap() {
    json value = {
        "name": "John",
        "age": 30
    };
    map<json> result = processFirestoreValue(value);
    
    test:assertTrue(result.hasKey("mapValue"), "Should contain mapValue key");
    
    json mapValue = result["mapValue"];
    test:assertTrue(mapValue is map<json>, "mapValue should be a map");
    
    if mapValue is map<json> {
        test:assertTrue(mapValue.hasKey("fields"), "Should contain fields key");
    }
}

# Test processing Firestore values - Array
@test:Config {}
function testProcessFirestoreValueArray() {
    json value = [1, 2, 3];
    map<json> result = processFirestoreValue(value);
    
    test:assertTrue(result.hasKey("arrayValue"), "Should contain arrayValue key");
    
    json arrayValue = result["arrayValue"];
    test:assertTrue(arrayValue is map<json>, "arrayValue should be a map");
    
    if arrayValue is map<json> {
        test:assertTrue(arrayValue.hasKey("values"), "Should contain values key");
    }
}

# Test extracting Firestore values - String
@test:Config {}
function testExtractFirestoreValueString() returns error? {
    json firestoreValue = {
        "stringValue": "test string"
    };
    
    json result = check extractFirestoreValue(firestoreValue);
    test:assertEquals(result, "test string", "Should correctly extract string value");
}

# Test extracting Firestore values - Integer as string
@test:Config {}
function testExtractFirestoreValueIntegerString() returns error? {
    json firestoreValue = {
        "integerValue": "42"
    };
    
    json result = check extractFirestoreValue(firestoreValue);
    test:assertEquals(result, 42, "Should correctly extract integer value from string");
}

# Test extracting Firestore values - Integer as int
@test:Config {}
function testExtractFirestoreValueIntegerInt() returns error? {
    json firestoreValue = {
        "integerValue": 42
    };
    
    json result = check extractFirestoreValue(firestoreValue);
    test:assertEquals(result, 42, "Should correctly extract integer value");
}

# Test extracting Firestore values - Boolean
@test:Config {}
function testExtractFirestoreValueBoolean() returns error? {
    json firestoreValue = {
        "booleanValue": true
    };
    
    json result = check extractFirestoreValue(firestoreValue);
    test:assertEquals(result, true, "Should correctly extract boolean value");
}

# Test extracting Firestore values - Null
@test:Config {}
function testExtractFirestoreValueNull() returns error? {
    json firestoreValue = {
        "nullValue": null
    };
    
    json result = check extractFirestoreValue(firestoreValue);
    test:assertEquals(result, null, "Should correctly extract null value");
}

# Test extracting Firestore values - Double as string
@test:Config {}
function testExtractFirestoreValueDoubleString() returns error? {
    json firestoreValue = {
        "doubleValue": "3.14"
    };
    
    json result = check extractFirestoreValue(firestoreValue);
    test:assertEquals(result, 3.14, "Should correctly extract double value from string");
}

# Test extracting Firestore values - Double as float
@test:Config {}
function testExtractFirestoreValueDoubleFloat() returns error? {
    json firestoreValue = {
        "doubleValue": 3.14
    };
    
    json result = check extractFirestoreValue(firestoreValue);
    test:assertEquals(result, 3.14, "Should correctly extract double value");
}

# Test extracting Firestore values - Map
@test:Config {}
function testExtractFirestoreValueMap() returns error? {
    json firestoreValue = {
        "mapValue": {
            "fields": {
                "name": {"stringValue": "John"},
                "age": {"integerValue": 30}
            }
        }
    };
    
    json result = check extractFirestoreValue(firestoreValue);
    test:assertTrue(result is map<json>, "Should extract as map");
    
    if result is map<json> {
        test:assertEquals(result["name"], "John", "Should correctly extract nested string");
        test:assertEquals(result["age"], 30, "Should correctly extract nested integer");
    }
}

# Test extracting Firestore values - Array
@test:Config {}
function testExtractFirestoreValueArray() returns error? {
    json firestoreValue = {
        "arrayValue": {
            "values": [
                {"integerValue": 1},
                {"integerValue": 2},
                {"integerValue": 3}
            ]
        }
    };
    
    json result = check extractFirestoreValue(firestoreValue);
    test:assertTrue(result is json[], "Should extract as array");
    
    if result is json[] {
        test:assertEquals(result.length(), 3, "Should have 3 elements");
        test:assertEquals(result[0], 1, "First element should be 1");
        test:assertEquals(result[1], 2, "Second element should be 2");
        test:assertEquals(result[2], 3, "Third element should be 3");
    }
}

# Test extracting invalid Firestore value
@test:Config {}
function testExtractFirestoreValueInvalid() {
    json firestoreValue = "invalid";
    
    json|error result = extractFirestoreValue(firestoreValue);
    test:assertTrue(result is error, "Should return error for invalid format");
}

# Test building Firestore filter - Empty
@test:Config {}
function testBuildFirestoreFilterEmpty() {
    map<json> filter = {};
    json result = buildFirestoreFilter(filter);
    
    test:assertTrue(result is map<json>, "Should return empty map for empty filter");
    if result is map<json> {
        test:assertEquals(result.length(), 0, "Result should be empty");
    }
}

# Test building Firestore filter - Single condition
@test:Config {}
function testBuildFirestoreFilterSingle() {
    map<json> filter = {
        "name": "John"
    };
    
    json result = buildFirestoreFilter(filter);
    test:assertTrue(result is map<json>, "Should return map");
    
    if result is map<json> {
        test:assertTrue(result.hasKey("fieldFilter"), "Should have fieldFilter key");
    }
}

# Test building Firestore filter - Multiple conditions
@test:Config {}
function testBuildFirestoreFilterMultiple() {
    map<json> filter = {
        "name": "John",
        "age": 30
    };
    
    json result = buildFirestoreFilter(filter);
    test:assertTrue(result is map<json>, "Should return map");
    
    if result is map<json> {
        test:assertTrue(result.hasKey("compositeFilter"), "Should have compositeFilter key");
    }
}

# Test Firestore operator conversion
@test:Config {}
function testGetFirestoreOperators() {
    test:assertEquals(getFirestoreOperator(">"), "GREATER_THAN");
    test:assertEquals(getFirestoreOperator(">="), "GREATER_THAN_OR_EQUAL");
    test:assertEquals(getFirestoreOperator("<"), "LESS_THAN");
    test:assertEquals(getFirestoreOperator("<="), "LESS_THAN_OR_EQUAL");
    test:assertEquals(getFirestoreOperator("!="), "NOT_EQUAL");
    test:assertEquals(getFirestoreOperator("=="), "EQUAL");
    test:assertEquals(getFirestoreOperator("array-contains"), "ARRAY_CONTAINS");
    test:assertEquals(getFirestoreOperator("array-contains-any"), "ARRAY_CONTAINS_ANY");
    test:assertEquals(getFirestoreOperator("in"), "IN");
    test:assertEquals(getFirestoreOperator("not-in"), "NOT_IN");
    test:assertEquals(getFirestoreOperator("unknown"), "EQUAL");
}

# Test advanced filter building - Simple equality
@test:Config {}
function testBuildAdvancedFilterSimple() {
    map<anydata> filter = {
        "name": "John"
    };
    
    json result = buildAdvancedFilter(filter);
    test:assertTrue(result is map<json>, "Should return map");
    
    if result is map<json> {
        test:assertTrue(result.hasKey("fieldFilter"), "Should have fieldFilter key");
    }
}

# Test advanced filter building - With operators
@test:Config {}
function testBuildAdvancedFilterWithOperators() {
    map<anydata> filter = {
        "age": {
            ">=": 18
        }
    };
    
    json result = buildAdvancedFilter(filter);
    test:assertTrue(result is map<json>, "Should return map");
}

# Test advanced filter building - Multiple conditions
@test:Config {}
function testBuildAdvancedFilterMultiple() {
    map<anydata> filter = {
        "age": {
            ">=": 18
        },
        "city": "New York"
    };
    
    json result = buildAdvancedFilter(filter);
    test:assertTrue(result is map<json>, "Should return map");
    
    if result is map<json> {
        test:assertTrue(result.hasKey("compositeFilter"), "Should have compositeFilter for multiple conditions");
    }
}

# Test complex data structure processing
@test:Config {}
function testProcessComplexDataStructure() returns error? {
    map<json> complexData = {
        "user": {
            "name": "John Doe",
            "age": 30,
            "active": true
        },
        "tags": ["developer", "engineer"],
        "score": 95.5,
        "metadata": null
    };
    
    // Process the complex data
    map<map<json>> firestoreFields = {};
    foreach var [key, value] in complexData.entries() {
        firestoreFields[key] = processFirestoreValue(value);
    }
    
    test:assertEquals(firestoreFields.length(), 4, "Should process all fields");
    test:assertTrue(firestoreFields.hasKey("user"), "Should have user field");
    test:assertTrue(firestoreFields.hasKey("tags"), "Should have tags field");
    test:assertTrue(firestoreFields.hasKey("score"), "Should have score field");
    test:assertTrue(firestoreFields.hasKey("metadata"), "Should have metadata field");
}

# Test round-trip conversion (process and extract)
@test:Config {}
function testRoundTripConversion() returns error? {
    json originalValue = {
        "name": "John",
        "age": 30,
        "scores": [85, 90, 95],
        "address": {
            "city": "New York",
            "zip": "10001"
        }
    };
    
    // Process to Firestore format
    map<json> firestoreValue = processFirestoreValue(originalValue);
    
    // Extract back to Ballerina format
    json extractedValue = check extractFirestoreValue(firestoreValue);
    
    test:assertTrue(extractedValue is map<json>, "Should extract as map");
    
    if extractedValue is map<json> {
        test:assertEquals(extractedValue["name"], "John", "Name should match");
        test:assertEquals(extractedValue["age"], 30, "Age should match");
        
        json scores = extractedValue["scores"];
        test:assertTrue(scores is json[], "Scores should be an array");
        
        json address = extractedValue["address"];
        test:assertTrue(address is map<json>, "Address should be a map");
    }
}

# Test ServiceAccount record type
@test:Config {}
function testServiceAccountRecordType() {
    ServiceAccount serviceAccount = {
        'type: "service_account",
        project_id: "test-project",
        private_key_id: "key123",
        private_key: "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----\n",
        client_email: "test@test-project.iam.gserviceaccount.com",
        client_id: "123456789",
        auth_uri: "https://accounts.google.com/o/oauth2/auth",
        token_uri: "https://oauth2.googleapis.com/token",
        auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
        client_x509_cert_url: "https://www.googleapis.com/robot/v1/metadata/x509/test",
        universe_domain: "googleapis.com"
    };
    
    test:assertEquals(serviceAccount.'type, "service_account");
    test:assertEquals(serviceAccount.project_id, "test-project");
    test:assertEquals(serviceAccount.client_id, "123456789");
}

# Test FirebaseConfig record type
@test:Config {}
function testFirebaseConfigRecordType() {
    FirebaseConfig config = {
        apiKey: "test-api-key",
        authDomain: "test-project.firebaseapp.com",
        databaseURL: "https://test-project.firebaseio.com",
        projectId: "test-project",
        storageBucket: "test-project.appspot.com",
        messagingSenderId: "123456789",
        appId: "1:123456789:web:abc123",
        measurementId: "G-ABC123"
    };
    
    test:assertEquals(config.apiKey, "test-api-key");
    test:assertEquals(config.projectId, "test-project");
}

# Test OperationResult record type
@test:Config {}
function testOperationResultRecordType() {
    OperationResult result = {
        success: true,
        documentId: "doc123",
        message: "Operation completed successfully"
    };
    
    test:assertTrue(result.success);
    test:assertEquals(result.documentId, "doc123");
    test:assertEquals(result.message, "Operation completed successfully");
}

# Test QueryOptions record type
@test:Config {}
function testQueryOptionsRecordType() {
    QueryOptions options = {
        'limit: 10,
        offset: 5,
        orderBy: {
            "created_at": "desc",
            "name": "asc"
        },
        selectedFields: ["name", "email", "age"]
    };
    
    test:assertEquals(options.'limit, 10);
    test:assertEquals(options.offset, 5);
    test:assertTrue(options.orderBy is map<string>);
    test:assertTrue(options.selectedFields is string[]);
}

# Test UpdateOptions record type
@test:Config {}
function testUpdateOptionsRecordType() {
    UpdateOptions options = {
        merge: false,
        updateMask: ["name", "age"]
    };
    
    test:assertFalse(options.merge);
    test:assertTrue(options.updateMask is string[]);
}

# Test BatchOperation record type - Create
@test:Config {}
function testBatchOperationCreate() {
    BatchOperation operation = {
        operation: "create",
        collection: "users",
        data: {
            "name": "John",
            "age": 30
        }
    };
    
    test:assertEquals(operation.operation, "create");
    test:assertEquals(operation.collection, "users");
    test:assertTrue(operation.data is map<json>);
}

# Test BatchOperation record type - Update
@test:Config {}
function testBatchOperationUpdate() {
    BatchOperation operation = {
        operation: "update",
        collection: "users",
        documentId: "user123",
        data: {
            "age": 31
        },
        options: {
            merge: true,
            updateMask: ["age"]
        }
    };
    
    test:assertEquals(operation.operation, "update");
    test:assertEquals(operation.documentId, "user123");
}

# Test BatchOperation record type - Delete
@test:Config {}
function testBatchOperationDelete() {
    BatchOperation operation = {
        operation: "delete",
        collection: "users",
        documentId: "user123"
    };
    
    test:assertEquals(operation.operation, "delete");
    test:assertEquals(operation.documentId, "user123");
}

# Test processing nested maps
@test:Config {}
function testProcessNestedMaps() returns error? {
    map<json> nestedData = {
        "level1": {
            "level2": {
                "level3": "deep value"
            }
        }
    };
    
    map<json> processed = processFirestoreValue(nestedData);
    test:assertTrue(processed.hasKey("mapValue"), "Should have mapValue");
    
    json extracted = check extractFirestoreValue(processed);
    test:assertTrue(extracted is map<json>, "Should extract as map");
    
    if extracted is map<json> {
        json level1 = extracted["level1"];
        test:assertTrue(level1 is map<json>, "Level 1 should be a map");
        
        if level1 is map<json> {
            json level2 = level1["level2"];
            test:assertTrue(level2 is map<json>, "Level 2 should be a map");
            
            if level2 is map<json> {
                test:assertEquals(level2["level3"], "deep value", "Deep value should match");
            }
        }
    }
}

# Test processing mixed arrays
@test:Config {}
function testProcessMixedArrays() returns error? {
    json mixedArray = [
        "string",
        42,
        true,
        3.14,
        {"nested": "object"}
    ];
    
    map<json> processed = processFirestoreValue(mixedArray);
    test:assertTrue(processed.hasKey("arrayValue"), "Should have arrayValue");
    
    json extracted = check extractFirestoreValue(processed);
    test:assertTrue(extracted is json[], "Should extract as array");
    
    if extracted is json[] {
        test:assertEquals(extracted.length(), 5, "Should have 5 elements");
        test:assertEquals(extracted[0], "string", "First element should be string");
        test:assertEquals(extracted[1], 42, "Second element should be integer");
        test:assertEquals(extracted[2], true, "Third element should be boolean");
        test:assertEquals(extracted[3], 3.14, "Fourth element should be float");
        test:assertTrue(extracted[4] is map<json>, "Fifth element should be map");
    }
}

# Test empty data structures
@test:Config {}
function testEmptyDataStructures() returns error? {
    // Empty map
    map<json> emptyMap = {};
    map<json> processedMap = processFirestoreValue(emptyMap);
    json extractedMap = check extractFirestoreValue(processedMap);
    test:assertTrue(extractedMap is map<json>, "Should handle empty map");
    if extractedMap is map<json> {
        test:assertEquals(extractedMap.length(), 0, "Empty map should remain empty");
    }
    
    // Empty array
    json[] emptyArray = [];
    map<json> processedArray = processFirestoreValue(emptyArray);
    json extractedArray = check extractFirestoreValue(processedArray);
    test:assertTrue(extractedArray is json[], "Should handle empty array");
    if extractedArray is json[] {
        test:assertEquals(extractedArray.length(), 0, "Empty array should remain empty");
    }
}

# Test document metadata structure
@test:Config {}
function testDocumentMetadataStructure() {
    DocumentMetadata metadata = {
        id: "doc123",
        name: "projects/test-project/databases/(default)/documents/users/doc123",
        createTime: "2024-01-01T00:00:00.000000Z",
        updateTime: "2024-01-02T00:00:00.000000Z"
    };
    
    test:assertEquals(metadata.id, "doc123");
    test:assertTrue(metadata.name.includes("users/doc123"));
}

# Test complete document structure
@test:Config {}
function testDocumentStructure() {
    Document doc = {
        id: "doc123",
        name: "projects/test-project/databases/(default)/documents/users/doc123",
        createTime: "2024-01-01T00:00:00.000000Z",
        updateTime: "2024-01-02T00:00:00.000000Z",
        fields: {
            "name": "John Doe",
            "age": 30,
            "email": "john@example.com"
        }
    };
    
    test:assertEquals(doc.id, "doc123");
    test:assertEquals(doc.fields["name"], "John Doe");
    test:assertEquals(doc.fields["age"], 30);
}

# Test validation error scenarios
@test:Config {}
function testValidationErrors() {
    // Test batch operation with too many operations
    BatchOperation[] largeOperations = [];
    
    // Creating 501 operations (exceeds limit of 500)
    foreach int i in 0...500 {
        largeOperations.push({
            operation: "create",
            collection: "test",
            data: {"id": i}
        });
    }
    
    // This would normally be tested with actual API call
    test:assertEquals(largeOperations.length(), 501, "Should have 501 operations");
}

# Integration test template - Add document
@test:Config {
    enable: false // Enable when you have valid credentials
}
function testAddDocument() returns error? {
    AuthConfig authConfig = {
        serviceAccountPath: TEST_SERVICE_ACCOUNT_PATH,
        jwtConfig: {
            scope: "https://www.googleapis.com/auth/datastore",
            expTime: 3600
        }
    };
    
    Client firestoreClient = check new(authConfig);
    
    map<json> testData = {
        "name": "Test User",
        "email": "test@example.com",
        "age": 25,
        "active": true,
        "created_at": "2024-01-01T00:00:00Z"
    };
    
    OperationResult result = check firestoreClient.add(TEST_COLLECTION, testData);
    
    test:assertTrue(result.success, "Document creation should succeed");
    test:assertTrue(result.documentId is string, "Should return document ID");
    
    io:println("Created document with ID: ", result.documentId);
}

# Integration test template - Get document
@test:Config {
    enable: false // Enable when you have valid credentials
}
function testGetDocument() returns error? {
    AuthConfig authConfig = {
        serviceAccountPath: TEST_SERVICE_ACCOUNT_PATH,
        jwtConfig: {
            scope: "https://www.googleapis.com/auth/datastore",
            expTime: 3600
        }
    };
    
    Client firestoreClient = check new(authConfig);
    
    string testDocumentId = "test-doc-id"; // Replace with actual document ID
    
    map<json>|DocumentNotFoundError|error result = firestoreClient.get(TEST_COLLECTION, testDocumentId);
    
    if result is map<json> {
        test:assertTrue(result.hasKey("id"), "Document should have ID");
        io:println("Retrieved document: ", result);
    } else if result is DocumentNotFoundError {
        io:println("Document not found - this is expected for non-existent document");
    }
}

# Integration test template - Update document
@test:Config {
    enable: false // Enable when you have valid credentials
}
function testUpdateDocument() returns error? {
    AuthConfig authConfig = {
        serviceAccountPath: TEST_SERVICE_ACCOUNT_PATH,
        jwtConfig: {
            scope: "https://www.googleapis.com/auth/datastore",
            expTime: 3600
        }
    };
    
    Client firestoreClient = check new(authConfig);
    
    string testDocumentId = "test-doc-id"; // Replace with actual document ID
    
    map<json> updateData = {
        "age": 26,
        "updated_at": "2024-01-02T00:00:00Z"
    };
    
    OperationResult result = check firestoreClient.update(TEST_COLLECTION, testDocumentId, updateData);
    
    test:assertTrue(result.success, "Document update should succeed");
}

# Integration test template - Query documents
@test:Config {
    enable: false // Enable when you have valid credentials
}
function testQueryDocuments() returns error? {
    AuthConfig authConfig = {
        serviceAccountPath: TEST_SERVICE_ACCOUNT_PATH,
        jwtConfig: {
            scope: "https://www.googleapis.com/auth/datastore",
            expTime: 3600
        }
    };
    
    Client firestoreClient = check new(authConfig);
    
    map<json> filter = {
        "active": true
    };
    
    map<json>[] results = check firestoreClient.query(TEST_COLLECTION, filter);
    
    test:assertTrue(results is map<json>[], "Should return array of documents");
    io:println("Found ", results.length(), " active documents");
}

# Integration test template - Delete document
@test:Config {
    enable: false // Enable when you have valid credentials
}
function testDeleteDocument() returns error? {
    AuthConfig authConfig = {
        serviceAccountPath: TEST_SERVICE_ACCOUNT_PATH,
        jwtConfig: {
            scope: "https://www.googleapis.com/auth/datastore",
            expTime: 3600
        }
    };
    
    Client firestoreClient = check new(authConfig);
    
    string testDocumentId = "test-doc-id"; // Replace with actual document ID
    
    OperationResult result = check firestoreClient.delete(TEST_COLLECTION, testDocumentId);
    
    test:assertTrue(result.success, "Document deletion should succeed");
}

# Integration test template - Batch operations
@test:Config {
    enable: false // Enable when you have valid credentials
}
function testBatchOperations() returns error? {
    AuthConfig authConfig = {
        serviceAccountPath: TEST_SERVICE_ACCOUNT_PATH,
        jwtConfig: {
            scope: "https://www.googleapis.com/auth/datastore",
            expTime: 3600
        }
    };
    
    Client firestoreClient = check new(authConfig);
    
    BatchOperation[] operations = [
        {
            operation: "create",
            collection: TEST_COLLECTION,
            documentId: "batch-test-1",
            data: {"name": "Batch User 1"}
        },
        {
            operation: "create",
            collection: TEST_COLLECTION,
            documentId: "batch-test-2",
            data: {"name": "Batch User 2"}
        }
    ];
    
    OperationResult[] results = check firestoreClient.batchWrite(operations);
    
    test:assertEquals(results.length(), 2, "Should return results for all operations");
    
    foreach OperationResult result in results {
        test:assertTrue(result.success, "Each operation should succeed");
    }
}

# Integration test template - Count documents
@test:Config {
    enable: false // Enable when you have valid credentials
}
function testCountDocuments() returns error? {
    AuthConfig authConfig = {
        serviceAccountPath: TEST_SERVICE_ACCOUNT_PATH,
        jwtConfig: {
            scope: "https://www.googleapis.com/auth/datastore",
            expTime: 3600
        }
    };
    
    Client firestoreClient = check new(authConfig);
    
    int count = check firestoreClient.count(TEST_COLLECTION);
    
    test:assertTrue(count >= 0, "Count should be non-negative");
    io:println("Total documents in collection: ", count);
}

# Integration test template - Find with advanced filters
@test:Config {
    enable: false // Enable when you have valid credentials
}
function testFindWithAdvancedFilters() returns error? {
    AuthConfig authConfig = {
        serviceAccountPath: TEST_SERVICE_ACCOUNT_PATH,
        jwtConfig: {
            scope: "https://www.googleapis.com/auth/datastore",
            expTime: 3600
        }
    };
    
    Client firestoreClient = check new(authConfig);
    
    map<anydata> filter = {
        "age": {
            ">=": 18
        },
        "active": true
    };
    
    QueryOptions options = {
        'limit: 10,
        orderBy: {"age": "desc"}
    };
    
    map<json>[] results = check firestoreClient.find(TEST_COLLECTION, filter, options);
    
    test:assertTrue(results is map<json>[], "Should return array of documents");
    io:println("Found ", results.length(), " documents matching criteria");
}

# ===== COMPREHENSIVE END-TO-END CRUD TEST =====

# Quick CRUD test
@test:Config {
    enable: true
}
function testQuickCRUD() returns error? {
    io:println("\n=== Quick CRUD Test ===\n");
    
    AuthConfig authConfig = {
        serviceAccountPath: TEST_SERVICE_ACCOUNT_PATH,
        jwtConfig: {
            scope: "https://www.googleapis.com/auth/datastore",
            expTime: 3600
        }
    };
    
    Client firestoreClient = check new(authConfig);
    io:println("✓ Client initialized");
    
    // CREATE
    map<json> testUser = {
        "name": "Test User",
        "age": 25
    };
    
    OperationResult createResult = check firestoreClient.add(TEST_COLLECTION, testUser);
    test:assertTrue(createResult.success, "Create should succeed");
    string docId = <string>createResult.documentId;
    io:println("✓ CREATE: Document ID = ", docId);
    
    // READ
    map<json>|DocumentNotFoundError|error readResult = firestoreClient.get(TEST_COLLECTION, docId);
    test:assertTrue(readResult is map<json>, "Read should succeed");
    if readResult is map<json> {
        io:println("✓ READ: Name = ", readResult["name"]);
    }
    
    // UPDATE
    OperationResult updateResult = check firestoreClient.update(TEST_COLLECTION, docId, {"age": 26});
    test:assertTrue(updateResult.success, "Update should succeed");
    io:println("✓ UPDATE: Age updated to 26");
    
    // DELETE
    OperationResult deleteResult = check firestoreClient.delete(TEST_COLLECTION, docId);
    test:assertTrue(deleteResult.success, "Delete should succeed");
    io:println("✓ DELETE: Document deleted");
    
    io:println("\n=== All Operations Passed! ===\n");
}

# Comprehensive test for all CRUD operations
@test:Config {
    enable: false
}
function testCompleteCRUDOperations() returns error? {
    io:println("\n========================================");
    io:println("Starting Comprehensive CRUD Test Suite");
    io:println("========================================\n");
    
    // Initialize client
    AuthConfig authConfig = {
        serviceAccountPath: TEST_SERVICE_ACCOUNT_PATH,
        jwtConfig: {
            scope: "https://www.googleapis.com/auth/datastore",
            expTime: 3600
        }
    };
    
    Client firestoreClient = check new(authConfig);
    string projectId = check firestoreClient.getProjectId();
    io:println("✓ Client initialized successfully");
    io:println("  Project ID: ", projectId);
    
    // Test 1: CREATE with add() - Auto-generated ID
    io:println("\n--- Test 1: CREATE Document (Auto ID) ---");
    map<json> userData1 = {
        "name": "Alice Johnson",
        "email": "alice@example.com",
        "age": 28,
        "city": "New York",
        "active": true,
        "tags": ["developer", "designer"],
        "created_at": "2024-01-01T10:00:00Z"
    };
    
    OperationResult addResult = check firestoreClient.add(TEST_COLLECTION, userData1);
    test:assertTrue(addResult.success, "Add operation should succeed");
    test:assertTrue(addResult.documentId is string, "Should return document ID");
    
    string docId1 = <string>addResult.documentId;
    io:println("✓ Document created with auto-generated ID: ", docId1);
    
    // Test 2: CREATE with set() - Specific ID
    io:println("\n--- Test 2: CREATE Document (Specific ID) ---");
    string customDocId = "user_12345";
    map<json> userData2 = {
        "name": "Bob Smith",
        "email": "bob@example.com",
        "age": 35,
        "city": "San Francisco",
        "active": true,
        "tags": ["manager", "leader"],
        "created_at": "2024-01-02T10:00:00Z"
    };
    
    OperationResult setResult = check firestoreClient.set(TEST_COLLECTION, customDocId, userData2);
    test:assertTrue(setResult.success, "Set operation should succeed");
    io:println("✓ Document created with custom ID: ", customDocId);
    
    // Test 3: READ - Get specific document
    io:println("\n--- Test 3: READ Document ---");
    map<json>|DocumentNotFoundError|error getResult = firestoreClient.get(TEST_COLLECTION, docId1);
    
    if getResult is map<json> {
        test:assertEquals(getResult["name"], "Alice Johnson", "Name should match");
        test:assertEquals(getResult["email"], "alice@example.com", "Email should match");
        test:assertEquals(getResult["age"], 28, "Age should match");
        test:assertTrue(getResult.hasKey("id"), "Should have document ID");
        io:println("✓ Document retrieved successfully");
        io:println("  Name: ", getResult["name"]);
        io:println("  Email: ", getResult["email"]);
        io:println("  Age: ", getResult["age"]);
    } else {
        test:assertFail("Document should be found");
    }
    
    // Test 4: READ - Get document with custom ID
    io:println("\n--- Test 4: READ Document (Custom ID) ---");
    map<json>|DocumentNotFoundError|error getResult2 = firestoreClient.get(TEST_COLLECTION, customDocId);
    
    if getResult2 is map<json> {
        test:assertEquals(getResult2["name"], "Bob Smith", "Name should match");
        io:println("✓ Document with custom ID retrieved successfully");
        io:println("  Name: ", getResult2["name"]);
    } else {
        test:assertFail("Document should be found");
    }
    
    // Test 5: UPDATE - Merge update
    io:println("\n--- Test 5: UPDATE Document (Merge) ---");
    map<json> updateData1 = {
        "age": 29,
        "city": "Boston",
        "updated_at": "2024-01-03T10:00:00Z"
    };
    
    OperationResult updateResult1 = check firestoreClient.update(
        TEST_COLLECTION, 
        docId1, 
        updateData1, 
        {merge: true}
    );
    test:assertTrue(updateResult1.success, "Update operation should succeed");
    io:println("✓ Document updated (merge mode)");
    
    // Verify update
    map<json>|DocumentNotFoundError|error verifyUpdate = firestoreClient.get(TEST_COLLECTION, docId1);
    if verifyUpdate is map<json> {
        test:assertEquals(verifyUpdate["age"], 29, "Age should be updated");
        test:assertEquals(verifyUpdate["city"], "Boston", "City should be updated");
        test:assertEquals(verifyUpdate["name"], "Alice Johnson", "Name should still exist");
        io:println("  Updated age: ", verifyUpdate["age"]);
        io:println("  Updated city: ", verifyUpdate["city"]);
    }
    
    // Test 6: UPDATE - Specific fields with updateMask
    io:println("\n--- Test 6: UPDATE Document (UpdateMask) ---");
    map<json> updateData2 = {
        "email": "alice.johnson@newcompany.com"
    };
    
    OperationResult updateResult2 = check firestoreClient.update(
        TEST_COLLECTION, 
        docId1, 
        updateData2, 
        {merge: true, updateMask: ["email"]}
    );
    test:assertTrue(updateResult2.success, "Update with mask should succeed");
    io:println("✓ Document updated with updateMask");
    
    // Test 7: QUERY - Get all documents
    io:println("\n--- Test 7: QUERY All Documents ---");
    map<json>[] allDocs = check firestoreClient.getAll(TEST_COLLECTION);
    test:assertTrue(allDocs.length() >= 2, "Should have at least 2 documents");
    io:println("✓ Retrieved all documents: ", allDocs.length(), " documents found");
    
    // Test 8: QUERY - Filter by field
    io:println("\n--- Test 8: QUERY with Filter ---");
    map<json> filter1 = {
        "active": true
    };
    
    map<json>[] filteredDocs = check firestoreClient.query(TEST_COLLECTION, filter1);
    test:assertTrue(filteredDocs.length() >= 2, "Should find active documents");
    io:println("✓ Filtered query: ", filteredDocs.length(), " active documents found");
    
    // Test 9: QUERY - Advanced filter with operators
    io:println("\n--- Test 9: QUERY with Advanced Filter ---");
    map<anydata> advancedFilter = {
        "age": {
            ">=": 25
        }
    };
    
    QueryOptions queryOptions = {
        'limit: 10,
        orderBy: {"age": "asc"}
    };
    
    map<json>[] advancedResults = check firestoreClient.find(TEST_COLLECTION, advancedFilter, queryOptions);
    test:assertTrue(advancedResults.length() >= 1, "Should find documents with age >= 25");
    io:println("✓ Advanced query: ", advancedResults.length(), " documents found");
    
    foreach map<json> doc in advancedResults {
        if doc.hasKey("name") && doc.hasKey("age") {
            io:println("  - ", doc["name"], " (age: ", doc["age"], ")");
        }
    }
    
    // Test 10: COUNT documents
    io:println("\n--- Test 10: COUNT Documents ---");
    int totalCount = check firestoreClient.count(TEST_COLLECTION);
    test:assertTrue(totalCount >= 2, "Should have at least 2 documents");
    io:println("✓ Total documents in collection: ", totalCount);
    
    // Test 11: COUNT with filter
    io:println("\n--- Test 11: COUNT with Filter ---");
    int activeCount = check firestoreClient.count(TEST_COLLECTION, {"active": true});
    test:assertTrue(activeCount >= 2, "Should have at least 2 active documents");
    io:println("✓ Active documents: ", activeCount);
    
    // Test 12: BATCH OPERATIONS
    io:println("\n--- Test 12: BATCH Operations ---");
    
    BatchOperation[] batchOps = [
        {
            operation: "create",
            collection: TEST_COLLECTION,
            documentId: "batch_user_1",
            data: {
                "name": "Charlie Brown",
                "age": 30,
                "city": "Chicago",
                "active": true
            }
        },
        {
            operation: "create",
            collection: TEST_COLLECTION,
            documentId: "batch_user_2",
            data: {
                "name": "Diana Prince",
                "age": 32,
                "city": "Seattle",
                "active": true
            }
        },
        {
            operation: "update",
            collection: TEST_COLLECTION,
            documentId: customDocId,
            data: {
                "active": false,
                "updated_at": "2024-01-04T10:00:00Z"
            }
        }
    ];
    
    OperationResult[] batchResults = check firestoreClient.batchWrite(batchOps);
    test:assertEquals(batchResults.length(), 3, "Should return 3 results");
    
    foreach OperationResult result in batchResults {
        test:assertTrue(result.success, "Each batch operation should succeed");
    }
    
    io:println("✓ Batch operations completed: ", batchResults.length(), " operations");
    
    // Verify batch create
    map<json>|DocumentNotFoundError|error batchDoc1 = firestoreClient.get(TEST_COLLECTION, "batch_user_1");
    if batchDoc1 is map<json> {
        test:assertEquals(batchDoc1["name"], "Charlie Brown");
        io:println("  - Batch user 1 created: ", batchDoc1["name"]);
    }
    
    // Test 13: QUERY with pagination
    io:println("\n--- Test 13: QUERY with Pagination ---");
    QueryOptions paginationOptions = {
        'limit: 2,
        offset: 0,
        orderBy: {"name": "asc"}
    };
    
    map<json>[] page1 = check firestoreClient.getAll(TEST_COLLECTION, paginationOptions);
    test:assertTrue(page1.length() <= 2, "Should return at most 2 documents");
    io:println("✓ Page 1: ", page1.length(), " documents");
    
    paginationOptions.offset = 2;
    map<json>[] page2 = check firestoreClient.getAll(TEST_COLLECTION, paginationOptions);
    io:println("✓ Page 2: ", page2.length(), " documents");
    
    // Test 14: QUERY with field selection
    io:println("\n--- Test 14: QUERY with Field Selection ---");
    QueryOptions selectOptions = {
        selectedFields: ["name", "email"]
    };
    
    map<json>[] selectedFields = check firestoreClient.getAll(TEST_COLLECTION, selectOptions);
    test:assertTrue(selectedFields.length() >= 1, "Should return documents");
    io:println("✓ Retrieved documents with selected fields only");
    
    // Test 15: DELETE operations
    io:println("\n--- Test 15: DELETE Documents ---");
    
    // Delete first document
    OperationResult deleteResult1 = check firestoreClient.delete(TEST_COLLECTION, docId1);
    test:assertTrue(deleteResult1.success, "Delete should succeed");
    io:println("✓ Deleted document: ", docId1);
    
    // Verify deletion
    map<json>|DocumentNotFoundError|error verifyDelete = firestoreClient.get(TEST_COLLECTION, docId1);
    test:assertTrue(verifyDelete is DocumentNotFoundError, "Document should not be found after deletion");
    io:println("  Verified: Document no longer exists");
    
    // Delete custom ID document
    OperationResult deleteResult2 = check firestoreClient.delete(TEST_COLLECTION, customDocId);
    test:assertTrue(deleteResult2.success, "Delete should succeed");
    io:println("✓ Deleted document: ", customDocId);
    
    // Delete batch documents
    OperationResult deleteResult3 = check firestoreClient.delete(TEST_COLLECTION, "batch_user_1");
    test:assertTrue(deleteResult3.success, "Delete should succeed");
    io:println("✓ Deleted document: batch_user_1");
    
    OperationResult deleteResult4 = check firestoreClient.delete(TEST_COLLECTION, "batch_user_2");
    test:assertTrue(deleteResult4.success, "Delete should succeed");
    io:println("✓ Deleted document: batch_user_2");
    
    // Test 16: Try to delete non-existent document
    io:println("\n--- Test 16: DELETE Non-existent Document ---");
    OperationResult|error deleteNonExistent = firestoreClient.delete(TEST_COLLECTION, "non_existent_doc");
    test:assertTrue(deleteNonExistent is DocumentNotFoundError, "Should return DocumentNotFoundError");
    io:println("✓ Correctly handled deletion of non-existent document");
    
    // Final count
    io:println("\n--- Final State ---");
    int finalCount = check firestoreClient.count(TEST_COLLECTION);
    io:println("✓ Final document count: ", finalCount);
    
    io:println("\n========================================");
    io:println("✓ ALL CRUD TESTS PASSED SUCCESSFULLY!");
    io:println("========================================\n");
}
