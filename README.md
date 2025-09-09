# Ballerina Firestore Connector

A comprehensive Ballerina connector for Google Cloud Firestore database with complete CRUD operations, advanced querying, and professional-grade features.

## Overview

This connector provides a simple and powerful interface to interact with Google Cloud Firestore, offering:
- Complete CRUD operations (Create, Read, Update, Delete)
- Advanced querying with filtering, sorting, and pagination
- Batch operations for efficient bulk processing
- Automatic authentication and token management
- Type-safe data conversion between Ballerina and Firestore formats
- Professional error handling and comprehensive testing

## Features

### Core Operations
- **Create**: Add documents with auto-generated or custom IDs
- **Read**: Get single documents, query with filters, or retrieve all documents
- **Update**: Update existing documents with merge options and field masks
- **Delete**: Remove documents individually or in batches
- **Count**: Count documents with optional filtering

### Advanced Features
- **Batch Operations**: Execute multiple operations in a single request
- **Advanced Querying**: Support for complex filters with operators (`>`, `>=`, `<`, `<=`, `!=`, `==`, `in`, `not-in`, `array-contains`)
- **Pagination**: Limit and offset support for large datasets
- **Sorting**: Order results by multiple fields in ascending or descending order
- **Field Selection**: Retrieve only specific fields to optimize performance
- **Token Caching**: Automatic access token management with renewal

### Data Type Support
- Strings, integers, floats, booleans, null values
- Arrays and nested objects
- Automatic type conversion between Ballerina and Firestore formats

## Installation

Add the following dependency to your `Ballerina.toml` file:

```toml
[dependencies]
nalaka/firestore = "1.0.2"
```

Or import directly:
```ballerina
import nalaka/firestore;
```

## Prerequisites

1. Google Cloud Project with Firestore enabled
2. Service Account with Firestore permissions
3. Service Account JSON key file
4. Ballerina Swan Lake 2201.8.0 or later

## Quick Start

### 1. Basic Setup

```ballerina
import nalaka/firestore;

public function main() returns error? {
    // Configure authentication
    firestore:AuthConfig authConfig = {
        serviceAccountPath: "./path/to/service-account.json",
        privateKeyPath: "./path/to/private-key.pem", // Optional, will be auto-generated
        jwtConfig: {
            scope: "https://www.googleapis.com/auth/datastore",
            expTime: 3600 // Token expiry in seconds
        }
    };

    // Initialize client
    firestore:Client firestoreClient = check new(authConfig);
    
    // Your operations here...
}
```

### 2. Create Documents

```ballerina
// Create document with auto-generated ID
map<json> userData = {
    "name": "John Doe",
    "email": "john@example.com",
    "age": 30,
    "active": true,
    "tags": ["user", "premium"],
    "metadata": {
        "createdBy": "system",
        "version": 1
    }
};

firestore:OperationResult result = check firestoreClient.add("users", userData);
io:println("Document created with ID: ", result.documentId);

// Create document with specific ID
firestore:OperationResult setResult = check firestoreClient.set("users", "user-123", userData);
io:println("Document set successfully: ", setResult.success);

// Convenience method (backward compatibility)
check firestoreClient.createDocument("users", userData);
```

### 3. Read Documents

```ballerina
// Get a single document
map<json>|firestore:DocumentNotFoundError|error doc = firestoreClient.get("users", "user-123");
if doc is map<json> {
    io:println("User name: ", doc["name"]);
    io:println("User age: ", doc["age"]);
} else if doc is firestore:DocumentNotFoundError {
    io:println("User not found");
}

// Get all documents with options
firestore:QueryOptions options = {
    'limit: 10,
    offset: 0,
    orderBy: {"name": "asc", "age": "desc"}
};

map<json>[] users = check firestoreClient.getAll("users", options);
foreach map<json> user in users {
    io:println("User: ", user["name"]);
}
```

### 4. Query Documents

