part of 'generated.dart';

class UpdateTimeEntryVariablesBuilder {
  String id;
  Optional<String> _comments = Optional.optional(nativeFromJson, nativeToJson);

  final FirebaseDataConnect _dataConnect;  UpdateTimeEntryVariablesBuilder comments(String? t) {
   _comments.value = t;
   return this;
  }

  UpdateTimeEntryVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<UpdateTimeEntryData> dataDeserializer = (dynamic json)  => UpdateTimeEntryData.fromJson(jsonDecode(json));
  Serializer<UpdateTimeEntryVariables> varsSerializer = (UpdateTimeEntryVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateTimeEntryData, UpdateTimeEntryVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateTimeEntryData, UpdateTimeEntryVariables> ref() {
    UpdateTimeEntryVariables vars= UpdateTimeEntryVariables(id: id,comments: _comments,);
    return _dataConnect.mutation("UpdateTimeEntry", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateTimeEntryTimeEntryUpdate {
  final String id;
  UpdateTimeEntryTimeEntryUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateTimeEntryTimeEntryUpdate otherTyped = other as UpdateTimeEntryTimeEntryUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  UpdateTimeEntryTimeEntryUpdate({
    required this.id,
  });
}

@immutable
class UpdateTimeEntryData {
  final UpdateTimeEntryTimeEntryUpdate? timeEntry_update;
  UpdateTimeEntryData.fromJson(dynamic json):
  
  timeEntry_update = json['timeEntry_update'] == null ? null : UpdateTimeEntryTimeEntryUpdate.fromJson(json['timeEntry_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateTimeEntryData otherTyped = other as UpdateTimeEntryData;
    return timeEntry_update == otherTyped.timeEntry_update;
    
  }
  @override
  int get hashCode => timeEntry_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (timeEntry_update != null) {
      json['timeEntry_update'] = timeEntry_update!.toJson();
    }
    return json;
  }

  UpdateTimeEntryData({
    this.timeEntry_update,
  });
}

@immutable
class UpdateTimeEntryVariables {
  final String id;
  late final Optional<String>comments;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateTimeEntryVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']) {
  
  
  
    comments = Optional.optional(nativeFromJson, nativeToJson);
    comments.value = json['comments'] == null ? null : nativeFromJson<String>(json['comments']);
  
  }
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateTimeEntryVariables otherTyped = other as UpdateTimeEntryVariables;
    return id == otherTyped.id && 
    comments == otherTyped.comments;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, comments.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    if(comments.state == OptionalState.set) {
      json['comments'] = comments.toJson();
    }
    return json;
  }

  UpdateTimeEntryVariables({
    required this.id,
    required this.comments,
  });
}

