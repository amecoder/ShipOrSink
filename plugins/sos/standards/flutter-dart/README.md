# Flutter / Dart 품질 체계

## 포함 도구

| 도구 | 역할 | Python 대응 | TypeScript 대응 |
|------|------|-------------|-----------------|
| **dart analyze** | 정적 분석 (very_good_analysis 기반) | ruff | ESLint |
| **dart format** | 코드 포매팅 | ruff format | Prettier |
| **flutter test** | 단위/위젯/통합 테스트 + 커버리지 (>= 80%) | pytest-cov | Vitest |
| **custom_lint** | 프로젝트별 커스텀 린트 규칙 | ruff 커스텀 | ESLint 플러그인 |
| **riverpod_lint** | Riverpod 전용 린트 (선택) | - | - |
| **pre-commit** | 커밋 전 자동 검사 | pre-commit (동일) | Husky |
| **detect-secrets** | 시크릿 탐지 | detect-secrets (동일) | detect-secrets (동일) |

## 자동 적용

```bash
cd /path/to/my-flutter-project
bash ~/.dev-standards/flutter-dart/bootstrap.sh
```

## 수동 적용 (단계별)

### 1. analysis_options.yaml 복사

```bash
cp ~/.dev-standards/flutter-dart/templates/analysis_options.yaml .
```

`pubspec.yaml`에 very_good_analysis 추가:
```yaml
dev_dependencies:
  very_good_analysis: ^7.0.0
  custom_lint: ^0.7.0
```

### 2. pre-commit 설정 복사

```bash
cp ~/.dev-standards/flutter-dart/templates/.pre-commit-config.yaml .
pip install pre-commit detect-secrets
pre-commit install
```

### 3. Claude Code 훅 설정

```bash
bash ~/.dev-standards/apply.sh --only hooks --target .     # 공통 Claude Code 훅 + .githooks/pre-push
bash ~/.dev-standards/apply.sh --only settings --target .  # 팀 공유 .claude/settings.json (있으면 병합)
```

> `permissions.allow` 목록을 프로젝트에 맞게 수정하세요.

---

## 포함 템플릿

| 파일 | 설명 |
|------|------|
| `analysis_options.yaml` | very_good_analysis 기반 strict 린트 규칙 |
| `.pre-commit-config.yaml` | dart format + dart analyze + flutter test + detect-secrets |

---

## 주요 명령어

```bash
dart format .                          # 포매팅
dart format --set-exit-if-changed .    # 포매팅 검사 (CI)
dart analyze --fatal-infos             # 정적 분석
dart fix --apply                       # 자동 수정
flutter test                           # 테스트 실행
flutter test --coverage                # 커버리지 리포트
flutter test --update-goldens          # 골든 테스트 업데이트
genhtml coverage/lcov.info -o coverage/html  # HTML 리포트
```

---

## 주요 위반 패턴 및 수정법

### 1. `avoid_print` — print() 사용 금지

```dart
// WRONG
void fetchData() {
  print('fetching data...');
}

// RIGHT: debugPrint (개발용) 또는 logger (프로덕션)
import 'dart:developer';

void fetchData() {
  log('fetching data...');
}

// RIGHT: logging 패키지 사용
import 'package:logging/logging.dart';

final _logger = Logger('DataService');

void fetchData() {
  _logger.info('fetching data...');
}
```

### 2. `prefer_const_constructors` — const 생성자 미사용

```dart
// WRONG
Widget build(BuildContext context) {
  return Container(
    child: Text('Hello'),
  );
}

// RIGHT: const 사용으로 리빌드 최적화
Widget build(BuildContext context) {
  return const SizedBox(
    child: Text('Hello'),
  );
}
```

### 3. `prefer_final_locals` — 불변 지역 변수

```dart
// WRONG
void processOrder(Order order) {
  var total = order.items.fold(0.0, (sum, item) => sum + item.price);
  var discount = calculateDiscount(total);
  return total - discount;
}

// RIGHT
void processOrder(Order order) {
  final total = order.items.fold(0.0, (sum, item) => sum + item.price);
  final discount = calculateDiscount(total);
  return total - discount;
}
```

### 4. `avoid_dynamic_calls` — dynamic 타입 호출

```dart
// WRONG: dynamic 타입으로 타입 안전성 없음
void process(dynamic data) {
  final name = data.name;  // runtime error 가능
}

// RIGHT: 구체적 타입 사용
void process(UserData data) {
  final name = data.name;  // 컴파일 타임 검사
}

// RIGHT: Object + 타입 체크
void process(Object data) {
  if (data is UserData) {
    final name = data.name;
  }
}
```

