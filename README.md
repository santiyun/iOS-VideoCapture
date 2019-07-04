### 视频自采集demo

#### 准备工作
1. 在三体云官网SDK下载页 [http://3ttech.cn/index.php?menu=53](http://3ttech.cn/index.php?menu=53) 下载对应平台的 连麦直播SDK。(Pod正式使用版是2.3.0及以上)
2. 登录三体云官网 [http://dashboard.3ttech.cn/index/login](http://dashboard.3ttech.cn/index/login) 注册体验账号，进入控制台新建自己的应用并获取APPID

####注意事项

1. 在**TTTRtcManager**里填写AppID
2. 自采集必须调用接口**setExternalVideoSource**
3. demo只简单做了单主播直播演示
4. demo中SDK是演示SDK

####声明
SDK有**localVideoFrameCaptured**回调给用户视频帧供用户做美颜等操作



