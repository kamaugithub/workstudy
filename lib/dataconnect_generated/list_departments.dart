part of 'generated.dart';

class ListDepartmentsVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  ListDepartmentsVariablesBuilder(this._dataConnect, );
  Deserializer<ListDepartmentsData> dataDeserializer = (dynamic json)  => ListDepartmentsData.fromJson(jsonDecode(json));
  
  Future<QueryResult<ListDepartmentsData, void>> execute() {
    return ref().execute();
  }

  QueryRef<ListDepartmentsData, void> ref() {
    
    return _dataConnect.query("ListDepartments", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class ListDepartmentsDepartments {
  final String id;
  final String name;
  final String? description;
  ListDepartmentsDepartments.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']),
  name = nativeFromJson<String>(json['name']),
  description = json['description'] == null ? null : nativeFromJson<String>(json['description']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListDepartmentsDepartments otherTyped = other as ListDepartmentsDepartments;
    return id == otherTyped.id && 
    name == otherTyped.name && 
    description == otherTyped.description;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, name.hashCode, description.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['name'] = nativeToJson<String>(name);
    if (description != null) {
      json['description'] = nativeToJson<String?>(description);
    }
    return json;
  }

  ListDepartmentsDepartments({
    required this.id,
    required this.name,
    this.description,
  });
}

@immutable
class ListDepartmentsData {
  final List<ListDepartmentsDepartments> departments;
  ListDepartmentsData.fromJson(dynamic json):
  
  departments = (json['departments'] as List<dynamic>)
        .map((e) => ListDepartmentsDepartments.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListDepartmentsData otherTyped = other as ListDepartmentsData;
    return departments == otherTyped.departments;
    
  }
  @override
  int get hashCode => departments.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['departments'] = departments.map((e) => e.toJson()).toList();
    return json;
  }

  ListDepartmentsData({
    required this.departments,
  });
}

