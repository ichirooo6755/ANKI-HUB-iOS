# Supabase セットアップ（Google ログイン復旧）

## 手順

1. [Supabase Dashboard](https://supabase.com/dashboard) でプロジェクト `uahrjcauawtftpecpxsq` を開く
2. **SQL Editor** → `schema.sql` の内容を貼り付けて **Run**
3. **Authentication → URL Configuration**
   - Redirect URLs に `sugwranki://login-callback` を追加
4. **Authentication → Providers → Google** を有効化
   - Client ID / Secret を Google Cloud Console から設定
5. **Google Cloud Console**
   - OAuth 同意画面を設定
   - iOS クライアント: バンドル ID `com.ankihub.ios`
6. アプリで Google ログイン → 成功後 `users` テーブルに行ができることを確認
7. 招待コード `DEV-INVITE-2026` をアプリの招待入力で使用（開発用）

## トラブルシュート

| 症状 | 確認 |
|------|------|
| ブラウザから戻らない | Redirect URL が Dashboard に未登録 |
| 401 on rest/v1/users | RLS ポリシー未適用 → schema.sql 再実行 |
| ログイン成功だが同期不可 | `invitations` に used_by が自分の UUID で存在するか |

## アプリ側設定

- `Sources/ANKI-HUB-iOS/Services/SupabaseConfig.swift` — URL / anon key
- `Sources/ANKI-HUB-iOS/Info.plist` — URL scheme `sugwranki`
