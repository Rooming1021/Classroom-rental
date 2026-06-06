# Supabase 및 Google 로그인 설정

## 현재 연결이 안 되는 경우

Supabase에 GitHub 계정으로 로그인하거나 Supabase에서 저장소를 연결하는 것만으로 웹사이트가 자동 연결되지는 않습니다.

다음 항목이 모두 필요합니다.

1. `supabase-config.js`에 실제 Supabase Project URL과 Publishable key 입력
2. GitHub 저장소에 이 프로젝트 파일 커밋 및 푸시
3. GitHub 저장소의 **Settings > Pages > Source**를 **GitHub Actions**로 설정
4. Supabase GitHub 연동을 사용할 경우 `supabase/migrations/` 아래 SQL 마이그레이션 푸시
5. Google 로그인 사용 시 Supabase와 Google Cloud 양쪽에 실제 GitHub Pages 주소 등록

이 프로젝트에는 GitHub Pages 배포용 `.github/workflows/pages.yml`과 Supabase 배포용 `supabase/migrations/` 경로가 포함되어 있습니다.

## 1. 예약 DB 설정

1. Supabase 프로젝트의 **SQL Editor**를 엽니다.
2. `schema.sql` 전체를 실행합니다.
3. 기존 `reservations` 테이블이 있어도 `user_id` 열과 로그인용 RLS 정책이 추가됩니다.

새 예약은 로그인한 사용자의 Supabase 사용자 ID와 연결됩니다. 기존 비로그인 예약은 시간 충돌 확인에는 계속 반영되지만, 소유자를 알 수 없으므로 누구의 `내 예약`에도 표시되지 않습니다.

## 2. Google OAuth 설정

1. [Google Auth Platform](https://console.cloud.google.com/auth/overview)에서 프로젝트를 만들고 OAuth 동의 화면을 설정합니다.
2. OAuth 클라이언트를 **웹 애플리케이션** 유형으로 생성합니다.
3. 승인된 JavaScript 원본에 사이트 원본을 추가합니다.
   - GitHub Pages 예시: `https://YOUR_GITHUB_ID.github.io`
   - 로컬 테스트 예시: `http://localhost:5500`
4. 승인된 리디렉션 URI에 Supabase 콜백 주소를 추가합니다.
   - `https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback`
5. 생성된 Google Client ID와 Client Secret을 복사합니다.
6. Supabase의 **Authentication > Providers > Google**에서 Google 로그인을 활성화하고 Client ID와 Client Secret을 입력합니다.

Google OAuth 앱이 테스트 상태라면 사용할 Google 계정을 테스트 사용자로 추가해야 합니다.

## 3. Supabase 리디렉션 URL 설정

Supabase의 **Authentication > URL Configuration**에서 다음을 설정합니다.

- **Site URL**: 배포된 GitHub Pages 주소
- **Redirect URLs**:
  - `https://YOUR_GITHUB_ID.github.io/YOUR_REPOSITORY/`
  - 로컬 테스트 주소가 필요하면 `http://localhost:5500/`

사이트 코드에서는 현재 페이지의 폴더 주소를 로그인 완료 후 이동할 주소로 사용합니다.

## 4. 프론트엔드 연결

Supabase 프로젝트의 **Connect** 또는 **Settings > API Keys**에서 값을 확인하고 `supabase-config.js`를 수정합니다.

```js
window.SUPABASE_CONFIG = {
  url: "https://YOUR_PROJECT_ID.supabase.co",
  publishableKey: "YOUR_SUPABASE_PUBLISHABLE_KEY"
};
```

Publishable key는 공개 웹사이트에 포함할 수 있습니다. Secret key 또는 `service_role` key는 절대 브라우저 코드에 넣지 마세요.

## 5. 배포

`index.html`, `styles.css`, `supabase-config.js`를 GitHub Pages에 배포합니다. Google 로그인 설정의 URL은 실제 배포 주소와 정확히 일치해야 합니다.

로그인하지 않은 사용자는 예약 가능 시간만 확인할 수 있습니다. 로그인한 사용자는 예약을 생성하고 본인의 `내 예약`만 조회할 수 있습니다.
