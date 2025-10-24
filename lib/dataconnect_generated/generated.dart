library dataconnect_generated;
import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

part 'create_department.dart';

part 'list_departments.dart';

part 'update_time_entry.dart';

part 'get_time_entry.dart';



  enum TimeEntryStatus {
    
      PENDING,
    
      APPROVED,
    
      DECLINED,
    
  }
  
  String timeEntryStatusSerializer(EnumValue<TimeEntryStatus> e) {
    return e.stringValue;
  }
  EnumValue<TimeEntryStatus> timeEntryStatusDeserializer(dynamic data) {
    switch (data) {
      
      case 'PENDING':
        return const Known(TimeEntryStatus.PENDING);
      
      case 'APPROVED':
        return const Known(TimeEntryStatus.APPROVED);
      
      case 'DECLINED':
        return const Known(TimeEntryStatus.DECLINED);
      
      default:
        return Unknown(data);
    }
  }
  



String enumSerializer(Enum e) {
  return e.name;
}



/// A sealed class representing either a known enum value or an unknown string value.
@immutable
sealed class EnumValue<T extends Enum> {
  const EnumValue();

  

  /// The string representation of the value.
  String get stringValue;
  @override
  String toString() {
    return "EnumValue($stringValue)";
  }
}

/// Represents a known, valid enum value.
class Known<T extends Enum> extends EnumValue<T> {
  /// The actual enum value.
  final T value;

  const Known(this.value);

  @override
  String get stringValue => value.name;

  @override
  String toString() {
    return "Known($stringValue)";
  }
}
/// Represents an unknown or unrecognized enum value.
class Unknown extends EnumValue<Never> {
  /// The raw string value that couldn't be mapped to a known enum.
  @override
  final String stringValue;

  const Unknown(this.stringValue);
  @override
  String toString() {
    return "Unknown($stringValue)";
  }
}

class ExampleConnector {
  
  
  CreateDepartmentVariablesBuilder createDepartment () {
    return CreateDepartmentVariablesBuilder(dataConnect, );
  }
  
  
  ListDepartmentsVariablesBuilder listDepartments () {
    return ListDepartmentsVariablesBuilder(dataConnect, );
  }
  
  
  UpdateTimeEntryVariablesBuilder updateTimeEntry ({required String id, }) {
    return UpdateTimeEntryVariablesBuilder(dataConnect, id: id,);
  }
  
  
  GetTimeEntryVariablesBuilder getTimeEntry ({required String id, }) {
    return GetTimeEntryVariablesBuilder(dataConnect, id: id,);
  }
  

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'us-east4',
    'example',
    'workstudy',
  );

  ExampleConnector({required this.dataConnect});
  static ExampleConnector get instance {
    return ExampleConnector(
        dataConnect: FirebaseDataConnect.instanceFor(
            connectorConfig: connectorConfig,
            sdkType: CallerSDKType.generated));
  }

  FirebaseDataConnect dataConnect;
}

