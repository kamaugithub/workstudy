part of 'generated.dart';

class CreateDepartmentVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  CreateDepartmentVariablesBuilder(this._dataConnect, );
  Deserializer<CreateDepartmentData> dataDeserializer = (dynamic json)  => CreateDepartmentData.fromJson(jsonDecode(json));
  
  Future<OperationResult<CreateDepartmentData, void>> execute() {
    return ref().execute();
  }

  MutationRef<CreateDepartmentData, void> ref() {
    
    return _dataConnect.mutation("CreateDepartment", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class CreateDepartmentDepartmentInsert {
  final String id;
  CreateDepartmentDepartmentInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateDepartmentDepartmentInsert otherTyped = other as CreateDepartmentDepartmentInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateDepartmentDepartmentInsert({
    required this.id,
  });
}

@immutable
class CreateDepartmentData {
  final CreateDepartmentDepartmentInsert department_insert;
  CreateDepartmentData.fromJson(dynamic json):
  
  department_insert = CreateDepartmentDepartmentInsert.fromJson(json['department_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateDepartmentData otherTyped = other as CreateDepartmentData;
    return department_insert == otherTyped.department_insert;
    
  }
  @override
  int get hashCode => department_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['department_insert'] = department_insert.toJson();
    return json;
  }

  CreateDepartmentData({
    required this.department_insert,
  });
}

