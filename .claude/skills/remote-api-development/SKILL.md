---
name: remote-api-development
description: Use when adding, modifying, or refactoring any remote/HTTP API call in this Flutter project. Invoke for new endpoints, data sources, repositories, providers, or when removing hardcoded URLs and inline response parsing.
license: MIT
metadata:
  version: "1.0.0"
  domain: networking
  triggers: API, endpoint, remote call, DioClient, data source, repository, provider, userInfo, ApiEndpoints
  role: specialist
  scope: implementation
  output-format: code
  related-skills: flutter-expert, flutter-tester
---

# Remote API Development Standards

本 skill 定义 fly-narwhal-flutter 项目远程接口调用的统一开发规范。新增或修改任何 HTTP 接口调用时必须遵循。

## When to Use This Skill

- 新增一个后端接口调用
- 重构内联在 Provider/Widget 中的硬编码 URL 或内联解析逻辑
- 新增/修改 RemoteDataSource、Repository、Provider
- 排查“同一个接口存在多处重复实现”的问题

## 分层架构（必须遵守）

请求自上而下分层，禁止跨层或在上层内联实现下层职责：

```
UI (Widget / Screen)
  └─ Provider (FutureProvider / Notifier)      // 仅编排，不写 URL/解析
       └─ Repository (可选，做实体映射 / 多源聚合)
            └─ RemoteDataSource                 // 唯一发起请求 + 解析响应的地方
                 └─ DioClient (core/network)    // 统一网络层
                      └─ ApiEndpoints           // 唯一的 URL 常量来源
```

## 核心规则

### 规则 1：URL 必须集中在 ApiEndpoints

- 所有接口路径只能定义在 `lib/core/constants/app_constants.dart` 的 `ApiEndpoints` 类中。
- 严禁在 DataSource/Provider/Widget 中出现硬编码字符串路径（如 `'/v/api/v1/user/info'`）。
- 带路径参数的接口用静态方法，如 `static String itemByGuid(String guid) => '$itemPrefix/$guid';`。

```dart
// app_constants.dart
class ApiEndpoints {
  const ApiEndpoints._();
  static const String userInfo = '/v/api/v1/user/info';
}
```

### 规则 2：请求与解析必须封装在 RemoteDataSource

- 所有 `_dioClient.get/post/...` 调用只能出现在 `lib/data/datasources/remote/` 下的 DataSource 中。
- 用 `converter` 回调解析响应，统一通过 `FnBaseResponse<T>` 处理。
- 业务错误码判断使用 `ResponseCodes.success`（即 0），失败时 `throw Exception(baseResponse.msg)`。
- 返回类型统一为 `ApiResult<T>`，禁止直接返回原始 `Response`。
- DataSource 依赖 **core 版** `DioClient`（`lib/core/network/dio_client.dart`），不要用 legacy 版（`lib/data/network/dio_client.dart`）。

```dart
class UserRemoteDataSource {
  final DioClient _dioClient;
  UserRemoteDataSource(this._dioClient);

  // Get current user info
  Future<ApiResult<UserInfo>> getUserInfo() async {
    return _dioClient.get<UserInfo>(
      ApiEndpoints.userInfo,
      converter: _parseUserInfoResponse,
    );
  }

  // Parse FnBaseResponse and unwrap data
  UserInfo _parseUserInfoResponse(dynamic data) {
    final baseResponse = FnBaseResponse<UserInfo>.fromJson(
      data,
      (json) => UserInfo.fromJson(
        json is Map<String, dynamic>
            ? json
            : Map<String, dynamic>.from(json as Map),
      ),
    );
    if (baseResponse.code != ResponseCodes.success) {
      throw Exception(baseResponse.msg);
    }
    return baseResponse.data ?? UserInfo(guid: '', username: '', isAdmin: 0);
  }
}
```

### 规则 3：Provider 只做编排，不写请求细节

- Provider 中禁止出现 URL、`FnBaseResponse` 解析、错误码判断。
- 先定义 `xxxRemoteDataSourceProvider`，再让业务 Provider 委托它。
- 用 `ApiResult.getOrThrow()` 把失败转为异常，交给 `AsyncValue.error` 处理；对外类型保持稳定（如 `FutureProvider<UserInfo>`）。

```dart
// DataSource provider —— 用 core 版 DioClient 构造
final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>((ref) {
  final prefsManager = ref.watch(preferencesManagerProvider);
  final dioClient = core_network.DioClient.withCallbacks(
    getToken: () => prefsManager.getToken() ?? '',
    getCookie: () => prefsManager.getCookie() ?? '',
    getAuthCode: () => prefsManager.getAuthCode() ?? '',
    getBaseUrl: () => prefsManager.getBaseUrl() ?? '',
  );
  return UserRemoteDataSource(dioClient);
});

// Business provider —— 只编排，不写请求细节
final userInfoProvider = FutureProvider<UserInfo>((ref) async {
  final dataSource = ref.read(userRemoteDataSourceProvider);
  final result = await dataSource.getUserInfo();
  return result.getOrThrow();
});
```

### 规则 4：Repository 层（按需）

- 当需要做 model→entity 映射或聚合多个数据源时，新增 Repository（`lib/data/repositories/`）实现 `lib/domain/repositories/` 接口。
- Repository 通过 `ApiResult.map` 转换数据，保持 `ApiResult<T>` 链路。

```dart
@override
Future<ApiResult<UserEntity>> getUserInfo() async {
  final result = await _remoteDataSource.getUserInfo();
  return result.map((data) => UserMapper.toEntity(data));
}
```

## 反模式（禁止）

- ❌ 在 Provider/Widget 里写 `dioClient.dio.get('/v/api/v1/...')` 硬编码 URL。
- ❌ 在 Provider/Widget 里内联 `FnBaseResponse.fromJson` 解析。
- ❌ 同一接口在多处重复实现请求与解析逻辑。
- ❌ DataSource 使用 legacy `DioClient`（`lib/data/network/dio_client.dart`）。
- ❌ 直接返回 `Response`，绕过 `ApiResult`。

## 新增接口操作清单

1. 在 `ApiEndpoints` 添加路径常量（或路径参数方法）。
2. 在对应 `RemoteDataSource` 添加方法，用 `converter` 解析，返回 `ApiResult<T>`。
3. 需要实体映射时在 Repository 添加方法并 `map`。
4. 在 `providers.dart` 添加/复用 `xxxRemoteDataSourceProvider`，业务 Provider 委托调用。
5. 验证：运行 `flutter analyze`，确认无 unused/undefined；涉及 UI 时按 flutter-tester 规范补充测试或 mcp UI 验证。

## 参考实现

- URL 常量：`lib/core/constants/app_constants.dart`
- DataSource：`lib/data/datasources/remote/user_remote_data_source.dart`
- 网络层：`lib/core/network/dio_client.dart`、`lib/core/network/api_result.dart`
- Provider：`lib/providers/providers.dart`（`userInfoProvider`、`userRemoteDataSourceProvider`）
