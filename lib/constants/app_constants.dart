class AppConstants {
  // API URLs
  static const String loginUrl = 'https://sso.weidian.com/login/index.php';
  static const String mysteryBoxUrl = 'https://h5.weidian.com/m/mystery-box/list.html#/';
  static const String mysteryBoxRecordApi = 'https://thor.weidian.com/pyxis/pyxis.mysteryBoxRecordList/1.0';
  static const String mysteryBoxInfoApi = 'https://thor.weidian.com/pyxis/pyxis.mysteryBoxLotteryPageInfo/1.0';
  static const String mysteryBoxActivityApi = 'https://thor.91ruyu.com/pyxis/pyxis.mysteryBoxActivityInfo/1.0';
  static const String logCollectorApi = 'https://logtake.weidian.com/h5collector/webcollect/3.0';
  static const String skittlesShareApi = 'https://thor.weidian.com/skittles/share.getConfig/';

  // Headers
  static const String refererHeader = 'https://h5.weidian.com/';
  static const String userAgentHeader = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';

  // Local Storage Keys
  static const String cookieKey = 'auth_cookie';
  static const String wdTokenKey = 'wd_token';
  static const String underscoreParamsKey = 'underscore_params';
  static const String loginStatusKey = 'login_status';

  // App Configuration
  static const int requestTimeout = 30; // seconds
  static const int pageSize = 20;
  static const Duration cacheExpiration = Duration(minutes: 30);

  // Messages
  static const String loginRequiredMessage = '请先登录';
  static const String tokenRequiredMessage = '请先打开盲盒界面获取必要信息';
  static const String networkErrorMessage = '网络请求失败，请检查网络连接';
  static const String dataErrorMessage = '数据解析失败';

  // App Info
  static const String appName = '盲盒工具';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Flutter版盲盒记录查询工具';
}