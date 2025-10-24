# Basic Usage

```dart
ExampleConnector.instance.CreateDepartment().execute();
ExampleConnector.instance.ListDepartments().execute();
ExampleConnector.instance.UpdateTimeEntry(updateTimeEntryVariables).execute();
ExampleConnector.instance.GetTimeEntry(getTimeEntryVariables).execute();

```

## Optional Fields

Some operations may have optional fields. In these cases, the Flutter SDK exposes a builder method, and will have to be set separately.

Optional fields can be discovered based on classes that have `Optional` object types.

This is an example of a mutation with an optional field:

```dart
await Example.instance.UpdateTimeEntry({ ... })
.comments(...)
.execute();
```

Note: the above example is a mutation, but the same logic applies to query operations as well. Additionally, `createMovie` is an example, and may not be available to the user.

