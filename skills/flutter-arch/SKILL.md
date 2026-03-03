---
name: flutter-arch
description: "Flutter app architecture patterns using Services, Repositories, and ValueNotifiers. Covers stateless services with result types, repository pattern with ValueNotifier state management, result translation between layers, contract testing against real APIs, and performance (notifier granularity, cursor pagination, lifecycle disposal, isolate parsing). Use when building Flutter data layers, services, repositories, or state management."
---

# Flutter Architecture — Services, Repositories, ValueNotifiers

## Architecture Overview

```
Services (Stateless) → Repositories (ValueNotifiers) → UI (Listeners)
     ↓                      ↓                          ↓
ApiResult<T>         Single Source Truth        ValueListenableBuilder
```

## Services Layer

- **Stateless** — instantiate ad-hoc, no DI: `final service = ItemService();`
- **Always return `ApiResult<T>`**, never throw
- Include `static String getCodeText(int statusCode)` for message translation

```dart
class ItemService {
  final ApiClient _apiClient = ApiClient();
  
  Future<ApiResult<List<Item>>> getItems({List<String>? include}) async {
    return _apiClient.request('GET', '/api/v2/items', (json) => ...);
  }
  
  static String getCodeText(int statusCode) {
    switch (statusCode) {
      case 200: return 'Operation successful';
      case 404: return 'Resource not found';
      default: return 'Operation error';
    }
  }
}
```

## DTOs vs Entities

| Type | Path | Purpose |
|------|------|---------|
| **DTOs** | `services/dtos/` | Wire format from/to API |
| **Entities** | `data/entities/` | Domain objects with optional enrichments |

## Result Pattern

| Type | Used By | Purpose |
|------|---------|---------|
| `ApiResult<T>` | Services | HTTP wrapper with `statusCode` |
| `Result` | Repos/VMs | User-facing localized messages |

**Translation between layers:**
```dart
// In Repository/ViewModel
Future<Result> placeBid(BidDto dto) async {
  final apiResult = await _bidService.placeBid(dto);
  return Result(
    success: apiResult.success,
    message: BidService.getCodeText(apiResult.statusCode),
  );
}

// In UI
onPressed: () async {
  final result = await vm.placeBid();
  if (!result.success) ScaffoldMessenger.of(context).showSnackBar(...);
}
```

## Repository Pattern

**Responsibilities:** Aggregate services • Expose `ValueNotifier<T>` • Register in service locator

**Refresh Method Rules:**
1. Name: `refreshXNotifier()`
2. Set `notifier.value` exactly once
3. Return `Future<Result<void>>`
4. Build `Result.message` from `Service.getCodeText(statusCode)`
5. NO pass-through wrappers

```dart
Future<Result<void>> refreshItemsNotifier() async {
  final api = await _itemService.getItems();
  if (api.success && api.data != null) itemsNotifier.value = api.data;
  return Result(success: api.success, message: ItemService.getCodeText(api.statusCode));
}

// Initialization: reuse refresh methods
Future<Result<void>> initialize() async {
  final r1 = await refreshItemsNotifier();
  if (!r1.success) return r1;
  return Result(success: true, message: '');
}
```

## UI State Management

```dart
ValueListenableBuilder<List<Item>>(
  valueListenable: locator<ItemRepository>().itemsNotifier,
  builder: (_, items, __) => items.isEmpty
    ? const EmptyState()
    : ListView.builder(itemBuilder: (_, i) => ItemCard(item: items[i])),
)
```

- Use standard `build(BuildContext context)`
- Inline small UI pieces
- Extract to `_buildX()` or private widgets when needed

## Real-time Events

```
Server Event → EventViewModel → Feature ViewModel → Repository → UI
```

- NO API calls for data already in event payload (unless eventual consistency)
- Repository updates notifier → UI auto-refreshes via ValueListenableBuilder

## Contract Testing

**Purpose:** Validate Services/DTOs/Entities against a REAL API to prevent runtime parsing failures.

