import 'dart:convert';
import 'dart:core';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/product.dart';

class ProductService{
  final Dio _dio = Dio();
  String getNewFeedUrl() {
    final String apiUrl = dotenv.env['API_URL'] ?? '';
    return '$apiUrl/common/product/newfeed';
  }

  String favoriteProductUrl(int productId) {
    final String apiUrl = dotenv.env['API_URL'] ?? '';
    return '$apiUrl/common/favorite/$productId';
  }


  String getProductUrl(int productId) {
    final String apiUrl = dotenv.env['API_URL'] ?? '';
    return '$apiUrl/common/store/product/$productId';
  }

  String addProductToCartUrl() {
    final String apiUrl = dotenv.env['API_URL'] ?? '';
    return '$apiUrl/common/cart';
  }

  String getCataProductUrl(int cataId) {
    final String apiUrl = dotenv.env['API_URL'] ?? '';
    return '$apiUrl/common/category/$cataId/product';
  }
  String getProvinceProductUrl(int provinceId) {
    final String apiUrl = dotenv.env['API_URL'] ?? '';
    return '$apiUrl/common/province/$provinceId/product';
  }

  String getFavoriteProductUrl() {
    final String apiUrl = dotenv.env['API_URL'] ?? '';
    return '$apiUrl/common/favorite';
  }
  String getFavoriteProductIDUrl() {
    final String apiUrl = dotenv.env['API_URL'] ?? '';
    return '$apiUrl/common/favorite/id';
  }

  String getProductSearchUrl(){
    final String apiUrl = dotenv.env['API_URL'] ?? '';
    return '$apiUrl/common/product/search';
  }
  String getProductSearchPriceUrl(){
    final String apiUrl = dotenv.env['API_URL'] ?? '';
    return '$apiUrl/common/product/price-range';
  }

  Future<List<ProductModel>> fetchProductBySearchPrice(String priceRange, {int page = 0, int size = 10}) async {
    try {
      final sharedPreferences = await SharedPreferences.getInstance();
      final accessToken = sharedPreferences.getString('accessToken') ?? '';

      if (accessToken.isEmpty) {
        throw Exception('Access token not found in SharedPreferences');
      }

      Map<String, dynamic> queryParameters = {
        'priceRange': priceRange,
        'page': page.toString(),
        'size': size.toString(),
      };

      final response = await _dio.get(
        getProductSearchPriceUrl(),
        queryParameters: queryParameters,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) {
            return status != null && status < 500; // Chỉ ném lỗi với status >= 500
          },
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> content = response.data['content'] as List<dynamic>;
        // Chuyển đổi dữ liệu thành ProductModel
        print('Response data: ${response.data}');
        return content.map((json) => ProductModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      print('Error: $e');
      if (e is DioError) {
        print('Error response status: ${e.response?.statusCode}');
        print('Error response data: ${e.response?.data}');
      }
      return [];
    }
  }
  Future<List<ProductModel>> fetchProductBySearchProductName(String productName, {int page = 0, int size = 10}) async {
    try {
      final sharedPreferences = await SharedPreferences.getInstance();
      final accessToken = sharedPreferences.getString('accessToken') ?? '';

      if (accessToken.isEmpty) {
        throw Exception('Access token not found in SharedPreferences');
      }

      Map<String, dynamic> queryParameters = {
        'productName': productName,
        'page': page.toString(),
        'size': size.toString(),
      };

      print('Requesting URL: ${getProductSearchUrl()}');
      print('Query parameters: $queryParameters');

      final response = await _dio.get(
        getProductSearchUrl(),
        queryParameters: queryParameters,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) {
            return status != null && status < 500; // Chỉ ném lỗi với status >= 500
          },
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> content = response.data['content'] as List<dynamic>;
        // Chuyển đổi dữ liệu thành ProductModel
        print('Response data: ${response.data}');
        return content.map((json) => ProductModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      print('Error: $e');
      if (e is DioError) {
        print('Error response status: ${e.response?.statusCode}');
        print('Error response data: ${e.response?.data}');
      }
      return [];
    }
  }


  Future<List<int>> fetchProductIDByFavorite(String accessToken) async{
    try{
      final sharedPreferences = await SharedPreferences.getInstance();
      final accessToken = sharedPreferences.getString('accessToken') ?? '';

      if (accessToken.isEmpty) {
        throw Exception('Access token not found in SharedPreferences');
      }
      final response = await _dio.get(
          getFavoriteProductIDUrl(),
          options: Options(
              headers: {
                'Authorization': 'Bearer $accessToken',
                'Content-Type': 'application/json',
              }
          )
      );
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw Exception('Failed to load products');
      }
    }catch(e){
      print('Error: $e');
      return [];
    }
  }
  Future<List<dynamic>> fetchProductsByFavorite(String accessToken) async{
    try{
      final sharedPreferences = await SharedPreferences.getInstance();
      final accessToken = sharedPreferences.getString('accessToken') ?? '';

      if (accessToken.isEmpty) {
        throw Exception('Access token not found in SharedPreferences');
      }
      final response = await _dio.get(
          getFavoriteProductUrl(),
          options: Options(
              headers: {
                'Authorization': 'Bearer $accessToken',
                'Content-Type': 'application/json',
              }
          )
      );
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw Exception('Failed to load products');
      }
    }catch(e){
      print('Error: $e');
      return [];
    }
  }

