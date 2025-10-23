import { describe, expect, test, beforeEach, jest } from '@jest/globals';
import fs from 'fs';
import path from 'path';
import YAML from 'yaml';

// Mock data
const mockNamespaceConfig = {
  namespaces: {
    'dao:vaultmesh': {
      description: 'VaultMesh DAO canonical ledger',
      witnesses: {
        min_required: 2,
        allowlist: [
          'did:vm:arbiter:prod-us-east-1',
          'did:vm:arbiter:prod-eu-west-1',
          'did:vm:arbiter:prod-dao-suite'
        ]
      },
      schema_policy: {
        allow: [
          'registry.set@1.0.x',
          'ledger.append@1.0.x',
          'vote.cast@1.0.x',
          'workflow.transition@1.0.x'
        ]
      }
    },
    'fin:clearing': {
      description: 'Financial clearing house instance',
      witnesses: {
        min_required: 3,
        allowlist: [
          'did:vm:arbiter:prod-clearing-a',
          'did:vm:arbiter:prod-clearing-b',
          'did:vm:arbiter:prod-clearing-c'
        ]
      },
      schema_policy: {
        allow: [
          'sequencer.commit@1.0.x',
          'indexer.checkpoint@1.0.x',
          'ledger.append@1.0.x'
        ]
      }
    }
  }
};

// Mock functions
jest.mock('fs', () => ({
  existsSync: jest.fn(),
  readFileSync: jest.fn(),
  mkdirSync: jest.fn(),
  writeFileSync: jest.fn()
}));

jest.mock('path', () => ({
  join: jest.fn().mockImplementation((...args) => args.join('/')),
  resolve: jest.fn().mockImplementation((...args) => args.join('/')),
  dirname: jest.fn().mockReturnValue('mock-dirname')
}));

describe('Namespace-specific admission rules', () => {
  // Helper function to test admission logic
  function testAdmission(event, namespaceConfig) {
    // Mock filesystem to return namespace config
    fs.existsSync.mockImplementation((p) => {
      if (p.endsWith('namespaces.yaml')) return true;
      return false;
    });
    fs.readFileSync.mockImplementation((p) => {
      if (p.endsWith('namespaces.yaml')) return YAML.stringify(namespaceConfig);
      return '{}';
    });
    
    // Extract namespace from subject
    const subjectNs = event.subject.split(':').slice(0, 2).join(':');
    const ns = namespaceConfig.namespaces[subjectNs];
    
    // Tests
    const result = {
      witnessCount: { pass: false, reason: '' },
      witnessAllowlist: { pass: false, reason: '' },
      schemaPolicy: { pass: false, reason: '' }
    };
    
    // Test witness count
    const witnesses = Array.isArray(event.witness) ? event.witness : [];
    const reqCount = ns?.witnesses?.min_required ?? 1;
    result.witnessCount.pass = witnesses.length >= reqCount;
    if (!result.witnessCount.pass) {
      result.witnessCount.reason = `insufficient witnesses (${witnesses.length} < ${reqCount})`;
    }
    
    // Test witness allowlist
    if (ns?.witnesses?.allowlist && Array.isArray(ns.witnesses.allowlist)) {
      const allowedWitnesses = new Set(ns.witnesses.allowlist);
      const invalidWitnesses = witnesses.filter((w) => !allowedWitnesses.has(w));
      result.witnessAllowlist.pass = invalidWitnesses.length === 0;
      if (!result.witnessAllowlist.pass) {
        result.witnessAllowlist.reason = `unauthorized witnesses: ${invalidWitnesses.join(', ')}`;
      }
    } else {
      result.witnessAllowlist.pass = true;
    }
    
    // Test schema policy
    if (ns?.schema_policy?.allow) {
      const schema = event.schema;
      result.schemaPolicy.pass = ns.schema_policy.allow.some((pat) => {
        if (!schema) return false;
        if (!pat.includes('@')) return schema.startsWith(pat);
        const [name, rule] = pat.split('@');
        if (!schema.startsWith(name + '@')) return false;
        const want = rule.replace('.x', '');
        return schema.startsWith(`${name}@${want}`);
      });
      if (!result.schemaPolicy.pass) {
        result.schemaPolicy.reason = `schema ${schema} not allowed for ${subjectNs}`;
      }
    } else {
      result.schemaPolicy.pass = true;
    }
    
    return result;
  }
  
  beforeEach(() => {
    jest.clearAllMocks();
  });
  
  test('passes valid DAO event with proper witnesses', () => {
    const validEvent = {
      subject: 'did:vm:dao:vaultmesh:test',
      schema: 'registry.set@1.0.0',
      witness: [
        'did:vm:arbiter:prod-us-east-1',
        'did:vm:arbiter:prod-eu-west-1'
      ]
    };
    
    const result = testAdmission(validEvent, mockNamespaceConfig);
    expect(result.witnessCount.pass).toBe(true);
    expect(result.witnessAllowlist.pass).toBe(true);
    expect(result.schemaPolicy.pass).toBe(true);
  });
  
  test('rejects event with insufficient witness count', () => {
    const invalidEvent = {
      subject: 'did:vm:dao:vaultmesh:test',
      schema: 'registry.set@1.0.0',
      witness: [
        'did:vm:arbiter:prod-us-east-1'
      ]
    };
    
    const result = testAdmission(invalidEvent, mockNamespaceConfig);
    expect(result.witnessCount.pass).toBe(false);
    expect(result.witnessCount.reason).toContain('insufficient witnesses');
  });
  
  test('rejects event with unauthorized witnesses', () => {
    const invalidEvent = {
      subject: 'did:vm:dao:vaultmesh:test',
      schema: 'registry.set@1.0.0',
      witness: [
        'did:vm:arbiter:prod-us-east-1',
        'did:vm:arbiter:unauthorized'
      ]
    };
    
    const result = testAdmission(invalidEvent, mockNamespaceConfig);
    expect(result.witnessAllowlist.pass).toBe(false);
    expect(result.witnessAllowlist.reason).toContain('unauthorized witnesses');
  });
  
  test('rejects event with unauthorized schema', () => {
    const invalidEvent = {
      subject: 'did:vm:dao:vaultmesh:test',
      schema: 'unauthorized.schema@1.0.0',
      witness: [
        'did:vm:arbiter:prod-us-east-1',
        'did:vm:arbiter:prod-eu-west-1'
      ]
    };
    
    const result = testAdmission(invalidEvent, mockNamespaceConfig);
    expect(result.schemaPolicy.pass).toBe(false);
    expect(result.schemaPolicy.reason).toContain('not allowed for dao:vaultmesh');
  });
  
  test('passes valid financial clearing event', () => {
    const validEvent = {
      subject: 'did:vm:fin:clearing:transaction',
      schema: 'sequencer.commit@1.0.0',
      witness: [
        'did:vm:arbiter:prod-clearing-a',
        'did:vm:arbiter:prod-clearing-b',
        'did:vm:arbiter:prod-clearing-c'
      ]
    };
    
    const result = testAdmission(validEvent, mockNamespaceConfig);
    expect(result.witnessCount.pass).toBe(true);
    expect(result.witnessAllowlist.pass).toBe(true);
    expect(result.schemaPolicy.pass).toBe(true);
  });
});