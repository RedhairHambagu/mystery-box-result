import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/mystery_box_record.dart';

class MysteryBoxService {
  static final MysteryBoxService _instance = MysteryBoxService._internal();
  factory MysteryBoxService() => _instance;
  MysteryBoxService._internal();

  final AuthService _authService = AuthService();

  // 获取盲盒记录列表
  Future<List<MysteryBoxRecord>> fetchMysteryBoxRecords(int page) async {
    final wdToken = await _authService.getWdToken();
    final underscoreParams = await _authService.getUnderscoreParams();
    final cookie = await _authService.getCookie();

    if (wdToken == null || cookie == null) {
      throw Exception('未找到认证信息，请重新登录');
    }

    final url = 'https://thor.weidian.com/pyxis/pyxis.mysteryBoxRecordList/1.0?'
        'param={"auth":"mysteryBoxCenter","flowAction":"mystery_box_list_V2","page":$page,"limit":20}'
        '&wdtoken=$wdToken'
        '&_=${underscoreParams['_'] ?? DateTime.now().millisecondsSinceEpoch}';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Referer': 'https://h5.weidian.com/',
          'Cookie': cookie,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> recordList = data['result']['boxRecordList'] ?? [];

        return recordList.map((item) => MysteryBoxRecord.fromJson(item)).toList();
      } else {
        throw Exception('请求失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取盲盒记录失败: $e');
    }
  }

  // 获取盲盒详细信息
  Future<Map<String, String>> fetchBoxInfo(String itemId, String orderId) async {
    final wdToken = await _authService.getWdToken();
    final underscoreParams = await _authService.getUnderscoreParams();
    final cookie = await _authService.getCookie();

    if (wdToken == null || cookie == null) {
      throw Exception('未找到认证信息');
    }

    final url = 'https://thor.weidian.com/pyxis/pyxis.mysteryBoxLotteryPageInfo/1.0?'
        'param={"auth":"mysteryBoxCenter","flowAction":"mystery_box_info_V2","itemId":"$itemId","orderId":"$orderId"}'
        '&wdtoken=$wdToken'
        '&_=${underscoreParams['_'] ?? DateTime.now().millisecondsSinceEpoch}';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Referer': 'https://h5.weidian.com/',
          'Cookie': cookie,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final boxInfo = data['result']['boxInfo'];
        return {
          'auth': boxInfo['auth'] ?? '',
          'name': boxInfo['name'] ?? '',
        };
      } else {
        throw Exception('请求失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取盲盒信息失败: $e');
    }
  }

  // 获取完整的奖品列表
  Future<List<String>> fetchCompleteItemList(String auth) async {
    final cookie = await _authService.getCookie();

    if (cookie == null) {
      throw Exception('未找到认证信息');
    }

    final url = 'https://thor.91ruyu.com/pyxis/pyxis.mysteryBoxActivityInfo/1.0?'
        'param={"auth":"$auth","flowAction":"mystery_box_main_page","showSold":true}'
        '&_=${DateTime.now().millisecondsSinceEpoch}';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Referer': 'https://h5.weidian.com/',
          'Cookie': cookie,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> prizeList = data['result']['prizeList'] ?? [];
        return prizeList.map((item) => item['name'].toString()).toList();
      } else {
        throw Exception('请求失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取完整奖品列表失败: $e');
    }
  }
}