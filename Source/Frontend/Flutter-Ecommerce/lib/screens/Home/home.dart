import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_carousel_slider/carousel_slider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_shop/Common/Widgets/app_title.dart';
import 'package:smart_shop/Common/Widgets/catalogue_widget.dart';
import 'package:smart_shop/Common/Widgets/custom_app_bar.dart';
import 'package:smart_shop/Common/Widgets/item_widget.dart';
import 'package:smart_shop/Common/Widgets/shimmer_effect.dart';
import 'package:smart_shop/Screens/Catalogue/catalogue.dart';
import 'package:smart_shop/Screens/Favorite/favorite.dart';
import 'package:smart_shop/Screens/Notifications/notifications.dart';
import 'package:smart_shop/Screens/Onboarding/onboarding.dart';
import 'package:smart_shop/Screens/Product/product.dart';
import 'package:smart_shop/Screens/Settings/settings.dart';
import 'package:smart_shop/Utils/app_colors.dart';
import 'package:smart_shop/Utils/font_styles.dart';
import 'package:smart_shop/dummy/dummy_data.dart';
import 'package:smart_shop/service/seller_service.dart';

import '../../service/product_service.dart';


class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);
  static const String routeName = 'home';

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final GlobalKey<ScaffoldState> _key = GlobalKey();
  List<dynamic>? _products;
  DateTime? _lastProductsUpdateTime;
  final productService = ProductService();
  @override
  void initState() {
    super.initState();
    _loadCachedProducts();
  }
  Future<void> _submitSellerLicense(File? licenseFile) async {
    final sellerService = SellerService();
    if (licenseFile != null) {
      final bool isSubmitted = await sellerService.submitSeller(imageFile: licenseFile);
      if (isSubmitted) {
        // Tải lên thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tải lên ảnh giấy phép thành công!')),
        );
      } else {
        // Tải lên thất bại
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tải lên ảnh giấy phép thất bại.')),
        );
      }
    }
  }
  Future<void> _loadCachedProducts() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final cachedProducts = sharedPreferences.getString('cachedProducts');
    if (cachedProducts != null) {
      _products = jsonDecode(cachedProducts);
      _lastProductsUpdateTime = DateTime.now().subtract(Duration(minutes: 29)); // Gán thời gian gần nhất
      setState(() {});
    } else {
      await _fetchProducts(context); // Nếu không có dữ liệu cached, gọi API
    }
  }



  Future<void> _logout(BuildContext context) async {
    // Xóa access token và refresh token từ SharedPreferences
    final sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.remove('accessToken');
    await sharedPreferences.remove('refreshToken'); // Nếu bạn lưu refresh token

    // Điều hướng đến màn hình đăng nhập
    Navigator.pushReplacementNamed(context, OnBoarding.routeName);
  }

  Future<void> _fetchProducts(BuildContext context) async {
    // Fetch latest products
    final sharedPreferences = await SharedPreferences.getInstance();
    final accessToken = sharedPreferences.getString('accessToken') ?? '';
    _products = await productService.fetchProductsNewFeed(accessToken);
    _lastProductsUpdateTime = DateTime.now();
    await sharedPreferences.setString('cachedProducts', jsonEncode(_products));

    setState(() {});
  }

  Future<void> _handleFavorite(BuildContext context, int productId) async {
    // Lấy accessToken từ SharedPreferences
    final sharedPreferences = await SharedPreferences.getInstance();
    final accessToken = sharedPreferences.getString('accessToken') ?? '';
    bool isSuccess = await productService.favoriteProduct(productId, accessToken);

    if (isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar( content: Text(
          'Thao tác thành công',
          style: TextStyle(color: Colors.black), // Đổi màu chữ
        ),
          backgroundColor: Colors.white, // Đổi màu nền của SnackBar
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yêu thích sản phẩm thất bại!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      key: _key,
      appBar: _buildCustomAppBar(context),
      drawer: _buildDrawer(context,_showUploadLicenseDialog,),
      body: _buildBody(context),
      resizeToAvoidBottomInset: false,
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSellerCard(),
          _buildCatalogue(),
          _buildProductSuggestions(context),
          _buildFeatured(context),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, Future<void> Function(BuildContext) showUploadLicenseDialog) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * .60,
      child: Drawer(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * .20,
              child: DrawerHeader(
                padding: EdgeInsets.zero,
                margin: EdgeInsets.zero,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(left: 20.0),
                    child: AppTitle(
                      fontStyle: FontStyles.montserratExtraBold18(),
                      marginTop: 0.0,
                    ),
                  ),
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primaryLight],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    stops: [0, 1],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width / 2,
              height: MediaQuery.of(context).size.height / 3.0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, Favorite.routeName);
                    },
                    leading: const Icon(Icons.star,
                        color: AppColors.primaryLight),
                    title: Text(
                      'Yêu thích',
                      style: FontStyles.montserratRegular18(),
                    ),
                  ),
                  ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      showUploadLicenseDialog(context);
                    },
                    leading: const Icon(Icons.supervised_user_circle,
                        color: AppColors.primaryLight),
                    title: Text(
                      'Trở thành người bán',
                      style: FontStyles.montserratRegular18(),
                    ),
                  ),
                  ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, Settings.routeName);
                    },
                    leading: const Icon(Icons.settings,
                        color: AppColors.primaryLight),
                    title: Text(
                      'Cài đặt',
                      style: FontStyles.montserratRegular18(),
                    ),
                  ),
                  ListTile(
                    onTap: () {
                      Navigator.pushNamed(context, Favorite.routeName);
                    },
                    leading: const Icon(Icons.help_outline,
                        color: AppColors.primaryLight),
                    title: Text(
                      'Trợ giúp',
                      style: FontStyles.montserratRegular18(),
                    ),
                  ),
                  ListTile(
                    onTap: () async {
                      await _logout(context);
                    },
                    leading: const Icon(Icons.logout_outlined,
                        color: AppColors.primaryLight),
                    title: Text(
                      'Đăng xuất',
                      style: FontStyles.montserratRegular18(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSize _buildCustomAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize:
          Size(double.infinity, MediaQuery.of(context).size.height * .20),
      child: CustomAppBar(
        isHome: true,
        enableSearchField: true,
        leadingIcon: Icons.menu,
        leadingOnTap: () {},
        trailingIcon: Icons.notifications_none_outlined,
        trailingOnTap: () {
          Navigator.of(context).pushNamed(NotificationScreen.routeName);
        },
        scaffoldKey: _key,
      ),
    );
  }

  Widget _buildSellerCard() {
    var screenHeight = MediaQuery.of(context).size.height;
    return Container(
      margin: EdgeInsets.only(left: 20.0.w, right: 20.w, top: 50.0.h),
      height: 88.h,
      width: 343.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0.r),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.0.r),
            child: makeSlider(),
          ),
          Positioned(
              top: screenHeight * .020.h,
              left: 20.0,
              child: Text(
                'Sản phẩm giảm giá',
                style: FontStyles.montserratBold25()
                    .copyWith(color: AppColors.white),
              )),
          Positioned(
            top: screenHeight * .070.h,
            left: 20.0.w,
            child: Row(
              children: [
                Text(
                  'Xem thêm',
                  style: FontStyles.montserratBold12().copyWith(
                    color: AppColors.secondary,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12.0.h,
                  color: AppColors.secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogue() {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, Catalogue.routeName, arguments: [true, true]);
      },
      child: Container(
        margin: EdgeInsets.only(top: 25.0.h, left: 20.h, right: 20.0.h, bottom: 17.h),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Danh mục sản phẩm',
                  style: FontStyles.montserratBold19().copyWith(
                    color: const Color(0xFF34283E),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, Catalogue.routeName, arguments: [true, true]);
                  },
                  child: Text(
                    'Xem thêm ',
                    style: FontStyles.montserratBold12().copyWith(color: const Color(0xFF9B9B9B)),
                  ),
                ),
              ],
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: 97.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: DummyData.catalogueImagesLink.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  return CatalogueWidget(
                    height: 88.h,
                    width: 88.w,
                    index: index,
                    imagePath: DummyData.catalogueImagesLink[index], // Truyền đường dẫn ảnh từ assets
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFeatured(BuildContext context) {
    var screenHeight = MediaQuery.of(context).size.height;

    return Container(
      margin: EdgeInsets.only(
        left: 20.0.w,
        right: 20.0.w,
        top: 20.h,
        bottom: screenHeight * .09.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sản phẩm mới',
            style: FontStyles.montserratBold19().copyWith(color: const Color(0xFF34283E)),
          ),
          SizedBox(height: 10.0.h),
          _products == null // Kiểm tra xem đã có sản phẩm chưa
              ? Center(child: CircularProgressIndicator())
              : (_products!.isEmpty
              ? Center(child: Text('No products found.'))
              : SizedBox(
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: _products!.length,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 250.0.h,
                crossAxisSpacing: 10.0.w,
                mainAxisSpacing: 8.0.h,
              ),
              itemBuilder: (_, index) {
                final product = _products![index];
                String productImageUrl = product['productImages'].isNotEmpty
                    ? product['productImages'][0]['imageUrl']
                    : '';

                return GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, Product.routeName, arguments: product['productId']);
                  },
                  child: ItemWidget(
                    index: index,
                    favoriteIcon: true,
                    productName: product['productName'],
                    provinceName: product['provinceName'],
                    productPrice: formatCurrency(product['productPrice']),
                    productImageUrl: productImageUrl,
                    productId: product['productId'],
                    onFavorite: (int productId) {
                      _handleFavorite(context, productId);
                    },
                  ),
                );
              },
            ),
          )),
        ],
      ),
    );
  }

  Future<void> _showUploadLicenseDialog(BuildContext context) async {
    File? _licenseFile;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tải lên ảnh giấy phép'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () async {
                final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (pickedFile != null) {
                  _licenseFile = File(pickedFile.path);
                  Navigator.of(context).pop();
                  await _submitSellerLicense(_licenseFile);
                }
              },
              child: Text('Chọn ảnh từ thư viện'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Hủy'),
            ),
          ],
        ),
      ),
    );
  }
  // Sản phẩm gợi ý
  Widget _buildProductSuggestions(BuildContext context) {
    var screenHeight = MediaQuery.of(context).size.height;
    int? _currentProvinceId;
    DateTime? _lastProductsUpdateTime;
    List<dynamic>? _products;

    return FutureBuilder<List<dynamic>>(
      future: _getCurrentProvinceId().then((provinceId) {
        _currentProvinceId = provinceId;
        return _getCachedProductSuggestions(_currentProvinceId!);
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Lỗi khi tải sản phẩm: ${snapshot.error}'));
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          _products = snapshot.data!.take(4).toList(); // Giới hạn 4 sản phẩm
          _lastProductsUpdateTime = DateTime.now();
          return Container(
            margin: EdgeInsets.only(
              left: 20.0.w,
              right: 20.0.w,
              top: 20.h,
              bottom: screenHeight * .01.h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sản phẩm gợi ý',
                      style: FontStyles.montserratBold19()
                          .copyWith(color: const Color(0xFF34283E)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_getCurrentProvinceName(_currentProvinceId ?? -1)}',
                          style: FontStyles.montserratRegular14()
                              .copyWith(color: Colors.lightBlue),
                        ),
                        SizedBox(width: 4.0.w),
                        Icon(
                          Icons.location_on,
                          color: Colors.green,
                          size: 16.0.h,
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 10.0.h),
                SizedBox(
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: _products!.length,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: 250.0.h,
                      crossAxisSpacing: 10.0.w,
                      mainAxisSpacing: 8.0.h,
                    ),
                    itemBuilder: (_, index) {
                      final product = _products![index];
                      String productImageUrl = product['productImages'].isNotEmpty
                          ? product['productImages'][0]['imageUrl']
                          : '';

                      return GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, Product.routeName, arguments: product['productId']);
                        },
                        child: ItemWidget(
                          index: index,
                          favoriteIcon: true,
                          productName: product['productName'],
                          provinceName: product['provinceName'],
                          productPrice: formatCurrency(product['productPrice']),
                          productImageUrl: productImageUrl,
                          productId: product['productId'],
                          onFavorite: (int productId) {
                            _handleFavorite(context, productId);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        } else {
          return Center(child: Text('Không có sản phẩm gợi ý'));
        }
      },
    );
  }
  Future<List<dynamic>> _getCachedProductSuggestions(int provinceId) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final cachedProductSuggestions = sharedPreferences.getString('cachedProductSuggestions$provinceId');
    final lastUpdateTime = sharedPreferences.getString('lastProductsUpdateTime$provinceId');

    if (cachedProductSuggestions != null && lastUpdateTime != null) {
      DateTime lastUpdate = DateTime.parse(lastUpdateTime);
      if (DateTime.now().difference(lastUpdate).inMinutes < 30) {
        return jsonDecode(cachedProductSuggestions); // Trả về dữ liệu cache
      }
    }

    // Nếu cache hết hạn, gọi API để lấy dữ liệu mới
    final products = await _fetchProductsByProvince(provinceId);
    await sharedPreferences.setString('cachedProductSuggestions$provinceId', jsonEncode(products));
    await sharedPreferences.setString('lastProductsUpdateTime$provinceId', DateTime.now().toIso8601String());

    return products;
  }

  String _getCurrentProvinceName(int provinceId) {
    switch (provinceId) {
      case 1:
        return 'An Giang';
      case 2:
        return 'Bạc Liêu';
      case 3:
        return 'Bến Tre';
      case 4:
        return 'Cà Mau';
      case 5:
        return 'Cần Thơ';
      case 6:
        return 'Đồng Tháp';
      case 7:
        return 'Hậu Giang';
      case 8:
        return 'Kiên Giang';
      case 9:
        return 'Long An';
      case 10:
        return 'Sóc Trăng';
      case 11:
        return 'Tiền Giang';
      case 12:
        return 'Trà Vinh';
      case 13:
        return 'Vĩnh Long';
      default:
        return 'Không xác định';
    }
  }
  Future<int> _getCurrentProvinceId() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Người dùng từ chối quyền, hãy xử lý phù hợp
        return -1;
      }
    }

    final position = await Geolocator.getCurrentPosition();
    return _getProvince(position.latitude, position.longitude);
  }

  Future<List<dynamic>> _fetchProductsByProvince(int provinceId) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final accessToken = sharedPreferences.getString('accessToken') ?? '';

    if (accessToken.isEmpty) {
      throw Exception('Access token not found in SharedPreferences');
    }

    // Kiểm tra nếu đã có sản phẩm và dữ liệu cache còn mới
    if (_products == null || DateTime.now().difference(_lastProductsUpdateTime!).inMinutes >= 30) {
      _products = await _fetchProductsByProvince(provinceId);
    }


    return await productService.fetchProductsByProvince(provinceId, accessToken);
  }

  int _getProvince(double latitude, double longitude) {
    // Xác định tỉnh/thành phố tương ứng với vị trí người dùng
    if (latitude >= 10.5 && longitude >= 104.8 && latitude <= 11.5 && longitude <= 105.3) {
      return 1; // An Giang
    } else if (latitude >= 9.0 && longitude >= 105.0 && latitude <= 9.5 && longitude <= 105.5) {
      return 2; // Bạc Liêu
    } else if (latitude >= 9.7 && longitude >= 105.9 && latitude <= 10.2 && longitude <= 106.4) {
      return 3; // Bến Tre
    } else if (latitude >= 8.8 && longitude >= 104.7 && latitude <= 9.3 && longitude <= 105.2) {
      return 4; // Cà Mau
    } else if (latitude >= 9.9 && longitude >= 105.5 && latitude <= 10.4 && longitude <= 106.0) {
      return 5; // Cần Thơ
    } else if (latitude >= 10.1 && longitude >= 105.5 && latitude <= 10.6 && longitude <= 106.0) {
      return 6; // Đồng Tháp
    } else if (latitude >= 9.5 && longitude >= 105.3 && latitude <= 10.0 && longitude <= 105.8) {
      return 7; // Hậu Giang
    } else if (latitude >= 9.8 && longitude >= 104.8 && latitude <= 10.3 && longitude <= 105.3) {
      return 8; // Kiên Giang
    } else if (latitude >= 10.3 && longitude >= 105.8 && latitude <= 10.8 && longitude <= 106.3) {
      return 9; // Long An
    } else if (latitude >= 9.3 && longitude >= 105.3 && latitude <= 9.8 && longitude <= 105.8) {
      return 10; // Sóc Trăng
    } else if (latitude >= 10.1 && longitude >= 105.8 && latitude <= 10.6 && longitude <= 106.3) {
      return 11; // Tiền Giang
    } else if (latitude >= 9.5 && longitude >= 106.0 && latitude <= 10.0 && longitude <= 106.5) {
      return 12; // Trà Vinh
    } else if (latitude >= 10.0 && longitude >= 105.5 && latitude <= 10.5 && longitude <= 106.0) {
      return 13; // Vĩnh Long
    } else {
      return -1; // Không xác định được
    }
  }


  Future<void> _loadCachedProductsProvince() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final provinceId = await _getCurrentProvinceId();
    final cachedProducts = sharedPreferences.getString('cachedProductSuggestions$provinceId');
    if (cachedProducts != null) {
      _products = jsonDecode(cachedProducts);
      _lastProductsUpdateTime = DateTime.now().subtract(Duration(minutes: 29)); // Gán thời gian gần nhất
      setState(() {});
    } else {
      await _fetchProductsProvince(context); // Nếu không có dữ liệu cached, gọi API
    }
  }

  Future<void> _fetchProductsProvince(BuildContext context) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final accessToken = sharedPreferences.getString('accessToken') ?? '';
    final provinceId = await _getCurrentProvinceId();
    final suggestionProducts = await _fetchProductsByProvince(provinceId);
    // Tải sản phẩm mới và lưu cache
    _products = await productService.fetchProductsByProvince(provinceId, accessToken);
    await sharedPreferences.setString('cachedProductSuggestions$provinceId', jsonEncode(suggestionProducts));
    _lastProductsUpdateTime = DateTime.now();

    setState(() {});
  }


  String formatCurrency(double price) {
    final formatter = NumberFormat.simpleCurrency(locale: 'vi_VN');
    return formatter.format(price);
  }


  Widget makeSlider() {
    return CarouselSlider.builder(
      unlimitedMode: true,
      autoSliderDelay: const Duration(seconds: 5),
      enableAutoSlider: true,
      slideBuilder: (index) {
        return Image.asset(
          DummyData.sellerImagesLink[index],
          color: const Color.fromRGBO(42, 3, 75, 0.35),
          colorBlendMode: BlendMode.srcOver,
          fit: BoxFit.fill,
          errorBuilder: (context, error, stackTrace) {
            return ShimmerEffect(
              borderRadius: 10.0.r,
              height: 88.h,
              width: 343.w,
            );
          },
        );
      },
      slideTransform: const DefaultTransform(),
      slideIndicator: CircularSlideIndicator(
        currentIndicatorColor: AppColors.lightGray,
        alignment: Alignment.bottomCenter,
        padding: EdgeInsets.only(bottom: 10.h, left: 20.0.w),
      ),
      itemCount: DummyData.sellerImagesLink.length,
    );
  }

}
