interface RoutingRule {
  intent: string;
  agent: string;
  description: string;
  keywords: string[];
}

const ROUTING_RULES: RoutingRule[] = [
  {
    intent: 'browser.login',
    agent: 'browser-login',
    description: 'Login/OAuth and managed browser operations',
    keywords: ['login', 'browser', 'portal', 'cookie', 'captcha']
  },
  {
    intent: 'deploy.coolify',
    agent: 'coolify-ops',
    description: 'Coolify service lifecycle and deployment operations',
    keywords: ['coolify', 'deploy', 'release', 'rollback', 'service up', 'service down']
  },
  {
    intent: 'research.analysis',
    agent: 'research',
    description: 'Research, comparisons, and technical analysis',
    keywords: ['investiga', 'analiza', 'research', 'comparar', 'resumen', 'benchmark']
  }
];

export function classifyIntent(text: string): { intent: string; targetAgent: string } {
  const lowered = text.toLowerCase();
  for (const rule of ROUTING_RULES) {
    if (rule.keywords.some((word) => lowered.includes(word))) {
      return { intent: rule.intent, targetAgent: rule.agent };
    }
  }

  return { intent: 'general.main', targetAgent: 'main' };
}

export function actionNeedsConfirmation(text: string): boolean {
  const lowered = text.toLowerCase();
  return ['delete', 'drop', 'destroy', 'stop', 'down', 'wipe', 'rm -rf', 'shutdown'].some((token) =>
    lowered.includes(token)
  );
}

export function listAvailableAgents(): Array<{ id: string; intent: string; description: string }> {
  const agents = new Map<string, { id: string; intent: string; description: string }>();

  agents.set('main', {
    id: 'main',
    intent: 'general.main',
    description: 'General coordinator and fallback'
  });

  for (const rule of ROUTING_RULES) {
    agents.set(rule.agent, {
      id: rule.agent,
      intent: rule.intent,
      description: rule.description
    });
  }

  return Array.from(agents.values());
}
