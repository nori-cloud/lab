# Scheduler Trigger Lambda

A simple AWS Lambda function built with Node.js and TypeScript that accepts scheduler trigger inputs and returns them unchanged.

## Input/Output Format

```typescript
// Input
{
  ref: string;
  inputs: {
    action: string;
  };
}

// Output (same as input)
{
  ref: string;
  inputs: {
    action: string;
  };
}
```

## Development

### Prerequisites
- Node.js 20+
- pnpm 10.14.0+
- Docker (for local testing)

### Install Dependencies
```bash
pnpm install
```

### Build
```bash
pnpm run build
```

### Local Testing with Docker
```bash
# Build the Docker image
pnpm run docker:build

# Run the Lambda locally
pnpm run docker:test

# Test the function (in another terminal)
curl "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d '{"ref":"master","inputs":{"action":"plan"}}'
```

## Project Structure

```
├── src/
│   ├── index.ts      # Main Lambda handler
│   └── types.ts      # TypeScript type definitions
├── dist/             # Compiled JavaScript (generated)
├── infra/            # Terraform infrastructure
├── Dockerfile        # Container build configuration
├── tsconfig.json     # TypeScript configuration
└── package.json      # Dependencies and scripts
```

## Logging

The function includes structured JSON logging with different levels:
- **INFO**: Function lifecycle and important operations
- **DEBUG**: Detailed input/output information
- **WARN**: Unusual conditions
- **ERROR**: Errors and exceptions

All logs include timestamps, request IDs, and relevant context for tracking and debugging.