```ballerina
// Simple query
map<json> filter = {
    "active": true,
    "age": 30
};

map<json>[] activeUsers = check firestoreClient.query("users", filter);
io:println("Found ", activeUsers.length(), " active users");

// Advanced query with operators
map<anydata> advancedFilter = {
    "age": {
        ">=": 18,
        "<": 65
    },
    "active": true,
    "tags": {
        "array-contains": "premium"
    }
};

firestore:QueryOptions queryOptions = {
    'limit: 20,
    orderBy: {"name": "asc"},
    selectedFields: ["name", "email", "age"] // Only return specific fields
};

map<json>[] filteredUsers = check firestoreClient.find("users", advancedFilter, queryOptions);
```

### 5. Update Documents

```ballerina
// Simple update (merge by default)
map<json> updates = {
    "age": 31,
    "lastLogin": "2024-01-01T10:00:00Z",
    "active": true
};

firestore:OperationResult updateResult = check firestoreClient.update("users", "user-123", updates);

// Update with specific options
firestore:UpdateOptions updateOptions = {
    merge: true,
    updateMask: ["age", "lastLogin"] // Only update specific fields
};

firestore:OperationResult maskedUpdate = check firestoreClient.update("users", "user-123", updates, updateOptions);
```

### 6. Delete Documents

```ballerina
// Delete a single document
firestore:OperationResult deleteResult = check firestoreClient.delete("users", "user-123");
if deleteResult.success {
    io:println("Document deleted successfully");
}
```

### 7. Count Documents

```ballerina
// Count all documents
int totalUsers = check firestoreClient.count("users");
io:println("Total users: ", totalUsers);

// Count with filter
map<json> activeFilter = {"active": true};
int activeUsers = check firestoreClient.count("users", activeFilter);
io:println("Active users: ", activeUsers);
```

### 8. Batch Operations

```ballerina
// Batch operations for efficiency
firestore:BatchOperation[] operations = [
    {
        operation: "create",
        collection: "users",
        documentId: "user-001",
        data: {"name": "Alice", "age": 25}
    },
    {
        operation: "create",
        collection: "users",
        documentId: "user-002",
        data: {"name": "Bob", "age": 30}
    },
    {
        operation: "update",
        collection: "users",
        documentId: "user-123",
        data: {"lastUpdated": "2024-01-01"},
        options: {merge: true}
    },
    {
        operation: "delete",
        collection: "users",
        documentId: "user-to-delete"
    }
];

firestore:OperationResult[] batchResults = check firestoreClient.batchWrite(operations);
foreach firestore:OperationResult result in batchResults {
    io:println("Operation success: ", result.success);
}
```

## Advanced Usage

### Custom Authentication Configuration

```ballerina
firestore:AuthConfig authConfig = {
    serviceAccountPath: "./service-account.json",
    privateKeyPath: "./custom-private-key.pem",
    firebaseConfig: {
        projectId: "my-project",
        apiKey: "your-api-key",
        authDomain: "my-project.firebaseapp.com",
        databaseURL: "https://my-project.firebaseio.com",
        storageBucket: "my-project.appspot.com"
    },
    jwtConfig: {
        scope: "https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/cloud-platform",
        expTime: 7200 // 2 hours
    }
};
```

### Error Handling

```ballerina
map<json>|firestore:DocumentNotFoundError|error result = firestoreClient.get("users", "non-existent");

if result is firestore:DocumentNotFoundError {
    io:println("Document not found: ", result.message());
} else if result is firestore:AuthenticationError {
    io:println("Authentication failed: ", result.message());
} else if result is firestore:ValidationError {
    io:println("Validation error: ", result.message());
} else if result is error {
    io:println("Other error: ", result.message());
} else {
    // Success case
    map<json> document = result;
    io:println("Document retrieved: ", document["name"]);
}
```

### Complex Queries

```ballerina
// Query with multiple conditions and sorting
map<anydata> complexFilter = {
    "department": "Engineering",
    "salary": {
        ">=": 50000,
        "<=": 150000
    },
    "skills": {
        "array-contains-any": ["java", "ballerina", "python"]
    },
    "active": true
};

firestore:QueryOptions complexOptions = {
    'limit: 50,
    offset: 0,
    orderBy: {"salary": "desc", "name": "asc"},
    selectedFields: ["name", "department", "salary", "skills"]
};

map<json>[] engineers = check firestoreClient.find("employees", complexFilter, complexOptions);
```

