import pino from 'pino';
import { CONFIG } from './config.js';

export const logger = pino({
  level: CONFIG.LOG_LEVEL,
  transport: CONFIG.NODE_ENV === 'development' ? {
    target: 'pino-pretty',
    options: {
      colorize: true,
      translateTime: 'SYS:standard',
      ignore: 'pid,hostname',
    },
  } : undefined,
});