**4-Phase Pattern:**
```dart
Future<void> runContract(TestContext ctx) async {
  try {
    // SETUP - Create prerequisites
    final user = await _createUser(ctx);
    
    // EXERCISE - Hit real API
    final resp = await ctx.httpClient.post(
      Uri.parse('${ctx.apiUrl}/api/v2/resources'),
      headers: ctx.authHeaders(user),
      body: jsonEncode({...}),
    );
    
    // ASSERTION - Parse with Entity.fromJson()
    final resource = MyEntity.fromJson(jsonDecode(resp.body));
    if (resource.id != expectedId) throw Exception('mismatch');
    
    // TEARDOWN - Cleanup (LIFO)
    ctx.registerCleanup(() async { /* delete resource */ });
  } finally {
    await ctx.runCleanup();
  }
}
```

**Critical Rules:**
- ❌ Never import Flutter deps in contract tests (causes `dart:ui` error)
- ❌ Never mock API responses (defeats purpose)
- ❌ Never test business logic (test DTO parsing only)
- ❌ Never hardcode test data (use unique generators)
- ❌ Never forget cleanup

## Performance

### 1. Notifier Granularity

Split state into **separate ValueNotifiers** so UI rebuilds only what changed. One fat notifier rebuilds every listener.

```dart
// ❌ One notifier = every listener rebuilds on any change
final showStateNotifier = ValueNotifier<ShowState>(...); // title, items, bids, chat

// ✅ Granular notifiers = localized rebuilds
final purchasesNotifier = ValueNotifier<List<Purchase>>([]);
final failedPurchasesCountNotifier = ValueNotifier<int>(0);
final isLoadingNotifier = ValueNotifier<bool>(false);
```

**Rules:**
- One notifier per independently-changing piece of state
- Loading flags get their own notifier (`isLoadingNotifier`, `isLoadingGroupsNotifier`)
- Derived/grouped data gets its own notifier (`purchasesByShowNotifier`, `purchasesBySellerNotifier`)
- Counts that update independently get their own notifier (`failedPurchasesCountNotifier`)

### 2. Cursor-Based Pagination

Services accept optional `cursor` and `limit`. Repositories track pagination state privately and expose a `loadMoreX()` method that **appends** to the existing notifier value.

**Service:**
```dart
Future<ApiResult<PaginatedResult<Item>>> getItems({String? cursor, int? limit}) async {
  return _apiClient.request('GET', '/api/v2/items',
    (json) => PaginatedResult.fromJson(json),
    queryParams: {'cursor': cursor, 'limit': limit?.toString()},
  );
}
```

**Repository:**
```dart
String? _nextCursor;
bool _hasMore = false;

void _storePaginationInfo(PageInfo pageInfo) {
  _nextCursor = pageInfo.nextCursor;
  _hasMore = pageInfo.hasMore;
}

bool get hasMoreItems => _hasMore;

Future<void> loadMoreItems() async {
  if (!_hasMore || _nextCursor == null) return;

  final result = await _itemService.getItems(cursor: _nextCursor, limit: 20);
  if (result.success && result.data != null) {
    final current = List<Item>.from(itemsNotifier.value);
    current.addAll(result.data!.items);
    itemsNotifier.value = current;
    _storePaginationInfo(result.data!.pageInfo);
  }
}
```

**Rules:**
- `refreshXNotifier()` resets pagination (`_nextCursor = null`, `_hasMore = false`)
- `loadMoreX()` guards with `if (!_hasMore || _nextCursor == null) return`
- Always copy list before appending: `List<T>.from(notifier.value)..addAll(new)`
- Store `next_cursor` and `has_more` from API `meta` field via `PageInfo`

### 3. Lifecycle & Disposal

Every repository and view model with notifiers, listeners, subscriptions, or timers **must** implement `dispose()`.

```dart
void dispose() {
  // 1. Remove cross-repository listeners
  _userRepository.authStateNotifier.removeListener(_handleAuthStateChange);

  // 2. Cancel subscriptions and timers
  _pusherSubscription?.cancel();
  _countdownTimer?.cancel();

  // 3. Dispose all ValueNotifiers
  purchasesNotifier.dispose();
  isLoadingNotifier.dispose();
  failedPurchasesCountNotifier.dispose();
}
```