  Future<List<dynamic>> fetchProductsByProvince(int provinceId, String accessToken) async {
    try {

      if (accessToken.isEmpty) {
        throw Exception('Access token not found in SharedPreferences');
      }
      final response = await _dio.get(
          getProvinceProductUrl(provinceId),
          options: Options(
              headers: {
                'Authorization': 'Bearer $accessToken',
                'Content-Type': 'application/json',
              }
          )
      );
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw Exception('Failed to load products');
      }
    }catch(e){
      print('Error: $e');
      return [];
    }
  }
  Future<List<dynamic>> fetchProductsByCategory(int cataId, String accessToken) async {
    try {
      final sharedPreferences = await SharedPreferences.getInstance();
      final accessToken = sharedPreferences.getString('accessToken') ?? '';

      if (accessToken.isEmpty) {
        throw Exception('Access token not found in SharedPreferences');
      }
      final response = await _dio.get(
        getCataProductUrl(cataId),
          options: Options(
              headers: {
                'Authorization': 'Bearer $accessToken',
                'Content-Type': 'application/json',
              }
          )
);
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw Exception('Failed to load products');
      }
        }catch(e){
    print('Error: $e');
    return [];
    }
  }

  Future<Map<String, dynamic>?> fetchProductDetails(int productId, String accessToken) async {
    try {
      final response = await _dio.get(
        getProductUrl(productId),
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 'Success') {
        return response.data['data']; // Trả về dữ liệu sản phẩm từ response
      } else {
        throw Exception('Failed to load product details');
      }
    } catch (e) {
      print('Error: $e');
      return null; // Trả về null nếu có lỗi
    }
  }

  Future<Map<String, dynamic>> addToCart(int productId, int quantity, String accessToken) async {
    final String url = addProductToCartUrl();
    try{
      final sharedPreferences = await SharedPreferences.getInstance();
      final accessToken = sharedPreferences.getString('accessToken') ?? '';

      if (accessToken.isEmpty) {
        throw Exception('Access token not found in SharedPreferences');
      }
      final response = await _dio.post(
      url,
          data: jsonEncode({
            'productId': productId,
            'quantity': quantity,
          }),
          options: Options(
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
          ),
        );

      if(response.statusCode == 200){
        return response.data;
      }else{
        return {'error': response.data['message']};
          }
    }catch(e){
      print('Error: $e');
     return {'error': 'Lỗi không xác định. Xin hãy thử lại.'};
    }

  }

  Future<List<dynamic>> fetchProductsNewFeed(String accessToken) async {
    try {
      final response = await _dio.get(
        getNewFeedUrl(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['data']; // Return the 'data' part of the response
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      print('Error: $e');
      return [];
    }
  }

  Future<bool> favoriteProduct(int productId, String accessToken) async {
    try {
      final response = await _dio.post(
        favoriteProductUrl(productId),
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to favorite product');
      }
    } catch (e) {
      print('Error: $e');
      return false; // Trả về false nếu có lỗi
    }
  }


}