### 5. `require_trailing_commas` — 후행 쉼표 누락

```dart
// WRONG: 후행 쉼표 없음 (dart format이 한 줄로 합침)
Widget build(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Column(
      children: [
        Text('Title'),
        Text('Subtitle')  // <-- missing comma
      ]
    )
  );
}

// RIGHT: 후행 쉼표로 멀티라인 유지
Widget build(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Column(
      children: [
        const Text('Title'),
        const Text('Subtitle'),  // <-- trailing comma
      ],
    ),
  );
}
```

### 6. `type_annotate_public_apis` — public API 타입 주석 누락

```dart
// WRONG: 반환 타입 없음
fetchUser(String id) async {
  return await repository.getUser(id);
}

// RIGHT: 반환 타입 + 매개변수 타입 명시
Future<User> fetchUser(String id) async {
  return await repository.getUser(id);
}
```

### 7. `avoid_unnecessary_containers` — 불필요한 Container

```dart
// WRONG: 속성 없는 Container는 불필요
Widget build(BuildContext context) {
  return Container(
    child: Text('Hello'),
  );
}

// RIGHT: Container 대신 의미 있는 위젯 사용
Widget build(BuildContext context) {
  return const Text('Hello');
}

// RIGHT: 패딩이 필요하면 Padding 사용
Widget build(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(16.0),
    child: Text('Hello'),
  );
}
```

---

## Widget 설계 규칙

### 위젯 추출 — 메서드 vs 클래스

```dart
// WRONG: 메서드로 위젯 추출 (리빌드 최적화 불가)
class ProfilePage extends StatelessWidget {
  Widget _buildHeader() {
    return const Text('Header');
  }

  Widget _buildBody() {
    return const Text('Body');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildBody(),
      ],
    );
  }
}

// RIGHT: 별도 위젯 클래스로 추출 (const 가능, 독립 리빌드)
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ProfileHeader(),
        ProfileBody(),
      ],
    );
  }
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('Header');
  }
}
```

### const 위젯 활용

```dart
// WRONG: 매번 새 인스턴스 생성
ListView.builder(
  itemBuilder: (context, index) {
    return ListTile(
      leading: Icon(Icons.person),  // not const
      title: Text(users[index].name),
    );
  },
);

// RIGHT: 정적 부분은 const로 분리
ListView.builder(
  itemBuilder: (context, index) {
    return ListTile(
      leading: const Icon(Icons.person),  // const
      title: Text(users[index].name),
    );
  },
);
```

---

## 상태 관리 패턴

### Riverpod (권장)

```dart
// Provider 정의 (@riverpod 어노테이션)
@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  FutureOr<User> build(String userId) async {
    return ref.watch(userRepositoryProvider).getUser(userId);
  }

  Future<void> updateName(String name) async {
    final user = await future;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(userRepositoryProvider).updateUser(
        user.copyWith(name: name),
      ),
    );
  }
}

// Widget에서 사용
class UserProfile extends ConsumerWidget {
  const UserProfile({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch: 반응형 (값 변경 시 리빌드)
    final userAsync = ref.watch(userNotifierProvider(userId));

    return userAsync.when(
      data: (user) => Text(user.name),
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
```

### Bloc (대안)

```dart
// Event: sealed class
sealed class UserEvent {
  const UserEvent();
}

final class UserLoadRequested extends UserEvent {
  const UserLoadRequested(this.userId);
  final String userId;
}

final class UserNameUpdated extends UserEvent {
  const UserNameUpdated(this.name);
  final String name;
}

// State: sealed class
sealed class UserState {
  const UserState();
}

final class UserInitial extends UserState {
  const UserInitial();
}

final class UserLoading extends UserState {
  const UserLoading();
}

final class UserLoaded extends UserState {
  const UserLoaded(this.user);
  final User user;
}

final class UserError extends UserState {
  const UserError(this.message);
  final String message;
}

// Bloc
class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc({required UserRepository repository})
      : _repository = repository,
        super(const UserInitial()) {
    on<UserLoadRequested>(_onLoadRequested);
    on<UserNameUpdated>(_onNameUpdated);
  }

  final UserRepository _repository;

  Future<void> _onLoadRequested(
    UserLoadRequested event,
    Emitter<UserState> emit,
  ) async {
    emit(const UserLoading());
    try {
      final user = await _repository.getUser(event.userId);
      emit(UserLoaded(user));
    } on Exception catch (e) {
      emit(UserError(e.toString()));
    }
  }
}
```

---

## 테스트 전략

### Widget Test

```dart
testWidgets('UserProfile renders user name', (tester) async {
  // Arrange
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: UserProfile(name: 'John Doe'),
      ),
    ),
  );

  // Act
  await tester.pumpAndSettle();

  // Assert
  expect(find.text('John Doe'), findsOneWidget);
});
```

