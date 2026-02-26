# SubTrkr — Account Management Design

> Date: 2026-02-25
> Scope: Roadmap item #12 — password change + account deletion (App Store requirement)

---

## 1. Change Password

**UI:** "Change Password" button in Settings Account section, opens a sheet with new password + confirm fields.

**Implementation:**
- `AuthService.updatePassword(newPassword:)` wraps `client.auth.update(user: UserAttributes(password:))`
- Only shown for email/password users (hide for OAuth-only users)
- Validates: min 6 chars, passwords match

## 2. Delete Account

**UI:** "Delete Account" button (red) at bottom of Settings. Two-step confirmation:
1. Alert explaining all data will be permanently deleted
2. Must type "DELETE" to confirm

**Implementation:**
- `AuthService.deleteAccount()` wraps `client.rpc("delete_user")`
- On success, signs out → returns to auth screen

**Supabase RPC (run in your Supabase project):**

```sql
create or replace function public.delete_user()
returns void
language plpgsql
security definer
as $$
begin
  -- Delete user data (cascade should handle most, but be explicit)
  delete from public.payments where user_id = auth.uid()::text;
  delete from public.item_status_history where user_id = auth.uid()::text;
  delete from public.items where user_id = auth.uid()::text;
  delete from public.categories where user_id = auth.uid()::text;
  delete from public.notification_channels where user_id = auth.uid()::text;
  delete from public.notification_preferences where user_id = auth.uid()::text;
  delete from public.notification_log where user_id = auth.uid()::text;
  -- Delete the auth user
  delete from auth.users where id = auth.uid();
end;
$$;
```

## Files Modified

| File | Change |
|------|--------|
| `Services/AuthService.swift` | Add `updatePassword()` and `deleteAccount()` |
| `Views/Settings/SettingsView.swift` | Add Change Password sheet and Delete Account with confirmation |
