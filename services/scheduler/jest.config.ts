import type { Config } from 'jest';

const config: Config = {
  testEnvironment: 'node',
  transform: {
    '^.+\\.(ts|tsx)$': ['ts-jest', { tsconfig: 'tsconfig.json' }],
  },
  roots: ['<rootDir>/test'],
  moduleFileExtensions: ['ts','tsx','js','json'],
  verbose: true
};

export default config;