### Golden Test (픽셀 완벽 회귀)

```dart
testWidgets('UserCard matches golden', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: UserCard(
          name: 'John Doe',
          email: 'john@example.com',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(UserCard),
    matchesGoldenFile('goldens/user_card.png'),
  );
});
```

### Riverpod 테스트

```dart
test('UserNotifier fetches user on build', () async {
  final container = ProviderContainer(
    overrides: [
      userRepositoryProvider.overrideWithValue(MockUserRepository()),
    ],
  );

  final user = await container.read(
    userNotifierProvider('user-123').future,
  );

  expect(user.name, equals('John Doe'));
});
```

---

## 커버리지 게이트 — 바뀐 줄 80% + 전체는 떨어지지 않음 (전체 80% 검사와 함께)

전체 커버리지 80% 검사는 그대로 두고, 그 위에 `scripts/coverage-gate.sh`(bootstrap 이 복사)를 하나 더 건다. 게이트는 두 가지를 본다.

1. **바뀐 줄**: base 브랜치 대비 이 브랜치가 바꾼 줄의 80% 이상이 테스트로 실행돼야 한다(diff-cover, 버전 고정)
2. **ratchet**: 전체 줄 커버리지가 `.coverage-baseline` 의 숫자 아래로 떨어지면 실패한다

두 검사를 함께 두는 이유(2026-11-10 결정): 전체 80% 는 바닥을 지키고, 바뀐 줄 검사는 전체 검사가 놓치는 것을 잡는다.
예를 들어 전체가 90% 인 프로젝트에 테스트 없는 새 코드 50줄을 넣어도 전체는 80% 를 넘어 통과하지만, 바뀐 줄 검사는 그 50줄이 0% 라서 막는다.
대신 전체가 80% 아래인 기존 프로젝트는 무엇을 바꾸든 먼저 전체를 80% 까지 올려야 push·PR 이 통과한다.

| 항목 | 내용 |
|---|---|
| 실행 위치 | pre-push 훅 `coverage-gate` — 리포트를 쓰는 훅 `flutter-test` 바로 뒤에서 돈다(같은 파일 조건) |
| 리포트 | `coverage/lcov.info` — `flutter test --coverage` |
| 필요한 것 | uv(`uvx`) 또는 pipx · `origin/main` 이 fetch 돼 있을 것 |
| 로컬에서 직접 | `flutter test --coverage && scripts/coverage-gate.sh coverage/lcov.info` |
| 첫 적용 | `scripts/coverage-gate.sh <리포트> --write-baseline` → `.coverage-baseline` 커밋. 기준선이 없으면 ratchet 은 알림만 내고 건너뛴다 |
| 기준선 올리기 | 커버리지가 오르면 같은 명령으로 다시 기록해 커밋한다(사람이 결정) |

> 검증: `tests/enforcement-coverage-langs.bats` 가 Flutter 모양(`SF:lib/…`)의 lcov 로 `coverage-gate` 훅을 실행한다 — Flutter 가 그 파일을 쓰는 부분은 그 테스트 범위 밖이다. 게이트 자체(바뀐 줄 80% 통과 · 79% 실패, ratchet, 리포트 여러 개 합산)는 `tests/enforcement-coverage.bats`.
> 한계: 리포트에 아예 없는 파일은 분모에서 빠진다. 문서·테스트만 바꾼 변경은 측정할 줄이 없어 알림과 함께 통과한다.
> 리포트마다 저장소의 파일을 하나 이상 가리켜야 한다 — 어느 한 리포트라도 하나도 맞지 않으면(경로 불일치) 다른 리포트가 맞아도 실패한다.

## Flutter / Dart 코딩 체크리스트

