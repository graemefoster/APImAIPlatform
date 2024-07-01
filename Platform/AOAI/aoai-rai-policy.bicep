param policyName string
param openAiServiceName string

resource aoai 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: openAiServiceName
}

resource responsibleAiPolicy 'Microsoft.CognitiveServices/accounts/raiPolicies@2024-04-01-preview' = {
  name: policyName
  parent: aoai
  properties: {
    basePolicyName: 'Microsoft.Default'
    completionBlocklists: []
    mode: 'Blocking'
    promptBlocklists: []
    contentFilters: [
      {
        name: 'hate'
        blocking: true
        enabled: true
        allowedContentLevel: 'high'
        source: 'prompt'
      }
      {
        name: 'sexual'
        blocking: true
        enabled: true
        allowedContentLevel: 'high'
        source: 'prompt'
      }
      {
        name: 'selfharm'
        blocking: true
        enabled: true
        allowedContentLevel: 'high'
        source: 'prompt'
      }
      {
        name: 'violence'
        blocking: true
        enabled: true
        allowedContentLevel: 'high'
        source: 'prompt'
      }
      {
        name: 'hate'
        blocking: true
        enabled: true
        allowedContentLevel: 'high'
        source: 'completion'
      }
      {
        name: 'sexual'
        blocking: true
        enabled: true
        allowedContentLevel: 'high'
        source: 'completion'
      }
      {
        name: 'selfharm'
        blocking: true
        enabled: true
        allowedContentLevel: 'high'
        source: 'completion'
      }
      {
        name: 'violence'
        blocking: true
        enabled: true
        allowedContentLevel: 'high'
        source: 'completion'
      }
      {
        name: 'jailbreak'
        blocking: true
        source: 'prompt'
        enabled: true
      }
      {
        name: 'indirect_attack'
        blocking: true
        source: 'prompt'
        enabled: true
      }
      {
        name: 'protected_material_text'
        blocking: true
        source: 'completion'
        enabled: true
      }
      {
        name: 'protected_material_code'
        blocking: true
        source: 'completion'
        enabled: true
      }
    ]
  }
}

output responsibleAiPolicyName string = responsibleAiPolicy.name