## API Reference

### Client Methods

| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `add()` | Create document with auto-generated ID | `collection`, `documentData` | `OperationResult` |
| `set()` | Create/replace document with specific ID | `collection`, `documentId`, `documentData` | `OperationResult` |
| `get()` | Get single document by ID | `collection`, `documentId` | `map<json>` or `DocumentNotFoundError` |
| `update()` | Update existing document | `collection`, `documentId`, `documentData`, `options?` | `OperationResult` |
| `delete()` | Delete document | `collection`, `documentId` | `OperationResult` |
| `query()` | Simple query with filters | `collection`, `filter?` | `map<json>[]` |
| `find()` | Advanced query with operators | `collection`, `filter?`, `options?` | `map<json>[]` |
| `getAll()` | Get all documents with pagination | `collection`, `options?` | `map<json>[]` |
| `count()` | Count documents | `collection`, `filter?` | `int` |
| `batchWrite()` | Execute batch operations | `operations` | `OperationResult[]` |

### Types

#### AuthConfig
```ballerina
public type AuthConfig record {|
    string serviceAccountPath;
    readonly & FirebaseConfig? firebaseConfig = ();
    readonly & JWTConfig jwtConfig;
    string privateKeyPath = "./private.key";
|};
```

#### QueryOptions
```ballerina
public type QueryOptions record {|
    int? 'limit = ();
    int? offset = ();
    map<string>? orderBy = ();
    string[]? selectedFields = ();
|};
```

#### UpdateOptions
```ballerina
public type UpdateOptions record {|
    boolean merge = true;
    string[]? updateMask = ();
|};
```

#### OperationResult
```ballerina
public type OperationResult record {|
    boolean success;
    string? documentId = ();
    string? message = ();
|};
```

### Query Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `==` or simple value | Equal to | `{"age": 25}` or `{"age": {"==": 25}}` |
| `!=` | Not equal to | `{"status": {"!=": "inactive"}}` |
| `>` | Greater than | `{"age": {">": 18}}` |
| `>=` | Greater than or equal | `{"salary": {">=": 50000}}` |
| `<` | Less than | `{"score": {"<": 100}}` |
| `<=` | Less than or equal | `{"age": {"<=": 65}}` |
| `in` | In array | `{"category": {"in": ["A", "B", "C"]}}` |
| `not-in` | Not in array | `{"status": {"not-in": ["banned", "suspended"]}}` |
| `array-contains` | Array contains value | `{"tags": {"array-contains": "featured"}}` |
| `array-contains-any` | Array contains any value | `{"skills": {"array-contains-any": ["java", "python"]}}` |

## Testing

The package includes comprehensive tests covering all functionality:

```bash
bal test
```

Test configuration requires:
- Valid service account JSON file
- Test project ID
- Proper Firestore permissions

## Best Practices

1. **Connection Management**: Reuse the client instance across your application
2. **Error Handling**: Always handle specific error types for better user experience
3. **Batch Operations**: Use batch writes for multiple operations to improve performance
4. **Field Selection**: Use `selectedFields` to retrieve only necessary data
5. **Pagination**: Use `limit` and `offset` for large datasets
6. **Indexing**: Ensure proper Firestore indexes for complex queries

## Performance Considerations

- Batch operations can handle up to 500 operations per request
- Use field selection to reduce data transfer
- Implement proper pagination for large result sets
- Cache client instances to reuse authentication tokens

## Error Types

- `ClientError`: General client errors
- `DocumentNotFoundError`: Document doesn't exist
- `AuthenticationError`: Authentication failures
- `QueryError`: Query execution errors
- `ValidationError`: Input validation errors

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the Apache 2.0 License.

## Support

For issues and questions:
- Create an issue on GitHub
- Check the Ballerina Central documentation
- Review the test cases for usage examples

## Changelog

### Version 1.0.2
- Complete CRUD operations
- Advanced querying with operators
- Batch operations support
- Automatic token management
- Comprehensive error handling
- Professional-grade testing suite