# Ballerina Firestore Connector

A Ballerina connector for Google Cloud Firestore with complete CRUD operations, advanced querying, and automatic authentication.

## Overview

This connector provides a simple and powerful way to interact with Google Cloud Firestore:

**Complete CRUD Operations** - Create, Read, Update, Delete  
**Advanced Querying** - Filter, sort, paginate with 10+ operators  
**Batch Operations** - Execute up to 500 operations at once  
**Auto Authentication** - Automatic token management and renewal  
**Type Safe** - Full type conversion between Ballerina and Firestore  
**Production Ready** - 43 passing tests, comprehensive error handling

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

Add to your `Ballerina.toml`:

```toml
[dependencies]
nalaka/firestore = "1.0.7"
```

Then import in your code:

```ballerina
import ballerina/io;
import nalaka/firestore;
```

## Prerequisites & Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing one
3. Navigate to **Firestore Database** and create database

### 2. Get Service Account Credentials

1. Go to **Project Settings** → **Service Accounts**
2. Click **Generate New Private Key**
3. Save the JSON file (e.g., `service-account.json`)

### 3. Configure Firestore Security Rules

**Important:** By default, Firestore blocks all read/write operations. Update security rules:

Go to **Firestore Database** → **Rules** tab:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      // For development/testing
      allow read, write: if true;
      
      // For production (recommended)
      // allow read, write: if request.auth != null;
    }
  }
}
```

Click **Publish** to save.

### 4. Requirements

- Ballerina Swan Lake 2201.8.0 or later
- Service account JSON file
- Internet connection for Firestore API access

## Quick Start

### Complete Example

```ballerina
import ballerina/io;
import nalaka/firestore;

public function main() returns error? {
    // 1. Initialize client with service account
    firestore:Client client = check new({
        serviceAccountPath: "./service-account.json",
        jwtConfig: {
            scope: "https://www.googleapis.com/auth/datastore",
            expTime: 3600
        }
    });
    
    // 2. Create a document
    map<json> user = {
        "name": "Alice Johnson",
        "email": "alice@example.com",
        "age": 28,
        "active": true
    };
    
    firestore:OperationResult createResult = check client.add("users", user);
    string docId = <string>createResult.documentId;
    io:println("✓ Created document: ", docId);
    
    // 3. Read the document
    map<json> retrieved = check client.get("users", docId);
    io:println("✓ Name: ", retrieved["name"]);
    
    // 4. Update the document
    check client.update("users", docId, {"age": 29});
    io:println("✓ Updated age to 29");
    
    // 5. Query documents
    map<json>[] activeUsers = check client.query("users", {"active": true});
    io:println("✓ Found ", activeUsers.length(), " active users");
    
    // 6. Delete the document
    check client.delete("users", docId);
    io:println("✓ Deleted successfully");
}
```

**Output:**
```
✓ Created document: nYJ0bceYpPLfouUMYgn5
✓ Name: Alice Johnson
✓ Updated age to 29
✓ Found 5 active users
✓ Deleted successfully
```

## Detailed Examples

### 1. Create Documents

```ballerina
// Method 1: Auto-generated ID
map<json> user = {
    "name": "John Doe",
    "email": "john@example.com",
    "age": 30,
    "active": true,
    "tags": ["premium", "verified"],
    "address": {
        "city": "New York",
        "country": "USA"
    }
};

firestore:OperationResult result = check client.add("users", user);
io:println("Created: ", result.documentId); // e.g., "Iu4pciwLWxKpcEwKSqYX"

// Method 2: Custom ID
firestore:OperationResult result2 = check client.set("users", "user-123", user);
io:println("Set document: ", result2.success); // true
```

### 2. Read Documents

```ballerina
// Get single document
map<json>|firestore:DocumentNotFoundError|error doc = client.get("users", "user-123");

if doc is map<json> {
    io:println("Name: ", doc["name"]);
    io:println("Age: ", doc["age"]);
} else if doc is firestore:DocumentNotFoundError {
    io:println("Document not found");
}

// Get all documents (with pagination)
firestore:QueryOptions options = {
    'limit: 10,
    offset: 0,
    orderBy: {"name": "asc"}
};

map<json>[] users = check client.getAll("users", options);
foreach var user in users {
    io:println(user["name"]);
}
```

### 3. Query Documents

```ballerina
// Simple query (exact match)
map<json> filter = {"active": true, "age": 30};
map<json>[] results = check client.query("users", filter);

// Advanced query with operators
map<anydata> advancedFilter = {
    "age": {">=": 18, "<": 65},           // Between 18 and 65
    "tags": {"array-contains": "premium"}, // Has "premium" tag
    "status": {"in": ["active", "verified"]} // Status is active or verified
};

firestore:QueryOptions queryOptions = {
    'limit: 20,
    orderBy: {"age": "desc", "name": "asc"},
    selectedFields: ["name", "email", "age"] // Only fetch these fields
};