**Rules:**
- Remove listeners from other repositories' notifiers FIRST
- Cancel stream subscriptions and timers
- Dispose owned ValueNotifiers LAST
- Unsubscribe Pusher channels in view model dispose
- Pair every `addListener()` with `removeListener()` in dispose

### 4. Heavy Parsing on Isolates

JSON parsing blocks the UI thread. For large payloads (100+ items, deeply nested entities), move parsing to an isolate using `compute()`.

```dart
// In Service — large payload parsing
Future<ApiResult<List<Item>>> getShowItems(String showId) async {
  final response = await _apiClient.rawRequest('GET', '/api/v2/shows/$showId/items');
  if (!response.success) return ApiResult(success: false, statusCode: response.statusCode);

  final items = await compute(_parseItems, response.body);
  return ApiResult(success: true, data: items, statusCode: response.statusCode);
}

// Top-level function (required by compute)
List<Item> _parseItems(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  return (json['data'] as List).map((e) => Item.fromJson(e)).toList();
}
```

**Rules:**
- Only use for payloads with 100+ items or deeply nested structures
- The parsing function must be **top-level or static** (not a closure)
- Don't use for small responses — the isolate overhead is worse than inline parsing
- Profile first with DevTools before adding isolate complexity

## Screen Prototyper Pattern

Preview real screens on a real simulator with fake data — no API, no services, no mocks infrastructure.

**Two changes per screen:**

### 1. ViewModel: Add `.preview()` constructor + `_isPreview` guard

```dart
class ProfileViewModel {
  late final UserService _userService;
  late final ShowService _showService;
  bool _isPreview = false;

  // Production constructor
  ProfileViewModel() {
    _userService = UserService();
    _showService = ShowService();
  }

  // Preview — populate notifiers with fake data, no API
  ProfileViewModel.preview() {
    _isPreview = true;
    user.value = const User(businessId: 'preview-001', username: 'carlos_preview', ...);
    isLoadingUser.value = false;
    followerCount.value = 1234;
  }

  // Notifiers
  final ValueNotifier<User?> user = ValueNotifier(null);
  final ValueNotifier<bool> isLoadingUser = ValueNotifier(false);
  final ValueNotifier<int> followerCount = ValueNotifier(0);

  void init(String userBusinessId) {
    if (_isPreview) return; // ← guard
    // ... normal API calls
  }

  Future<Result> refreshUserNotifier(String id) async {
    if (_isPreview) return Result.success('');
    // ... normal API calls
  }
}
```

**Key rules:**
- Make service fields `late final` so `.preview()` skips instantiation
- Add `if (_isPreview) return` at the top of every public method that hits the API
- Populate ALL notifiers in `.preview()` (especially loading flags → `false`)

### 2. Screen: Accept optional `viewModel` param

```dart
class ProfileView extends StatefulWidget {
  final String userBusinessId;
  final ProfileViewModel? viewModel; // ← add this

  const ProfileView({super.key, required this.userBusinessId, this.viewModel});
}

class _ProfileViewState extends State<ProfileView> {
  late final ProfileViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? ProfileViewModel(); // ← fallback
    _viewModel.init(widget.userBusinessId);
  }
}
```

### 3. Navigate with preview VM

```dart
// From Screen Prototyper or anywhere
Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => ProfileView(
    userBusinessId: 'preview-001',
    viewModel: ProfileViewModel.preview(),
  ),
));
```

**Access:** Account tab → Screen Prototyper (admin-only). Catalog screen lists available previews.

**Adding a new screen:** Add `.preview()` + `_isPreview` guard to VM, add optional `viewModel` param to screen, add entry in Screen Prototyper catalog.

## Logging

- NO happy-path logs
- Log failures with identifiers and status codes
- Levels: `warning` (recoverable), `error`/`critical` (non-recoverable)
