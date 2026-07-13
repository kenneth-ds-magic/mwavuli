import 'package:dio/dio.dart';

/// Turn an API/network error into a friendly message for the auth forms.
String authErrorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Can\'t reach the server. Check your connection and try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
