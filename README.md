# Firestore Module

A Ballerina module for accessing Google Cloud Firestore database with authentication support.

## Overview

This module provides a simple interface to interact with Google Cloud Firestore, including:
- Document creation
- Document querying with filters
- Firebase/Google Cloud authentication
- Automatic data type conversion between Ballerina and Firestore formats

## Features

- **Document Operations**: Create and query documents in Firestore collections
- **Authentication**: Integrated Google Cloud authentication using service account
- **Type Safety**: Automatic conversion between Ballerina types and Firestore field types
- **Filtering**: Support for single and multiple field filters with AND operations
- **Error Handling**: Comprehensive error handling for all operations

## Usage

### Configuration

```ballerina
import your_org/firestore;

public function main() returns error? {
    firestore:AuthConfig authConfig = {
        serviceAccountPath: "./path/to/service-account.json",
        privateKeyPath: "./path/to/private-key.pem",
        jwtConfig: {
            scope: "https://www.googleapis.com/auth/datastore",
            expTime: 3600
        }
    };

    firestore:Client firestoreClient = check new(authConfig);
    
    // Your operations here
}
```

### Creating Documents

```ballerina
string accessToken = check firestoreClient.generateToken();

map<json> documentData = {
    "name": "John Doe",
    "age": 30,
    "active": true,
    "metadata": {
        "created": "2024-01-01",
        "tags": ["user", "active"]
    }
};

check firestore:createFirestoreDocument(
    "your-project-id",
    accessToken,
    "users",
    documentData
);
```

### Querying Documents

```ballerina
string accessToken = check firestoreClient.generateToken();

map<json> filter = {
    "active": true,
    "age": 30
};

map<json>[] results = check firestore:queryFirestoreDocuments(
    "your-project-id",
    accessToken,
    "users",
    filter
);

foreach var doc in results {
    io:println("Document: ", doc);
}
```

## Supported Data Types

The module automatically converts between Ballerina and Firestore types:

| Ballerina Type | Firestore Type |
|----------------|----------------|
| `string` | `stringValue` |
| `int` | `integerValue` |
| `boolean` | `booleanValue` |
| `()` (null) | `nullValue` |
| `map<json>` | `mapValue` |
| `json[]` | `arrayValue` |
| `float` | `doubleValue` |

## API Reference

### Types

- `ServiceAccount`: Service account configuration record
- `FirebaseConfig`: Firebase project configuration (optional)
- `JWTConfig`: JWT token configuration
- `AuthConfig`: Authentication configuration for the client

### Functions

- `createFirestoreDocument()`: Create a new document in a collection
- `queryFirestoreDocuments()`: Query documents with filters
- `processFirestoreValue()`: Convert Ballerina values to Firestore format
- `extractFirestoreValue()`: Convert Firestore values to Ballerina format
- `buildFirestoreFilter()`: Build Firestore query filters

### Client

- `Client`: Main client class for authentication and token management
- `generateToken()`: Generate OAuth2 access token for Firestore API calls

## Requirements

- Ballerina Swan Lake 2201.8.0 or later
- Google Cloud Project with Firestore enabled
- Service Account with Firestore permissions
- Service Account JSON key file

## License

This module is available under the Apache 2.0 license.