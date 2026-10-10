class Employee {
  Employee({
    required this.userId,
    required this.directoryId,
    required this.employeeNumber,
    this.role,
    this.phone,
  });

  final String userId;
  final String directoryId;
  final String? role;
  final String employeeNumber;
  final String? phone;

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
    userId: j["userId"] as String,
    directoryId: j["directoryId"] as String,
    employeeNumber: j["employeeNumber"] as String,
    role: j["role"] as String?,
    phone: j["phone"] as String?,
  );
}