map<json>[] users = check client.find("users", advancedFilter, queryOptions);
```

### 4. Update Documents

```ballerina
// Simple update (merges with existing data)
map<json> updates = {
    "age": 31,
    "lastLogin": "2024-11-02T10:00:00Z"
};

firestore:OperationResult result = check client.update("users", "user-123", updates);

// Update specific fields only
firestore:UpdateOptions options = {
    merge: true,
    updateMask: ["age", "lastLogin"]
};

check client.update("users", "user-123", updates, options);
```

### 5. Delete Documents

```ballerina
firestore:OperationResult result = check client.delete("users", "user-123");
io:println("Deleted: ", result.success); // true
```

### 6. Count Documents

```ballerina
// Count all
int total = check client.count("users");
io:println("Total users: ", total);

// Count with filter
int active = check client.count("users", {"active": true});
io:println("Active users: ", active);
```

### 7. Batch Operations

```ballerina
// Perform multiple operations at once (up to 500)
firestore:BatchOperation[] operations = [
    {
        operation: "create",
        collection: "users",
        documentId: "user-001",
        data: {"name": "Alice", "age": 25}
    },
    {
        operation: "update",
        collection: "users",
        documentId: "user-002",
        data: {"age": 26}
    },
    {
        operation: "delete",
        collection: "users",
        documentId: "user-003"
    }
];

firestore:OperationResult[] results = check client.batchWrite(operations);
io:println("Completed ", results.length(), " operations");
```

## Error Handling

Always handle errors properly:

```ballerina
map<json>|firestore:DocumentNotFoundError|error result = client.get("users", userId);

if result is firestore:DocumentNotFoundError {
    io:println("User not found");
} else if result is firestore:AuthenticationError {
    io:println("Auth failed - check service account");
} else if result is firestore:ValidationError {
    io:println("Invalid data");
} else if result is error {
    io:println("Error: ", result.message());
} else {
    io:println("Success: ", result["name"]);
}
```

### Error Types
- `DocumentNotFoundError` - Document doesn't exist
- `AuthenticationError` - Authentication failed
- `ValidationError` - Invalid input data
- `QueryError` - Query execution failed
- `ClientError` - General client errors

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

## Common Issues

### "Permission Denied" Error

If you get `403 Permission Denied`:

1. Go to Firebase Console → Firestore Database → Rules
2. Update rules to allow access (see Prerequisites section)
3. Click "Publish"

### "Authentication Failed"

- Verify `service-account.json` path is correct
- Ensure service account has Firestore permissions
- Check project ID matches your Firebase project

### Document Not Found

- Verify document ID and collection name
- Check if document exists in Firestore Console
- Ensure security rules allow read access

## Best Practices

### 1. Reuse Client Instance
```ballerina
// ✅ Good - Create once, use everywhere
Client client = check new(authConfig);

// ❌ Bad - Don't create multiple instances
Client client1 = check new(authConfig);
Client client2 = check new(authConfig);
```

### 2. Use Batch Operations
```ballerina
// ✅ Good - One request for multiple operations
BatchOperation[] ops = [...];
check client.batchWrite(ops);

// ❌ Bad - Multiple requests
check client.add("users", user1);
check client.add("users", user2);
```

### 3. Use Field Selection
```ballerina
// ✅ Good - Fetch only what you need
QueryOptions options = {selectedFields: ["name", "email"]};
map<json>[] users = check client.getAll("users", options);
```

### 4. Implement Pagination
```ballerina
// ✅ Good - For large datasets
QueryOptions options = {'limit: 100, offset: pageNum * 100};
map<json>[] page = check client.getAll("users", options);
```

## Performance Tips

- Batch operations support up to 500 operations per request
- Use `selectedFields` to reduce data transfer
- Use `limit` and `offset` for pagination
- Client automatically caches and renews authentication tokens
- Reuse client instance to avoid re-authentication

## Support

Need help? Here's how to get support:

- 📖 **Documentation**: Check this README and API reference above
- 🐛 **Issues**: [Report bugs on GitHub](https://github.com/NalakaDineshSamarasingha/nalaka-firestore/issues)
- 💬 **Discussions**: Ask questions in GitHub Discussions
- 📚 **Examples**: See [test cases](https://github.com/NalakaDineshSamarasingha/nalaka-firestore/tree/main/tests) for more examples

## Changelog

### Version 1.0.3 (Latest)
- ✅ 43 passing tests - Full test coverage
- ✅ Production-ready with comprehensive error handling
- ✅ All CRUD operations verified
- ✅ Advanced querying with 10+ operators
- ✅ Batch operations (up to 500)
- ✅ Automatic token caching and renewal
- ✅ Field selection and pagination

## License

Apache License 2.0

---

Made with ❤️ using [Ballerina](https://ballerina.io/)