```
타입 안전성
[ ] strict-casts + strict-inference + strict-raw-types 활성화
[ ] dynamic 타입 0개 (avoid_dynamic_calls)
[ ] 모든 public API에 타입 주석 (type_annotate_public_apis)
[ ] sealed class로 상태 모델링

불변성
[ ] final 지역 변수 (prefer_final_locals)
[ ] const 생성자 (prefer_const_constructors)
[ ] @freezed 또는 @immutable 데이터 클래스
[ ] 상태 직접 변경 금지 (새 상태 반환)

Widget 설계
[ ] 위젯 클래스로 추출 (메서드 아님)
[ ] const 정적 서브트리
[ ] 한 위젯 = 한 책임
[ ] Key 매개변수

상태 관리
[ ] Riverpod @riverpod 또는 Bloc sealed class
[ ] ref.watch (build) / ref.read (이벤트)
[ ] 구독 정리 (dispose / onDispose)

품질
[ ] McCabe 복잡도 <= 15
[ ] 함수 <= 50줄
[ ] 파일 <= 800줄
[ ] avoid_print (debugPrint 또는 logger)
[ ] require_trailing_commas

테스트
[ ] Widget 테스트: pumpWidget + pumpAndSettle
[ ] Golden 테스트: matchesGoldenFile
[ ] 단위 테스트: 비즈니스 로직
[ ] 커버리지 >= 80% (flutter test --coverage)

보안
[ ] 하드코딩된 시크릿 없음 (API 키, 토큰)
[ ] 환경 변수: --dart-define 또는 dotenv
[ ] 네트워크 보안: HTTPS only, certificate pinning
[ ] 민감 데이터: flutter_secure_storage
```

---

## 품질 수치 강제 — `tool/quality_metrics`

`dart analyze` 에는 복잡도·함수 길이 규칙이 없고(이를 하던 `dart_code_metrics` 는 유료 DCM 으로 바뀌었다),
`flutter test --coverage` 는 리포트만 쓰고 80% 를 검사하지 않는다. 2026-11-06 전 템플릿은 세 칸 모두 막는 장치가 없었다.
지금은 `bootstrap.sh` 가 `tool/quality_metrics/`(독립 Dart 패키지)를 복사하고 pre-commit 훅이 부른다.

| 훅 | 단계 | 하는 일 |
|---|---|---|
| `dart-metrics` | commit | `lib/**/*.dart` 의 함수·메서드·생성자·클로저마다 복잡도 > 15 또는 50줄 초과면 `FAIL: 파일:줄 이름 (…)` |
| `flutter-test` | push | `flutter test --coverage` 뒤 `coverage/lcov.info` 의 줄 커버리지(LH/LF 합) < 80% 면 실패 |

세는 방법(`tests/enforcement-dart.bats` 가 확인):
- 복잡도: `1 + if·for·while·do·case·catch·?:·&&·||·??` 개수(아홉 종류를 섞은 fixture 로 확인). 생성자 초기화 리스트도 센다.
  클로저는 따로 잰다(감싼 함수에 더하지 않는다). 구문 오류가 있는 파일은 `FAIL: 파일:줄 syntax error` 로 막는다
- 함수 길이: 선언 줄부터 마지막 줄까지 **실제 줄 수** — 위의 문서 주석(`///`)·어노테이션은 빼고, 안의 빈 줄·주석은 센다

> 주의
> - 도구 패키지가 따로인 이유: 프로젝트의 `custom_lint` 는 `analyzer ^8` 을 요구해서, 도구가 쓰는 `analyzer` 를 프로젝트
>   dev 의존성에 넣으면 의존성 해석이 실패한다. 루트 `analysis_options.yaml` 은 `tool/quality_metrics/**` 를 분석에서 뺀다
> - `analyzer 14.7.0` 은 Dart SDK 3.13 이상이 필요하다. 더 낮은 SDK 면 `tool/quality_metrics/pubspec.yaml` 의 버전을 낮추고
>   `dart pub get --directory=tool/quality_metrics` 로 잠금 파일을 다시 만든다(pub.dev 의 analyzer 버전별 SDK 조건 참고)
> - 커버리지의 분모는 `coverage/lcov.info` 에 있는 파일뿐이다 — 어떤 테스트도 import 하지 않은 `lib/` 파일은 빠진다.
>   모든 파일을 세려면 `lib/` 전체를 import 하는 테스트 하나(예: `test/coverage_helper_test.dart`)를 둔다
> - 기존 `analysis_options.yaml` 을 유지했다면 `analyzer.exclude` 에 `tool/quality_metrics/**` 를 추가한다
> - 로컬 훅이라 `--no-verify` 나 훅 미설치면 건너뛴다 — Dart CI 템플릿은 없다

## 품질 기준 요약 (전 언어 통일)

| 항목 | 기준값 | 도구 |
|------|--------|------|
| 커버리지 | >= 80% | pre-push 훅 flutter-test (`flutter test --coverage` + `tool/quality_metrics/bin/coverage_check.dart`) |
| 복잡도 | <= 15 | pre-commit 훅 dart-metrics (`tool/quality_metrics`) |
| 함수 길이 | <= 50줄 | pre-commit 훅 dart-metrics (`tool/quality_metrics`) |
| 파일 크기 | <= 800줄 | pre-commit 훅 file-size-limit |
| dynamic 타입 | 0개 | avoid_dynamic_calls |
| 보안 취약점 | 0 critical/high | detect-secrets + HTTPS |
