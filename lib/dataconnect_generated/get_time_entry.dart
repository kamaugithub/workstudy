part of 'generated.dart';

class GetTimeEntryVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  GetTimeEntryVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<GetTimeEntryData> dataDeserializer = (dynamic json)  => GetTimeEntryData.fromJson(jsonDecode(json));
  Serializer<GetTimeEntryVariables> varsSerializer = (GetTimeEntryVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<GetTimeEntryData, GetTimeEntryVariables>> execute() {
    return ref().execute();
  }

  QueryRef<GetTimeEntryData, GetTimeEntryVariables> ref() {
    GetTimeEntryVariables vars= GetTimeEntryVariables(id: id,);
    return _dataConnect.query("GetTimeEntry", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class GetTimeEntryTimeEntry {
  final String id;
  final GetTimeEntryTimeEntryStudent student;
  final Timestamp clockInTime;
  final Timestamp? clockOutTime;
  final EnumValue<TimeEntryStatus> status;
  GetTimeEntryTimeEntry.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']),
  student = GetTimeEntryTimeEntryStudent.fromJson(json['student']),
  clockInTime = Timestamp.fromJson(json['clockInTime']),
  clockOutTime = json['clockOutTime'] == null ? null : Timestamp.fromJson(json['clockOutTime']),
  status = timeEntryStatusDeserializer(json['status']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetTimeEntryTimeEntry otherTyped = other as GetTimeEntryTimeEntry;
    return id == otherTyped.id && 
    student == otherTyped.student && 
    clockInTime == otherTyped.clockInTime && 
    clockOutTime == otherTyped.clockOutTime && 
    status == otherTyped.status;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, student.hashCode, clockInTime.hashCode, clockOutTime.hashCode, status.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['student'] = student.toJson();
    json['clockInTime'] = clockInTime.toJson();
    if (clockOutTime != null) {
      json['clockOutTime'] = clockOutTime!.toJson();
    }
    json['status'] = 
    timeEntryStatusSerializer(status)
    ;
    return json;
  }

  GetTimeEntryTimeEntry({
    required this.id,
    required this.student,
    required this.clockInTime,
    this.clockOutTime,
    required this.status,
  });
}

@immutable
class GetTimeEntryTimeEntryStudent {
  final String id;
  final String displayName;
  GetTimeEntryTimeEntryStudent.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']),
  displayName = nativeFromJson<String>(json['displayName']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetTimeEntryTimeEntryStudent otherTyped = other as GetTimeEntryTimeEntryStudent;
    return id == otherTyped.id && 
    displayName == otherTyped.displayName;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, displayName.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['displayName'] = nativeToJson<String>(displayName);
    return json;
  }

  GetTimeEntryTimeEntryStudent({
    required this.id,
    required this.displayName,
  });
}

@immutable
class GetTimeEntryData {
  final GetTimeEntryTimeEntry? timeEntry;
  GetTimeEntryData.fromJson(dynamic json):
  
  timeEntry = json['timeEntry'] == null ? null : GetTimeEntryTimeEntry.fromJson(json['timeEntry']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetTimeEntryData otherTyped = other as GetTimeEntryData;
    return timeEntry == otherTyped.timeEntry;
    
  }
  @override
  int get hashCode => timeEntry.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (timeEntry != null) {
      json['timeEntry'] = timeEntry!.toJson();
    }
    return json;
  }

  GetTimeEntryData({
    this.timeEntry,
  });
}

@immutable
class GetTimeEntryVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  GetTimeEntryVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetTimeEntryVariables otherTyped = other as GetTimeEntryVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  GetTimeEntryVariables({
    required this.id,
  });
}

