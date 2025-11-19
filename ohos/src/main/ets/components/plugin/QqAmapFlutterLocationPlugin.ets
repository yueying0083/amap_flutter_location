import {
  AMapLocationManagerImpl,
  AMapLocationOption,
  AMapLocationReGeocodeLanguage,
  AMapLocationType,
  IAMapLocationListener,
} from '@amap/amap_lbs_location';
import {
  Any,
  EventChannel,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  ToolUtils,
} from '@ohos/flutter_ohos';
import { EventSink, StreamHandler } from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel';
import { abilityAccessCtrl, bundleManager, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { CommonConstants } from './CommonConstants';
import { BusinessError } from '@ohos.base';
import { AMapPrivacyShowStatus, AMapPrivacyInfoStatus, AMapPrivacyAgreeStatus } from '@amap/amap_lbs_common';
import geoLocationManager from '@ohos.geoLocationManager';

/** AmapFlutterLocationPlugin **/
export default class AmapFlutterLocationPlugin implements FlutterPlugin, MethodCallHandler, StreamHandler {
  private channel: MethodChannel | null = null;
  private eventChannel: EventChannel | null = null;
  private eventSink?: EventSink
  private CHANNEL_METHOD_LOCATION: string = "amap_flutter_location"
  private CHANNEL_STREAM_LOCATION: string = "amap_flutter_location_stream"
  response: string = ''
  private context = getContext(this);
  locationManger?: AMapLocationManagerImpl;
  options: AMapLocationOption = {}
  mPluginKey: string = ''
  private TAG = "AmapFlutterLocationPlugin"
  private isNeedAddress: boolean = false;

  constructor() {
  }

  onListen(args: Any, events: EventSink): void {
    console.info(this.TAG + ' eventChannel onListen: events is ' + events)
    this.eventSink = events;
    console.info(this.TAG + ' eventChannel onListen2: eventSink is ' + this.eventSink)
  }

  onCancel(args: Any): void {
    console.info(this.TAG + ' setStreamHandler onCancel ')
    this.eventSink = undefined;
  }

  getUniqueClassName(): string {
    return "AmapFlutterLocationPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    console.info(this.TAG + ' onLocationChanged  onAttachedToEngine  ')

    this.channel = new MethodChannel(binding.getBinaryMessenger(), this.CHANNEL_METHOD_LOCATION);
    this.channel.setMethodCallHandler(this)

    this.eventChannel = new EventChannel(binding.getBinaryMessenger(), this.CHANNEL_STREAM_LOCATION);
    this.eventChannel.setStreamHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case "getPlatformVersion":
        result.success("OpenHarmony ^ ^ ")
        break
      case "updatePrivacyStatement":
        this.updatePrivacyStatement(call.args);
        break
      case "setApiKey":
        this.setApiKey(call.args)
        break
      case "setLocationOption":
        this.setLocationOption(call.args)
        break
      case "startLocation":
        this.startLocation(call.args)
        break
      case "stopLocation":
        this.stopLocation(call.args)
        break
      case "destroy":
        this.destroy(call.args)
        break
      default:
        result.notImplemented()
    }
  }

  updatePrivacyStatement(map: Any) {
    AMapLocationManagerImpl.updatePrivacyShow(AMapPrivacyShowStatus.DidShow, AMapPrivacyInfoStatus.DidContain,
      getContext(this))
    AMapLocationManagerImpl.updatePrivacyAgree(AMapPrivacyAgreeStatus.DidAgree, getContext(this))
  }

  setApiKey(map: Any) {
    try {
      let apiKey: string = this.argumentParse('ohos', map)
      console.info(this.TAG + ' setApiKey: ' + apiKey)
      AMapLocationManagerImpl.setApiKey(apiKey)
    } catch (e) {
      console.info(this.TAG + ' setApiKey error: ' + e)
    }
  }

  setLocationOption(map: Any) {
    console.info(this.TAG + ' setLocationOption  map: ' + JSON.stringify(map))
    this.mPluginKey = this.argumentParse('pluginKey', map)

    console.info(this.TAG + ' setLocationOption  pluginKey: ' + this.mPluginKey)

    AMapLocationManagerImpl.updatePrivacyShow(AMapPrivacyShowStatus.DidShow, AMapPrivacyInfoStatus.DidContain,
      getContext(this))
    AMapLocationManagerImpl.updatePrivacyAgree(AMapPrivacyAgreeStatus.DidAgree, getContext(this))
    if (this.locationManger === undefined) {
      this.locationManger = new AMapLocationManagerImpl(this.context);
    }

    this.isNeedAddress = this.argumentParse('needAddress', map)

    this.options = {
      priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
      scenario: geoLocationManager.LocationRequestScenario.UNSET,
      maxAccuracy: 0,
      singleLocationTimeout: 3000,
      allowsBackgroundLocationUpdates: false,
      locatingWithReGeocode: this.isNeedAddress,
      reGeocodeLanguage: AMapLocationReGeocodeLanguage.Chinese,
      isOffset: true
    }
    if (map.has("locationInterval")) {
      this.options.timeInterval = map["locationInterval"]
    }

    if (map.has("locationMode")) {

    }
    if (map.has("geoLanguage")) {

    }
    if (map.has("onceLocation")) {

    }
    this.options.reGeocodeLanguage = AMapLocationReGeocodeLanguage.Chinese
    this.locationManger?.setLocationOption(AMapLocationType.Single, this.options)
  }

  startLocation(map: Any) {
    console.info(this.TAG + ' onLocationChanged  开始定位')
    this.checkPermissions();
    let listener: IAMapLocationListener = {
      onLocationChanged: (location) => {
        console.info(this.TAG + ' onLocationChanged  ' + JSON.stringify(location))

        this.response =
          " 经度：" + location.longitude + "\n"
            + " 纬度：" + location.latitude + "\n"
            + " 海拔：" + location.altitude + "\n"
            + " 精度：" + location.accuracy + "\n"
            + " 速度：" + location.speed + "\n"
            + " UTC时间：" + location.timeStamp + "\n"
            + " 方向：" + location.direction + "\n"
            + " 自启动以来时间：" + location.timeSinceBoot + "\n"
            + " 附加信息：" + location.additions + "\n"
            + " 附加信息size：" + location.additionSize + "\n"

        console.info(this.TAG + ' onLocationChanged  eventSink is ' + this.eventSink)
        console.info(this.TAG + ' onLocationChanged  ' + this.response)
        try {
          let m = new Map<string, Object | string | undefined>()
          let reGeo = location.reGeo
          m.set("locationTime", this.timestampToFullDate(location.timeStamp));
          // m.set("locationType", location.getLocationType());
          m.set('latitude', location.latitude ?? "")
          m.set('longitude', location.longitude ?? "")
          m.set("accuracy", location.accuracy);
          m.set("altitude", location.altitude);
          // m.set("bearing", location.getBearing());
          m.set("speed", location.speed);
          m.set("country", reGeo?.country ?? "");
          m.set("province", reGeo?.province ?? "");
          m.set("city", reGeo?.city ?? "");
          m.set("district", reGeo?.district ?? "");
          m.set("street", reGeo?.street ?? "");
          m.set("streetNumber", reGeo?.number ?? "");
          m.set("cityCode", reGeo?.citycode ?? "");
          m.set("adCode", reGeo?.adcode ?? "");
          m.set("address", reGeo?.address ?? "");
          m.set("description", reGeo?.desc ?? "");
          m.set("pluginKey", this.mPluginKey)
          this.eventSink?.success(m)
        } catch (e) {
          console.info(this.TAG + ' error1  ' + JSON.stringify(e))
          let m = new Map<string, Object | string | undefined>()
          m.set('errorCode', -1)
          m.set('errorInfo', JSON.stringify(e))
          m.set("pluginKey", this.mPluginKey)
          this.eventSink?.success(m)
        }
      }, onLocationError: (error) => {
        console.info(this.TAG + ' error  ' + JSON.stringify(error))
        let m = new Map<string, Object | string | undefined>()
        m.set('errorCode', error.errorCode)
        m.set('errorInfo', error.errorMsg)
        m.set("pluginKey", this.mPluginKey)
        this.eventSink?.success(m)
      }
    };
    if (this.locationManger === undefined) {
      this.locationManger = new AMapLocationManagerImpl(this.context);
    }
    this.locationManger?.setLocationListener(AMapLocationType.Single, listener)
    this.locationManger?.setLocationOption(AMapLocationType.Single, this.options)
    this.locationManger?.requestSingleLocation()
  }

  stopLocation(map: Any) {
    if (this.locationManger === undefined) {
      this.locationManger = new AMapLocationManagerImpl(this.context);
    }
    this.locationManger?.stopUpdatingLocation()
  }

  destroy(map: Any) {

  }

  async checkPermissions(): Promise<void> {
    console.info(this.TAG + ' onLocationChanged  checkPermissions')
    const permissions: Array<Permissions> = ['ohos.permission.LOCATION'];
    let grantStatus: abilityAccessCtrl.GrantStatus = await this.checkAccessToken(permissions[0]);

    if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
      // 已经授权，可以继续访问目标操作
      console.info(this.TAG + ' onLocationChanged  已经授权，可以继续访问目标操作')

    } else {

      const permissions: Array<Permissions> = ['ohos.permission.LOCATION'];

      this.reqPermissionsFromUser(CommonConstants.REQUEST_PERMISSIONS);
    }
  }

  async checkAccessToken(permission: Permissions): Promise<abilityAccessCtrl.GrantStatus> {
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    let grantStatus: abilityAccessCtrl.GrantStatus = abilityAccessCtrl.GrantStatus.PERMISSION_DENIED;

    // 获取应用程序的accessTokenID
    let tokenId: number = 0;
    try {
      let bundleInfo: bundleManager.BundleInfo =
        await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      let appInfo: bundleManager.ApplicationInfo = bundleInfo.appInfo;
      tokenId = appInfo.accessTokenId;
      console.info(this.TAG + ` tokenId is ${tokenId}`);
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      console.info(this.TAG + ` Failed to get bundle info for self. Code is ${err.code}, message is ${err.message}`);
    }

    // 校验应用是否被授予权限
    try {
      grantStatus = await atManager.checkAccessToken(tokenId, permission);
      console.info(this.TAG + ` grantStatus ${grantStatus}`);

    } catch (error) {
      let err: BusinessError = error as BusinessError;
      console.info(this.TAG + ` Failed to check access token. Code is ${err.code}, message is ${err.message}`);
    }

    return grantStatus;
  }

  reqPermissionsFromUser(permissions: Array<Permissions>): void {
    console.info(this.TAG + ` reqPermissionsFromUser`);
    let context: Context = getContext(this) as common.UIAbilityContext;
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    // requestPermissionsFromUser会判断权限的授权状态来决定是否唤起弹窗
    atManager.requestPermissionsFromUser(context, permissions).then((data: PermissionRequestResult) => {
      let grantStatus: Array<number> = data.authResults;
      console.info(this.TAG + ` reqPermissionsFromUser result grantStatus:${grantStatus}`);
      let length: number = grantStatus.length;
      for (let i = 0; i < length; i++) {
        if (grantStatus[i] === 0) {
          // 用户授权，可以继续访问目标操作
        } else {
          // 用户拒绝授权，提示用户必须授权才能访问当前页面的功能，并引导用户到系统设置中打开相应的权限
          // this.openPermissionsInSystemSettings()
          return;
        }
      }
      // 授权成功
    }).catch((err: BusinessError) => {

      console.info(this.TAG +
        ` Failed to request permissions from user. Code is ${err.code}, message is ${err.message}`);
    })
  }

  requestPermissions(): void {
    let atManager = abilityAccessCtrl.createAtManager();
    try {
      atManager.requestPermissionsFromUser(this.context, CommonConstants.REQUEST_PERMISSIONS).then((data) => {
        console.info('requestPermissionsFromUser')

        if (data.authResults[0] !== 0 || data.authResults[1] !== 0) {
          console.info('requestPermissionsFromUser return')
          return;
        }
        const that = this;

      }).catch((err: Error) => {
        console.info('requestPermissionsFromUser err' + JSON.stringify(err))
      })
    } catch (err) {
      console.info('requestPermissionsFromUser err' + JSON.stringify(err));
    }
  }

  argumentParse(key: string, args: Any): Any {
    if (args == null) {
      return null;
    } else if (args instanceof Map) {
      return (args as Map<Any, Any>).get(key);
    } else if (ToolUtils.isObj(args)) {
      return args[key]
    } else {
      throw new Error("ClassCastException");
    }
  }

  timestampToFullDate(timestamp: number): string {
    const date = new Date(timestamp);

    const year = date.getFullYear();
    const month = ("0" + (date.getMonth() + 1)).slice(-2); // Months are zero-based
    const day = ("0" + date.getDate()).slice(-2);
    const hours = ("0" + date.getHours()).slice(-2);
    const minutes = ("0" + date.getMinutes()).slice(-2);
    const seconds = ("0" + date.getSeconds()).slice(-2);

    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
  }
}





