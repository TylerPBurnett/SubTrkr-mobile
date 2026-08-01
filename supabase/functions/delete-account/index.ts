import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Supabase Edge Function: delete-account
//
// Permanently deletes the calling user's account (GDPR / CCPA "right to
// erasure"). The caller proves identity with their own access token; the
// function never accepts a user id from the request body, so a user can only
// ever delete themselves.
//
// Cascade behaviour (verified against supabase/migrations/):
//   - notification_channels.user_id     -> auth.users(id) ON DELETE CASCADE
//   - notification_preferences.user_id  -> auth.users(id) ON DELETE CASCADE
//   - notification_log.user_id          -> auth.users(id) ON DELETE CASCADE
//   - notification_log.item_id          -> items(id)      ON DELETE SET NULL
//   - item_status_history.item_id       -> items(id)      ON DELETE CASCADE
// items / categories / payments predate the migration history in this repo
// (they were created in the Supabase dashboard), so their FK actions are not
// verifiable from source. See README.md -- confirm them before deploying.

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ success: false, error: "Method not allowed" }, 405);
  }

  try {
    // Service-role client: needed both to resolve the token (getUser with an
    // explicit token argument) and to call the admin delete API.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ success: false, error: "No authorization header" }, 401);
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return jsonResponse({ success: false, error: "Invalid token" }, 401);
    }

    // Hard delete. `shouldSoftDelete` defaults to false, which is what the
    // right-to-erasure promise in the UI requires: the auth.users row goes
    // away and every ON DELETE CASCADE FK fires with it.
    const { error: deleteError } = await supabase.auth.admin.deleteUser(user.id);

    if (deleteError) {
      // The real reason (constraint name, PostgREST detail, admin API body)
      // stays in the function logs; the client gets a fixed, safe string.
      console.error(`Failed to delete user ${user.id}: ${deleteError.message}`);
      return jsonResponse(
        { success: false, error: "Could not delete this account. Please try again." },
        500
      );
    }

    console.log(`Deleted account ${user.id}`);
    return jsonResponse({ success: true });
  } catch (err) {
    console.error("delete-account failed:", err);
    return jsonResponse(
      { success: false, error: "Could not delete this account. Please try again." },
      500
    );
  }
});
