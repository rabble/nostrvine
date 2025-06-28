// Logger utility for Analytics Worker with configurable log levels

export enum LogLevel {
  VERBOSE = 0,
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}

export interface LoggerConfig {
  level: LogLevel;
  prefix?: string;
}

class Logger {
  private level: LogLevel;
  private prefix: string;

  constructor(config: LoggerConfig) {
    this.level = config.level;
    this.prefix = config.prefix || 'Analytics';
  }

  private shouldLog(level: LogLevel): boolean {
    return level >= this.level;
  }

  private formatMessage(level: string, message: string, data?: any): string {
    const timestamp = new Date().toISOString();
    const base = `[${timestamp}] [${this.prefix}] [${level}] ${message}`;
    return data ? `${base} ${JSON.stringify(data)}` : base;
  }

  verbose(message: string, data?: any): void {
    if (this.shouldLog(LogLevel.VERBOSE)) {
      console.log(this.formatMessage('VERBOSE', message, data));
    }
  }

  debug(message: string, data?: any): void {
    if (this.shouldLog(LogLevel.DEBUG)) {
      console.log(this.formatMessage('DEBUG', message, data));
    }
  }

  info(message: string, data?: any): void {
    if (this.shouldLog(LogLevel.INFO)) {
      console.log(this.formatMessage('INFO', message, data));
    }
  }

  warn(message: string, data?: any): void {
    if (this.shouldLog(LogLevel.WARN)) {
      console.warn(this.formatMessage('WARN', message, data));
    }
  }

  error(message: string, error?: Error | any): void {
    if (this.shouldLog(LogLevel.ERROR)) {
      const errorData = error instanceof Error ? {
        message: error.message,
        stack: error.stack,
        name: error.name
      } : error;
      console.error(this.formatMessage('ERROR', message, errorData));
    }
  }

  // Helper to create child logger with different prefix
  child(prefix: string): Logger {
    return new Logger({
      level: this.level,
      prefix: `${this.prefix}:${prefix}`
    });
  }

  // Update log level at runtime
  setLevel(level: LogLevel): void {
    this.level = level;
  }
}

// Get log level from environment or default
function getDefaultLogLevel(): LogLevel {
  const envLevel = globalThis.LOG_LEVEL || process?.env?.LOG_LEVEL;
  
  switch (envLevel?.toUpperCase()) {
    case 'VERBOSE':
      return LogLevel.VERBOSE;
    case 'DEBUG':
      return LogLevel.DEBUG;
    case 'INFO':
      return LogLevel.INFO;
    case 'WARN':
    case 'WARNING':
      return LogLevel.WARN;
    case 'ERROR':
      return LogLevel.ERROR;
    default:
      // Default to INFO in production, DEBUG in development
      return globalThis.ENVIRONMENT === 'production' ? LogLevel.INFO : LogLevel.DEBUG;
  }
}

// Create default logger instance
export const logger = new Logger({
  level: getDefaultLogLevel(),
  prefix: 'Analytics'
});

// Export for convenience
export default logger;