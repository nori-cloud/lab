FROM public.ecr.aws/lambda/nodejs:22 AS base
WORKDIR /usr/app

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

FROM base AS deps

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --prod --frozen-lockfile

FROM base AS builder

COPY package.json .
COPY pnpm-lock.yaml .
COPY src ./src
COPY tsup.config.ts ./tsup.config.ts

RUN pnpm install --frozen-lockfile
RUN pnpm run build

    
FROM base
WORKDIR ${LAMBDA_TASK_ROOT}

COPY --from=deps /usr/app/node_modules ./node_modules
COPY --from=builder /usr/app/dist/* ./
CMD ["index.handler"]