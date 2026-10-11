import { createClient } from 'jsr:@supabase/supabase-js@2'
import { withSupabase } from 'npm:@supabase/server'

/**
 * Prep-Ethiopia Dynamic API Monolith
 * Handles:
 * 1. Auth Proxy (Sign-in / Sign-up via internal network mesh)
 * 2. Curriculum Engine (Incremental updates / Feature flags)
 * 3. Synchronization (Progress state push / pull mechanics)
 */

interface SupabaseContext {
  supabase: any;
  supabaseAdmin: any;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-retry-count',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
}

export default {
  fetch: withSupabase({ auth: 'none' }, async (req: Request, ctx: SupabaseContext) => {
    // Get environment variables with fallbacks
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''

    // Create admin client with proper configuration
    const supabaseAdmin = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
          detectSessionInUrl: false
        },
        global: {
          headers: {
            'Authorization': `Bearer ${serviceRoleKey}`
          }
        }
      }
    )

    // Create anon client for public operations
    const supabaseAnon = createClient(
      supabaseUrl,
      anonKey,
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
          detectSessionInUrl: false
        }
      }
    )

    const url = new URL(req.url)

    // Handle CORS preflight routing requests
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders })
    }

    let path = url.pathname.split('/dynamic-api').pop() || '/';

    // Normalize path slashes
    if (!path.startsWith('/')) path = '/' + path;
    if (path.endsWith('/') && path.length > 1) path = path.slice(0, -1);

    console.log(`[Request] Method: ${req.method} | Path: ${path}`);

    // Helper for standardized error responses with deep object serialization
    const errorResponse = (message: string, code: string = 'unknown', status: number = 400, details?: any) => {
      let processedDetails = details;

      try {
        if (details instanceof Error) {
          processedDetails = {
            name: details.name,
            message: details.message || message,
            stack: details.stack?.split('\n').slice(0, 3).join('\n'),
            status: (details as any).status,
            code: (details as any).code,
          };
        } else if (typeof details === 'object' && details !== null) {
          // Deep serialization for nested objects and errors
          processedDetails = JSON.parse(JSON.stringify(details, Object.getOwnPropertyNames(details)));

          if (processedDetails.message && typeof processedDetails.message === 'object') {
            processedDetails.message = JSON.parse(JSON.stringify(processedDetails.message, Object.getOwnPropertyNames(processedDetails.message)));
          }
        }
      } catch (e) {
        console.error('[Error Response] Serialization failed:', e);
        processedDetails = { raw: String(details) };
      }

      const finalMessage = message || (processedDetails?.message && typeof processedDetails.message === 'string' ? processedDetails.message : 'An unexpected error occurred');

      console.error(`[Error Response] ${status} - ${code}: ${finalMessage}`, JSON.stringify(processedDetails));

      return Response.json({
        error: finalMessage,
        code: code || 'error',
        status: status,
        details: processedDetails
      }, {
        status: status,
        headers: corsHeaders
      })
    }

    // Helper to get authenticated user for protected sync structures
    const getAuthenticatedUser = async () => {
      const authHeader = req.headers.get('Authorization')
      if (!authHeader) return null

      const token = authHeader.replace('Bearer ', '')

      // Try with admin client first
      try {
        const { data: { user }, error } = await supabaseAdmin.auth.getUser(token)
        if (error) {
          console.error('[Auth] Admin token validation error:', error.message)
          // Fallback to anon client
          const { data: anonData, error: anonError } = await supabaseAnon.auth.getUser(token)
          if (anonError) {
            console.error('[Auth] Anon token validation error:', anonError.message)
            return null
          }
          return anonData.user
        }
        return user
      } catch (e) {
        console.error('[Auth] Token validation exception:', e)
        return null
      }
    }

    // --- 1. AUTH PROXY ---
    if (path === '/auth/sign-in') {
      let body: any;
      try {
        body = await req.json();
      } catch (e) {
        return errorResponse('Invalid JSON request body', 'bad_request', 400, e);
      }

      try {
        console.log(`[Auth] Sign-in attempt for: ${body.email}`);

        // Use the anon client for sign in
        const { data, error } = await supabaseAnon.auth.signInWithPassword({
          email: body.email,
          password: body.password
        })

        if (error) {
          console.error('[Auth] Sign-in error:', error)

          // Handle specific error cases
          if (error.message?.includes('Invalid login credentials')) {
            return errorResponse('Invalid email or password', 'invalid_credentials', 401, error);
          }
          if (error.message?.includes('Email not confirmed')) {
            return errorResponse('Please confirm your email before signing in', 'email_not_confirmed', 400, error);
          }
          if (error.status === 429 || error.message?.includes('rate limit')) {
            return errorResponse('Too many attempts. Please try again later.', 'rate_limited', 429, error);
          }
          return errorResponse(error.message, error.code || 'auth_error', error.status || 400, error);
        }

        if (!data.session) {
          return errorResponse('No session created', 'session_error', 500);
        }

        console.log(`[Auth] Sign-in successful for: ${body.email}`)
        return Response.json({
          user: {
            id: data.user.id,
            email: data.user.email,
            user_metadata: data.user.user_metadata
          },
          access_token: data.session.access_token,
          refresh_token: data.session.refresh_token,
          expires_at: data.session.expires_at,
          token_type: data.session.token_type,
        }, {
          headers: {
            ...corsHeaders,
            'Cache-Control': 'no-cache, no-store, must-revalidate'
          }
        })
      } catch (e) {
        console.error('[Auth] Sign-in exception:', e)
        if (e instanceof Error && (e.message?.includes('fetch') || e.message?.includes('connection') || e.message?.includes('timeout'))) {
          return errorResponse('Network error during sign-in. Please retry.', 'network_error', 503, e);
        }
        return errorResponse('Internal Server Error during sign-in', 'internal_error', 500, e);
      }
    }

    if (path === '/auth/sign-up') {
      let body: any;
      try {
        body = await req.json();
      } catch (e) {
        return errorResponse('Invalid JSON request body', 'bad_request', 400, e);
      }

      try {
        console.log(`[Auth] Sign-up attempt for: ${body.email}`);

        // Validate input
        if (!body.email || !body.password) {
          return errorResponse('Email and password are required', 'validation_error', 400);
        }

        if (body.password.length < 6) {
          return errorResponse('Password must be at least 6 characters', 'validation_error', 400);
        }

        // Use admin client for user creation
        const { data: adminData, error: adminError } = await supabaseAdmin.auth.admin.createUser({
          email: body.email,
          password: body.password,
          email_confirm: true,
          user_metadata: {
            role: body.role || 'student',
            full_name: body.full_name || body.email,
            phone_number: body.phone_number && body.phone_number.trim() !== "" ? body.phone_number : null,
            preferred_language: body.preferred_language || 'en'
          }
        })

        if (adminError) {
          console.error('[Auth] Admin create user error:', adminError)

          if (adminError.message?.toLowerCase().includes('already registered') ||
              adminError.code === 'user_already_exists') {
            return errorResponse('User already registered. Please sign in instead.', 'user_already_exists', 400);
          }
          return errorResponse(adminError.message, adminError.code || 'admin_error', adminError.status || 400, adminError);
        }

        console.log(`[Auth] User created successfully for: ${body.email}`);

        // 2. GENERATE SESSION SAFELY VIA ADMIN CLIENT (Fixes AuthRetryableFetchError loop)
        // This avoids the network race condition by staying within the admin context
        const { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
          type: 'signup',
          email: body.email,
          password: body.password
        });

        if (linkError || !linkData?.session) {
          console.warn('[Auth] Account created but inline token generation failed:', linkError?.message);

          return Response.json({
            user: {
              id: adminData.user.id,
              email: adminData.user.email,
              user_metadata: adminData.user.user_metadata
            },
            message: 'Account created successfully. Please sign in.',
            require_signin: true
          }, { headers: corsHeaders })
        }

        // 3. Return complete authentication payload back to Flutter
        console.log(`[Auth] Sign-up complete and token generated for: ${body.email}`)
        return Response.json({
          user: {
            id: linkData.user.id,
            email: linkData.user.email,
            user_metadata: linkData.user.user_metadata
          },
          access_token: linkData.session.access_token,
          refresh_token: linkData.session.refresh_token,
          expires_at: linkData.session.expires_at,
          token_type: linkData.session.token_type,
        }, { headers: corsHeaders })
      } catch (e) {


        console.error('[Auth] Sign-up exception:', e)
        if (e instanceof Error && (e.message?.includes('fetch') || e.message?.includes('connection') || e.message?.includes('timeout'))) {
          return errorResponse('Network error during sign-up. Please retry.', 'network_error', 503, e);
        }
        return errorResponse('Internal Server Error during sign-up', 'internal_error', 500, e);
      }
    }

    // --- 2. CURRICULUM ---
    if (path === '/curriculum/feature-flags') {
      try {
        const { data, error } = await supabaseAdmin
          .from('feature_flags')
          .select('*')
          .order('created_at', { ascending: true })

        if (error) {
          console.error('[Curriculum] Feature flags error:', error)
          return errorResponse(error.message, 'db_error', 500, error)
        }
        return Response.json(data || [], { headers: corsHeaders })
      } catch (e) {
        console.error('[Curriculum] Feature flags exception:', e)
        return errorResponse('Failed to fetch feature flags', 'internal_error', 500, e)
      }
    }

    if (path === '/curriculum/incremental') {
      const since = url.searchParams.get('since') || new Date(0).toISOString()

      try {
        // Use Promise.allSettled for better error handling
        const results = await Promise.allSettled([
          supabaseAdmin.from('grades').select('*').gt('updated_at', since),
          supabaseAdmin.from('subjects').select('*').gt('updated_at', since),
          supabaseAdmin.from('units').select('*').gt('updated_at', since),
          supabaseAdmin.from('lessons').select('*').gt('updated_at', since),
          supabaseAdmin.from('steps').select('*').gt('updated_at', since),
          supabaseAdmin.from('quiz_questions').select('*').gt('updated_at', since),
          supabaseAdmin.from('exams').select('*').gt('updated_at', since),
          supabaseAdmin.from('exam_questions').select('*').gt('updated_at', since),
          supabaseAdmin.from('flashcard_templates').select('*').gt('updated_at', since),
          supabaseAdmin.from('textbooks').select('*').gt('updated_at', since),
          supabaseAdmin.from('worksheets').select('*').gt('updated_at', since),
        ])

        // Check for rejected promises (failures)
        const errors = results
          .filter(r => r.status === 'rejected')
          .map(r => (r as PromiseRejectedResult).reason?.message || 'Unknown error')
        
        if (errors.length > 0) {
          // If all failed, return error
          if (errors.length === results.length) {
            return errorResponse('All curriculum sync requests failed', 'sync_error', 500, errors)
          }
          // If some failed, log but continue with partial data
          console.warn('[Sync] Partial failure in curriculum sync:', errors)
        }

        // Extract data from successful promises
        const data = results.map(r => {
          if (r.status === 'fulfilled') {
            return r.value.data || []
          }
          return []
        })

        return Response.json({
          grades: data[0] || [],
          subjects: data[1] || [],
          units: data[2] || [],
          lessons: data[3] || [],
          steps: data[4] || [],
          quiz_questions: data[5] || [],
          exams: data[6] || [],
          exam_questions: data[7] || [],
          flashcard_templates: data[8] || [],
          textbooks: data[9] || [],
          worksheets: data[10] || [],
          partial_sync: errors.length > 0,
          sync_errors: errors.length > 0 ? errors : undefined
        }, { headers: corsHeaders })
      } catch (e) {
        console.error('[Curriculum] Sync exception:', e)
        return errorResponse('Unexpected sync error', 'internal_error', 500, e)
      }
    }

    // --- 3. SYNC ENGINE ---
    if (path === '/sync/push-progress') {
      const user = await getAuthenticatedUser()
      if (!user) {
        return errorResponse('Unauthorized', 'unauthorized', 401)
      }

      let payload: any;
      try {
        payload = await req.json();
      } catch (e) {
        return errorResponse('Invalid JSON payload', 'bad_request', 400)
      }

      const { user_progress, quiz_attempts, exam_attempts, user_flashcards, profiles, worksheet_attempts } = payload

      const validateOwnership = (items: any[], userField: string = 'user_id') => {
        if (!items) return true
        return items.every(item => (item[userField] === user.id || item['id'] === user.id))
      }

      if (!validateOwnership(user_progress) ||
          !validateOwnership(quiz_attempts) ||
          !validateOwnership(exam_attempts) ||
          !validateOwnership(user_flashcards) ||
          !validateOwnership(profiles, 'id') ||
          !validateOwnership(worksheet_attempts)) {
        return errorResponse('Forbidden: Ownership mismatch', 'forbidden', 403)
      }

      try {
        const operations = []
        if (user_progress?.length) operations.push(supabaseAdmin.from('user_progress').upsert(user_progress))
        if (quiz_attempts?.length) operations.push(supabaseAdmin.from('quiz_attempts').upsert(quiz_attempts))
        if (exam_attempts?.length) operations.push(supabaseAdmin.from('exam_attempts').upsert(exam_attempts))
        if (user_flashcards?.length) operations.push(supabaseAdmin.from('user_flashcards').upsert(user_flashcards))
        if (profiles?.length) operations.push(supabaseAdmin.from('profiles').upsert(profiles))
        if (worksheet_attempts?.length) operations.push(supabaseAdmin.from('worksheet_attempts').upsert(worksheet_attempts))

        // Execute all operations with Promise.allSettled to handle partial failures
        if (operations.length > 0) {
          const results = await Promise.allSettled(operations)
          const failed = results.filter(r => r.status === 'rejected')
          
          if (failed.length > 0) {
            const errors = failed.map(r => (r as PromiseRejectedResult).reason?.message || 'Unknown error')
            console.error('[Sync Push] Some operations failed:', errors)
            return Response.json({ 
              success: true, 
              partial_failure: true,
              errors: errors 
            }, { headers: corsHeaders })
          }
        }

        return Response.json({ success: true }, { headers: corsHeaders })
      } catch (e) {
        console.error('[Sync] Push exception:', e)
        return errorResponse('Sync push failed', 'db_error', 500, e)
      }
    }

    if (path === '/sync/pull-progress') {
      const user = await getAuthenticatedUser()
      if (!user) {
        return errorResponse('Unauthorized', 'unauthorized', 401)
      }

      const userId = url.searchParams.get('user_id')
      const since = url.searchParams.get('since') || new Date(0).toISOString()

      if (!userId) return errorResponse('Missing user_id', 'bad_request', 400)

      if (userId !== user.id) {
        return errorResponse('Forbidden: Cannot access other users data', 'forbidden', 403)
      }

      try {
        const results = await Promise.allSettled([
          supabaseAdmin.from('user_progress').select('*').eq('user_id', userId).gt('updated_at', since),
          supabaseAdmin.from('quiz_attempts').select('*').eq('user_id', userId).gt('updated_at', since),
          supabaseAdmin.from('exam_attempts').select('*').eq('user_id', userId).gt('updated_at', since),
          supabaseAdmin.from('user_flashcards').select('*').eq('user_id', userId).gt('updated_at', since),
          supabaseAdmin.from('profiles').select('*').eq('id', userId).gt('updated_at', since),
          supabaseAdmin.from('worksheet_attempts').select('*').eq('user_id', userId).gt('updated_at', since),
        ])

        const errors = results
          .filter(r => r.status === 'rejected')
          .map(r => (r as PromiseRejectedResult).reason?.message || 'Unknown error')

        if (errors.length > 0 && errors.length === results.length) {
          return errorResponse('All sync pull requests failed', 'db_error', 500, errors)
        }

        // Extract data from successful promises
        const data = results.map(r => {
          if (r.status === 'fulfilled') {
            return r.value.data || []
          }
          return []
        })

        return Response.json({
          user_progress: data[0] || [],
          quiz_attempts: data[1] || [],
          exam_attempts: data[2] || [],
          user_flashcards: data[3] || [],
          profiles: data[4] || [],
          worksheet_attempts: data[5] || [],
          partial_sync: errors.length > 0,
          sync_errors: errors.length > 0 ? errors : undefined
        }, { headers: corsHeaders })
      } catch (e) {
        console.error('[Sync] Pull exception:', e)
        return errorResponse('Internal sync pull error', 'internal_error', 500, e)
      }
    }

    if (path === '/sync/parent-student-links') {
      const user = await getAuthenticatedUser()
      if (!user) {
        return errorResponse('Unauthorized', 'unauthorized', 401)
      }

      const userId = url.searchParams.get('user_id')
      if (!userId) return errorResponse('Missing user_id', 'bad_request', 400)

      if (userId !== user.id) {
        return errorResponse('Forbidden', 'forbidden', 403)
      }

      try {
        const { data, error } = await supabaseAdmin
          .from('parent_student_links')
          .select('*')
          .or(`parent_id.eq.${userId},student_id.eq.${userId}`)

        if (error) {
          console.error('[Sync] Parent-student links error:', error)
          return errorResponse(error.message, 'db_error', 500, error)
        }
        return Response.json(data || [], { headers: corsHeaders })
      } catch (e) {
        console.error('[Sync] Parent-student links exception:', e)
        return errorResponse('Failed to fetch parent-student links', 'internal_error', 500, e)
      }
    }


    return errorResponse('Not Found', 'not_found', 404, { path })
  }),
}