"""Synthetic provider replies, shaped by each production decoder. Every percentage here is what the menu must show."""
from datetime import timedelta
import kit
from kit import ROUTES, epoch, iso, state

EXTRA_CLAUDE = {}
PERCENTS = {'codex': (92, 40), 'claude': (35, 22), 'commandcode': (55, 30), 'kimi': (15, 12), 'zai': (70, 5), 'openrouter': 60}


def codex(_):
    five, week = PERCENTS['codex']
    return 200, {'account_id': 'synthetic-account', 'plan_type': 'pro', 'rate_limit': {
        'primary_window': {'used_percent': five, 'reset_at': epoch(timedelta(hours=2)), 'limit_window_seconds': 18000},
        'secondary_window': {'used_percent': week, 'reset_at': epoch(timedelta(days=4)), 'limit_window_seconds': 604800}}}


def claude(_):
    five, week = PERCENTS['claude']
    return 200, {'five_hour': {'utilization': five, 'resets_at': iso(timedelta(hours=3))},
                 'seven_day': {'utilization': week, 'resets_at': iso(timedelta(days=5))}, **EXTRA_CLAUDE}


def claude_profile(_):
    return 200, {'account': {'uuid': 'synthetic-claude', 'email': 'claude@example.test'},
                 'organization': {'uuid': 'synthetic-org', 'organization_type': 'claude_max', 'rate_limit_tier': 'default_claude_max_5x'}}


def commandcode_credits(_):
    five, week = PERCENTS['commandcode']
    return 200, {'credits': {'monthlyCredits': 70, 'monthlyCreditsGranted': 100, 'purchasedCredits': 0, 'windowLimits': {
        'fiveHour': {'cap': 100, 'used': five, 'resetAt': iso(timedelta(hours=2))},
        'weekly': {'cap': 100, 'used': week, 'resetAt': iso(timedelta(days=3))}}}}


def commandcode_sub(_):
    return 200, {'success': True, 'data': {'planId': 'individual-pro', 'status': 'active', 'currentPeriodEnd': iso(timedelta(days=20))}}


def kimi(_):
    if state.get('kimi_expired'):
        return 401, {'error': {'message': 'Unauthorized'}}
    five, week = PERCENTS['kimi']
    return 200, {'usages': {'limit_5h': {'used_ratio': five / 100, 'reset_time': iso(timedelta(hours=4))},
                            'limit_7d': {'used_ratio': week / 100, 'reset_time': iso(timedelta(days=6))}},
                 'user': {'membership': {'level': 'LEVEL_INTERMEDIATE'}}, 'version': '1'}


def zai(_):
    five = PERCENTS['zai'][0]
    return 200, {'code': 200, 'success': True, 'msg': 'ok', 'data': {'planName': 'Pro', 'limits': [
        {'type': 'TOKENS_LIMIT', 'unit': 3, 'number': 5, 'percentage': five, 'usage': 100, 'currentValue': five, 'remaining': 100 - five,
         'nextResetTime': epoch(timedelta(hours=3)) * 1000}]}}


def openrouter_credits(_):
    return 200, {'data': {'total_credits': 100, 'total_usage': PERCENTS['openrouter']}}


def openrouter_key(_):
    return 200, {'data': {'label': 'synthetic', 'limit': 100, 'limit_remaining': 100 - PERCENTS['openrouter'], 'usage': PERCENTS['openrouter'],
                          'usage_daily': 2, 'usage_weekly': 9, 'usage_monthly': 20, 'rate_limit': {'requests': 100, 'interval': '10s'}}}


def moonshot(_):
    return 200, {'code': 0, 'scode': '0x0', 'status': True, 'data': {'available_balance': 42.5, 'voucher_balance': 2.5, 'cash_balance': 40.0}}


def deepseek(_):
    return 200, {'is_available': True, 'balance_infos': [{'currency': 'USD', 'total_balance': '18.40', 'granted_balance': '0.00', 'topped_up_balance': '18.40'}]}


def install():
    ROUTES[('chatgpt.com', '/backend-api/wham/usage')] = codex
    ROUTES[('chatgpt.com', '/backend-api/accounts')] = lambda _: (200, {'items': []})
    ROUTES[('api.anthropic.com', '/api/oauth/usage')] = claude
    ROUTES[('api.anthropic.com', '/api/oauth/profile')] = claude_profile
    ROUTES[('api.commandcode.ai', '/alpha/billing/credits')] = commandcode_credits
    ROUTES[('api.commandcode.ai', '/alpha/billing/subscriptions')] = commandcode_sub
    ROUTES[('api.kimi.com', '/coding/v1/usages')] = kimi
    ROUTES[('api.kimi.ai', '/coding/v1/usages')] = kimi
    ROUTES[('api.z.ai', '/api/monitor/usage/quota/limit')] = zai
    ROUTES[('openrouter.ai', '/api/v1/credits')] = openrouter_credits
    ROUTES[('openrouter.ai', '/api/v1/key')] = openrouter_key
    ROUTES[('api.moonshot.ai', '/v1/users/me/balance')] = moonshot
    ROUTES[('api.deepseek.com', '/user/balance')] = deepseek


CONFIG = [
    {'id': 'codex', 'enabled': True, 'source': 'oauth'},
    {'id': 'claude', 'enabled': True, 'source': 'oauth'},
    {'id': 'commandcode', 'enabled': True, 'source': 'api', 'apiKey': 'synthetic-commandcode'},
    {'id': 'kimi', 'enabled': True, 'source': 'api', 'apiKey': 'synthetic-kimi'},
    {'id': 'zai', 'enabled': True, 'source': 'api', 'apiKey': 'synthetic-zai'},
    {'id': 'openrouter', 'enabled': True, 'source': 'api', 'apiKey': 'synthetic-openrouter'},
    {'id': 'moonshot', 'enabled': True, 'source': 'api', 'apiKey': 'synthetic-moonshot'},
    {'id': 'deepseek', 'enabled': True, 'source': 'api', 'apiKey': 'synthetic-deepseek'},
]

OVERVIEW_IDS = [p['id'] for p in CONFIG]


def overview_defaults(**extra):
    kit.defaults_write('providerDetectionCompleted', True)
    kit.defaults_write('mergeIcons', True)
    kit.defaults_write('mergedMenuLastSelectedWasOverview', True)
    kit.defaults_write('debugDisableKeychainAccess', True)
    kit.defaults_write('hasPresentedSettings', True)
    for k, v in extra.items():
        kit.defaults_write(k, v)


def write_history(days=14):
    """Local transcripts the real cost scanner reads: three Claude models and two Codex models, recent days weighted."""
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0)
    for back in range(days):
        day = now - timedelta(days=back, hours=1)
        w = 1 + (days - back) % 5
        kit.write_claude(day, 'claude-opus-4-5', 200000 * w, 40000 * w, session=f'opus{back}')
        kit.write_claude(day, 'claude-sonnet-4-5', 300000 * w, 50000 * w, session=f'sonnet{back}')
        if back % 2 == 0:
            kit.write_claude(day, 'claude-haiku-4-5', 500000, 60000, session=f'haiku{back}')
        kit.write_codex(day, 'gpt-5.2-codex', 400000 * w, 60000 * w)
        if back % 3 == 0:
            kit.write_codex(day, 'gpt-5.1-codex-mini', 900000, 80000)
