# dataconnect_generated SDK

## Installation
```sh
flutter pub get firebase_data_connect
flutterfire configure
```
For more information, see [Flutter for Firebase installation documentation](https://firebase.google.com/docs/data-connect/flutter-sdk#use-core).

## Data Connect instance
Each connector creates a static class, with an instance of the `DataConnect` class that can be used to connect to your Data Connect backend and call operations.

### Connecting to the emulator

```dart
String host = 'localhost'; // or your host name
int port = 9399; // or your port number
ExampleConnector.instance.dataConnect.useDataConnectEmulator(host, port);
```

You can also call queries and mutations by using the connector class.
## Queries

### ListDepartments
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.listDepartments().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListDepartmentsData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listDepartments();
ListDepartmentsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.listDepartments().ref();
ref.execute();

ref.subscribe(...);
```


### GetTimeEntry
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.getTimeEntry(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetTimeEntryData, GetTimeEntryVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getTimeEntry(
  id: id,
);
GetTimeEntryData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.getTimeEntry(
  id: id,
).ref();
ref.execute();

ref.subscribe(...);
```

## Mutations

### CreateDepartment
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.createDepartment().execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateDepartmentData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createDepartment();
CreateDepartmentData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.createDepartment().ref();
ref.execute();
```


### UpdateTimeEntry
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.updateTimeEntry(
  id: id,
).execute();
```

#### Optional Arguments
We return a builder for each query. For UpdateTimeEntry, we created `UpdateTimeEntryBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class UpdateTimeEntryVariablesBuilder {
  ...
   UpdateTimeEntryVariablesBuilder comments(String? t) {
   _comments.value = t;
   return this;
  }

  ...
}
ExampleConnector.instance.updateTimeEntry(
  id: id,
)
.comments(comments)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<UpdateTimeEntryData, UpdateTimeEntryVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.updateTimeEntry(
  id: id,
);
UpdateTimeEntryData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.updateTimeEntry(
  id: id,
).ref();
ref.execute();
```

